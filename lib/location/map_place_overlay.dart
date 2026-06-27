import 'package:flutter/widgets.dart';
import 'package:genui_template/location/location_point.dart';
import 'package:genui_template/places/places.dart';

enum MapPlaceMarkerKind { searchResult, savedItinerary }

class MapPlaceMarker {
  const MapPlaceMarker({
    required this.id,
    required this.label,
    required this.coordinate,
    required this.kind,
    this.subtitle,
    this.sequence,
    this.googleMapsUri,
  });

  factory MapPlaceMarker.fromPlaceResult(PlaceResult place) {
    final latitude = place.latitude;
    final longitude = place.longitude;
    if (!_isValidCoordinate(latitude, longitude)) {
      throw ArgumentError.value(
        place.id,
        'place',
        'Place markers require valid latitude and longitude.',
      );
    }

    return MapPlaceMarker(
      id: place.id,
      label: place.displayName,
      subtitle: place.formattedAddress,
      coordinate: LocationCoordinate(
        latitude: latitude!,
        longitude: longitude!,
      ),
      kind: MapPlaceMarkerKind.searchResult,
      googleMapsUri: place.googleMapsUri,
    );
  }

  final String id;
  final String label;
  final LocationCoordinate coordinate;
  final MapPlaceMarkerKind kind;
  final String? subtitle;
  final int? sequence;
  final Uri? googleMapsUri;

  static List<MapPlaceMarker> searchResultsFromPlaces(
    Iterable<PlaceResult> places,
  ) {
    return [
      for (final place in places)
        if (_isValidCoordinate(place.latitude, place.longitude))
          MapPlaceMarker.fromPlaceResult(place),
    ];
  }
}

class MapPlaceOverlayController extends ValueNotifier<List<MapPlaceMarker>> {
  MapPlaceOverlayController() : super(const []);

  List<MapPlaceMarker> _searchResultMarkers = const [];
  List<MapPlaceMarker> _savedItineraryMarkers = const [];

  List<MapPlaceMarker> get searchResultMarkers => _searchResultMarkers;

  List<MapPlaceMarker> get savedItineraryMarkers => _savedItineraryMarkers;

  void showSearchResults(Iterable<MapPlaceMarker> markers) {
    _searchResultMarkers = List.unmodifiable(markers);
    _publish();
  }

  void clearSearchResults() {
    if (_searchResultMarkers.isEmpty) return;
    _searchResultMarkers = const [];
    _publish();
  }

  void showSavedItineraryMarkers(Iterable<MapPlaceMarker> markers) {
    _savedItineraryMarkers = List.unmodifiable(markers);
    _publish();
  }

  void clearSavedItineraryMarkers() {
    if (_savedItineraryMarkers.isEmpty) return;
    _savedItineraryMarkers = const [];
    _publish();
  }

  void _publish() {
    value = List.unmodifiable([
      ..._savedItineraryMarkers,
      ..._searchResultMarkers,
    ]);
  }
}

class MapPlaceOverlayScope extends InheritedWidget {
  const MapPlaceOverlayScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final MapPlaceOverlayController controller;

  static MapPlaceOverlayController? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<MapPlaceOverlayScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(MapPlaceOverlayScope oldWidget) {
    return oldWidget.controller != controller;
  }
}

bool _isValidCoordinate(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return false;
  return latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}
