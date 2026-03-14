import 'package:latlong2/latlong.dart';
import 'package:tu_world_map_app/models/building.dart';
import 'package:tu_world_map_app/models/building_type.dart';
import 'package:tu_world_map_app/services/database_service.dart';
import 'dart:convert';

class BuildingService {
  List<Building>? _cache; // ⭐ cache

  Future<List<Building>> getBuildings() async {
    if (_cache != null) return _cache!; // ⭐ return cached data

    final db = await DatabaseService.openDB();
    final rows = await db.query('buildings');

    _cache = rows.map((row) {
      final decoded = jsonDecode(row['polygons'] as String);

      final polygons = (decoded as List)
          .map<List<LatLng>>(
            (poly) =>
                (poly as List).map<LatLng>((p) => LatLng(p[0], p[1])).toList(),
          )
          .toList();
      final center = polygons.first.first;

      return Building(
        id: row['id'] as String,
        name: row['name'] as String,
        type: BuildingType.values.firstWhere((e) => e.name == row['type']),
        imageUrl: row['imageUrl'] as String,
        polygons: polygons,
        center: center,
      );
    }).toList();

    return _cache!;
  }
}
