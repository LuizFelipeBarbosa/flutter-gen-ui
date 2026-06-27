import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/explore/itinerary.dart';
import 'package:genui_template/places/places.dart';

void main() {
  group('ItineraryController', () {
    test('adds places and dedupes by place id', () {
      final controller = ItineraryController();
      addTearDown(controller.dispose);

      final added = controller.addPlace(
        const PlaceResult(
          id: 'place-1',
          displayName: 'Dolores Park',
          formattedAddress: 'Dolores St, San Francisco, CA',
          latitude: 37.7596,
          longitude: -122.4269,
        ),
      );
      final duplicate = controller.addPlace(
        const PlaceResult(
          id: 'place-1',
          displayName: 'Mission Dolores Park',
        ),
      );

      expect(added, isTrue);
      expect(duplicate, isFalse);
      expect(controller.value, hasLength(1));
      expect(controller.value.single.title, 'Dolores Park');
      expect(controller.value.single.latitude, 37.7596);
    });

    test('adds stops from action context and dedupes normalized text', () {
      final controller = ItineraryController();
      addTearDown(controller.dispose);

      expect(
        controller.addFromAction({
          'title': ' Ferry Building ',
          'address': '1 Ferry Building, San Francisco, CA',
          'category': 'Food',
        }),
        isTrue,
      );
      expect(
        controller.addFromAction({
          'title': 'ferry   building',
          'address': '1 ferry building, san francisco, ca',
        }),
        isFalse,
      );

      expect(controller.value, hasLength(1));
      expect(controller.value.single.category, 'Food');
    });

    test('removes, reorders, clears, and serializes prompt context', () {
      final controller = ItineraryController();
      addTearDown(controller.dispose);

      controller
        ..addFromAction({'title': 'Coffee', 'durationMinutes': 30})
        ..addFromAction({'title': 'Museum', 'durationMinutes': 90})
        ..addFromAction({'title': 'Dinner', 'durationMinutes': 75});

      final dinnerId = controller.value[2].localId;
      controller.move(dinnerId, -1);

      expect(
        controller.value.map((stop) => stop.title),
        ['Coffee', 'Dinner', 'Museum'],
      );
      expect(controller.toPromptContext(), contains('Avoid duplicate stops'));
      expect(controller.toPromptContext(), contains('Dinner | 75 min'));

      controller.remove(dinnerId);
      expect(
        controller.value.map((stop) => stop.title),
        ['Coffee', 'Museum'],
      );

      controller.clear();
      expect(controller.value, isEmpty);
      expect(controller.toPromptContext(), contains('Itinerary: empty'));
    });
  });
}
