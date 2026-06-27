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

    test('round-trips stops through json', () {
      final stop = ItineraryStop(
        localId: 'stop-8',
        placeId: 'place-1',
        title: 'Ferry Building',
        address: '1 Ferry Building, San Francisco, CA',
        category: 'Food',
        durationMinutes: 45,
        latitude: 37.7955,
        longitude: -122.3937,
        googleMapsUri: Uri.parse('https://maps.google.com/?cid=place-1'),
        notes: 'Snack stop',
      );

      final decoded = ItineraryStop.fromJson(stop.toJson());

      expect(decoded.localId, stop.localId);
      expect(decoded.placeId, stop.placeId);
      expect(decoded.title, stop.title);
      expect(decoded.address, stop.address);
      expect(decoded.category, stop.category);
      expect(decoded.durationMinutes, stop.durationMinutes);
      expect(decoded.latitude, stop.latitude);
      expect(decoded.longitude, stop.longitude);
      expect(decoded.googleMapsUri, stop.googleMapsUri);
      expect(decoded.notes, stop.notes);
    });

    test('replaceAll dedupes and preserves next local id continuity', () {
      final controller = ItineraryController();
      addTearDown(controller.dispose);

      controller.replaceAll([
        const ItineraryStop(localId: 'stop-7', title: 'Coffee'),
        const ItineraryStop(localId: 'stop-9', title: 'Museum'),
        const ItineraryStop(localId: 'stop-3', title: 'coffee'),
      ]);

      expect(controller.value.map((stop) => stop.title), ['Coffee', 'Museum']);

      controller.addFromAction({'title': 'Dinner'});

      expect(controller.value.last.localId, 'stop-10');
    });

    test('bulk add preserves order and reports duplicates', () {
      final controller = ItineraryController();
      addTearDown(controller.dispose);

      controller.addFromAction({'title': 'Coffee'});

      final result = controller.addFromActions([
        {'title': 'coffee'},
        {'title': 'Museum', 'durationMinutes': 90},
        {'title': 'museum', 'durationMinutes': 30},
        {'title': 'Dinner'},
      ]);

      expect(result.added, 2);
      expect(result.skipped, 2);
      expect(result.total, 4);
      expect(
        controller.value.map((stop) => stop.title),
        ['Coffee', 'Museum', 'Dinner'],
      );
      expect(controller.value[1].durationMinutes, 90);
    });

    test('transit prompt includes ordered saved stop context', () {
      final controller = ItineraryController();
      addTearDown(controller.dispose);

      controller.addFromAction({
        'title': 'Ferry Building',
        'address': '1 Ferry Building',
        'durationMinutes': 45,
        'latitude': 37.7955,
        'longitude': -122.3937,
      });

      expect(
        controller.toTransitPromptContext(),
        contains('Saved itinerary stops in order'),
      );
      expect(controller.toTransitPromptContext(), contains('coords 37.79550'));
      expect(
        controller.toTransitPromptContext(),
        contains('cards/lists rather than map markers'),
      );
    });
  });
}
