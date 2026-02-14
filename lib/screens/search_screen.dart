import 'package:flutter/material.dart';
import 'package:tu_world_map_app/services/building_service.dart';
import 'package:tu_world_map_app/services/recent_location_service.dart';
import 'package:tu_world_map_app/models/building.dart';
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
  final ScrollController _scrollController = ScrollController();

  String currentQuery = '';
  BuildingType? selectedType;

  List<Building> allBuildings = [];
  List<Building> filteredBuildings = [];
  List<Building> displayedBuildings = []; // Buildings currently shown
  bool isLoading = true;
  bool isLoadingMore = false;

  static const int _buildingsPerPage = 20;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreBuildings();
    }
  }

  void _loadMoreBuildings() {
    if (isLoadingMore ||
        displayedBuildings.length >= filteredBuildings.length) {
      return;
    }

    setState(() {
      isLoadingMore = true;
    });

    // Simulate a small delay for smooth UX
    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        _currentPage++;
        final startIndex = _currentPage * _buildingsPerPage;
        final endIndex = (startIndex + _buildingsPerPage).clamp(
          0,
          filteredBuildings.length,
        );

        if (startIndex < filteredBuildings.length) {
          displayedBuildings.addAll(
            filteredBuildings.sublist(startIndex, endIndex),
          );
        }

        isLoadingMore = false;
      });
    });
  }

  void _resetPagination() {
    _currentPage = 0;
    final endIndex = _buildingsPerPage.clamp(0, filteredBuildings.length);
    displayedBuildings = filteredBuildings.take(endIndex).toList();
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

  Future<void> _loadBuildings() async {
    final data = await buildingService.getBuildings();
    setState(() {
      allBuildings = data;
      filteredBuildings = data;
      _resetPagination();
      isLoading = false;
    });
  }

  void _search(String query) {
    currentQuery = query;

    setState(() {
      _applyFilters(query: query);
      _resetPagination();
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

    _resetPagination();
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
                            color: Color(0xFFEF5350), // Darker red
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFEF5350), // Darker red
                            width: 1.5,
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

                  // Building count indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      '${filteredBuildings.length} building${filteredBuildings.length != 1 ? 's' : ''} found',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF5D4037).withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Buildings List - Always visible
                  Expanded(
                    child: filteredBuildings.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: const Color(
                                    0xFFD32F2F,
                                  ).withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No buildings found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3E2723),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try adjusting your search or filters',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color(
                                      0xFF5D4037,
                                    ).withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount:
                                displayedBuildings.length +
                                (isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Show loading indicator at the bottom
                              if (index == displayedBuildings.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFFD32F2F),
                                    ),
                                  ),
                                );
                              }

                              final building = displayedBuildings[index];

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
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFFFFCDD2,
                                                ).withOpacity(0.3),
                                                borderRadius:
                                                    BorderRadius.circular(8),
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
                                      color: Color(
                                        0xFF3E2723,
                                      ), // Very dark brown
                                    ),
                                  ),
                                  subtitle: Text(
                                    building.type.displayName,
                                    style: const TextStyle(
                                      color: Color(
                                        0xFF5D4037,
                                      ), // Dark warm brown
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
                                          MapSelectionService().select(
                                            building,
                                          );
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
