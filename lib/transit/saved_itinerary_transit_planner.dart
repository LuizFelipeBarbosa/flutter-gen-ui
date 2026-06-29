import 'package:bayhop/explore/itinerary.dart';
import 'package:bayhop/location/location_point.dart';
import 'package:bayhop/transit/google_routes_transit_client.dart';

class SavedItineraryTransitPlanner {
  const SavedItineraryTransitPlanner({
    required this.client,
  });

  final TransitRouteClient client;

  void close() {
    client.close();
  }

  Future<SavedItineraryTransitPlan> plan({
    required List<ItineraryStop> stops,
    required DateTime departureTime,
    LocationCoordinate? currentLocation,
  }) async {
    if (stops.isEmpty) {
      return const SavedItineraryTransitPlan(
        status: SavedItineraryTransitPlanStatus.unavailable,
        segments: [],
        notes: ['Saved itinerary is empty; no transit route was planned.'],
      );
    }

    final segments = <SavedItineraryTransitSegment>[];
    final notes = <String>[];
    DateTime? nextDeparture = departureTime;

    if (currentLocation == null) {
      notes.add(
        'Current location is unavailable, so the first saved stop is the '
        'starting point.',
      );
    } else {
      final firstStop = stops.first;
      final destination = _coordinateFor(firstStop);
      if (destination == null) {
        segments.add(
          SavedItineraryTransitSegment.unavailable(
            fromName: 'Current location',
            toName: firstStop.title,
            requestedDepartureTime: nextDeparture,
            note:
                'Missing coordinates for ${firstStop.title}; no '
                'data-backed transit time is available.',
          ),
        );
        nextDeparture = null;
      } else {
        final segment = await _planSegment(
          fromName: 'Current location',
          toName: firstStop.title,
          origin: currentLocation,
          destination: destination,
          departureTime: nextDeparture,
        );
        segments.add(segment);
        nextDeparture = _nextDepartureAfterTravel(segment, nextDeparture);
      }
    }

    for (var index = 0; index < stops.length - 1; index++) {
      final fromStop = stops[index];
      final toStop = stops[index + 1];
      if (nextDeparture != null) {
        nextDeparture = nextDeparture.add(
          Duration(minutes: fromStop.durationMinutes),
        );
      }

      final origin = _coordinateFor(fromStop);
      final destination = _coordinateFor(toStop);
      if (origin == null || destination == null) {
        segments.add(
          SavedItineraryTransitSegment.unavailable(
            fromName: fromStop.title,
            toName: toStop.title,
            requestedDepartureTime: nextDeparture,
            note: _missingCoordinateNote(fromStop, toStop),
          ),
        );
        nextDeparture = null;
        continue;
      }

      if (nextDeparture == null) {
        segments.add(
          SavedItineraryTransitSegment.unavailable(
            fromName: fromStop.title,
            toName: toStop.title,
            note: _unknownDepartureNote(fromStop.title, toStop.title),
          ),
        );
        continue;
      }

      final segment = await _planSegment(
        fromName: fromStop.title,
        toName: toStop.title,
        origin: origin,
        destination: destination,
        departureTime: nextDeparture,
      );
      segments.add(segment);
      nextDeparture = _nextDepartureAfterTravel(segment, nextDeparture);
    }

    final unavailableSegments = segments.where(
      (segment) => !segment.available,
    );
    if (segments.isEmpty || unavailableSegments.length == segments.length) {
      return SavedItineraryTransitPlan(
        status: SavedItineraryTransitPlanStatus.unavailable,
        segments: segments,
        notes: [
          ...notes,
          _plannerUnavailableNote,
        ],
      );
    }

    return SavedItineraryTransitPlan(
      status: unavailableSegments.isEmpty
          ? SavedItineraryTransitPlanStatus.available
          : SavedItineraryTransitPlanStatus.partial,
      segments: segments,
      notes: notes,
    );
  }

  Future<SavedItineraryTransitSegment> _planSegment({
    required String fromName,
    required String toName,
    required LocationCoordinate origin,
    required LocationCoordinate destination,
    required DateTime departureTime,
  }) async {
    try {
      final journey = await client.fetchBestRoute(
        origin: origin,
        destination: destination,
        departureTime: departureTime,
        originName: fromName,
        destinationName: toName,
      );
      if (!_hasUsableTiming(journey)) {
        return SavedItineraryTransitSegment.unavailable(
          fromName: fromName,
          toName: toName,
          requestedDepartureTime: departureTime,
          note:
              'Google Routes returned no usable transit times for this '
              'segment. Do not fabricate times for this segment.',
        );
      }
      return SavedItineraryTransitSegment.available(
        fromName: fromName,
        toName: toName,
        requestedDepartureTime: departureTime,
        journey: journey,
      );
    } on GoogleRoutesTransitException catch (error) {
      return SavedItineraryTransitSegment.unavailable(
        fromName: fromName,
        toName: toName,
        requestedDepartureTime: departureTime,
        note: '${error.message}. Do not fabricate times for this segment.',
      );
    } on Object catch (error) {
      return SavedItineraryTransitSegment.unavailable(
        fromName: fromName,
        toName: toName,
        requestedDepartureTime: departureTime,
        note:
            'Transit planner request failed unexpectedly: $error. '
            'Do not fabricate times for this segment.',
      );
    }
  }
}

