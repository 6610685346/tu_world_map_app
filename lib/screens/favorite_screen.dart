import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:tu_world_map_app/services/favorite_service.dart';
import 'package:tu_world_map_app/services/map_selection_service.dart';
import 'package:tu_world_map_app/models/building.dart';
import 'package:tu_world_map_app/models/building_type.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  final FavoriteService _favoriteService = FavoriteService();

  @override
  Widget build(BuildContext context) {
    final List<Building> favorites = _favoriteService.getFavorites();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF5), // Warm cream background
        elevation: 0,
        toolbarHeight: 90,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Favorites',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6D4C41), // Warm brown
              ),
            ),
            Text(
              '${favorites.length} saved location${favorites.length != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF5D4037), // Dark warm brown
              ),
            ),
          ],
        ),
      ),
      body: Container(
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
        child: favorites.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 80,
                      color: Color(
                        0xFFD32F2F,
                      ).withValues(alpha: 0.3), // Light red
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Favorites Yet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E2723), // Very dark brown
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start adding your favorite locations!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF5D4037), // Warm brown
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to search or map
                      },
                      icon: Icon(Icons.search),
                      label: Text('Explore Locations'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F), // Red
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        elevation: 3,
                        shadowColor: Colors.red.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final building = favorites[index];
                  return Dismissible(
                    key: Key(building.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) {
                      setState(() {
                        _favoriteService.remove(building);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${building.name} removed from favorites',
                          ),
                          backgroundColor: Color(0xFFD32F2F),
                          behavior: SnackBarBehavior.floating,
                          action: SnackBarAction(
                            label: 'UNDO',
                            textColor: Colors.white,
                            onPressed: () {
                              setState(() {
                                _favoriteService.toggle(building);
                              });
                            },
                          ),
                        ),
                      );
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Color(0xFFD32F2F), // Red
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.delete, color: Colors.white, size: 28),
                    ),
                    child: Card(
                      color: Colors.white.withValues(alpha: 0.9),
                      elevation: 2,
                      shadowColor: Colors.red.withValues(alpha: 0.2),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Color(0xFFD32F2F).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.favorite,
                            color: Color(0xFFD32F2F), // Red
                            size: 24,
                          ),
                        ),
                        title: Text(
                          building.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF3E2723), // Very dark brown
                          ),
                        ),
                        subtitle: Text(
                          building.type.displayName,
                          style: const TextStyle(
                            color: Color(0xFF5D4037), // Warm brown
                            fontSize: 14,
                          ),
                        ),
                        trailing: Icon(
                          CupertinoIcons.chevron_right,
                          color: Color(0xFF8D6E63), // Light brown
                          size: 20,
                        ),
                        onTap: () {
                          MapSelectionService().select(building);
                          // Navigate to map - you can implement this
                          // For now, just selecting the building
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
