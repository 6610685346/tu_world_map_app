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

class AppColors {
  static const primaryRed = Color(0xFFD32F2F);
  static const darkRed = Color(0xFFB71C1C);
  static const cream = Color(0xFFFFFBF5);
  static const brown = Color(0xFF6D4C41);
  static const darkBrown = Color(0xFF3E2723);
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();
  final BuildingService buildingService = BuildingService();
  final MapSelectionService selectionService = MapSelectionService();

  List<Building> buildings = [];
  List<LatLng> currentRoute = [];
  String? selectedBuildingId;
  Building? selectedBuilding;
  bool isLoading = true;
  LatLng? currentLocation;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
    _getCurrentLocation();

    selectionService.clear();
    selectionService.addListener(_onBuildingSelected);
  }

  void _onBuildingSelected() {
    final selected = selectionService.selectedBuilding;
    if (selected == null || buildings.isEmpty) return;

    final polygon = selected.polygons.first;
    final center = _polygonCentroid(polygon);

    setState(() {
      selectedBuildingId = selected.id;
      selectedBuilding = selected;
    });

    mapController.move(center, 18.33);
  }

  @override
  void dispose() {
    selectionService.removeListener(_onBuildingSelected);
    super.dispose();
  }

  Future<void> _loadBuildings() async {
    final data = await buildingService.getBuildings();
    setState(() {
      buildings = data;
      isLoading = false;
    });
  }

  Future<void> navigateToBuilding(Building building) async {
    if (currentLocation == null) return;

    final destination = _getClosestPoint(
      currentLocation!,
      building.polygons.first,
    );

    final route = await NavigationService().buildRoute(
      start: currentLocation!,
      destination: destination,
    );

    setState(() {
      currentRoute = route;
    });

    final bounds = LatLngBounds.fromPoints(route);

    mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  Future<void> _getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
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
      ),
      body: isLoading
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.cream,
                    Color(0xFFFFF8F0),
                    Color(0xFFFFF3E8),
                  ],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primaryRed),
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(14.0683, 100.6034),
                    initialZoom: 16,
                    minZoom: 15,
                    maxZoom: 19,
                    cameraConstraint: CameraConstraint.contain(
                      bounds: LatLngBounds(
                        const LatLng(14.00, 100.55),
                        const LatLng(14.10, 100.65),
                      ),
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://api.maptiler.com/maps/openstreetmap/256/{z}/{x}/{y}.jpg?key=pKEb1AjUUNqlSI9aLaO5',
                      userAgentPackageName: 'com.example.tu_world_map_app',
                    ),

                    PolygonLayer(
                      polygons: buildings.expand((building) {
                        return building.polygons.map(
                          (polygon) => Polygon(
                            points: polygon,
                            isFilled: true,
                            color: building.id == selectedBuildingId
                                ? AppColors.primaryRed.withOpacity(0.4)
                                : Colors.transparent,
                            borderColor: building.id == selectedBuildingId
                                ? AppColors.darkRed
                                : Colors.transparent,
                            borderStrokeWidth: building.id == selectedBuildingId
                                ? 3
                                : 0,
                          ),
                        );
                      }).toList(),
                    ),

                    if (currentRoute.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: currentRoute,
                            strokeWidth: 5,
                            color: AppColors.primaryRed,
                          ),
                        ],
                      ),

                    if (currentLocation != null)
                      MarkerLayer(
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
                      ),

                    const RichAttributionWidget(
                      alignment: AttributionAlignment.bottomRight,
                      attributions: [
                        TextSourceAttribution(
                          '© MapTiler © OpenStreetMap contributors',
                        ),
                      ],
                    ),
                  ],
                ),

                if (selectedBuilding != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      elevation: 4,
                      shadowColor: AppColors.primaryRed.withOpacity(0.3),
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
                                color: AppColors.primaryRed.withOpacity(0.1),
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
                                      color: AppColors.brown.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: AppColors.brown,
                              ),
                              onPressed: () {
                                setState(() {
                                  selectedBuildingId = null;
                                  selectedBuilding = null;
                                });
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

  LatLng _polygonCentroid(List<LatLng> polygon) {
    double latSum = 0;
    double lngSum = 0;

    for (final p in polygon) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    return LatLng(latSum / polygon.length, lngSum / polygon.length);
  }
}
