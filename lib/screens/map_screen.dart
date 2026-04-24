import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logging/logging.dart';

import 'package:tu_world_map_app/models/building.dart';
import 'package:tu_world_map_app/models/building_type.dart';
import 'package:tu_world_map_app/models/path_node.dart' show TravelMode;
import 'package:tu_world_map_app/services/building_service.dart';
import 'package:tu_world_map_app/services/map_selection_service.dart';
import 'package:tu_world_map_app/services/navigation_service.dart';
import 'package:tu_world_map_app/services/favorite_service.dart';
import 'package:tu_world_map_app/services/mock_location_service.dart';
import 'package:tu_world_map_app/services/snap_to_path_service.dart';
import 'package:tu_world_map_app/services/fused_location_source.dart';
import 'package:tu_world_map_app/screens/route_picker_sheet.dart';
import 'package:tu_world_map_app/screens/route_preview_panel.dart';

/// =====================
/// App Colors
/// =====================
class AppColors {
  static const primaryRed = Color(0xFFD32F2F);
  static const darkRed = Color(0xFFB71C1C);
  static const cream = Color(0xFFFFFBF5);
  static const brown = Color(0xFF6D4C41);
  static const darkBrown = Color(0xFF3E2723);
}

/// =====================
/// Navigation flow state
/// =====================
/// idle:       no building selected; just the map.
/// selected:   a building is selected; map shows its highlight + a card
///             with the primary "Directions" action.
/// preview:    a route has been computed and drawn; the preview panel
///             shows distance/ETA/mode chips and a Start button. Camera
///             does not track the user yet.
/// navigating: the user pressed Start. Camera tracks user, snap-to-path
///             and reroute logic are active.
enum _NavState { idle, selected, preview, navigating }

