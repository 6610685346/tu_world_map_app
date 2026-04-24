import 'package:http/http.dart' as http;

class ImageUrlResolver {
  static final Map<String, String> _cache = {};

  static bool needsResolution(String url) =>
      _isDriveUrl(url) || _isIbbCoGallery(url);

  static bool _isDriveUrl(String url) => url.contains('drive.google.com');

  static bool _isIbbCoGallery(String url) =>
      url.contains('ibb.co') && !url.contains('i.ibb.co');

  static String? _tryResolveDrive(String url) {
    final fileId =
        RegExp(r'/file/d/([a-zA-Z0-9_-]+)').firstMatch(url)?.group(1) ??
        RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(url)?.group(1);
    if (fileId != null) {
      return 'https://drive.google.com/uc?export=view&id=$fileId';
    }
    return null;
  }

  static Future<String?> _tryResolveIbbCo(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        for (final pattern in [
          RegExp(r'property="og:image"\s+content="([^"]+)"'),
          RegExp(r'content="([^"]+)"\s+property="og:image"'),
        ]) {
          final m = pattern.firstMatch(response.body);
          if (m != null) return m.group(1);
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<String> resolve(String url) async {
    if (_cache.containsKey(url)) return _cache[url]!;

    String? resolved;
    if (_isDriveUrl(url)) {
      resolved = _tryResolveDrive(url);
    } else if (_isIbbCoGallery(url)) {
      resolved = await _tryResolveIbbCo(url);
    }

    final result = resolved ?? url;
    _cache[url] = result;
    return result;
  }
}
