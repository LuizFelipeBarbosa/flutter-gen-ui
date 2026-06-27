import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/explore/explore_widgets.dart';
import 'package:genui_template/places/places.dart';

void main() {
  testWidgets('places carousel fits dense metadata without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
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
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Place with lots of metadata'), findsOneWidget);
  });
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
    ];
  }
}
