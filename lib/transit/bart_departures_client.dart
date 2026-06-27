import 'dart:async';
import 'dart:convert';

import 'package:genui_template/transit/_json.dart' as json_util;
import 'package:genui_template/transit/transit_lines.dart';
import 'package:http/http.dart' as http;

enum LiveDeparturesSource { bart, sf511 }

class LiveDeparturesRequest {
  const LiveDeparturesRequest.bart({
    required this.stationAbbr,
    this.stationName,
  }) : source = LiveDeparturesSource.bart,
       agency = null,
       agencyName = null,
       stopCode = null,
       stopName = null,
       lineFilter = null;

  const LiveDeparturesRequest.sf511({
    this.agency,
    this.agencyName,
    this.stopCode,
    this.stopName,
    this.lineFilter,
  }) : source = LiveDeparturesSource.sf511,
       stationAbbr = null,
       stationName = null;

  final LiveDeparturesSource source;
  final String? stationAbbr;
  final String? stationName;
  final String? agency;
  final String? agencyName;
  final String? stopCode;
  final String? stopName;
  final String? lineFilter;

  String get cacheKey {
    return [
      source.name,
      stationAbbr,
      stationName,
      agency,
      agencyName,
      stopCode,
      stopName,
      lineFilter,
    ].map((part) => (part ?? '').trim().toLowerCase()).join('|');
  }
}

class BartDeparture {
  const BartDeparture({
    required this.line,
    required this.destination,
    required this.minutes,
    this.platform,
    this.live = true,
    this.lineLabel,
    this.operatorName,
    this.operatorId,
    this.mode,
    this.serviceTime,
    this.serviceTimeKind,
    this.timeStatusLabel,
  });

  final String line;
  final String destination;
  final int minutes;
  final String? platform;
  final bool live;
  final String? lineLabel;
  final String? operatorName;
  final String? operatorId;
  final String? mode;
  final DateTime? serviceTime;
  final String? serviceTimeKind;
  final String? timeStatusLabel;
}

class BartDepartureBoard {
  const BartDepartureBoard({
    required this.station,
    required this.departures,
    this.live = true,
    this.sourceLabel = 'BART',
    this.fetchedAt,
    this.statusLabel,
  });

  final String station;
  final List<BartDeparture> departures;
  final bool live;
  final String sourceLabel;
  final DateTime? fetchedAt;
  final String? statusLabel;
}

class TransitAgencyInfo {
  const TransitAgencyInfo({
    required this.id,
    required this.name,
    required this.monitored,
  });

  final String id;
  final String name;
  final bool monitored;
}

class TransitRouteInfo {
  const TransitRouteInfo({
    required this.id,
    required this.label,
    required this.mode,
  });

  final String id;
  final String label;
  final String mode;
}

class TransitStopInfo {
  const TransitStopInfo({
    required this.code,
    required this.name,
    this.lineLabels = const [],
  });

  final String code;
  final String name;
  final List<String> lineLabels;
}

