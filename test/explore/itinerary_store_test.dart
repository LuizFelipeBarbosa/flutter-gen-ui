import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/explore/itinerary.dart';
import 'package:genui_template/explore/itinerary_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ItineraryStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and loads a versioned itinerary payload', () async {
      final store = ItineraryStore();
      final stops = [
        const ItineraryStop(
          localId: 'stop-1',
          placeId: 'place-1',
          title: 'Dolores Park',
          address: 'Dolores St, San Francisco, CA',
          category: 'Park',
          latitude: 37.7596,
          longitude: -122.4269,
        ),
      ];

      await store.save(stops);

      final loaded = await store.load();

      expect(loaded, hasLength(1));
      expect(loaded.single.localId, 'stop-1');
      expect(loaded.single.title, 'Dolores Park');
      expect(loaded.single.latitude, 37.7596);
    });

    test('returns an empty itinerary for malformed stored data', () async {
      SharedPreferences.setMockInitialValues({
        ItineraryStore.defaultKey: 'not json',
      });

      final loaded = await ItineraryStore().load();

      expect(loaded, isEmpty);
    });

    test('skips malformed stops inside an otherwise valid payload', () async {
      SharedPreferences.setMockInitialValues({
        ItineraryStore.defaultKey: jsonEncode({
          'version': 1,
          'stops': [
            {'localId': 'stop-1', 'title': 'Valid'},
            {'localId': 'stop-2'},
            'bad',
          ],
        }),
      });

      final loaded = await ItineraryStore().load();

      expect(loaded.map((stop) => stop.title), ['Valid']);
    });

    test('ignores unsupported payload versions', () async {
      SharedPreferences.setMockInitialValues({
        ItineraryStore.defaultKey: jsonEncode({
          'version': 99,
          'stops': [
            {'localId': 'stop-1', 'title': 'Future'},
          ],
        }),
      });

      final loaded = await ItineraryStore().load();

      expect(loaded, isEmpty);
    });
  });
}
