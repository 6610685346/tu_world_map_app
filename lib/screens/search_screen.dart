import 'package:flutter/material.dart';
import 'package:tu_world_map_app/services/building_service.dart';
import 'package:tu_world_map_app/services/recent_location_service.dart';
import 'package:tu_world_map_app/models/building.dart';
import 'package:tu_world_map_app/services/search_history_service.dart';
import 'package:tu_world_map_app/services/map_selection_service.dart';
import "package:tu_world_map_app/models/building_type.dart";

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
  BuildingType? selectedType;

  List<Building> allBuildings = [];
  List<Building> filteredBuildings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  void _filterByType(BuildingType type) {
    setState(() {
      if (selectedType == type) {
        selectedType = null; // toggle off
      } else {
        selectedType = type;
      }

      _applyFilters(query: currentQuery);
    });
  }

  Widget _buildFilterChip(BuildingType type) {
    final isSelected = selectedType == type;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          type.displayName,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF3E2723),
          ),
        ),
        selected: isSelected,
        selectedColor: const Color(0xFFD32F2F), // Red
        backgroundColor: Colors.white.withOpacity(0.7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFFD32F2F)
                : const Color(0xFFFFCDD2),
          ),
        ),
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E2723), // Very dark brown
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...history.map((query) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.white.withOpacity(0.7),
              elevation: 1,
              shadowColor: Colors.red.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.history,
                  color: Color(0xFFD32F2F), // Red
                ),
                title: Text(
                  query,
                  style: const TextStyle(
                    color: Color(0xFF3E2723), // Dark brown
                  ),
                ),
                onTap: () {
                  _search(query);
                },
              ),
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
  Widget build(BuildContext) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF6D4C41), // Brighter brown
          ),
        ),
        backgroundColor: const Color(0xFFFFFBF5), // Almost white with warm hint
        elevation: 0,
      ),
      body: Container(
        // Subtle warm gradient background
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFFBF5), // Almost white with warm hint
              const Color(0xFFFFF8F0), // Very light cream
              const Color(0xFFFFF3E8), // Subtle warm white
            ],
          ),
        ),
        child: isLoading
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
                      style: const TextStyle(
                        color: Color(0xFF3E2723), // Dark brown
                      ),
                      decoration: InputDecoration(
                        hintText: "Search building...",
                        hintStyle: TextStyle(
                          color: const Color(0xFF3E2723).withOpacity(0.5),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFFD32F2F), // Red
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFFFCDD2), // Light red
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFFFCDD2), // Light red
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFD32F2F), // Red
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),

                  //Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: BuildingType.values.map((type) {
                        return _buildFilterChip(type);
                      }).toList(),
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
                            color: Colors.white.withOpacity(0.9),
                            elevation: 2,
                            shadowColor: Colors.red.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  building.imageUrl,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFFCDD2,
                                        ).withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        size: 30,
                                        color: Color(0xFFD32F2F),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              title: Text(
                                building.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3E2723), // Very dark brown
                                ),
                              ),
                              subtitle: Text(
                                building.type.displayName,
                                style: const TextStyle(
                                  color: Color(0xFF5D4037), // Dark warm brown
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      building.isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: const Color(0xFFD32F2F), // Red
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        building.isFavorite =
                                            !building.isFavorite;
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.location_on,
                                      color: Color(0xFFD32F2F), // Red
                                    ),
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
      ),
    );
  }
}
