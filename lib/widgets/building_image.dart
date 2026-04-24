import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tu_world_map_app/utils/image_url_resolver.dart';

class BuildingImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double errorIconSize;
  final String? errorActionLabel;
  final IconData? errorActionIcon;
  final VoidCallback? onErrorAction;

  const BuildingImage({
    super.key,
    required this.imageUrl,
    this.width = 50,
    this.height = 50,
    this.fit = BoxFit.cover,
    this.errorIconSize = 30,
    this.errorActionLabel,
    this.errorActionIcon,
    this.onErrorAction,
  });

  @override
  State<BuildingImage> createState() => _BuildingImageState();
}

class _BuildingImageState extends State<BuildingImage> {
  static const Color _accent = Color(0xFFD32F2F);
  static const Color _tint = Color(0xFF6D4C41);

  Future<String>? _resolvedUrl;

  @override
  void initState() {
    super.initState();
    if (ImageUrlResolver.needsResolution(widget.imageUrl)) {
      _resolvedUrl = ImageUrlResolver.resolve(widget.imageUrl);
    }
  }

  BoxDecoration get _tintedBg => BoxDecoration(
        color: _tint.withValues(alpha: 0.08),
      );

  Widget _placeholder() => Container(
        width: widget.width,
        height: widget.height,
        decoration: _tintedBg,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _accent,
            ),
          ),
        ),
      );

  Widget _error() {
    final showAction =
        widget.onErrorAction != null && widget.errorActionLabel != null;

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: _tintedBg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: widget.errorIconSize,
            color: _tint.withValues(alpha: 0.6),
          ),
          if (showAction) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: widget.onErrorAction,
              icon: Icon(widget.errorActionIcon ?? Icons.open_in_browser),
              label: Text(widget.errorActionLabel!),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cachedImage(String url) => CachedNetworkImage(
        imageUrl: url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: (_, _) => _placeholder(),
        errorWidget: (_, _, _) => _error(),
      );

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.isEmpty) return _error();

    if (_resolvedUrl == null) {
      return _cachedImage(widget.imageUrl);
    }

    return FutureBuilder<String>(
      future: _resolvedUrl,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _placeholder();
        return _cachedImage(snapshot.data!);
      },
    );
  }
}
