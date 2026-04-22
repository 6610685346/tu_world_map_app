import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logging/logging.dart';

import 'package:tu_world_map_app/models/building.dart';
import 'package:tu_world_map_app/models/building_type.dart';
import 'package:tu_world_map_app/services/building_service.dart';
import 'package:tu_world_map_app/services/map_selection_service.dart';
import 'package:tu_world_map_app/services/navigation_service.dart';
import 'package:tu_world_map_app/services/favorite_service.dart';
import 'package:tu_world_map_app/services/mock_location_service.dart';
import 'package:tu_world_map_app/services/snap_to_path_service.dart';
import 'package:tu_world_map_app/screens/route_picker_sheet.dart';

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
  static const double _boundsSwLat = 14.0685;
  static const double _boundsSwLng = 100.5893;
  static const double _boundsNeLat = 14.0821;
  static const double _boundsNeLng = 100.6200;

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
  bool _isCustomRoute = false; // true when using building-to-building route
  bool _userInsideCampus = false; // whether real GPS is inside university bounds
  String? _styleJson;

  StreamSubscription<Position>? _positionStream;
  final MockLocationService _mockService = MockLocationService();

  // Heading (degrees, 0=north, clockwise)
  double _heading = 0;
  LatLng? _prevLocation; // for heading estimation from movement

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onBuildingSelected();
    });
  }

  @override
  void dispose() {
    _selectionService.removeListener(_onBuildingSelected);
    _mockService.removeListener(_onMockLocationChanged);
    _positionStream?.cancel();
    _joystickTimer?.cancel();
    super.dispose();
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
      final jsonString = await rootBundle.loadString(
        'assets/styles/versatiles-colorful.json',
      );
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
      _lastRouteStart = null;
      _isRouting = false;
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
  /// GeoJSON Route Layer
  /// =====================
  Future<void> _addRouteSource() async {
    try {
      const String routeSourceId = 'app-route';
      const String routeLayerId = 'app-route-line';

      await _mapController.addSource(
        routeSourceId,
        maplibre.GeojsonSourceProperties(
          data: {
            'type': 'FeatureCollection',
            'features': [],
          },
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
          'properties': {
            'id': selBuilding.id,
            'name': selBuilding.name,
          },
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
      distanceFilter: 5,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) async {
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

            _handleLocationUpdate(
              newLocation,
              gpsHeading: position.heading,
            );
          },
        );
  }

  /// Unified location update handler for both real GPS and mock GPS.
  /// Applies snap-to-path when a route is active.
  void _handleLocationUpdate(LatLng rawLocation, {double? gpsHeading}) {
    LatLng displayLocation = rawLocation;

    // Apply snap-to-path if we have an active route (skip for mock GPS — no jitter)
    if (currentRoute.isNotEmpty && !_isCustomRoute && !_mockService.enabled) {
      displayLocation = SnapToPathService.snap(rawLocation, currentRoute);
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
    if (_mapReady && routingDestination != null && !_isCustomRoute) {
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

    // Update route in real-time if navigating (not custom A→B)
    if (routingDestination != null && !_isCustomRoute) {
      // Use raw location for reroute distance check
      _checkAndReroute(rawLocation);
    }
  }

  /// Check if the user has moved enough to warrant a reroute.
  Future<void> _checkAndReroute(LatLng rawLocation) async {
    if (_isRouting) return;
    if (routingDestination == null) return;

    if (_lastRouteStart != null) {
      final moved = const Distance().as(
        LengthUnit.Meter,
        _lastRouteStart!,
        rawLocation,
      );
      if (moved < 10) return;
    }

    _isRouting = true;

    try {
      final newRoute = await _navigationService.buildRoute(
        start: rawLocation,
        destination: routingDestination!,
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
  /// Navigation
  /// =====================

  Future<void> startNavigation(Building building, {LatLng? customStart}) async {
    final startPoint = customStart ?? currentLocation;
    if (startPoint == null) return;

    final isCustom = customStart != null;

    setState(() {
      _isRouting = false;
      currentRoute.clear();
      _lastRouteStart = null;
      routingDestination = null;
      _isCustomRoute = isCustom;
    });

    final destinationNode = _navigationService.findNearestNodeToPolygon(
      building.polygons.first,
    );

    final destination = destinationNode.position;

    routingDestination = destination;

    final route = await _navigationService.buildRoute(
      start: startPoint,
      destination: destination,
    );

    if (route.isEmpty) {
      debugPrint("NO ROUTE FOUND map screen");
      return;
    }

    setState(() {
      currentRoute = route;
      _lastRouteStart = startPoint;
    });

    // Update the route layer on the map
    await _updateRouteLayer();

    // Fit camera to show the full route
    if (route.length >= 2) {
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
          bottom: 50,
        ),
      );
    }
  }

  /// Open the route picker sheet for custom A→B navigation.
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

    if (result.origin != null) {
      // Custom A→B: origin is a building
      final originCenter = polygonCentroid(result.origin!.polygons.first);
      setState(() {
        _routeOriginBuilding = result.origin;
        selectedBuilding = result.destination;
        selectedBuildingId = result.destination.id;
        selectedBuildingCenter = polygonCentroid(result.destination.polygons.first);
      });
      _updateSelectedBuilding();
      await startNavigation(result.destination, customStart: originCenter);
    } else {
      // From current location
      setState(() {
        _routeOriginBuilding = null;
        selectedBuilding = result.destination;
        selectedBuildingId = result.destination.id;
        selectedBuildingCenter = polygonCentroid(result.destination.polygons.first);
      });
      _updateSelectedBuilding();
      await startNavigation(result.destination);
    }
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
      centerTitle: true,
      actions: [
        if (selectedBuilding != null)
          IconButton(
            icon: Icon(
              FavoriteService().isFavorite(selectedBuilding!)
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: AppColors.primaryRed,
            ),
            onPressed: () {
              FavoriteService().toggle(selectedBuilding!);
              setState(() {});
            },
          ),
        // Route picker (custom A→B)
        IconButton(
          icon: const Icon(Icons.alt_route, color: AppColors.primaryRed),
          tooltip: 'Plan Route',
          onPressed: _openRoutePicker,
        ),
        // Quick navigate from current location (only visible when a target is selected)
        if (selectedBuilding != null)
          IconButton(
            icon: const Icon(Icons.directions, color: AppColors.primaryRed),
            tooltip: 'Navigate from here',
            onPressed: () {
              startNavigation(selectedBuilding!);
            },
          ),
        // Current location button
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
        // Mock GPS toggle — only allow manual toggle if inside campus or already enabled
        if (!_mockService.autoEnabled)
          IconButton(
            icon: Icon(
              Icons.gamepad,
              color: _mockService.enabled
                  ? Colors.green
                  : AppColors.brown.withValues(alpha: 0.5),
            ),
            tooltip: _mockService.enabled ? 'Disable Mock GPS' : 'Enable Mock GPS',
            onPressed: () {
              _mockService.toggle(initialPosition: currentLocation);
              setState(() {});
            },
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
        child: CircularProgressIndicator(
          color: AppColors.primaryRed,
        ),
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
          minMaxZoomPreference: const maplibre.MinMaxZoomPreference(
            13,
            22,
          ),
          cameraTargetBounds: maplibre.CameraTargetBounds(
            maplibre.LatLngBounds(
              southwest: const maplibre.LatLng(_boundsSwLat, _boundsSwLng),
              northeast: const maplibre.LatLng(_boundsNeLat, _boundsNeLng),
            ),
          ),
          trackCameraPosition: true,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          tiltGesturesEnabled: true,
          rotateGesturesEnabled: true,
          myLocationEnabled: false, // We use our own blue dot
        ),
        // Attribution
        Positioned(
          bottom: selectedBuilding != null ? 90 : 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '© OpenStreetMap contributors',
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                        _mockService.autoEnabled ? Icons.location_off : Icons.gamepad,
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                  color: isSelected ? Colors.white : Colors.grey.shade700,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  speed.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : Colors.grey.shade700,
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
        // Selected building info card
        if (selectedBuilding != null) _buildSelectedCard(),
      ],
    );
  }

  /// ---------------------
  /// Mock Controls (Racing-Game Style)
  /// ---------------------
  /// Layout: Steering joystick on the left, Accelerate/Brake buttons on the right.
  Widget _buildMockControls() {
    final bottomOffset = selectedBuilding != null ? 110.0 : 24.0;

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
            _joystickTimer = Timer.periodic(
              const Duration(milliseconds: 50),
              (_) {
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
              },
            );
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
              const Positioned(top: 6, child: Text('N', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))),
              const Positioned(bottom: 6, child: Text('S', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))),
              const Positioned(left: 8, child: Text('W', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))),
              const Positioned(right: 8, child: Text('E', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))),
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
    _joystickTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) {
        if (!_isAccelerating && !_isReversing) return;
        final speed = _mockService.metersPerTick;
        final direction = _isReversing ? -1.0 : 1.0;
        final rad = _mockService.heading * math.pi / 180;
        _mockService.moveBy(
          math.sin(rad) * speed * direction,
          math.cos(rad) * speed * direction,
        );
      },
    );
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
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shadowColor: Colors.red.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.white.withValues(alpha: 0.95),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCDD2).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_city,
                  color: AppColors.primaryRed,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedBuilding!.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkBrown,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedBuilding!.type.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF5D4037).withValues(alpha: 0.8),
                      ),
                    ),
                    if (_routeOriginBuilding != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'From: ${_routeOriginBuilding!.name}',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF5D4037)),
                onPressed: () {
                  setState(() {
                    selectedBuilding = null;
                    selectedBuildingId = null;
                    selectedBuildingCenter = null;
                    currentRoute.clear();
                    _lastRouteStart = null;
                    routingDestination = null;
                    _routeOriginBuilding = null;
                    _isCustomRoute = false;
                  });
                  _updateSelectedBuilding();
                  _updateRouteLayer();
                  _selectionService.clear();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
