import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('Downtown Berkeley  9:05'), findsOneWidget);
    expect(find.text('SFO  10:03'), findsOneWidget);
    expect(find.text('Ride to SFO'), findsOneWidget);
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
    expect(find.text('2 min'), findsOneWidget);
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
