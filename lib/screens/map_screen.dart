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

  final List<Map<String, dynamic>> buildings = [
    {
      'id': 'ENG',
      'name': 'Engineering Building',
      'polygon': [
        LatLng(14.06820, 100.60320),
        LatLng(14.06820, 100.60360),
        LatLng(14.06850, 100.60360),
        LatLng(14.06850, 100.60320),
      ],
    },
    {
      'id': 'LIB',
      'name': 'Library',
      'polygon': [
        LatLng(14.06740, 100.60400),
        LatLng(14.06740, 100.60440),
        LatLng(14.06770, 100.60440),
        LatLng(14.06770, 100.60400),
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

          // 👆 Handle tap HERE
          onTap: (tapPosition, point) {
            for (final building in buildings) {
              if (_pointInsidePolygon(point, building['polygon'])) {
                setState(() {
                  selectedBuildingId = building['id'];
                });

                mapController.fitBounds(
                  LatLngBounds.fromPoints(building['polygon']),
                  options: const FitBoundsOptions(padding: EdgeInsets.all(40)),
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

                break;
              }
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.tu_world_map_app',
          ),

          // 🟧 Building overlays
          PolygonLayer(
            polygons: buildings.map((building) {
              final isSelected = selectedBuildingId == building['id'];

              return Polygon(
                points: building['polygon'],
                color: isSelected
                    ? Colors.orange.withOpacity(0.3)
                    : Colors.transparent,
                borderColor: isSelected ? Colors.orange : Colors.grey,
                borderStrokeWidth: isSelected ? 3 : 1,
                isFilled: true,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 🔍 Simple point-in-rectangle check (FAST & OK for squares)
  bool _pointInsidePolygon(LatLng point, List<LatLng> polygon) {
    final lats = polygon.map((p) => p.latitude);
    final lngs = polygon.map((p) => p.longitude);

    return point.latitude >= lats.reduce((a, b) => a < b ? a : b) &&
        point.latitude <= lats.reduce((a, b) => a > b ? a : b) &&
        point.longitude >= lngs.reduce((a, b) => a < b ? a : b) &&
        point.longitude <= lngs.reduce((a, b) => a > b ? a : b);
  }
}
