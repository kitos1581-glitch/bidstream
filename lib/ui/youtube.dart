/// Extrae el ID de un video/directo de YouTube de casi cualquier formato:
/// youtube.com/watch?v=ID, youtu.be/ID, youtube.com/live/ID,
/// youtube.com/embed/ID, youtube.com/shorts/ID.
String? youtubeIdFrom(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return null;
  final host = uri.host.replaceFirst(RegExp(r'^(www|m)\.'), '');
  if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
    return uri.pathSegments.first;
  }
  if (host.endsWith('youtube.com')) {
    final v = uri.queryParameters['v'];
    if (v != null && v.isNotEmpty) return v;
    final seg = uri.pathSegments;
    if (seg.length >= 2 && ['live', 'embed', 'shorts'].contains(seg[0])) {
      return seg[1];
    }
  }
  return null;
}
