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
        client.fetchDepartures('TEST'),
        throwsA(
          isA<BartDeparturesException>().having(
            (error) => error.message,
            'message',
            contains('No data matched'),
          ),
        ),
      );
    });
  });
}
