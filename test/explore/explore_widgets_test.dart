import 'package:bayhop/explore/explore_widgets.dart';
import 'package:bayhop/location/location.dart';
import 'package:bayhop/places/places.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [340.0, 720.0]) {
    for (final count in [2, 3, 4, 5]) {
      testWidgets('image mosaic renders $count tiles at ${width}px wide', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: width,
                  child: ExploreImageMosaic(
                    title: 'Pick a bento path',
                    tiles: _mosaicTiles(count),
                    onAction: (_, _) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Pick a bento path'), findsOneWidget);
        for (var index = 0; index < count; index++) {
          expect(find.text('Tile ${index + 1}'), findsOneWidget);
        }
      });
    }
  }

  testWidgets('broad image widgets ignore stock image URLs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExploreHero(
            title: 'Waterfront afternoon',
            summary: 'A broad branch without a grounded image.',
            imageUrl:
                'https://images.unsplash.com/photo-1501594907352-04cda38ebc29',
            onAction: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.travel_explore_rounded), findsOneWidget);
  });

  testWidgets('hero uses Google Places photo for placeQuery', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExploreHero(
            title: 'Photo header',
            summary: 'A header backed by Google Places.',
            placeQuery: 'Photo Place San Francisco',
            client: _PhotoPlacesClient(),
            onAction: (_, _) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    final image = tester.widget<Image>(imageFinder);
    final provider = image.image;

    expect(provider, isA<NetworkImage>());
    expect((provider as NetworkImage).url, contains('/media'));
    expect(provider.url, contains('maxWidthPx=1200'));
  });

  testWidgets('hero with placeQuery does not use imageUrl as exact fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExploreHero(
            title: 'No photo header',
            summary: 'A header with no Google photo.',
            placeQuery: 'No Photo Place San Francisco',
            imageUrl: 'https://assets.example.test/broad-header.jpg',
            client: _NoPhotoPlacesClient(),
            onAction: (_, _) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.travel_explore_rounded), findsOneWidget);
  });

  testWidgets('option card uses Google Places photo for placeQuery', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExplorerOptionCard(
            title: 'Playful Oakland food crawl',
            query: 'Plan a playful Oakland food crawl',
            badge: 'Start',
            placeQuery: "Swan's Market Oakland",
            imageUrl: 'https://assets.example.test/ignored.jpg',
            client: _PhotoPlacesClient(),
            onAction: (_, _) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    final image = tester.widget<Image>(imageFinder);
    final provider = image.image;

    expect(provider, isA<NetworkImage>());
    expect((provider as NetworkImage).url, contains('/media'));
    expect(provider.url, contains('maxWidthPx=320'));
  });

  testWidgets('option card with placeQuery does not use imageUrl fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExplorerOptionCard(
            title: 'No photo option',
            query: 'Explore no photo option',
            placeQuery: 'No Photo Place San Francisco',
            imageUrl: 'https://assets.example.test/broad-option.jpg',
            client: _NoPhotoPlacesClient(),
            onAction: (_, _) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.explore_rounded), findsOneWidget);
  });

  testWidgets(
    'option card keeps query as action text with placeQuery metadata',
    (
      tester,
    ) async {
      String? actionName;
      Map<String, Object?>? actionContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExplorerOptionCard(
              title: 'Playful Oakland food crawl',
              query: 'Plan a playful Oakland food crawl',
              badge: 'Start',
              placeQuery: "Swan's Market Oakland",
              imageUrl: 'https://assets.example.test/ignored.jpg',
              client: _PhotoPlacesClient(),
              onAction: (name, context) {
                actionName = name;
                actionContext = context;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Playful Oakland food crawl'));

      expect(actionName, 'explore_option');
      expect(actionContext?['query'], 'Plan a playful Oakland food crawl');
      expect(actionContext?['placeQuery'], "Swan's Market Oakland");
      expect(actionContext?.containsKey('imageUrl'), isFalse);
    },
  );

  testWidgets('image mosaic uses Google Places photo for placeQuery tiles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 720,
            child: ExploreImageMosaic(
              tiles: const [
                ExploreMosaicImage(
                  title: 'Photo tile',
                  badge: 'Grounded',
                  placeQuery: 'Photo Place San Francisco',
                  imageUrl: 'https://assets.example.test/ignored.jpg',
                  query: 'Explore the photo tile',
                ),
              ],
              client: _PhotoPlacesClient(),
              onAction: (_, _) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    final image = tester.widget<Image>(imageFinder);
    final provider = image.image;

    expect(provider, isA<NetworkImage>());
    expect((provider as NetworkImage).url, contains('/media'));
    expect(provider.url, contains('maxWidthPx=640'));
  });

  testWidgets('image mosaic with placeQuery does not use imageUrl fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 720,
            child: ExploreImageMosaic(
              tiles: const [
                ExploreMosaicImage(
                  title: 'No photo tile',
                  badge: 'Grounded',
                  placeQuery: 'No Photo Place San Francisco',
                  imageUrl: 'https://assets.example.test/broad-tile.jpg',
                  query: 'Explore the no-photo tile',
                ),
              ],
              client: _NoPhotoPlacesClient(),
              onAction: (_, _) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.image_rounded), findsOneWidget);
  });

  testWidgets(
    'image mosaic keeps query as action text with placeQuery metadata',
    (
      tester,
    ) async {
      String? actionName;
      Map<String, Object?>? actionContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 720,
              child: ExploreImageMosaic(
                tiles: const [
                  ExploreMosaicImage(
                    title: 'Photo tile',
                    badge: 'Grounded',
                    placeQuery: 'Photo Place San Francisco',
                    imageUrl: 'https://assets.example.test/ignored.jpg',
                    query: 'Explore the photo tile',
                  ),
                ],
                client: _PhotoPlacesClient(),
                onAction: (name, context) {
                  actionName = name;
                  actionContext = context;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Photo tile'));

      expect(actionName, 'explore_option');
      expect(actionContext?['query'], 'Explore the photo tile');
      expect(actionContext?['placeQuery'], 'Photo Place San Francisco');
      expect(actionContext?.containsKey('imageUrl'), isFalse);
    },
  );

  testWidgets('image mosaic filters duplicate generated tiles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 720,
            child: ExploreImageMosaic(
              tiles: const [
                ExploreMosaicImage(
                  title: 'Coffee crawl',
                  query: 'Find coffee near BART',
                ),
                ExploreMosaicImage(
                  title: 'Duplicate coffee',
                  query: 'Find coffee near BART',
                ),
                ExploreMosaicImage(
                  title: 'Museum stop',
                  query: 'Find a museum near BART',
                ),
              ],
              onAction: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Coffee crawl'), findsOneWidget);
    expect(find.text('Duplicate coffee'), findsNothing);
    expect(find.text('Museum stop'), findsOneWidget);
  });

  testWidgets('image mosaic filters duplicate placeQuery tiles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 720,
            child: ExploreImageMosaic(
              tiles: const [
                ExploreMosaicImage(
                  title: 'Lake branch',
                  placeQuery: 'Lake Merritt Oakland',
                  query: 'Explore Lake Merritt',
                ),
                ExploreMosaicImage(
                  title: 'Duplicate lake branch',
                  placeQuery: 'Lake Merritt Oakland',
                  query: 'Explore a different Lake Merritt branch',
                ),
                ExploreMosaicImage(
                  title: 'Museum branch',
                  placeQuery: 'Oakland Museum of California',
                  query: 'Explore OMCA',
                ),
              ],
              client: _NoPhotoPlacesClient(),
              onAction: (_, _) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Lake branch'), findsOneWidget);
    expect(find.text('Duplicate lake branch'), findsNothing);
    expect(find.text('Museum branch'), findsOneWidget);
  });

  testWidgets('places carousel fits dense metadata without overflow', (
    tester,
  ) async {
    final overlayController = MapPlaceOverlayController();
    addTearDown(overlayController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MapPlaceOverlayScope(
          controller: overlayController,
          child: Scaffold(
            body: SizedBox(
              width: 360,
              child: ExplorePlaceSearch(
                title: 'Dense places',
                query: 'dense places',
                layout: ExplorePlaceSearchLayout.carousel,
                latitude: 37.7749,
                longitude: -122.4194,
                client: _FakePlacesClient(),
                onAction: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Place with lots of metadata'), findsOneWidget);
    expect(overlayController.searchResultMarkers, hasLength(2));
    expect(
      overlayController.searchResultMarkers.map((marker) => marker.label),
      containsAll(['Place with lots of metadata', 'Another dense place']),
    );
  });

  testWidgets('places list dedupes results before publishing markers', (
    tester,
  ) async {
    final overlayController = MapPlaceOverlayController();
    addTearDown(overlayController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MapPlaceOverlayScope(
          controller: overlayController,
          child: Scaffold(
            body: SizedBox(
              width: 360,
              child: ExplorePlaceSearch(
                title: 'Duplicate places',
                query: 'duplicate places',
                client: _DuplicatePlacesClient(),
                onAction: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Duplicate Cafe'), findsOneWidget);
    expect(find.text('Second Place'), findsOneWidget);
    expect(overlayController.searchResultMarkers, hasLength(2));
    expect(
      overlayController.searchResultMarkers.map((marker) => marker.label),
      ['Duplicate Cafe', 'Second Place'],
    );
  });

  testWidgets('places cards use Google photos without stock fallback images', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: ExplorePlaceSearch(
              title: 'Photo places',
              query: 'photo places',
              client: _PhotoPlacesClient(),
              onAction: (_, _) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    final image = tester.widget<Image>(imageFinder);
    final provider = image.image;

    expect(provider, isA<NetworkImage>());
    expect((provider as NetworkImage).url, contains('/media'));
    expect(find.text('Photo Place'), findsOneWidget);
    expect(find.text('No Photo Place'), findsOneWidget);
  });

  for (final width in [360.0, 760.0]) {
    testWidgets('places mosaic renders at ${width}px wide', (tester) async {
      final overlayController = MapPlaceOverlayController();
      addTearDown(overlayController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MapPlaceOverlayScope(
            controller: overlayController,
            child: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: width,
                  child: ExplorePlaceSearch(
                    title: 'Bento places',
                    query: 'dense places',
                    layout: ExplorePlaceSearchLayout.mosaic,
                    latitude: 37.7749,
                    longitude: -122.4194,
                    client: _FakePlacesClient(),
                    onAction: (_, _) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Bento places'), findsOneWidget);
      expect(find.text('Place with lots of metadata'), findsOneWidget);
      expect(find.text('Another dense place'), findsOneWidget);
      expect(overlayController.searchResultMarkers, hasLength(2));
    });
  }
}

List<ExploreMosaicImage> _mosaicTiles(int count) {
  return [
    for (var index = 0; index < count; index++)
      ExploreMosaicImage(
        imageUrl: '',
        title: 'Tile ${index + 1}',
        badge: index.isEven ? 'Views' : 'Food',
        query: 'Explore tile ${index + 1}',
      ),
  ];
}

class _FakePlacesClient extends GooglePlacesClient {
  _FakePlacesClient() : super(apiKey: 'test-key');

  @override
  Future<List<PlaceResult>> searchText({
    required String query,
    int maxResultCount = 10,
    PlaceSearchCircle? locationBias,
    String? includedType,
    String? languageCode,
    String? regionCode,
    bool? openNow,
  }) async {
    return const [
      PlaceResult(
        id: 'place-1',
        displayName: 'Place with lots of metadata',
        formattedAddress:
            '123 Long Waterfront Address, San Francisco, California',
        rating: 4.8,
        userRatingCount: 1200,
        priceLevel: 'PRICE_LEVEL_MODERATE',
        openNow: true,
        latitude: 37.775,
        longitude: -122.419,
        types: ['tourist_attraction', 'restaurant', 'point_of_interest'],
      ),
      PlaceResult(
        id: 'place-2',
        displayName: 'Another dense place',
        formattedAddress: '456 Market Street, San Francisco, California',
        rating: 4.6,
        userRatingCount: 850,
        priceLevel: 'PRICE_LEVEL_EXPENSIVE',
        openNow: false,
        latitude: 37.776,
        longitude: -122.42,
        types: ['museum', 'store', 'establishment'],
      ),
      PlaceResult(
        id: 'place-3',
        displayName: 'Unmapped place',
        formattedAddress: 'No exact coordinate',
        types: ['point_of_interest'],
      ),
    ];
  }
}

class _DuplicatePlacesClient extends GooglePlacesClient {
  _DuplicatePlacesClient() : super(apiKey: 'test-key');

  @override
  Future<List<PlaceResult>> searchText({
    required String query,
    int maxResultCount = 10,
    PlaceSearchCircle? locationBias,
    String? includedType,
    String? languageCode,
    String? regionCode,
    bool? openNow,
  }) async {
    return const [
      PlaceResult(
        id: 'duplicate-1',
        displayName: 'Duplicate Cafe',
        formattedAddress: '1 Market Street, San Francisco, CA',
        latitude: 37.775,
        longitude: -122.419,
        types: ['cafe'],
      ),
      PlaceResult(
        id: 'duplicate-1',
        displayName: 'Duplicate Cafe Updated',
        formattedAddress: '1 Market Street, San Francisco, CA',
        latitude: 37.776,
        longitude: -122.42,
        types: ['cafe'],
      ),
      PlaceResult(
        id: 'duplicate-2',
        displayName: 'Duplicate Cafe',
        formattedAddress: '1 Market Street, San Francisco, CA',
        latitude: 37.777,
        longitude: -122.421,
        types: ['cafe'],
      ),
      PlaceResult(
        id: 'second-place',
        displayName: 'Second Place',
        formattedAddress: '2 Market Street, San Francisco, CA',
        latitude: 37.778,
        longitude: -122.422,
        types: ['museum'],
      ),
    ];
  }
}

class _PhotoPlacesClient extends GooglePlacesClient {
  _PhotoPlacesClient() : super(apiKey: 'test-key');

  @override
  Future<List<PlaceResult>> searchText({
    required String query,
    int maxResultCount = 10,
    PlaceSearchCircle? locationBias,
    String? includedType,
    String? languageCode,
    String? regionCode,
    bool? openNow,
  }) async {
    return const [
      PlaceResult(
        id: 'photo-place',
        displayName: 'Photo Place',
        formattedAddress: '3 Market Street, San Francisco, CA',
        types: ['tourist_attraction'],
        photos: [
          PlacePhoto(
            name: 'places/photo-place/photos/photo-1',
            authorAttributions: [
              PlacePhotoAttribution(displayName: 'A Photographer'),
            ],
          ),
        ],
      ),
      PlaceResult(
        id: 'no-photo-place',
        displayName: 'No Photo Place',
        formattedAddress: '4 Market Street, San Francisco, CA',
        types: ['park'],
      ),
    ];
  }
}

class _NoPhotoPlacesClient extends GooglePlacesClient {
  _NoPhotoPlacesClient() : super(apiKey: 'test-key');

  @override
  Future<List<PlaceResult>> searchText({
    required String query,
    int maxResultCount = 10,
    PlaceSearchCircle? locationBias,
    String? includedType,
    String? languageCode,
    String? regionCode,
    bool? openNow,
  }) async {
    return const [
      PlaceResult(
        id: 'no-photo-place',
        displayName: 'No Photo Place',
        formattedAddress: '4 Market Street, San Francisco, CA',
        types: ['park'],
      ),
    ];
  }
}
