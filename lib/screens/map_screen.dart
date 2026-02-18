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

  // State
  late List<BuildingWithPolygon> buildingsWithPolygon;

  List<LatLng> currentRoute = [];

  Building? selectedBuilding;
  int? selectedBuildingId;
  LatLng? selectedBuildingCenter;
  LatLng? currentLocation;

  bool isLoading = true;

  bool _isInsidePolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;

    for (int i = 0, j = polygon.length - 1;
        i < polygon.length;
        j = i++) {

      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      final intersect =
          ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) *
                      (point.latitude - yi) /
                      (yj - yi) +
                  xi);

      if (intersect) inside = !inside;
    }

    return inside;
  }

  /// =====================
  /// Lifecycle
  /// =====================
  @override
  void initState() {
    super.initState();
    _selectionService.addListener(_onBuildingSelected);
    _loadData();
  }

  Future<void> _loadData() async {
    final service = BuildingService();
    final data = await service.getAllBuildingsWithPolygons();

    setState(() {
      buildingsWithPolygon = data;
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _selectionService.removeListener(_onBuildingSelected);
    super.dispose();
  }

  /// =====================
  /// Building Selection
  /// =====================
  void _onBuildingSelected() {
    final selected = _selectionService.selectedBuilding;
    if (selected == null) return;

    BuildingWithPolygon? item;

    for (final e in buildingsWithPolygon) {
      if (e.building.id == selected.id) {
        item = e;
        break;
      }
    }

if (item == null) return;

    final center = _polygonCentroid(item.polygon);

    setState(() {
      selectedBuilding = selected;
      selectedBuildingId = selected.id;
      selectedBuildingCenter = center;
      currentRoute.clear();
    });

    _mapController.move(center, 18.3);
  }

  /// =====================
  /// Location
  /// =====================
  Future<void> _getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
    });
  }

  /// =====================
  /// Navigation
  /// =====================
  Future<void> navigateToBuilding(Building building) async {
    if (currentLocation == null) return;

  BuildingWithPolygon? item;

  for (final e in buildingsWithPolygon) {
    if (e.building.id == building.id) {
      item = e;
      break;
    }
  }

  if (item == null) return;

    final destination = _getClosestPoint(
      currentLocation!,
      item.polygon,
    );

    final route = await NavigationService().buildRoute(
      start: currentLocation!,
      destination: destination,
    );

    setState(() => currentRoute = route);

    final bounds = LatLngBounds.fromPoints(route);

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  LatLng _getClosestPoint(LatLng start, List<LatLng> polygon) {
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

  LatLng _polygonCentroid(List<LatLng> polygon) {
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
              navigateToBuilding(selectedBuilding!);
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
          options: MapOptions(
            initialCenter: const LatLng(14.0683, 100.6034),
            initialZoom: 16,
            minZoom: 15,
            maxZoom: 19,

            onTap: (tapPosition, latlng) {
              bool found = false;

              for (final item in buildingsWithPolygon) {
                if (_isInsidePolygon(latlng, item.polygon)) {
                  _selectionService.select(item.building);
                  found = true;
                  break;
                }
              }

              if (!found) {
                _selectionService.clear();
              }
            },
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
      polygons: buildingsWithPolygon.expand((item) {
        return [
          Polygon(
            points: item.polygon,
            color: item.building.id == selectedBuildingId
                ? AppColors.primaryRed.withOpacity(0.4)
                : Colors.transparent,
            borderColor: item.building.id == selectedBuildingId
                ? AppColors.darkRed
                : Colors.transparent,
            borderStrokeWidth:
                item.building.id == selectedBuildingId ? 3 : 0,
          ),
        ];
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
    if (selectedBuildingCenter == null) return const SizedBox();

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
              });
              _selectionService.clear();
            },
          ),
        ),
      ),
    );
  }
}
