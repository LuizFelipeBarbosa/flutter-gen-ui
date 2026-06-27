import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/explore/explore_widgets.dart';
import 'package:genui_template/location/location.dart';
import 'package:genui_template/places/places.dart';

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