class LiveDeparturesClient {
  LiveDeparturesClient({
    http.Client? httpClient,
    this.bartApiKey = const String.fromEnvironment(
      'BART_API_KEY',
      defaultValue: defaultBartApiKey,
    ),
    this.key511 = const String.fromEnvironment('KEY_511'),
    this.proxyBaseUrl = const String.fromEnvironment('BART_PROXY_BASE_URL'),
    this.timeout = const Duration(seconds: 8),
    this.cacheDuration = const Duration(seconds: 60),
    DateTime Function()? now,
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsClient = httpClient == null,
       _now = now ?? DateTime.now;

  final http.Client _httpClient;
  final bool _ownsClient;
  final DateTime Function() _now;

  final String bartApiKey;
  final String key511;
  final String proxyBaseUrl;
  final Duration timeout;
  final Duration cacheDuration;

  final Map<String, _CachedBoard> _departureCache = {};
  List<TransitAgencyInfo>? _agencies;
  final Map<String, Map<String, TransitRouteInfo>> _routesByAgency = {};
  final Map<String, List<TransitStopInfo>> _stopsByAgency = {};

  Future<BartDepartureBoard> fetch(LiveDeparturesRequest request) async {
    return _fetchWithCache(request);
  }

  Future<BartDepartureBoard> fetchBartDepartures(String stationAbbr) {
    return _fetchWithCache(
      LiveDeparturesRequest.bart(stationAbbr: stationAbbr),
    );
  }

  Future<BartDepartureBoard> fetch511Departures({
    String? agency,
    String? agencyName,
    String? stopCode,
    String? stopName,
    String? lineFilter,
  }) {
    return _fetchWithCache(
      LiveDeparturesRequest.sf511(
        agency: agency,
        agencyName: agencyName,
        stopCode: stopCode,
        stopName: stopName,
        lineFilter: lineFilter,
      ),
    );
  }

  Future<BartDepartureBoard> _fetchWithCache(
    LiveDeparturesRequest request,
  ) async {
    final cacheKey = request.cacheKey;
    final cached = _departureCache[cacheKey];
    if (cached != null && _now().difference(cached.fetchedAt) < cacheDuration) {
      return cached.board;
    }

    final board = switch (request.source) {
      LiveDeparturesSource.bart => await _fetchBartDeparturesFromNetwork(
        request.stationAbbr ?? request.stationName ?? '',
      ),
      LiveDeparturesSource.sf511 => await _fetch511DeparturesFromNetwork(
        request,
      ),
    };
    _departureCache[cacheKey] = _CachedBoard(
      board: board,
      fetchedAt: board.fetchedAt ?? _now(),
    );
    return board;
  }

  Future<List<TransitAgencyInfo>> monitoredAgencies() async {
    final cached = _agencies;
    if (cached != null) return cached;

    _require511Key();
    final data = await _getJson(
      _uri511('/transit/operators'),
      service: '511 operators',
      buildException: LiveDeparturesException.new,
    );
    final agencies = _parseAgencies(data);
    if (agencies.isEmpty) {
      throw const LiveDeparturesException(
        '511 did not return any monitored transit agencies',
      );
    }

    _agencies = agencies;
    return agencies;
  }

  Future<Map<String, TransitRouteInfo>> routesForAgency(String agency) async {
    final normalizedAgency = _normalizeAgencyId(agency);
    if (normalizedAgency.isEmpty) {
      throw const LiveDeparturesException('511 agency is required');
    }

    final cached = _routesByAgency[normalizedAgency];
    if (cached != null) return cached;

    _require511Key();
    final data = await _getJson(
      _uri511('/transit/lines', {'operator_id': normalizedAgency}),
      service: '511 lines',
      buildException: LiveDeparturesException.new,
    );
    final routes = _parseRoutes(data);
    _routesByAgency[normalizedAgency] = routes;
    return routes;
  }

  Future<List<TransitStopInfo>> stopsForAgency(String agency) async {
    final normalizedAgency = _normalizeAgencyId(agency);
    if (normalizedAgency.isEmpty) {
      throw const LiveDeparturesException('511 agency is required');
    }

    final cached = _stopsByAgency[normalizedAgency];
    if (cached != null) return cached;

    _require511Key();
    final data = await _getJson(
      _uri511('/transit/stops', {'operator_id': normalizedAgency}),
      service: '511 stops',
      buildException: LiveDeparturesException.new,
    );
    final stops = _parseStops(data);
    if (stops.isEmpty) {
      throw LiveDeparturesException(
        '511 did not return stops for agency $normalizedAgency',
      );
    }

    _stopsByAgency[normalizedAgency] = stops;
    return stops;
  }

  Future<BartDepartureBoard> _fetchBartDeparturesFromNetwork(
    String stationAbbr,
  ) async {
    final normalizedStation = _normalizeStationAbbr(stationAbbr);
    if (normalizedStation == 'OAKL') return _oakAirportConnectorBoard();

    final data = await _getJson(
      _bartUriFor(normalizedStation),
      service: 'BART API',
      buildException: BartDeparturesException.new,
    );
    final decoded = json_util.map(data);
    if (decoded.isEmpty) {
      throw const BartDeparturesException('BART API returned invalid JSON');
    }
    if (decoded['error'] case final Object error) {
      throw BartDeparturesException(error.toString());
    }
    final fetchedAt = _now();
    if (decoded['kind'] == 'departures') {
      return _boardFromProxyJson(decoded, normalizedStation, fetchedAt);
    }
    return _boardFromBartJson(decoded, normalizedStation, fetchedAt);
  }

  Future<BartDepartureBoard> _fetch511DeparturesFromNetwork(
    LiveDeparturesRequest request,
  ) async {
    _require511Key();

    final agency = await _resolveAgency(request.agency, request.agencyName);
    final stops = await _resolveStops(
      agency.id,
      request.stopCode,
      request.stopName,
      request.lineFilter,
    );
    final routes = await _routesForAgencyOrEmpty(agency.id);

    final visits = <Map<String, Object?>>[];
    final stopErrors = <String>[];
    for (final stop in stops) {
      final data = await _getJson(
        _uri511('/transit/StopMonitoring', {
          'agency': agency.id,
          'stopcode': stop.code,
        }),
        service: '511 StopMonitoring',
        buildException: LiveDeparturesException.new,
      );

      final error = _siriErrorMessage(data);
      if (error != null) {
        stopErrors.add(error);
        continue;
      }
      visits.addAll(_monitoredStopVisits(data));
    }

    if (visits.isEmpty && stopErrors.isNotEmpty) {
      throw LiveDeparturesException(stopErrors.first);
    }

    final fetchedAt = _now();
    final departures = <BartDeparture>[];
    for (final visit in visits) {
      final journey = json_util.map(visit['MonitoredVehicleJourney']);
      final call = json_util.map(journey['MonitoredCall']);
      final serviceTime = _siriServiceTime(call);
      if (serviceTime == null) continue;

      final lineRef = _field(journey, const ['LineRef']);
      final publishedLineName = _field(journey, const ['PublishedLineName']);
      final route = _routeFor(routes, lineRef, publishedLineName);
      if (!_matchesLineFilter(
        request.lineFilter,
        lineRef,
        publishedLineName,
        route,
      )) {
        continue;
      }

      final secondsUntilDeparture = serviceTime.time
          .difference(fetchedAt)
          .inSeconds;
      final minutes = secondsUntilDeparture <= 0
          ? 0
          : (secondsUntilDeparture / 60).round();
      departures.add(
        BartDeparture(
          line: _lineIdFor511(agency.id, lineRef, route, publishedLineName),
          destination: _field(
            journey,
            const ['DestinationName', 'DirectionName'],
            fallback: publishedLineName.isEmpty ? 'Transit' : publishedLineName,
          ),
          platform: json_util.nullableString(
            _valueFor(call, const ['ArrivalPlatformName', 'Platform']),
          ),
          minutes: minutes,
          lineLabel: _lineLabelFor511(lineRef, route, publishedLineName),
          operatorName: agency.name,
          operatorId: agency.id,
          mode: route?.mode,
          serviceTime: serviceTime.time,
          serviceTimeKind: serviceTime.kind,
          timeStatusLabel: serviceTime.statusLabel,
        ),
      );
    }

    departures.sort((a, b) => a.minutes.compareTo(b.minutes));
    if (departures.isEmpty) {
      throw LiveDeparturesException(
        'No live 511 departures found for ${_stopLabel(stops)}',
      );
    }

    final stationName = stops.length == 1
        ? _stopNameFromVisits(visits) ?? stops.single.name
        : _clean(request.stopName).isEmpty
        ? _stopLabel(stops)
        : _clean(request.stopName);
    return BartDepartureBoard(
      station: stationName,
      sourceLabel: agency.name,
      fetchedAt: fetchedAt,
      departures: departures.take(8).toList(),
    );
  }

  Uri _bartUriFor(String stationAbbr) {
    if (proxyBaseUrl.trim().isNotEmpty) return _proxyUri(stationAbbr);
    return Uri.https('api.bart.gov', '/api/etd.aspx', {
      'cmd': 'etd',
      'orig': stationAbbr,
      'key': _effectiveBartApiKey,
      'json': 'y',
    });
  }

  Uri _proxyUri(String stationAbbr) {
    final base = proxyBaseUrl.trim();
    if (base.endsWith('=') || base.endsWith('/')) {
      return Uri.parse('$base$stationAbbr');
    }

    final uri = Uri.parse(base);
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'station': stationAbbr,
      },
    );
  }

