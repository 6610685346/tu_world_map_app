import 'package:flutter/material.dart';
import '../models/building.dart';

class MapSelectionService extends ChangeNotifier {
  static final MapSelectionService _instance = MapSelectionService._internal();

  factory MapSelectionService() {
    return _instance;
  }

  MapSelectionService._internal();

  Building? selectedBuilding;

  void select(Building building) {
    selectedBuilding = building;
    notifyListeners();
  }

  void clear() {
    selectedBuilding = null;
    notifyListeners();
  }
}
