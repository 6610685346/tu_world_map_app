import 'package:latlong2/latlong.dart';

class Building {
  final String id;
  final String name;
  final String type; // NEW
  final String imageUrl; // NEW
  bool isFavorite; // NEW (mutable)
  final List<List<LatLng>> polygons;

  Building({
    required this.id,
    required this.name,
    required this.type,
    required this.imageUrl,
    required this.polygons,
    this.isFavorite = false,
  });
}
