import 'package:latlong2/latlong.dart';

import 'package:tu_world_map_app/models/path_node.dart';
import 'package:tu_world_map_app/services/graph_loader.dart';

/// A* pathfinder over the loaded path graph, with travel-mode aware edge
/// costs.
///
/// Edge cost = base_distance_meters * profile_weight(edgeType). Weights are
/// chosen so each mode prefers its own infrastructure and only spills onto
/// other edge types when the detour cost dominates.
///
/// - walk: prefers walking paths, tolerates cycle lanes, avoids roads unless
///   the walking detour would be ~4x longer.
/// - bike: prefers cycle lanes, tolerates walking paths, uses roads at ~2.5x
///   cost before giving up.
/// - car:  uses roads only. Walking / cycling edges are impassable.
class PathfindingService {
  static final Distance _distance = Distance();

  static double _weight(TravelMode mode, EdgeType type) {
    switch (mode) {
      case TravelMode.walk:
        switch (type) {
          case EdgeType.walk:
            return 1.0;
          case EdgeType.bike:
            return 1.1;
          case EdgeType.road:
            return 4.0;
        }
      case TravelMode.bike:
        switch (type) {
          case EdgeType.bike:
            return 1.0;
          case EdgeType.walk:
            return 1.4;
          case EdgeType.road:
            return 2.5;
        }
      case TravelMode.car:
        switch (type) {
          case EdgeType.road:
            return 1.0;
          case EdgeType.walk:
          case EdgeType.bike:
            return double.infinity;
        }
    }
  }

  /// Build the cheapest route from [startId] to [goalId] for [mode].
  /// Returns the list of node positions, or an empty list if unreachable.
  static List<LatLng> findRoute({
    required String startId,
    required String goalId,
    required TravelMode mode,
  }) {
    final nodes = GraphLoader.nodes;
    final start = nodes[startId];
    final goal = nodes[goalId];
    if (start == null || goal == null) return const [];
    if (startId == goalId) return [start.position];

    final gScore = <String, double>{startId: 0.0};
    final cameFrom = <String, String>{};
    final open = _MinHeap();
    open.push(_HeapEntry(_heuristic(start, goal), startId));

    while (!open.isEmpty) {
      final current = open.pop();
      final currentId = current.nodeId;

      if (currentId == goalId) {
        return _reconstruct(cameFrom, currentId, nodes);
      }

      // Skip stale heap entries — we use lazy deletion instead of
      // decrease-key.
      final gCurrent = gScore[currentId]!;
      if (current.fScore >
          gCurrent + _heuristic(nodes[currentId]!, goal) + 1e-9) {
        continue;
      }

      final currentNode = nodes[currentId]!;
      for (final edge in currentNode.edges) {
        final neighbor = nodes[edge.toId];
        if (neighbor == null) continue;

        final w = _weight(mode, edge.type);
        if (w.isInfinite) continue;

        final segmentMeters = _distance.as(
          LengthUnit.Meter,
          currentNode.position,
          neighbor.position,
        );
        final tentativeG = gCurrent + segmentMeters * w;

        final existing = gScore[edge.toId];
        if (existing != null && tentativeG >= existing) continue;

        gScore[edge.toId] = tentativeG;
        cameFrom[edge.toId] = currentId;
        final f = tentativeG + _heuristic(neighbor, goal);
        open.push(_HeapEntry(f, edge.toId));
      }
    }

    return const [];
  }

  static double _heuristic(PathNode a, PathNode b) {
    // Admissible: raw geometric distance is always <= any weighted edge
    // cost because the minimum profile weight is 1.0.
    return _distance.as(LengthUnit.Meter, a.position, b.position);
  }

  static List<LatLng> _reconstruct(
    Map<String, String> cameFrom,
    String endId,
    Map<String, PathNode> nodes,
  ) {
    final out = <LatLng>[];
    String? cur = endId;
    while (cur != null) {
      out.add(nodes[cur]!.position);
      cur = cameFrom[cur];
    }
    return out.reversed.toList(growable: false);
  }

  /// Return the [count] nodes closest to [point]. Isolated nodes are
  /// skipped because they cannot be entry points into the routable graph.
  static List<PathNode> nearestNodes(LatLng point, int count) {
    final result = <PathNode>[];
    final dists = <double>[];

    for (final node in GraphLoader.nodes.values) {
      if (node.edges.isEmpty) continue;
      final d = _distance.as(LengthUnit.Meter, point, node.position);

      if (result.length < count) {
        result.add(node);
        dists.add(d);
        continue;
      }

      int worstIdx = 0;
      double worstDist = dists[0];
      for (int i = 1; i < dists.length; i++) {
        if (dists[i] > worstDist) {
          worstDist = dists[i];
          worstIdx = i;
        }
      }

      if (d < worstDist) {
        result[worstIdx] = node;
        dists[worstIdx] = d;
      }
    }

    final indices = List<int>.generate(result.length, (i) => i)
      ..sort((a, b) => dists[a].compareTo(dists[b]));
    return [for (final i in indices) result[i]];
  }
}

class _HeapEntry {
  final double fScore;
  final String nodeId;
  _HeapEntry(this.fScore, this.nodeId);
}

class _MinHeap {
  final List<_HeapEntry> _data = [];

  bool get isEmpty => _data.isEmpty;

  void push(_HeapEntry e) {
    _data.add(e);
    _siftUp(_data.length - 1);
  }

  _HeapEntry pop() {
    final top = _data.first;
    final last = _data.removeLast();
    if (_data.isNotEmpty) {
      _data[0] = last;
      _siftDown(0);
    }
    return top;
  }

  void _siftUp(int i) {
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_data[i].fScore < _data[parent].fScore) {
        final tmp = _data[i];
        _data[i] = _data[parent];
        _data[parent] = tmp;
        i = parent;
      } else {
        break;
      }
    }
  }

  void _siftDown(int i) {
    final n = _data.length;
    while (true) {
      final l = 2 * i + 1;
      final r = 2 * i + 2;
      int smallest = i;
      if (l < n && _data[l].fScore < _data[smallest].fScore) smallest = l;
      if (r < n && _data[r].fScore < _data[smallest].fScore) smallest = r;
      if (smallest == i) break;
      final tmp = _data[i];
      _data[i] = _data[smallest];
      _data[smallest] = tmp;
      i = smallest;
    }
  }
}
