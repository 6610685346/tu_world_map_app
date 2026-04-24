import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import 'package:tu_world_map_app/models/path_node.dart';

/// Loads the path graph from `assets/paths.geojson` at app startup.
///
/// The GeoJSON file is produced offline by `tool/fetch_osm_paths.py` from
/// OpenStreetMap data. Each LineString feature becomes a chain of graph
/// edges with the edge type carried in `properties.type` (walk|bike|road)
/// and direction optionally restricted by `properties.oneWay`.
///
/// Node identity is derived by rounding coordinates to 7 decimals
/// (~1.1cm), which is well below OSM's precision — identical junction
/// points across features reliably collapse to the same node id.
class GraphLoader {
  static const String _assetPath = 'assets/paths.geojson';

  static Map<String, PathNode>? _nodes;
  static Future<void>? _loading;

  /// Idempotent. First call triggers the async load; subsequent calls
  /// return the same future. Safe to await from multiple call sites.
  static Future<void> ensureLoaded() {
    return _loading ??= _load();
  }

  /// The fully built graph. Throws if accessed before [ensureLoaded]
  /// completes — callers on the hot path should await `ensureLoaded()`
  /// once at startup.
  static Map<String, PathNode> get nodes {
    final n = _nodes;
    if (n == null) {
      throw StateError(
        'GraphLoader.nodes accessed before ensureLoaded() completed',
      );
    }
    return n;
  }

  static bool get isLoaded => _nodes != null;

  static Future<void> _load() async {
    final raw = await rootBundle.loadString(_assetPath);
    // Parse + build in an isolate so the main thread stays responsive;
    // the resulting map is cheap to send back (primitives only, then
    // rehydrated into PathNode/PathEdge on the main side).
    final built = await compute(_parseAndBuild, raw);
    _nodes = built;
    debugPrint('GraphLoader: ${built.length} nodes loaded');
  }
}

/// Top-level entry for [compute]. Parses the GeoJSON string and returns
/// the fully assembled node map.
Map<String, PathNode> _parseAndBuild(String raw) {
  final doc = json.decode(raw) as Map<String, dynamic>;
  final features = doc['features'] as List<dynamic>;

  final nodes = <String, _MutableNode>{};

  for (final f in features) {
    final feature = f as Map<String, dynamic>;
    final props = feature['properties'] as Map<String, dynamic>;
    final geom = feature['geometry'] as Map<String, dynamic>;
    final coords = geom['coordinates'] as List<dynamic>;
    if (coords.length < 2) continue;

    final type = _edgeTypeFromString(props['type'] as String);
    final oneWay = props['oneWay'] == true;

    String? prevId;
    for (final c in coords) {
      final lon = (c[0] as num).toDouble();
      final lat = (c[1] as num).toDouble();
      final id = _nodeId(lat, lon);
      nodes.putIfAbsent(id, () => _MutableNode(id, LatLng(lat, lon)));

      if (prevId != null && prevId != id) {
        nodes[prevId]!.edges.add(PathEdge(toId: id, type: type));
        if (!oneWay) {
          nodes[id]!.edges.add(PathEdge(toId: prevId, type: type));
        }
      }
      prevId = id;
    }
  }

  final result = <String, PathNode>{};
  nodes.forEach((id, m) {
    result[id] = PathNode(id: id, position: m.position, edges: m.edges);
  });
  return result;
}

EdgeType _edgeTypeFromString(String s) {
  switch (s) {
    case 'bike':
      return EdgeType.bike;
    case 'road':
      return EdgeType.road;
    case 'walk':
    default:
      return EdgeType.walk;
  }
}

/// Node id format matches the 7-decimal rounding in the Python exporter.
/// Stable string keys survive isolate transfer cheaper than two-field
/// composite keys.
String _nodeId(double lat, double lon) {
  return '${lat.toStringAsFixed(7)},${lon.toStringAsFixed(7)}';
}

class _MutableNode {
  final String id;
  final LatLng position;
  final List<PathEdge> edges = [];
  _MutableNode(this.id, this.position);
}
