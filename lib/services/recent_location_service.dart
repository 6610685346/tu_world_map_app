import 'package:logging/logging.dart';
import 'package:tu_world_map_app/models/building.dart';

class RecentLocationService {
  final _log = Logger('RecentLocationService');
  static final RecentLocationService _instance =
      RecentLocationService._internal();

  factory RecentLocationService() {
    return _instance;
  }

  RecentLocationService._internal();

  final List<Building> _recent = [];

  void add(Building building) {
    _log.info("ADDING RECENT: ${building.name}");

    _recent.removeWhere((b) => b.id == building.id);
    _recent.insert(0, building);

    _log.info("RECENT COUNT: ${_recent.length}");

    if (_recent.length > 10) {
      _recent.removeLast();
    }
  }

  List<Building> getRecent() {
    return List.unmodifiable(_recent);
  }
}
