import 'package:latlong2/latlong.dart';

class NavigationService {
  Future<List<LatLng>> buildRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    // TODO: Replace with real DB-based routing
    return [start, destination];
  }
}
