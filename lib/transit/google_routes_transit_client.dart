import 'dart:async';
import 'dart:convert';

import 'package:bayhop/location/location_point.dart';
import 'package:bayhop/transit/transit_lines.dart';
import 'package:http/http.dart' as http;

enum TransitRoutingPreference {
  fewerTransfers('FEWER_TRANSFERS'),
  lessWalking('LESS_WALKING');

  const TransitRoutingPreference(this.apiValue);

  final String apiValue;
}

abstract class TransitRouteClient {
  Future<GoogleRoutesTransitJourney> fetchBestRoute({
    required LocationCoordinate origin,
    required LocationCoordinate destination,
    DateTime? departureTime,
    String originName = 'Origin',
    String destinationName = 'Destination',
    TransitRoutingPreference? routingPreference,
  });

  void close();
}

class GoogleRoutesTransitException implements Exception {
  const GoogleRoutesTransitException(this.message);

  final String message;

  @override
  String toString() => 'GoogleRoutesTransitException: $message';
}

class GoogleRoutesTransitClient implements TransitRouteClient {
  GoogleRoutesTransitClient({
    http.Client? httpClient,
    String? apiKey,
    this.baseUrl = 'https://routes.googleapis.com',
    this.timeout = const Duration(seconds: 8),
  }) : apiKey = _configuredApiKey(apiKey),
       _httpClient = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  static const defaultFieldMask =
      'routes.duration,'
      'routes.travelAdvisory.transitFare,'
      'routes.legs.steps.travelMode,'
      'routes.legs.steps.staticDuration,'
      'routes.legs.steps.navigationInstruction,'
      'routes.legs.steps.transitDetails';

  final http.Client _httpClient;
  final bool _ownsClient;
  final String apiKey;
  final String baseUrl;
  final Duration timeout;

  @override
  Future<GoogleRoutesTransitJourney> fetchBestRoute({
    required LocationCoordinate origin,
    required LocationCoordinate destination,
    DateTime? departureTime,
    String originName = 'Origin',
    String destinationName = 'Destination',
    TransitRoutingPreference? routingPreference,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const GoogleRoutesTransitException(
        'GOOGLE_MAPS_API_KEY or GOOGLE_ROUTES_API_KEY is required for '
        'transit route timing.',
      );
    }

    try {
      final response = await _httpClient
          .post(
            _uri('/directions/v2:computeRoutes'),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': key,
              'X-Goog-FieldMask': defaultFieldMask,
            },
            body: jsonEncode(
              _requestBody(
                origin: origin,
                destination: destination,
                departureTime: departureTime,
                routingPreference: routingPreference,
              ),
            ),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw GoogleRoutesTransitException(_errorMessage(response));
      }

      return _journeyFromResponse(
        jsonDecode(response.body),
        originName: originName,
        destinationName: destinationName,
        fallbackDeparture: departureTime,
      );
    } on GoogleRoutesTransitException {
      rethrow;
    } on TimeoutException {
      throw const GoogleRoutesTransitException(
        'Google Routes request timed out',
      );
    } on FormatException {
      throw const GoogleRoutesTransitException(
        'Google Routes returned invalid JSON',
      );
    } on Object catch (error) {
      throw GoogleRoutesTransitException(
        'Google Routes request failed: $error',
      );
    }
  }

  @override
  void close() {
    if (_ownsClient) _httpClient.close();
  }

  Uri _uri(String path) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root$path');
  }
}

class GoogleRoutesTransitJourney {
  const GoogleRoutesTransitJourney({
    required this.from,
    required this.to,
    required this.departClock,
    required this.arriveClock,
    required this.durationMinutes,
    required this.changes,
    required this.legs,
    this.fare = '',
    this.departureDateTime,
    this.arrivalDateTime,
  });

  final String from;
  final String to;
  final String departClock;
  final String arriveClock;
  final int durationMinutes;
  final int changes;
  final String fare;
  final List<GoogleRoutesTransitLeg> legs;
  final DateTime? departureDateTime;
  final DateTime? arrivalDateTime;

  Map<String, Object?> toTransitJourneyJson({
    bool recommended = true,
    String tag = 'Planner-backed',
  }) {
    return {
      'recommended': recommended,
      'tag': tag,
      'from': from,
      'to': to,
      'depart': departClock,
      'arrive': arriveClock,
      'duration': durationMinutes,
      'changes': changes,
      'fare': fare,
      'crowd': 'Some seats',
      'legs': [for (final leg in legs) leg.toTransitJourneyJson()],
    }..removeWhere((_, value) => value == null || value == '');
  }

