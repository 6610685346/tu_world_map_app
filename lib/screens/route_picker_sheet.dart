import 'package:flutter/material.dart';
import 'package:tu_world_map_app/models/building.dart';
import 'package:tu_world_map_app/models/building_type.dart';

/// Result of route picker: origin building (null = current location) and destination building.
class RouteRequest {
  final Building? origin; // null means "My Location"
  final Building destination;

  const RouteRequest({this.origin, required this.destination});
}

/// A bottom sheet widget for configuring a custom A→B navigation route.
///
/// Allows the user to pick an origin (default "My Location") and
/// a destination building. Returns a [RouteRequest] when the user
/// taps "Start Navigation".
class RoutePickerSheet extends StatefulWidget {
  /// Pre-selected destination (e.g. the currently selected building).
  final Building? initialDestination;

  /// All buildings available for selection.
  final List<Building> buildings;

  const RoutePickerSheet({
    super.key,
    this.initialDestination,
    required this.buildings,
  });

  @override
  State<RoutePickerSheet> createState() => _RoutePickerSheetState();
}

class _RoutePickerSheetState extends State<RoutePickerSheet> {
  Building? _origin; // null = My Location
  Building? _destination;

  @override
  void initState() {
    super.initState();
    _destination = widget.initialDestination;
  }

  void _swap() {
    setState(() {
      final temp = _origin;
      _origin = _destination;
      _destination = temp;
    });
  }

  void _pickBuilding({required bool isOrigin}) async {
    final result = await showModalBottomSheet<Building?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BuildingSearchPicker(
        buildings: widget.buildings,
        showMyLocation: isOrigin,
        title: isOrigin ? 'Select Origin' : 'Select Destination',
      ),
    );

    // result is null if user tapped "My Location" in origin mode
    // result is a Building if user selected one
    // If the sheet was dismissed (back/swipe), we do nothing
    if (!mounted) return;

    if (isOrigin) {
      setState(() => _origin = result);
    } else {
      if (result != null) {
        setState(() => _destination = result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBF5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          const Text(
            'Plan Your Route',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E2723),
            ),
          ),
          const SizedBox(height: 20),

          // From field
          Row(
            children: [
              // Timeline indicator
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4CAF50),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLocationTile(
                  label: 'From',
                  value: _origin?.name ?? 'My Location',
                  icon: _origin == null ? Icons.my_location : Icons.location_city,
                  iconColor: const Color(0xFF4CAF50),
                  onTap: () => _pickBuilding(isOrigin: true),
                ),
              ),
            ],
          ),

          // Swap button
          Padding(
            padding: const EdgeInsets.only(left: 0),
            child: Row(
              children: [
                const SizedBox(width: 18), // align with timeline
                IconButton(
                  onPressed: _swap,
                  icon: const Icon(Icons.swap_vert, color: Color(0xFF6D4C41)),
                  tooltip: 'Swap origin and destination',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                  ),
                ),
              ],
            ),
          ),

          // To field
          Row(
            children: [
              // Timeline indicator
              Column(
                children: [
                  Container(
                    width: 2,
                    height: 8,
                    color: Colors.grey.shade300,
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFD32F2F),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD32F2F).withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLocationTile(
                  label: 'To',
                  value: _destination?.name ?? 'Select destination',
                  icon: Icons.flag,
                  iconColor: const Color(0xFFD32F2F),
                  onTap: () => _pickBuilding(isOrigin: false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Start Navigation button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _destination != null
                  ? () {
                      Navigator.of(context).pop(
                        RouteRequest(origin: _origin, destination: _destination!),
                      );
                    }
                  : null,
              icon: const Icon(Icons.navigation, color: Colors.white),
              label: const Text(
                'Start Navigation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTile({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3E2723),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// Building Search Picker — a full-screen bottom sheet with search
// ================================================================

class _BuildingSearchPicker extends StatefulWidget {
  final List<Building> buildings;
  final bool showMyLocation;
  final String title;

  const _BuildingSearchPicker({
    required this.buildings,
    required this.showMyLocation,
    required this.title,
  });

  @override
  State<_BuildingSearchPicker> createState() => _BuildingSearchPickerState();
}

class _BuildingSearchPickerState extends State<_BuildingSearchPicker> {
  String _query = '';

  List<Building> get _filtered {
    if (_query.isEmpty) return widget.buildings;
    return widget.buildings
        .where((b) => b.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBF5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E2723),
                  ),
                ),
              ),

              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search building...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              // Results
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _filtered.length + (widget.showMyLocation ? 1 : 0),
                  itemBuilder: (context, index) {
                    // "My Location" option at the top for origin picker
                    if (widget.showMyLocation && index == 0) {
                      return ListTile(
                        leading: const Icon(
                          Icons.my_location,
                          color: Color(0xFF4CAF50),
                        ),
                        title: const Text(
                          'My Location',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text('Use current GPS position'),
                        onTap: () => Navigator.of(context).pop(null),
                      );
                    }

                    final buildingIndex = widget.showMyLocation ? index - 1 : index;
                    final building = _filtered[buildingIndex];

                    return ListTile(
                      leading: const Icon(
                        Icons.location_city,
                        color: Color(0xFF6D4C41),
                      ),
                      title: Text(
                        building.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(building.type.displayName),
                      onTap: () => Navigator.of(context).pop(building),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
