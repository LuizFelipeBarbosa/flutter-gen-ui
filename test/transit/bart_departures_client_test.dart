import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/transit/bart_departures_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('BartDeparturesClient', () {
    test('returns planned connector departures for OAKL', () async {
      final client = BartDeparturesClient(
        httpClient: MockClient((_) async {
          fail('OAKL should not call the BART ETD endpoint');
        }),
      );

      final board = await client.fetchDepartures('OAKL');

      expect(board.station, 'Oakland Airport');
      expect(board.live, isFalse);
      expect(board.departures, hasLength(3));
      expect(board.departures.first.line, 'bart-beige');
      expect(board.departures.first.destination, 'Coliseum');
    });

    test(
      'resolves full station names before requesting live departures',
      () async {
        final fetchedAt = DateTime.parse('2026-06-26T12:00:00Z');
        late Uri requestedUrl;
        final client = BartDeparturesClient(
          now: () => fetchedAt,
          httpClient: MockClient((request) async {
            requestedUrl = request.url;
            return http.Response(
              jsonEncode({
                'root': {
                  'station': [
                    {
                      'name': 'Embarcadero',
                      'etd': [
                        {
                          'destination': 'Richmond',
                          'estimate': [
                            {
                              'minutes': '4',
                              'platform': '2',
                              'color': 'RED',
                            },
                          ],
                        },
                      ],
                    },
                  ],
                },
              }),
              200,
            );
          }),
        );

        final board = await client.fetchDepartures('Embarcadero');

        expect(requestedUrl.queryParameters['orig'], 'EMBR');
        expect(board.station, 'Embarcadero');
        expect(board.departures.single.line, 'bart-red');
        expect(board.departures.single.minutes, 4);
        expect(
          board.departures.single.serviceTime,
          fetchedAt.add(const Duration(minutes: 4)),
        );
        expect(
          board.departures.single.serviceTimeKind,
          'RelativeDepartureMinutes',
        );
        expect(board.departures.single.timeStatusLabel, 'BART estimate');
      },
    );

    test('uses exact proxy service times when they are fresh', () async {
      final client = BartDeparturesClient(
        proxyBaseUrl: 'https://example.test/departures/',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'kind': 'departures',
              'station': 'Embarcadero',
              'fetchedAt': '2026-06-26T12:00:00Z',
              'list': [
                {
                  'line': 'muni-n',
                  'dest': 'Exact expected',
                  'mins': 99,
                  'serviceTime': '2026-06-26T12:04:00Z',
                  'serviceTimeKind': 'ExpectedDepartureTime',
                  'timeStatusLabel': 'Expected',
                },
                {
                  'line': 'bart-red',
                  'dest': 'Relative estimate',
                  'mins': 2,
                  'serviceTime': '2026-06-26T12:10:00Z',
                  'serviceTimeKind': 'RelativeDepartureMinutes',
                  'timeStatusLabel': 'BART estimate',
                },
                {
                  'line': 'muni-t',
                  'dest': 'Stale expected',
                  'mins': 3,
                  'serviceTime': '2026-06-26T11:55:00Z',
                  'serviceTimeKind': 'ExpectedDepartureTime',
                  'timeStatusLabel': 'Expected',
                },
              ],
            }),
            200,
          ),
        ),
      );

      final board = await client.fetchDepartures('EMBR');

      final departuresByDestination = {
        for (final departure in board.departures)
          departure.destination: departure,
      };

      final exactExpected = departuresByDestination['Exact expected']!;
      expect(exactExpected.minutes, 4);
      expect(
        exactExpected.serviceTime,
        DateTime.parse('2026-06-26T12:04:00Z'),
      );
      expect(exactExpected.serviceTimeKind, 'ExpectedDepartureTime');
      expect(exactExpected.timeStatusLabel, 'Expected');

      final relativeEstimate = departuresByDestination['Relative estimate']!;
      expect(relativeEstimate.minutes, 2);
      expect(
        relativeEstimate.serviceTime,
        DateTime.parse('2026-06-26T12:02:00Z'),
      );
      expect(relativeEstimate.serviceTimeKind, 'RelativeDepartureMinutes');
      expect(relativeEstimate.timeStatusLabel, 'BART estimate');

      final staleExpected = departuresByDestination['Stale expected']!;
      expect(staleExpected.minutes, 3);
      expect(
        staleExpected.serviceTime,
        DateTime.parse('2026-06-26T12:03:00Z'),
      );
      expect(staleExpected.serviceTimeKind, 'RelativeDepartureMinutes');
      expect(staleExpected.timeStatusLabel, 'BART estimate');
    });

    test('uses the public demo key when BART_API_KEY is blank', () async {
      late Uri requestedUrl;
      final client = BartDeparturesClient(
        bartApiKey: '',
        httpClient: MockClient((request) async {
          requestedUrl = request.url;
          return http.Response(
            jsonEncode({
              'root': {
                'station': [
                  {
                    'name': 'Embarcadero',
                    'etd': [
                      {
                        'destination': 'Richmond',
                        'estimate': [
                          {
                            'minutes': '4',
                            'platform': '2',
                            'color': 'RED',
                          },
                        ],
                      },
                    ],
                  },
                ],
              },
            }),
            200,
          );
        }),
      );

      await client.fetchDepartures('EMBR');

      expect(requestedUrl.queryParameters['key'], 'MW9S-E7SL-26DU-VV8V');
    });

    test('surfaces nested BART API errors', () async {
      final client = BartDeparturesClient(
        httpClient: MockClient(
          (_) async => http.Response(
            '{"root":{"message":{"error":"Invalid station abbreviation"}}}',
            200,
          ),
        ),
      );

      expect(
        client.fetchDepartures('XXXX'),
        throwsA(
          isA<BartDeparturesException>().having(
            (error) => error.message,
            'message',
            contains('Invalid station'),
          ),
        ),
      );
    });

    test('rejects unknown station names instead of truncating them', () async {
      final client = BartDeparturesClient(
        httpClient: MockClient((_) async {
          fail('Unknown long station names should not be sent to BART');
        }),
      );

      expect(
        client.fetchDepartures('Definitely Not A Station'),
        throwsA(
          isA<BartDeparturesException>().having(
            (error) => error.message,
            'message',
            contains('Invalid station'),
          ),
        ),
      );
    });

    test('uses nested warnings when no departures are available', () async {
      final client = BartDeparturesClient(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'root': {
                'message': {'warning': 'No data matched the request'},
                'station': [
                  {'name': 'Test Station'},
                ],
              },
            }),
            200,
          ),
        ),
      );

      expect(
        client.fetchDepartures('EMBR'),
        throwsA(
          isA<BartDeparturesException>().having(
            (error) => error.message,
            'message',
            contains('No data matched'),
          ),
        ),
      );
    });

    test(
      'parses single-object BART station, etd, and estimate payloads',
      () async {
        final client = BartDeparturesClient(
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'root': {
                  'station': {
                    'name': 'Embarcadero',
                    'etd': {
                      'destination': 'Dublin/Pleasanton',
                      'estimate': {
                        'minutes': 'Leaving',
                        'platform': '1',
                        'color': 'BLUE',
                      },
                    },
                  },
                },
              }),
              200,
            ),
          ),
        );

        final board = await client.fetchDepartures('EMBR');

        expect(board.departures, hasLength(1));
        expect(board.departures.single.line, 'bart-blue');
        expect(board.departures.single.destination, 'Dublin/Pleasanton');
        expect(board.departures.single.minutes, 0);
        expect(board.departures.single.platform, '1');
      },
    );

    test('keeps unmapped and empty BART colors neutral', () async {
      final client = BartDeparturesClient(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'root': {
                'station': [
                  {
                    'name': 'Embarcadero',
                    'etd': [
                      {
                        'destination': 'Mystery Train',
                        'estimate': [
                          {
                            'minutes': '7',
                            'color': 'PURPLE',
                          },
                          {
                            'minutes': '9',
                            'color': '',
                          },
                        ],
                      },
                    ],
                  },
                ],
              },
            }),
            200,
          ),
        ),
      );

      final board = await client.fetchDepartures('EMBR');

      expect(board.departures, hasLength(2));
      expect(board.departures.map((departure) => departure.line), [
        'unknown',
        'unknown',
      ]);
    });
  });
}
