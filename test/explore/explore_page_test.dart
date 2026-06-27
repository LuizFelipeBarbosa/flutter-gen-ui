import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/explore/explore_page.dart';
import 'package:genui_template/explore/itinerary.dart';
import 'package:genui_template/location/location.dart';
import 'package:genui_template/model/model_client.dart';

void main() {
  testWidgets('saved itinerary exposes a route in Transit action', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1000, 800));
    final itinerary = ItineraryController()
      ..addFromAction({'title': 'Coffee'})
      ..addFromAction({'title': 'Museum'});
    final location = _testLocation();
    var routed = false;

    addTearDown(itinerary.dispose);
    addTearDown(location.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExplorePage(
            itineraryController: itinerary,
            locationListenable: location,
            onRouteInTransit: () => routed = true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2 stops'), findsOneWidget);
    expect(find.byTooltip('Route in Transit'), findsOneWidget);

    await tester.tap(find.byTooltip('Route in Transit'));
    await tester.pump();

    expect(routed, isTrue);
  });

  testWidgets('navigation chips send expected prompts', (tester) async {
    await _setSurfaceSize(tester, const Size(1000, 800));
    final itinerary = ItineraryController();
    final location = _testLocation();
    late final _TestModelClient modelClient;

    addTearDown(itinerary.dispose);
    addTearDown(location.dispose);

    await _pumpExplorePage(
      tester,
      itinerary: itinerary,
      location: location,
      modelClientBuilder: ({required systemPrompt}) {
        return modelClient = _TestModelClient(systemPrompt: systemPrompt);
      },
    );

    await tester.tap(find.text('Food'));
    await _pumpUntil(tester, () => modelClient.history.isNotEmpty);

    expect(
      modelClient.history.single.text,
      contains('Request: Explore food stops, snack crawls, and coffee nearby.'),
    );
  });

  testWidgets('remix chips send current result prompts', (tester) async {
    await _setSurfaceSize(tester, const Size(1000, 800));
    final itinerary = ItineraryController();
    final location = _testLocation();
    late final _TestModelClient modelClient;

    addTearDown(itinerary.dispose);
    addTearDown(location.dispose);

    await _pumpExplorePage(
      tester,
      itinerary: itinerary,
      location: location,
      modelClientBuilder: ({required systemPrompt}) {
        return modelClient = _TestModelClient(
          systemPrompt: systemPrompt,
          responses: [_summarySurface('Nearby branch')],
        );
      },
    );

    await tester.tap(find.text('Nearby'));
    await _pumpUntil(
      tester,
      () => find.text('More scenic').evaluate().isNotEmpty,
    );

    await tester.tap(find.text('More scenic'));
    await _pumpUntil(tester, () => modelClient.history.length >= 3);

    final prompt = modelClient.history.last.text;
    expect(prompt, contains('Remix the current Explore result/request'));
    expect(
      prompt,
      contains('Find nearby mini adventures and grounded places.'),
    );
    expect(prompt, contains('Make it more scenic'));
  });

  testWidgets('back renders an earlier generated surface', (tester) async {
    await _setSurfaceSize(tester, const Size(1000, 800));
    final itinerary = ItineraryController();
    final location = _testLocation();

    addTearDown(itinerary.dispose);
    addTearDown(location.dispose);

    await _pumpExplorePage(
      tester,
      itinerary: itinerary,
      location: location,
      modelClientBuilder: ({required systemPrompt}) {
        return _TestModelClient(
          systemPrompt: systemPrompt,
          responses: [
            _summarySurface('First branch'),
            _summarySurface('Second branch'),
          ],
        );
      },
    );

    await tester.tap(find.text('Nearby'));
    await _pumpUntil(
      tester,
      () => find.text('First branch').evaluate().isNotEmpty,
    );

    await tester.tap(find.text('Food'));
    await _pumpUntil(
      tester,
      () => find.text('Second branch').evaluate().isNotEmpty,
    );

    expect(find.byTooltip('Back'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('First branch'), findsOneWidget);
    expect(find.text('Second branch'), findsNothing);
  });

  testWidgets('ExploreAdventurePlan bulk-adds stops in order', (tester) async {
    await _setSurfaceSize(tester, const Size(1000, 800));
    final itinerary = ItineraryController();
    final location = _testLocation();

    addTearDown(itinerary.dispose);
    addTearDown(location.dispose);

    await _pumpExplorePage(
      tester,
      itinerary: itinerary,
      location: location,
      modelClientBuilder: ({required systemPrompt}) {
        return _TestModelClient(
          systemPrompt: systemPrompt,
          responses: [_adventureSurface],
        );
      },
    );

    await tester.tap(find.text('One Shot'));
    await _pumpUntil(tester, () => find.text('Add all').evaluate().isNotEmpty);

    await tester.tap(find.text('Add all'));
    await tester.pump();

    expect(
      itinerary.value.map((stop) => stop.title),
      ['Coffee Stop', 'View Stop', 'Museum Stop'],
    );
  });

  testWidgets('mobile itinerary sheet expands and collapses', (tester) async {
    await _setSurfaceSize(tester, const Size(500, 800));
    final itinerary = ItineraryController()
      ..addFromAction({'title': 'Coffee'})
      ..addFromAction({'title': 'Museum'});
    final location = _testLocation();

    addTearDown(itinerary.dispose);
    addTearDown(location.dispose);

    await _pumpExplorePage(
      tester,
      itinerary: itinerary,
      location: location,
      modelClientBuilder: ({required systemPrompt}) {
        return _TestModelClient(systemPrompt: systemPrompt);
      },
    );

    expect(find.byTooltip('Expand itinerary'), findsOneWidget);
    expect(find.text('2 stops'), findsOneWidget);
    expect(find.text('Coffee'), findsNothing);

    await tester.tap(find.byTooltip('Expand itinerary'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Collapse itinerary'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);

    await tester.tap(find.byTooltip('Collapse itinerary'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Expand itinerary'), findsOneWidget);
    expect(find.text('Coffee'), findsNothing);
  });
}

Future<void> _pumpExplorePage(
  WidgetTester tester, {
  required ItineraryController itinerary,
  required ValueNotifier<LocationSnapshot> location,
  required ModelClient Function({required String systemPrompt})
  modelClientBuilder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ExplorePage(
          itineraryController: itinerary,
          locationListenable: location,
          modelClientBuilder: modelClientBuilder,
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _setSurfaceSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var attempts = 0; attempts < 40; attempts++) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 10));
  }

  fail('Condition was not met before the pump limit.');
}

ValueNotifier<LocationSnapshot> _testLocation() {
  return ValueNotifier(
    LocationSnapshot.idle(capturedAt: DateTime(2026, 6, 26, 9)),
  );
}

class _TestModelClient extends ModelClient {
  _TestModelClient({
    required super.systemPrompt,
    this.responses = const [],
  });

  final List<String> responses;
  var _responseIndex = 0;

  @override
  Stream<String> generateResponse() async* {
    if (_responseIndex < responses.length) {
      yield responses[_responseIndex++];
    }
  }

  @override
  void dispose() {}
}

String _summarySurface(String title) {
  return '''
```json
{"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"$basicCatalogId","sendDataModel":true}}
```
```json
{"version":"v0.9","updateComponents":{"surfaceId":"main","components":[{"id":"root","component":"ExploreSummary","title":"$title","summary":"Pick the next branch."}]}}
```
''';
}

const _adventureSurface =
    '''
```json
{"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"$basicCatalogId","sendDataModel":true}}
```
```json
{"version":"v0.9","updateComponents":{"surfaceId":"main","components":[{"id":"root","component":"ExploreAdventurePlan","title":"One-shot test","summary":"A complete preview.","durationLabel":"3h","priceLabel":"Free","transitHint":"BART + walking","stops":[{"title":"Coffee Stop","category":"Coffee","durationMinutes":30},{"title":"View Stop","category":"Views","durationMinutes":45},{"title":"Museum Stop","category":"Culture","durationMinutes":60}]}]}}
```
''';
