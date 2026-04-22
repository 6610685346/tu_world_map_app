import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Singleton service that provides a mock GPS location
/// controllable via a virtual joystick for testing navigation.
class MockLocationService extends ChangeNotifier {
  static final MockLocationService _instance = MockLocationService._internal();

  factory MockLocationService() => _instance;

  MockLocationService._internal();

  /// Whether mock mode is currently active.
  bool _enabled = false;
  bool get enabled => _enabled;

  /// The current mock position.
  LatLng _mockPosition = const LatLng(14.0723, 100.6034); // Campus center default

  LatLng get mockPosition => _mockPosition;

  /// Conversion constants at campus latitude (~14°N)
  /// 1 degree latitude  ≈ 111,320 meters
  /// 1 degree longitude ≈ 107,550 meters (cos(14°) * 111,320)
  static const double _metersPerDegreeLat = 111320.0;
  static const double _metersPerDegreeLng = 107550.0;

  /// Enable mock mode, optionally initializing at a given position.
  void enable({LatLng? initialPosition}) {
    _enabled = true;
    if (initialPosition != null) {
      _mockPosition = initialPosition;
    }
    notifyListeners();
  }

  /// Disable mock mode.
  void disable() {
    _enabled = false;
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
}
