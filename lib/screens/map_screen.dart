import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logging/logging.dart';

import 'package:tu_world_map_app/models/building.dart';
import 'package:tu_world_map_app/models/building_type.dart';
import 'package:tu_world_map_app/services/building_service.dart';
import 'package:tu_world_map_app/services/map_selection_service.dart';
import 'package:tu_world_map_app/services/navigation_service.dart';
import 'package:tu_world_map_app/services/favorite_service.dart';

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

  bool isLoading = true;
  bool _isRouting = false;
  bool _mapReady = false;
  String? _styleJson;

  StreamSubscription<Position>? _positionStream;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onBuildingSelected();
    });
  }

  @override
  void dispose() {
    _selectionService.removeListener(_onBuildingSelected);
    _positionStream?.cancel();
    super.dispose();
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

      // If a building was already selected before the map loaded, highlight it
      if (selectedBuildingId != null) {
        await _updateSelectedBuilding();
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
      distanceFilter: 10,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) async {
            final newLocation = LatLng(position.latitude, position.longitude);

            setState(() {
              currentLocation = newLocation;
            });

            // Update route in real-time if navigating
            if (routingDestination != null) {
              await updateRouteWhileWalking();
            }
          },
        );
  }

  /// =====================
  /// Navigation
  /// =====================

  Future<void> startNavigation(Building building) async {
    if (currentLocation == null) return;

    setState(() {
      _isRouting = false;
      currentRoute.clear();
      _lastRouteStart = null;
      routingDestination = null;
    });

    final destinationNode = _navigationService.findNearestNodeToPolygon(
      building.polygons.first,
    );

    final destination = destinationNode.position;

    routingDestination = destination;

    final route = await _navigationService.buildRoute(
      start: currentLocation!,
      destination: destination,
    );

    if (route.isEmpty) {
      debugPrint("NO ROUTE FOUND map screen");
      return;
    }

    setState(() {
      currentRoute = route;
      _lastRouteStart = currentLocation;
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

  /// =====================
  /// Realtime navigation update (while walking)
  /// =====================

  Future<void> updateRouteWhileWalking() async {
    if (currentLocation == null) return;
    if (routingDestination == null) return;
    if (_isRouting) return;

    if (_lastRouteStart != null) {
      final moved = const Distance().as(
        LengthUnit.Meter,
        _lastRouteStart!,
        currentLocation!,
      );

      if (moved < 10) return; // avoid constant rerouting
    }

    _isRouting = true;

    try {
      final newRoute = await _navigationService.buildRoute(
        start: currentLocation!,
        destination: routingDestination!,
      );

      if (newRoute.isEmpty) {
        debugPrint("Realtime route failed — keeping old route");
        return;
      }

      setState(() {
        currentRoute = newRoute;
        _lastRouteStart = currentLocation;
      });

      await _updateRouteLayer();
    } finally {
      _isRouting = false;
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
        IconButton(
          icon: const Icon(Icons.directions, color: AppColors.primaryRed),
          onPressed: () {
            if (selectedBuilding != null) {
              startNavigation(selectedBuilding!);
            }
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
          myLocationEnabled: !kIsWeb,
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
        // Selected building info card
        if (selectedBuilding != null) _buildSelectedCard(),
      ],
    );
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
