import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/building.dart';
import '../services/building_service.dart';
import '../services/map_selection_service.dart';
import '../models/building.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();
  String? selectedBuildingId;
  final BuildingService buildingService = BuildingService();
  List<Building> buildings = [];
  bool isLoading = true;
  final MapSelectionService selectionService = MapSelectionService();

  @override
  void initState() {
    super.initState();
    _loadBuildings();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSelectionLoop();
    });
  }

  void _checkSelectionLoop() {
    final selected = selectionService.selectedBuilding;

    if (selected != null && buildings.isNotEmpty) {
      mapController.fitBounds(
        LatLngBounds.fromPoints(selected.polygons.first),
        options: const FitBoundsOptions(padding: EdgeInsets.all(40)),
      );

      selectionService.clear();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSelectionLoop();
    });
  }

  Future<void> _loadBuildings() async {
    final data = await buildingService.getBuildings();
    setState(() {
      buildings = data;
      isLoading = false;
    });
  }

  /// 🔒 University campus bounds
  final LatLngBounds campusBounds = LatLngBounds(
    LatLng(14.0645, 100.5995), // Southwest
    LatLng(14.0725, 100.6090), // Northeast
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Map')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: const LatLng(14.0683, 100.6034),
                initialZoom: 16,
                minZoom: 15,
                maxZoom: 19,

                /// 🔒 Restrict camera to campus
                cameraConstraint: CameraConstraint.contain(
                  bounds: campusBounds,
                ),

                /// 👆 Tap detection
                onTap: (tapPosition, point) {
                  for (final building in buildings) {
                    for (final polygon in building.polygons) {
                      if (_pointInPolygon(point, polygon)) {
                        setState(() {
                          selectedBuildingId = building.id;
                        });

                        mapController.fitBounds(
                          LatLngBounds.fromPoints(polygon),
                          options: const FitBoundsOptions(
                            padding: EdgeInsets.all(40),
                          ),
                        );

                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text(building.name),
                            content: const Text('Selected building'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                        return;
                      }
                    }
                  }
                },
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
                    return (building.polygons as List<List<LatLng>>).map(
                      (polygon) => Polygon(
                        points: polygon,
                        isFilled: true,
                        color: Colors.orange.withOpacity(0.35),
                        borderColor: Colors.orange,
                        borderStrokeWidth: 2,
                      ),
                    );
                  }).toList(),
                ),

                /// 📍 GYM 6 center marker
                MarkerLayer(
                  markers: buildings.where((b) => b.id == 'GYM6').expand((
                    building,
                  ) {
                    return (building.polygons as List<List<LatLng>>).map((
                      polygon,
                    ) {
                      final center = _polygonCentroid(polygon);
                      return Marker(
                        point: center,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      );
                    });
                  }).toList(),
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
