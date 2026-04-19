import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

import '../models/path_node.dart';
import 'package:tu_world_map_app/services/path_graph_generated.dart';

class PathGraphService {
  static final Map<String, PathNode> nodes = PathGraphGenerated.nodes;

  static final Distance _distance = Distance();

  static bool _graphPrepared = false;

  // -------------------------------------------------------
  // Prepare graph once
  // -------------------------------------------------------
  static void _prepareGraph() {
    if (_graphPrepared) return;

    _ensureBidirectional();
    _graphPrepared = true;
  }

  // -------------------------------------------------------
  // Find nearest single node
  // -------------------------------------------------------
  static PathNode findNearestNode(LatLng point) {
    PathNode? closest;
    double minDistance = double.infinity;

    for (final node in nodes.values) {
      if (node.neighbors.isEmpty) continue;

      final d = _distance.as(LengthUnit.Meter, point, node.position);

      if (d < minDistance) {
        minDistance = d;
        closest = node;
      }
    }

    return closest!;
  }

  // -------------------------------------------------------
  // Find nearest N nodes
  // -------------------------------------------------------
  static List<PathNode> findNearestNodes(LatLng point, int count) {
    final List<PathNode> best = [];
    final List<double> bestDist = [];

    for (final node in nodes.values) {
      final d = _distance.as(LengthUnit.Meter, point, node.position);

      if (best.length < count) {
        best.add(node);
        bestDist.add(d);
        continue;
      }

      int worstIndex = 0;
      double worstDist = bestDist[0];

      for (int i = 1; i < bestDist.length; i++) {
        if (bestDist[i] > worstDist) {
          worstDist = bestDist[i];
          worstIndex = i;
        }
      }

      if (d < worstDist) {
        best[worstIndex] = node;
        bestDist[worstIndex] = d;
      }
    }

    return best;
  }

  // -------------------------------------------------------
  // A* Pathfinding
  // -------------------------------------------------------
  static List<PathNode> findPath(PathNode start, PathNode goal) {
    _prepareGraph();

    debugPrint("A* ROUTING STARTED");
    debugPrint("START NODE: ${start.id}");
    debugPrint("GOAL NODE: ${goal.id}");
    debugPrint("TOTAL NODES: ${nodes.length}");
    debugPrint(
      "EDGE COUNT: ${nodes.values.fold(0, (s, n) => s + n.neighbors.length)}",
    );

    final openSet = <String>{start.id};
    final cameFrom = <String, String>{};

    final gScore = <String, double>{};
    final fScore = <String, double>{};

    final graph = _buildBidirectionalGraph();

    for (final node in nodes.keys) {
      gScore[node] = double.infinity;
      fScore[node] = double.infinity;
    }

    gScore[start.id] = 0;
    fScore[start.id] = _heuristic(start, goal);

    while (openSet.isNotEmpty) {
      final current = openSet.reduce((a, b) => fScore[a]! < fScore[b]! ? a : b);

      if (current == goal.id) {
        return _reconstructPath(cameFrom, current);
      }

      openSet.remove(current);

      final currentNode = nodes[current]!;

      // NORMAL GRAPH NEIGHBORS
      for (final neighborId in graph[current] ?? []) {
        if (!nodes.containsKey(neighborId)) continue;

        final neighborNode = nodes[neighborId]!;

        final tentativeG =
            gScore[current]! +
            _distance.as(
              LengthUnit.Meter,
              currentNode.position,
              neighborNode.position,
            );

        if (tentativeG < gScore[neighborId]!) {
          cameFrom[neighborId] = current;
          gScore[neighborId] = tentativeG;
          fScore[neighborId] = tentativeG + _heuristic(neighborNode, goal);

          openSet.add(neighborId);
        }
      }

      // GAP BRIDGE (lightweight)
      for (final other in nodes.values) {
        if (other.id == current) continue;

        final d = _distance.as(
          LengthUnit.Meter,
          currentNode.position,
          other.position,
        );

        // only allow very small connection
        if (d < 8) {
          final tentativeG = gScore[current]! + d;

          if (tentativeG < gScore[other.id]!) {
            cameFrom[other.id] = current;
            gScore[other.id] = tentativeG;
            fScore[other.id] = tentativeG + _heuristic(other, goal);

            openSet.add(other.id);
          }
        }
      }
    }

    debugPrint("NO PATH FOUND, A* FAILED");
    return [];
  }

  // -------------------------------------------------------
  // Heuristic
  // -------------------------------------------------------
  static double _heuristic(PathNode a, PathNode b) {
    return _distance.as(LengthUnit.Meter, a.position, b.position);
  }

  // -------------------------------------------------------
  // Reconstruct path
  // -------------------------------------------------------
  static List<PathNode> _reconstructPath(
    Map<String, String> cameFrom,
    String current,
  ) {
    final path = <PathNode>[nodes[current]!];

    while (cameFrom.containsKey(current)) {
      current = cameFrom[current]!;
      path.insert(0, nodes[current]!);
    }

    return path;
  }

  // -------------------------------------------------------
  // Ensure bidirectional graph
  // -------------------------------------------------------
  static void _ensureBidirectional() {
    for (final node in nodes.values) {
      for (final neighborId in node.neighbors) {
        if (!nodes.containsKey(neighborId)) continue;

        final neighbor = nodes[neighborId]!;

        if (!neighbor.neighbors.contains(node.id)) {
          neighbor.neighbors.add(node.id);
        }
      }
    }
  }

  // -------------------------------------------------------
  // Build graph map
  // -------------------------------------------------------
  static Map<String, List<String>> _buildBidirectionalGraph() {
    final graph = <String, List<String>>{};

    for (final node in nodes.values) {
      graph[node.id] = List.from(node.neighbors);
    }

    for (final node in nodes.values) {
      for (final neighborId in node.neighbors) {
        if (!nodes.containsKey(neighborId)) continue;

        graph.putIfAbsent(neighborId, () => []);

        if (!graph[neighborId]!.contains(node.id)) {
          graph[neighborId]!.add(node.id);
        }
      }
    }

    return graph;
  }
}
