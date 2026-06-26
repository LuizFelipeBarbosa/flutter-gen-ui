import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/location/location.dart';

void main() {
  group('LocationSnapshot.promptContext', () {
    test('formats the nearest stop and accuracy for the model prompt', () {
      final capturedAt = DateTime(2026, 6, 26, 9, 5);
      final powell = bayAreaTransitStops.firstWhere(
        (stop) => stop.id == 'bart-powell',
      );
      final nearest = NearestTransitStop(stop: powell, distanceMeters: 42);

      final snapshot = LocationSnapshot.available(
        capturedAt: capturedAt,
        fix: UserLocationFix(
          coordinate: powell.coordinate,
          accuracyMeters: 12.4,
          timestamp: capturedAt,
        ),
        nearestStop: nearest,
      );

      expect(
        snapshot.promptContext,
        'User location snapshot: nearest stop Powell St (BART), '
        '42 m away, coordinates 37.78447, -122.40797, '
        'accuracy about 12 m, BART abbreviation POWL.',
      );
    });

    test('formats unavailable states as explicit context', () {
      final snapshot = LocationSnapshot.permissionDenied(
        capturedAt: DateTime(2026, 6, 26, 9, 5),
      );

      expect(
        snapshot.promptContext,
        'User location snapshot: unavailable '
        "(Location permission was denied.). Do not infer the user's current "
        'station or neighborhood.',
      );
    });

    test('omits idle snapshots from prompts', () {
      final snapshot = LocationSnapshot.idle(
        capturedAt: DateTime(2026, 6, 26, 9, 5),
      );

      expect(snapshot.promptContext, isNull);
    });
  });
}
