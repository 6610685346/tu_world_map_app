import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();

  factory SettingsService() => _instance;

  SettingsService._internal();

  static const String _autoSaveRecentKey = 'auto_save_recent';
  static const String _firstLaunchKey = 'first_launch';

  bool _autoSaveRecent = true;
  bool _firstLaunch = true;

  bool get autoSaveRecent => _autoSaveRecent;
  bool get firstLaunch => _firstLaunch;

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _autoSaveRecent = prefs.getBool(_autoSaveRecentKey) ?? true;
    _firstLaunch = prefs.getBool(_firstLaunchKey) ?? true;
  }

  Future<void> setAutoSaveRecent(bool value) async {
    _autoSaveRecent = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSaveRecentKey, value);
  }

  Future<void> setFirstLaunchSeen() async {
    _firstLaunch = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, false);
  }
}
