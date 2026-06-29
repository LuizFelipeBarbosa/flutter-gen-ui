import 'dart:convert';

import 'package:bayhop/explore/itinerary.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ItineraryStore {
  ItineraryStore({
    Future<SharedPreferences> Function()? preferencesLoader,
    this.key = defaultKey,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const defaultKey = 'bayhop.saved_itinerary.v1';
  static const _version = 1;

  final Future<SharedPreferences> Function() _preferencesLoader;
  final String key;

  Future<List<ItineraryStop>> load() async {
    final preferences = await _preferencesLoader();
    final raw = preferences.getString(key);
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];

      final payload = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      if (payload['version'] != _version) return const [];

      return itineraryStopsFromJson(payload['stops']);
    } on FormatException {
      return const [];
    }
  }

  Future<void> save(List<ItineraryStop> stops) async {
    final preferences = await _preferencesLoader();
    final payload = {
      'version': _version,
      'stops': [for (final stop in stops) stop.toJson()],
    };
    await preferences.setString(key, jsonEncode(payload));
  }

  Future<void> clear() async {
    final preferences = await _preferencesLoader();
    await preferences.remove(key);
  }
}
