import 'package:flutter/material.dart';
import 'package:tu_world_map_app/models/building.dart';
import 'package:tu_world_map_app/models/building_detail.dart';
import 'package:tu_world_map_app/services/building_detail_service.dart';
import 'package:tu_world_map_app/services/favorite_service.dart';

class BuildingDetailScreen extends StatefulWidget {
  final Building building;
  final VoidCallback onViewOnMap;

  const BuildingDetailScreen({
    super.key,
    required this.building,
    required this.onViewOnMap,
  });

  @override
  State<BuildingDetailScreen> createState() => _BuildingDetailScreenState();
}

class _BuildingDetailScreenState extends State<BuildingDetailScreen> {
  late Future<BuildingDetail> detailFuture;

  @override
  void initState() {
    super.initState();
    detailFuture = BuildingDetailService().getDetail(widget.building.id);
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = FavoriteService().isFavorite(widget.building);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF6F0),
      body: SafeArea(
        child: FutureBuilder<BuildingDetail>(
          future: detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData) {
              return const Center(child: Text("Failed to load detail"));
            }

            final detail = snapshot.data!;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TOP BAR
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        // Map button
                        IconButton(
                          icon: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                          ),
                          onPressed: widget.onViewOnMap,
                        ),

                        Expanded(
                          child: Center(
                            child: Text(
                              widget.building.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                        // Favorite button
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            setState(() {
                              FavoriteService().toggle(widget.building);
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // IMAGE
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      widget.building.imageUrl,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.image_not_supported, size: 100),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _infoTile(Icons.access_time, detail.openingTime),
                        _infoTile(Icons.place, detail.address),
                        _infoTile(Icons.phone, detail.phone),
                        _infoTile(Icons.public, detail.facebook),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, color: Colors.red),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
