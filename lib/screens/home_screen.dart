import 'package:flutter/material.dart';
import '../services/recent_location_service.dart';
import '../models/building.dart';

class HomeScreen extends StatelessWidget {
  final Function(int) onTabChange;
  const HomeScreen({super.key, required this.onTabChange});

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
                    onTabChange(1); // Map tab index
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
                    onTabChange(2); // Search tab index
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

              const RecentLocationsSection(),

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
  const RecentLocationsSection({super.key});

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
          ),
        );
      }).toList(),
    );
  }
}

class PopularLocationsSection extends StatelessWidget {
  const PopularLocationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final popular = ["Cafeteria", "Main Hall", "Auditorium"];

    return Column(
      children: popular.map((name) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.location_on),
            title: Text(name),
          ),
        );
      }).toList(),
    );
  }
}
