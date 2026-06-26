import 'package:flutter/material.dart';
import 'package:genui_template/location/location.dart';
import 'package:genui_template/transit/transit_lines.dart';
import 'package:genui_template/transit/transit_widgets.dart';

MapRouteOverlay? buildTransitJourneyRouteOverlay(
  TransitJourney journey, {
  LocationCoordinate? currentLocation,
}) {
  final segments = <MapRouteSegment>[];
  final transferMarkers = <MapRouteMarker>[];
  final firstRide = journey.firstRide;
  final lastRide = journey.lastRide;
  var currentPoint = _routePointForText(
    journey.from,
    lineId: firstRide?.line,
    currentLocation: currentLocation,
  );

  for (final leg in journey.legs) {
    switch (leg.type) {
      case TransitLegType.ride:
        final fromPoint =
            _routePointForText(
              leg.from,
              lineId: leg.line,
              currentLocation: currentLocation,
            ) ??
            currentPoint;
        final toPoint = _routePointForText(
          leg.to,
          lineId: leg.line,
          currentLocation: currentLocation,
        );
        final line = lineFor(leg.line);

        if (fromPoint != null && toPoint != null) {
          final points = _ridePoints(
            lineId: leg.line,
            from: fromPoint,
            to: toPoint,
          );
          if (points.length > 1) {
            segments.add(
              MapRouteSegment(
                points: points,
                color: line.color,
                label: line.label,
              ),
            );
            currentPoint = toPoint;
          }
        }

      case TransitLegType.change:
        final point = _routePointForText(
          leg.station,
          lineId: lastRide?.line ?? firstRide?.line,
          currentLocation: currentLocation,
        );
        if (point != null) {
          currentPoint = point;
          transferMarkers.add(
            MapRouteMarker(
              coordinate: point.coordinate,
              label: point.label,
              kind: MapRouteMarkerKind.transfer,
              color: BayHopRouteColors.transfer,
            ),
          );
        }

      case TransitLegType.walk:
        final fromPoint =
            currentPoint ??
            _routePointForText(
              leg.from.isEmpty ? journey.from : leg.from,
              lineId: firstRide?.line ?? lastRide?.line,
              currentLocation: currentLocation,
            );
        final toPoint = _routePointForText(
          leg.to,
          lineId: firstRide?.line ?? lastRide?.line,
          currentLocation: currentLocation,
        );
        if (fromPoint != null && toPoint != null) {
          segments.add(
            MapRouteSegment(
              points: [fromPoint.coordinate, toPoint.coordinate],
              color: BayHopRouteColors.walk,
              label: 'Walk',
              dashed: true,
            ),
          );
          currentPoint = toPoint;
        }
    }
  }

  if (segments.isEmpty) return null;

  final originPoint = _routePointForText(
    journey.from,
    lineId: firstRide?.line,
    currentLocation: currentLocation,
  );
  final destinationPoint = _routePointForText(
    journey.to,
    lineId: lastRide?.line,
    currentLocation: currentLocation,
  );
  final markers = <MapRouteMarker>[
    if (originPoint != null)
      MapRouteMarker(
        coordinate: originPoint.coordinate,
        label: _originLabel(journey.from, originPoint),
        kind: MapRouteMarkerKind.origin,
        color: _routeEndpointColor(firstRide?.line),
      ),
    ...transferMarkers,
    if (destinationPoint != null)
      MapRouteMarker(
        coordinate: destinationPoint.coordinate,
        label: destinationPoint.label,
        kind: MapRouteMarkerKind.destination,
        color: _routeEndpointColor(lastRide?.line),
      ),
  ];

  return MapRouteOverlay(
    id: _overlayIdFor(journey),
    segments: segments,
    markers: markers,
  );
}

BayAreaTransitStop? resolveTransitRouteStop(
  String text, {
  String? lineId,
}) {
  final query = _normalizeStopText(text);
  if (query.isEmpty || _currentLocationNames.contains(query)) return null;

  final aliasId = _stopAliases[query];
  if (aliasId != null) {
    final aliasStop = _stopById(aliasId, lineId: lineId);
    if (aliasStop != null) return aliasStop;
  }

  final candidates = <BayAreaTransitStop>[];
  for (final stop in bayAreaTransitStops) {
    final name = _normalizeStopText(stop.name);
    final id = _normalizeStopText(stop.id);
    final abbr = _normalizeStopText(stop.bartAbbr ?? '');
    if (query == name ||
        query == id ||
        query == abbr ||
        name.contains(query) ||
        query.contains(name)) {
      candidates.add(stop);
    }
  }

  return _preferLineMatch(candidates, lineId);
}

