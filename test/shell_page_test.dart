import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/explore/itinerary.dart';
import 'package:genui_template/explore/itinerary_store.dart';
import 'package:genui_template/shell_page.dart';

void main() {
  testWidgets('waits for saved itinerary before showing the shell', (
    tester,
  ) async {
    final store = _RecordingItineraryStore(
      stops: const [
        ItineraryStop(
          localId: 'stop-1',
          title: 'Coffee',
          address: 'San Francisco, CA',
          durationMinutes: 30,
        ),
        ItineraryStop(
          localId: 'stop-2',
          title: 'Museum',
          address: 'San Francisco, CA',
          durationMinutes: 90,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BayHopShellPage(itineraryStore: store),
      ),
    );

    final loadingIndicator = find.byKey(
      const ValueKey('itinerary-loading-indicator'),
    );

    expect(loadingIndicator, findsOneWidget);
    expect(find.text('Saved itinerary'), findsNothing);
    expect(store.saveCalls, 0);

    store.completeLoad();
    await _pumpUntil(
      tester,
      () => find.text('Saved itinerary').evaluate().isNotEmpty,
    );

    expect(loadingIndicator, findsNothing);
    expect(find.text('Saved itinerary'), findsOneWidget);
    expect(find.text('Coffee → Museum'), findsOneWidget);
    expect(store.saveCalls, 0);
  });
}

class _RecordingItineraryStore extends ItineraryStore {
  _RecordingItineraryStore({required this.stops});

  final List<ItineraryStop> stops;
  final Completer<List<ItineraryStop>> _loadCompleter =
      Completer<List<ItineraryStop>>();
  int saveCalls = 0;

  void completeLoad() {
    _loadCompleter.complete(stops);
  }

  @override
  Future<List<ItineraryStop>> load() => _loadCompleter.future;

  @override
  Future<void> save(List<ItineraryStop> stops) async {
    saveCalls += 1;
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempts = 0; attempts < 20; attempts++) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 16));
  }

  fail('Condition was not met before the pump limit.');
}
