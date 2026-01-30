import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();

  String? selectedBuildingId;

  /// 🔷 Buildings (supports MULTIPLE polygons)
  final List<Map<String, dynamic>> buildings = [
    {
      'id': 'ENG',
      'name': 'Engineering Building',
      'polygons': [
        [
          LatLng(14.06820, 100.60320),
          LatLng(14.06820, 100.60360),
          LatLng(14.06850, 100.60360),
          LatLng(14.06850, 100.60320),
        ],
      ],
    },

    /// 🏟️ GYM 6
    {
      'id': 'GYM6',
      'name': 'Gym 6',
      'polygons': [
        [
          LatLng(14.06732934062687, 100.60422284413761),
          LatLng(14.06726860316219, 100.6042196330992),
          LatLng(14.067106636511511, 100.60401733771084),
          LatLng(14.067041226869136, 100.60401412667414),
          LatLng(14.06677958811592, 100.60430633112355),
          LatLng(14.066737539002276, 100.60441550641275),
          LatLng(14.066729752128452, 100.60457284727158),
          LatLng(14.066762456996102, 100.60467560048409),
          LatLng(14.066726637379361, 100.60467560048409),
          LatLng(14.066723522629374, 100.60482009719135),
          LatLng(14.066876145309465, 100.60481206959639),
          LatLng(14.067031882633543, 100.6049517497454),
          LatLng(14.067087948043692, 100.6049517497454),
          LatLng(14.067316881661228, 100.60473982124199),
          LatLng(14.067369832261079, 100.60460014109299),
          LatLng(14.067374504372012, 100.60447009405726),
          LatLng(14.067354258556236, 100.60438339603292),
          LatLng(14.067332455368643, 100.60433201942675),
          LatLng(14.06732934062687, 100.60422284413761),
        ],
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Map')),
      body: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: LatLng(14.0683, 100.6034),
          initialZoom: 16,

          /// 👆 TAP detection
          onTap: (tapPosition, point) {
            for (final building in buildings) {
              for (final polygon in building['polygons']) {
                if (_pointInPolygon(point, polygon)) {
                  setState(() {
                    selectedBuildingId = building['id'];
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
                      title: Text(building['name']),
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
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.tu_world_map_app',
          ),

          /// 🟧 Building overlays
          PolygonLayer(
            polygons: buildings.expand((building) {
              return (building['polygons'] as List<List<LatLng>>).map(
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

          /// 📍 GYM 6 CENTER MARKER
          MarkerLayer(
            markers: buildings.where((b) => b['id'] == 'GYM6').expand((
              building,
            ) {
              return (building['polygons'] as List<List<LatLng>>).map((
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
        ],
      ),
    );
  }

  /// 🎯 REAL point-in-polygon
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

  /// 📐 Polygon centroid (for marker placement)
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
