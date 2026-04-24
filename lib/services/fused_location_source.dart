import 'dart:async';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// A location event emitted by [FusedLocationSource]. Combines GPS
/// ground-truth with step-based dead reckoning for smoother updates
/// between GPS fixes.
class SmoothedLocation {
  final LatLng position;
  final double headingDeg;
  final double? accuracyMeters;
  final DateTime timestamp;

  const SmoothedLocation({
    required this.position,
    required this.headingDeg,
    required this.accuracyMeters,
    required this.timestamp,
  });
}

/// Pedestrian dead reckoning (PDR) fused with GPS.
///
/// Subscribes to the device accelerometer for step detection and the
/// gyroscope for heading updates between GPS fixes. On each GPS fix,
/// a complementary filter blends the GPS position with the PDR estimate
/// (weight driven by the fix's reported accuracy).
///
/// This class is intentionally scoped to *walk* mode only. Bike/car
/// routing should bypass it — wheel motion produces bogus step events
/// and GPS is adequate at those speeds.
class FusedLocationSource {
  // --- Tunables -----------------------------------------------------------
  static const double _strideMeters = 0.7;
  static const int _minStepIntervalMs = 280;
  // m/s² of userAccelerometer magnitude residual that counts as a step peak
  static const double _stepThreshold = 1.2;
  // Low-pass smoothing coefficient for the accel magnitude baseline
  static const double _baselineAlpha = 0.05;
  // Weight given to fresh GPS heading when speed is sufficient
  static const double _gpsHeadingBlend = 0.3;
  // User is considered "actively walking" if a step was detected within
  // this window. Outside the window PDR blending is bypassed and GPS is
  // passed through — otherwise the filter damps GPS against a stationary
  // PDR estimate (big problem for mock GPS, stopped users, and vehicles).
  static const int _walkingWindowMs = 2000;
  // If GPS reports a jump of more than this in one fix AND we aren't
  // actively walking, trust GPS fully regardless of other state.
  static const double _gpsJumpThresholdMeters = 3.0;
  // Campus latitude constants (good enough over a ~5km span)
  static const double _metersPerDegLat = 111320.0;
  static const double _metersPerDegLng = 107550.0;

  // --- Outputs ------------------------------------------------------------
  final StreamController<SmoothedLocation> _controller =
      StreamController<SmoothedLocation>.broadcast();
  Stream<SmoothedLocation> get stream => _controller.stream;

  // --- Sensor subscriptions ----------------------------------------------
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  // --- PDR state ---------------------------------------------------------
  LatLng? _position;
  double _headingDeg = 0.0;
  double? _lastAccuracy;
  DateTime? _lastGyroAt;

  // Step detector state
  double _accelBaseline = 0.0;
  double _prevResidual = 0.0;
  DateTime? _lastStepAt;

  bool _running = false;
  bool get isRunning => _running;

  void start() {
    if (_running) return;
    _running = true;
    _accelSub = userAccelerometerEventStream().listen(_onAccel);
    _gyroSub = gyroscopeEventStream().listen(_onGyro);
  }

