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
  List<LatLng> routePoints = [];

  String? selectedBuildingId;
  RouteMode routeMode = RouteMode.walk;

  late NavigationService navigationService;

  @override
  void initState() {
    super.initState();
    results = buildings;

    navigationService = NavigationService(
      onLocationUpdate: (loc) => setState(() => userLocation = loc),
    );

    navigationService.startTracking().catchError((e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    });
  }

  @override
  void dispose() {
    navigationService.stopTracking();
    super.dispose();
  }

  LatLng _centroid(List<LatLng> pts) {
    double lat = 0, lng = 0;
    for (final p in pts) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / pts.length, lng / pts.length);
  }

  void _onSearchChanged(String v) {
    setState(() => results = SearchService.search(v));
  }

  Future<void> _selectBuilding(Map<String, dynamic> b) async {
    final dest = _centroid(b['polygons'].first);

    final route = (userLocation == null)
        ? <LatLng>[]
        : await navigationService.getRoute(
            userLocation!, dest, routeMode);

    setState(() {
      destination = dest;
      selectedBuildingId = b['id'];
      routePoints = route;
      searchController.clear();
    });

    mapController.move(dest, 18);
  }

  Widget _modeButton(String text, RouteMode mode) {
    final active = routeMode == mode;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? Colors.blue : Colors.grey,
      ),
      onPressed: () async {
        routeMode = mode;
        if (userLocation != null && destination != null) {
          routePoints = await navigationService.getRoute(
              userLocation!, destination!, routeMode);
          setState(() {});
        }
      },
      child: Text(text),
    );
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
            routePoints = [];
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
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.app',
              ),
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_labels_under/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              if (selectedBuildingId != null)
                PolygonLayer(
                  polygons: buildings
                      .where((b) => b['id'] == selectedBuildingId)
                      .expand((b) => (b['polygons'] as List<List<LatLng>>).map(
                            (p) => Polygon(
                              points: p,
                              isFilled: true,
                              color: Colors.orange.withOpacity(0.4),
                              borderColor: Colors.orange,
                              borderStrokeWidth: 3,
                            ),
                          ))
                      .toList(),
                ),
              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 4,
                      color: Colors.blue,
                    ),
                  ],
                ),
              if (userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.person_pin_circle,
                          color: Colors.blue, size: 40),
                    ),
                  ],
                ),
              if (destination != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: destination!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_pin,
                          color: Colors.red, size: 40),
                    ),
                    Marker(
                      point: destination!,
                      width: 150,
                      height: 50,
                      child: Transform.translate(
                        offset: const Offset(0, -45),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4)
                            ],
                          ),
                          child: Text(
                            buildings.firstWhere(
                                (b) => b['id'] == selectedBuildingId)['name'],
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          /// 🔍 Search
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
                      hintText: 'Search...',
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
                      itemBuilder: (_, i) {
                        final b = results[i];
                        return ListTile(
                          title: Text(b['name']),
                          subtitle: Text(b['description']),
                          onTap: () => _selectBuilding(b),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          /// 🚦 Mode
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _modeButton('เดิน', RouteMode.walk),
                _modeButton('ซอย', RouteMode.bike),
                _modeButton('รถ', RouteMode.car),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

