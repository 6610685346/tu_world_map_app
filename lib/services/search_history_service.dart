class SearchHistoryService {
  static final SearchHistoryService _instance =
      SearchHistoryService._internal();

  factory SearchHistoryService() {
    return _instance;
  }

  SearchHistoryService._internal();

  final List<String> _history = [];

  List<String> getHistory() {
    return _history.reversed.take(5).toList();
  }

  void add(String query) {
    if (query.trim().isEmpty) return;

    _history.remove(query);
    _history.add(query);
  }

  void clear() {
    _history.clear();
  }
}
