import 'package:flutter/material.dart';
import 'package:tu_world_map_app/models/building.dart';
import 'package:tu_world_map_app/models/building_type.dart';
import 'package:tu_world_map_app/screens/building_detail_screen.dart';
import 'package:tu_world_map_app/services/building_service.dart';
import 'package:tu_world_map_app/services/map_selection_service.dart';
import 'package:tu_world_map_app/services/recent_location_service.dart';
import 'package:tu_world_map_app/services/search_history_service.dart';
import 'package:tu_world_map_app/services/favorite_service.dart';
import 'package:tu_world_map_app/widgets/building_image.dart';

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
    FavoriteService().addListener(_syncFavorites);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    FavoriteService().removeListener(_syncFavorites);
    super.dispose();
  }

  // ================= DATA =================

  Future<void> _loadBuildings() async {
    try {
      final data = await buildingService.getBuildings();

      // Sync favorite status from FavoriteService
      for (var building in data) {
        building.isFavorite = FavoriteService().isFavorite(building);
      }

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

  void _syncFavorites() {
    if (mounted) {
      setState(() {
        for (var building in allBuildings) {
          building.isFavorite = FavoriteService().isFavorite(building);
        }
      });
    }
  }

  void _resetPagination() {
    _currentPage = 0;
    final end = _buildingsPerPage.clamp(0, filteredBuildings.length);
    displayedBuildings = filteredBuildings.take(end).toList();
  }

  void _loadMoreBuildings() {
    if (isLoadingMore ||
        displayedBuildings.length >= filteredBuildings.length) {
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
                color: Color(0xFFFFFBF5),
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
        selectedColor: const Color(0xFFD32F2F),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF5D4037),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFFD32F2F)
                : const Color(0xFFD7CCC8),
          ),
        ),
        onSelected: (_) => _filterByType(type),
      ),
    );
  }

  Widget _buildBuildingCard(Building building) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shadowColor: const Color(0xFFD32F2F).withValues(alpha: 0.1),
      color: Colors.white.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _openBuildingDetail(building),

        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BuildingImage(imageUrl: building.imageUrl),
        ),

        title: Text(
          building.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E2723),
          ),
        ),

        subtitle: Text(
          building.type.displayName,
          style: const TextStyle(color: Color(0xFF5D4037)),
        ),

        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                building.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: const Color(0xFFD32F2F),
              ),
              onPressed: () {
                setState(() {
                  FavoriteService().toggle(building);
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.location_on, color: Color(0xFFD32F2F)),
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6D4C41),
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Try adjusting your search or filters",
            style: TextStyle(color: Color(0xFF8D6E63)),
          ),
        ],
      ),
    );
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      appBar: AppBar(
        title: const Text(
          "Search",
          style: TextStyle(
            color: Color(0xFF6D4C41),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFFFFBF5),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF6D4C41)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(
            height: 1,
            thickness: 1,
            color: const Color(0xFF6D4C41).withValues(alpha: 0.1),
          ),
        ),
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
                      hintStyle: const TextStyle(color: Color(0xFF8D6E63)),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFFD32F2F),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: Colors.brown.withValues(alpha: 0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(
                          color: Color(0xFFD32F2F),
                          width: 1.5,
                        ),
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
                        color: Color(0xFF8D6E63),
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