_RoutePoint? _routePointForText(
  String text, {
  required String? lineId,
  required LocationCoordinate? currentLocation,
}) {
  final query = _normalizeStopText(text);
  if (query.isEmpty) return null;
  if (_currentLocationNames.contains(query)) {
    if (currentLocation == null) return null;
    return _RoutePoint(
      label: 'Current location',
      coordinate: currentLocation,
      isCurrentLocation: true,
    );
  }

  final stop = resolveTransitRouteStop(text, lineId: lineId);
  if (stop != null) {
    return _RoutePoint(
      label: stop.name,
      coordinate: stop.coordinate,
      stop: stop,
    );
  }

  return _resolveRouteAnchor(query);
}

List<LocationCoordinate> _ridePoints({
  required String lineId,
  required _RoutePoint from,
  required _RoutePoint to,
}) {
  final fromStop = from.stop;
  final toStop = to.stop;
  if (fromStop == null || toStop == null) {
    return [from.coordinate, to.coordinate];
  }

  final sequence = _lineStopSequences[lineId];
  if (sequence == null) return [from.coordinate, to.coordinate];

  final fromIndex = sequence.indexOf(fromStop.id);
  final toIndex = sequence.indexOf(toStop.id);
  if (fromIndex < 0 || toIndex < 0) return [from.coordinate, to.coordinate];

  final ids = fromIndex <= toIndex
      ? sequence.sublist(fromIndex, toIndex + 1)
      : sequence.sublist(toIndex, fromIndex + 1).reversed;

  final points = [
    for (final id in ids)
      if (_stopById(id) case final stop?) stop.coordinate,
  ];
  if (points.length > 1) return points;
  return [from.coordinate, to.coordinate];
}

BayAreaTransitStop? _stopById(String id, {String? lineId}) {
  final candidates = bayAreaTransitStops.where((stop) => stop.id == id);
  return _preferLineMatch(candidates, lineId);
}

BayAreaTransitStop? _preferLineMatch(
  Iterable<BayAreaTransitStop> candidates,
  String? lineId,
) {
  final stops = candidates.toList();
  if (stops.isEmpty) return null;
  final normalizedLine = lineId?.trim();
  if (normalizedLine != null && normalizedLine.isNotEmpty) {
    for (final stop in stops) {
      if (stop.lineIds.contains(normalizedLine)) return stop;
    }
  }
  return stops.first;
}

_RoutePoint? _resolveRouteAnchor(String query) {
  final anchorId = _routeAnchorAliases[query];
  if (anchorId != null) return _routeAnchors[anchorId];

  for (final anchor in _routeAnchors.values) {
    final label = _normalizeStopText(anchor.label);
    if (query == label || label.contains(query) || query.contains(label)) {
      return anchor;
    }
  }

  return null;
}

Color _routeEndpointColor(String? lineId) {
  if (lineId == null || lineId.isEmpty) return BayHopRouteColors.walk;
  return lineFor(lineId).color;
}

String _originLabel(
  String label,
  _RoutePoint origin,
) {
  if (origin.isCurrentLocation) return 'Current location';
  return label;
}

String _overlayIdFor(TransitJourney journey) {
  final legs = journey.legs
      .map(
        (leg) => [
          leg.type.name,
          leg.line,
          leg.from,
          leg.to,
          leg.station,
          leg.minutes,
        ].join(':'),
      )
      .join('|');
  return 'transit:${journey.from}>${journey.to}:${journey.depart}:$legs';
}

String _normalizeStopText(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp("['.]"), '')
      .replaceAll(RegExp('[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\b(station|stop|bart|muni|metro|caltrain)\b'), '')
      .replaceAll(RegExp(r'\bstreet\b'), 'st')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class BayHopRouteColors {
  const BayHopRouteColors._();

  static const walk = Color(0xFF7C8997);
  static const transfer = Color(0xFF151A20);
}

class _RoutePoint {
  const _RoutePoint({
    required this.label,
    required this.coordinate,
    this.stop,
    this.isCurrentLocation = false,
  });

  final String label;
  final LocationCoordinate coordinate;
  final BayAreaTransitStop? stop;
  final bool isCurrentLocation;
}

const _currentLocationNames = {
  'here',
  'from here',
  'current location',
  'my location',
  'near me',
  'nearby',
};

