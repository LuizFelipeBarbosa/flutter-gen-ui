import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/explore/explore_handoff_controller.dart';
import 'package:genui_template/explore/itinerary.dart';
import 'package:genui_template/explore/transit_route_handoff_controller.dart';

void main() {
  test('ExploreHandoffController emits a new handoff for repeated queries', () {
    final controller = ExploreHandoffController();
    addTearDown(controller.dispose);

    controller.open('Explore near SFO');
    final first = controller.value;

    controller.open('Explore near SFO');
    final second = controller.value;

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(second!.query, first!.query);
    expect(second.id, isNot(first.id));
  });

  test('TransitRouteHandoffController emits route requests repeatedly', () {
    final controller = TransitRouteHandoffController();
    addTearDown(controller.dispose);

    const stops = [
      ItineraryStop(localId: 'stop-1', title: 'Coffee'),
      ItineraryStop(localId: 'stop-2', title: 'Museum'),
    ];

    controller.routeItinerary(stops);
    final first = controller.value;

    controller.routeItinerary(stops);
    final second = controller.value;

    expect(first, isNotNull);
    expect(first!.query, contains('Route this saved itinerary in order'));
    expect(first.query, contains('Coffee'));
    expect(first.query, contains('Google-backed cards/lists'));
    expect(second, isNotNull);
    expect(second!.id, isNot(first.id));
  });

  test('transitRouteRequestFor returns null for empty itineraries', () {
    expect(transitRouteRequestFor(const []), isNull);
  });
}