  Uri _uri511(String path, [Map<String, String> extraQuery = const {}]) {
    return Uri.https('api.511.org', path, {
      'api_key': key511,
      ...extraQuery,
      'format': 'json',
    });
  }

  Future<Object?> _getJson(
    Uri uri, {
    required String service,
    required LiveDeparturesException Function(String message) buildException,
  }) async {
    try {
      final response = await _httpClient.get(uri).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw buildException('$service HTTP ${response.statusCode}');
      }

      final body = utf8
          .decode(response.bodyBytes)
          .replaceFirst(RegExp(r'^\uFEFF'), '')
          .trim();
      if (body.isEmpty) throw buildException('$service returned an empty body');
      return jsonDecode(body);
    } on LiveDeparturesException {
      rethrow;
    } on TimeoutException {
      throw buildException('$service timed out');
    } on FormatException {
      throw buildException('$service returned invalid JSON');
    } on Object catch (error) {
      throw buildException('$service request failed: $error');
    }
  }

  BartDepartureBoard _boardFromProxyJson(
    Map<String, Object?> json,
    String stationAbbr,
    DateTime fetchedAt,
  ) {
    final boardFetchedAt = _parseDateTime(json['fetchedAt']) ?? fetchedAt;
    final departures =
        json_util
            .mapList(json['list'])
            .map((departure) => _departureFromProxy(departure, boardFetchedAt))
            .toList()
          ..sort((a, b) => a.minutes.compareTo(b.minutes));
    return BartDepartureBoard(
      station: json_util.string(json['station'], stationAbbr),
      departures: departures.take(8).toList(),
      sourceLabel: json_util.string(json['sourceLabel'], 'BART'),
      live: json_util.boolean(json['live'], fallback: true),
      fetchedAt: boardFetchedAt,
      statusLabel: json_util.nullableString(json['statusLabel']),
    );
  }

  BartDeparture _departureFromProxy(
    Map<String, Object?> json,
    DateTime fetchedAt,
  ) {
    final minutes = _minutes(json['mins']);
    final serviceTime =
        _parseDateTime(json['serviceTime']) ??
        _relativeServiceTime(fetchedAt, minutes);
    return BartDeparture(
      line: _proxyLineId(json['line']),
      destination: json_util.string(json['dest'], 'Transit'),
      platform: json_util.nullableString(json['plat']),
      minutes: minutes,
      live: json_util.boolean(json['live'], fallback: true),
      lineLabel: json_util.nullableString(json['lineLabel']),
      operatorName: json_util.nullableString(json['operatorName']),
      operatorId: json_util.nullableString(json['operatorId']),
      mode: json_util.nullableString(json['mode']),
      serviceTime: serviceTime,
      serviceTimeKind:
          json_util.nullableString(json['serviceTimeKind']) ??
          'RelativeDepartureMinutes',
      timeStatusLabel:
          json_util.nullableString(json['timeStatusLabel']) ?? 'BART estimate',
    );
  }

  BartDepartureBoard _boardFromBartJson(
    Map<String, Object?> json,
    String stationAbbr,
    DateTime fetchedAt,
  ) {
    final root = json_util.map(json['root']);
    if (_bartApiMessage(root, 'error') case final error?) {
      throw BartDeparturesException(error);
    }

    final station = json_util.mapList(root['station']).firstOrNull;
    if (station == null) {
      throw BartDeparturesException(
        _bartApiMessage(root, 'warning') ?? 'No BART station in response',
      );
    }

    final departures = <BartDeparture>[];
    for (final etd in json_util.mapList(station['etd'])) {
      for (final estimate in json_util.mapList(etd['estimate'])) {
        final minutes = _minutes(estimate['minutes']);
        departures.add(
          BartDeparture(
            line: _lineIdForBartColor(estimate['color']),
            destination: json_util.string(etd['destination'], 'Train'),
            platform: json_util.nullableString(estimate['platform']),
            minutes: minutes,
            operatorName: 'BART',
            serviceTime: _relativeServiceTime(fetchedAt, minutes),
            serviceTimeKind: 'RelativeDepartureMinutes',
            timeStatusLabel: 'BART estimate',
          ),
        );
      }
    }

    if (departures.isEmpty) {
      throw BartDeparturesException(
        _bartApiMessage(root, 'warning') ?? 'No trains reported here right now',
      );
    }

    departures.sort((a, b) => a.minutes.compareTo(b.minutes));
    return BartDepartureBoard(
      station: json_util.string(station['name'], stationAbbr),
      departures: departures.take(8).toList(),
      fetchedAt: fetchedAt,
    );
  }

  BartDepartureBoard _oakAirportConnectorBoard() {
    return const BartDepartureBoard(
      station: 'Oakland Airport',
      live: false,
      departures: [
        BartDeparture(
          line: oakAirportConnectorLineId,
          destination: 'Coliseum',
          minutes: 3,
          live: false,
        ),
        BartDeparture(
          line: oakAirportConnectorLineId,
          destination: 'Coliseum',
          minutes: oakAirportConnectorMinutes,
          live: false,
        ),
        BartDeparture(
          line: oakAirportConnectorLineId,
          destination: 'Coliseum',
          minutes: 15,
          live: false,
        ),
      ],
    );
  }

  Future<TransitAgencyInfo> _resolveAgency(
    String? agency,
    String? agencyName,
  ) async {
    final agencyId = _normalizeAgencyId(agency ?? '');
    if (agencyId.isNotEmpty) {
      try {
        final agencies = await monitoredAgencies();
        for (final candidate in agencies) {
          if (candidate.id.toUpperCase() == agencyId) return candidate;
        }
      } on LiveDeparturesException {
        // A known agency id can still be used if discovery is temporarily down.
      }

      return TransitAgencyInfo(
        id: agencyId,
        name: _clean(agencyName).isEmpty ? agencyId : _clean(agencyName),
        monitored: true,
      );
    }

    final name = _clean(agencyName);
    if (name.isEmpty) {
      throw const LiveDeparturesException(
        '511 agency or agencyName is required for live departures',
      );
    }

    final needle = _normalizeLookup(name);
    final matches = [
      for (final candidate in await monitoredAgencies())
        if (_normalizeLookup(candidate.name) == needle ||
            _normalizeLookup(candidate.id) == needle)
          candidate,
    ];
    if (matches.length == 1) return matches.single;
    if (matches.length > 1) {
      throw LiveDeparturesException('511 agency "$name" is ambiguous');
    }
    throw LiveDeparturesException('511 agency "$name" was not found');
  }

  Future<List<TransitStopInfo>> _resolveStops(
    String agency,
    String? stopCode,
    String? stopName,
    String? lineFilter,
  ) async {
    final code = _clean(stopCode);
    final name = _clean(stopName);
    if (code.isNotEmpty) {
      return [TransitStopInfo(code: code, name: name.isEmpty ? code : name)];
    }
    if (name.isEmpty) {
      throw const LiveDeparturesException(
        '511 stopCode or stopName is required for live departures',
      );
    }

    final needle = _normalizeLookup(name);
    final localStops = _local511StopsForAgency(
      agency,
      name,
      lineFilter: lineFilter,
    );
    if (localStops.isNotEmpty) return localStops;

    final matches = [
      for (final stop in await stopsForAgency(agency))
        if (_normalizeLookup(stop.name) == needle ||
            _normalizeLookup(stop.code) == needle)
          stop,
    ];
    final distinctCodes = {for (final stop in matches) stop.code};
    if (distinctCodes.length == 1) return [matches.first];
    if (distinctCodes.length > 1) {
      throw LiveDeparturesException('511 stop "$name" is ambiguous');
    }
    throw LiveDeparturesException('511 stop "$name" was not found');
  }

  Future<Map<String, TransitRouteInfo>> _routesForAgencyOrEmpty(
    String agency,
  ) async {
    try {
      return await routesForAgency(agency);
    } on LiveDeparturesException {
      return const {};
    }
  }

  String _normalizeStationAbbr(String stationAbbr) {
    final resolvedStation = resolveBartStation(stationAbbr);
    if (resolvedStation != null) return resolvedStation.abbr;

    final cleaned = stationAbbr.toUpperCase().replaceAll(
      RegExp('[^A-Z0-9]'),
      '',
    );
    if (cleaned.length == 4) return cleaned;

    throw BartDeparturesException(
      'Invalid station "$stationAbbr". Use a known BART station name or '
      'four-letter abbreviation.',
    );
  }

  void _require511Key() {
    if (key511.trim().isEmpty) {
      throw const LiveDeparturesException(
        'KEY_511 is required for 511 live departures. Run with '
        '--dart-define=KEY_511=your_511_token.',
      );
    }
  }

  String get _effectiveBartApiKey {
    final trimmed = bartApiKey.trim();
    return trimmed.isEmpty ? defaultBartApiKey : trimmed;
  }

  void close() {
    if (_ownsClient) _httpClient.close();
  }
}

