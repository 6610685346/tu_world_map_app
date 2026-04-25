import 'package:flutter/material.dart';
import 'package:tu_world_map_app/models/building.dart';

class MapSelectionService extends ChangeNotifier {
  static final MapSelectionService _instance = MapSelectionService._internal();

  factory MapSelectionService() {
    return _instance;
  }

  MapSelectionService._internal();

  Building? selectedBuilding;

  /// Tracks whether the Map tab is currently active in the navigation bar.
  bool _isMapTabActive = false;
  bool get isMapTabActive => _isMapTabActive;

  void select(Building building) {
    selectedBuilding = building;
    notifyListeners();
  }

  void clear() {
    selectedBuilding = null;
    notifyListeners();
  }

  /// Updates whether the map tab is active.
  void setMapTabActive(bool active) {
    if (_isMapTabActive != active) {
      _isMapTabActive = active;
      notifyListeners();
    }
  }
}
