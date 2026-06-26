import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/explore/explore_page.dart';
import 'package:genui_template/explore/itinerary.dart';
import 'package:genui_template/location/location.dart';

void main() {
  testWidgets('saved itinerary exposes a route in Transit action', (
    tester,
  ) async {
    final itinerary = ItineraryController()
      ..addFromAction({'title': 'Coffee'})
      ..addFromAction({'title': 'Museum'});
    final location = ValueNotifier(
      LocationSnapshot.idle(capturedAt: DateTime(2026, 6, 26, 9)),
    );
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
}
