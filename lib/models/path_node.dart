import 'package:latlong2/latlong.dart';

/// Physical type of a graph edge. Controls which travel modes may use it
/// and how desirable it is for modes that can.
enum EdgeType { walk, bike, road }

/// User's chosen travel mode. Each mode resolves edge types to a weight
/// multiplier; `double.infinity` means the edge is impassable for that mode.
enum TravelMode { walk, bike, car }

/// A directed edge from one node to another. When [oneWay] is false the
/// graph loader adds the reverse edge automatically, so the rest of the
/// code can treat it as directed.
class PathEdge {
  final String toId;
  final EdgeType type;
  final bool oneWay;

  const PathEdge({
    required this.toId,
    required this.type,
    this.oneWay = false,
  });
}

class PathNode {
  final String id;
  final LatLng position;
  final List<PathEdge> edges;

  PathNode({required this.id, required this.position, required this.edges});
}