const _routeAnchors = {
  'salesforce-transit-center': _RoutePoint(
    label: 'Salesforce Transit Center',
    coordinate: LocationCoordinate(latitude: 37.7897, longitude: -122.3969),
  ),
  'ferry-building': _RoutePoint(
    label: 'Ferry Building',
    coordinate: LocationCoordinate(latitude: 37.7955, longitude: -122.3937),
  ),
  'pier-39': _RoutePoint(
    label: "Fisherman's Wharf / Pier 39",
    coordinate: LocationCoordinate(latitude: 37.8087, longitude: -122.4098),
  ),
  'golden-gate-park-9th-irving': _RoutePoint(
    label: 'Golden Gate Park / 9th & Irving',
    coordinate: LocationCoordinate(latitude: 37.764, longitude: -122.4661),
  ),
  'dolores-park': _RoutePoint(
    label: 'Dolores Park',
    coordinate: LocationCoordinate(latitude: 37.7596, longitude: -122.4269),
  ),
  'presidio-transit-center': _RoutePoint(
    label: 'Presidio Transit Center',
    coordinate: LocationCoordinate(latitude: 37.8, longitude: -122.455),
  ),
  'uc-berkeley': _RoutePoint(
    label: 'UC Berkeley',
    coordinate: LocationCoordinate(latitude: 37.8719, longitude: -122.2585),
  ),
  'stanford': _RoutePoint(
    label: 'Stanford',
    coordinate: LocationCoordinate(latitude: 37.4275, longitude: -122.1697),
  ),
  'san-jose-airport': _RoutePoint(
    label: 'San Jose Airport',
    coordinate: LocationCoordinate(latitude: 37.3639, longitude: -121.9289),
  ),
};

const _routeAnchorAliases = {
  'salesforce transit center': 'salesforce-transit-center',
  'salesforce center': 'salesforce-transit-center',
  'transbay terminal': 'salesforce-transit-center',
  'sf transit center': 'salesforce-transit-center',
  'ferry building': 'ferry-building',
  'sf ferry building': 'ferry-building',
  'san francisco ferry building': 'ferry-building',
  'fishermans wharf': 'pier-39',
  'fisherman wharf': 'pier-39',
  'pier 39': 'pier-39',
  'golden gate park': 'golden-gate-park-9th-irving',
  '9th and irving': 'golden-gate-park-9th-irving',
  '9th irving': 'golden-gate-park-9th-irving',
  'ninth and irving': 'golden-gate-park-9th-irving',
  'ninth irving': 'golden-gate-park-9th-irving',
  'dolores park': 'dolores-park',
  'mission dolores park': 'dolores-park',
  'presidio transit center': 'presidio-transit-center',
  'presidio': 'presidio-transit-center',
  'uc berkeley': 'uc-berkeley',
  'university of california berkeley': 'uc-berkeley',
  'cal campus': 'uc-berkeley',
  'berkeley campus': 'uc-berkeley',
  'stanford': 'stanford',
  'stanford university': 'stanford',
  'san jose airport': 'san-jose-airport',
  'sjc': 'san-jose-airport',
  'mineta san jose airport': 'san-jose-airport',
};

const _stopAliases = {
  '12th': 'bart-12th-st-oakland',
  '12th oakland': 'bart-12th-st-oakland',
  '19th': 'bart-19th-st-oakland',
  '19th oakland': 'bart-19th-st-oakland',
  '4th and king': 'sf-caltrain',
  '4th king': 'sf-caltrain',
  'sf 4th and king': 'sf-caltrain',
  'sf caltrain': 'sf-caltrain',
  'san francisco': 'sf-caltrain',
  'san francisco 4th and king': 'sf-caltrain',
  'south san francisco': 'caltrain-south-san-francisco',
  'san francisco airport': 'bart-sfo',
  'san francisco international': 'bart-sfo',
  'sfo': 'bart-sfo',
  'oak': 'bart-oakland-airport',
  'oak airport': 'bart-oakland-airport',
  'oakland airport': 'bart-oakland-airport',
  'oakland international': 'bart-oakland-airport',
  'berryessa': 'bart-berryessa',
  'north san jose': 'bart-berryessa',
  'dublin': 'bart-dublin-pleasanton',
  'pleasanton': 'bart-dublin-pleasanton',
  'west dublin': 'bart-west-dublin-pleasanton',
  'west dublin pleasanton': 'bart-west-dublin-pleasanton',
};