bool _hasUsableTiming(GoogleRoutesTransitJourney journey) {
  if (journey.durationMinutes <= 0) return false;
  if (journey.departClock == '--:--' || journey.arriveClock == '--:--') {
    return false;
  }
  return journey.legs.any((leg) => leg.durationMinutes > 0);
}

enum SavedItineraryTransitPlanStatus { available, partial, unavailable }

class SavedItineraryTransitPlan {
  const SavedItineraryTransitPlan({
    required this.status,
    required this.segments,
    this.notes = const [],
  });

  final SavedItineraryTransitPlanStatus status;
  final List<SavedItineraryTransitSegment> segments;
  final List<String> notes;

  bool get available => status == SavedItineraryTransitPlanStatus.available;
  bool get hasAvailableSegments {
    return segments.any((segment) => segment.available);
  }

  Map<String, Object?> toStructuredJson() {
    final json = <String, Object?>{
      'status': status.name,
      'segments': _structuredSegments(),
    };
    if (notes.isNotEmpty) json['notes'] = notes;
    return json;
  }

  String toPromptContext() {
    final buffer = StringBuffer(
      'Saved itinerary transit planner status: ${status.name}. ',
    );
    if (notes.isNotEmpty) buffer.write('Notes: ${notes.join(' ')} ');
    if (segments.isEmpty) return buffer.toString().trim();

    buffer.write('Segments: ');
    for (var index = 0; index < segments.length; index++) {
      if (index > 0) buffer.write(' ');
      buffer.write('${index + 1}. ${segments[index].toPromptFacts()}');
    }
    return buffer.toString().trim();
  }

  List<Map<String, Object?>> _structuredSegments() {
    final firstAvailableIndex = segments.indexWhere(
      (segment) => segment.available,
    );

    return [
      for (var index = 0; index < segments.length; index++)
        segments[index].toStructuredJson(
          index: index + 1,
          recommended: index == firstAvailableIndex,
        ),
    ];
  }
}

class SavedItineraryTransitSegment {
  const SavedItineraryTransitSegment.available({
    required this.fromName,
    required this.toName,
    required this.journey,
    this.requestedDepartureTime,
  }) : note = null;

  const SavedItineraryTransitSegment.unavailable({
    required this.fromName,
    required this.toName,
    required this.note,
    this.requestedDepartureTime,
  }) : journey = null;

  final String fromName;
  final String toName;
  final DateTime? requestedDepartureTime;
  final GoogleRoutesTransitJourney? journey;
  final String? note;

  bool get available => journey != null;

  Map<String, Object?> toStructuredJson({
    required int index,
    required bool recommended,
  }) {
    final segment = {
      'index': index,
      'status': available ? 'available' : 'unavailable',
      'from': fromName,
      'to': toName,
      'requestedDeparture': requestedDepartureTime == null
          ? null
          : _formatDateTime(requestedDepartureTime!),
      'component': available ? 'TransitJourney' : 'TransitNote',
    };

    final journey = this.journey;
    if (journey == null) {
      return {
        ...segment,
        'note': note,
      }..removeWhere((_, value) => value == null || value == '');
    }

    return {
      ...segment,
      'journey': journey.toTransitJourneyJson(
        recommended: recommended,
        tag: 'Saved itinerary segment $index',
      ),
    }..removeWhere((_, value) => value == null || value == '');
  }

  String toPromptFacts() {
    final routeLabel = '$fromName to $toName';
    final plannedAt = requestedDepartureTime == null
        ? ''
        : ' requested departure ${_formatDateTime(requestedDepartureTime!)}.';
    final journey = this.journey;
    if (journey == null) {
      return '$routeLabel unavailable.$plannedAt ${note ?? ''}'.trim();
    }

    return '${journey.toPromptFacts(label: routeLabel)}$plannedAt';
  }
}

LocationCoordinate? _coordinateFor(ItineraryStop stop) {
  final latitude = stop.latitude;
  final longitude = stop.longitude;
  if (latitude == null || longitude == null) return null;
  return LocationCoordinate(latitude: latitude, longitude: longitude);
}

String _missingCoordinateNote(ItineraryStop fromStop, ItineraryStop toStop) {
  final missing = [
    if (fromStop.latitude == null || fromStop.longitude == null) fromStop.title,
    if (toStop.latitude == null || toStop.longitude == null) toStop.title,
  ];
  return 'Missing coordinates for ${missing.join(' and ')}; no data-backed '
      'transit time is available.';
}

String _unknownDepartureNote(String fromName, String toName) {
  return 'Previous segment timing is unavailable, so no data-backed departure '
      'time is available for $fromName to $toName.';
}

DateTime? _nextDepartureAfterTravel(
  SavedItineraryTransitSegment segment,
  DateTime fallbackDeparture,
) {
  final arrival = segment.journey?.arrivalDateTime;
  if (arrival != null) return arrival;
  final duration = segment.journey?.durationMinutes;
  if (duration != null) {
    return fallbackDeparture.add(Duration(minutes: duration));
  }
  return null;
}

String _formatDateTime(DateTime value) {
  final local = value.isUtc ? value.toLocal() : value;
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} $hour:$minute';
}

const _plannerUnavailableNote =
    'Transit planner facts are unavailable; do not fabricate route times.';
