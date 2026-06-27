import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/transit/bart_departures_client.dart';
import 'package:genui_template/transit/transit_widgets.dart';

void main() {
  testWidgets('TransitJourneyCard renders route details', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        child: TransitJourneyCard.fromJson(const {
          'recommended': true,
          'tag': 'Direct',
          'from': 'Downtown Berkeley',
          'to': 'SFO',
          'depart': '9:05',
          'arrive': '10:03',
          'duration': 58,
          'changes': 0,
          'fare': '11.95',
          'crowd': 'Some seats',
          'legs': [
            {
              'type': 'ride',
              'line': 'bart-red',
              'from': 'Downtown Berkeley',
              'to': 'SFO',
              'mins': 58,
              'stops': 18,
            },
          ],
        }),
      ),
    );

    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('9:05 → 10:03'), findsOneWidget);
    expect(find.text('Ride to SFO'), findsOneWidget);
    expect(find.textContaining('Depart Downtown Berkeley'), findsOneWidget);
    expect(find.textContaining('Arrive SFO'), findsOneWidget);
  });

  testWidgets('TransitJourneyCard auto-selects recommended route', (
    tester,
  ) async {
    TransitJourney? selectedJourney;

    await tester.pumpWidget(
      _TestApp(
        child: TransitRouteSelectionScope(
          onJourneySelected: (journey) => selectedJourney = journey,
          child: TransitJourneyCard.fromJson(const {
            'recommended': true,
            'tag': 'Direct',
            'from': 'Downtown Berkeley',
            'to': 'SFO',
            'depart': '9:05',
            'arrive': '10:03',
            'duration': 58,
            'changes': 0,
            'fare': '11.95',
            'crowd': 'Some seats',
            'legs': [
              {
                'type': 'ride',
                'line': 'bart-red',
                'from': 'Downtown Berkeley',
                'to': 'SFO',
                'mins': 58,
                'stops': 18,
              },
            ],
          }),
        ),
      ),
    );
    await tester.pump();

    expect(selectedJourney, isNotNull);
    expect(selectedJourney!.to, 'SFO');
  });

  testWidgets('TransitJourneyCard selects route when tapped', (tester) async {
    TransitJourney? selectedJourney;

    await tester.pumpWidget(
      _TestApp(
        child: TransitRouteSelectionScope(
          onJourneySelected: (journey) => selectedJourney = journey,
          child: TransitJourneyCard.fromJson(const {
            'recommended': false,
            'tag': 'Direct',
            'from': 'Downtown Berkeley',
            'to': 'SFO',
            'depart': '9:05',
            'arrive': '10:03',
            'duration': 58,
            'changes': 0,
            'fare': '11.95',
            'crowd': 'Some seats',
            'legs': [
              {
                'type': 'ride',
                'line': 'bart-red',
                'from': 'Downtown Berkeley',
                'to': 'SFO',
                'mins': 58,
                'stops': 18,
              },
            ],
          }),
        ),
      ),
    );

    expect(selectedJourney, isNull);

    await tester.tap(find.byType(TransitJourneyCard));
    await tester.pump();

    expect(selectedJourney, isNotNull);
    expect(selectedJourney!.from, 'Downtown Berkeley');
  });

  testWidgets('TransitJourneyCard normalizes OAK connector leg only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: TransitJourneyCard.fromJson(const {
          'recommended': true,
          'tag': 'Airport',
          'from': 'Downtown Berkeley',
          'to': 'Oakland Airport',
          'depart': '11:12',
          'arrive': '12:10',
          'duration': 58,
          'changes': 1,
          'fare': '12.20',
          'crowd': 'Some seats',
          'legs': [
            {
              'type': 'ride',
              'line': 'bart-orange',
              'from': 'Downtown Berkeley',
              'to': 'Coliseum',
              'mins': 25,
              'stops': 9,
            },
            {
              'type': 'change',
              'station': 'Coliseum',
              'mins': 4,
            },
            {
              'type': 'ride',
              'line': 'bart-beige',
              'from': 'Coliseum',
              'to': 'Oakland Airport',
              'mins': 30,
              'stops': 2,
            },
          ],
        }),
      ),
    );

    expect(find.text('38'), findsOneWidget);
    expect(find.text('11:12 → 11:50'), findsOneWidget);
    expect(find.textContaining('Arrive Oakland Airport'), findsOneWidget);
    expect(find.textContaining('1 stops · 9 min'), findsOneWidget);
  });

  testWidgets('TransitJourneyCard computes arrival from leg minutes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: TransitJourneyCard.fromJson(const {
          'recommended': true,
          'tag': 'Direct',
          'from': 'Downtown Berkeley',
          'to': 'SFO',
          'depart': '9:05',
          'arrive': '9:25',
          'duration': 20,
          'changes': 0,
          'fare': '11.95',
          'crowd': 'Some seats',
          'legs': [
            {
              'type': 'ride',
              'line': 'bart-red',
              'from': 'Downtown Berkeley',
              'to': 'SFO',
              'mins': 58,
              'stops': 18,
            },
          ],
        }),
      ),
    );

    expect(find.text('58'), findsOneWidget);
    expect(find.text('9:05 → 10:03'), findsOneWidget);
  });

  testWidgets('TransitJourneyCard wraps computed arrival after midnight', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: TransitJourneyCard.fromJson(const {
          'recommended': true,
          'tag': 'Late',
          'from': 'Origin',
          'to': 'Destination',
          'depart': '23:50',
          'arrive': '23:55',
          'duration': 5,
          'changes': 0,
          'fare': '2.75',
          'crowd': 'Quiet',
          'legs': [
            {
              'type': 'ride',
              'line': 'regional-transit',
              'from': 'Origin',
              'to': 'Destination',
              'mins': 20,
            },
          ],
        }),
      ),
    );

    expect(find.text('23:50 → 0:10'), findsOneWidget);
  });

  testWidgets('TransitJourneyCard leaves non-connector beige legs alone', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: TransitJourneyCard.fromJson(const {
          'recommended': true,
          'tag': 'Estimate',
          'from': 'MacArthur',
          'to': 'SFO',
          'depart': '10:00',
          'arrive': '10:30',
          'duration': 30,
          'changes': 0,
          'fare': '8.40',
          'crowd': 'Quiet',
          'legs': [
            {
              'type': 'ride',
              'line': 'bart-beige',
              'from': 'MacArthur',
              'to': 'SFO',
              'mins': 30,
              'stops': 7,
            },
          ],
        }),
      ),
    );

    expect(find.text('10:00 → 10:30'), findsOneWidget);
    expect(find.textContaining('7 stops · 30 min'), findsOneWidget);
  });

  testWidgets('TransitDeparturesCard renders departure rows', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        child: TransitDeparturesCard.fromJson(const {
          'station': 'Embarcadero',
          'live': true,
          'list': [
            {
              'line': 'bart-yellow',
              'dest': 'SFO / Millbrae',
              'plat': '2',
              'mins': 2,
            },
            {
              'line': 'muni-n',
              'dest': 'Ocean Beach',
              'mins': 3,
            },
          ],
        }),
      ),
    );

    expect(find.text('Embarcadero'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('SFO / Millbrae'), findsOneWidget);
    expect(find.text('Ocean Beach'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('TransitDeparturesCard renders live 511 metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: TransitDeparturesCard.fromJson(const {
          'station': 'Ferry Building',
          'live': true,
          'list': [
            {
              'line': 'regional-ferry',
              'lineLabel': 'Larkspur Ferry',
              'operatorName': 'Golden Gate Ferry',
              'mode': 'ferry',
              'dest': 'Larkspur',
              'mins': 5,
            },
          ],
        }),
      ),
    );

    expect(find.text('Ferry Building'), findsOneWidget);
    expect(find.text('Larkspur'), findsOneWidget);
    expect(
      find.text('Larkspur Ferry - Golden Gate Ferry - ferry'),
      findsOneWidget,
    );
  });

  testWidgets('TransitDeparturesCard renders service time before minutes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: TransitDeparturesCard.fromJson(const {
          'station': 'Embarcadero',
          'live': true,
          'statusLabel': 'Expected',
          'list': [
            {
              'line': 'muni-n',
              'dest': 'Ocean Beach',
              'mins': 4,
              'serviceTime': '2026-06-26T09:12:00-07:00',
              'serviceTimeKind': 'ExpectedDepartureTime',
              'timeStatusLabel': 'Expected',
            },
          ],
        }),
      ),
    );

    expect(find.text('Expected'), findsOneWidget);
    expect(find.text('9:12 AM'), findsOneWidget);
    expect(find.text('Expected - 4 min'), findsOneWidget);
    expect(find.text('Ocean Beach'), findsOneWidget);
  });

  testWidgets('LiveBartDeparturesBoard falls back to offline estimates', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: LiveBartDeparturesBoard(
          stationAbbr: 'EMBR',
          stationName: 'Embarcadero',
          client: _FailingBartDeparturesClient(),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(TransitNoteCard), findsNothing);
    expect(find.text('BART offline estimates - retrying'), findsOneWidget);
    expect(find.text('Embarcadero'), findsOneWidget);
    expect(find.text('Estimated'), findsOneWidget);
    expect(find.text('SFO / Millbrae'), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('LiveBartDeparturesBoard labels stale live data as cached', (
    tester,
  ) async {
    final client = _CachedThenFailingBartDeparturesClient();

    await tester.pumpWidget(
      _TestApp(
        child: LiveBartDeparturesBoard(
          stationAbbr: 'WCRK',
          stationName: 'Walnut Creek',
          client: client,
        ),
      ),
    );

    await tester.pump();
    expect(find.text('LIVE'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();

    expect(find.text('Cached'), findsOneWidget);
    expect(find.textContaining('BART cached departures'), findsOneWidget);
    expect(find.text('Antioch'), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('TransitAlertCard renders status details', (tester) async {
    await tester.pumpWidget(
      const _TestApp(
        child: TransitAlertCard(
          line: 'bart-yellow',
          status: 'minor',
          detail: 'About 10-minute delays while trains recover.',
        ),
      ),
    );

    expect(find.text('Yellow Line'), findsOneWidget);
    expect(find.text('Minor delays'), findsOneWidget);
    expect(find.textContaining('10-minute delays'), findsOneWidget);
  });

  testWidgets('TransitExploreBranch dispatches open explore action', (
    tester,
  ) async {
    String? actionName;
    Map<String, Object?>? actionContext;

    await tester.pumpWidget(
      _TestApp(
        child: TransitExploreBranch(
          title: 'Explore near SFO',
          subtitle: 'Food and coffee after arrival',
          badge: 'Explore',
          destination: 'SFO',
          query: 'Explore places near SFO after taking BART',
          onAction: (name, context) {
            actionName = name;
            actionContext = context;
          },
        ),
      ),
    );

    await tester.tap(find.text('Explore near SFO'));
    await tester.pump();

    expect(actionName, 'open_explore');
    expect(
      actionContext?['query'],
      'Explore places near SFO after taking BART',
    );
    expect(actionContext?['destination'], 'SFO');
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4FB0E8),
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(body: Center(child: child)),
    );
  }
}

class _FailingBartDeparturesClient extends BartDeparturesClient {
  @override
  Future<BartDepartureBoard> fetchDepartures(String stationAbbr) async {
    throw const BartDeparturesException('demo key unavailable');
  }

  @override
  void close() {}
}

class _CachedThenFailingBartDeparturesClient extends BartDeparturesClient {
  var _calls = 0;

  @override
  Future<BartDepartureBoard> fetchDepartures(String stationAbbr) async {
    _calls += 1;
    if (_calls == 1) {
      return const BartDepartureBoard(
        station: 'Walnut Creek',
        departures: [
          BartDeparture(
            line: 'bart-yellow',
            destination: 'Antioch',
            minutes: 4,
          ),
        ],
      );
    }

    throw const BartDeparturesException('network unavailable');
  }

  @override
  void close() {}
}