class BartDeparturesClient extends LiveDeparturesClient {
  BartDeparturesClient({
    super.httpClient,
    super.bartApiKey,
    super.key511,
    super.proxyBaseUrl,
    super.timeout,
    super.cacheDuration,
    super.now,
  });

  @override
  Future<BartDepartureBoard> fetch(LiveDeparturesRequest request) {
    if (request.source == LiveDeparturesSource.bart) {
      return fetchDepartures(request.stationAbbr ?? request.stationName ?? '');
    }
    return super.fetch(request);
  }

  Future<BartDepartureBoard> fetchDepartures(String stationAbbr) {
    return super.fetchBartDepartures(stationAbbr);
  }
}

class LiveDeparturesException implements Exception {
  const LiveDeparturesException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BartDeparturesException extends LiveDeparturesException {
  const BartDeparturesException(super.message);
}

class _CachedBoard {
  const _CachedBoard({required this.board, required this.fetchedAt});

  final BartDepartureBoard board;
  final DateTime fetchedAt;
}

class _SiriServiceTime {
  const _SiriServiceTime({
    required this.time,
    required this.kind,
    required this.statusLabel,
  });

  final DateTime time;
  final String kind;
  final String statusLabel;
}

class _SiriTimeField {
  const _SiriTimeField(this.name, this.statusLabel);

