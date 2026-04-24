/// Standalone smoke test for the GeoJSON-driven pathfinding pipeline.
///
/// Runs outside Flutter so it doesn't depend on rootBundle — reads the
/// asset from disk directly, exercises the same graph/pathfinding code
/// the app uses at runtime, and prints a short report.
///
/// Usage:  dart run tool/test_routing.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

import 'package:tu_world_map_app/models/path_node.dart';
// We can't import graph_loader.dart because it pulls in Flutter. Instead
// we inline the GeoJSON->graph transform, which is a faithful copy of
// _parseAndBuild in graph_loader.dart.

void main() {
  final raw = File('assets/paths.geojson').readAsStringSync();
  final sw = Stopwatch()..start();
  final nodes = _parseAndBuild(raw);
  sw.stop();

  print('=== Graph ===');
  print('Nodes: ${nodes.length}');
  int walkE = 0, bikeE = 0, roadE = 0;
  for (final n in nodes.values) {
    for (final e in n.edges) {
      switch (e.type) {
        case EdgeType.walk:
          walkE++;
        case EdgeType.bike:
          bikeE++;
        case EdgeType.road:
          roadE++;
      }
    }
  }
  print('Edges: walk=$walkE  bike=$bikeE  road=$roadE  (directed, incl. reverses)');
  print('Parse+build time: ${sw.elapsedMilliseconds} ms');

  // Connected-components over the *undirected* union (any edge connects).
  final cc = _components(nodes);
  cc.sort((a, b) => b.compareTo(a));
  print('Connected components (by node count): '
      'largest=${cc.first}  top5=${cc.take(5).toList()}  total=${cc.length}');

  // Pick two real points on TU Rangsit — main gate-ish and dome area.
  final start = LatLng(14.0683, 100.6034);
  final end = LatLng(14.0751, 100.6025);

  for (final mode in TravelMode.values) {
    final t = Stopwatch()..start();
    final route = _buildRoute(nodes, start, end, mode);
    t.stop();

    print('\n=== ${mode.name.toUpperCase()} ===');
    if (route.isEmpty) {
      print('No route found (${t.elapsedMilliseconds} ms)');
      continue;
    }
    final meters = _routeLength(route);
    print('Route: ${route.length} points, ${meters.toStringAsFixed(0)}m, ${t.elapsedMilliseconds} ms');
    print('  first: ${route.first.latitude.toStringAsFixed(5)}, ${route.first.longitude.toStringAsFixed(5)}');
    print('  last:  ${route.last.latitude.toStringAsFixed(5)}, ${route.last.longitude.toStringAsFixed(5)}');
  }
}

// --- Inlined graph builder (mirror of graph_loader.dart) ---------------

Map<String, PathNode> _parseAndBuild(String raw) {
  final doc = json.decode(raw) as Map<String, dynamic>;
  final features = doc['features'] as List<dynamic>;
  final tmp = <String, _Mut>{};

  for (final f in features) {
    final feature = f as Map<String, dynamic>;
    final props = feature['properties'] as Map<String, dynamic>;
    final geom = feature['geometry'] as Map<String, dynamic>;
    final coords = geom['coordinates'] as List<dynamic>;
    if (coords.length < 2) continue;

    final type = switch (props['type'] as String) {
      'bike' => EdgeType.bike,
      'road' => EdgeType.road,
      _ => EdgeType.walk,
    };
    final oneWay = props['oneWay'] == true;

    String? prevId;
    for (final c in coords) {
      final lon = (c[0] as num).toDouble();
      final lat = (c[1] as num).toDouble();
      final id = '${lat.toStringAsFixed(7)},${lon.toStringAsFixed(7)}';
      tmp.putIfAbsent(id, () => _Mut(id, LatLng(lat, lon)));
      if (prevId != null && prevId != id) {
        tmp[prevId]!.edges.add(PathEdge(toId: id, type: type));
        if (!oneWay) tmp[id]!.edges.add(PathEdge(toId: prevId, type: type));
      }
      prevId = id;
    }
  }

  return {
    for (final e in tmp.entries)
      e.key: PathNode(id: e.key, position: e.value.position, edges: e.value.edges),
  };
}

class _Mut {
  final String id;
  final LatLng position;
  final List<PathEdge> edges = [];
  _Mut(this.id, this.position);
}

