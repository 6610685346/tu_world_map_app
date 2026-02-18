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
        '?overview=full&geometries=geojson';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      print("STATUS CODE: ${response.statusCode}");
      print("BODY: ${response.body}");
      throw Exception('Failed to load route');
    }

    final data = json.decode(response.body);

    final coordinates = data['routes'][0]['geometry']['coordinates'] as List;

    return coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
  }
}
