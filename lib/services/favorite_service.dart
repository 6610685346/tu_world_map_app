import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:tu_world_map_app/models/building.dart';

class FavoriteService extends ChangeNotifier {
  final _log = Logger('FavoriteService');

  static final FavoriteService _instance = FavoriteService._internal();

  factory FavoriteService() => _instance;

  FavoriteService._internal();

  final List<Building> _favorites = [];
  final Map<int, String> _customNames = {};

  void toggle(Building building) {
    if (isFavorite(building)) {
      _favorites.removeWhere((b) => b.id == building.id);
      _customNames.remove(building.id);
      building.isFavorite = false;
    } else {
      _favorites.add(building);
      building.isFavorite = true;
    }
    notifyListeners();
  }

  bool isFavorite(Building building) {
    return _favorites.any((b) => b.id == building.id);
  }

  void remove(Building building) {
    _favorites.removeWhere((b) => b.id == building.id);
    _customNames.remove(building.id);
    building.isFavorite = false;
    notifyListeners();
  }

  List<Building> getFavorites() {
    return List.unmodifiable(_favorites);
  }

  void setCustomName(int buildingId, String name) {
    _customNames[buildingId] = name;
    notifyListeners();
  }

  String getDisplayName(Building building) {
    return _customNames[building.id] ?? building.name;
  }
}
