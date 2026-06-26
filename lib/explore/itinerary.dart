import 'package:flutter/foundation.dart';
import 'package:genui_template/places/places.dart';

class ItineraryStop {
  const ItineraryStop({
    required this.localId,
    required this.title,
    this.placeId,
    this.address,
    this.category,
    this.durationMinutes = 60,
    this.latitude,
    this.longitude,
    this.googleMapsUri,
    this.notes,
  });

  factory ItineraryStop.fromPlace(
    PlaceResult place, {
    required String localId,
    String? notes,
  }) {
    return ItineraryStop(
      localId: localId,
      placeId: place.id,
      title: place.displayName,
      address: place.formattedAddress,
      category: place.types.isEmpty ? null : _typeLabel(place.types.first),
      latitude: place.latitude,
      longitude: place.longitude,
      googleMapsUri: place.googleMapsUri,
      notes: notes,
    );
  }

  factory ItineraryStop.fromAction(
    Map<String, Object?> context, {
    required String localId,
  }) {
    return ItineraryStop(
      localId: localId,
      placeId: _string(context['placeId']) ?? _string(context['id']),
      title:
          _string(context['title']) ??
          _string(context['displayName']) ??
          'Stop',
      address:
          _string(context['address']) ?? _string(context['formattedAddress']),
      category: _string(context['category']),
      durationMinutes: _int(context['durationMinutes'], fallback: 60),
      latitude: _double(context['latitude']),
      longitude: _double(context['longitude']),
      googleMapsUri: _uri(context['googleMapsUri']),
      notes: _string(context['notes']),
    );
  }

  final String localId;
  final String? placeId;
  final String title;
  final String? address;
  final String? category;
  final int durationMinutes;
  final double? latitude;
  final double? longitude;
  final Uri? googleMapsUri;
  final String? notes;

  String get dedupeKey {
    final id = placeId?.trim().toLowerCase();
    if (id != null && id.isNotEmpty) return 'place:$id';
    final addressPart = address == null ? '' : '|${_normalize(address!)}';
    return 'text:${_normalize(title)}$addressPart';
  }

  Map<String, Object?> toActionContext() {
    return {
      'placeId': placeId,
      'title': title,
      'address': address,
      'category': category,
      'durationMinutes': durationMinutes,
      'latitude': latitude,
      'longitude': longitude,
      'googleMapsUri': googleMapsUri?.toString(),
      'notes': notes,
    }..removeWhere((_, value) => value == null);
  }
}

class ItineraryController extends ValueNotifier<List<ItineraryStop>> {
  ItineraryController() : super(const []);

  int _nextId = 1;

  bool addStop(ItineraryStop stop) {
    final key = stop.dedupeKey;
    if (value.any((existing) => existing.dedupeKey == key)) return false;
    value = [...value, stop];
    return true;
  }

  bool addPlace(PlaceResult place) {
    return addStop(
      ItineraryStop.fromPlace(place, localId: _createLocalId()),
    );
  }

  bool addFromAction(Map<String, Object?> context) {
    return addStop(
      ItineraryStop.fromAction(context, localId: _createLocalId()),
    );
  }

  void remove(String localId) {
    value = [
      for (final stop in value)
        if (stop.localId != localId) stop,
    ];
  }

  void clear() {
    value = const [];
  }

  void move(String localId, int delta) {
    final current = [...value];
    final index = current.indexWhere((stop) => stop.localId == localId);
    if (index < 0) return;
    final nextIndex = (index + delta).clamp(0, current.length - 1);
    if (nextIndex == index) return;

    final stop = current.removeAt(index);
    current.insert(nextIndex, stop);
    value = current;
  }

  String toPromptContext() {
    if (value.isEmpty) {
      return 'Itinerary: empty. Avoid assuming saved stops.';
    }

    final rows = <String>[];
    for (var i = 0; i < value.length; i++) {
      final stop = value[i];
      final details = [
        stop.title,
        if (stop.category != null) stop.category,
        if (stop.address != null) stop.address,
        '${stop.durationMinutes} min',
      ].join(' | ');
      rows.add('${i + 1}. $details');
    }
    return 'Itinerary: ${rows.join('; ')}. Avoid duplicate stops.';
  }

  String _createLocalId() => 'stop-${_nextId++}';
}

String _normalize(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String _typeLabel(String type) {
  final words = type
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}');
  return words.join(' ');
}

String? _string(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _int(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double? _double(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

Uri? _uri(Object? value) {
  final text = _string(value);
  if (text == null) return null;
  return Uri.tryParse(text);
}
