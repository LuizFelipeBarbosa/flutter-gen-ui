import 'package:bayhop/location/location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nearestBayAreaTransitStop', () {
    test('finds Powell St near Union Square', () {
      final nearest = nearestBayAreaTransitStop(
        const LocationCoordinate(
          latitude: 37.7858,
          longitude: -122.4064,
        ),
      );

      expect(nearest, isNotNull);
      expect(nearest!.stop.name, 'Powell St');
      expect(nearest.stop.bartAbbr, 'POWL');
      expect(nearest.distanceMeters, lessThan(250));
    });

    test('finds San Jose Diridon in downtown San Jose', () {
      final nearest = nearestBayAreaTransitStop(
        const LocationCoordinate(
          latitude: 37.3297,
          longitude: -121.9024,
        ),
      );

      expect(nearest, isNotNull);
      expect(nearest!.stop.name, 'San Jose Diridon');
      expect(nearest.stop.operatorName, 'Caltrain');
      expect(nearest.distanceMeters, lessThan(100));
    });

    test('returns null for an empty candidate list', () {
      final nearest = nearestBayAreaTransitStop(
        const LocationCoordinate(latitude: 37.8, longitude: -122.4),
        stops: const [],
      );

      expect(nearest, isNull);
    });
  });
}
