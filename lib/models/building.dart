import 'package:latlong2/latlong.dart';
import 'building_type.dart';

class Building {
  final int id;
  final String name;
  final BuildingType type;
  final String imageUrl;
  bool isFavorite;

  Building({
    required this.id,
    required this.name,
    required this.type,
    required this.imageUrl,
    this.isFavorite = false,
  });

  factory Building.fromMap(Map<String, dynamic> map) {
    return Building(
      id: map['id'] as int,
      name: map['name'] as String,
      type: BuildingType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => BuildingType.other,
      ),
      imageUrl: map['image_url'] as String? ?? '',
    );
  }
}