  String toPromptFacts({String? label}) {
    final routeLabel = label ?? '$from to $to';
    final changeLabel = switch (changes) {
      0 => 'direct',
      1 => '1 change',
      _ => '$changes changes',
    };
    return 'Planner-backed route facts for $routeLabel: '
        'depart $departClock; arrive $arriveClock; '
        'duration $durationMinutes min; $changeLabel; '
        '${fare.isEmpty ? '' : 'fare $fare; '}'
        'legs ${legs.map((leg) => leg.toPromptFacts()).join(' | ')}. '
        'Use these TransitJourney fields exactly.';
  }
}

class GoogleRoutesTransitLeg {
  const GoogleRoutesTransitLeg._({
    required this.type,
    required this.durationMinutes,
    this.lineId = '',
    this.from = '',
    this.to = '',
    this.station = '',
    this.stopCount,
  });

  const GoogleRoutesTransitLeg.ride({
    required int durationMinutes,
    required String lineId,
    required String from,
    required String to,
    int? stopCount,
  }) : this._(
         type: 'ride',
         durationMinutes: durationMinutes,
         lineId: lineId,
         from: from,
         to: to,
         stopCount: stopCount,
       );

  const GoogleRoutesTransitLeg.walk({
    required int durationMinutes,
    required String to,
  }) : this._(
         type: 'walk',
         durationMinutes: durationMinutes,
         to: to,
       );

  const GoogleRoutesTransitLeg.change({
    required int durationMinutes,
    required String station,
  }) : this._(
         type: 'change',
         durationMinutes: durationMinutes,
         station: station,
       );

  final String type;
  final String lineId;
  final String from;
  final String to;
  final String station;
  final int durationMinutes;
  final int? stopCount;

  Map<String, Object?> toTransitJourneyJson() {
    return {
      'type': type,
      'line': lineId,
      'from': from,
      'to': to,
      'station': station,
      'mins': durationMinutes,
      'stops': stopCount,
    }..removeWhere((_, value) => value == null || value == '');
  }

  String toPromptFacts() {
    return switch (type) {
      'ride' =>
        'ride ${lineId.isEmpty ? regionalTransitLineId : lineId} from $from '
            'to $to for $durationMinutes min'
            '${stopCount == null ? '' : ' ($stopCount stops)'}',
      'walk' => 'walk to $to for $durationMinutes min',
      'change' => 'change at $station for $durationMinutes min',
      _ => '$type for $durationMinutes min',
    };
  }
}

String _configuredApiKey(String? explicit) {
  final explicitKey = explicit?.trim();
  if (explicitKey != null && explicitKey.isNotEmpty) return explicitKey;

  const mapsKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  if (mapsKey != '') return mapsKey;
  return const String.fromEnvironment('GOOGLE_ROUTES_API_KEY');
}

Map<String, Object?> _requestBody({
  required LocationCoordinate origin,
  required LocationCoordinate destination,
  DateTime? departureTime,
  TransitRoutingPreference? routingPreference,
}) {
  final body = <String, Object?>{
    'origin': _waypoint(origin),
    'destination': _waypoint(destination),
    'travelMode': 'TRANSIT',
    if (departureTime != null)
      'departureTime': departureTime.toUtc().toIso8601String(),
    if (routingPreference != null)
      'transitPreferences': {'routingPreference': routingPreference.apiValue},
  };
  return body;
}

Map<String, Object?> _waypoint(LocationCoordinate coordinate) {
  return {
    'location': {
      'latLng': {
        'latitude': coordinate.latitude,
        'longitude': coordinate.longitude,
      },
    },
  };
}

