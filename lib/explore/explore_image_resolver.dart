/// Deterministic fallback imagery for broad Explore suggestions.
///
/// These URLs are intentionally static: widgets can use them without any
/// resolver-side network calls, asset bundles, or platform-specific setup.
String fallbackExploreImageUrlFor(Iterable<String?> cues) {
  final cueText = _normalizedCueText(cues);
  if (cueText.isEmpty) return _generalBayAreaImageUrls.first;

  final category = _categoryFor(cueText);
  return _selectImageUrl(category.imageUrls, cueText);
}

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

const String _imageUrlSuffix = '?auto=format&fit=crop&w=1200&q=80';

final List<String> _foodImageUrls = [
  _unsplashImageUrl('photo-1504674900247-0877df9cc836'),
  _unsplashImageUrl('photo-1555939594-58d7cb561ad1'),
  _unsplashImageUrl('photo-1481833761820-0509d3217039'),
];

final List<String> _coffeeImageUrls = [
  _unsplashImageUrl('photo-1495474472287-4d71bcdd2085'),
  _unsplashImageUrl('photo-1509042239860-f550ce710b93'),
  _unsplashImageUrl('photo-1511920170033-f8396924c348'),
];

final List<String> _viewsImageUrls = [
  _unsplashImageUrl('photo-1500534314209-a25ddb2bd429'),
  _unsplashImageUrl('photo-1469474968028-56623f02e42e'),
  _unsplashImageUrl('photo-1506905925346-21bda4d32df4'),
];

final List<String> _outdoorsImageUrls = [
  _unsplashImageUrl('photo-1500530855697-b586d89ba3ee'),
  _unsplashImageUrl('photo-1441974231531-c6227db76b6e'),
  _unsplashImageUrl('photo-1501854140801-50d01698950b'),
];

final List<String> _cultureImageUrls = [
  _unsplashImageUrl('photo-1518998053901-5348d3961a04'),
  _unsplashImageUrl('photo-1541961017774-22349e4a1262'),
  _unsplashImageUrl('photo-1460661419201-fd4cecdf8a8b'),
];

final List<String> _waterfrontImageUrls = [
  _unsplashImageUrl('photo-1501594907352-04cda38ebc29'),
  _unsplashImageUrl('photo-1507525428034-b723cf961d3e'),
  _unsplashImageUrl('photo-1518837695005-2083093ee35b'),
];

final List<String> _oaklandImageUrls = [
  _unsplashImageUrl('photo-1519501025264-65ba15a82390'),
  _unsplashImageUrl('photo-1494526585095-c41746248156'),
  _unsplashImageUrl('photo-1465447142348-e9952c393450'),
];

final List<String> _berkeleyImageUrls = [
  _unsplashImageUrl('photo-1533929736458-ca588d08c8be'),
  _unsplashImageUrl('photo-1449034446853-66c86144b0ad'),
  _unsplashImageUrl('photo-1496307653780-42ee777d4833'),
];

final List<String> _transitImageUrls = [
  _unsplashImageUrl('photo-1544620347-c4fd4a3d5957'),
  _unsplashImageUrl('photo-1474487548417-781cb71495f3'),
  _unsplashImageUrl('photo-1494783367193-149034c05e8f'),
];

final List<String> _generalBayAreaImageUrls = [
  _unsplashImageUrl('photo-1501594907352-04cda38ebc29'),
  _unsplashImageUrl('photo-1449034446853-66c86144b0ad'),
  _unsplashImageUrl('photo-1533929736458-ca588d08c8be'),
];

