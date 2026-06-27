import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/transit/bart_departures_client.dart';
import 'package:genui_template/transit/transit_lines.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('LiveDeparturesClient 511 support', () {
    test('requires KEY_511 for 511 calls', () {
      final emptyKey = ''.trim();
      final client = LiveDeparturesClient(
        key511: emptyKey,
        httpClient: MockClient((_) async {
          fail('511 requests should not run without a token');
        }),
      );

      expect(
        client.fetch511Departures(agency: 'SF', stopCode: '15184'),
        throwsA(
          isA<LiveDeparturesException>().having(
            (error) => error.message,
            'message',
            contains('KEY_511'),
          ),
        ),
      );
    });

    test('filters and caches monitored agencies', () async {
      var operatorRequests = 0;
      final client = LiveDeparturesClient(
        key511: 'test-511-key',
        httpClient: MockClient((request) async {
          if (request.url.path == '/transit/operators') {
            operatorRequests += 1;
            return _jsonResponse({
              'operators': [
                {'Id': 'SF', 'Name': 'Muni', 'Monitored': true},
                {'Id': '5E', 'Name': 'Internal 511', 'Monitored': true},
                {'Id': 'ZZ', 'Name': 'Static Only', 'Monitored': false},
              ],
            });
          }
          return http.Response('not found', 404);
        }),
      );

      final first = await client.monitoredAgencies();
      final second = await client.monitoredAgencies();

      expect(first.map((agency) => agency.id), ['SF']);
      expect(second, same(first));
      expect(operatorRequests, 1);
    });

    test(
      'resolves agency and stop names, strips BOM, and parses SIRI times',
      () async {
        final requests = <Uri>[];
        final client = LiveDeparturesClient(
          key511: 'test-511-key',
          now: () => DateTime.parse('2026-06-26T12:00:00Z'),
          httpClient: MockClient((request) async {
            requests.add(request.url);
            return switch (request.url.path) {
              '/transit/operators' => _jsonResponse({
                'operators': [
                  {'Id': 'SF', 'Name': 'Muni', 'Monitored': true},
                ],
              }),
              '/transit/stops' => _jsonResponse({
                'stops': [
                  {'StopCode': '15184', 'Name': 'Metro Embarcadero'},
                ],
              }),
              '/transit/lines' => _jsonResponse({
                'lines': [
                  {'Id': 'N', 'Name': 'N Judah', 'TransportMode': 'tram'},
                  {'Id': 'K', 'Name': 'K Ingleside', 'TransportMode': 'tram'},
                ],
              }),
              '/transit/StopMonitoring' => _jsonResponse(
                _siri([
                  _visit(
                    line: 'N',
                    publishedLine: 'N',
                    destination: 'Ocean Beach',
                    stopName: 'Embarcadero Station',
                    expectedDeparture: '2026-06-26T12:04:00Z',
                  ),
                  _visit(
                    line: 'K',
                    publishedLine: 'K',
                    destination: 'Balboa Park',
                    stopName: 'Embarcadero Station',
                    expectedArrival: '2026-06-26T12:06:00Z',
                  ),
                  _visit(
                    line: 'N',
                    publishedLine: 'N',
                    destination: 'Caltrain',
                    stopName: 'Embarcadero Station',
                    aimedDeparture: '2026-06-26T12:08:00Z',
                  ),
                ]),
                prefixBom: true,
              ),
              _ => http.Response('not found', 404),
            };
          }),
        );

        final board = await client.fetch511Departures(
          agencyName: 'Muni',
          stopName: 'Metro Embarcadero',
        );

        expect(board.station, 'Embarcadero Station');
        expect(board.sourceLabel, 'Muni');
        expect(board.departures.map((departure) => departure.minutes), [
          4,
          6,
          8,
        ]);
        expect(board.departures.first.line, 'muni-n');
        expect(board.departures.first.lineLabel, 'N Judah');
        expect(board.departures.first.operatorName, 'Muni');
        expect(board.departures.first.mode, 'tram');

        final stopMonitoringUrl = requests.singleWhere(
          (url) => url.path == '/transit/StopMonitoring',
        );
        expect(stopMonitoringUrl.queryParameters['agency'], 'SF');
        expect(stopMonitoringUrl.queryParameters['stopcode'], '15184');
        expect(stopMonitoringUrl.queryParameters['api_key'], 'test-511-key');
      },
    );

    test(
      'preserves 511 time precedence, timezone offsets, and clamped minutes',
      () async {
        final client = LiveDeparturesClient(
          key511: 'test-511-key',
          now: () => DateTime.parse('2026-06-26T12:00:30Z'),
          httpClient: MockClient((request) async {
            if (request.url.path == '/transit/StopMonitoring') {
              return _jsonResponse(
                _siri([
                  _visit(
                    line: 'N',
                    publishedLine: 'N',
                    destination: 'Expected departure wins',
                    stopName: 'Embarcadero Station',
                    expectedDeparture: '2026-06-26T12:06:00Z',
                    expectedArrival: '2026-06-26T12:01:00Z',
                    aimedDeparture: '2026-06-26T12:02:00Z',
                    aimedArrival: '2026-06-26T12:03:00Z',
                  ),
                  _visit(
                    line: 'K',
                    publishedLine: 'K',
                    destination: 'Expected arrival wins',
                    stopName: 'Embarcadero Station',
                    expectedArrival: '2026-06-26T05:02:00-07:00',
                    aimedDeparture: '2026-06-26T12:04:00Z',
                  ),
                  _visit(
                    line: 'M',
                    publishedLine: 'M',
                    destination: 'Aimed departure wins',
                    stopName: 'Embarcadero Station',
                    aimedDeparture: '2026-06-26T12:08:00Z',
                    aimedArrival: '2026-06-26T12:05:00Z',
                  ),
                  _visit(
                    line: 'T',
                    publishedLine: 'T',
                    destination: 'Past aimed arrival clamps',
                    stopName: 'Embarcadero Station',
                    aimedArrival: '2026-06-26T04:59:00-07:00',
                  ),
                ]),
              );
            }
            return http.Response('not found', 404);
          }),
        );

        final board = await client.fetch511Departures(
          agency: 'SF',
          stopCode: '15184',
        );

        expect(board.fetchedAt, DateTime.parse('2026-06-26T12:00:30Z'));

        final departuresByDestination = {
          for (final departure in board.departures)
            departure.destination: departure,
        };
        final expectedDeparture =
            departuresByDestination['Expected departure wins']!;
        expect(expectedDeparture.minutes, 6);
        expect(expectedDeparture.serviceTimeKind, 'ExpectedDepartureTime');
        expect(expectedDeparture.timeStatusLabel, 'Expected');
        expect(
          expectedDeparture.serviceTime,
          DateTime.parse('2026-06-26T12:06:00Z'),
        );

        final expectedArrival =
            departuresByDestination['Expected arrival wins']!;
        expect(expectedArrival.minutes, 2);
        expect(expectedArrival.serviceTimeKind, 'ExpectedArrivalTime');
        expect(expectedArrival.timeStatusLabel, 'Expected');
        expect(
          expectedArrival.serviceTime!.isAtSameMomentAs(
            DateTime.parse('2026-06-26T12:02:00Z'),
          ),
          isTrue,
        );

        final aimedDeparture = departuresByDestination['Aimed departure wins']!;
        expect(aimedDeparture.minutes, 8);
        expect(aimedDeparture.serviceTimeKind, 'AimedDepartureTime');
        expect(aimedDeparture.timeStatusLabel, 'Scheduled');
        expect(
          aimedDeparture.serviceTime,
          DateTime.parse('2026-06-26T12:08:00Z'),
        );

        final pastAimedArrival =
            departuresByDestination['Past aimed arrival clamps']!;
        expect(pastAimedArrival.minutes, 0);
        expect(pastAimedArrival.serviceTimeKind, 'AimedArrivalTime');
        expect(pastAimedArrival.timeStatusLabel, 'Scheduled');
      },
    );

    test(
      'ignores stale 511 times before applying field precedence',
      () async {
        final client = LiveDeparturesClient(
          key511: 'test-511-key',
          now: () => DateTime.parse('2026-06-26T12:00:30Z'),
          httpClient: MockClient((request) async {
            if (request.url.path == '/transit/StopMonitoring') {
              return _jsonResponse(
                _siri([
                  _visit(
                    line: 'N',
                    publishedLine: 'N',
                    destination: 'Stale expected falls back',
                    stopName: 'Embarcadero Station',
                    expectedDeparture: '2026-06-26T11:57:00Z',
                    aimedDeparture: '2026-06-26T12:07:00Z',
                  ),
                  _visit(
                    line: 'K',
                    publishedLine: 'K',
                    destination: 'Near-past expected clamps',
                    stopName: 'Embarcadero Station',
                    expectedDeparture: '2026-06-26T11:59:00Z',
                    aimedDeparture: '2026-06-26T12:04:00Z',
                  ),
                  _visit(
                    line: 'M',
                    publishedLine: 'M',
                    destination: 'Stale only skipped',
                    stopName: 'Embarcadero Station',
                    expectedDeparture: '2026-06-26T11:55:00Z',
                  ),
                ]),
              );
            }
            return http.Response('not found', 404);
          }),
        );

        final board = await client.fetch511Departures(
          agency: 'SF',
          stopCode: '15184',
        );

        final departuresByDestination = {
          for (final departure in board.departures)
            departure.destination: departure,
        };
        expect(departuresByDestination, isNot(contains('Stale only skipped')));

        final fallback = departuresByDestination['Stale expected falls back']!;
        expect(fallback.minutes, 7);
        expect(fallback.serviceTimeKind, 'AimedDepartureTime');
        expect(fallback.timeStatusLabel, 'Scheduled');
        expect(
          fallback.serviceTime,
          DateTime.parse('2026-06-26T12:07:00Z'),
        );

        final nearPast = departuresByDestination['Near-past expected clamps']!;
        expect(nearPast.minutes, 0);
        expect(nearPast.serviceTimeKind, 'ExpectedDepartureTime');
        expect(nearPast.timeStatusLabel, 'Expected');
      },
    );

    test('uses local Muni stop codes for 4th and King', () async {
      final requests = <Uri>[];
      final client = LiveDeparturesClient(
        key511: 'test-511-key',
        now: () => DateTime.parse('2026-06-26T12:00:00Z'),
        httpClient: MockClient((request) async {
          requests.add(request.url);
          if (request.url.path == '/transit/stops') {
            fail('4th & King should use local stop-code aliases');
          }
          return switch (request.url.path) {
            '/transit/operators' => _jsonResponse({
              'operators': [
                {'Id': 'SF', 'Name': 'Muni', 'Monitored': true},
              ],
            }),
            '/transit/lines' => _jsonResponse({
              'lines': [
                {'Id': 'N', 'Name': 'N Judah', 'TransportMode': 'tram'},
                {'Id': 'T', 'Name': 'T Third', 'TransportMode': 'tram'},
                {'Id': '91', 'Name': '91 Owl', 'TransportMode': 'bus'},
              ],
            }),
            '/transit/StopMonitoring' => _jsonResponse(
              _siri([
                _visit(
                  line: _lineForStopCode(
                    request.url.queryParameters['stopcode'],
                  ),
                  publishedLine: _lineForStopCode(
                    request.url.queryParameters['stopcode'],
                  ),
                  destination: 'Inbound',
                  stopName: '4th & King',
                  expectedDeparture: '2026-06-26T12:05:00Z',
                ),
              ]),
            ),
            _ => http.Response('not found', 404),
          };
        }),
      );

      final board = await client.fetch511Departures(
        agency: 'SF',
        stopName: '4th & King',
      );

      final stopCodes = requests
          .where((url) => url.path == '/transit/StopMonitoring')
          .map((url) => url.queryParameters['stopcode'])
          .toSet();
      expect(stopCodes, {'15239', '15240', '17166', '17397', '17405'});
      expect(board.station, '4th & King');
      expect(board.departures, hasLength(5));
      expect(
        board.departures.map((departure) => departure.line).toSet(),
        containsAll({'muni-n', 'muni-t', regionalBusLineId}),
      );
    });

    test('filters local Muni stop-code aliases by line', () async {
      final requests = <Uri>[];
      final client = LiveDeparturesClient(
        key511: 'test-511-key',
        now: () => DateTime.parse('2026-06-26T12:00:00Z'),
        httpClient: MockClient((request) async {
          requests.add(request.url);
          return switch (request.url.path) {
            '/transit/operators' => _jsonResponse({
              'operators': [
                {'Id': 'SF', 'Name': 'Muni', 'Monitored': true},
              ],
            }),
            '/transit/lines' => _jsonResponse({
              'lines': [
                {'Id': 'T', 'Name': 'T Third', 'TransportMode': 'tram'},
              ],
            }),
            '/transit/StopMonitoring' => _jsonResponse(
              _siri([
                _visit(
                  line: 'T',
                  publishedLine: 'T',
                  destination: 'Chinatown',
                  stopName: '4th & King',
                  expectedDeparture: '2026-06-26T12:05:00Z',
                ),
              ]),
            ),
            _ => http.Response('not found', 404),
          };
        }),
      );

      await client.fetch511Departures(
        agency: 'SF',
        stopName: '4th & King',
        lineFilter: 'T Third',
      );

      final stopCodes = requests
          .where((url) => url.path == '/transit/StopMonitoring')
          .map((url) => url.queryParameters['stopcode'])
          .toList();
      expect(stopCodes, ['17166', '17397']);
    });

    test('maps non-core monitored operators to generic line styles', () async {
      final client = LiveDeparturesClient(
        key511: 'test-511-key',
        now: () => DateTime.parse('2026-06-26T12:00:00Z'),
        httpClient: MockClient((request) async {
          return switch (request.url.path) {
            '/transit/operators' => _jsonResponse({
              'operators': [
                {'Id': 'VT', 'Name': 'VTA', 'Monitored': true},
              ],
            }),
            '/transit/lines' => _jsonResponse({
              'lines': [
                {'Id': '22', 'Name': '22 Local', 'TransportMode': 'bus'},
              ],
            }),
            '/transit/StopMonitoring' => _jsonResponse(
              _siri([
                _visit(
                  line: '22',
                  publishedLine: '22',
                  destination: 'Palo Alto',
                  stopName: 'Santa Clara Transit Center',
                  expectedDeparture: '2026-06-26T12:05:00Z',
                ),
              ]),
            ),
            _ => http.Response('not found', 404),
          };
        }),
      );

      final board = await client.fetch511Departures(
        agency: 'VT',
        stopCode: '64723',
      );

      expect(board.sourceLabel, 'VTA');
      expect(board.departures.single.line, regionalBusLineId);
      expect(board.departures.single.lineLabel, '22 Local');
      expect(board.departures.single.operatorName, 'VTA');
    });

    test('surfaces SIRI error payloads', () {
      final client = LiveDeparturesClient(
        key511: 'test-511-key',
        httpClient: MockClient((request) async {
          if (request.url.path == '/transit/StopMonitoring') {
            return _jsonResponse({
              'ServiceDelivery': {
                'StopMonitoringDelivery': {
                  'ErrorCondition': {
                    'Description': 'Invalid stop code',
                  },
                },
              },
            });
          }
          return http.Response('not found', 404);
        }),
      );

      expect(
        client.fetch511Departures(agency: 'SF', stopCode: 'bad-stop'),
        throwsA(
          isA<LiveDeparturesException>().having(
            (error) => error.message,
            'message',
            contains('Invalid stop code'),
          ),
        ),
      );
    });

    test('caches live departure boards for the configured TTL', () async {
      var now = DateTime.parse('2026-06-26T12:00:00Z');
      var stopMonitoringRequests = 0;
      final client = LiveDeparturesClient(
        key511: 'test-511-key',
        now: () => now,
        httpClient: MockClient((request) async {
          if (request.url.path == '/transit/lines') {
            return _jsonResponse({
              'lines': [
                {'Id': 'N', 'Name': 'N Judah', 'TransportMode': 'tram'},
              ],
            });
          }
          if (request.url.path == '/transit/StopMonitoring') {
            stopMonitoringRequests += 1;
            return _jsonResponse(
              _siri([
                _visit(
                  line: 'N',
                  publishedLine: 'N',
                  destination: 'Ocean Beach',
                  stopName: 'Embarcadero Station',
                  expectedDeparture: '2026-06-26T12:04:00Z',
                ),
              ]),
            );
          }
          return http.Response('not found', 404);
        }),
      );

      await client.fetch511Departures(agency: 'SF', stopCode: '15184');
      await client.fetch511Departures(agency: 'SF', stopCode: '15184');
      now = now.add(const Duration(seconds: 61));
      await client.fetch511Departures(agency: 'SF', stopCode: '15184');

      expect(stopMonitoringRequests, 2);
    });
  });
}

