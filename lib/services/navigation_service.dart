import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

enum RouteMode { walk, bike, car }

class NavigationService {
  final Function(LatLng) onLocationUpdate;
  Timer? _timer;

  NavigationService({required this.onLocationUpdate});

  Future<void> startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('GPS not enabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied forever');
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      onLocationUpdate(LatLng(pos.latitude, pos.longitude));
    });
  }

  void stopTracking() => _timer?.cancel();

  Future<List<LatLng>> getRoute(
      LatLng start, LatLng end, RouteMode mode) async {
    String profile = switch (mode) {
      RouteMode.walk => 'foot',
      RouteMode.bike => 'bike',
      RouteMode.car => 'car',
    };

    final url =
        'https://router.project-osrm.org/route/v1/$profile/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson';

    final res = await http.get(Uri.parse(url));
    final data = jsonDecode(res.body);
    final coords = data['routes'][0]['geometry']['coordinates'];

    return coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
  }
}