import '../data/map_location.dart';

class SearchService {
  static List<Map<String, dynamic>> search(String keyword) {
    if (keyword.isEmpty) return buildings;

    return buildings.where((b) {
      final text =
          (b['name'] + b['description']).toLowerCase();
      return text.contains(keyword.toLowerCase());
    }).toList();
  }
}