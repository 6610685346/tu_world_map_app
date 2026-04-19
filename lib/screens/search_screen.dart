import 'package:flutter/material.dart';
import 'package:tu_world_map_app/models/building.dart';
import 'package:tu_world_map_app/models/building_type.dart';
import 'package:tu_world_map_app/screens/building_detail_screen.dart';
import 'package:tu_world_map_app/services/building_service.dart';
import 'package:tu_world_map_app/services/map_selection_service.dart';
import 'package:tu_world_map_app/services/recent_location_service.dart';
import 'package:tu_world_map_app/services/search_history_service.dart';
import 'package:tu_world_map_app/services/favorite_service.dart';

class SearchScreen extends StatefulWidget {
  final Function(int) onTabChange;

  const SearchScreen({super.key, required this.onTabChange});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // Services
  final BuildingService buildingService = BuildingService();
  final RecentLocationService recentService = RecentLocationService();
  final SearchHistoryService historyService = SearchHistoryService();

  final ScrollController _scrollController = ScrollController();

  // State
  String currentQuery = '';
  BuildingType? selectedType;

  List<Building> allBuildings = [];
  List<Building> filteredBuildings = [];
  List<Building> displayedBuildings = [];

  bool isLoading = true;
  bool isLoadingMore = false;

  static const int _buildingsPerPage = 20;
  int _currentPage = 0;

  // ================= INIT =================

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

  // ================= DATA =================

  Future<void> _loadBuildings() async {
    try {
      final data = await buildingService.getBuildings();

      if (mounted) {
        setState(() {
          allBuildings = data;
          filteredBuildings = data;
          _resetPagination();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading buildings: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _resetPagination() {
    _currentPage = 0;
    final end = _buildingsPerPage.clamp(0, filteredBuildings.length);
    displayedBuildings = filteredBuildings.take(end).toList();
  }

  void _loadMoreBuildings() {
    if (isLoadingMore || displayedBuildings.length >= filteredBuildings.length) {
      return;
    }

    setState(() => isLoadingMore = true);

    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() {
        _currentPage++;

        final start = _currentPage * _buildingsPerPage;
        final end = (start + _buildingsPerPage).clamp(
          0,
          filteredBuildings.length,
        );

        if (start < filteredBuildings.length) {
          displayedBuildings.addAll(filteredBuildings.sublist(start, end));
        }

        isLoadingMore = false;
      });
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreBuildings();
    }
  }

  // ================= SEARCH & FILTER =================

  void _search(String query) {
    currentQuery = query;
    _applyFilters(query: query);
  }

  void _applyFilters({String query = ''}) {
    setState(() {
      filteredBuildings = allBuildings.where((building) {
        final matchesSearch = building.name.toLowerCase().contains(
          query.toLowerCase(),
        );

        final matchesType =
            selectedType == null || building.type == selectedType;

        return matchesSearch && matchesType;
      }).toList();

      _resetPagination();
    });
  }

  void _filterByType(BuildingType type) {
    setState(() {
      selectedType = selectedType == type ? null : type;
      _applyFilters(query: currentQuery);
    });
  }

  // ================= UI HELPERS =================

  void _openBuildingDetail(Building building) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFDF6F0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: BuildingDetailScreen(
                building: building,
                onViewOnMap: () {
                  Navigator.of(sheetContext).pop(true);
                },
              ),
            );
          },
        );
      },
    ).then((result) {
      if (result == true) {
        recentService.add(building);
        MapSelectionService().select(building);
        widget.onTabChange(1);
      }
    });
  }

  Widget _buildFilterChip(BuildingType type) {
    final isSelected = selectedType == type;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(type.displayName),
        selected: isSelected,
        selectedColor: const Color(0xFFE60012),
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
        onSelected: (_) => _filterByType(type),
      ),
    );
  }

  Widget _buildBuildingCard(Building building) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _openBuildingDetail(building),

        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            building.imageUrl,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.image_not_supported,
              size: 40,
              color: Colors.grey,
            ),
          ),
        ),

        title: Text(
          building.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        subtitle: Text(building.type.displayName),

        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                building.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: Colors.red,
              ),
              onPressed: () {
                setState(() {
                  FavoriteService().toggle(building);
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.location_on),
              onPressed: () {
                recentService.add(building);
                MapSelectionService().select(building);
                widget.onTabChange(1);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "No buildings found",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text("Try adjusting your search or filters"),
        ],
      ),
    );
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6F0),
      appBar: AppBar(
        title: const Text("Search"),
        backgroundColor: const Color(0xFFFDF6F0),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Field
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    onChanged: _search,
                    onSubmitted: (value) => historyService.add(value),
                    decoration: InputDecoration(
                      hintText: "Search building...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: BuildingType.values
                        .map((type) => _buildFilterChip(type))
                        .toList(),
                  ),
                ),

                const SizedBox(height: 8),

                // Result Count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "${filteredBuildings.length} building${filteredBuildings.length != 1 ? 's' : ''} found",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Results
                Expanded(
                  child: filteredBuildings.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount:
                              displayedBuildings.length +
                              (isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == displayedBuildings.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final building = displayedBuildings[index];

                            return _buildBuildingCard(building);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