  Future<void> stop() async {
    _running = false;
    await _accelSub?.cancel();
    await _gyroSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
    _lastGyroAt = null;
    _lastStepAt = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  /// Seed / correct the PDR state with a GPS fix. Called by the map layer
  /// whenever the platform reports a new real-GPS position.
  void onGpsFix({
    required LatLng position,
    double? gpsHeadingDeg,
    double? accuracyMeters,
    double? speedMps,
  }) {
    _lastAccuracy = accuracyMeters;

    // First fix: just seed.
    if (_position == null) {
      _position = position;
      if (gpsHeadingDeg != null && gpsHeadingDeg >= 0) {
        _headingDeg = gpsHeadingDeg;
      }
      _emit();
      return;
    }

    // Decide whether PDR should contribute to this fix.
    //
    // PDR only makes sense when the user is actively walking. If the
    // accelerometer hasn't seen a step recently, we're dealing with
    // mock GPS, a stopped user, or a moving vehicle — in all those
    // cases the PDR estimate is stale and would damp GPS, making the
    // dot feel sluggish. Pass GPS straight through instead.
    final now = DateTime.now();
    final activelyWalking = _lastStepAt != null &&
        now.difference(_lastStepAt!).inMilliseconds < _walkingWindowMs;

    // Also bypass PDR if GPS jumps a lot in one fix and we aren't
    // walking — catches teleports from mock-GPS apps, vehicle motion,
    // and recovery from a long GPS gap.
    final gpsJump = _metersBetween(_position!, position);
    final trustGpsFully = !activelyWalking || gpsJump > _gpsJumpThresholdMeters;

    if (trustGpsFully) {
      _position = position;
    } else {
      // Complementary filter: higher GPS accuracy → trust GPS more.
      final acc = (accuracyMeters ?? 20.0).clamp(5.0, 50.0);
      final alpha = 0.2 + (50.0 - acc) / 45.0 * 0.7;
      _position = LatLng(
        alpha * position.latitude + (1 - alpha) * _position!.latitude,
        alpha * position.longitude + (1 - alpha) * _position!.longitude,
      );
    }

    // Blend heading from GPS when the user is moving fast enough that
    // GPS course is meaningful. Same gate applies whether or not PDR
    // contributed to the position update.
    if (gpsHeadingDeg != null &&
        gpsHeadingDeg >= 0 &&
        (speedMps ?? 0) > 1.0 &&
        (accuracyMeters ?? 100.0) < 15.0) {
      // When trusting GPS fully, snap heading too; otherwise blend.
      _headingDeg = trustGpsFully
          ? gpsHeadingDeg
          : _blendHeading(_headingDeg, gpsHeadingDeg, _gpsHeadingBlend);
    }

    _emit();
  }

  static double _metersBetween(LatLng a, LatLng b) {
    final dLat = (a.latitude - b.latitude) * _metersPerDegLat;
    final dLng = (a.longitude - b.longitude) * _metersPerDegLng;
    return math.sqrt(dLat * dLat + dLng * dLng);
  }

  // --- Step detection -----------------------------------------------------

  void _onAccel(UserAccelerometerEvent e) {
    // userAccelerometer excludes gravity; magnitude hovers near 0 at rest
    // and peaks on footfall.
    final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    _accelBaseline =
        _accelBaseline * (1 - _baselineAlpha) + mag * _baselineAlpha;
    final residual = mag - _accelBaseline;

    // Rising-edge threshold crossing with refractory period.
    if (_prevResidual < _stepThreshold && residual >= _stepThreshold) {
      final now = DateTime.now();
      if (_lastStepAt == null ||
          now.difference(_lastStepAt!).inMilliseconds >= _minStepIntervalMs) {
        _lastStepAt = now;
        _onStep();
      }
    }
    _prevResidual = residual;
  }

  void _onStep() {
    if (_position == null) return;
    final rad = _headingDeg * math.pi / 180.0;
    // Heading 0°=N, 90°=E. dNorth = cos(h), dEast = sin(h).
    final dNorth = _strideMeters * math.cos(rad);
    final dEast = _strideMeters * math.sin(rad);
    _position = LatLng(
      _position!.latitude + dNorth / _metersPerDegLat,
      _position!.longitude + dEast / _metersPerDegLng,
    );
    _emit();
  }

  // --- Heading integration -----------------------------------------------

  void _onGyro(GyroscopeEvent e) {
    // Integrate yaw rate using the real sample interval rather than a
    // fixed step, since sensors_plus delivery is irregular.
    final now = DateTime.now();
    final last = _lastGyroAt;
    _lastGyroAt = now;
    if (last == null) return;
    final dt = now.difference(last).inMicroseconds / 1e6;
    if (dt <= 0 || dt > 0.2) return; // skip bogus intervals

    // Assumes phone is held roughly flat / screen-up. For other poses the
    // yaw-about-world-vertical is not equal to gyro.z; this is an MVP
    // simplification and will be revisited in Phase 2 with orientation
    // compensation.
    final dDeg = -e.z * dt * 180.0 / math.pi;
    _headingDeg = (_headingDeg + dDeg) % 360.0;
    if (_headingDeg < 0) _headingDeg += 360.0;
  }

  // --- Helpers ------------------------------------------------------------

  void _emit() {
    final p = _position;
    if (p == null) return;
    _controller.add(SmoothedLocation(
      position: p,
      headingDeg: _headingDeg,
      accuracyMeters: _lastAccuracy,
      timestamp: DateTime.now(),
    ));
  }

  static double _blendHeading(double a, double b, double alpha) {
    // Shortest-arc blend across the 0/360 seam.
    final diff = ((b - a + 540) % 360) - 180;
    var out = (a + alpha * diff) % 360;
    if (out < 0) out += 360;
    return out;
  }
}
