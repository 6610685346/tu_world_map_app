import 'package:latlong2/latlong.dart';

class PathNode {
  final String id;
  final LatLng position;
  final List<String> neighbors;

  PathNode({required this.id, required this.position, required this.neighbors});
}
