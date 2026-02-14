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
  List<Building> recent = [];

  // void _loadRecent() {
  //   setState(() {
  //     recent = RecentLocationService().getRecent();
  //   });
  // }

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
      // ส่วนหัวของ App
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF5), // Almost white with warm hint
        elevation: 0,
        toolbarHeight: 90,
        title: Column(
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
            Text(
              'Welcome back! Where would you like to go today?',
              style: TextStyle(fontSize: 14, color: Color(0xFF5D4037)),
            ),
          ],
        ),
      ),

      // ส่วน body ของ App
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
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
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        constraints.maxHeight - 32, // Account for padding
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    // เนื้อหาในส่วน body
                    children: [
                      const Text(
                        "Quick Actions",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E2723), // Very dark brown
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          /// View Map Button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                widget.onTabChange(1); // Map tab index
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD32F2F), // Red
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 30,
                                ),
                                elevation: 3,
                                shadowColor: Colors.red.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(CupertinoIcons.location_solid, size: 28),
                                  SizedBox(height: 6),
                                  Text(
                                    "View Map",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          /// Search Button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                widget.onTabChange(2); // Search tab index
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFFFF9800,
                                ), // Orange
                                foregroundColor: Color.fromARGB(
                                  255,
                                  65,
                                  45,
                                  35,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 30,
                                ),
                                elevation: 3,
                                shadowColor: Colors.orange.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.search, size: 28),
                                  SizedBox(height: 6),
                                  Text(
                                    "Search",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        /// View Map Button
                      ),

                      const SizedBox(height: 30),

                      /// Recent Locations
                      const Text(
                        "Recent Locations",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E2723), // Very dark brown
                        ),
                      ),

                      const SizedBox(height: 10),

                      RecentLocationsSection(onTabChange: widget.onTabChange),

                      const SizedBox(height: 30),

                      /// Popular Locations
                      const Text(
                        "Popular Locations",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E2723), // Very dark brown
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
        },
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
      return const Text(
        "No recent locations.",
        style: TextStyle(color: Color(0xFF3E2723)),
      );
    }

    return Column(
      children: latestThree.map((building) {
        return Card(
          color: Colors.white.withOpacity(0.9),
          elevation: 2,
          shadowColor: Colors.red.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: const Icon(
              Icons.history,
              color: Color(0xFFD32F2F), // Red
            ),
            title: Text(
              building.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E2723), // Very dark brown
              ),
            ),
            onTap: () {
              MapSelectionService().select(building);
              widget.onTabChange(1); // open Map tab
            },
          ),
        );
      }).toList(),
    );
  }
}

// Popular Location
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
      return const Text(
        "No popular locations.",
        style: TextStyle(color: Color(0xFF3E2723)),
      );
    }

    return Column(
      children: popular.map((building) {
        return Card(
          color: Colors.white.withOpacity(0.9),
          elevation: 2,
          shadowColor: Colors.red.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: const Icon(
              Icons.location_on,
              color: Color(0xFFD32F2F), // Red
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
                color: Color(0xFF5D4037), // Warm brown
              ),
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