  final String name;
  final String statusLabel;
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

List<TransitAgencyInfo> _parseAgencies(Object? data) {
  return [
    for (final object in _objectsFrom(data, const ['operators', 'operator']))
      if (_agencyFromJson(object) case final agency?)
        if (agency.monitored && !_internal511OperatorIds.contains(agency.id))
          agency,
  ];
}

TransitAgencyInfo? _agencyFromJson(Map<String, Object?> json) {
  final id = _field(
    json,
    const ['Id', 'ID', 'OperatorId', 'OperatorID', 'operator_id', 'AgencyId'],
  ).toUpperCase();
  if (id.isEmpty) return null;

  return TransitAgencyInfo(
    id: id,
    name: _field(
      json,
      const ['Name', 'OperatorName', 'AgencyName', 'Title'],
      fallback: id,
    ),
    monitored: _boolField(json, const ['Monitored', 'monitored']),
  );
}

Map<String, TransitRouteInfo> _parseRoutes(Object? data) {
  final routes = <String, TransitRouteInfo>{};
  for (final object in _objectsFrom(data, const ['lines', 'line', 'routes'])) {
    final route = _routeFromJson(object);
    if (route == null) continue;
    routes[_normalizeRouteKey(route.id)] = route;
    routes[_normalizeRouteKey(route.label)] = route;
  }
  return routes;
}

TransitRouteInfo? _routeFromJson(Map<String, Object?> json) {
  final id = _field(
    json,
    const ['Id', 'ID', 'LineId', 'LineID', 'LineRef', 'RouteId', 'Code'],
  );
  if (id.isEmpty) return null;

  return TransitRouteInfo(
    id: id,
    label: _field(
      json,
      const ['Name', 'PublicCode', 'PublishedLineName', 'Description'],
      fallback: id,
    ),
    mode: _field(json, const ['TransportMode', 'Mode', 'RouteType']),
  );
}

List<TransitStopInfo> _parseStops(Object? data) {
  return [
    for (final object in _objectsFrom(data, const ['stops', 'stop']))
      ?_stopFromJson(object),
  ];
}

TransitStopInfo? _stopFromJson(Map<String, Object?> json) {
  final code = _field(
    json,
    const ['StopCode', 'Code', 'Id', 'ID', 'StopId', 'StopPointRef'],
  );
  if (code.isEmpty) return null;

  return TransitStopInfo(
    code: code,
    name: _field(
      json,
      const ['Name', 'StopName', 'Description', 'Title'],
      fallback: code,
    ),
  );
}

List<TransitStopInfo> _local511StopsForAgency(
  String agency,
  String stopName, {
  String? lineFilter,
}) {
  final agencyStops = _local511Stops[_normalizeAgencyId(agency)];
  if (agencyStops == null) return const [];

  final stops = agencyStops[_normalizeLookup(stopName)] ?? const [];
  if (stops.isEmpty) return const [];

  final filter = _normalizeLookup(lineFilter ?? '');
  if (filter.isEmpty) return stops;

  final filtered = [
    for (final stop in stops)
      if (stop.lineLabels.any((line) => _normalizeLookup(line) == filter)) stop,
  ];
  return filtered.isEmpty ? stops : filtered;
}

String _stopLabel(List<TransitStopInfo> stops) {
  if (stops.isEmpty) return 'this stop';
  if (stops.length == 1) return stops.single.name;
  final names = {for (final stop in stops) stop.name};
  if (names.length == 1) return names.single;
  return names.take(2).join(' / ');
}

List<Map<String, Object?>> _monitoredStopVisits(Object? data) {
  final delivery = json_util.map(
    json_util.map(data)['ServiceDelivery'],
  );
  final stopMonitoringDelivery = json_util
      .mapList(delivery['StopMonitoringDelivery'])
      .firstOrNull;
  if (stopMonitoringDelivery == null) return const [];
  return json_util.mapList(stopMonitoringDelivery['MonitoredStopVisit']);
}

String? _siriErrorMessage(Object? data) {
  final delivery = json_util.map(json_util.map(data)['ServiceDelivery']);
  final serviceError = _nestedMessage(
    delivery['ErrorCondition'],
    'Description',
  );
  if (serviceError != null && serviceError.isNotEmpty) return serviceError;

  for (final stopDelivery in json_util.mapList(
    delivery['StopMonitoringDelivery'],
  )) {
    final error = _nestedMessage(stopDelivery['ErrorCondition'], 'Description');
    if (error != null && error.isNotEmpty) return error;
  }
  return null;
}

String? _stopNameFromVisits(List<Map<String, Object?>> visits) {
  for (final visit in visits) {
    final journey = json_util.map(visit['MonitoredVehicleJourney']);
    final call = json_util.map(journey['MonitoredCall']);
    final name = _field(call, const ['StopPointName']);
    if (name.isNotEmpty) return name;
  }
  return null;
}

List<Map<String, Object?>> _objectsFrom(Object? data, List<String> keys) {
  if (data is List) return json_util.mapList(data);

  final root = json_util.map(data);
  if (root.isEmpty) return const [];

  for (final key in keys) {
    final value = _valueFor(root, [key]);
    final objects = json_util.mapList(value);
    if (objects.isNotEmpty) return objects;
  }

  if (_looksLikeSingleObject(root, keys)) return [root];
  return const [];
}

bool _looksLikeSingleObject(Map<String, Object?> json, List<String> keys) {
  if (keys.contains('operators')) {
    return _field(json, const ['Id', 'OperatorId', 'operator_id']).isNotEmpty;
  }
  if (keys.contains('lines')) {
    return _field(json, const ['Id', 'LineId', 'LineRef']).isNotEmpty;
  }
  if (keys.contains('stops')) {
    return _field(json, const ['StopCode', 'Code', 'StopPointRef']).isNotEmpty;
  }
  return false;
}

TransitRouteInfo? _routeFor(
  Map<String, TransitRouteInfo> routes,
  String lineRef,
  String publishedLineName,
) {
  return routes[_normalizeRouteKey(lineRef)] ??
      routes[_normalizeRouteKey(publishedLineName)];
}

bool _matchesLineFilter(
  String? lineFilter,
  String lineRef,
  String publishedLineName,
  TransitRouteInfo? route,
) {
  final filter = _normalizeLookup(lineFilter ?? '');
  if (filter.isEmpty) return true;

  return [
    lineRef,
    publishedLineName,
    route?.id ?? '',
    route?.label ?? '',
  ].any((value) => _normalizeLookup(value) == filter);
}

String _lineLabelFor511(
  String lineRef,
  TransitRouteInfo? route,
  String publishedLineName,
) {
  if (route != null && route.label.isNotEmpty) return route.label;
  if (publishedLineName.isNotEmpty) return publishedLineName;
  return lineRef;
}

String _lineIdFor511(
  String agency,
  String lineRef,
  TransitRouteInfo? route,
  String publishedLineName,
) {
  final agencyId = agency.toUpperCase();
  final lineKey = lineRef.toUpperCase();
  if (agencyId == 'SF') {
    final muniLineId = muniMetroLineIds[lineKey];
    if (muniLineId != null) return muniLineId;
  }
  if (agencyId == 'CT') return 'caltrain';
  if (agencyId == 'BA') {
    final bartLineId = bartColorLineIds[lineKey];
    if (bartLineId != null) return bartLineId;
  }

  final mode = '${route?.mode ?? ''} $publishedLineName ${route?.label ?? ''}'
      .toLowerCase();
  if (mode.contains('ferry')) return regionalFerryLineId;
  if (mode.contains('rail') ||
      mode.contains('train') ||
      mode.contains('subway') ||
      mode.contains('metro')) {
    return regionalRailLineId;
  }
  if (mode.contains('bus') || mode.contains('coach')) return regionalBusLineId;
  return regionalTransitLineId;
}

String? _bartApiMessage(Map<String, Object?> root, String key) {
  final text = _nestedMessage(root['message'], key);
  return text == null || text.isEmpty ? null : text;
}

String? _nestedMessage(Object? value, String key) {
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key.toString().toLowerCase() == key.toLowerCase()) {
        return _messageText(entry.value);
      }

