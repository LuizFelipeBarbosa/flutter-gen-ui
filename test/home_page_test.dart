import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/explore/itinerary.dart';
import 'package:genui_template/explore/transit_route_handoff_controller.dart';
import 'package:genui_template/home_page.dart';
import 'package:genui_template/location/location.dart';
import 'package:genui_template/model/model_client.dart';
import 'package:genui_template/transit/google_routes_transit_client.dart';
import 'package:genui_template/transit/saved_itinerary_transit_planner.dart';

void main() {
  group('HomePage suggestions', () {
    testWidgets('starter idle action sends its query', (tester) async {
      late final _CapturingModelClient modelClient;

      final locationController = UserLocationController();
      addTearDown(locationController.dispose);

      await tester.pumpWidget(
        _TestApp(
          child: HomePage(
            locationController: locationController,
            modelClientBuilder: ({required systemPrompt}) {
              return modelClient = _CapturingModelClient(
                systemPrompt: systemPrompt,
              );
            },
          ),
        ),
      );
      await tester.pump();

      await _tapIdleAction(tester, 'starter_route');
      await _pumpUntil(tester, () => modelClient.history.isNotEmpty);

      expect(
        modelClient.history.single.text,
        contains('Request: Downtown Berkeley to SFO, leave now'),
      );
    });

    testWidgets(
      'nearby-stop-only first view renders nearby stop text and idle action '
      'sends departures query',
      (tester) async {
        late final _CapturingModelClient modelClient;

        final locationController = UserLocationController()
          ..value = _locationSnapshotNear4thAndKing();
        addTearDown(locationController.dispose);

        await tester.pumpWidget(
          _TestApp(
            child: HomePage(
              locationController: locationController,
              modelClientBuilder: ({required systemPrompt}) {
                return modelClient = _CapturingModelClient(
                  systemPrompt: systemPrompt,
                );
              },
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('4th & King'), findsWidgets);
        expect(_idleAction('nearby_departures'), findsOneWidget);
        expect(_idleAction('route_saved_itinerary'), findsNothing);
        expect(modelClient.history, isEmpty);

        await _tapIdleAction(tester, 'nearby_departures');
        await _pumpUntil(tester, () => modelClient.history.isNotEmpty);

        expect(
          modelClient.history.single.text,
          contains('Request: Next departures from 4th & King'),
        );
      },
    );

    testWidgets(
      'saved-itinerary context renders and idle route action sends route '
      'request',
      (tester) async {
        late final _CapturingModelClient modelClient;

        final locationController = UserLocationController();
        final itinerary = _savedItineraryController();
        addTearDown(locationController.dispose);
        addTearDown(itinerary.dispose);

        await tester.pumpWidget(
          _TestApp(
            child: HomePage(
              locationController: locationController,
              itineraryController: itinerary,
              currentTime: _testNow,
              transitPlanner: SavedItineraryTransitPlanner(
                client: _FakeTransitRouteClient(),
              ),
              modelClientBuilder: ({required systemPrompt}) {
                return modelClient = _CapturingModelClient(
                  systemPrompt: systemPrompt,
                );
              },
            ),
          ),
        );
        await tester.pump();

        final routeRequest = transitRouteRequestFor(itinerary.value)!;

        expect(find.text('Saved itinerary'), findsOneWidget);
        expect(find.text('Coffee → Museum'), findsOneWidget);
        expect(_idleAction('route_saved_itinerary'), findsOneWidget);
        expect(modelClient.history, isEmpty);

        await _tapIdleAction(tester, 'route_saved_itinerary');
        await _pumpUntil(tester, () => modelClient.history.isNotEmpty);

        expect(
          modelClient.history.single.text,
          contains('Request: $routeRequest'),
        );
        expect(
          modelClient.history.single.text,
          contains('Planner-backed route facts'),
        );
        expect(modelClient.history.single.text, contains('depart 9:30'));
        expect(modelClient.history.single.text, contains('arrive 9:42'));
      },
    );

    testWidgets('idle first view does not call the model before a tap', (
      tester,
    ) async {
      late final _CapturingModelClient modelClient;

      final locationController = UserLocationController()
        ..value = _locationSnapshotNear4thAndKing();
      final itinerary = _savedItineraryController();
      addTearDown(locationController.dispose);
      addTearDown(itinerary.dispose);

      await tester.pumpWidget(
        _TestApp(
          child: HomePage(
            locationController: locationController,
            itineraryController: itinerary,
            modelClientBuilder: ({required systemPrompt}) {
              return modelClient = _CapturingModelClient(
                systemPrompt: systemPrompt,
              );
            },
          ),
        ),
      );

      await tester.pump();

      expect(_idleAction('nearby_departures'), findsOneWidget);
      expect(_idleAction('route_saved_itinerary'), findsOneWidget);
      expect(modelClient.history, isEmpty);
    });

    testWidgets(
      'idle view updates when location or itinerary changes before first query',
      (tester) async {
        late final _CapturingModelClient modelClient;

        final locationController = UserLocationController();
        final itinerary = ItineraryController();
        addTearDown(locationController.dispose);
        addTearDown(itinerary.dispose);

        await tester.pumpWidget(
          _TestApp(
            child: HomePage(
              locationController: locationController,
              itineraryController: itinerary,
              currentTime: _testNow,
              transitPlanner: SavedItineraryTransitPlanner(
                client: _FakeTransitRouteClient(),
              ),
              modelClientBuilder: ({required systemPrompt}) {
                return modelClient = _CapturingModelClient(
                  systemPrompt: systemPrompt,
                );
              },
            ),
          ),
        );
        await tester.pump();

        expect(_idleAction('nearby_departures'), findsNothing);
        expect(_idleAction('route_saved_itinerary'), findsNothing);
        expect(modelClient.history, isEmpty);

        locationController.value = _locationSnapshotNear4thAndKing();
        await tester.pump();

        expect(find.textContaining('4th & King'), findsWidgets);
        expect(_idleAction('nearby_departures'), findsOneWidget);
        expect(_idleAction('route_saved_itinerary'), findsNothing);
        expect(modelClient.history, isEmpty);

        itinerary.replaceAll(_savedItineraryStops);
        await tester.pump();

        expect(find.text('Coffee → Museum'), findsOneWidget);
        expect(_idleAction('nearby_departures'), findsOneWidget);
        expect(_idleAction('route_saved_itinerary'), findsOneWidget);
        expect(modelClient.history, isEmpty);
      },
    );

    testWidgets('nearby stop row sends a departures query', (tester) async {
      late final _CapturingModelClient modelClient;

      final locationController = UserLocationController()
        ..value = _locationSnapshotNear4thAndKing();
      addTearDown(locationController.dispose);

      await tester.pumpWidget(
        _TestApp(
          child: HomePage(
            locationController: locationController,
            modelClientBuilder: ({required systemPrompt}) {
              return modelClient = _CapturingModelClient(
                systemPrompt: systemPrompt,
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.textContaining('4th & King').first);
      await _pumpUntil(tester, () => modelClient.history.isNotEmpty);

      expect(
        modelClient.history.single.text,
        contains('Request: Next departures from 4th & King'),
      );
    });

    testWidgets('focused search suggestions use generated action keys', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        late final _CapturingModelClient modelClient;

        final locationController = UserLocationController();
        addTearDown(locationController.dispose);

        await tester.pumpWidget(
          _TestApp(
            child: HomePage(
              locationController: locationController,
              modelClientBuilder: ({required systemPrompt}) {
                return modelClient = _CapturingModelClient(
                  systemPrompt: systemPrompt,
                );
              },
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byType(TextField));
        await tester.pump();

        expect(_searchSuggestion('starter_route'), findsOneWidget);
        expect(_searchSuggestion('starter_departures'), findsOneWidget);
        expect(_searchSuggestion('starter_status'), findsOneWidget);

        final suggestion = _searchSuggestion('starter_departures');
        expect(suggestion, findsOneWidget);

        await tester.tap(suggestion);
        await _pumpUntil(tester, () => modelClient.history.isNotEmpty);

        expect(
          modelClient.history.single.text,
          contains('Request: Next trains from Embarcadero'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('bottom sheet raises and lowers with mouse drags', (
      tester,
    ) async {
      final locationController = UserLocationController();
      addTearDown(locationController.dispose);

      await tester.pumpWidget(
        _TestApp(
          child: HomePage(
            locationController: locationController,
            modelClientBuilder: ({required systemPrompt}) {
              return _CapturingModelClient(systemPrompt: systemPrompt);
            },
          ),
        ),
      );
      await tester.pump();

      final sheet = find.byKey(const ValueKey('transit-sheet-scrollable'));
      final handle = find.byKey(const ValueKey('transit-sheet-drag-handle'));
      expect(sheet, findsOneWidget);
      expect(handle, findsOneWidget);

      final initialTop = tester.getTopLeft(sheet).dy;
      final lowerGesture = await tester.startGesture(
        tester.getCenter(handle),
        kind: PointerDeviceKind.mouse,
      );
      await lowerGesture.moveBy(const Offset(0, 280));
      await tester.pump();
      await lowerGesture.up();
      await tester.pumpAndSettle();

      final loweredTop = tester.getTopLeft(sheet).dy;
      expect(loweredTop, greaterThan(initialTop + 80));

      final raiseGesture = await tester.startGesture(
        tester.getCenter(handle),
        kind: PointerDeviceKind.mouse,
      );
      await raiseGesture.moveBy(const Offset(0, -280));
      await tester.pump();
      await raiseGesture.up();
      await tester.pumpAndSettle();

      final raisedTop = tester.getTopLeft(sheet).dy;
      expect(raisedTop, lessThan(loweredTop - 80));
    });

    testWidgets('saved itinerary panel sends a route query', (tester) async {
      late final _CapturingModelClient modelClient;

      final locationController = UserLocationController();
      final itinerary = _savedItineraryController();
      addTearDown(locationController.dispose);
      addTearDown(itinerary.dispose);

      await tester.pumpWidget(
        _TestApp(
          child: HomePage(
            locationController: locationController,
            itineraryController: itinerary,
            modelClientBuilder: ({required systemPrompt}) {
              return modelClient = _CapturingModelClient(
                systemPrompt: systemPrompt,
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Saved itinerary'), findsOneWidget);
      expect(find.text('Coffee → Museum'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Route'));
      await _pumpUntil(tester, () => modelClient.history.isNotEmpty);

      expect(
        modelClient.history.single.text,
        contains('Saved itinerary stops in order'),
      );
      expect(
        modelClient.history.single.text,
        contains('Request: Route this saved itinerary in order'),
      );
      expect(modelClient.history.single.text, contains('Coffee'));
      expect(modelClient.history.single.text, contains('Museum'));
    });

    testWidgets('route handoff sends a fresh route request', (tester) async {
      late final _CapturingModelClient modelClient;

      final locationController = UserLocationController();
      final handoffController = TransitRouteHandoffController();
      addTearDown(locationController.dispose);
      addTearDown(handoffController.dispose);

      await tester.pumpWidget(
        _TestApp(
          child: HomePage(
            locationController: locationController,
            routeHandoffController: handoffController,
            currentTime: _testNow,
            transitPlanner: SavedItineraryTransitPlanner(
              client: _FakeTransitRouteClient(),
            ),
            modelClientBuilder: ({required systemPrompt}) {
              return modelClient = _CapturingModelClient(
                systemPrompt: systemPrompt,
              );
            },
          ),
        ),
      );
      await tester.pump();

      handoffController.routeItinerary(const [
        ItineraryStop(
          localId: 'stop-1',
          title: 'Ferry Building',
          latitude: 37.795,
          longitude: -122.393,
        ),
      ]);
      await _pumpUntil(tester, () => modelClient.history.isNotEmpty);

      expect(
        modelClient.history.single.text,
        contains('Request: Route me to this saved itinerary stop'),
      );
      expect(modelClient.history.single.text, contains('Ferry Building'));
      expect(
        modelClient.history.single.text,
        contains('Current location is unavailable'),
      );
      expect(
        modelClient.history.single.text,
        contains('Transit planner facts are unavailable'),
      );
      expect(
        modelClient.history.single.text,
        contains('Do not render TransitJourney'),
      );
      expect(
        modelClient.history.single.text,
        isNot(contains('Planner-backed route facts')),
      );
    });
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: child);
  }
}

class _CapturingModelClient extends ModelClient {
  _CapturingModelClient({required super.systemPrompt});

  @override
  Stream<String> generateResponse() => const Stream.empty();

  @override
  void dispose() {}
}

const List<ItineraryStop> _savedItineraryStops = [
  ItineraryStop(
    localId: 'stop-1',
    title: 'Coffee',
    address: 'San Francisco, CA',
    durationMinutes: 30,
    latitude: 37.776,
    longitude: -122.408,
  ),
  ItineraryStop(
    localId: 'stop-2',
    title: 'Museum',
    address: 'San Francisco, CA',
    durationMinutes: 90,
    latitude: 37.785,
    longitude: -122.401,
  ),
];

DateTime _testNow() => DateTime.parse('2026-06-27T09:00:00Z');

class _FakeTransitRouteClient implements TransitRouteClient {
  @override
  Future<GoogleRoutesTransitJourney> fetchBestRoute({
    required LocationCoordinate origin,
    required LocationCoordinate destination,
    DateTime? departureTime,
    String originName = 'Origin',
    String destinationName = 'Destination',
    TransitRoutingPreference? routingPreference,
  }) async {
    final depart = departureTime ?? _testNow();
    final arrive = depart.add(const Duration(minutes: 12));
    return GoogleRoutesTransitJourney(
      from: originName,
      to: destinationName,
      departClock: _clock(depart),
      arriveClock: _clock(arrive),
      durationMinutes: 12,
      changes: 0,
      fare: r'$2.75',
      departureDateTime: depart,
      arrivalDateTime: arrive,
      legs: [
        GoogleRoutesTransitLeg.ride(
          durationMinutes: 12,
          lineId: 'regional-transit',
          from: originName,
          to: destinationName,
        ),
      ],
    );
  }

  @override
  void close() {}
}

String _clock(DateTime time) {
  return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
}

Finder _idleAction(String actionKey) {
  return find.byKey(ValueKey('idle-action-$actionKey'));
}

Finder _searchSuggestion(String actionKey) {
  return find.byKey(ValueKey('search-suggestion-$actionKey'));
}

Future<void> _tapIdleAction(WidgetTester tester, String actionKey) async {
  final action = _idleAction(actionKey);
  await tester.drag(
    find.byKey(const ValueKey('transit-sheet-drag-handle')),
    const Offset(0, -260),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.ensureVisible(action);
  await tester.pump();
  await tester.tap(action);
}

LocationSnapshot _locationSnapshotNear4thAndKing() {
  final capturedAt = DateTime(2026, 6, 26, 9);
  const coordinate = LocationCoordinate(latitude: 37.7751, longitude: -122.393);

  return LocationSnapshot.available(
    capturedAt: capturedAt,
    fix: UserLocationFix(
      coordinate: coordinate,
      accuracyMeters: 20,
      timestamp: capturedAt,
    ),
    nearestStop: nearestBayAreaTransitStop(coordinate),
  );
}

ItineraryController _savedItineraryController() {
  return ItineraryController()..replaceAll(_savedItineraryStops);
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempts = 0; attempts < 20; attempts++) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 16));
  }

  fail('Condition was not met before the pump limit.');
}
