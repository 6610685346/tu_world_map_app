import '../models/building.dart';

class RecentLocationService {
  static final RecentLocationService _instance =
      RecentLocationService._internal();

  factory RecentLocationService() {
    return _instance;
  }

  RecentLocationService._internal();

  final List<Building> _recent = [];

  List<Building> getRecent() {
    return _recent.reversed.take(3).toList();
  }

  void add(Building building) {
    _recent.removeWhere((b) => b.id == building.id);
    _recent.add(building);
  }
}
