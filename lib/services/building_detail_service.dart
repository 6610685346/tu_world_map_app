import 'package:tu_world_map_app/models/building_detail.dart';
import 'package:tu_world_map_app/services/database_service.dart';

class BuildingDetailService {
  Future<BuildingDetail> getDetail(String buildingId) async {
    final db = await DatabaseService.openDB();
    final rows = await db.query('buildings', where: 'id = ?', whereArgs: [int.tryParse(buildingId) ?? buildingId]);

    String time = "Unknown";
    String detail = "No details available";
    String contact = "No contact info";

    if (rows.isNotEmpty) {
      final row = rows.first;
      final dbTime = row['time'] as String?;
      final dbDetail = row['detail'] as String?;
      final dbContact = row['contact'] as String?;

      if (dbTime != null && dbTime.isNotEmpty) time = dbTime;
      if (dbDetail != null && dbDetail.isNotEmpty) detail = dbDetail;
      if (dbContact != null && dbContact.isNotEmpty) contact = dbContact;
    }

    return BuildingDetail(
      buildingId: buildingId,
      time: time,
      detail: detail,
      contact: contact,
    );
  }
}
