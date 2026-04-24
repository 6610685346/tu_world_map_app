import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Result of projecting a point onto a route polyline: the index of the
/// segment the projection landed on, the interpolation parameter along
/// that segment (0..1), the projected [LatLng], and the distance from the
/// original point to the projection in meters.
class RouteProjection {
  final int segmentIndex;
  final double t;
  final LatLng point;
  final double distanceMeters;

  const RouteProjection({
    required this.segmentIndex,
    required this.t,
    required this.point,
    required this.distanceMeters,
  });
}

/// Utility service that snaps a raw GPS position onto the nearest
/// point of an active navigation route, and supports trimming the
/// already-walked portion so the drawn route stays ahead of the user.
class SnapToPathService {
  /// Snap [rawPosition] to the nearest point on [routePath].
  ///
  /// If the nearest projected point is farther than [maxSnapDistance]
  /// meters, the raw position is returned unchanged (user is likely
  /// off-route).
  static LatLng snap(
    LatLng rawPosition,
    List<LatLng> routePath, {
    double maxSnapDistance = 25.0,
  }) {
    final proj = projectOnto(rawPosition, routePath);
    if (proj == null) return rawPosition;
    if (proj.distanceMeters <= maxSnapDistance) return proj.point;
    return rawPosition;
  }

  /// Project [p] onto the nearest segment of [route]. Returns null if
  /// the route has fewer than two points.
  static RouteProjection? projectOnto(LatLng p, List<LatLng> route) {
    if (route.length < 2) return null;

    int bestIdx = 0;
    double bestT = 0;
    LatLng bestPoint = route.first;
    double bestDistSq = double.infinity;

    for (int i = 0; i < route.length - 1; i++) {
      final a = route[i];
      final b = route[i + 1];
      final (proj, t) = _projectOntoSegment(p, a, b);
      final distSq = _distanceSqDegrees(p, proj);

      if (distSq < bestDistSq) {
        bestDistSq = distSq;
        bestIdx = i;
        bestT = t;
        bestPoint = proj;
      }
    }

    final dLat = (p.latitude - bestPoint.latitude) * 111320.0;
    final dLng = (p.longitude - bestPoint.longitude) * 107550.0;
    final meters = sqrt(dLat * dLat + dLng * dLng);

    return RouteProjection(
      segmentIndex: bestIdx,
      t: bestT,
      point: bestPoint,
      distanceMeters: meters,
    );
  }

  /// Return the suffix of [route] starting at [projection]: the projected
  /// point becomes the new first vertex, followed by every route vertex
  /// strictly after the projection's segment.
  static List<LatLng> trimFrom(List<LatLng> route, RouteProjection projection) {
    if (route.isEmpty) return const [];
    final suffix = route.sublist(projection.segmentIndex + 1);
    return [projection.point, ...suffix];
  }

  /// Project point P onto segment A→B, clamped. Returns (projection, t).
  static (LatLng, double) _projectOntoSegment(LatLng p, LatLng a, LatLng b) {
    final apLat = p.latitude - a.latitude;
    final apLng = p.longitude - a.longitude;
    final abLat = b.latitude - a.latitude;
    final abLng = b.longitude - a.longitude;
    final abLenSq = abLat * abLat + abLng * abLng;

    if (abLenSq < 1e-14) return (a, 0.0);

    final dot = apLat * abLat + apLng * abLng;
    final t = (dot / abLenSq).clamp(0.0, 1.0);
    return (
      LatLng(a.latitude + t * abLat, a.longitude + t * abLng),
      t,
    );
  }

  static double _distanceSqDegrees(LatLng a, LatLng b) {
    final dLat = a.latitude - b.latitude;
    final dLng = a.longitude - b.longitude;
    return dLat * dLat + dLng * dLng;
  }
}
