import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<void> _launchWebImage() async {
    if (widget.building.imageUrl.isEmpty) return;
    
    final Uri url = Uri.parse(widget.building.imageUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open image link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = FavoriteService().isFavorite(widget.building);
    // Is it likely an HTML page like ibb.co?
    final bool isWebLink = widget.building.imageUrl.contains('ibb.co') || 
                           (!widget.building.imageUrl.endsWith('.png') && 
                            !widget.building.imageUrl.endsWith('.jpg') && 
                            !widget.building.imageUrl.endsWith('.jpeg'));

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      body: SafeArea(
        child: FutureBuilder<BuildingDetail>(
          future: detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.red));
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
                            color: const Color(0xFFD32F2F),
                          ),
                          onPressed: widget.onViewOnMap,
                        ),

                        Expanded(
                            child: Text(
                              widget.building.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3E2723),
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ),

                        // Favorite button
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: const Color(0xFFD32F2F),
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
                  if (widget.building.imageUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: isWebLink
                            ? Container(
                                width: double.infinity,
                                height: 180,
                                color: Colors.grey.withValues(alpha: 0.2),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.image, size: 64, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _launchWebImage,
                                      icon: const Icon(Icons.open_in_browser),
                                      label: const Text('View Full Image on Web'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFD32F2F),
                                        foregroundColor: Colors.white,
                                      ),
                                    )
                                  ],
                                ),
                              )
                            : Image.network(
                                widget.building.imageUrl,
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      height: 220,
                                      width: double.infinity,
                                      color: Colors.grey.withValues(alpha: 0.2),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                                          const SizedBox(height: 8),
                                          ElevatedButton.icon(
                                            onPressed: _launchWebImage,
                                            icon: const Icon(Icons.open_in_browser),
                                            label: const Text('Open in Browser'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFD32F2F),
                                              foregroundColor: Colors.white,
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                              ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _infoTile(Icons.access_time, detail.time),
                        _infoTile(Icons.place, detail.detail),
                        _infoTile(Icons.phone, detail.contact),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFD32F2F)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF5D4037),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
