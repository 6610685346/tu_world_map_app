import 'package:latlong2/latlong.dart';
import 'building_type.dart';

class Building {
  final String id;
  final String name;
  final BuildingType type; //
  final String imageUrl;
  bool isFavorite;
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
