import 'dart:async';

import 'package:bayhop/explore/itinerary.dart';
import 'package:bayhop/explore/itinerary_store.dart';
import 'package:bayhop/location/location.dart';
import 'package:bayhop/shell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('publishes saved itinerary markers with valid coordinates', (
    tester,
  ) async {
    final placeOverlayController = MapPlaceOverlayController();
    addTearDown(placeOverlayController.dispose);

    final store = _RecordingItineraryStore(
      stops: const [
        ItineraryStop(
          localId: 'stop-1',
          title: 'Coffee',
          latitude: 37.776,
          longitude: -122.424,
        ),
        ItineraryStop(
          localId: 'stop-2',
          title: 'No coordinate stop',
        ),
        ItineraryStop(
          localId: 'stop-3',
          title: 'Museum',
          category: 'Art',
          latitude: 37.785,
          longitude: -122.401,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BayHopShellPage(
          itineraryStore: store,
          placeOverlayController: placeOverlayController,
        ),
      ),
    );

    store.completeLoad();
    await _pumpUntil(
      tester,
      () => placeOverlayController.savedItineraryMarkers.length == 2,
    );

    expect(
      placeOverlayController.savedItineraryMarkers.map((marker) => marker.id),
      ['stop-1', 'stop-3'],
    );
    expect(
      placeOverlayController.savedItineraryMarkers.map(
        (marker) => marker.sequence,
      ),
      [1, 3],
    );
    expect(
      placeOverlayController.savedItineraryMarkers.last.subtitle,
      'Art',
    );
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
