/// No generic remote fallback is used for Explore imagery.
///
/// Returning `null` keeps generated exact places from silently substituting
/// stock photos when Google Places does not provide a grounded photo.
String? fallbackExploreImageUrlFor(Iterable<String?> _) => null;

/// Returns whether [value] is an HTTPS image URL that is suitable to render.
bool isUsableExploreImageUrl(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty || text.contains(RegExp(r'\s'))) {
    return false;
  }

  final uri = Uri.tryParse(text);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return false;
  }

  return !_isBlockedImageHost(uri.host);
}

bool _isBlockedImageHost(String host) {
  final normalizedHost = host.toLowerCase();
  return _blockedImageHosts.any(
    (blockedHost) =>
        normalizedHost == blockedHost ||
        normalizedHost.endsWith('.$blockedHost'),
  );
}

const List<String> _blockedImageHosts = [
  'example.com',
  'example.org',
  'example.net',
  'placeholder.com',
  'placehold.co',
  'picsum.photos',
  'loremflickr.com',
  'unsplash.com',
  'images.unsplash.com',
  'pexels.com',
  'images.pexels.com',
  'pixabay.com',
  'cdn.pixabay.com',
  'stock.adobe.com',
  'shutterstock.com',
  'istockphoto.com',
  'gettyimages.com',
  'localhost',
  '127.0.0.1',
];
