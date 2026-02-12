import 'package:flutter/material.dart';
import '../services/recent_location_service.dart';
import '../services/building_service.dart';
import '../services/map_selection_service.dart';
import '../models/building_type.dart';
import '../models/building.dart';

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

  void _loadRecent() {
    setState(() {
      recent = RecentLocationService().getRecent();
    });
  }

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
      appBar: AppBar(title: const Text('Home')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              /// View Map Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onTabChange(1); // Map tab index
                  },
                  child: const Text("View Map"),
                ),
              ),

              const SizedBox(height: 10),

              /// Search Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onTabChange(2); // Search tab index
                  },
                  child: const Text("Search"),
                ),
              ),

              const SizedBox(height: 30),

              /// Recent Locations
              const Text(
                "Recent Locations",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              RecentLocationsSection(onTabChange: widget.onTabChange),

              const SizedBox(height: 30),

              /// Popular Locations
              const Text(
                "Popular Locations",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              const PopularLocationsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

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

    if (recent.isEmpty) {
      return const Text("No recent locations.");
    }

    return Column(
      children: recent.map((building) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.history),
            title: Text(building.name),
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

class PopularLocationsSection extends StatefulWidget {
  const PopularLocationsSection({super.key});

  @override
  State<PopularLocationsSection> createState() =>
      _PopularLocationsSectionState();
}

class _PopularLocationsSectionState extends State<PopularLocationsSection> {
  final BuildingService buildingService = BuildingService();
  List<Building> popular = [];

  @override
  void initState() {
    super.initState();
    _loadPopular();
  }

  void _loadPopular() async {
    final all = await buildingService.getBuildings();
    setState(() {
      popular = all.take(3).toList();
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
          child: ListTile(
            leading: const Icon(Icons.location_on),
            title: Text(building.name),
            subtitle: Text(building.type.displayName),
          ),
        );
      }).toList(),
    );
  }
}
