import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/explore/itinerary.dart';
import 'package:genui_template/location/location_point.dart';
import 'package:genui_template/transit/google_routes_transit_client.dart';
import 'package:genui_template/transit/saved_itinerary_transit_planner.dart';

void main() {
  group('SavedItineraryTransitPlanner', () {
    test('plans one saved stop from the current location', () async {
      final client = _FakeTransitRouteClient();
      final planner = SavedItineraryTransitPlanner(client: client);

      final plan = await planner.plan(
        stops: [
          _stop(
            'stop-1',
            'Ferry Building',
            latitude: 37.795,
            longitude: -122.393,
          ),
        ],
        currentLocation: const LocationCoordinate(
          latitude: 37.78,
          longitude: -122.41,
        ),
        departureTime: DateTime.parse('2026-06-27T15:00:00Z'),
      );

      expect(plan.status, SavedItineraryTransitPlanStatus.available);
      expect(plan.segments, hasLength(1));
      expect(plan.segments.single.fromName, 'Current location');
      expect(plan.segments.single.toName, 'Ferry Building');
      expect(
        client.requests.single.departureTime.toIso8601String(),
        contains('15:00:00'),
      );
      expect(
        plan.toPromptContext(),
        contains('Current location to Ferry Building'),
      );
    });

    test('serializes ordered journey cards and unavailable notes', () async {
      final client = _FakeTransitRouteClient(
        fare: r'$2.75',
        outcomes: [
          10,
          const GoogleRoutesTransitException('No route'),
        ],
      );
      final planner = SavedItineraryTransitPlanner(client: client);

      final plan = await planner.plan(
        stops: [
          _stop(
            'stop-1',
            'Coffee',
            durationMinutes: 20,
            latitude: 37.776,
            longitude: -122.408,
          ),
          _stop('stop-2', 'Museum', latitude: 37.785, longitude: -122.401),
          _stop('stop-3', 'Dinner', latitude: 37.789, longitude: -122.39),
        ],
        currentLocation: const LocationCoordinate(
          latitude: 37.78,
          longitude: -122.41,
        ),
        departureTime: DateTime.parse('2026-06-27T10:00:00'),
      );

      expect(plan.status, SavedItineraryTransitPlanStatus.partial);
      expect(
        plan.toStructuredJson(),
        {
          'status': 'partial',
          'segments': [
            {
              'index': 1,
              'status': 'available',
              'from': 'Current location',
              'to': 'Coffee',
              'requestedDeparture': '2026-06-27 10:00',
              'component': 'TransitJourney',
              'journey': {
                'recommended': true,
                'tag': 'Saved itinerary segment 1',
                'from': 'Current location',
                'to': 'Coffee',
                'depart': '10:00',
                'arrive': '10:10',
                'duration': 10,
                'changes': 0,
                'fare': r'$2.75',
                'crowd': 'Some seats',
                'legs': [
                  {
                    'type': 'ride',
                    'line': 'regional-transit',
                    'from': 'Current location',
                    'to': 'Coffee',
                    'mins': 10,
                  },
                ],
              },
            },
            {
              'index': 2,
              'status': 'unavailable',
              'from': 'Coffee',
              'to': 'Museum',
              'requestedDeparture': '2026-06-27 10:30',
              'component': 'TransitNote',
              'note': 'No route. Do not fabricate times for this segment.',
            },
            {
              'index': 3,
              'status': 'unavailable',
              'from': 'Museum',
              'to': 'Dinner',
              'component': 'TransitNote',
              'note':
                  'Previous segment timing is unavailable, so no '
                  'data-backed departure time is available for Museum to '
                  'Dinner.',
            },
          ],
        },
      );
    });

    test('propagates stop dwell time across multi-stop routing', () async {
      final client = _FakeTransitRouteClient();
      final planner = SavedItineraryTransitPlanner(client: client);

      await planner.plan(
        stops: [
          _stop(
            'stop-1',
            'Coffee',
            durationMinutes: 30,
            latitude: 37.776,
            longitude: -122.408,
          ),
          _stop(
            'stop-2',
            'Museum',
            latitude: 37.785,
            longitude: -122.401,
          ),
          _stop(
            'stop-3',
            'Dinner',
            latitude: 37.789,
            longitude: -122.39,
          ),
        ],
        departureTime: DateTime.parse('2026-06-27T10:00:00Z'),
      );

      expect(client.requests.map((request) => request.fromName), [
        'Coffee',
        'Museum',
      ]);
      expect(client.requests.map((request) => request.toName), [
        'Museum',
        'Dinner',
      ]);
      expect(
        client.requests[0].departureTime,
        DateTime.parse('2026-06-27T10:30:00Z'),
      );
      expect(
        client.requests[1].departureTime,
        DateTime.parse('2026-06-27T11:40:00Z'),
      );
    });

    test(
      'uses the first stop as the start when current location is missing',
      () async {
        final client = _FakeTransitRouteClient();
        final planner = SavedItineraryTransitPlanner(client: client);

        final plan = await planner.plan(
          stops: [
            _stop('stop-1', 'Coffee', latitude: 37.776, longitude: -122.408),
            _stop('stop-2', 'Museum', latitude: 37.785, longitude: -122.401),
          ],
          departureTime: DateTime.parse('2026-06-27T10:00:00Z'),
        );

        expect(plan.status, SavedItineraryTransitPlanStatus.available);
        expect(plan.notes.single, contains('Current location is unavailable'));
        expect(client.requests, hasLength(1));
        expect(client.requests.single.fromName, 'Coffee');
      },
    );

    test('skips missing-coordinate segments with unavailable notes', () async {
      final client = _FakeTransitRouteClient();
      final planner = SavedItineraryTransitPlanner(client: client);

      final plan = await planner.plan(
        stops: [
          _stop('stop-1', 'Coffee'),
          _stop('stop-2', 'Museum', latitude: 37.785, longitude: -122.401),
        ],
        currentLocation: const LocationCoordinate(
          latitude: 37.78,
          longitude: -122.41,
        ),
        departureTime: DateTime.parse('2026-06-27T10:00:00Z'),
      );

      expect(client.requests, isEmpty);
      expect(plan.status, SavedItineraryTransitPlanStatus.unavailable);
      expect(plan.segments, hasLength(2));
      expect(plan.segments.every((segment) => !segment.available), isTrue);
      expect(
        plan.toPromptContext(),
        contains('Missing coordinates for Coffee'),
      );
      expect(plan.toPromptContext(), contains('do not fabricate'));
    });

    test(
      'does not plan later timed segments after missing coordinates',
      () async {
        final client = _FakeTransitRouteClient();
        final planner = SavedItineraryTransitPlanner(client: client);

        final plan = await planner.plan(
          stops: [
            _stop(
              'stop-1',
              'Coffee',
              latitude: 37.776,
              longitude: -122.408,
            ),
            _stop('stop-2', 'Museum'),
            _stop('stop-3', 'Dinner', latitude: 37.789, longitude: -122.39),
            _stop('stop-4', 'Theater', latitude: 37.792, longitude: -122.4),
          ],
          currentLocation: const LocationCoordinate(
            latitude: 37.78,
            longitude: -122.41,
          ),
          departureTime: DateTime.parse('2026-06-27T10:00:00Z'),
        );

        expect(plan.status, SavedItineraryTransitPlanStatus.partial);
        expect(client.requests, hasLength(1));
        expect(client.requests.single.fromName, 'Current location');
        expect(plan.segments, hasLength(4));
        expect(plan.segments.last.fromName, 'Dinner');
        expect(plan.segments.last.toName, 'Theater');
        expect(plan.segments.last.requestedDepartureTime, isNull);
        expect(
          plan.segments.last.note,
          contains('Previous segment timing is unavailable'),
        );
      },
    );

    test('returns unavailable notes for planner failures', () async {
      final client = _FakeTransitRouteClient(
        error: const GoogleRoutesTransitException('Google Routes failed'),
      );
      final planner = SavedItineraryTransitPlanner(client: client);

      final plan = await planner.plan(
        stops: [
          _stop('stop-1', 'Coffee', latitude: 37.776, longitude: -122.408),
          _stop('stop-2', 'Museum', latitude: 37.785, longitude: -122.401),
        ],
        departureTime: DateTime.parse('2026-06-27T10:00:00Z'),
      );

      expect(plan.status, SavedItineraryTransitPlanStatus.unavailable);
      expect(plan.segments.single.note, contains('Google Routes failed'));
      expect(plan.segments.single.note, contains('Do not fabricate times'));
    });

    test('returns unavailable notes for unexpected planner failures', () async {
      final client = _FakeTransitRouteClient(error: StateError('boom'));
      final planner = SavedItineraryTransitPlanner(client: client);

      final plan = await planner.plan(
        stops: [
          _stop('stop-1', 'Coffee', latitude: 37.776, longitude: -122.408),
          _stop('stop-2', 'Museum', latitude: 37.785, longitude: -122.401),
        ],
        departureTime: DateTime.parse('2026-06-27T10:00:00Z'),
      );

      expect(plan.status, SavedItineraryTransitPlanStatus.unavailable);
      expect(
        plan.segments.single.note,
        contains('Transit planner request failed unexpectedly'),
      );
      expect(plan.segments.single.note, contains('Do not fabricate times'));
    });

    test('marks zero-duration planner responses unavailable', () async {
      final client = _FakeTransitRouteClient(durationMinutes: 0);
      final planner = SavedItineraryTransitPlanner(client: client);

      final plan = await planner.plan(
        stops: [
          _stop('stop-1', 'Coffee', latitude: 37.776, longitude: -122.408),
          _stop('stop-2', 'Museum', latitude: 37.785, longitude: -122.401),
        ],
        departureTime: DateTime.parse('2026-06-27T10:00:00Z'),
      );

      expect(plan.status, SavedItineraryTransitPlanStatus.unavailable);
      expect(plan.hasAvailableSegments, isFalse);
      expect(plan.segments.single.note, contains('no usable transit times'));
      expect(plan.toPromptContext(), contains('do not fabricate'));
    });
  });
}

