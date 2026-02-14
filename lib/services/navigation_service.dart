import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class NavigationService {
  static const String _apiKey = 'pKEb1AjUUNqlSI9aLaO5';

  Future<List<LatLng>> buildRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    final url =
        'https://router.project-osrm.org/route/v1/foot/'
        '${start.longitude},${start.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=polyline';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      print("STATUS CODE: ${response.statusCode}");
      print("BODY: ${response.body}");
      throw Exception('Failed to load route');
    }

    final data = json.decode(response.body);

    final geometry = data['routes'][0]['geometry'];

    return _decodePolyline(geometry);
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}
