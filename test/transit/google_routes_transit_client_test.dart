import 'dart:convert';

import 'package:bayhop/location/location_point.dart';
import 'package:bayhop/transit/google_routes_transit_client.dart';
import 'package:bayhop/transit/transit_lines.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('GoogleRoutesTransitClient', () {
    test('field mask only requests valid Routes transit step fields', () {
      expect(
        GoogleRoutesTransitClient.defaultFieldMask,
        isNot(contains('routes.legs.steps.duration')),
      );
      expect(
        GoogleRoutesTransitClient.defaultFieldMask,
        contains('routes.legs.steps.staticDuration'),
      );
      expect(
        GoogleRoutesTransitClient.defaultFieldMask,
        contains('routes.legs.steps.transitDetails'),
      );
    });

    test(
      'posts transit route requests and parses BART, fare, and walk',
      () async {
        late http.Request sentRequest;
        final client = GoogleRoutesTransitClient(
          apiKey: 'routes-key',
          baseUrl: 'https://routes.test',
          httpClient: MockClient((request) async {
            sentRequest = request;
            return _jsonResponse({
              'routes': [
                _route(
                  duration: '1800s',
                  fare: _money(units: '6', nanos: 500000000),
                  steps: [
                    _walkStep(duration: '300s', instructions: 'Walk to DBRK'),
                    _transitStep(
                      duration: '1500s',
                      agency: 'BART',
                      lineName: 'BART Red Line',
                      lineShortName: 'Red',
                      from: 'Downtown Berkeley',
                      to: 'Embarcadero',
                      departureTime: '2026-06-27T08:05:00-07:00',
                      arrivalTime: '2026-06-27T08:30:00-07:00',
                      stopCount: 9,
                    ),
                    _walkStep(
                      duration: '300s',
                      instructions: 'Walk to Ferry Building',
                    ),
                  ],
                ),
              ],
            });
          }),
        );

        final journey = await client.fetchBestRoute(
          origin: const LocationCoordinate(latitude: 37.87, longitude: -122.27),
          destination: const LocationCoordinate(
            latitude: 37.795,
            longitude: -122.393,
          ),
          departureTime: DateTime.parse('2026-06-27T15:00:00Z'),
          originName: 'Home',
          destinationName: 'Ferry Building',
          routingPreference: TransitRoutingPreference.fewerTransfers,
        );

        expect(sentRequest.method, 'POST');
        expect(
          sentRequest.url.toString(),
          'https://routes.test/directions/v2:computeRoutes',
        );
        expect(_header(sentRequest, 'X-Goog-Api-Key'), 'routes-key');
        expect(
          _header(sentRequest, 'X-Goog-FieldMask'),
          GoogleRoutesTransitClient.defaultFieldMask,
        );

        final body = _jsonMap(sentRequest.body);
        expect(body['travelMode'], 'TRANSIT');
        expect(body['departureTime'], '2026-06-27T15:00:00.000Z');
        expect(
          body['transitPreferences'],
          {'routingPreference': 'FEWER_TRANSFERS'},
        );
        expect(
          body['origin'],
          {
            'location': {
              'latLng': {'latitude': 37.87, 'longitude': -122.27},
            },
          },
        );

        expect(journey.from, 'Home');
        expect(journey.to, 'Ferry Building');
        expect(journey.departClock, '8:00');
        expect(journey.arriveClock, '8:35');
        expect(journey.durationMinutes, 30);
        expect(journey.changes, 0);
        expect(journey.fare, r'$6.50');
        expect(journey.legs.map((leg) => leg.lineId), [
          '',
          'bart-red',
          '',
        ]);
        expect(journey.legs[1].stopCount, 9);

        final widgetJson = journey.toTransitJourneyJson();
        expect(widgetJson['fare'], r'$6.50');
        expect(
          widgetJson['legs'],
          contains(
            containsPair('line', 'bart-red'),
          ),
        );
      },
    );

    test('serializes TransitJourney JSON with caller metadata', () {
      const journey = GoogleRoutesTransitJourney(
        from: 'Coffee',
        to: 'Museum',
        departClock: '10:30',
        arriveClock: '10:52',
        durationMinutes: 22,
        changes: 1,
        fare: r'$2.75',
        legs: [
          GoogleRoutesTransitLeg.ride(
            durationMinutes: 10,
            lineId: 'regional-bus',
            from: 'Coffee',
            to: 'Transfer',
            stopCount: 4,
          ),
          GoogleRoutesTransitLeg.change(
            durationMinutes: 4,
            station: 'Transfer',
          ),
          GoogleRoutesTransitLeg.ride(
            durationMinutes: 8,
            lineId: 'muni-n',
            from: 'Transfer',
            to: 'Museum',
          ),
        ],
      );

      expect(
        journey.toTransitJourneyJson(
          recommended: false,
          tag: 'Saved itinerary segment 2',
        ),
        {
          'recommended': false,
          'tag': 'Saved itinerary segment 2',
          'from': 'Coffee',
          'to': 'Museum',
          'depart': '10:30',
          'arrive': '10:52',
          'duration': 22,
          'changes': 1,
          'fare': r'$2.75',
          'crowd': 'Some seats',
          'legs': [
            {
              'type': 'ride',
              'line': 'regional-bus',
              'from': 'Coffee',
              'to': 'Transfer',
              'mins': 10,
              'stops': 4,
            },
            {
              'type': 'change',
              'station': 'Transfer',
              'mins': 4,
            },
            {
              'type': 'ride',
              'line': 'muni-n',
              'from': 'Transfer',
              'to': 'Museum',
              'mins': 8,
            },
          ],
        },
      );
    });

    test('maps Caltrain, Muni, walking, and transfers', () async {
      final client = GoogleRoutesTransitClient(
        apiKey: 'routes-key',
        httpClient: MockClient(
          (_) async => _jsonResponse({
            'routes': [
              _route(
                steps: [
                  _transitStep(
                    duration: '1200s',
                    agency: 'Caltrain',
                    lineName: 'Caltrain Local',
                    from: '22nd Street',
                    to: 'San Francisco',
                    departureTime: '2026-06-27T09:00:00-07:00',
                    arrivalTime: '2026-06-27T09:20:00-07:00',
                  ),
                  _walkStep(
                    duration: '240s',
                    instructions: 'Walk to 4th & King',
                  ),
                  _transitStep(
                    duration: '480s',
                    agency: 'SFMTA',
                    lineName: 'N Judah',
                    lineShortName: 'N',
                    from: '4th & King',
                    to: 'Embarcadero',
                    departureTime: '2026-06-27T09:26:00-07:00',
                    arrivalTime: '2026-06-27T09:34:00-07:00',
                    vehicleType: 'TRAM',
                  ),
                ],
              ),
            ],
          }),
        ),
      );

      final journey = await client.fetchBestRoute(
        origin: const LocationCoordinate(latitude: 37.75, longitude: -122.39),
        destination: const LocationCoordinate(
          latitude: 37.793,
          longitude: -122.397,
        ),
      );

      expect(journey.changes, 1);
      expect(journey.legs.map((leg) => leg.lineId), [
        'caltrain',
        '',
        'muni-n',
      ]);
      expect(journey.legs[1].durationMinutes, 4);
      expect(journey.toPromptFacts(), contains('1 change'));
    });

    test('adds change wait between adjacent ride legs', () async {
      final client = GoogleRoutesTransitClient(
        apiKey: 'routes-key',
        httpClient: MockClient(
          (_) async => _jsonResponse({
            'routes': [
              _route(
                steps: [
                  _transitStep(
                    duration: '1200s',
                    agency: 'Caltrain',
                    lineName: 'Caltrain Local',
                    from: '22nd Street',
                    to: '4th & King',
                    departureTime: '2026-06-27T09:00:00-07:00',
                    arrivalTime: '2026-06-27T09:20:00-07:00',
                  ),
                  _transitStep(
                    duration: '480s',
                    agency: 'SFMTA',
                    lineName: 'N Judah',
                    lineShortName: 'N',
                    from: '4th & King',
                    to: 'Embarcadero',
                    departureTime: '2026-06-27T09:26:00-07:00',
                    arrivalTime: '2026-06-27T09:34:00-07:00',
                    vehicleType: 'TRAM',
                  ),
                ],
              ),
            ],
          }),
        ),
      );

      final journey = await client.fetchBestRoute(
        origin: const LocationCoordinate(latitude: 37.75, longitude: -122.39),
        destination: const LocationCoordinate(
          latitude: 37.793,
          longitude: -122.397,
        ),
      );

      expect(journey.durationMinutes, 34);
      expect(journey.changes, 1);
      expect(journey.legs.map((leg) => leg.type), [
        'ride',
        'change',
        'ride',
      ]);
      expect(journey.legs[1].station, '4th & King');
      expect(journey.legs[1].durationMinutes, 6);
      expect(journey.legs.map((leg) => leg.lineId), [
        'caltrain',
        '',
        'muni-n',
      ]);
    });

    test('uses regional fallbacks for unknown transit and bus lines', () async {
      final client = GoogleRoutesTransitClient(
        apiKey: 'routes-key',
        httpClient: MockClient(
          (_) async => _jsonResponse({
            'routes': [
              _route(
                steps: [
                  _transitStep(
                    duration: '600s',
                    agency: 'AC Transit',
                    lineName: '72M',
                    from: 'San Pablo Av',
                    to: 'MacArthur',
                    departureTime: '2026-06-27T10:00:00-07:00',
                    arrivalTime: '2026-06-27T10:10:00-07:00',
                    vehicleType: 'BUS',
                  ),
                  _transitStep(
                    duration: '600s',
                    agency: 'Some Shuttle',
                    lineName: 'Connector',
                    from: 'MacArthur',
                    to: 'Uptown',
                    departureTime: '2026-06-27T10:12:00-07:00',
                    arrivalTime: '2026-06-27T10:22:00-07:00',
                  ),
                ],
              ),
            ],
          }),
        ),
      );

      final journey = await client.fetchBestRoute(
        origin: const LocationCoordinate(latitude: 37.84, longitude: -122.29),
        destination: const LocationCoordinate(
          latitude: 37.81,
          longitude: -122.27,
        ),
      );

      expect(journey.legs.first.lineId, regionalBusLineId);
      expect(journey.legs.last.lineId, regionalTransitLineId);
    });

    test('does not collapse same-time transit steps to zero minutes', () async {
      final client = GoogleRoutesTransitClient(
        apiKey: 'routes-key',
        httpClient: MockClient(
          (_) async => _jsonResponse({
            'routes': [
              _route(
                steps: [
                  _transitStep(
                    duration: '90s',
                    agency: 'BART',
                    lineName: 'BART Red Line',
                    lineShortName: 'Red',
                    from: 'Downtown Berkeley',
                    to: 'North Berkeley',
                    departureTime: '2026-06-27T09:00:00-07:00',
                    arrivalTime: '2026-06-27T09:00:00-07:00',
                  ),
                ],
              ),
            ],
          }),
        ),
      );

      final journey = await client.fetchBestRoute(
        origin: const LocationCoordinate(latitude: 37.87, longitude: -122.27),
        destination: const LocationCoordinate(
          latitude: 37.874,
          longitude: -122.283,
        ),
      );

      expect(journey.durationMinutes, 2);
      expect(journey.legs.single.durationMinutes, 2);
      expect(journey.arriveClock, '9:02');
    });

    test('does not call the network when the API key is missing', () async {
      var called = false;
      final client = GoogleRoutesTransitClient(
        apiKey: ' ',
        httpClient: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        client.fetchBestRoute(
          origin: const LocationCoordinate(latitude: 0, longitude: 0),
          destination: const LocationCoordinate(latitude: 1, longitude: 1),
        ),
        throwsA(
          isA<GoogleRoutesTransitException>().having(
            (error) => error.message,
            'message',
            contains('GOOGLE_MAPS_API_KEY'),
          ),
        ),
      );
      expect(called, isFalse);
    });

    test('surfaces no-route and API errors', () async {
      final noRouteClient = GoogleRoutesTransitClient(
        apiKey: 'routes-key',
        httpClient: MockClient(
          (_) async => _jsonResponse({'routes': <Object?>[]}),
        ),
      );
      await expectLater(
        noRouteClient.fetchBestRoute(
          origin: const LocationCoordinate(latitude: 0, longitude: 0),
          destination: const LocationCoordinate(latitude: 1, longitude: 1),
        ),
        throwsA(
          isA<GoogleRoutesTransitException>().having(
            (error) => error.message,
            'message',
            contains('did not return a transit route'),
          ),
        ),
      );

      final errorClient = GoogleRoutesTransitClient(
        apiKey: 'routes-key',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'API key not valid'},
            }),
            403,
          ),
        ),
      );
      await expectLater(
        errorClient.fetchBestRoute(
          origin: const LocationCoordinate(latitude: 0, longitude: 0),
          destination: const LocationCoordinate(latitude: 1, longitude: 1),
        ),
        throwsA(
          isA<GoogleRoutesTransitException>().having(
            (error) => error.message,
            'message',
            contains('API key not valid'),
          ),
        ),
      );
    });
  });
}