const _lineStopSequences = {
  'bart-red': [
    'bart-richmond',
    'bart-el-cerrito-del-norte',
    'bart-el-cerrito-plaza',
    'bart-north-berkeley',
    'bart-downtown-berkeley',
    'bart-ashby',
    'bart-macarthur',
    'bart-19th-st-oakland',
    'bart-12th-st-oakland',
    'bart-west-oakland',
    'bart-embarcadero',
    'bart-montgomery',
    'bart-powell',
    'bart-civic-center',
    'bart-16th-st-mission',
    'bart-24th-st-mission',
    'bart-glen-park',
    'bart-balboa-park',
    'bart-daly-city',
    'bart-colma',
    'bart-south-san-francisco',
    'bart-san-bruno',
    'bart-sfo',
    'bart-millbrae',
  ],
  'bart-yellow': [
    'bart-antioch',
    'bart-pittsburg-bay-point',
    'bart-north-concord',
    'bart-concord',
    'bart-pleasant-hill',
    'bart-walnut-creek',
    'bart-lafayette',
    'bart-orinda',
    'bart-rockridge',
    'bart-macarthur',
    'bart-19th-st-oakland',
    'bart-12th-st-oakland',
    'bart-west-oakland',
    'bart-embarcadero',
    'bart-montgomery',
    'bart-powell',
    'bart-civic-center',
    'bart-16th-st-mission',
    'bart-24th-st-mission',
    'bart-glen-park',
    'bart-balboa-park',
    'bart-daly-city',
    'bart-colma',
    'bart-south-san-francisco',
    'bart-san-bruno',
    'bart-sfo',
    'bart-millbrae',
  ],
  'bart-orange': [
    'bart-richmond',
    'bart-el-cerrito-del-norte',
    'bart-el-cerrito-plaza',
    'bart-north-berkeley',
    'bart-downtown-berkeley',
    'bart-ashby',
    'bart-macarthur',
    'bart-19th-st-oakland',
    'bart-12th-st-oakland',
    'bart-lake-merritt',
    'bart-fruitvale',
    'bart-coliseum',
    'bart-san-leandro',
    'bart-bay-fair',
    'bart-hayward',
    'bart-south-hayward',
    'bart-union-city',
    'bart-fremont',
    'bart-warm-springs',
    'bart-milpitas',
    'bart-berryessa',
  ],
  'bart-green': [
    'bart-berryessa',
    'bart-milpitas',
    'bart-warm-springs',
    'bart-fremont',
    'bart-union-city',
    'bart-south-hayward',
    'bart-hayward',
    'bart-bay-fair',
    'bart-san-leandro',
    'bart-coliseum',
    'bart-fruitvale',
    'bart-lake-merritt',
    'bart-west-oakland',
    'bart-embarcadero',
    'bart-montgomery',
    'bart-powell',
    'bart-civic-center',
    'bart-16th-st-mission',
    'bart-24th-st-mission',
    'bart-glen-park',
    'bart-balboa-park',
    'bart-daly-city',
  ],
  'bart-blue': [
    'bart-dublin-pleasanton',
    'bart-west-dublin-pleasanton',
    'bart-castro-valley',
    'bart-bay-fair',
    'bart-san-leandro',
    'bart-coliseum',
    'bart-fruitvale',
    'bart-lake-merritt',
    'bart-west-oakland',
    'bart-embarcadero',
    'bart-montgomery',
    'bart-powell',
    'bart-civic-center',
    'bart-16th-st-mission',
    'bart-24th-st-mission',
    'bart-glen-park',
    'bart-balboa-park',
    'bart-daly-city',
  ],
  'bart-beige': [
    'bart-coliseum',
    'bart-oakland-airport',
  ],
  'muni-j': [
    'muni-embarcadero',
    'muni-montgomery',
    'muni-powell',
    'muni-civic-center',
    'muni-van-ness',
    'muni-church',
  ],
  'muni-k': [
    'muni-embarcadero',
    'muni-montgomery',
    'muni-powell',
    'muni-civic-center',
    'muni-van-ness',
    'muni-church',
    'muni-castro',
    'muni-forest-hill',
    'muni-west-portal',
  ],
  'muni-l': [
    'muni-embarcadero',
    'muni-montgomery',
    'muni-powell',
    'muni-civic-center',
    'muni-van-ness',
    'muni-church',
    'muni-castro',
    'muni-forest-hill',
    'muni-west-portal',
  ],
  'muni-m': [
    'muni-embarcadero',
    'muni-montgomery',
    'muni-powell',
    'muni-civic-center',
    'muni-van-ness',
    'muni-church',
    'muni-castro',
    'muni-forest-hill',
    'muni-west-portal',
  ],
  'muni-n': [
    'muni-4th-king',
    'muni-embarcadero',
    'muni-montgomery',
    'muni-powell',
    'muni-civic-center',
    'muni-van-ness',
    'muni-church',
  ],
  'muni-t': [
    'muni-4th-king',
    'muni-embarcadero',
    'muni-montgomery',
    'muni-powell',
    'muni-civic-center',
  ],
  'caltrain': [
    'sf-caltrain',
    'caltrain-22nd-st',
    'caltrain-bayshore',
    'caltrain-south-san-francisco',
    'caltrain-san-bruno',
    'caltrain-millbrae',
    'caltrain-burlingame',
    'caltrain-san-mateo',
    'caltrain-hillsdale',
    'caltrain-belmont',
    'caltrain-san-carlos',
    'caltrain-redwood-city',
    'caltrain-menlo-park',
    'caltrain-palo-alto',
    'caltrain-california-ave',
    'caltrain-mountain-view',
    'caltrain-sunnyvale',
    'caltrain-lawrence',
    'caltrain-santa-clara',
    'caltrain-san-jose-diridon',
  ],
};
