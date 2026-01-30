import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLibreMapController? controller;
  String? selectedBuildingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Map')),
      body: MapLibreMap(
        styleString: "https://demotiles.maplibre.org/style.json",
        initialCameraPosition: const CameraPosition(
          target: LatLng(14.0683, 100.6034), // TU Rangsit
          zoom: 16,
        ),
        onMapCreated: (c) {
          controller = c;
          _addBuildings();
        },
        onMapClick: (point, latLng) async {
          final features = await controller!.queryRenderedFeatures(
            point,
            [],
            null,
          );

          if (features.isNotEmpty) {
            setState(() {
              selectedBuildingId = features.first['properties']['id'];
            });
            _updateHighlight();
          }
        },
      ),
    );
  }

  /// Add building polygons
  Future<void> _addBuildings() async {
    await controller!.addSource(
      "buildings",
      GeojsonSourceProperties(
        data: {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "properties": {"id": "ENG", "name": "Engineering Building"},
              "geometry": {
                "type": "Polygon",
                "coordinates": [
                  [
                    [100.6032, 14.0681],
                    [100.6035, 14.0681],
                    [100.6035, 14.0684],
                    [100.6032, 14.0684],
                    [100.6032, 14.0681],
                  ],
                ],
              },
            },
          ],
        },
      ),
    );

    await controller!.addFillLayer(
      "buildings",
      "building-fill",
      FillLayerProperties(
        fillColor: [
          "case",
          [
            "==",
            ["get", "id"],
            selectedBuildingId,
          ],
          "#f44336",
          "#cccccc",
        ],
        fillOpacity: [
          "case",
          [
            "==",
            ["get", "id"],
            selectedBuildingId,
          ],
          0.7,
          0.3,
        ],
      ),
    );

    await controller!.addLineLayer(
      "buildings",
      "building-outline",
      LineLayerProperties(lineColor: "#d32f2f", lineWidth: 3),
    );
  }

  /// Update highlight dynamically
  Future<void> _updateHighlight() async {
    await controller!.setPaintProperty("building-fill", "fill-color", [
      "case",
      [
        "==",
        ["get", "id"],
        selectedBuildingId,
      ],
      "#f44336",
      "#cccccc",
    ]);
  }
}
