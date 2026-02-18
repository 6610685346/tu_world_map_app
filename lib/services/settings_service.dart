import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();

  factory SettingsService() => _instance;

  SettingsService._internal();

  static const String _locationEnabledKey = 'location_enabled';
  static const String _autoSaveRecentKey = 'auto_save_recent';

  bool _locationEnabled = true;
  bool _autoSaveRecent = true;

  bool get locationEnabled => _locationEnabled;
  bool get autoSaveRecent => _autoSaveRecent;

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _locationEnabled = prefs.getBool(_locationEnabledKey) ?? true;
    _autoSaveRecent = prefs.getBool(_autoSaveRecentKey) ?? true;
  }

  Future<void> setLocationEnabled(bool value) async {
    _locationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_locationEnabledKey, value);
  }

  Future<void> setAutoSaveRecent(bool value) async {
    _autoSaveRecent = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSaveRecentKey, value);
  }
}
