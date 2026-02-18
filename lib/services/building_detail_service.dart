import 'package:tu_world_map_app/models/building_detail.dart';

class BuildingDetailService {
  Future<BuildingDetail> getDetail(String buildingId) async {
    // simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // MOCK DATA (temporary until real database is connected)
    return BuildingDetail(
      buildingId: buildingId,
      openingTime: "08:00 - 17:00",
      address: "Thammasat University, Rangsit Campus",
      phone: "+66 2 123 4567",
      facebook: "facebook.com/thammasat",
    );
  }
}
