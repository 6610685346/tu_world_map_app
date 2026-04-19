import 'package:latlong2/latlong.dart';
import 'package:tu_world_map_app/models/path_node.dart';
import 'package:tu_world_map_app/services/path_graph_service.dart';
import 'package:flutter/foundation.dart';
import 'package:tu_world_map_app/services/path_graph_generated.dart';

class NavigationService {
  Future<List<LatLng>> buildRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    final startCandidates = PathGraphService.findNearestNodes(start, 10);
    final endCandidates = PathGraphService.findNearestNodes(destination, 10);

    final distance = Distance();

    // Sort candidates so closest nodes are tested first
    startCandidates.sort(
      (a, b) => distance
          .as(LengthUnit.Meter, start, a.position)
          .compareTo(distance.as(LengthUnit.Meter, start, b.position)),
    );

    endCandidates.sort(
      (a, b) => distance
          .as(LengthUnit.Meter, destination, a.position)
          .compareTo(distance.as(LengthUnit.Meter, destination, b.position)),
    );

    List<PathNode> bestPath = [];

    for (final s in startCandidates) {
      for (final e in endCandidates) {
        debugPrint("TRY ROUTE: ${s.id} -> ${e.id}");

        final path = PathGraphService.findPath(s, e);

        if (path.isNotEmpty) {
          bestPath = path;
          debugPrint("ROUTE FOUND");
          break;
        }
      }

      if (bestPath.isNotEmpty) break;
    }

    if (bestPath.isEmpty) {
      debugPrint("NO ROUTE FOUND, navigation service");
      return [];
    }

    debugPrint("PATH NODE COUNT: ${bestPath.length}");

    final simplified = <LatLng>[];
    LatLng? last;

    const minDistance = 3;

    for (final node in bestPath) {
      if (last == null ||
          distance.as(LengthUnit.Meter, last, node.position) > minDistance) {
        simplified.add(node.position);
        last = node.position;
      }
    }

    if (bestPath.isNotEmpty) {
      final first = bestPath.first.position;
      final lastNode = bestPath.last.position;

      if (distance.as(LengthUnit.Meter, start, first) < 15) {
        simplified.insert(0, start);
      }

      if (distance.as(LengthUnit.Meter, lastNode, destination) < 50) {
        simplified.add(destination);
      }
    }

    debugPrint("SIMPLIFIED COUNT: ${simplified.length}");

    return simplified;
  }

  PathNode findNearestNodeToPolygon(List<LatLng> polygon) {
    double bestDistance = double.infinity;
    PathNode? bestNode;

    final distance = Distance();

    for (final node in PathGraphGenerated.nodes.values) {
      if (node.neighbors.isEmpty) continue; // Skip isolated nodes

      for (final p in polygon) {
        final d = distance.as(LengthUnit.Meter, node.position, p);

        if (d < bestDistance) {
          bestDistance = d;
          bestNode = node;
        }
      }
    }

    return bestNode!;
  }
}
