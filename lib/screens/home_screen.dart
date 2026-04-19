import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:tu_world_map_app/services/recent_location_service.dart';
import 'package:tu_world_map_app/services/building_service.dart';
import 'package:tu_world_map_app/services/map_selection_service.dart';
import 'package:tu_world_map_app/models/building_type.dart';
import 'package:tu_world_map_app/models/building.dart';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  final Function(int) onTabChange;
  final int currentIndex;
  const HomeScreen({
    super.key,
    required this.onTabChange,
    required this.currentIndex,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If tab changed to Home (index 0)
    if (widget.currentIndex == 0 && oldWidget.currentIndex != 0) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF5),
        elevation: 0,
        toolbarHeight: 90,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TU World Map',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6D4C41),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Welcome back! Where would you like to go today?',
              style: TextStyle(fontSize: 14, color: Color(0xFF5D4037)),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBF5), Color(0xFFFFFBF5), Color(0xFFFFFBF5)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Quick Actions",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E2723),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    /// View Map
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => widget.onTabChange(1),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          elevation: 3,
                          shadowColor: Colors.red.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.location_solid, size: 28),
                            SizedBox(height: 6),
                            Text(
                              "View Map",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    /// Search
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => widget.onTabChange(2),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9800),
                          foregroundColor: const Color(0xFF3E2723),
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          elevation: 3,
                          shadowColor: Colors.orange.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search, size: 28),
                            SizedBox(height: 6),
                            Text(
                              "Search",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                const Text(
                  "Recent Locations",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E2723),
                  ),
                ),
                const SizedBox(height: 10),
                RecentLocationsSection(onTabChange: widget.onTabChange),

                const SizedBox(height: 40),

                const Text(
                  "Recommend Locations",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E2723),
                  ),
                ),
                const SizedBox(height: 10),
                PopularLocationsSection(onTabChange: widget.onTabChange),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//function to render recent locations and popular locations
//-----------------------------------------------------------------------------------------------------------------

//Render Locations
class RecentLocationsSection extends StatefulWidget {
  final Function(int) onTabChange;
  const RecentLocationsSection({super.key, required this.onTabChange});

  @override
  State<RecentLocationsSection> createState() => _RecentLocationsSectionState();
}

class _RecentLocationsSectionState extends State<RecentLocationsSection> {
  final RecentLocationService recentService = RecentLocationService();

  @override
  Widget build(BuildContext context) {
    final List<Building> recent = recentService.getRecent();
    final List<Building> latestThree = recent.take(3).toList();

    if (recent.isEmpty) {
      return const Text("No recent locations.");
    }

    return Column(
      children: latestThree.map((building) {
        return Card(
          color: Colors.white.withValues(alpha: 0.9),
          elevation: 2,
          shadowColor: Colors.red.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: const Icon(Icons.history, color: Color(0xFFD32F2F)),
            title: Text(
              building.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E2723),
              ),
            ),
            onTap: () {
              MapSelectionService().select(building);
              widget.onTabChange(1);
            },
          ),
        );
      }).toList(),
    );
  }
}

// Recommend Location
class PopularLocationsSection extends StatefulWidget {
  final Function(int) onTabChange;

  const PopularLocationsSection({super.key, required this.onTabChange});

  @override
  State<PopularLocationsSection> createState() =>
      _PopularLocationsSectionState();
}

class _PopularLocationsSectionState extends State<PopularLocationsSection> {
  final BuildingService buildingService = BuildingService();
  final RecentLocationService recentService = RecentLocationService();
  List<Building> popular = [];

  @override
  void initState() {
    super.initState();
    _loadPopular();
  }

  void _loadPopular() async {
    final all = await buildingService.getBuildings();
    final shuffled = List.of(all)..shuffle();
    setState(() {
      popular = shuffled.take(min(3, shuffled.length)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (popular.isEmpty) {
      return const Text("No popular locations.");
    }

    return Column(
      children: popular.map((building) {
        return Card(
          color: Colors.white.withValues(alpha: 0.9),
          elevation: 2,
          shadowColor: Colors.red.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: const Icon(Icons.location_on, color: Color(0xFFD32F2F)),
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
            onTap: () {
              recentService.add(building);
              MapSelectionService().select(building);
              widget.onTabChange(1);
            },
          ),
        );
      }).toList(),
    );
  }
}
