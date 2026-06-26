import 'package:flutter/foundation.dart';
import 'package:genui_template/explore/itinerary.dart';

class TransitRouteHandoff {
  const TransitRouteHandoff({
    required this.id,
    required this.query,
  });

  final int id;
  final String query;
}

class TransitRouteHandoffController
    extends ValueNotifier<TransitRouteHandoff?> {
  TransitRouteHandoffController() : super(null);

  int _nextId = 1;

  void routeItinerary(List<ItineraryStop> stops) {
    final query = transitRouteRequestFor(stops);
    if (query == null) return;
    value = TransitRouteHandoff(id: _nextId++, query: query);
  }
}

String? transitRouteRequestFor(List<ItineraryStop> stops) {
  if (stops.isEmpty) return null;

  final rows = <String>[];
  for (var i = 0; i < stops.length; i++) {
    rows.add(stops[i].toTransitPromptRow(i + 1));
  }

  final routeScope = stops.length == 1
      ? 'Route me to this saved itinerary stop'
      : 'Route this saved itinerary in order';

  return '$routeScope: ${rows.join('; ')}. Generate one recommended '
      'TransitJourney first, keep the stop order, and include points of '
      'interest around the saved stops or route corridor as Google-backed '
      'cards/lists.';
}