GoogleRoutesTransitJourney _journeyFromResponse(
  Object? data, {
  required String originName,
  required String destinationName,
  required DateTime? fallbackDeparture,
}) {
  final routes = _mapList(_map(data)['routes']);
  if (routes.isEmpty) {
    throw const GoogleRoutesTransitException(
      'Google Routes did not return a transit route',
    );
  }

  final route = routes.first;
  final legs = <GoogleRoutesTransitLeg>[];
  DateTime? firstTransitDeparture;
  DateTime? lastTransitArrival;
  DateTime? previousRideArrival;
  var leadingWalkMinutes = 0;
  var trailingWalkMinutes = 0;
  var hasSeenRide = false;

  for (final routeLeg in _mapList(route['legs'])) {
    for (final step in _mapList(routeLeg['steps'])) {
      final parsed = _legFromStep(step);
      if (parsed == null) continue;
      if (parsed.leg.type == 'ride') {
        _addTransferWaitIfNeeded(legs, parsed, previousRideArrival);
        legs.add(parsed.leg);
        firstTransitDeparture ??= parsed.departureTime;
        lastTransitArrival = parsed.arrivalTime ?? lastTransitArrival;
        previousRideArrival = parsed.arrivalTime;
        hasSeenRide = true;
        trailingWalkMinutes = 0;
      } else if (!hasSeenRide) {
        legs.add(parsed.leg);
        previousRideArrival = null;
        leadingWalkMinutes += parsed.leg.durationMinutes;
      } else {
        legs.add(parsed.leg);
        previousRideArrival = null;
        trailingWalkMinutes += parsed.leg.durationMinutes;
      }
    }
  }

  if (legs.isEmpty) {
    throw const GoogleRoutesTransitException(
      'Google Routes did not return transit route steps',
    );
  }

  final durationMinutes = _routeDurationMinutes(route, legs);
  final departureDateTime =
      firstTransitDeparture?.subtract(Duration(minutes: leadingWalkMinutes)) ??
      fallbackDeparture;
  final arrivalDateTime =
      lastTransitArrival?.add(Duration(minutes: trailingWalkMinutes)) ??
      departureDateTime?.add(Duration(minutes: durationMinutes));

  return GoogleRoutesTransitJourney(
    from: originName,
    to: destinationName,
    departClock: _clock(departureDateTime),
    arriveClock: _clock(arrivalDateTime),
    durationMinutes: durationMinutes,
    changes: _changeCount(legs),
    fare: _fare(route),
    legs: legs,
    departureDateTime: departureDateTime,
    arrivalDateTime: arrivalDateTime,
  );
}

void _addTransferWaitIfNeeded(
  List<GoogleRoutesTransitLeg> legs,
  _ParsedTransitLeg nextRide,
  DateTime? previousRideArrival,
) {
  if (legs.isEmpty || legs.last.type != 'ride') return;

  final previousRide = legs.last;
  final waitMinutes = _minutesBetween(
    previousRideArrival,
    nextRide.departureTime,
  );
  if (waitMinutes == null || waitMinutes <= 0) return;

  legs.add(
    GoogleRoutesTransitLeg.change(
      durationMinutes: waitMinutes,
      station: _transferStation(previousRide, nextRide.leg),
    ),
  );
}

String _transferStation(
  GoogleRoutesTransitLeg previousRide,
  GoogleRoutesTransitLeg nextRide,
) {
  if (nextRide.from.isNotEmpty) return nextRide.from;
  if (previousRide.to.isNotEmpty) return previousRide.to;
  return 'transfer stop';
}

int _routeDurationMinutes(
  Map<String, Object?> route,
  List<GoogleRoutesTransitLeg> legs,
) {
  final routeDuration = _durationMinutes(route['duration']);
  if (routeDuration > 0) return routeDuration;
  return legs.fold<int>(0, (total, leg) => total + leg.durationMinutes);
}

int _changeCount(List<GoogleRoutesTransitLeg> legs) {
  final rides = legs.where((leg) => leg.type == 'ride').length;
  return rides <= 1 ? 0 : rides - 1;
}

_ParsedTransitLeg? _legFromStep(Map<String, Object?> step) {
  final transitDetails = _map(step['transitDetails']);
  if (transitDetails.isNotEmpty) return _rideLegFromStep(step, transitDetails);

  if (_string(step['travelMode']).toUpperCase() == 'WALK') {
    return _ParsedTransitLeg(
      leg: GoogleRoutesTransitLeg.walk(
        durationMinutes: _stepDurationMinutes(step),
        to: _walkDestination(step),
      ),
    );
  }

  return null;
}

_ParsedTransitLeg _rideLegFromStep(
  Map<String, Object?> step,
  Map<String, Object?> transitDetails,
) {
  final stopDetails = _map(transitDetails['stopDetails']);
  final departureStop = _map(stopDetails['departureStop']);
  final arrivalStop = _map(stopDetails['arrivalStop']);
  final line = _map(transitDetails['transitLine']);
  final vehicle = _map(line['vehicle']);
  final departureTime = _dateTime(stopDetails['departureTime']);
  final rawArrivalTime = _dateTime(stopDetails['arrivalTime']);
  final durationMinutes =
      _minutesBetween(departureTime, rawArrivalTime) ??
      _stepDurationMinutes(step);
  final arrivalTime =
      rawArrivalTime != null &&
          departureTime != null &&
          rawArrivalTime.isAfter(departureTime)
      ? rawArrivalTime
      : departureTime?.add(Duration(minutes: durationMinutes));

  return _ParsedTransitLeg(
    departureTime: departureTime,
    arrivalTime: arrivalTime,
    leg: GoogleRoutesTransitLeg.ride(
      durationMinutes: durationMinutes,
      lineId: _lineIdFor(line, vehicle),
      from: _string(departureStop['name']),
      to: _string(arrivalStop['name']),
      stopCount: _nullableInt(transitDetails['stopCount']),
    ),
  );
}

