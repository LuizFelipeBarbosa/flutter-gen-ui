import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/location/location.dart';
import 'package:genui_template/places/places.dart';

void main() {
  group('MapPlaceOverlayController', () {
    test(
      'replaces search markers while preserving saved itinerary markers',
      () {
        final controller = MapPlaceOverlayController();
        addTearDown(controller.dispose);

        const savedMarker = MapPlaceMarker(
          id: 'stop-1',
          label: 'Coffee',
          coordinate: LocationCoordinate(latitude: 37.78, longitude: -122.4),
          kind: MapPlaceMarkerKind.savedItinerary,
          sequence: 1,
        );

        const firstSearchMarker = MapPlaceMarker(
          id: 'place-1',
          label: 'Museum',
          coordinate: LocationCoordinate(latitude: 37.79, longitude: -122.41),
          kind: MapPlaceMarkerKind.searchResult,
        );

        const secondSearchMarker = MapPlaceMarker(
          id: 'place-2',
          label: 'Park',
          coordinate: LocationCoordinate(latitude: 37.8, longitude: -122.42),
          kind: MapPlaceMarkerKind.searchResult,
        );

        controller
          ..showSavedItineraryMarkers([savedMarker])
          ..showSearchResults([firstSearchMarker]);

        expect(controller.value, [savedMarker, firstSearchMarker]);

        controller.showSearchResults([secondSearchMarker]);

        expect(controller.value, [savedMarker, secondSearchMarker]);

        controller.clearSearchResults();

        expect(controller.value, [savedMarker]);
      },
    );

    test('builds Google Places markers only for valid coordinates', () {
      final markers = MapPlaceMarker.searchResultsFromPlaces(
        [
          PlaceResult(
            id: 'place-1',
            displayName: 'Valid Park',
            formattedAddress: 'Dolores St, San Francisco, CA',
            latitude: 37.7596,
            longitude: -122.4269,
            googleMapsUri: Uri.parse('https://maps.google.com/?cid=1'),
          ),
          const PlaceResult(
            id: 'place-2',
            displayName: 'Missing latitude',
            longitude: -122.4269,
          ),
          const PlaceResult(
            id: 'place-3',
            displayName: 'Missing longitude',
            latitude: 37.7596,
          ),
        ],
      );

      expect(markers, hasLength(1));
      expect(markers.single.id, 'place-1');
      expect(markers.single.label, 'Valid Park');
      expect(markers.single.subtitle, 'Dolores St, San Francisco, CA');
      expect(markers.single.kind, MapPlaceMarkerKind.searchResult);
      expect(markers.single.googleMapsUri, isNotNull);
    });
  });
}
