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

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _log = Logger('MapScreen');
  late maplibre.MapLibreMapController mapController;
  final BuildingService buildingService = BuildingService();
  final MapSelectionService selectionService = MapSelectionService();
  List<Building> buildings = [];
  List<LatLng> currentRoute = [];
  String? selectedBuildingId;
  bool isLoading = true;
  LatLng? currentLocation;
  String? styleJson;

  @override
  void initState() {
    super.initState();
    _loadStyleJson();
    _loadBuildings();
    _getCurrentLocation();

    selectionService.clear();
    selectionService.addListener(_onBuildingSelected);
  }

  @override
  void dispose() {
    selectionService.removeListener(_onBuildingSelected);
    super.dispose();
  }

  Future<void> _loadStyleJson() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/styles/versatiles-colorful.json',
      );
      setState(() {
        styleJson = jsonString;
      });
      _log.info('Loaded style JSON');
    } catch (e, stackTrace) {
      _log.severe('Failed to load style JSON', e, stackTrace);
    }
  }

  Future<void> _loadBuildings() async {
    final data = await buildingService.getBuildings();
    setState(() {
      buildings = data;
      isLoading = false;
    });
    _log.info('Buildings loaded: ${buildings.length}');
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    _log.info("Location services called");

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _log.warning("Location services disabled");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _log.warning("Location permission denied");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _log.warning("Location permanently denied");
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
    });

    _log.info("Current Location: $currentLocation");
  }

  void _onBuildingSelected() {
    final selected = selectionService.selectedBuilding;

    if (selected == null || buildings.isEmpty) return;
    final polygon = selected.polygons.first;
    final center = _polygonCentroid(polygon);

    setState(() {
      selectedBuildingId = selected.id;
    });

    // Update the selected building highlight on map
    _updateSelectedBuilding();

    // Animate camera to selected building
    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        mapController.animateCamera(
          maplibre.CameraUpdate.newLatLngZoom(
            maplibre.LatLng(center.latitude, center.longitude),
            18.33,
          ),
        );
      } catch (e, stackTrace) {
        _log.severe('Camera animation error', e, stackTrace);
      }
    });
  }

  void _onMapCreated(maplibre.MapLibreMapController controller) {
    mapController = controller;
    _log.info('MapLibre controller created');
  }

  Future<void> _onStyleLoaded() async {
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
    } catch (e, stackTrace) {
      _log.severe('Error in _onStyleLoaded', e, stackTrace);
    }
  }

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

      await mapController.addSource(
        sourceId,
        maplibre.GeojsonSourceProperties(data: geoJson),
      );

      /// Add fill layer - invisible for non-selected buildings
      await mapController.addLayer(
        sourceId,
        fillLayerId,
        maplibre.FillLayerProperties(
          fillColor: '#90A4AE', // Neutral blue-gray (not visible)
          fillOpacity: 0, // Invisible
        ),
      );

      /// Add stroke layer - invisible for non-selected buildings
      await mapController.addLayer(
        sourceId,
        strokeLayerId,
        maplibre.LineLayerProperties(
          lineColor: '#607D8B', // Dark blue-gray (not visible)
          lineWidth: 0, // Invisible
        ),
      );

      /// Add separate source and layers for selected building (initially empty)
      const String selectedSourceId = 'app-selected-building';
      const String selectedFillLayerId = 'app-selected-building-fill';
      const String selectedStrokeLayerId = 'app-selected-building-stroke';

      await mapController.addSource(
        selectedSourceId,
        maplibre.GeojsonSourceProperties(
          data: {'type': 'FeatureCollection', 'features': []},
        ),
      );

      /// Add fill layer for selected building with red color
      await mapController.addLayer(
        selectedSourceId,
        selectedFillLayerId,
        maplibre.FillLayerProperties(
          fillColor: '#D32F2F', // Red for selected
          fillOpacity: 0.5,
        ),
      );

      /// Add stroke layer for selected building with dark red
      await mapController.addLayer(
        selectedSourceId,
        selectedStrokeLayerId,
        maplibre.LineLayerProperties(
          lineColor: '#B71C1C', // Dark red for selected
          lineWidth: 3,
        ),
      );
    } catch (e, stackTrace) {
      _log.severe('Error adding building source', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _updateSelectedBuilding() async {
    try {
      if (selectedBuildingId == null) {
        // Clear selected building layer
        await mapController.setGeoJsonSource('app-selected-building', {
          'type': 'FeatureCollection',
          'features': [],
        });
        return;
      }

      // Find the selected building
      final selectedBuilding = buildings.firstWhere(
        (b) => b.id == selectedBuildingId,
      );

      // Create GeoJSON for selected building only
      final features = <Map<String, dynamic>>[];
      for (final polygon in selectedBuilding.polygons) {
        features.add({
          'type': 'Feature',
          'properties': {
            'id': selectedBuilding.id,
            'name': selectedBuilding.name,
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
      await mapController.setGeoJsonSource('app-selected-building', geoJson);
    } catch (e, stackTrace) {
      _log.severe('Error updating selected building', e, stackTrace);
    }
  }

  Future<void> navigateToBuilding(Building building) async {
    if (currentLocation == null) {
      _log.warning("Current location not available yet.");
      return;
    }
    final destination = _polygonCentroid(building.polygons.first);

    final route = await NavigationService().buildRoute(
      start: currentLocation!,
      destination: destination,
    );

    setState(() {
      currentRoute = route;
    });
  }

  LatLng _polygonCentroid(List<LatLng> polygon) {
    double latSum = 0;
    double lngSum = 0;

    for (final p in polygon) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    return LatLng(latSum / polygon.length, lngSum / polygon.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Campus Map',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF6D4C41), // Brighter brown
          ),
        ),
        backgroundColor: const Color(0xFFFFFBF5), // Almost white with warm hint
        elevation: 0,
        centerTitle: true,
        actions: [
          // Current location button
          IconButton(
            icon: const Icon(
              Icons.my_location,
              color: Color(0xFFD32F2F), // Red
            ),
            tooltip: 'My Location',
            onPressed: () async {
              await _getCurrentLocation();
              if (currentLocation != null) {
                mapController.animateCamera(
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
      ),
      body: isLoading || styleJson == null
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFFFBF5), // Almost white with warm hint
                    const Color(0xFFFFF8F0), // Very light cream
                    const Color(0xFFFFF3E8), // Subtle warm white
                  ],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFD32F2F), // Red
                ),
              ),
            )
          : Stack(
              children: [
                maplibre.MapLibreMap(
                  styleString: styleJson!,
                  onMapCreated: _onMapCreated,
                  onStyleLoadedCallback: _onStyleLoaded,
                  initialCameraPosition: const maplibre.CameraPosition(
                    target: maplibre.LatLng(14.0683, 100.6034),
                    zoom: 14,
                  ),
                  minMaxZoomPreference: const maplibre.MinMaxZoomPreference(
                    0,
                    24,
                  ),
                  trackCameraPosition: true,
                  scrollGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  myLocationEnabled: !kIsWeb,
                ),
                // Selected building info card
                if (selectedBuildingId != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      elevation: 4,
                      shadowColor: Colors.red.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Colors.white.withOpacity(0.95),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFCDD2).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.location_city,
                                color: Color(0xFFD32F2F),
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
                                    buildings
                                        .firstWhere(
                                          (b) => b.id == selectedBuildingId,
                                        )
                                        .name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(
                                        0xFF3E2723,
                                      ), // Very dark brown
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    buildings
                                        .firstWhere(
                                          (b) => b.id == selectedBuildingId,
                                        )
                                        .type
                                        .displayName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: const Color(
                                        0xFF5D4037,
                                      ).withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Color(0xFF5D4037),
                              ),
                              onPressed: () {
                                setState(() {
                                  selectedBuildingId = null;
                                });
                                _updateSelectedBuilding();
                                selectionService.clear();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
