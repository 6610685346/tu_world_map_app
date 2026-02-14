import 'package:logging/logging.dart';
import 'package:tu_world_map_app/models/building.dart';

class FavoriteService {
  final _log = Logger('FavoriteService');
  static final FavoriteService _instance = FavoriteService._internal();

  factory FavoriteService() {
    return _instance;
  }

  FavoriteService._internal();

  final List<Building> _favorites = [];

  void toggle(Building building) {
    if (isFavorite(building)) {
      _log.info("REMOVING FAVORITE: ${building.name}");
      _favorites.removeWhere((b) => b.id == building.id);
    } else {
      _log.info("ADDING FAVORITE: ${building.name}");
      _favorites.add(building);
    }
    _log.info("FAVORITES COUNT: ${_favorites.length}");
  }

  bool isFavorite(Building building) {
    return _favorites.any((b) => b.id == building.id);
  }

  void remove(Building building) {
    _log.info("REMOVING FAVORITE: ${building.name}");
    _favorites.removeWhere((b) => b.id == building.id);
  }

  List<Building> getFavorites() {
    return List.unmodifiable(_favorites);
  }
}
