import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class NavigationService {
  Timer? _timer;
  LatLng? currentLocation;

  final void Function(LatLng) onLocationUpdate;

  NavigationService({required this.onLocationUpdate});

  Future<void> startTracking() async {
    await Geolocator.requestPermission();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final pos = await Geolocator.getCurrentPosition();
      currentLocation = LatLng(pos.latitude, pos.longitude);
      onLocationUpdate(currentLocation!);
    });
  }

  void stopTracking() {
    _timer?.cancel();
  }

  List<LatLng> buildRoute(LatLng start, LatLng destination) {
    return [start, destination]; // เส้นตรง
  }
}