/// =====================
/// Map Screen
/// =====================
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _log = Logger('MapScreen');

  // Controllers & Services
  late maplibre.MapLibreMapController _mapController;
  final BuildingService _buildingService = BuildingService();
  final MapSelectionService _selectionService = MapSelectionService();
  final NavigationService _navigationService = NavigationService();

  // Campus bounds (for clamping)
  // SW corner, NE corner
  static const double _boundsSwLat = 14.055335;
  static const double _boundsSwLng = 100.57105;
  static const double _boundsNeLat = 14.089425;
  static const double _boundsNeLng = 100.64185;

  // State
  List<Building> buildings = [];
  List<LatLng> currentRoute = [];

  Building? selectedBuilding;
  String? selectedBuildingId;
  LatLng? selectedBuildingCenter;
  LatLng? currentLocation;
  LatLng? _lastRouteStart;
  LatLng? routingDestination;
  Building? _routeOriginBuilding; // non-null = custom A→B route

  bool isLoading = true;
  bool _isRouting = false;
  bool _mapReady = false;
  _NavState _navState = _NavState.idle;
  TravelMode _travelMode = TravelMode.walk;
  // Cached route metrics for the preview panel.
  double _previewDistanceMeters = 0;
  Duration _previewEta = Duration.zero;

  // Reroute rate limit: never recompute more often than once every 3s.
  DateTime? _lastRerouteAt;
  static const double _offRouteThresholdMeters = 25.0;
  static const double _movedThresholdMeters = 10.0;
  static const Duration _rerouteCooldown = Duration(seconds: 3);
  bool _userInsideCampus =
      false; // whether real GPS is inside university bounds
  String? _styleJson;

  StreamSubscription<Position>? _positionStream;
  final MockLocationService _mockService = MockLocationService();

  /// IMU fusion layer (Phase 1: step-based PDR + gyro heading).
  /// Only engaged when travel mode is walk AND mock mode is off.
  final FusedLocationSource _fusion = FusedLocationSource();
  StreamSubscription<SmoothedLocation>? _fusionSub;

  // Heading (degrees, 0=north, clockwise)
  double _heading = 0;
  LatLng? _prevLocation; // for heading estimation from movement

  // Current camera zoom (updated on every camera-idle event)
  // ignore: unused_field
  double _currentZoom = 14.0;

  // Joystick state (racing-game style)
  Offset _joystickDelta = Offset.zero; // direction only
  Timer? _joystickTimer;
  bool _isAccelerating = false;
  bool _isReversing = false;

  /// =====================
  /// Lifecycle
  /// =====================
  @override
  void initState() {
    super.initState();

    _loadStyleJson();
    _loadBuildings();
    _getCurrentLocation();

    _selectionService.addListener(_onBuildingSelected);
    _mockService.addListener(_onMockLocationChanged);
    FavoriteService().addListener(_syncFavorites);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onBuildingSelected();
    });
  }

  @override
  void dispose() {
    _selectionService.removeListener(_onBuildingSelected);
    _mockService.removeListener(_onMockLocationChanged);
    FavoriteService().removeListener(_syncFavorites);
    _positionStream?.cancel();
    _fusionSub?.cancel();
    _fusion.dispose();
    _joystickTimer?.cancel();
    super.dispose();
  }

  void _syncFavorites() {
    if (mounted) {
      setState(() {
        for (var building in buildings) {
          building.isFavorite = FavoriteService().isFavorite(building);
        }
      });
    }
  }

  /// Called whenever the mock location service updates.
  void _onMockLocationChanged() {
    if (!_mockService.enabled) return;
    _handleLocationUpdate(_mockService.mockPosition);
  }

  /// =====================
  /// Load Style JSON
  /// =====================
  Future<void> _loadStyleJson() async {
    try {
      var jsonString = await rootBundle.loadString(
        'assets/styles/versatiles-colorful.json',
      );

      // On Flutter Web, sprite names containing colons (e.g. "basics:icon-bank")
      // get double-URL-encoded (%253A instead of %3A) causing 404 errors.
      // Strip the sprite reference on web — text labels still work, only icons
      // are removed. Native platforms keep sprites since they handle colons fine.
      if (kIsWeb) {
        final parsed = json.decode(jsonString) as Map<String, dynamic>;
        parsed.remove('sprite');
        jsonString = json.encode(parsed);
        _log.info('Removed sprite reference for Flutter Web compatibility');
      }

      setState(() {
        _styleJson = jsonString;
      });
      _log.info('Loaded style JSON');
    } catch (e, stackTrace) {
      _log.severe('Failed to load style JSON', e, stackTrace);
    }
  }

  /// =====================
  /// Building Selection
  /// =====================
  void _onBuildingSelected() {
    final selected = _selectionService.selectedBuilding;
    if (selected == null || buildings.isEmpty) return;

    final polygon = selected.polygons.first;
    final center = polygonCentroid(polygon);

    setState(() {
      selectedBuilding = selected;
      selectedBuildingId = selected.id;
      selectedBuildingCenter = center;

      currentRoute.clear();
      routingDestination = null;
      _routeOriginBuilding = null;
      _lastRouteStart = null;
      _isRouting = false;
      _navState = _NavState.selected;
    });

    // Update the selected building highlight on map
    if (_mapReady) {
      _updateSelectedBuilding();
    }

    // Animate camera to selected building
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_mapReady) {
        try {
          _mapController.animateCamera(
            maplibre.CameraUpdate.newLatLngZoom(
              maplibre.LatLng(center.latitude, center.longitude),
              18.3,
            ),
          );
        } catch (e, stackTrace) {
          _log.severe('Camera animation error', e, stackTrace);
        }
      }
    });
  }

  /// =====================
  /// Load Data
  /// =====================
  Future<void> _loadBuildings() async {
    try {
      final data = await _buildingService.getBuildings();

      // Sync favorite status from FavoriteService
      for (var building in data) {
        building.isFavorite = FavoriteService().isFavorite(building);
      }

      if (mounted) {
        setState(() {
          buildings = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading buildings: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /// =====================
  /// MapLibre Callbacks
  /// =====================
  void _onMapCreated(maplibre.MapLibreMapController controller) {
    _mapController = controller;
    _log.info('MapLibre controller created');
  }

  Future<void> _onStyleLoaded() async {
    _mapReady = true;
    try {
      _log.info('Map style loaded callback triggered');

      if (buildings.isEmpty) {
        _log.info('Loading buildings from service...');
        await _loadBuildings();
      }

      if (buildings.isNotEmpty) {
        _log.info(
          'Adding building source to map (${buildings.length} buildings)...',
        );
        await _addBuildingSource();
        _log.info('Buildings successfully added to map');
      } else {
        _log.warning('No buildings to add');
      }

      // Add route source (initially empty)
      await _addRouteSource();

      // Add user location blue dot source
      await _addUserLocationSource();

      // Enhance POI labels from tile data (bus stops, parking, shops, etc.)
      await _enhancePoiLayers();

      // Add building name labels from app database
      if (buildings.isNotEmpty) {
        await _addBuildingLabels();
      }

      // If a building was already selected before the map loaded, highlight it
      if (selectedBuildingId != null) {
        await _updateSelectedBuilding();
      }

      // If we already have a location, show it immediately
      if (currentLocation != null) {
        await _updateUserLocationDot();
      }
    } catch (e, stackTrace) {
      _log.severe('Error in _onStyleLoaded', e, stackTrace);
    }
  }

  /// =====================
  /// GeoJSON Building Layers
  /// =====================
  Future<void> _addBuildingSource() async {
    try {
      /// Create GeoJSON feature collection from buildings
      final features = <Map<String, dynamic>>[];

      for (final building in buildings) {
        for (final polygon in building.polygons) {
          features.add({
            'type': 'Feature',
            'properties': {'id': building.id, 'name': building.name},
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                polygon
                    .map((point) => [point.longitude, point.latitude])
                    .toList(),
              ],
            },
          });
        }
      }

      final geoJson = {'type': 'FeatureCollection', 'features': features};

      /// Add source for all buildings
      const String sourceId = 'app-buildings';
      const String fillLayerId = 'app-buildings-fill';
      const String strokeLayerId = 'app-buildings-stroke';

      await _mapController.addSource(
        sourceId,
        maplibre.GeojsonSourceProperties(data: geoJson),
      );

      /// Add fill layer - invisible for non-selected buildings
      await _mapController.addLayer(
        sourceId,
        fillLayerId,
        const maplibre.FillLayerProperties(
          fillColor: '#90A4AE', // Neutral blue-gray (not visible)
          fillOpacity: 0, // Invisible
        ),
      );

      /// Add stroke layer - invisible for non-selected buildings
      await _mapController.addLayer(
        sourceId,
        strokeLayerId,
        const maplibre.LineLayerProperties(
          lineColor: '#607D8B', // Dark blue-gray (not visible)
          lineWidth: 0, // Invisible
        ),
      );

      /// Add separate source and layers for selected building (initially empty)
      const String selectedSourceId = 'app-selected-building';
      const String selectedFillLayerId = 'app-selected-building-fill';
      const String selectedStrokeLayerId = 'app-selected-building-stroke';

      await _mapController.addSource(
        selectedSourceId,
        maplibre.GeojsonSourceProperties(
          data: {'type': 'FeatureCollection', 'features': []},
        ),
      );

      /// Add fill layer for selected building with red color
      await _mapController.addLayer(
        selectedSourceId,
        selectedFillLayerId,
        const maplibre.FillLayerProperties(
          fillColor: '#D32F2F', // Red for selected
          fillOpacity: 0.5,
        ),
      );

      /// Add stroke layer for selected building with dark red
      await _mapController.addLayer(
        selectedSourceId,
        selectedStrokeLayerId,
        const maplibre.LineLayerProperties(
          lineColor: '#B71C1C', // Dark red for selected
          lineWidth: 3,
        ),
      );
    } catch (e, stackTrace) {
      _log.severe('Error adding building source', e, stackTrace);
      rethrow;
    }
  }

  /// =====================
  /// Enhance Tile-Data POI Layers
  /// =====================
  /// Modifies the existing style POI layers to show text labels (name)
  /// at lower zoom levels with higher opacity, similar to OpenStreetMap.
  Future<void> _enhancePoiLayers() async {
    try {
      // List of existing POI layer IDs from the VersaTiles style
      const poiLayers = [
        'poi-amenity',
        'poi-leisure',
        'poi-tourism',
        'poi-shop',
        'poi-man_made',
        'poi-historic',
        'poi-emergency',
        'poi-highway',
        'poi-office',
      ];

      for (final layerId in poiLayers) {
        try {
          // Add text labels and increase icon/text opacity at lower zoom
          await _mapController.setLayerProperties(
            layerId,
            maplibre.SymbolLayerProperties(
              textField: [maplibre.Expressions.get, 'name'],
              textSize: [
                maplibre.Expressions.interpolate,
                ['linear'],
                [maplibre.Expressions.zoom],
                14,
                9,
                16,
                11,
                18,
                13,
              ],
              textOffset: [
                maplibre.Expressions.literal,
                [0, 1.5],
              ],
              textAnchor: 'top',
              textMaxWidth: 8,
              textOptional: true,
              iconAllowOverlap: false,
              textAllowOverlap: false,
              iconOpacity: [
                maplibre.Expressions.interpolate,
                ['linear'],
                [maplibre.Expressions.zoom],
                14,
                0.0,
                15,
                0.6,
                17,
                1.0,
              ],
              textOpacity: [
                maplibre.Expressions.interpolate,
                ['linear'],
                [maplibre.Expressions.zoom],
                14,
                0.0,
                15,
                0.7,
                17,
                1.0,
              ],
              textColor: '#333333',
              textHaloColor: '#FFFFFF',
              textHaloWidth: 1.5,
            ),
          );
        } catch (e) {
          // Layer might not exist in this tile region — skip silently
          _log.fine('Could not enhance POI layer $layerId: $e');
        }
      }

      _log.info('POI layers enhanced with text labels');
    } catch (e, stackTrace) {
      _log.severe('Error enhancing POI layers', e, stackTrace);
    }
  }

  /// =====================
  /// Campus Building Name Labels (from app DB)
  /// =====================
  /// Creates a GeoJSON point source with building centroids and a symbol
  /// layer that renders building names on the map.
  Future<void> _addBuildingLabels() async {
    try {
      // Build GeoJSON features from the app's building database
      final features = <Map<String, dynamic>>[];

      for (final building in buildings) {
        if (building.polygons.isEmpty) continue;

        final centroid = polygonCentroid(building.polygons.first);

        features.add({
          'type': 'Feature',
          'properties': {'name': building.name, 'type': building.type.name},
          'geometry': {
            'type': 'Point',
            'coordinates': [centroid.longitude, centroid.latitude],
          },
        });
      }

      final geoJson = {'type': 'FeatureCollection', 'features': features};

      // Add source
      await _mapController.addSource(
        'app-building-labels',
        maplibre.GeojsonSourceProperties(data: geoJson),
      );

      // Add symbol layer for building names
      await _mapController.addLayer(
        'app-building-labels',
        'app-building-labels-text',
        maplibre.SymbolLayerProperties(
          textField: [maplibre.Expressions.get, 'name'],
          textSize: [
            maplibre.Expressions.interpolate,
            ['linear'],
            [maplibre.Expressions.zoom],
            14, 0, // invisible at z14
            15, 10, // small text at z15
            17, 13, // medium at z17
            19, 15, // full at z19
          ],
          textFont: [
            maplibre.Expressions.literal,
            ['noto_sans_regular'],
          ],
          textAnchor: 'center',
          textMaxWidth: 8,
          textAllowOverlap: false,
          textIgnorePlacement: false,
          textColor: '#5D4037', // Brown to match app theme
          textHaloColor: '#FFFFFF',
          textHaloWidth: 2,
          textOpacity: [
            maplibre.Expressions.interpolate,
            ['linear'],
            [maplibre.Expressions.zoom],
            14,
            0.0,
            15.5,
            0.8,
            17,
            1.0,
          ],
        ),
      );

      _log.info('Building labels added (${features.length} buildings)');
    } catch (e, stackTrace) {
      _log.severe('Error adding building labels', e, stackTrace);
    }
  }

  /// =====================
  /// GeoJSON Route Layer
  /// =====================
  Future<void> _addRouteSource() async {
    try {
      const String routeSourceId = 'app-route';
      const String routeLayerId = 'app-route-line';

      await _mapController.addSource(
        routeSourceId,
        maplibre.GeojsonSourceProperties(
          data: {'type': 'FeatureCollection', 'features': []},
        ),
      );

      await _mapController.addLayer(
        routeSourceId,
        routeLayerId,
        const maplibre.LineLayerProperties(
          lineColor: '#D32F2F', // Primary red
          lineWidth: 5,
          lineCap: 'round',
          lineJoin: 'round',
        ),
      );
    } catch (e, stackTrace) {
      _log.severe('Error adding route source', e, stackTrace);
    }
  }

  Future<void> _updateRouteLayer() async {
    if (!_mapReady) return;

    try {
      Map<String, dynamic> geoJson;

      if (currentRoute.isEmpty) {
        geoJson = {'type': 'FeatureCollection', 'features': []};
      } else {
        geoJson = {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'properties': {},
              'geometry': {
                'type': 'LineString',
                'coordinates': currentRoute
                    .map((p) => [p.longitude, p.latitude])
                    .toList(),
              },
            },
          ],
        };
      }

      await _mapController.setGeoJsonSource('app-route', geoJson);
    } catch (e, stackTrace) {
      _log.severe('Error updating route layer', e, stackTrace);
    }
  }

  /// =====================
  /// Selected Building Highlight
  /// =====================
  Future<void> _updateSelectedBuilding() async {
    if (!_mapReady) return;

    try {
      if (selectedBuildingId == null) {
        // Clear selected building layer
        await _mapController.setGeoJsonSource('app-selected-building', {
          'type': 'FeatureCollection',
          'features': [],
        });
        return;
      }

      // Find the selected building
      final selBuilding = buildings.firstWhere(
        (b) => b.id == selectedBuildingId,
      );

      // Create GeoJSON for selected building only
      final features = <Map<String, dynamic>>[];
      for (final polygon in selBuilding.polygons) {
        features.add({
          'type': 'Feature',
          'properties': {'id': selBuilding.id, 'name': selBuilding.name},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              polygon
                  .map((point) => [point.longitude, point.latitude])
                  .toList(),
            ],
          },
        });
      }

      final geoJson = {'type': 'FeatureCollection', 'features': features};

      // Update selected building source
      await _mapController.setGeoJsonSource('app-selected-building', geoJson);
    } catch (e, stackTrace) {
      _log.severe('Error updating selected building', e, stackTrace);
    }
  }

  /// =====================
  /// User Location Blue Dot (GeoJSON)
  /// =====================
  Future<void> _addUserLocationSource() async {
    try {
      // Source for user location dot
      await _mapController.addSource(
        'app-user-location',
        maplibre.GeojsonSourceProperties(
          data: {'type': 'FeatureCollection', 'features': []},
        ),
      );

      // Outer glow / accuracy ring
      await _mapController.addLayer(
        'app-user-location',
        'app-user-location-glow',
        const maplibre.CircleLayerProperties(
          circleRadius: 18,
          circleColor: '#4285F4',
          circleOpacity: 0.15,
        ),
      );

      // White border
      await _mapController.addLayer(
        'app-user-location',
        'app-user-location-border',
        const maplibre.CircleLayerProperties(
          circleRadius: 9,
          circleColor: '#FFFFFF',
          circleOpacity: 1,
        ),
      );

      // Blue dot
      await _mapController.addLayer(
        'app-user-location',
        'app-user-location-dot',
        const maplibre.CircleLayerProperties(
          circleRadius: 6,
          circleColor: '#4285F4',
          circleOpacity: 1,
        ),
      );
    } catch (e, stackTrace) {
      _log.severe('Error adding user location source', e, stackTrace);
    }
  }

  Future<void> _updateUserLocationDot() async {
    if (!_mapReady || currentLocation == null) return;

    try {
      final geoJson = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {},
            'geometry': {
              'type': 'Point',
              'coordinates': [
                currentLocation!.longitude,
                currentLocation!.latitude,
              ],
            },
          },
        ],
      };

      await _mapController.setGeoJsonSource('app-user-location', geoJson);
    } catch (e) {
      _log.warning('Error updating user location dot: $e');
    }
  }

  /// Check if a position is within campus bounds.
  bool _isInsideCampus(LatLng pos) {
    return pos.latitude >= _boundsSwLat &&
        pos.latitude <= _boundsNeLat &&
        pos.longitude >= _boundsSwLng &&
        pos.longitude <= _boundsNeLng;
  }

  /// Called whenever the camera becomes idle (pan/zoom ends).
  ///
  /// MapLibre's [cameraTargetBounds] only constrains the camera *center* to a
  /// fixed rectangle — it does NOT shrink that rectangle as the user zooms in.
  /// The result is that at high zoom levels the camera center can be placed near
  /// the edge of the campus rectangle, making half the viewport show area outside
  /// campus.  At low zoom levels the viewport is larger than the rectangle, so
  /// the SDK fights itself and produces jittery over-clamping.
  ///
  /// The correct approach: compute how many degrees of lat/lng a half-screen
  /// occupies at the *current* zoom level and shrink the allowed center region
  /// by that inset on every side.  If the current center violates the shrunken
  /// box, snap it back in one smooth animation.
  void _onCameraIdle() {
    if (!_mapReady) return;

    final position = _mapController.cameraPosition;
    if (position == null) return;

    final zoom = position.zoom;
    _currentZoom = zoom;

    final centerLat = position.target.latitude;
    final centerLng = position.target.longitude;

    // At zoom level z, one tile covers 360°/2^z of longitude.
    // A standard 256-px tile displayed on a ~390-pt-wide screen means roughly
    // (screenWidthTiles / 2) tiles are visible on each side of the center.
    // We use a conservative half-viewport estimate in degrees so the full
    // visible area stays inside the campus bounds.
    //
    // halfLng° of longitude per half-screen  = 360 / 2^zoom  * (viewport_px/2 / 256)
    // halfLat° ≈ halfLng (Mercator distortion is negligible at campus scale)
    //
    // We use a fixed logical half-screen size of 220 pt (safe for phones/tablets).
    const double halfScreenPx = 220.0;
    final double tilesPerDegLng = math.pow(2, zoom) / 360.0;
    final double halfLng = halfScreenPx / 256.0 / tilesPerDegLng;

    // Latitude scaling: Mercator stretches latitude near the equator edge;
    // at ~14° N the correction is tiny, but apply it for correctness.
    final double latRad = centerLat * math.pi / 180.0;
    final double halfLat = halfLng * math.cos(latRad);

    // Inset the full campus bounds by the half-viewport on every side.
    final double minLat = _boundsSwLat + halfLat;
    final double maxLat = _boundsNeLat - halfLat;
    final double minLng = _boundsSwLng + halfLng;
    final double maxLng = _boundsNeLng - halfLng;

    // If the inset box has collapsed (user zoomed out further than the campus
    // area fills the screen), clamp to the campus center so we don't invert
    // the constraint.
    final double clampedMinLat = minLat < maxLat
        ? minLat
        : (_boundsSwLat + _boundsNeLat) / 2;
    final double clampedMaxLat = minLat < maxLat
        ? maxLat
        : (_boundsSwLat + _boundsNeLat) / 2;
    final double clampedMinLng = minLng < maxLng
        ? minLng
        : (_boundsSwLng + _boundsNeLng) / 2;
    final double clampedMaxLng = minLng < maxLng
        ? maxLng
        : (_boundsSwLng + _boundsNeLng) / 2;

    // Clamp the current center into the zoom-adjusted box.
    final double newLat = centerLat.clamp(clampedMinLat, clampedMaxLat);
    final double newLng = centerLng.clamp(clampedMinLng, clampedMaxLng);

    // Only animate if the center is actually out of bounds (avoid jitter).
    const double epsilon = 1e-7;
    if ((newLat - centerLat).abs() > epsilon ||
        (newLng - centerLng).abs() > epsilon) {
      try {
        _mapController.animateCamera(
          maplibre.CameraUpdate.newCameraPosition(
            maplibre.CameraPosition(
              target: maplibre.LatLng(newLat, newLng),
              zoom: zoom,
              bearing: position.bearing,
              tilt: position.tilt,
            ),
          ),
        );
      } catch (e) {
        _log.warning('Boundary clamp animation failed: $e');
      }
    }
  }

  /// =====================
  /// Location (Real-Time)
  /// =====================
  Future<void> _getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      // distanceFilter: 0 lets every platform fix through — matches Google
      // Maps' default. A non-zero filter silently drops updates below the
      // threshold, which at walking pace can mean multi-second gaps.
      distanceFilter: 0,
    );

    // IMU fusion emits smoothed positions between GPS fixes whenever
    // a step is detected or the gyro-corrected heading changes the
    // dead-reckoned position. We only consume it for walk mode; other
    // modes pass raw GPS straight through.
    _fusion.start();
    _fusionSub = _fusion.stream.listen((smoothed) {
      if (_mockService.enabled) return;
      if (_travelMode != TravelMode.walk) return;
      _handleLocationUpdate(smoothed.position, gpsHeading: smoothed.headingDeg);
    });

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) async {
          // Skip real GPS updates when mock mode is active
          if (_mockService.enabled) return;

          final newLocation = LatLng(position.latitude, position.longitude);
          final inside = _isInsideCampus(newLocation);

          // Auto-enable mock GPS if user is outside campus
          if (!inside && !_userInsideCampus && !_mockService.enabled) {
            _mockService.enable(
              initialPosition: const LatLng(14.0723, 100.6034), // campus center
              auto: true,
            );
            setState(() {
              _userInsideCampus = false;
            });
            return;
          }

          // If user comes back inside campus, disable auto-mock
          if (inside && _mockService.autoEnabled) {
            _mockService.disable();
          }

          setState(() {
            _userInsideCampus = inside;
          });

          if (_travelMode == TravelMode.walk) {
            // Feed GPS into PDR; the fusion stream callback above will
            // deliver the smoothed update into _handleLocationUpdate.
            _fusion.onGpsFix(
              position: newLocation,
              gpsHeadingDeg: position.heading,
              accuracyMeters: position.accuracy,
              speedMps: position.speed,
            );
          } else {
            _handleLocationUpdate(newLocation, gpsHeading: position.heading);
          }
        });
  }

  /// Unified location update handler for both real GPS and mock GPS.
  /// Applies snap-to-path when a route is active.
  void _handleLocationUpdate(LatLng rawLocation, {double? gpsHeading}) {
    LatLng displayLocation = rawLocation;
    RouteProjection? projection;

    // Project the user onto the active route. The projection drives both
    // snap-to-path (display smoothing) and the off-route reroute trigger.
    if (currentRoute.isNotEmpty && _navState == _NavState.navigating) {
      projection = SnapToPathService.projectOnto(rawLocation, currentRoute);
      // Mock GPS doesn't jitter, so we don't snap the displayed dot; but
      // we still use the projection for trimming and reroute decisions.
      if (projection != null &&
          !_mockService.enabled &&
          projection.distanceMeters <= _offRouteThresholdMeters) {
        displayLocation = projection.point;
      }
    }

    // Trim the portion of the route already behind the user so the red
    // line doesn't trail. Only trim when the user is reasonably on-route;
    // if they're far off, the reroute path below will rebuild the line.
    if (projection != null &&
        projection.distanceMeters <= _offRouteThresholdMeters) {
      final trimmed = SnapToPathService.trimFrom(currentRoute, projection);
      if (trimmed.length >= 2 && trimmed.length != currentRoute.length) {
        currentRoute = trimmed;
        _updateRouteLayer();
      }
    }

    // Estimate heading from movement if no sensor heading provided
    if (gpsHeading != null && gpsHeading >= 0) {
      _heading = gpsHeading;
    } else if (_prevLocation != null) {
      final dLat = rawLocation.latitude - _prevLocation!.latitude;
      final dLng = rawLocation.longitude - _prevLocation!.longitude;
      if (dLat.abs() > 1e-7 || dLng.abs() > 1e-7) {
        _heading = (math.atan2(dLng, dLat) * 180 / math.pi) % 360;
      }
    }
    _prevLocation = rawLocation;

    // If mock service is providing heading, use it
    if (_mockService.enabled) {
      _heading = _mockService.heading;
    }

    setState(() {
      currentLocation = displayLocation;
    });

    // Update the blue dot on the map
    _updateUserLocationDot();

    // Rotate map to match heading when navigating
    if (_mapReady && _navState == _NavState.navigating) {
      try {
        _mapController.animateCamera(
          maplibre.CameraUpdate.newCameraPosition(
            maplibre.CameraPosition(
              target: maplibre.LatLng(
                displayLocation.latitude,
                displayLocation.longitude,
              ),
              bearing: _heading,
              zoom: 18,
              tilt: 45,
            ),
          ),
        );
      } catch (e) {
        _log.warning('Camera rotation failed: $e');
      }
    }

    // Real-time reroute only fires once the user has actually started.
    if (_navState == _NavState.navigating) {
      _checkAndReroute(rawLocation, projection);
    }
  }

  /// Decide whether to recompute the route, and do so if needed. Fires on
  /// two triggers: (a) user has moved >10m since the last reroute, or
  /// (b) user is >25m from the drawn route (off-graph detour, shortcut).
  /// A 3s cooldown prevents rapid rerouting from GPS jitter.
  Future<void> _checkAndReroute(
    LatLng rawLocation,
    RouteProjection? projection,
  ) async {
    if (_isRouting) return;
    if (routingDestination == null) return;

    final now = DateTime.now();
    if (_lastRerouteAt != null &&
        now.difference(_lastRerouteAt!) < _rerouteCooldown) {
      return;
    }

    final distance = const Distance();
    final movedEnough = _lastRouteStart == null ||
        distance.as(LengthUnit.Meter, _lastRouteStart!, rawLocation) >
            _movedThresholdMeters;
    final offRoute = projection != null &&
        projection.distanceMeters > _offRouteThresholdMeters;

    if (!movedEnough && !offRoute) return;

    _isRouting = true;
    _lastRerouteAt = now;

    try {
      final newRoute = await _navigationService.buildRoute(
        start: rawLocation,
        destination: routingDestination!,
        mode: _travelMode,
      );

      if (newRoute.isEmpty) {
        debugPrint("Realtime route failed — keeping old route");
        return;
      }

      setState(() {
        currentRoute = newRoute;
        _lastRouteStart = rawLocation;
      });

      await _updateRouteLayer();
    } finally {
      _isRouting = false;
    }
  }

  /// =====================
  /// Navigation flow
  /// =====================

  /// Sum of segment lengths along a polyline, in meters.
  double _routeDistanceMeters(List<LatLng> route) {
    if (route.length < 2) return 0;
    final d = const Distance();
    double total = 0;
    for (int i = 1; i < route.length; i++) {
      total += d.as(LengthUnit.Meter, route[i - 1], route[i]);
    }
    return total;
  }

  /// Estimated travel time for [meters] under [mode]. Speed presets match
  /// MockSpeedExtension so the preview stays consistent with mock GPS.
  Duration _etaFor(double meters, TravelMode mode) {
    final mps = switch (mode) {
      TravelMode.walk => 1.4, // 5 km/h
      TravelMode.bike => 4.2, // 15 km/h
      TravelMode.car => 8.3, // 30 km/h
    };
    if (mps <= 0) return Duration.zero;
    return Duration(seconds: (meters / mps).round());
  }

  /// User tapped Directions on the selected card. Compute the route and
  /// transition to preview. Optionally [originBuilding] picks a custom
  /// origin (set by Change Start in the preview, or the route picker).
  Future<void> _handleDirectionsPressed({
    Building? originBuilding,
  }) async {
    final building = selectedBuilding;
    if (building == null) return;

    final originCenter = originBuilding != null
        ? polygonCentroid(originBuilding.polygons.first)
        : currentLocation;
    if (originCenter == null) return;

    setState(() {
      _isRouting = false;
      currentRoute.clear();
      _lastRouteStart = null;
      routingDestination = null;
      _routeOriginBuilding = originBuilding;
    });

    final destinationNode = await _navigationService.findNearestNodeToPolygon(
      building.polygons.first,
    );
    final destination = destinationNode.position;
    routingDestination = destination;

    final route = await _navigationService.buildRoute(
      start: originCenter,
      destination: destination,
      mode: _travelMode,
    );

    if (route.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No route found for this travel mode.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final meters = _routeDistanceMeters(route);
    setState(() {
      currentRoute = route;
      _lastRouteStart = originCenter;
      _previewDistanceMeters = meters;
      _previewEta = _etaFor(meters, _travelMode);
      _navState = _NavState.preview;
    });

    await _updateRouteLayer();
    _fitCameraToRoute(route);
  }

  /// User tapped a different mode chip while in preview. Recompute and
  /// stay in preview.
  Future<void> _onPreviewModeChanged(TravelMode mode) async {
    if (mode == _travelMode) return;
    setState(() {
      _travelMode = mode;
    });
    if (_navState == _NavState.preview) {
      await _handleDirectionsPressed(originBuilding: _routeOriginBuilding);
    } else if (_navState == _NavState.navigating) {
      // Already navigating — recompute on the fly.
      await _recomputeNavigatingRoute();
    }
  }

  /// Recompute the active route from the current location after an
  /// in-flight mode change.
  Future<void> _recomputeNavigatingRoute() async {
    final start = currentLocation;
    final dest = routingDestination;
    if (start == null || dest == null) return;
    final route = await _navigationService.buildRoute(
      start: start,
      destination: dest,
      mode: _travelMode,
    );
    if (!mounted) return;
    if (route.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No ${_travelMode.name} route available.'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      currentRoute = route;
      _lastRouteStart = start;
    });
    await _updateRouteLayer();
  }

  /// User tapped Start in the preview. Transition to navigating.
  void _beginNavigation() {
    if (_navState != _NavState.preview) return;
    if (_routeOriginBuilding != null) {
      // Custom A→B routes are informational; we don't track turn-by-turn
      // because the user isn't physically at the origin building.
      return;
    }
    setState(() {
      _navState = _NavState.navigating;
    });
  }

  /// Drop the route, return to "selected" (the building stays selected).
  void _exitPreviewToSelected() {
    setState(() {
      _navState = _NavState.selected;
      currentRoute.clear();
      _lastRouteStart = null;
      routingDestination = null;
      _routeOriginBuilding = null;
    });
    _updateRouteLayer();
  }

  /// Stop navigation and clear the selection entirely. Recenters the
  /// camera on the user's location so they can see where they are after
  /// the navigation overlay goes away.
  void _exitToIdle() {
    setState(() {
      _navState = _NavState.idle;
      currentRoute.clear();
      _lastRouteStart = null;
      routingDestination = null;
      _routeOriginBuilding = null;
      selectedBuilding = null;
      selectedBuildingId = null;
      selectedBuildingCenter = null;
    });
    _updateSelectedBuilding();
    _updateRouteLayer();
    _selectionService.clear();
    _recenterOnUser();
  }

  /// Animate the camera back to the user's current location (if known
  /// and the map is ready). Used when returning to idle from navigation.
  void _recenterOnUser() {
    final loc = currentLocation;
    if (loc == null || !_mapReady) return;
    try {
      _mapController.animateCamera(
        maplibre.CameraUpdate.newCameraPosition(
          maplibre.CameraPosition(
            target: maplibre.LatLng(loc.latitude, loc.longitude),
            zoom: 17,
            // Reset tilt/bearing — navigation may have rotated the map.
            bearing: 0,
            tilt: 0,
          ),
        ),
      );
    } catch (e) {
      _log.warning('Recenter-on-user failed: $e');
    }
  }

  /// Fit the map camera to show the entire route polyline.
  void _fitCameraToRoute(List<LatLng> route) {
    if (route.length < 2 || !_mapReady) return;
    final lats = route.map((p) => p.latitude);
    final lngs = route.map((p) => p.longitude);
    final sw = maplibre.LatLng(
      lats.reduce((a, b) => a < b ? a : b),
      lngs.reduce((a, b) => a < b ? a : b),
    );
    final ne = maplibre.LatLng(
      lats.reduce((a, b) => a > b ? a : b),
      lngs.reduce((a, b) => a > b ? a : b),
    );
    _mapController.animateCamera(
      maplibre.CameraUpdate.newLatLngBounds(
        maplibre.LatLngBounds(southwest: sw, northeast: ne),
        left: 50,
        top: 50,
        right: 50,
        // Leave room for the preview panel at the bottom.
        bottom: 220,
      ),
    );
  }

  /// Open the route picker sheet for custom A→B preview. After the user
  /// confirms, computes the route and lands in preview state.
  void _openRoutePicker() async {
    final result = await showModalBottomSheet<RouteRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RoutePickerSheet(
        initialDestination: selectedBuilding,
        buildings: buildings,
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      selectedBuilding = result.destination;
      selectedBuildingId = result.destination.id;
      selectedBuildingCenter = polygonCentroid(
        result.destination.polygons.first,
      );
    });
    _updateSelectedBuilding();
    await _handleDirectionsPressed(originBuilding: result.origin);
  }

  /// =====================
  /// Geometry Helpers
  /// =====================

  LatLng polygonCentroid(List<LatLng> polygon) {
    double latSum = 0;
    double lngSum = 0;

    for (final p in polygon) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }

    return LatLng(latSum / polygon.length, lngSum / polygon.length);
  }

  /// =====================
  /// UI
  /// =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: _buildAppBar(),
      body: isLoading || _styleJson == null ? _buildLoading() : _buildMap(),
    );
  }

  /// ---------------------
  /// AppBar
  /// ---------------------
  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'Campus Map',
        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brown),
      ),
      backgroundColor: AppColors.cream,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Divider(
          height: 1,
          thickness: 1,
          color: AppColors.brown.withValues(alpha: 0.1),
        ),
      ),
      actions: [
        // Center camera on the user's location.
        IconButton(
          icon: const Icon(Icons.my_location, color: AppColors.primaryRed),
          tooltip: 'My Location',
          onPressed: () async {
            if (currentLocation != null && _mapReady) {
              _mapController.animateCamera(
                maplibre.CameraUpdate.newLatLngZoom(
                  maplibre.LatLng(
                    currentLocation!.latitude,
                    currentLocation!.longitude,
                  ),
                  17,
                ),
              );
            }
          },
        ),
        // Power-user / debug actions tucked behind an overflow menu.
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.primaryRed),
          tooltip: 'More',
          color: AppColors.cream,
          surfaceTintColor: Colors.transparent,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            switch (value) {
              case 'plan_route':
                _openRoutePicker();
                break;
              case 'mock_gps':
                _mockService.toggle(initialPosition: currentLocation);
                setState(() {});
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'plan_route',
              child: Row(
                children: [
                  const Icon(Icons.alt_route, color: AppColors.primaryRed, size: 20),
                  const SizedBox(width: 12),
                  const Text(
                    'Plan custom route',
                    style: TextStyle(
                      color: AppColors.darkBrown,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (!_mockService.autoEnabled)
              PopupMenuItem(
                value: 'mock_gps',
                child: Row(
                  children: [
                    Icon(
                      Icons.gamepad,
                      color: _mockService.enabled ? Colors.green : AppColors.brown,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _mockService.enabled
                          ? 'Disable Mock GPS'
                          : 'Enable Mock GPS',
                      style: const TextStyle(
                        color: AppColors.darkBrown,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// ---------------------
  /// Loading UI
  /// ---------------------
  Widget _buildLoading() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFBF5), // Almost white with warm hint
            Color(0xFFFFF8F0), // Very light cream
            Color(0xFFFFF3E8), // Subtle warm white
          ],
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primaryRed),
      ),
    );
  }

  /// ---------------------
  /// Map UI
  /// ---------------------
  Widget _buildMap() {
    return Stack(
      children: [
        maplibre.MapLibreMap(
          styleString: _styleJson!,
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          initialCameraPosition: const maplibre.CameraPosition(
            target: maplibre.LatLng(14.0683, 100.6034),
            zoom: 14,
          ),
          minMaxZoomPreference: const maplibre.MinMaxZoomPreference(13, 22),
          // NOTE: cameraTargetBounds is intentionally omitted here.
          // Boundary enforcement is handled in _onCameraIdle() with a
          // zoom-aware inset so the visible viewport never leaves the campus.
          onCameraIdle: _onCameraIdle,
          trackCameraPosition: true,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          tiltGesturesEnabled: true,
          rotateGesturesEnabled: true,
          myLocationEnabled: false, // We use our own blue dot
          // Hide the attribution button and use our own attribution text widget instead
          attributionButtonMargins: const math.Point(-100, -100),
          logoEnabled: false,
        ),
        // Attribution
        Positioned(
          bottom: selectedBuilding != null ? 110 : 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '© MapLibre | OpenStreetMap contributors',
              style: TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ),
        ),
        // Mock GPS indicator badge + speed selector
        if (_mockService.enabled)
          Positioned(
            top: 8,
            left: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _mockService.autoEnabled
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _mockService.autoEnabled
                            ? Icons.location_off
                            : Icons.gamepad,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _mockService.autoEnabled
                            ? 'Outside Campus'
                            : 'Mock GPS',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Speed selector chips
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: MockSpeed.values.map((speed) {
                      final isSelected = _mockService.speed == speed;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: InkWell(
                          onTap: () {
                            _mockService.setSpeed(speed);
                            setState(() {});
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.green.shade600
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  speed.icon,
                                  size: 14,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  speed.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        // Mock controls overlay (only when mock mode is active)
        if (_mockService.enabled) _buildMockControls(),
        // Bottom UI: depends on the navigation state.
        if (_navState == _NavState.selected) _buildSelectedCard(),
        if (_navState == _NavState.preview) _buildPreviewPanel(),
        if (_navState == _NavState.navigating) _buildNavigatingBar(),
      ],
    );
  }

  /// ---------------------
  /// Preview panel (post-Directions, pre-Start)
  /// ---------------------
  Widget _buildPreviewPanel() {
    final building = selectedBuilding;
    if (building == null) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: RoutePreviewPanel(
        originLabel: _routeOriginBuilding?.name,
        destinationLabel: building.name,
        destinationTypeLabel: building.type.displayName,
        distanceMeters: _previewDistanceMeters,
        eta: _previewEta,
        mode: _travelMode,
        canStartNavigation: _routeOriginBuilding == null,
        onStart: _beginNavigation,
        onClose: _exitPreviewToSelected,
        onChangeStart: _openRoutePicker,
        onModeChanged: _onPreviewModeChanged,
      ),
    );
  }

  /// ---------------------
  /// Navigating bar (slim status + End button)
  /// ---------------------
  Widget _buildNavigatingBar() {
    final building = selectedBuilding;
    if (building == null) return const SizedBox.shrink();
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12 + bottomInset,
      child: Material(
        elevation: 6,
        color: AppColors.primaryRed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      RoutePreviewPanel.formatEta(_previewEta),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${RoutePreviewPanel.formatDistance(_previewDistanceMeters)} · to ${building.name}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _exitToIdle,
                icon: const Icon(Icons.close, color: Colors.white),
                label: const Text(
                  'End',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ---------------------
  /// Mock Controls (Racing-Game Style)
  /// ---------------------
  /// Layout: Steering joystick on the left, Accelerate/Brake buttons on the right.
  Widget _buildMockControls() {
    final bottomOffset = selectedBuilding != null ? 140.0 : 35.0;

    return Positioned(
      bottom: bottomOffset,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // LEFT: Steering joystick (direction only)
            _buildSteeringWheel(),
            // RIGHT: Accelerate + Brake pedals
            _buildPedals(),
          ],
        ),
      ),
    );
  }

  /// Steering joystick — controls facing direction only, no movement.
  Widget _buildSteeringWheel() {
    const double baseSize = 110;
    const double knobSize = 40;
    const double maxDisplacement = (baseSize - knobSize) / 2;

    return SizedBox(
      width: baseSize,
      height: baseSize,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.15),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: GestureDetector(
          onPanStart: (_) {
            // Start a timer that continuously updates heading based on joystick position
            _joystickTimer?.cancel();
            _joystickTimer = Timer.periodic(const Duration(milliseconds: 50), (
              _,
            ) {
              if (_joystickDelta == Offset.zero) return;
              // Compute heading from joystick direction
              // dx = east/west, dy = north/south (inverted screen Y)
              final headingRad = math.atan2(
                _joystickDelta.dx,
                -_joystickDelta.dy, // screen up = north
              );
              final headingDeg = (headingRad * 180 / math.pi) % 360;
              _mockService.setHeading(headingDeg);

              // If accelerating or reversing, move in the heading direction
              if (_isAccelerating || _isReversing) {
                final speed = _mockService.metersPerTick;
                final direction = _isReversing ? -1.0 : 1.0;
                final rad = headingDeg * math.pi / 180;
                _mockService.moveBy(
                  math.sin(rad) * speed * direction,
                  math.cos(rad) * speed * direction,
                );
              }
            });
          },
          onPanUpdate: (details) {
            final center = const Offset(baseSize / 2, baseSize / 2);
            final localPos = details.localPosition;
            var delta = localPos - center;

            // Clamp to circle
            if (delta.distance > maxDisplacement) {
              delta = delta / delta.distance * maxDisplacement;
            }

            setState(() {
              _joystickDelta = delta;
            });
          },
          onPanEnd: (_) {
            _joystickTimer?.cancel();
            setState(() {
              _joystickDelta = Offset.zero;
            });
          },
          onPanCancel: () {
            _joystickTimer?.cancel();
            setState(() {
              _joystickDelta = Offset.zero;
            });
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // N/S/E/W labels
              const Positioned(
                top: 6,
                child: Text(
                  'N',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Positioned(
                bottom: 6,
                child: Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Positioned(
                left: 8,
                child: Text(
                  'W',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Positioned(
                right: 8,
                child: Text(
                  'E',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Draggable knob
              Transform.translate(
                offset: _joystickDelta,
                child: Container(
                  width: knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Transform.rotate(
                    angle: _mockService.heading * math.pi / 180,
                    child: Icon(
                      Icons.navigation,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Accelerate and Brake pedal buttons (right side).
  Widget _buildPedals() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Accelerate button
        GestureDetector(
          onTapDown: (_) {
            setState(() => _isAccelerating = true);
            // If no joystick active, start a movement timer using current heading
            _ensureMovementTimer();
          },
          onTapUp: (_) {
            setState(() => _isAccelerating = false);
            _stopMovementIfIdle();
          },
          onTapCancel: () {
            setState(() => _isAccelerating = false);
            _stopMovementIfIdle();
          },
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isAccelerating
                  ? Colors.green.shade600
                  : Colors.green.shade700.withValues(alpha: 0.7),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: _isAccelerating
                  ? [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: const Icon(
              Icons.arrow_upward,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Brake / Reverse button
        GestureDetector(
          onTapDown: (_) {
            setState(() => _isReversing = true);
            _ensureMovementTimer();
          },
          onTapUp: (_) {
            setState(() => _isReversing = false);
            _stopMovementIfIdle();
          },
          onTapCancel: () {
            setState(() => _isReversing = false);
            _stopMovementIfIdle();
          },
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isReversing
                  ? AppColors.primaryRed
                  : AppColors.primaryRed.withValues(alpha: 0.7),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: _isReversing
                  ? [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: const Icon(
              Icons.arrow_downward,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  /// Start the movement timer if pedals are pressed without joystick.
  void _ensureMovementTimer() {
    if (_joystickTimer != null) return; // joystick already running
    _joystickTimer?.cancel();
    _joystickTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_isAccelerating && !_isReversing) return;
      final speed = _mockService.metersPerTick;
      final direction = _isReversing ? -1.0 : 1.0;
      final rad = _mockService.heading * math.pi / 180;
      _mockService.moveBy(
        math.sin(rad) * speed * direction,
        math.cos(rad) * speed * direction,
      );
    });
  }

  /// Stop the movement timer if neither pedal is pressed and joystick is idle.
  void _stopMovementIfIdle() {
    if (!_isAccelerating && !_isReversing && _joystickDelta == Offset.zero) {
      _joystickTimer?.cancel();
      _joystickTimer = null;
    }
  }

  /// ---------------------
  /// Selected Building Card
  /// ---------------------
  Widget _buildSelectedCard() {
    final building = selectedBuilding!;
    final isFavorite = FavoriteService().isFavorite(building);
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shadowColor: Colors.red.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white.withValues(alpha: 0.97),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCDD2).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.location_city,
                      color: AppColors.primaryRed,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          building.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkBrown,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          building.type.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF5D4037).withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: AppColors.primaryRed,
                    ),
                    tooltip: isFavorite ? 'Unfavorite' : 'Favorite',
                    onPressed: () {
                      FavoriteService().toggle(building);
                      setState(() {});
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF5D4037)),
                    tooltip: 'Close',
                    onPressed: _exitToIdle,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => _handleDirectionsPressed(),
                  icon: const Icon(Icons.directions, color: Colors.white),
                  label: const Text(
                    'Directions',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
