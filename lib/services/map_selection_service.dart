import '../models/building.dart';

class MapSelectionService {
  static final MapSelectionService _instance = MapSelectionService._internal();

  factory MapSelectionService() {
    return _instance;
  }

  MapSelectionService._internal();

  Building? selectedBuilding;

  void select(Building building) {
    selectedBuilding = building;
  }

  void clear() {
    selectedBuilding = null;
  }
}
