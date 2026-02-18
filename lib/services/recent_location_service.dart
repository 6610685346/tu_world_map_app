import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tu_world_map_app/models/building.dart';

class RecentLocationService {
  static final RecentLocationService _instance =
      RecentLocationService._internal();

  factory RecentLocationService() {
    return _instance;
  }

  RecentLocationService._internal();

  static const String _prefsKey = 'recent_locations';

  final List<Building> _recent = [];

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString != null) {
      final List<dynamic> jsonList = json.decode(jsonString);
      _recent.clear();
      _recent.addAll(jsonList.map((e) => Building.fromJson(e)).toList());
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(_recent.map((b) => b.toJson()).toList());
    await prefs.setString(_prefsKey, jsonString);
  }

  void add(Building building) {
    _recent.removeWhere((b) => b.id == building.id);
    _recent.insert(0, building);

    if (_recent.length > 10) {
      _recent.removeLast();
    }

    _saveToPrefs();
  }

  Future<void> clear() async {
    _recent.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  List<Building> getRecent() {
    return List.unmodifiable(_recent);
  }
}
