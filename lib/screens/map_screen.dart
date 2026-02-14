import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logging/logging.dart';

import 'package:tu_world_map_app/models/building.dart';
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
        'assets/styles/simple_shortbread.json',
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
    _log.info('✅ MapLibre controller created');
  }

  Future<void> _onStyleLoaded() async {
    try {
      _log.info('🗺️ Map style loaded callback triggered');

      if (buildings.isEmpty) {
        _log.info('📦 Loading buildings from service...');
        await _loadBuildings();
      }

      if (buildings.isNotEmpty) {
        _log.info(
          '🎯 Adding building source to map (${buildings.length} buildings)...',
        );
        await _addBuildingSource();
        _log.info('✅ Buildings successfully added to map');
      } else {
        _log.warning('⚠️ No buildings to add');
      }
    } catch (e, stackTrace) {
      _log.severe('❌ Error in _onStyleLoaded', e, stackTrace);
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

      /// Add source (use app-scoped id to avoid colliding with style-defined layers)
      const String sourceId = 'app-buildings';
      const String fillLayerId = 'app-buildings-fill';
      const String strokeLayerId = 'app-buildings-stroke';

      await mapController.addSource(
        sourceId,
        maplibre.GeojsonSourceProperties(data: geoJson),
      );

      /// Add fill layer (use CSS color strings; opacity is controlled by `fillOpacity`)
      await mapController.addLayer(
        sourceId,
        fillLayerId,
        maplibre.FillLayerProperties(fillColor: '#1f78b4', fillOpacity: 0.3),
      );

      /// Add stroke layer
      await mapController.addLayer(
        sourceId,
        strokeLayerId,
        maplibre.LineLayerProperties(lineColor: '#1f78b4', lineWidth: 2),
      );
    } catch (e, stackTrace) {
      _log.severe('Error adding building source', e, stackTrace);
      rethrow;
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
      appBar: AppBar(title: const Text('Campus Map')),
      body: isLoading || styleJson == null
          ? const Center(child: CircularProgressIndicator())
          : maplibre.MapLibreMap(
              styleString: styleJson!,
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: _onStyleLoaded,
              initialCameraPosition: const maplibre.CameraPosition(
                target: maplibre.LatLng(14.0683, 100.6034),
                zoom: 14,
              ),
              minMaxZoomPreference: const maplibre.MinMaxZoomPreference(0, 24),
              trackCameraPosition: true,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              tiltGesturesEnabled: true,
              rotateGesturesEnabled: true,
              myLocationEnabled: !kIsWeb,
            ),
    );
  }
}
