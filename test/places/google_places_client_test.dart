import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/places/places.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('GooglePlacesClient', () {
    test(
      'posts text search requests with a field mask and parses cards',
      () async {
        late http.Request sentRequest;
        final client = GooglePlacesClient(
          apiKey: 'places-key',
          baseUrl: 'https://places.test',
          httpClient: MockClient((request) async {
            sentRequest = request;
            return http.Response(
              jsonEncode({
                'places': [
                  {
                    'id': 'coffee-1',
                    'displayName': {'text': 'Sightglass Coffee'},
                    'formattedAddress': '270 7th St, San Francisco, CA',
                    'rating': 4.6,
                    'userRatingCount': 912,
                    'priceLevel': 'PRICE_LEVEL_MODERATE',
                    'types': ['coffee_shop', 'cafe', 'food'],
                    'googleMapsUri': 'https://maps.google.com/?cid=coffee-1',
                    'websiteUri': 'https://sightglasscoffee.com',
                    'nationalPhoneNumber': '(415) 555-0100',
                    'currentOpeningHours': {'openNow': true},
                    'location': {
                      'latitude': 37.776,
                      'longitude': -122.408,
                    },
                    'photos': [
                      {
                        'name': 'places/coffee-1/photos/photo-1',
                        'widthPx': 800,
                        'heightPx': 600,
                        'authorAttributions': [
                          {
                            'displayName': 'A Photographer',
                            'uri': 'https://example.com/profile',
                          },
                        ],
                      },
                    ],
                  },
                ],
              }),
              200,
            );
          }),
        );

        final results = await client.searchText(
          query: ' coffee ',
          maxResultCount: 3,
          includedType: 'cafe',
          languageCode: 'en',
          regionCode: 'US',
          openNow: true,
          locationBias: const PlaceSearchCircle(
            latitude: 37.78,
            longitude: -122.41,
            radiusMeters: 800,
          ),
        );

        expect(sentRequest.method, 'POST');
        expect(
          sentRequest.url.toString(),
          'https://places.test/v1/places:searchText',
        );
        expect(_header(sentRequest, 'X-Goog-Api-Key'), 'places-key');
        expect(
          _header(sentRequest, 'X-Goog-FieldMask'),
          GooglePlacesClient.defaultFieldMask,
        );
        expect(
          _header(sentRequest, 'X-Goog-FieldMask'),
          contains('places.location'),
        );
        expect(
          _header(sentRequest, 'X-Goog-FieldMask'),
          contains('places.photos'),
        );

        final body = _jsonMap(sentRequest.body);
        expect(body['textQuery'], 'coffee');
        expect(body['maxResultCount'], 3);
        expect(body['includedType'], 'cafe');
        expect(body['languageCode'], 'en');
        expect(body['regionCode'], 'US');
        expect(body['openNow'], isTrue);
        expect(
          body,
          containsPair(
            'locationBias',
            {
              'circle': {
                'center': {
                  'latitude': 37.78,
                  'longitude': -122.41,
                },
                'radius': 800,
              },
            },
          ),
        );

        expect(results, hasLength(1));
        expect(results.single.id, 'coffee-1');
        expect(results.single.displayName, 'Sightglass Coffee');
        expect(
          results.single.formattedAddress,
          '270 7th St, San Francisco, CA',
        );
        expect(results.single.rating, 4.6);
        expect(results.single.userRatingCount, 912);
        expect(results.single.openNow, isTrue);
        expect(results.single.latitude, 37.776);
        expect(results.single.longitude, -122.408);
        expect(results.single.photos, hasLength(1));
        expect(
          results.single.primaryPhoto?.name,
          'places/coffee-1/photos/photo-1',
        );
        expect(results.single.primaryPhoto?.attributionLabel, 'A Photographer');

        final card = results.single.toCardData().toJson();
        expect(card['kind'], 'placeResultCard');
        expect(card['title'], 'Sightglass Coffee');
        expect(card['metadata'], ['4.6 (912)', r'$$', 'Open now']);
        expect(card['tags'], ['Coffee Shop', 'Cafe', 'Food']);
        expect(card['googleMapsUri'], 'https://maps.google.com/?cid=coffee-1');
        expect(card['photoName'], 'places/coffee-1/photos/photo-1');
        expect(card['photoAttributionLabel'], 'A Photographer');
        expect(jsonEncode(card), isNot(contains('latitude')));
        expect(jsonEncode(card), isNot(contains('longitude')));

        final photoUri = client.photoMediaUri(results.single.primaryPhoto!);
        expect(
          photoUri?.path,
          '/v1/places/coffee-1/photos/photo-1/media',
        );
        expect(
          photoUri?.queryParameters,
          {
            'key': 'places-key',
            'maxWidthPx': '480',
            'maxHeightPx': '320',
          },
        );
      },
    );

    test('posts nearby search requests with a location restriction', () async {
      late http.Request sentRequest;
      final client = GooglePlacesClient(
        apiKey: 'places-key',
        baseUrl: 'https://places.test',
        httpClient: MockClient((request) async {
          sentRequest = request;
          return http.Response(
            jsonEncode({
              'places': [
                {
                  'id': 'food-1',
                  'displayName': {'text': 'Souvla'},
                  'formattedAddress': 'San Francisco, CA',
                  'regularOpeningHours': {'openNow': false},
                },
              ],
            }),
            200,
          );
        }),
      );

      final results = await client.searchNearby(
        latitude: 37.776,
        longitude: -122.408,
        radiusMeters: 1200,
        maxResultCount: 5,
        includedTypes: ['restaurant', ' '],
        excludedTypes: ['bar'],
        rankPreference: NearbyRankPreference.distance,
      );

      expect(
        sentRequest.url.toString(),
        'https://places.test/v1/places:searchNearby',
      );
      final body = _jsonMap(sentRequest.body);
      expect(body['maxResultCount'], 5);
      expect(body['includedTypes'], ['restaurant']);
      expect(body['excludedTypes'], ['bar']);
      expect(body['rankPreference'], 'DISTANCE');
      expect(
        body,
        containsPair(
          'locationRestriction',
          {
            'circle': {
              'center': {
                'latitude': 37.776,
                'longitude': -122.408,
              },
              'radius': 1200,
            },
          },
        ),
      );
      expect(results.single.displayName, 'Souvla');
      expect(results.single.openNow, isFalse);
    });

    test('does not call the network when the API key is missing', () async {
      var called = false;
      final client = GooglePlacesClient(
        apiKey: '   ',
        httpClient: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        client.searchText(query: 'coffee'),
        throwsA(
          isA<PlacesException>().having(
            (error) => error.message,
            'message',
            contains('GOOGLE_PLACES_API_KEY'),
          ),
        ),
      );
      expect(called, isFalse);
    });

    test('surfaces Places API error messages', () async {
      final client = GooglePlacesClient(
        apiKey: 'bad-key',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {
                'code': 403,
                'message': 'API key not valid. Please pass a valid API key.',
                'status': 'PERMISSION_DENIED',
              },
            }),
            403,
          ),
        ),
      );

      await expectLater(
        client.searchText(query: 'coffee'),
        throwsA(
          isA<PlacesException>().having(
            (error) => error.message,
            'message',
            contains('API key not valid'),
          ),
        ),
      );
    });

    test('wraps network failures in a PlacesException', () async {
      final client = GooglePlacesClient(
        apiKey: 'places-key',
        httpClient: MockClient((_) async {
          throw http.ClientException('socket closed');
        }),
      );

      await expectLater(
        client.searchNearby(
          latitude: 37.776,
          longitude: -122.408,
          radiusMeters: 1200,
        ),
        throwsA(
          isA<PlacesException>().having(
            (error) => error.message,
            'message',
            contains('Google Places request failed'),
          ),
        ),
      );
    });

    test('builds list data without marker coordinates', () {
      final list = PlaceResultListData.fromResults(
        [
          const PlaceResult(
            id: 'park-1',
            displayName: 'Dolores Park',
            formattedAddress: 'Dolores St, San Francisco, CA',
            rating: 4.8,
            userRatingCount: 12000,
            types: ['park', 'tourist_attraction'],
          ),
        ],
        title: 'Nearby parks',
      ).toJson();

      expect(list['kind'], 'placeResultList');
      expect(list['title'], 'Nearby parks');
      expect(jsonEncode(list), isNot(contains('latitude')));
      expect(jsonEncode(list), isNot(contains('longitude')));
      expect(jsonEncode(list), isNot(contains('marker')));
    });
  });
}

Map<String, Object?> _jsonMap(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

String? _header(http.Request request, String name) {
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
  }
  return null;
}
