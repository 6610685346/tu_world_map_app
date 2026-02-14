import 'package:tu_world_map_app/utils/buildingsList.dart';
import 'package:tu_world_map_app/models/building.dart';

class BuildingService {
  Future<List<Building>> getBuildings() async {
    await Future.delayed(const Duration(seconds: 1));
    return buildingsList;
  }
}
