import 'package:flutter/material.dart';

import 'package:tu_world_map_app/models/path_node.dart' show TravelMode;

/// Persistent bottom panel shown after the user taps "Directions" on a
/// selected building, before they actually start navigating.
///
/// Mirrors the Google Maps preview pattern: the route is already drawn
/// on the map, this panel shows the trip summary (distance, ETA), the
/// active travel mode, and primary "Start" / secondary "Change start"
/// actions.
class RoutePreviewPanel extends StatelessWidget {
  /// Origin label. `null` means "My Location" (current GPS).
  final String? originLabel;
  final String destinationLabel;
  final String? destinationTypeLabel;
  final double distanceMeters;
  final Duration eta;
  final TravelMode mode;

  /// Whether the route can actually be navigated. False when origin is
  /// a building other than the user's current location — in that case
  /// the panel is purely informational.
  final bool canStartNavigation;

  final VoidCallback onStart;
  final VoidCallback onClose;
  final VoidCallback onChangeStart;
  final ValueChanged<TravelMode> onModeChanged;

  const RoutePreviewPanel({
    super.key,
    required this.originLabel,
    required this.destinationLabel,
    required this.destinationTypeLabel,
    required this.distanceMeters,
    required this.eta,
    required this.mode,
    required this.canStartNavigation,
    required this.onStart,
    required this.onClose,
    required this.onChangeStart,
    required this.onModeChanged,
  });

  static const _primary = Color(0xFFD32F2F);
  static const _darkBrown = Color(0xFF3E2723);
  static const _muted = Color(0xFF8D6E63);
  static const _cream = Color(0xFFFFFBF5);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Material(
      color: _cream,
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildSummaryRow(),
            const SizedBox(height: 12),
            _buildModeChips(),
            const SizedBox(height: 14),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                destinationLabel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _darkBrown,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (destinationTypeLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    destinationTypeLabel!,
                    style: const TextStyle(fontSize: 13, color: _muted),
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.trip_origin, size: 14, color: Color(0xFF4CAF50)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'From ${originLabel ?? "My Location"}',
                      style: const TextStyle(fontSize: 13, color: _muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close preview',
          icon: const Icon(Icons.close, color: _muted),
          onPressed: onClose,
        ),
      ],
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      children: [
        Text(
          _formatEta(eta),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _primary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '· ${_formatDistance(distanceMeters)}',
          style: const TextStyle(fontSize: 15, color: _muted),
        ),
      ],
    );
  }

  Widget _buildModeChips() {
    return Wrap(
      spacing: 8,
      children: [
        _ModeChip(
          icon: Icons.directions_walk,
          label: 'Walk',
          selected: mode == TravelMode.walk,
          onTap: () => onModeChanged(TravelMode.walk),
        ),
        _ModeChip(
          icon: Icons.directions_bike,
          label: 'Bike',
          selected: mode == TravelMode.bike,
          onTap: () => onModeChanged(TravelMode.bike),
        ),
        _ModeChip(
          icon: Icons.directions_car,
          label: 'Car',
          selected: mode == TravelMode.car,
          onTap: () => onModeChanged(TravelMode.car),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: canStartNavigation ? onStart : null,
              icon: const Icon(Icons.navigation, color: Colors.white),
              label: const Text(
                'Start',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onChangeStart,
            icon: const Icon(Icons.swap_calls, color: _primary, size: 18),
            label: const Text(
              'Change start',
              style: TextStyle(color: _primary, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Public formatters so other UI surfaces (e.g. the navigating bar in
  /// MapScreen) can reuse the same conventions.
  static String formatDistance(double meters) => _formatDistance(meters);
  static String formatEta(Duration d) => _formatEta(d);

  static String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  static String _formatEta(Duration d) {
    if (d.inMinutes < 1) return '<1 min';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : RoutePreviewPanel._darkBrown;
    final bg =
        selected ? RoutePreviewPanel._primary : Colors.white;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? RoutePreviewPanel._primary
                : RoutePreviewPanel._muted.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
