import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Speed presets for mock GPS joystick movement.
enum MockSpeed {
  walking,
  cycling,
  motorcycle,
}

extension MockSpeedExtension on MockSpeed {
  String get label {
    switch (this) {
      case MockSpeed.walking:
        return 'Walking';
      case MockSpeed.cycling:
        return 'Cycling';
      case MockSpeed.motorcycle:
        return 'Motorcycle';
    }
  }

  IconData get icon {
    switch (this) {
      case MockSpeed.walking:
        return Icons.directions_walk;
      case MockSpeed.cycling:
        return Icons.directions_bike;
      case MockSpeed.motorcycle:
        return Icons.two_wheeler;
    }
  }

  /// Meters per second at full joystick displacement.
  double get metersPerSecond {
    switch (this) {
      case MockSpeed.walking:
        return 1.4; // ~5 km/h
      case MockSpeed.cycling:
        return 4.2; // ~15 km/h
      case MockSpeed.motorcycle:
        return 8.3; // ~30 km/h
    }
  }
}

/// Singleton service that provides a mock GPS location
/// controllable via a virtual joystick for testing navigation.
class MockLocationService extends ChangeNotifier {
  static final MockLocationService _instance = MockLocationService._internal();

  factory MockLocationService() => _instance;

  MockLocationService._internal();

  /// Whether mock mode is currently active.
  bool _enabled = false;
  bool get enabled => _enabled;

  /// Whether mock mode was auto-enabled (user is outside campus).
  bool _autoEnabled = false;
  bool get autoEnabled => _autoEnabled;

  /// Current speed preset.
  MockSpeed _speed = MockSpeed.motorcycle;
  MockSpeed get speed => _speed;

  /// The current mock position.
  LatLng _mockPosition = const LatLng(14.0723, 100.6034); // Campus center default

  LatLng get mockPosition => _mockPosition;

  /// Current heading in degrees (0 = north, 90 = east).
  double _heading = 0;
  double get heading => _heading;

  /// Conversion constants at campus latitude (~14°N)
  static const double _metersPerDegreeLat = 111320.0;
  static const double _metersPerDegreeLng = 107550.0;

  /// Set the speed preset.
  void setSpeed(MockSpeed newSpeed) {
    _speed = newSpeed;
    notifyListeners();
  }

  /// Set heading explicitly (from steering wheel).
  void setHeading(double degrees) {
    _heading = degrees % 360;
    notifyListeners();
  }

  /// Enable mock mode, optionally initializing at a given position.
  void enable({LatLng? initialPosition, bool auto = false}) {
    _enabled = true;
    _autoEnabled = auto;
    if (initialPosition != null) {
      _mockPosition = initialPosition;
    }
    notifyListeners();
  }

  /// Disable mock mode.
  void disable() {
    _enabled = false;
    _autoEnabled = false;
    notifyListeners();
  }

  /// Toggle mock mode on/off.
  void toggle({LatLng? initialPosition}) {
    if (_enabled) {
      disable();
    } else {
      enable(initialPosition: initialPosition);
    }
  }

  /// Move the mock position by [dx] meters (east/west) and [dy] meters (north/south).
  /// Positive dx = east, positive dy = north.
  /// Heading is NOT updated here — it is controlled exclusively by [setHeading]
  /// so that reversing (negative dx/dy) does not flip the facing direction.
  void moveBy(double dx, double dy) {
    if (!_enabled) return;

    final newLat = _mockPosition.latitude + (dy / _metersPerDegreeLat);
    final newLng = _mockPosition.longitude + (dx / _metersPerDegreeLng);

    _mockPosition = LatLng(newLat, newLng);
    notifyListeners();
  }

  /// Jump to a specific position.
  void setPosition(LatLng position) {
    if (!_enabled) return;
    _mockPosition = position;
    notifyListeners();
  }

  /// Meters per tick at full displacement for the current speed.
  /// Joystick ticks at 50ms intervals = 20 ticks/sec.
  /// So metersPerTick = metersPerSecond / 20.
  double get metersPerTick => _speed.metersPerSecond / 20.0;
}
