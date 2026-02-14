import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/building.dart';
import '../services/building_service.dart';
import '../services/map_selection_service.dart';
import '../models/building.dart';
import '../services/navigation_service.dart';
import 'package:geolocator/geolocator.dart';

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
    print("NAVIGATION STARTED 🚀");

    if (currentLocation == null) {
      print("Current location not available yet.");
      return;
    }
    final destination = _getClosestPoint(
      currentLocation!,
      building.polygons.first,
    );

    print("BUILDING NAME: ${building.name}");
    print("DESTINATION: $destination");
    print("START: $currentLocation");

    final route = await NavigationService().buildRoute(
      start: currentLocation!, // 🔵 real GPS
      destination: destination,
    );

    print("ROUTE POINTS COUNT: ${route.length}");
    print("LAST ROUTE POINT: ${route.last}");

    setState(() {
      currentRoute = route;
    });

    final bounds = LatLngBounds.fromPoints(route);

    mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    print("GPS FUNCTION CALLED 🔵🔵🔵");

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services disabled.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Location permission denied");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print("Location permanently denied");
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
    });

    print("Current Location: $currentLocation");
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
      appBar: AppBar(
        title: const Text('Campus Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions),
            onPressed: () {
              if (buildings.isNotEmpty) {
                if (selectedBuilding != null) {
                  navigateToBuilding(selectedBuilding!);
                }
              }
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: const LatLng(14.0683, 100.6034),
                initialZoom: 16,
                minZoom: 15,
                maxZoom: 19,

                onPositionChanged: (position, hasGesture) {
                  print("Current Zoom: ${position.zoom}");
                },

                /// 🔒 Restrict camera to campus
                cameraConstraint: CameraConstraint.contain(
                  bounds: LatLngBounds(
                    LatLng(14.00, 100.55),
                    LatLng(14.10, 100.65),
                  ),
                ),
              ),
              children: [
                /// 🗺️ MapTiler base map
                TileLayer(
                  urlTemplate:
                      'https://api.maptiler.com/maps/openstreetmap/256/{z}/{x}/{y}.jpg?key=pKEb1AjUUNqlSI9aLaO5',
                  userAgentPackageName: 'com.example.tu_world_map_app',
                ),

                /// 🟧 Building polygons
                PolygonLayer(
                  polygons: buildings.expand((building) {
                    final isSelected = building.id == selectedBuildingId;
                    return building.polygons.map(
                      (polygon) => Polygon(
                        points: polygon,
                        isFilled: true,
                        color: building.id == selectedBuildingId
                            ? Colors.blue.withOpacity(0.6) // selected
                            : Colors.transparent,
                        borderColor: building.id == selectedBuildingId
                            ? Colors.blue
                            : Colors.transparent,
                        borderStrokeWidth: building.id == selectedBuildingId
                            ? 3
                            : 0,
                      ),
                    );
                  }).toList(),
                ),

                /// 🔵 Navigation Route
                if (currentRoute.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: currentRoute,
                        strokeWidth: 5,
                        color: Colors.blue,
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
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),
                    ],
                  ),

                /// ✅ Required attribution (correct placement)
                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomRight,
                  attributions: const [
                    TextSourceAttribution(
                      '© MapTiler © OpenStreetMap contributors',
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  /// 🎯 Point-in-polygon detection
  bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersections = 0;

    for (int i = 0; i < polygon.length - 1; i++) {
      final a = polygon[i];
      final b = polygon[i + 1];

      if ((a.latitude > point.latitude) != (b.latitude > point.latitude)) {
        final intersectLng =
            (b.longitude - a.longitude) *
                (point.latitude - a.latitude) /
                (b.latitude - a.latitude) +
            a.longitude;

        if (point.longitude < intersectLng) {
          intersections++;
        }
      }
    }
    return intersections.isOdd;
  }

  /// 📐 Polygon centroid
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
