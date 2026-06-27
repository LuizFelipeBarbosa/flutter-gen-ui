import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/explore/explore_image_resolver.dart';

void main() {
  group('fallbackExploreImageUrlFor', () {
    test('returns a stable image for the same cues', () {
      final first = fallbackExploreImageUrlFor([
        'Oakland waterfront',
        'sunset snacks',
        'easy BART connection',
      ]);

      expect(
        fallbackExploreImageUrlFor([
          'Oakland waterfront',
          'sunset snacks',
          'easy BART connection',
        ]),
        first,
      );
    });

    test('can vary different suggestions in the same category', () {
      final urls = {
        fallbackExploreImageUrlFor(['coffee crawl near a quiet cafe']),
        fallbackExploreImageUrlFor(['coffee in north beach']),
        fallbackExploreImageUrlFor(['coffee shop']),
      };

      expect(urls, hasLength(greaterThan(1)));
      expect(
        urls.every(
          (url) => _containsAnyPhotoId(url, const [
            'photo-1495474472287-4d71bcdd2085',
            'photo-1509042239860-f550ce710b93',
            'photo-1511920170033-f8396924c348',
          ]),
        ),
        isTrue,
      );
    });

    test('selects imagery from recognized category cues', () {
      final cases = <String, List<String>>{
        'taco dinner snack crawl': [
          'photo-1504674900247-0877df9cc836',
          'photo-1555939594-58d7cb561ad1',
          'photo-1481833761820-0509d3217039',
        ],
        'coffee roastery espresso': [
          'photo-1495474472287-4d71bcdd2085',
          'photo-1509042239860-f550ce710b93',
          'photo-1511920170033-f8396924c348',
        ],
        'sunset skyline bridge view': [
          'photo-1500534314209-a25ddb2bd429',
          'photo-1469474968028-56623f02e42e',
          'photo-1506905925346-21bda4d32df4',
        ],
        'redwoods trail outdoor hike': [
          'photo-1500530855697-b586d89ba3ee',
          'photo-1441974231531-c6227db76b6e',
          'photo-1501854140801-50d01698950b',
        ],
        'mural gallery jazz culture': [
          'photo-1518998053901-5348d3961a04',
          'photo-1541961017774-22349e4a1262',
          'photo-1460661419201-fd4cecdf8a8b',
        ],
        'ferry pier waterfront': [
          'photo-1501594907352-04cda38ebc29',
          'photo-1507525428034-b723cf961d3e',
          'photo-1518837695005-2083093ee35b',
        ],
        'lake merritt oakland afternoon': [
          'photo-1519501025264-65ba15a82390',
          'photo-1494526585095-c41746248156',
          'photo-1465447142348-e9952c393450',
        ],
        'telegraph berkeley bookstore': [
          'photo-1533929736458-ca588d08c8be',
          'photo-1449034446853-66c86144b0ad',
          'photo-1496307653780-42ee777d4833',
        ],
        'bart station transit transfer': [
          'photo-1544620347-c4fd4a3d5957',
          'photo-1474487548417-781cb71495f3',
          'photo-1494783367193-149034c05e8f',
        ],
        'bay area day trip': [
          'photo-1501594907352-04cda38ebc29',
          'photo-1449034446853-66c86144b0ad',
          'photo-1533929736458-ca588d08c8be',
        ],
      };

      for (final MapEntry(key: cue, value: photoIds) in cases.entries) {
        final url = fallbackExploreImageUrlFor([cue]);

        expect(
          _containsAnyPhotoId(url, photoIds),
          isTrue,
          reason: 'Expected "$cue" to select a category image, got $url',
        );
      }
    });

    test('uses the default general fallback for empty or invalid cues', () {
      final defaultFallback = fallbackExploreImageUrlFor(const []);

      expect(
        defaultFallback,
        contains('photo-1501594907352-04cda38ebc29'),
      );
      expect(fallbackExploreImageUrlFor([null, '', '   ']), defaultFallback);
      expect(
        fallbackExploreImageUrlFor([
          'https://example.com/coffee.jpg',
          'http://placeholder.com/food.jpg',
          'data:image/png;base64,abc',
        ]),
        defaultFallback,
      );
    });
  });

  group('isUsableExploreImageUrl', () {
    test('allows stable HTTPS image URLs', () {
      expect(
        isUsableExploreImageUrl(
          'https://images.unsplash.com/photo-1501594907352-04cda38ebc29',
        ),
        isTrue,
      );
    });

    test('rejects blank, non-HTTPS, and placeholder URLs', () {
      expect(isUsableExploreImageUrl(null), isFalse);
      expect(isUsableExploreImageUrl('   '), isFalse);
      expect(
        isUsableExploreImageUrl('http://images.example.test/a.jpg'),
        isFalse,
      );
      expect(isUsableExploreImageUrl('https://example.com/a.jpg'), isFalse);
      expect(isUsableExploreImageUrl('https://placehold.co/600x400'), isFalse);
    });
  });
}

bool _containsAnyPhotoId(String url, List<String> photoIds) {
  return photoIds.any(url.contains);
}
