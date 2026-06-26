import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/location/location.dart';
import 'package:genui_template/transit/transit_lines.dart';
import 'package:genui_template/transit/transit_route_geometry.dart';
import 'package:genui_template/transit/transit_widgets.dart';

void main() {
  group('resolveTransitRouteStop', () {
    test('matches station names case-insensitively', () {
      final stop = resolveTransitRouteStop('downtown berkeley');

      expect(stop, isNotNull);
      expect(stop!.id, 'bart-downtown-berkeley');
    });

    test('matches BART abbreviations', () {
      final stop = resolveTransitRouteStop('DBRK');

      expect(stop, isNotNull);
      expect(stop!.name, 'Downtown Berkeley');
    });

    test('prefers stops served by the requested line', () {
      final muniStop = resolveTransitRouteStop(
        'Powell',
        lineId: 'muni-n',
      );
      final bartStop = resolveTransitRouteStop(
        'Powell',
        lineId: 'bart-red',
      );

      expect(muniStop?.id, 'muni-powell');
      expect(bartStop?.id, 'bart-powell');
    });

    test('returns null for unresolved endpoints', () {
      expect(resolveTransitRouteStop('Atlantis Terminal'), isNull);
    });
  });

  group('buildTransitJourneyRouteOverlay', () {
    test('builds direct Downtown Berkeley to SFO geometry', () {
      final overlay = buildTransitJourneyRouteOverlay(
        _journey(
          from: 'Downtown Berkeley',
          to: 'SFO',
          legs: const [
            {
              'type': 'ride',
              'line': 'bart-red',
              'from': 'Downtown Berkeley',
              'to': 'SFO',
              'mins': 58,
              'stops': 18,
            },
          ],
        ),
      );

      expect(overlay, isNotNull);
      expect(overlay!.segments, hasLength(1));
      expect(overlay.segments.single.points.length, greaterThan(2));
      expect(overlay.markers.map((marker) => marker.label), contains('SFO'));
    });

    test('builds OAK connector geometry', () {
      final overlay = buildTransitJourneyRouteOverlay(
        _journey(
          from: 'Coliseum',
          to: 'Oakland Airport',
          legs: const [
            {
              'type': 'ride',
              'line': 'bart-beige',
              'from': 'Coliseum',
              'to': 'Oakland Airport',
              'mins': 9,
              'stops': 1,
            },
          ],
        ),
      );

      expect(overlay, isNotNull);
      expect(overlay!.segments.single.points, hasLength(2));
      expect(
        overlay.markers.map((marker) => marker.label),
        contains('Oakland Airport'),
      );
    });

    test('builds transfer route geometry', () {
      final overlay = buildTransitJourneyRouteOverlay(
        _journey(
          from: 'Walnut Creek',
          to: 'Berryessa/North San Jose',
          changes: 1,
          legs: const [
            {
              'type': 'ride',
              'line': 'bart-yellow',
              'from': 'Walnut Creek',
              'to': 'MacArthur',
              'mins': 18,
              'stops': 4,
            },
            {'type': 'change', 'station': 'MacArthur', 'mins': 4},
            {
              'type': 'ride',
              'line': 'bart-orange',
              'from': 'MacArthur',
              'to': 'Berryessa/North San Jose',
              'mins': 54,
              'stops': 16,
            },
          ],
        ),
      );

      expect(overlay, isNotNull);
      expect(overlay!.segments, hasLength(2));
      expect(
        overlay.markers
            .where((marker) => marker.kind == MapRouteMarkerKind.transfer)
            .map((marker) => marker.label),
        contains('MacArthur'),
      );
    });

    test('uses current location for from-here walk legs', () {
      const currentLocation = LocationCoordinate(
        latitude: 37.7858,
        longitude: -122.4064,
      );

      final overlay = buildTransitJourneyRouteOverlay(
        _journey(
          from: 'Current location',
          to: 'SFO',
          legs: const [
            {'type': 'walk', 'to': 'Powell St', 'mins': 4},
            {
              'type': 'ride',
              'line': 'bart-yellow',
              'from': 'Powell St',
              'to': 'SFO',
              'mins': 34,
              'stops': 9,
            },
          ],
        ),
        currentLocation: currentLocation,
      );

      expect(overlay, isNotNull);
      expect(overlay!.segments.first.dashed, isTrue);
      expect(overlay.segments.first.points.first, currentLocation);
      expect(
        overlay.markers.map((marker) => marker.label),
        contains('Current location'),
      );
    });

    test('builds regional bus geometry between known transit stops', () {
      final overlay = buildTransitJourneyRouteOverlay(
        _journey(
          from: 'Downtown Berkeley',
          to: 'MacArthur',
          legs: const [
            {
              'type': 'ride',
              'line': regionalBusLineId,
              'from': 'Downtown Berkeley',
              'to': 'MacArthur',
              'mins': 18,
              'stops': 8,
            },
          ],
        ),
      );

      expect(overlay, isNotNull);
      expect(overlay!.segments, hasLength(1));
      expect(overlay.segments.single.label, 'Bus');
      expect(overlay.segments.single.color, lineFor(regionalBusLineId).color);
      expect(overlay.segments.single.dashed, isFalse);
      expect(overlay.segments.single.points, hasLength(2));
    });

    test('builds regional bus geometry to a local route anchor', () {
      final overlay = buildTransitJourneyRouteOverlay(
        _journey(
          from: 'Downtown Berkeley',
          to: 'UC Berkeley',
          legs: const [
            {
              'type': 'ride',
              'line': regionalBusLineId,
              'from': 'Downtown Berkeley',
              'to': 'UC Berkeley',
              'mins': 7,
              'stops': 3,
            },
          ],
        ),
      );

      expect(overlay, isNotNull);
      final endpoint = overlay!.segments.single.points.last;
      expect(endpoint.latitude, closeTo(37.8719, 0.0001));
      expect(endpoint.longitude, closeTo(-122.2585, 0.0001));
      expect(
        overlay.markers.map((marker) => marker.label),
        contains('UC Berkeley'),
      );
    });

    test('builds trailing walk geometry to a local route anchor', () {
      final overlay = buildTransitJourneyRouteOverlay(
        _journey(
          from: 'MacArthur',
          to: 'UC Berkeley',
          legs: const [
            {
              'type': 'ride',
              'line': 'bart-red',
              'from': 'MacArthur',
              'to': 'Downtown Berkeley',
              'mins': 8,
              'stops': 2,
            },
            {'type': 'walk', 'to': 'UC Berkeley', 'mins': 9},
          ],
        ),
      );

      expect(overlay, isNotNull);
      expect(overlay!.segments, hasLength(2));
      expect(overlay.segments.last.label, 'Walk');
      expect(overlay.segments.last.dashed, isTrue);
      expect(
        overlay.segments.last.points.last.latitude,
        closeTo(37.8719, 0.0001),
      );
    });

    test('builds foot-only geometry from current location to an anchor', () {
      const currentLocation = LocationCoordinate(
        latitude: 37.792,
        longitude: -122.397,
      );

      final overlay = buildTransitJourneyRouteOverlay(
        _journey(
          from: 'Current location',
          to: 'Ferry Building',
          legs: const [
            {'type': 'walk', 'to': 'Ferry Building', 'mins': 8},
          ],
        ),
        currentLocation: currentLocation,
      );

      expect(overlay, isNotNull);
      expect(overlay!.segments, hasLength(1));
      expect(overlay.segments.single.dashed, isTrue);
      expect(overlay.segments.single.points.first, currentLocation);
      expect(
        overlay.markers.map((marker) => marker.label),
        containsAll(['Current location', 'Ferry Building']),
      );
    });

    test('builds mixed rail, bus, and walk geometry', () {
      final overlay = buildTransitJourneyRouteOverlay(
        _journey(
          from: 'Downtown Berkeley',
          to: 'Ferry Building',
          changes: 1,
          legs: const [
            {
              'type': 'ride',
              'line': 'bart-red',
              'from': 'Downtown Berkeley',
              'to': 'Embarcadero',
              'mins': 27,
              'stops': 8,
            },
            {'type': 'change', 'station': 'Embarcadero', 'mins': 4},
            {
              'type': 'ride',
              'line': regionalBusLineId,
              'from': 'Embarcadero',
              'to': 'Salesforce Transit Center',
              'mins': 5,
              'stops': 1,
            },
            {'type': 'walk', 'to': 'Ferry Building', 'mins': 7},
          ],
        ),
      );

      expect(overlay, isNotNull);
      expect(overlay!.segments.map((segment) => segment.label), [
        'Red Line',
        'Bus',
        'Walk',
      ]);
      expect(overlay.segments.last.dashed, isTrue);
      expect(
        overlay.markers
            .where((marker) => marker.kind == MapRouteMarkerKind.transfer)
            .map((marker) => marker.label),
        contains('Embarcadero'),
      );
    });

    test('builds generated Berkeley to Petaluma bus route geometry', () {
      final overlay = buildTransitJourneyRouteOverlay(
        _journey(
          from: 'Berkeley (BART)',
          to: 'Petaluma',
          changes: 1,
          legs: const [
            {
              'type': 'ride',
              'line': 'bart-red',
              'from': 'Berkeley (BART)',
              'to': 'Embarcadero',
              'mins': 22,
              'stops': 10,
            },
            {'type': 'walk', 'to': 'Ferry Building', 'mins': 5},
            {
              'type': 'ride',
              'line': regionalBusLineId,
              'from': 'Ferry Building',
              'to': 'Petaluma',
              'mins': 45,
            },
          ],
        ),
      );

      expect(overlay, isNotNull);
      expect(overlay!.segments.map((segment) => segment.label), [
        'Red Line',
        'Walk',
        'Bus',
      ]);
      expect(
        overlay.segments.last.points.last.latitude,
        closeTo(38.2324, 0.0001),
      );
      expect(
        overlay.markers.map((marker) => marker.label),
        contains('Petaluma'),
      );
    });

    test('skips unresolved bus and walk endpoints without failing route', () {
      final overlay = buildTransitJourneyRouteOverlay(
        _journey(
          from: 'Downtown Berkeley',
          to: 'Ferry Building',
          legs: const [
            {
              'type': 'ride',
              'line': 'bart-red',
              'from': 'Downtown Berkeley',
              'to': 'Embarcadero',
              'mins': 27,
              'stops': 8,
            },
            {
              'type': 'ride',
              'line': regionalBusLineId,
              'from': 'Embarcadero',
              'to': 'Atlantis Terminal',
              'mins': 11,
            },
            {'type': 'walk', 'to': 'Moon Base', 'mins': 6},
            {'type': 'walk', 'to': 'Ferry Building', 'mins': 7},
          ],
        ),
      );

      expect(overlay, isNotNull);
      expect(overlay!.segments, hasLength(2));
      expect(overlay.segments.map((segment) => segment.label), [
        'Red Line',
        'Walk',
      ]);
      expect(
        overlay.segments.last.points.first.latitude,
        closeTo(37.792874, 0.0001),
      );
    });

    test('returns null when no route segment can be resolved', () {
      final overlay = buildTransitJourneyRouteOverlay(
        _journey(
          from: 'Atlantis Terminal',
          to: 'Moon Base',
          legs: const [
            {
              'type': 'ride',
              'line': 'regional-transit',
              'from': 'Atlantis Terminal',
              'to': 'Moon Base',
              'mins': 42,
            },
          ],
        ),
      );

      expect(overlay, isNull);
    });
  });
}

TransitJourney _journey({
  required String from,
  required String to,
  required List<Map<String, Object?>> legs,
  int changes = 0,
}) {
  return TransitJourney.fromJson({
    'recommended': true,
    'tag': 'Route',
    'from': from,
    'to': to,
    'depart': '9:05',
    'arrive': '10:03',
    'duration': 58,
    'changes': changes,
    'fare': '11.95',
    'crowd': 'Some seats',
    'legs': legs,
  });
}