ItineraryStop _stop(
  String id,
  String title, {
  int durationMinutes = 60,
  double? latitude,
  double? longitude,
}) {
  return ItineraryStop(
    localId: id,
    title: title,
    durationMinutes: durationMinutes,
    latitude: latitude,
    longitude: longitude,
  );
}

class _FakeTransitRouteClient implements TransitRouteClient {
  _FakeTransitRouteClient({
    this.error,
    this.durationMinutes = 10,
    this.fare = '',
    List<Object>? outcomes,
  }) : outcomes = outcomes ?? const [];

  final Object? error;
  final int durationMinutes;
  final String fare;
  final List<Object> outcomes;
  final List<_TransitRequest> requests = [];

  @override
  Future<GoogleRoutesTransitJourney> fetchBestRoute({
    required LocationCoordinate origin,
    required LocationCoordinate destination,
    DateTime? departureTime,
    String originName = 'Origin',
    String destinationName = 'Destination',
    TransitRoutingPreference? routingPreference,
  }) async {
    final requestDeparture =
        departureTime ?? DateTime.parse('2026-06-27T10:00:00Z');
    final requestIndex = requests.length;
    requests.add(
      _TransitRequest(
        fromName: originName,
        toName: destinationName,
        departureTime: requestDeparture,
      ),
    );
    final error = this.error;
    if (error != null) _throwClientError(error);
    final outcome = requestIndex < outcomes.length
        ? outcomes[requestIndex]
        : null;
    if (outcome != null && outcome is! int) _throwClientError(outcome);
    final requestDuration = outcome is int ? outcome : durationMinutes;
    final arrivalTime = requestDeparture.add(
      Duration(minutes: requestDuration),
    );

    return GoogleRoutesTransitJourney(
      from: originName,
      to: destinationName,
      departClock: _clock(requestDeparture),
      arriveClock: _clock(arrivalTime),
      durationMinutes: requestDuration,
      changes: 0,
      fare: fare,
      legs: [
        GoogleRoutesTransitLeg.ride(
          durationMinutes: requestDuration,
          lineId: 'regional-transit',
          from: originName,
          to: destinationName,
        ),
      ],
      departureDateTime: requestDeparture,
      arrivalDateTime: arrivalTime,
    );
  }

  @override
  void close() {}
}

Never _throwClientError(Object error) {
  if (error is Exception) throw error;
  if (error is Error) throw error;
  throw StateError('Unsupported fake client error: $error');
}

class _TransitRequest {
  const _TransitRequest({
    required this.fromName,
    required this.toName,
    required this.departureTime,
  });

  final String fromName;
  final String toName;
  final DateTime departureTime;
}

String _clock(DateTime value) {
  return '${value.hour}:${value.minute.toString().padLeft(2, '0')}';
}
