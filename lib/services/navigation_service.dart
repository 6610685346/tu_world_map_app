import 'package:latlong2/latlong.dart';

import 'package:tu_world_map_app/models/path_node.dart';
import 'package:tu_world_map_app/services/graph_loader.dart';
import 'package:tu_world_map_app/services/pathfinding_service.dart';

/// High-level navigation API used by the UI.
///
/// The expensive graph parse happens once at app startup inside a
/// background isolate (see [GraphLoader.ensureLoaded]). Route computation
/// itself runs on the main thread because A* on this graph (~20k nodes,
/// bounded frontier from a good heuristic) completes in a few ms — the
/// cost of marshaling the graph in/out of a fresh isolate per request
/// would exceed the compute savings.
class NavigationService {
  static const int _endpointCandidates = 5;
  static const double _snapToStartMeters = 15.0;
  static const double _snapToDestMeters = 50.0;
  static const double _simplifyMeters = 3.0;

  Future<List<LatLng>> buildRoute({
    required LatLng start,
    required LatLng destination,
    TravelMode mode = TravelMode.walk,
  }) async {
    await GraphLoader.ensureLoaded();

    final startNodes = PathfindingService.nearestNodes(start, _endpointCandidates);
    final endNodes = PathfindingService.nearestNodes(
      destination,
      _endpointCandidates,
    );

    List<LatLng> raw = const [];
    for (final s in startNodes) {
      for (final e in endNodes) {
        final path = PathfindingService.findRoute(
          startId: s.id,
          goalId: e.id,
          mode: mode,
        );
        if (path.isNotEmpty) {
          raw = path;
          break;
        }
      }
      if (raw.isNotEmpty) break;
    }

    if (raw.isEmpty) return const [];
    return _postProcess(raw, start, destination);
  }

  Future<PathNode> findNearestNodeToPolygon(List<LatLng> polygon) async {
    await GraphLoader.ensureLoaded();

    final distance = Distance();
    double best = double.infinity;
    PathNode? winner;

    for (final node in GraphLoader.nodes.values) {
      if (node.edges.isEmpty) continue;
      for (final p in polygon) {
        final d = distance.as(LengthUnit.Meter, node.position, p);
        if (d < best) {
          best = d;
          winner = node;
        }
      }
    }

    return winner!;
  }

  List<LatLng> _postProcess(List<LatLng> raw, LatLng start, LatLng destination) {
    final distance = Distance();
    final simplified = <LatLng>[];
    LatLng? last;

    for (final p in raw) {
      if (last == null ||
          distance.as(LengthUnit.Meter, last, p) > _simplifyMeters) {
        simplified.add(p);
        last = p;
      }
    }

    if (simplified.isNotEmpty) {
      if (distance.as(LengthUnit.Meter, start, simplified.first) <
          _snapToStartMeters) {
        simplified.insert(0, start);
      }
      if (distance.as(LengthUnit.Meter, simplified.last, destination) <
          _snapToDestMeters) {
        simplified.add(destination);
      }
    }

    return simplified;
  }
}
