import 'package:latlong2/latlong.dart';
import 'building_type.dart';

class Building {
  final String id;
  final String name;
  final BuildingType type;
  final String imageUrl;
  bool isFavorite;
  final List<List<LatLng>> polygons;
  final LatLng center;

  Building({
    required this.id,
    required this.name,
    required this.type,
    required this.imageUrl,
    required this.polygons,
    required this.center,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'imageUrl': imageUrl,
      'isFavorite': isFavorite,
      'polygons': polygons
          .map(
            (polygon) => polygon
                .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                .toList(),
          )
          .toList(),
    };
  }

  factory Building.fromJson(Map<String, dynamic> json) {
    final polygons = (json['polygons'] as List)
        .map(
          (polygon) => (polygon as List)
              .map(
                (p) => LatLng(
                  (p['lat'] as num).toDouble(),
                  (p['lng'] as num).toDouble(),
                ),
              )
              .toList(),
        )
        .toList();

    final center = polygons.first.first;

    return Building(
      id: json['id'] as String,
      name: json['name'] as String,
      type: BuildingType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => BuildingType.other,
      ),
      imageUrl: json['imageUrl'] as String,
      isFavorite: json['isFavorite'] as bool? ?? false,
      polygons: polygons,
      center: center,
    );
  }
}