http.Response _jsonResponse(Map<String, Object?> body) {
  return http.Response(jsonEncode(body), 200);
}

Map<String, Object?> _route({
  required List<Map<String, Object?>> steps,
  String? duration,
  Map<String, Object?>? fare,
}) {
  final route = <String, Object?>{
    'legs': [
      {'steps': steps},
    ],
  };
  if (duration != null) route['duration'] = duration;
  if (fare != null) route['travelAdvisory'] = {'transitFare': fare};
  return route;
}

Map<String, Object?> _walkStep({
  required String duration,
  required String instructions,
}) {
  return {
    'travelMode': 'WALK',
    'duration': duration,
    'navigationInstruction': {'instructions': instructions},
  };
}

Map<String, Object?> _transitStep({
  required String duration,
  required String agency,
  required String lineName,
  required String from,
  required String to,
  required String departureTime,
  required String arrivalTime,
  String? lineShortName,
  String? vehicleType,
  int? stopCount,
}) {
  return {
    'travelMode': 'TRANSIT',
    'duration': duration,
    'transitDetails': {
      'stopCount': stopCount,
      'stopDetails': {
        'departureStop': {'name': from},
        'arrivalStop': {'name': to},
        'departureTime': departureTime,
        'arrivalTime': arrivalTime,
      },
      'transitLine': _lineJson(
        agency: agency,
        lineName: lineName,
        lineShortName: lineShortName,
        vehicleType: vehicleType,
      ),
    }..removeWhere((_, value) => value == null),
  };
}

Map<String, Object?> _lineJson({
  required String agency,
  required String lineName,
  String? lineShortName,
  String? vehicleType,
}) {
  final line = <String, Object?>{
    'agencies': [
      {'name': agency},
    ],
    'name': lineName,
  };
  if (lineShortName != null) line['nameShort'] = lineShortName;
  if (vehicleType != null) line['vehicle'] = {'type': vehicleType};
  return line;
}

Map<String, Object?> _money({required String units, required int nanos}) {
  return {
    'currencyCode': 'USD',
    'units': units,
    'nanos': nanos,
  };
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
