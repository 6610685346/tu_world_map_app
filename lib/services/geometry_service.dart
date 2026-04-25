import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Utility service for polygon-related geometric calculations.
class GeometryService {
  /// Check if a [point] is inside a [polygon] using the ray casting algorithm.
  /// Works for simple polygons (including concave ones).
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    bool isInside = false;
    final x = point.longitude;
    final y = point.latitude;

    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      final intersect = ((yi > y) != (yj > y)) &&
          (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
      if (intersect) isInside = !isInside;
    }

    return isInside;
  }

  /// Minimum distance from [point] to the boundary of [polygon] in meters.
  /// If the point is inside the polygon, returns 0.0.
  static double minDistanceToPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.isEmpty) return double.infinity;
    if (isPointInPolygon(point, polygon)) return 0.0;

    double minDistance = double.infinity;

    for (int i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];

      final dist = distanceToSegment(point, a, b);
      if (dist < minDistance) {
        minDistance = dist;
      }
    }

    return minDistance;
  }

  /// Calculates the shortest distance from point [p] to the segment [a]-[b] in meters.
  /// Uses a Cartesian approximation suitable for small areas like a campus.
  static double distanceToSegment(LatLng p, LatLng a, LatLng b) {
    // We use a Cartesian approximation for short distances at campus scale.
    // at ~14° N (campus latitude):
    // 1 degree latitude ~ 111,320 meters.
    // 1 degree longitude ~ 111,320 * cos(14°) ~ 108,000 meters.
    
    final latRad = a.latitude * pi / 180.0;
    final kLng = cos(latRad);
    
    // Scale factors to convert degrees to meters
    const double degToMeters = 111320.0;
    
    // Convert to meters relative to point A
    final apX = (p.longitude - a.longitude) * degToMeters * kLng;
    final apY = (p.latitude - a.latitude) * degToMeters;
    
    final abX = (b.longitude - a.longitude) * degToMeters * kLng;
    final abY = (b.latitude - a.latitude) * degToMeters;
    
    final abLenSq = abX * abX + abY * abY;
    
    if (abLenSq < 1e-10) {
      // Segment is actually a point
      return sqrt(apX * apX + apY * apY);
    }
    
    // Project P onto line AB, yielding t as the fraction along AB
    final t = ((apX * abX + apY * abY) / abLenSq).clamp(0.0, 1.0);
    
    // Closest point on the segment
    final projX = abX * t;
    final projY = abY * t;
    
    // Distance from P to the projection
    final dx = apX - projX;
    final dy = apY - projY;
    
    return sqrt(dx * dx + dy * dy);
  }
}
