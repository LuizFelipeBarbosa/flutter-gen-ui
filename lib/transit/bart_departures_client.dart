import 'dart:convert';

import 'package:genui_template/transit/transit_lines.dart';
import 'package:http/http.dart' as http;

class BartDeparture {
  const BartDeparture({
    required this.line,
    required this.destination,
    required this.minutes,
    this.platform,
    this.live = true,
  });

  final String line;
  final String destination;
  final int minutes;
  final String? platform;
  final bool live;
}

class BartDepartureBoard {
  const BartDepartureBoard({
    required this.station,
    required this.departures,
    this.live = true,
  });

  final String station;
  final List<BartDeparture> departures;
  final bool live;
}

class BartDeparturesClient {
  BartDeparturesClient({
    http.Client? httpClient,
    this._apiKey = const String.fromEnvironment(
      'BART_API_KEY',
      defaultValue: defaultBartApiKey,
    ),
    this._proxyBaseUrl = const String.fromEnvironment('BART_PROXY_BASE_URL'),
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  final http.Client _httpClient;
  final bool _ownsClient;
  final String _apiKey;
  final String _proxyBaseUrl;

  Future<BartDepartureBoard> fetchDepartures(String stationAbbr) async {
    final normalizedStation = _normalizeStationAbbr(stationAbbr);
    if (normalizedStation == 'OAKL') return _oakAirportConnectorBoard();

    final response = await _httpClient.get(_uriFor(normalizedStation));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BartDeparturesException('BART API HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const BartDeparturesException('BART API returned invalid JSON');
    }
    if (decoded['error'] case final Object error) {
      throw BartDeparturesException(error.toString());
    }
    if (decoded['kind'] == 'departures') {
      return _boardFromProxyJson(decoded, normalizedStation);
    }
    return _boardFromBartJson(decoded, normalizedStation);
  }

  Uri _uriFor(String stationAbbr) {
    if (_proxyBaseUrl.trim().isNotEmpty) return _proxyUri(stationAbbr);
    return Uri.https('api.bart.gov', '/api/etd.aspx', {
      'cmd': 'etd',
      'orig': stationAbbr,
      'key': _apiKey,
      'json': 'y',
    });
  }

  Uri _proxyUri(String stationAbbr) {
    final base = _proxyBaseUrl.trim();
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

  BartDepartureBoard _boardFromProxyJson(
    Map<String, Object?> json,
    String stationAbbr,
  ) {
    final departures = _mapList(json['list']).map(_departureFromProxy).toList()
      ..sort((a, b) => a.minutes.compareTo(b.minutes));
    return BartDepartureBoard(
      station: _string(json['station'], stationAbbr),
      departures: departures.take(8).toList(),
    );
  }

  BartDeparture _departureFromProxy(Map<String, Object?> json) {
    return BartDeparture(
      line: _string(json['line'], 'bart-red'),
      destination: _string(json['dest'], 'Train'),
      platform: _nullableString(json['plat']),
      minutes: _minutes(json['mins']),
      live: _bool(json['live'], fallback: true),
    );
  }

  BartDepartureBoard _boardFromBartJson(
    Map<String, Object?> json,
    String stationAbbr,
  ) {
    final root = _map(json['root']);
    if (_bartApiMessage(root, 'error') case final error?) {
      throw BartDeparturesException(error);
    }

    final station = _mapList(root['station']).firstOrNull;
    if (station == null) {
      throw BartDeparturesException(
        _bartApiMessage(root, 'warning') ?? 'No BART station in response',
      );
    }

    final departures = <BartDeparture>[];
    for (final etd in _mapList(station['etd'])) {
      for (final estimate in _mapList(etd['estimate'])) {
        final color = _string(estimate['color']).toUpperCase();
        departures.add(
          BartDeparture(
            line: bartColorLineIds[color] ?? 'bart-red',
            destination: _string(etd['destination'], 'Train'),
            platform: _nullableString(estimate['platform']),
            minutes: _minutes(estimate['minutes']),
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
      station: _string(station['name'], stationAbbr),
      departures: departures.take(8).toList(),
    );
  }

  BartDepartureBoard _oakAirportConnectorBoard() {
    return const BartDepartureBoard(
      station: 'Oakland Airport',
      live: false,
      departures: [
        BartDeparture(
          line: 'bart-beige',
          destination: 'Coliseum',
          minutes: 3,
          live: false,
        ),
        BartDeparture(
          line: 'bart-beige',
          destination: 'Coliseum',
          minutes: 9,
          live: false,
        ),
        BartDeparture(
          line: 'bart-beige',
          destination: 'Coliseum',
          minutes: 15,
          live: false,
        ),
      ],
    );
  }

  String _normalizeStationAbbr(String stationAbbr) {
    final cleaned = stationAbbr.toUpperCase().replaceAll(
      RegExp('[^A-Z0-9]'),
      '',
    );
    return cleaned.length <= 4 ? cleaned : cleaned.substring(0, 4);
  }

  void close() {
    if (_ownsClient) _httpClient.close();
  }
}

class BartDeparturesException implements Exception {
  const BartDeparturesException(this.message);

  final String message;

  @override
  String toString() => message;
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
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

String _string(Object? value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

String? _bartApiMessage(Map<String, Object?> root, String key) {
  final text = _nestedMessage(root['message'], key);
  return text == null || text.isEmpty ? null : text;
}

String? _nestedMessage(Object? value, String key) {
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key.toString().toLowerCase() == key) {
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

bool _bool(Object? value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

int _minutes(Object? value) {
  if (value is num) return value.round();
  if (value is String && value.toLowerCase() == 'leaving') return 0;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