final List<_ExploreImageCategory> _specificCategories = [
  _ExploreImageCategory(
    imageUrls: _oaklandImageUrls,
    keywords: [
      'oakland',
      'temescal',
      'rockridge',
      'jack london',
      'lake merritt',
      'piedmont ave',
      'grand lake',
      'uptown',
      'fruitvale',
      'old oakland',
    ],
  ),
  _ExploreImageCategory(
    imageUrls: _berkeleyImageUrls,
    keywords: [
      'berkeley',
      'uc berkeley',
      'cal',
      'telegraph',
      'elmwood',
      'northside',
      'gourmet ghetto',
      'gilman',
      'tilden',
      'fourth street',
      'westbrae',
    ],
  ),
  _ExploreImageCategory(
    imageUrls: _transitImageUrls,
    keywords: [
      'transit',
      'bart',
      'muni',
      'caltrain',
      'bus',
      'train',
      'station',
      'stations',
      'streetcar',
      'cable car',
      'rail',
      'shuttle',
    ],
  ),
  _ExploreImageCategory(
    imageUrls: _waterfrontImageUrls,
    keywords: [
      'waterfront',
      'ferry',
      'pier',
      'marina',
      'embarcadero',
      'shoreline',
      'harbor',
      'wharf',
      'ocean',
      'coast',
      'coastal',
      'boat',
      'sail',
    ],
  ),
  _ExploreImageCategory(
    imageUrls: _coffeeImageUrls,
    keywords: [
      'coffee',
      'cafe',
      'cafes',
      'espresso',
      'latte',
      'cappuccino',
      'roaster',
      'roastery',
      'pour over',
      'tea',
      'boba',
    ],
  ),
  _ExploreImageCategory(
    imageUrls: _foodImageUrls,
    keywords: [
      'food',
      'snack',
      'snacks',
      'restaurant',
      'restaurants',
      'dinner',
      'lunch',
      'brunch',
      'breakfast',
      'taco',
      'tacos',
      'pizza',
      'ramen',
      'dim sum',
      'crawl',
      'market',
      'bakery',
      'bites',
      'dining',
    ],
  ),
  _ExploreImageCategory(
    imageUrls: _viewsImageUrls,
    keywords: [
      'view',
      'views',
      'vista',
      'lookout',
      'overlook',
      'skyline',
      'sunset',
      'sunrise',
      'hilltop',
      'panorama',
      'bridge',
      'golden gate',
      'bay bridge',
      'scenic',
    ],
  ),
  _ExploreImageCategory(
    imageUrls: _outdoorsImageUrls,
    keywords: [
      'outdoor',
      'outdoors',
      'park',
      'parks',
      'hike',
      'hikes',
      'hiking',
      'trail',
      'trails',
      'garden',
      'gardens',
      'beach',
      'beaches',
      'redwoods',
      'picnic',
      'lake',
    ],
  ),
  _ExploreImageCategory(
    imageUrls: _cultureImageUrls,
    keywords: [
      'culture',
      'museum',
      'museums',
      'art',
      'arts',
      'mural',
      'murals',
      'gallery',
      'galleries',
      'music',
      'jazz',
      'theater',
      'theatre',
      'books',
      'bookstore',
      'bookstores',
      'history',
      'historic',
      'performance',
      'concert',
    ],
  ),
];

final _ExploreImageCategory _generalBayAreaCategory = _ExploreImageCategory(
  imageUrls: _generalBayAreaImageUrls,
  keywords: [],
);

String _unsplashImageUrl(String photoId) {
  return 'https://images.unsplash.com/$photoId$_imageUrlSuffix';
}

_ExploreImageCategory _categoryFor(String cueText) {
  for (final category in _specificCategories) {
    if (_containsKeyword(cueText, category.keywords)) return category;
  }

  return _generalBayAreaCategory;
}

String _selectImageUrl(List<String> imageUrls, String cueText) {
  final index = _stableHash(cueText) % imageUrls.length;
  return imageUrls[index];
}

String _normalizedCueText(Iterable<String?> cues) {
  final cueText = cues
      .whereType<String>()
      .map((cue) => cue.trim())
      .where((cue) => cue.isNotEmpty && !_looksLikeUrl(cue))
      .join(' ');

  return _normalizeForMatching(cueText);
}

String _normalizeForMatching(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool _containsKeyword(String cueText, List<String> keywords) {
  final paddedCueText = ' $cueText ';

  return keywords.any((keyword) {
    final normalizedKeyword = _normalizeForMatching(keyword);
    return paddedCueText.contains(' $normalizedKeyword ');
  });
}

int _stableHash(String text) {
  const fnvOffsetBasis = 0x811c9dc5;
  const fnvPrime = 0x01000193;

  var hash = fnvOffsetBasis;
  for (final codeUnit in text.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * fnvPrime) & 0xffffffff;
  }

  return hash;
}

bool _looksLikeUrl(String value) {
  final text = value.toLowerCase();
  return text.startsWith('http://') ||
      text.startsWith('https://') ||
      text.startsWith('www.') ||
      text.startsWith('data:') ||
      text.startsWith('file:');
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
  'localhost',
  '127.0.0.1',
];

class _ExploreImageCategory {
  const _ExploreImageCategory({
    required this.imageUrls,
    required this.keywords,
  });

  final List<String> imageUrls;
  final List<String> keywords;
}
