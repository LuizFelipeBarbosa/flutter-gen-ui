import 'package:bayhop/explore/explore_image_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fallbackExploreImageUrlFor', () {
    test('does not provide generic remote fallback imagery', () {
      expect(
        fallbackExploreImageUrlFor([
          'Oakland waterfront',
          'coffee',
          'museum',
        ]),
        isNull,
      );
      expect(fallbackExploreImageUrlFor(const []), isNull);
    });
  });

  group('isUsableExploreImageUrl', () {
    test('allows Google Places HTTPS photo media URLs', () {
      expect(
        isUsableExploreImageUrl(
          'https://places.googleapis.com/v1/places/abc/photos/def/media'
          '?key=places-key&maxWidthPx=480',
        ),
        isTrue,
      );
    });

    test('rejects blank, non-HTTPS, placeholder, and stock URLs', () {
      expect(isUsableExploreImageUrl(null), isFalse);
      expect(isUsableExploreImageUrl('   '), isFalse);
      expect(
        isUsableExploreImageUrl('http://images.example.test/a.jpg'),
        isFalse,
      );
      expect(isUsableExploreImageUrl('https://example.com/a.jpg'), isFalse);
      expect(isUsableExploreImageUrl('https://placehold.co/600x400'), isFalse);
      expect(
        isUsableExploreImageUrl(
          'https://images.unsplash.com/photo-1501594907352-04cda38ebc29',
        ),
        isFalse,
      );
    });
  });
}