class _ParsedTransitLeg {
  const _ParsedTransitLeg({
    required this.leg,
    this.departureTime,
    this.arrivalTime,
  });

  final GoogleRoutesTransitLeg leg;
  final DateTime? departureTime;
  final DateTime? arrivalTime;
}

String _lineIdFor(Map<String, Object?> line, Map<String, Object?> vehicle) {
  final agencies = _mapList(
    line['agencies'],
  ).map((agency) => _string(agency['name'])).join(' ');
  final shortName = _string(line['nameShort']);
  final haystack =
      '$agencies ${_string(line['name'])} $shortName '
              '${_string(line['color'])} ${_string(vehicle['type'])}'
          .toLowerCase();

  if (haystack.contains('bart')) {
    if (haystack.contains('yellow')) return 'bart-yellow';
    if (haystack.contains('orange')) return 'bart-orange';
    if (haystack.contains('green')) return 'bart-green';
    if (haystack.contains('blue')) return 'bart-blue';
    if (haystack.contains('red')) return 'bart-red';
    if (haystack.contains('beige') || haystack.contains('oak')) {
      return oakAirportConnectorLineId;
    }
  }

  if (haystack.contains('muni') || haystack.contains('sfmta')) {
    final muniLine = muniMetroLineIds[shortName.toUpperCase()];
    if (muniLine != null) return muniLine;
  }

  if (haystack.contains('caltrain')) return 'caltrain';
  if (haystack.contains('ferry')) return regionalFerryLineId;
  if (haystack.contains('bus')) return regionalBusLineId;
  if (haystack.contains('rail') || haystack.contains('train')) {
    return regionalRailLineId;
  }
  return regionalTransitLineId;
}

String _walkDestination(Map<String, Object?> step) {
  final instructions = _string(
    _map(step['navigationInstruction'])['instructions'],
  );
  return instructions.isEmpty ? 'next stop' : instructions;
}

String _fare(Map<String, Object?> route) {
  final fare = _map(_map(route['travelAdvisory'])['transitFare']);
  final localizedText = _string(_map(fare['localizedText'])['text']);
  if (localizedText.isNotEmpty) return localizedText;

  final units = int.tryParse(_string(fare['units']));
  final nanos = _nullableInt(fare['nanos']) ?? 0;
  if (units == null && nanos == 0) return '';

  final value = (units ?? 0) + nanos / 1000000000;
  return '\$${value.toStringAsFixed(2)}';
}

int _stepDurationMinutes(Map<String, Object?> step) {
  final staticDuration = _durationMinutes(step['staticDuration']);
  if (staticDuration > 0) return staticDuration;
  final duration = _durationMinutes(step['duration']);
  return duration <= 0 ? 1 : duration;
}

int _durationMinutes(Object? value) {
  final text = _string(value);
  final match = RegExp(r'^(-?\d+(?:\.\d+)?)s$').firstMatch(text);
  if (match == null) return 0;
  final seconds = double.tryParse(match.group(1) ?? '') ?? 0;
  if (seconds <= 0) return 0;
  return (seconds / 60).ceil();
}

int? _minutesBetween(DateTime? depart, DateTime? arrive) {
  if (depart == null || arrive == null) return null;
  final seconds = arrive.difference(depart).inSeconds;
  if (seconds <= 0) return null;
  return (seconds / 60).round();
}

DateTime? _dateTime(Object? value) {
  final text = _string(value);
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

String _clock(DateTime? value) {
  if (value == null) return '--:--';
  final local = value.isUtc ? value.toLocal() : value;
  return '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
}

String _errorMessage(http.Response response) {
  try {
    final error = _map(_map(jsonDecode(response.body))['error']);
    final message = _string(error['message']);
    if (message.isNotEmpty) return message;
  } on Object {
    // Fall through to status code.
  }
  return 'Google Routes HTTP ${response.statusCode}';
}

Map<String, Object?> _map(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, value) => MapEntry(key.toString(), value)),
  ];
}

String _string(Object? value) {
  if (value == null) return '';
  final text = value.toString().trim();
  return text;
}

int? _nullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}
