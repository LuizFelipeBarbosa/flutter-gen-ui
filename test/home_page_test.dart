import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/explore/itinerary.dart';
import 'package:genui_template/explore/transit_route_handoff_controller.dart';
import 'package:genui_template/home_page.dart';
import 'package:genui_template/location/location.dart';
import 'package:genui_template/model/model_client.dart';

void main() {
  group('HomePage suggestions', () {
    testWidgets('intro suggestion sends its query', (tester) async {
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

      await tester.tap(
        find.byKey(
          const ValueKey(
            'intro-suggestion-Downtown Berkeley to SFO, leave now',
          ),
        ),
      );
      await _pumpUntil(tester, () => modelClient.history.isNotEmpty);

      expect(
        modelClient.history.single.text,
        contains('Request: Downtown Berkeley to SFO, leave now'),
      );
    });

    testWidgets('nearby stop row sends a departures query', (tester) async {
      late final _CapturingModelClient modelClient;

      final locationController = UserLocationController()
        ..value = LocationSnapshot.available(
          capturedAt: DateTime(2026, 6, 26, 9),
          fix: UserLocationFix(
            coordinate: const LocationCoordinate(
              latitude: 37.7751,
              longitude: -122.393,
            ),
            accuracyMeters: 20,
            timestamp: DateTime(2026, 6, 26, 9),
          ),
          nearestStop: nearestBayAreaTransitStop(
            const LocationCoordinate(latitude: 37.7751, longitude: -122.393),
          ),
        );
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

    testWidgets('focused search suggestion stays mounted and sends its query', (
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

        final suggestion = find.byKey(
          const ValueKey('search-suggestion-Next trains from Embarcadero'),
        );
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
      final itinerary = ItineraryController()
        ..addFromAction({
          'title': 'Coffee',
          'address': 'San Francisco, CA',
          'durationMinutes': 30,
        })
        ..addFromAction({
          'title': 'Museum',
          'address': 'San Francisco, CA',
          'durationMinutes': 90,
        });
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

      await tester.tap(find.text('Route'));
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
        ItineraryStop(localId: 'stop-1', title: 'Ferry Building'),
      ]);
      await _pumpUntil(tester, () => modelClient.history.isNotEmpty);

      expect(
        modelClient.history.single.text,
        contains('Request: Route me to this saved itinerary stop'),
      );
      expect(modelClient.history.single.text, contains('Ferry Building'));
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

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempts = 0; attempts < 20; attempts++) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 16));
  }

  fail('Condition was not met before the pump limit.');
}