http.Response _jsonResponse(
  Object body, {
  bool prefixBom = false,
}) {
  final json = jsonEncode(body);
  if (!prefixBom) return http.Response(json, 200);
  return http.Response.bytes(utf8.encode('\uFEFF$json'), 200);
}

Map<String, Object?> _siri(List<Map<String, Object?>> visits) {
  return {
    'ServiceDelivery': {
      'StopMonitoringDelivery': {
        'MonitoredStopVisit': visits,
      },
    },
  };
}

Map<String, Object?> _visit({
  required String line,
  required String publishedLine,
  required String destination,
  required String stopName,
  String? expectedDeparture,
  String? expectedArrival,
  String? aimedDeparture,
  String? aimedArrival,
}) {
  final call = <String, Object?>{
    'StopPointName': stopName,
    'ExpectedDepartureTime': expectedDeparture,
    'ExpectedArrivalTime': expectedArrival,
    'AimedDepartureTime': aimedDeparture,
    'AimedArrivalTime': aimedArrival,
  }..removeWhere((_, value) => value == null);

  return {
    'MonitoredVehicleJourney': {
      'LineRef': line,
      'PublishedLineName': publishedLine,
      'DestinationName': destination,
      'MonitoredCall': call,
    },
  };
}

String _lineForStopCode(String? stopCode) {
  return switch (stopCode) {
    '15239' || '15240' => 'N',
    '17166' || '17397' => 'T',
    '17405' => '91',
    _ => 'N',
  };
}
