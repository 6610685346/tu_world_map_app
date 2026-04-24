import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tu_world_map_app/models/building.dart';

class FavoriteService extends ChangeNotifier {
  static final FavoriteService _instance = FavoriteService._internal();

  factory FavoriteService() => _instance;

  FavoriteService._internal();

  static const String _favoritesKey = 'favorites';

  final List<Building> _favorites = [];

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Load favorites
    final favJson = prefs.getString(_favoritesKey);
    if (favJson != null) {
      final List<dynamic> jsonList = json.decode(favJson);
      _favorites.clear();
      _favorites.addAll(jsonList.map((e) => Building.fromJson(e)).toList());
    }

    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final favJson = json.encode(_favorites.map((b) => b.toJson()).toList());
    await prefs.setString(_favoritesKey, favJson);
  }

  void toggle(Building building) {
    if (isFavorite(building)) {
      _favorites.removeWhere((b) => b.id == building.id);
      building.isFavorite = false;
    } else {
      _favorites.add(building);
      building.isFavorite = true;
    }
    _saveToPrefs();
    notifyListeners();
  }

  bool isFavorite(Building building) {
    return _favorites.any((b) => b.id == building.id);
  }

  void remove(Building building) {
    _favorites.removeWhere((b) => b.id == building.id);
    building.isFavorite = false;
    _saveToPrefs();
    notifyListeners();
  }

  List<Building> getFavorites() {
    return List.unmodifiable(_favorites);
  }

  Future<void> clearAll() async {
    for (final b in _favorites) {
      b.isFavorite = false;
    }
    _favorites.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favoritesKey);
    await prefs.remove('favorite_custom_names');
    notifyListeners();
  }
}
