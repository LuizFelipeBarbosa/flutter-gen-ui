import 'dart:async';
import 'dart:convert';

import 'package:bayhop/places/place_result.dart';
import 'package:http/http.dart' as http;

enum NearbyRankPreference { popularity, distance }

class PlaceSearchCircle {
  const PlaceSearchCircle({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final double latitude;
  final double longitude;
  final double radiusMeters;

  Map<String, Object?> toJson() {
    return {
      'circle': {
        'center': {
          'latitude': latitude,
          'longitude': longitude,
        },
        'radius': radiusMeters,
      },
    };
  }
}

class PlacesException implements Exception {
  const PlacesException(this.message);

  final String message;

  @override
  String toString() => 'PlacesException: $message';
}

class GooglePlacesClient {
  GooglePlacesClient({
    http.Client? httpClient,
    this.apiKey = const String.fromEnvironment('GOOGLE_PLACES_API_KEY'),
    this.baseUrl = 'https://places.googleapis.com',
    this.fieldMask = defaultFieldMask,
    this.timeout = const Duration(seconds: 8),
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  static const String defaultFieldMask =
      'places.id,'
      'places.displayName,'
      'places.formattedAddress,'
      'places.rating,'
      'places.userRatingCount,'
      'places.priceLevel,'
      'places.types,'
      'places.location,'
      'places.photos,'
      'places.googleMapsUri,'
      'places.websiteUri,'
      'places.nationalPhoneNumber,'
      'places.currentOpeningHours.openNow,'
      'places.regularOpeningHours.openNow';

  final http.Client _httpClient;
  final bool _ownsClient;

  final String apiKey;
  final String baseUrl;
  final String fieldMask;
  final Duration timeout;

  Future<List<PlaceResult>> searchText({
    required String query,
    int maxResultCount = 10,
    PlaceSearchCircle? locationBias,
    String? includedType,
    String? languageCode,
    String? regionCode,
    bool? openNow,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      throw const PlacesException('Text search query is required');
    }
    _validateMaxResultCount(maxResultCount);
    if (locationBias != null) _validateCircle(locationBias);

    final body = <String, Object?>{
      'textQuery': trimmedQuery,
      'maxResultCount': maxResultCount,
    };
    if (locationBias != null) body['locationBias'] = locationBias.toJson();
    final type = _nonEmpty(includedType);
    if (type != null) body['includedType'] = type;
    final language = _nonEmpty(languageCode);
    if (language != null) body['languageCode'] = language;
    final region = _nonEmpty(regionCode);
    if (region != null) body['regionCode'] = region;
    if (openNow != null) body['openNow'] = openNow;

    return _postSearch(
      path: 'places:searchText',
      body: body,
    );
  }

  Future<List<PlaceResult>> searchNearby({
    required double latitude,
    required double longitude,
    required double radiusMeters,
    int maxResultCount = 10,
    List<String> includedTypes = const [],
    List<String> excludedTypes = const [],
    NearbyRankPreference? rankPreference,
    String? languageCode,
    String? regionCode,
  }) async {
    _validateMaxResultCount(maxResultCount);
    final circle = PlaceSearchCircle(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
    _validateCircle(circle);

    final body = <String, Object?>{
      'maxResultCount': maxResultCount,
      'locationRestriction': circle.toJson(),
    };
    final types = _nonEmptyList(includedTypes);
    if (types != null) body['includedTypes'] = types;
    final exclusions = _nonEmptyList(excludedTypes);
    if (exclusions != null) body['excludedTypes'] = exclusions;
    if (rankPreference != null) {
      body['rankPreference'] = _rankPreferenceValue(rankPreference);
    }
    final language = _nonEmpty(languageCode);
    if (language != null) body['languageCode'] = language;
    final region = _nonEmpty(regionCode);
    if (region != null) body['regionCode'] = region;

    return _postSearch(
      path: 'places:searchNearby',
      body: body,
    );
  }

  Uri? photoMediaUri(
    PlacePhoto photo, {
    int maxWidthPx = 480,
    int maxHeightPx = 320,
  }) {
    final key = _nonEmpty(apiKey);
    final name = _nonEmpty(photo.name);
    if (key == null || name == null) return null;

    final queryParameters = <String, String>{'key': key};
    if (maxWidthPx > 0) queryParameters['maxWidthPx'] = '$maxWidthPx';
    if (maxHeightPx > 0) queryParameters['maxHeightPx'] = '$maxHeightPx';

    return _uri('$name/media').replace(queryParameters: queryParameters);
  }

  void close() {
    if (_ownsClient) _httpClient.close();
  }

  Future<List<PlaceResult>> _postSearch({
    required String path,
    required Map<String, Object?> body,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const PlacesException(
        'GOOGLE_PLACES_API_KEY is required for Google Places requests',
      );
    }
    if (fieldMask.trim().isEmpty) {
      throw const PlacesException('Google Places field mask is required');
    }

    try {
      final response = await _httpClient
          .post(
            _uri(path),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': key,
              'X-Goog-FieldMask': fieldMask,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PlacesException(_errorMessage(response));
      }

      final decoded = jsonDecode(_responseBody(response));
      final places = _mapList(_map(decoded)['places']);
      return [for (final place in places) PlaceResult.fromJson(place)];
    } on PlacesException {
      rethrow;
    } on TimeoutException {
      throw const PlacesException('Google Places request timed out');
    } on FormatException {
      throw const PlacesException('Google Places returned invalid JSON');
    } on Object catch (error) {
      throw PlacesException('Google Places request failed: $error');
    }
  }

  Uri _uri(String path) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root/v1/$path');
  }
}

void _validateMaxResultCount(int value) {
  if (value < 1 || value > 20) {
    throw const PlacesException(
      'Google Places maxResultCount must be between 1 and 20',
    );
  }
}

void _validateCircle(PlaceSearchCircle circle) {
  if (circle.latitude < -90 || circle.latitude > 90) {
    throw const PlacesException('Latitude must be between -90 and 90');
  }
  if (circle.longitude < -180 || circle.longitude > 180) {
    throw const PlacesException('Longitude must be between -180 and 180');
  }
  if (circle.radiusMeters <= 0 || circle.radiusMeters > 50000) {
    throw const PlacesException(
      'Google Places radius must be greater than 0 and no more than 50000',
    );
  }
}

String _rankPreferenceValue(NearbyRankPreference rankPreference) {
  return switch (rankPreference) {
    NearbyRankPreference.popularity => 'POPULARITY',
    NearbyRankPreference.distance => 'DISTANCE',
  };
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

List<String>? _nonEmptyList(List<String> values) {
  final trimmed = <String>[];
  for (final value in values) {
    final text = _nonEmpty(value);
    if (text != null) trimmed.add(text);
  }
  return trimmed.isEmpty ? null : trimmed;
}

String _responseBody(http.Response response) {
  return utf8
      .decode(response.bodyBytes)
      .replaceFirst(RegExp(r'^\uFEFF'), '')
      .trim();
}

String _errorMessage(http.Response response) {
  final body = _responseBody(response);
  if (body.isEmpty) {
    return 'Google Places HTTP ${response.statusCode}';
  }

  try {
    final data = _map(jsonDecode(body));
    final error = _map(data['error']);
    final message = _string(error['message']) ?? _string(data['message']);
    if (message != null) return message;
  } on FormatException {
    return 'Google Places HTTP ${response.statusCode}';
  }

  return 'Google Places HTTP ${response.statusCode}';
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
      if (item is Map) _map(item),
  ];
}

String? _string(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
