import 'package:flutter/material.dart';
import '../services/building_service.dart';
import '../services/recent_location_service.dart';
import '../models/building.dart';
import '../services/search_history_service.dart';
import '../services/map_selection_service.dart';

class SearchScreen extends StatefulWidget {
  final Function(int) onTabChange;

  const SearchScreen({super.key, required this.onTabChange});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final BuildingService buildingService = BuildingService();
  final RecentLocationService recentService = RecentLocationService();
  final SearchHistoryService historyService = SearchHistoryService();
  String currentQuery = '';
  String? selectedType;

  List<Building> allBuildings = [];
  List<Building> filteredBuildings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  void _filterByType(String? type) {
    setState(() {
      if (selectedType == type) {
        selectedType = null; // toggle off
      } else {
        selectedType = type;
      }

      _applyFilters();
    });
  }

  Widget _buildFilterChip(String type) {
    final isSelected = selectedType == type;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(type.toUpperCase()),
        selected: isSelected,
        onSelected: (_) => _filterByType(type),
      ),
    );
  }

  Widget _buildHistorySection() {
    final history = historyService.getHistory();

    if (history.isEmpty) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Recent Searches",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...history.map((query) {
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(query),
              onTap: () {
                _search(query);
              },
            );
          }),
        ],
      ),
    );
  }

  Future<void> _loadBuildings() async {
    final data = await buildingService.getBuildings();
    setState(() {
      allBuildings = data;
      filteredBuildings = data;
      isLoading = false;
    });
  }

  void _search(String query) {
    currentQuery = query;

    setState(() {
      _applyFilters(query: query);
    });
  }

  void _applyFilters({String query = ''}) {
    filteredBuildings = allBuildings.where((building) {
      final matchesSearch = building.name.toLowerCase().contains(
        query.toLowerCase(),
      );

      final matchesType = selectedType == null || building.type == selectedType;

      return matchesSearch && matchesType;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    onChanged: _search,
                    onSubmitted: (value) {
                      historyService.add(value);
                      setState(() {});
                    },
                    decoration: const InputDecoration(
                      hintText: "Search building...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

                //Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _buildFilterChip("academic"),
                      _buildFilterChip("gym"),
                      _buildFilterChip("restaurant"),
                    ],
                  ),
                ),

                if (currentQuery.isEmpty) _buildHistorySection(),

                // Results List
                if (currentQuery.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredBuildings.length,
                      itemBuilder: (context, index) {
                        final building = filteredBuildings[index];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: Image.network(
                              building.imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.image_not_supported,
                                  size: 40,
                                  color: Colors.grey,
                                );
                              },
                            ),
                            title: Text(building.name),
                            subtitle: Text(building.type),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    building.isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      building.isFavorite =
                                          !building.isFavorite;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.location_on),
                                  onPressed: () {
                                    recentService.add(building);
                                    MapSelectionService().select(building);
                                    setState(() {
                                      currentQuery = '';
                                    });
                                    widget.onTabChange(1);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
