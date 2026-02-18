import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:tu_world_map_app/models/building.dart';
import 'package:tu_world_map_app/models/building_type.dart';
import 'package:tu_world_map_app/services/favorite_service.dart';
import 'package:tu_world_map_app/services/map_selection_service.dart';

class FavoriteScreen extends StatefulWidget {
  final Function(int) onTabChange;

  const FavoriteScreen({super.key, required this.onTabChange});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  final FavoriteService _favoriteService = FavoriteService();

  static const _cream = Color(0xFFFFFBF5);
  static const _lightCream = Color(0xFFFFF8F0);
  static const _lighterCream = Color(0xFFFFF3E8);
  static const _primaryRed = Color(0xFFD32F2F);
  static const _darkBrown = Color(0xFF3E2723);
  static const _brown = Color(0xFF5D4037);
  static const _lightBrown = Color(0xFF8D6E63);

  @override
  void initState() {
    super.initState();
    _favoriteService.addListener(_refresh);
  }

  @override
  void dispose() {
    _favoriteService.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final favorites = _favoriteService.getFavorites();

    return Scaffold(
      backgroundColor: _cream,
      appBar: _buildAppBar(favorites.length),
      body: _buildBody(favorites),
    );
  }

  /// =====================
  /// App Bar
  /// =====================
  AppBar _buildAppBar(int count) {
    return AppBar(
      backgroundColor: _cream,
      elevation: 0,
      toolbarHeight: 90,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Favorites',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6D4C41),
            ),
          ),
          Text(
            '$count saved location${count != 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 14, color: _brown),
          ),
        ],
      ),
    );
  }

  /// =====================
  /// Body
  /// =====================
  Widget _buildBody(List<Building> favorites) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_cream, _lightCream, _lighterCream],
        ),
      ),
      child: favorites.isEmpty
          ? _buildEmptyState()
          : _buildFavoritesList(favorites),
    );
  }

  /// =====================
  /// Empty State
  /// =====================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: _primaryRed.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Favorites Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _darkBrown,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start adding your favorite locations!',
            style: TextStyle(fontSize: 16, color: _brown),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => widget.onTabChange(2),
            icon: const Icon(Icons.search),
            label: const Text('Explore Locations'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// =====================
  /// Favorites List
  /// =====================
  Widget _buildFavoritesList(List<Building> favorites) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final building = favorites[index];

        return Dismissible(
          key: Key(building.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) {
            _favoriteService.remove(building);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${building.name} removed from favorites'),
                backgroundColor: _primaryRed,
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'UNDO',
                  textColor: Colors.white,
                  onPressed: () {
                    _favoriteService.toggle(building);
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
              color: _primaryRed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete, color: Colors.white, size: 28),
          ),
          child: _buildFavoriteCard(building),
        );
      },
    );
  }

  Widget _buildFavoriteCard(Building building) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _primaryRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.favorite, color: _primaryRed, size: 24),
        ),
        title: Text(
          _favoriteService.getDisplayName(building),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: _darkBrown,
          ),
        ),
        subtitle: Text(
          building.type.displayName,
          style: const TextStyle(fontSize: 14, color: _brown),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.location_on_outlined,
                size: 22,
                color: _lightBrown,
              ),
              tooltip: "View on map",
              onPressed: () {
                MapSelectionService().select(building);
                widget.onTabChange(1);
              },
            ),
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                size: 20,
                color: _lightBrown,
              ),
              tooltip: "Rename",
              onPressed: () {
                _showRenameDialog(building);
              },
            ),
          ],
        ),

        onTap: () {
          MapSelectionService().select(building);
        },
      ),
    );
  }

  /// =====================
  /// Rename Dialog
  /// =====================
  void _showRenameDialog(Building building) {
    final controller = TextEditingController(
      text: _favoriteService.getDisplayName(building),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Rename Favorite"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Enter custom name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                _favoriteService.setCustomName(
                  building.id,
                  controller.text.trim(),
                );
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }
}
