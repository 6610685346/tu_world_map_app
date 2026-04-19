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
      final decoded = jsonDecode(row['geometry'] as String);

      final coordinates = decoded['coordinates'] as List;
      final polygons = coordinates
          .map<List<LatLng>>(
            (ring) => (ring as List)
                .map<LatLng>(
                  (p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
                )
                .toList(),
          )
          .toList();
      final center = polygons.first.first;

      final buildingTypeStr = (row['building'] as String? ?? '').toLowerCase();

      return Building(
        id: row['id'].toString(),
        name: row['name'] as String? ?? 'Unknown',
        type: BuildingType.values.firstWhere(
          (e) => e.name.toLowerCase() == buildingTypeStr,
          orElse: () => BuildingType.other,
        ),
        imageUrl: row['image'] as String? ?? '',
        polygons: polygons,
        center: center,
      );
    }).toList();

    return _cache!;
  }
}
