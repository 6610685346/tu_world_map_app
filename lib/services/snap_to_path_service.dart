import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Utility service that snaps a raw GPS position onto the nearest
/// point of an active navigation route to mitigate GPS jitter.
class SnapToPathService {
  /// Snap [rawPosition] to the nearest point on [routePath].
  ///
  /// If the nearest projected point is farther than [maxSnapDistance] meters,
  /// the raw position is returned unchanged (user is likely off-route).
  ///
  /// Returns the snapped position.
  static LatLng snap(
    LatLng rawPosition,
    List<LatLng> routePath, {
    double maxSnapDistance = 25.0,
  }) {
    if (routePath.length < 2) return rawPosition;

    double bestDistSq = double.infinity;
    LatLng bestProjection = rawPosition;

    for (int i = 0; i < routePath.length - 1; i++) {
      final a = routePath[i];
      final b = routePath[i + 1];

      final projected = _projectOntoSegment(rawPosition, a, b);
      final distSq = _distanceSqDegrees(rawPosition, projected);

      if (distSq < bestDistSq) {
        bestDistSq = distSq;
        bestProjection = projected;
      }
    }

    // Convert the best squared-degree distance to approximate meters
    // Using average scale at campus latitude (~14°N):
    // 1° lat ≈ 111,320m, 1° lng ≈ 107,550m
    final dLat = (rawPosition.latitude - bestProjection.latitude) * 111320.0;
    final dLng = (rawPosition.longitude - bestProjection.longitude) * 107550.0;
    final distMeters = sqrt(dLat * dLat + dLng * dLng);

    if (distMeters <= maxSnapDistance) {
      return bestProjection;
    }

    // Too far from route — return raw position (will trigger rerouting)
    return rawPosition;
  }

  /// Project point P onto line segment A→B, clamped to the segment.
  ///
  /// Uses the formula: t = clamp(dot(P-A, B-A) / dot(B-A, B-A), 0, 1)
  /// projected = A + t * (B - A)
  static LatLng _projectOntoSegment(LatLng p, LatLng a, LatLng b) {
    final apLat = p.latitude - a.latitude;
    final apLng = p.longitude - a.longitude;
    final abLat = b.latitude - a.latitude;
    final abLng = b.longitude - a.longitude;

    final abLenSq = abLat * abLat + abLng * abLng;

    if (abLenSq < 1e-14) {
      // A and B are essentially the same point
      return a;
    }

    final dot = apLat * abLat + apLng * abLng;
    final t = (dot / abLenSq).clamp(0.0, 1.0);

    return LatLng(
      a.latitude + t * abLat,
      a.longitude + t * abLng,
    );
  }

  /// Squared distance in degrees (for comparison — avoids sqrt).
  static double _distanceSqDegrees(LatLng a, LatLng b) {
    final dLat = a.latitude - b.latitude;
    final dLng = a.longitude - b.longitude;
    return dLat * dLat + dLng * dLng;
  }
}
