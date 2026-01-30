import '../data/map_location.dart';

class SearchService {
  static List<Map<String, dynamic>> search(String query) {
    if (query.isEmpty) return buildings;

    return buildings.where((b) {
      return b['name']
          .toString()
          .toLowerCase()
          .contains(query.toLowerCase());
    }).toList();
  }
}