      final nested = _nestedMessage(entry.value, key);
      if (nested != null && nested.isNotEmpty) return nested;
    }
  }

  if (value is List) {
    for (final item in value) {
      final nested = _nestedMessage(item, key);
      if (nested != null && nested.isNotEmpty) return nested;
    }
  }

  return null;
}

String? _messageText(Object? value) {
  if (value == null) return null;
  if (value is String) return value.trim();
  if (value is num || value is bool) return value.toString();

  if (value is Map) {
    final parts = [
      for (final entry in value.entries) _messageText(entry.value),
    ].whereType<String>().where((text) => text.isNotEmpty);
    return parts.join(' ').trim();
  }

  if (value is List) {
    final parts = value
        .map(_messageText)
        .whereType<String>()
        .where((text) => text.isNotEmpty);
    return parts.join(' ').trim();
  }

  return value.toString();
}

Object? _valueFor(Map<String, Object?> json, List<String> keys) {
  final wanted = {for (final key in keys) key.toLowerCase()};
  for (final entry in json.entries) {
    if (wanted.contains(entry.key.toLowerCase())) return entry.value;
  }
  return null;
}

String _field(
  Map<String, Object?> json,
  List<String> keys, {
  String fallback = '',
}) {
  return json_util.string(_valueFor(json, keys), fallback).trim();
}

