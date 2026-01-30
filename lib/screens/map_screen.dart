import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/map_location.dart';
import '../services/search_service.dart';
import '../services/navigation_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> results = [];
  LatLng? userLocation;
  LatLng? destination;

  String? selectedBuildingId;

  late NavigationService navigationService;

  @override
  void initState() {
    super.initState();
    results = buildings;

    navigationService = NavigationService(
      onLocationUpdate: (loc) {
        setState(() {
          userLocation = loc;
        });
      },
    );

    navigationService.startTracking();
  }

  @override
  void dispose() {
    navigationService.stopTracking();
    super.dispose();
  }

  LatLng _calculateCentroid(List<LatLng> points) {
    double lat = 0, lng = 0;
    for (final p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  void _onSearchChanged(String value) {
    setState(() {
      results = SearchService.search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.refresh),
        onPressed: () {
          setState(() {
            destination = null;
            selectedBuildingId = null;
          });
        },
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: LatLng(14.0683, 100.6034),
              initialZoom: 16,
            ),
            children: [
              /// 🗺 Base map
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                maxZoom: 20,
                userAgentPackageName: 'com.example.app',
              ),

              /// 🏷 Labels (CARTO)
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_labels_under/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                maxZoom: 20,
                userAgentPackageName: 'com.example.app',
              ),

              /// 📜 Attribution
              RichAttributionWidget(
                attributions: const [
                  TextSourceAttribution(
                    '© OpenStreetMap contributors © CARTO',
                  ),
                ],
              ),

              /// 🟧 Polygon (เฉพาะที่เลือก)
              if (selectedBuildingId != null)
                PolygonLayer(
                  polygons: buildings
                      .where((b) => b['id'] == selectedBuildingId)
                      .expand((b) {
                    return (b['polygons'] as List<List<LatLng>>).map(
                      (p) => Polygon(
                        points: p,
                        isFilled: true,
                        color: Colors.orange.withOpacity(0.45),
                        borderColor: Colors.orange,
                        borderStrokeWidth: 3,
                      ),
                    );
                  }).toList(),
                ),

              /// 📍 User marker
              if (userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                  ],
                ),

              /// 🎯 Destination marker + label (ไม่ชนกัน)
              if (destination != null)
                MarkerLayer(
                  markers: [
                    /// pin
                    Marker(
                      point: destination!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),

                    /// label (ขยับขึ้น)
                    Marker(
                      point: destination!,
                      width: 150,
                      height: 50,
                      child: Transform.translate(
                        offset: const Offset(0, -45),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            buildings.firstWhere(
                                (b) => b['id'] == selectedBuildingId)['name'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              /// 🧭 Route
              if (userLocation != null && destination != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: navigationService.buildRoute(
                          userLocation!, destination!),
                      strokeWidth: 4,
                      color: Colors.blue,
                    ),
                  ],
                ),
            ],
          ),

          /// 🔍 Search UI
          Positioned(
            top: 40,
            left: 15,
            right: 15,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: searchController,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search building...',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),

                if (searchController.text.isNotEmpty)
                  Container(
                    height: 200,
                    color: Colors.white,
                    child: ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final b = results[i];
                        return ListTile(
                          title: Text(b['name']),
                          subtitle: Text(b['description']),
                          onTap: () {
                            final dest =
                                _calculateCentroid(b['polygons'].first);

                            setState(() {
                              destination = dest;
                              selectedBuildingId = b['id'];
                              searchController.clear();
                            });

                            mapController.move(dest, 18);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

