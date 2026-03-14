import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

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
  // Controllers & Services
  final MapController _mapController = MapController();
  final BuildingService _buildingService = BuildingService();
  final MapSelectionService _selectionService = MapSelectionService();
  final NavigationService _navigationService = NavigationService();

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

  StreamSubscription<Position>? _positionStream;

  /// =====================
  /// Lifecycle
  /// =====================
  @override
  void initState() {
    super.initState();

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

    _mapController.move(center, 18.3);
  }

  /// =====================
  /// Load Data
  /// =====================
  Future<void> _loadBuildings() async {
    final data = await _buildingService.getBuildings();

    setState(() {
      buildings = data;
      isLoading = false;
    });
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
      print("NO ROUTE FOUND map screen");
      return;
    }

    setState(() {
      currentRoute = route;
      _lastRouteStart = currentLocation;
    });

    final bounds = LatLngBounds.fromPoints(route);

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  /// =====================
  /// Realtime navigation update (while walking)
  /// =====================

  Future<void> updateRouteWhileWalking() async {
    if (currentLocation == null) return;
    if (routingDestination == null) return;
    if (_isRouting) return;

    if (_lastRouteStart != null) {
      final moved = Distance().as(
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
        print("Realtime route failed — keeping old route");
        return;
      }

      setState(() {
        currentRoute = newRoute;
        _lastRouteStart = currentLocation;
      });
    } finally {
      _isRouting = false;
    }
  }

  /// =====================
  /// Geometry Helpers
  /// =====================

  LatLng getClosestPoint(LatLng start, List<LatLng> polygon) {
    double minDistance = double.infinity;
    LatLng closest = polygon.first;

    for (final point in polygon) {
      final distance = Distance().as(LengthUnit.Meter, start, point);

      if (distance < minDistance) {
        minDistance = distance;
        closest = point;
      }
    }

    return closest;
  }

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
      body: isLoading ? _buildLoading() : _buildMap(),
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
      ],
    );
  }

  /// ---------------------
  /// Loading UI
  /// ---------------------
  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primaryRed),
    );
  }

  /// ---------------------
  /// Map UI
  /// ---------------------
  Widget _buildMap() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(14.0683, 100.6034),
            initialZoom: 16,
            minZoom: 15,
            maxZoom: 19,
          ),
          children: [
            _buildTileLayer(),
            _buildPolygonLayer(),
            _buildRouteLayer(),
            _buildCurrentLocationMarker(),
            _buildSelectedBuildingMarker(),
            _buildAttribution(),
          ],
        ),
        if (selectedBuilding != null) _buildSelectedCard(),
      ],
    );
  }

  TileLayer _buildTileLayer() {
    return TileLayer(
      urlTemplate:
          'https://api.maptiler.com/maps/openstreetmap/256/{z}/{x}/{y}.jpg?key=pKEb1AjUUNqlSI9aLaO5',
      userAgentPackageName: 'com.example.tu_world_map_app',
    );
  }

  PolygonLayer _buildPolygonLayer() {
    return PolygonLayer(
      polygons: buildings.expand((building) {
        return building.polygons.map(
          (polygon) => Polygon(
            points: polygon,
            color: building.id == selectedBuildingId
                ? AppColors.primaryRed.withOpacity(0.4)
                : Colors.transparent,
            borderColor: building.id == selectedBuildingId
                ? AppColors.darkRed
                : Colors.transparent,
            borderStrokeWidth: building.id == selectedBuildingId ? 3 : 0,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRouteLayer() {
    if (currentRoute.isEmpty) return const SizedBox();

    return PolylineLayer(
      polylines: [
        Polyline(
          points: currentRoute,
          strokeWidth: 5,
          color: AppColors.primaryRed,
        ),
      ],
    );
  }

  Widget _buildCurrentLocationMarker() {
    if (currentLocation == null) return const SizedBox();

    return MarkerLayer(
      markers: [
        Marker(
          point: currentLocation!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.my_location,
            color: AppColors.primaryRed,
            size: 30,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedBuildingMarker() {
    if (selectedBuildingCenter == null) {
      return const SizedBox();
    }

    return MarkerLayer(
      markers: [
        Marker(
          point: selectedBuildingCenter!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.location_on,
            color: AppColors.darkRed,
            size: 36,
          ),
        ),
      ],
    );
  }

  Widget _buildAttribution() {
    return const RichAttributionWidget(
      alignment: AttributionAlignment.bottomRight,
      attributions: [
        TextSourceAttribution('© MapTiler © OpenStreetMap contributors'),
      ],
    );
  }

  Widget _buildSelectedCard() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          title: Text(
            selectedBuilding!.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(selectedBuilding!.type.displayName),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                selectedBuilding = null;
                selectedBuildingId = null;
                selectedBuildingCenter = null;
                currentRoute.clear();
                _lastRouteStart = null;
                routingDestination = null;
              });
              _selectionService.clear();
            },
          ),
        ),
      ),
    );
  }
}