bool _boolField(Map<String, Object?> json, List<String> keys) {
  return json_util.boolean(_valueFor(json, keys), fallback: false);
}

_SiriServiceTime? _siriServiceTime(Map<String, Object?> call) {
  for (final field in _siriTimeFields) {
    final time = _parseDateTime(_valueFor(call, [field.name]));
    if (time != null) {
      return _SiriServiceTime(
        time: time,
        kind: field.name,
        statusLabel: field.statusLabel,
      );
    }
  }
  return null;
}

DateTime? _parseDateTime(Object? value) {
  final text = json_util.string(value).trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

DateTime _relativeServiceTime(DateTime fetchedAt, int minutes) {
  return fetchedAt.add(Duration(minutes: minutes));
}

int _minutes(Object? value) {
  if (value is num) return value.round();
  if (value is String && value.toLowerCase() == 'leaving') return 0;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _lineIdForBartColor(Object? value) {
  final color = json_util.string(value).toUpperCase();
  return bartColorLineIds[color] ?? fallbackTransitLine.id;
}

String _proxyLineId(Object? value) {
  return json_util.string(value, fallbackTransitLine.id);
}

String _normalizeAgencyId(String agency) {
  return agency.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
}

String _normalizeRouteKey(String value) {
  return _normalizeLookup(value);
}

String _normalizeLookup(String value) {
  return value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
}

String _clean(String? value) => (value ?? '').trim();

const _siriTimeFields = [
  _SiriTimeField('ExpectedDepartureTime', 'Expected'),
  _SiriTimeField('ExpectedArrivalTime', 'Expected'),
  _SiriTimeField('AimedDepartureTime', 'Scheduled'),
  _SiriTimeField('AimedArrivalTime', 'Scheduled'),
];

const _sfFourthAndKingStops = [
  TransitStopInfo(
    code: '15239',
    name: 'King St & 4th St',
    lineLabels: ['N', 'N Judah'],
  ),
  TransitStopInfo(
    code: '15240',
    name: 'King St & 4th St',
    lineLabels: ['N', 'N Judah'],
  ),
  TransitStopInfo(
    code: '17166',
    name: '4th St & King St',
    lineLabels: ['T', 'T Third'],
  ),
  TransitStopInfo(
    code: '17397',
    name: '4th St & King St',
    lineLabels: ['T', 'T Third'],
  ),
  TransitStopInfo(
    code: '17405',
    name: '4th St & King St',
    lineLabels: ['91', 'TBUS'],
  ),
];

const Map<String, Map<String, List<TransitStopInfo>>> _local511Stops = {
  'SF': {
    '4thandking': _sfFourthAndKingStops,
    '4thking': _sfFourthAndKingStops,
    '4thstandkingst': _sfFourthAndKingStops,
    'kingstand4thst': _sfFourthAndKingStops,
    '4thandkingcaltrain': _sfFourthAndKingStops,
    'sanfranciscocaltrain': _sfFourthAndKingStops,
    'sfcaltrain': _sfFourthAndKingStops,
  },
};

const Set<String> _internal511OperatorIds = {'5E', '5F', '5O', '5S'};