// --- Inlined A* (mirror of pathfinding_service.dart) -------------------

final Distance _dist = Distance();

double _weight(TravelMode m, EdgeType t) {
  return switch ((m, t)) {
    (TravelMode.walk, EdgeType.walk) => 1.0,
    (TravelMode.walk, EdgeType.bike) => 1.1,
    (TravelMode.walk, EdgeType.road) => 4.0,
    (TravelMode.bike, EdgeType.bike) => 1.0,
    (TravelMode.bike, EdgeType.walk) => 1.4,
    (TravelMode.bike, EdgeType.road) => 2.5,
    (TravelMode.car, EdgeType.road) => 1.0,
    (TravelMode.car, _) => double.infinity,
  };
}

List<LatLng> _buildRoute(
  Map<String, PathNode> nodes,
  LatLng start,
  LatLng end,
  TravelMode mode,
) {
  // Try the 10 nearest candidates on each side and return the first route
  // that resolves — mirrors NavigationService behavior.
  final starts = _nearestN(nodes, start, 10, mode);
  final ends = _nearestN(nodes, end, 10, mode);
  for (final s in starts) {
    for (final e in ends) {
      final r = _aStar(nodes, s, e, mode);
      if (r.isNotEmpty) return r;
    }
  }
  return const [];
}

List<PathNode> _nearestN(
  Map<String, PathNode> nodes,
  LatLng p,
  int n,
  TravelMode mode,
) {
  final all = <MapEntry<double, PathNode>>[];
  for (final node in nodes.values) {
    // Must have at least one edge usable by this mode.
    if (!node.edges.any((e) => _weight(mode, e.type).isFinite)) continue;
    final d = _dist.as(LengthUnit.Meter, p, node.position);
    all.add(MapEntry(d, node));
  }
  all.sort((a, b) => a.key.compareTo(b.key));
  return all.take(n).map((e) => e.value).toList();
}

List<LatLng> _aStar(
  Map<String, PathNode> nodes,
  PathNode s,
  PathNode e,
  TravelMode mode,
) {

  final gScore = <String, double>{s.id: 0.0};
  final cameFrom = <String, String>{};
  final open = <_He>[_He(_dist.as(LengthUnit.Meter, s.position, e.position), s.id)];

  while (open.isNotEmpty) {
    open.sort((a, b) => a.f.compareTo(b.f));
    final cur = open.removeAt(0);
    if (cur.id == e.id) return _recon(nodes, cameFrom, cur.id);
    final node = nodes[cur.id]!;
    final gCur = gScore[cur.id]!;

    for (final edge in node.edges) {
      final nb = nodes[edge.toId];
      if (nb == null) continue;
      final w = _weight(mode, edge.type);
      if (w.isInfinite) continue;
      final seg = _dist.as(LengthUnit.Meter, node.position, nb.position);
      final g = gCur + seg * w;
      if ((gScore[edge.toId] ?? double.infinity) <= g) continue;
      gScore[edge.toId] = g;
      cameFrom[edge.toId] = cur.id;
      final f = g + _dist.as(LengthUnit.Meter, nb.position, e.position);
      open.add(_He(f, edge.toId));
    }
  }
  return const [];
}

List<LatLng> _recon(Map<String, PathNode> nodes, Map<String, String> from, String endId) {
  final out = <LatLng>[];
  String? cur = endId;
  while (cur != null) {
    out.add(nodes[cur]!.position);
    cur = from[cur];
  }
  return out.reversed.toList();
}

double _routeLength(List<LatLng> r) {
  double m = 0;
  for (int i = 1; i < r.length; i++) {
    m += _dist.as(LengthUnit.Meter, r[i - 1], r[i]);
  }
  return m;
}

class _He {
  final double f;
  final String id;
  _He(this.f, this.id);
}

List<int> _components(Map<String, PathNode> nodes) {
  final seen = <String>{};
  final sizes = <int>[];
  for (final start in nodes.keys) {
    if (seen.contains(start)) continue;
    int size = 0;
    final stack = <String>[start];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      if (!seen.add(id)) continue;
      size++;
      for (final e in nodes[id]!.edges) {
        if (!seen.contains(e.toId) && nodes.containsKey(e.toId)) {
          stack.add(e.toId);
        }
      }
    }
    sizes.add(size);
  }
  return sizes;
}
