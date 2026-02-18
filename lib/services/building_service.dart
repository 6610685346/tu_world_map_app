import 'database_service.dart';
import 'package:tu_world_map_app/models/building.dart';
import 'package:latlong2/latlong.dart';


class BuildingWithPolygon {
  final Building building;
  final List<LatLng> polygon;

  BuildingWithPolygon({
    required this.building,
    required this.polygon,
  });
}


class BuildingService {
  Future<List<BuildingWithPolygon>> getAllBuildingsWithPolygons() async {
    final db = await DatabaseService.database;

    // 1. ดึงอาคารทั้งหมด
    final buildingsRaw = await db.query('buildings');

    List<BuildingWithPolygon> result = [];

    for (var buildingMap in buildingsRaw) {
      final building = Building.fromMap(buildingMap);

      // 2. หา polygon ของตึกนี้
      final polygonRaw = await db.query(
        'polygons',
        where: 'building_id = ?',
        whereArgs: [building.id],
      );

      if (polygonRaw.isEmpty) continue;

      final polygonId = polygonRaw.first['id'];

      // 3. ดึง points เรียงตาม point_order
      final pointsRaw = await db.query(
        'polygon_points',
        where: 'polygon_id = ?',
        whereArgs: [polygonId],
        orderBy: 'point_order ASC',
      );

      final points = pointsRaw.map((p) {
        return LatLng(
          p['lat'] as double,
          p['lng'] as double,
        );
      }).toList();

      result.add(
        BuildingWithPolygon(
          building: building,
          polygon: points,
        ),
      );
    }

    return result;
  }
  Future<List<Building>> getBuildings() async {
    final data = await getAllBuildingsWithPolygons();
    return data.map((e) => e.building).toList();
  }

}
