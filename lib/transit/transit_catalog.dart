import 'dart:convert';

import 'package:bayhop/transit/transit_widgets.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

final List<CatalogItem> transitCatalogItems = [
  transitSummaryItem,
  transitJourneyItem,
  transitDeparturesItem,
  transitLiveDeparturesItem,
  transitExploreBranchItem,
  transitPlaceSearchItem,
  transitAlertItem,
  transitNoteItem,
];

final CatalogItem transitSummaryItem = CatalogItem(
  name: 'TransitSummary',
  dataSchema: S.object(
    description:
        'A compact summary for a Bay Area transit result. Use once at the top.',
    properties: {
      'intent': S.string(
        description: 'The request type.',
        enumValues: ['trip', 'departures', 'status', 'info'],
      ),
      'summary': S.string(description: 'One short plain-language answer.'),
      'sourceLabel': S.string(
        description: 'Optional small label such as live feed or planner.',
      ),
    },
    required: ['summary'],
  ),
  widgetBuilder: (context) {
    return TransitSummaryCard.fromJson(context.data as JsonMap);
  },
  exampleData: [
    () => jsonEncode([
      {
        'id': 'root',
        'component': 'TransitSummary',
        'intent': 'trip',
        'summary': 'The Red Line runs straight to SFO with no transfers.',
      },
    ]),
  ],
);

final CatalogItem transitJourneyItem = CatalogItem(
  name: 'TransitJourney',
  dataSchema: S.object(
    description:
        'A trip option card with ride, change, and walk legs. Use one to '
        'three cards for trip planning, soonest or best first.',
    properties: {
      'recommended': S.boolean(
        description: 'True for the best option. Use on one journey at most.',
      ),
      'tag': S.string(
        description: 'Short label such as Fastest, Direct, Cheapest.',
      ),
      'from': S.string(description: 'Origin station or place.'),
      'to': S.string(description: 'Destination station or place.'),
      'depart': S.string(description: 'Departure clock time, H:MM or HH:MM.'),
      'arrive': S.string(description: 'Arrival clock time, H:MM or HH:MM.'),
      'duration': S.integer(description: 'Whole trip duration in minutes.'),
      'changes': S.integer(description: 'Number of transfers.'),
      'fare': S.string(description: 'Fare amount, with or without a dollar.'),
      'crowd': S.string(
        description: 'Estimated crowding.',
        enumValues: ['Quiet', 'Some seats', 'Busy'],
      ),
      'legs': S.list(
        description: 'Ordered trip legs.',
        items: _legSchema,
        minItems: 1,
      ),
    },
    required: [
      'from',
      'to',
      'depart',
      'arrive',
      'duration',
      'changes',
      'legs',
    ],
  ),
  widgetBuilder: (context) {
    return TransitJourneyCard.fromJson(context.data as JsonMap);
  },
  exampleData: [
    () => jsonEncode([
      {
        'id': 'root',
        'component': 'TransitJourney',
        'recommended': true,
        'tag': 'Direct',
        'from': 'Downtown Berkeley',
        'to': 'SFO',
        'depart': '9:08',
        'arrive': '10:06',
        'duration': 58,
        'changes': 0,
        'fare': '11.95',
        'crowd': 'Some seats',
        'legs': [
          {
            'type': 'ride',
            'line': 'bart-red',
            'from': 'Downtown Berkeley',
            'to': 'SFO',
            'mins': 58,
            'stops': 18,
          },
        ],
      },
    ]),
  ],
);

final CatalogItem transitDeparturesItem = CatalogItem(
  name: 'TransitDepartures',
  dataSchema: S.object(
    description:
        'A departure board for planned or model-estimated train departures.',
    properties: {
      'station': S.string(description: 'Station name.'),
      'live': S.boolean(description: 'Whether these departures are live.'),
      'statusLabel': S.string(
        description: 'Optional board status chip, e.g. Expected or Planned.',
      ),
      'list': S.list(
        description: 'Departures sorted by soonest first.',
        items: _departureSchema,
        minItems: 1,
        maxItems: 8,
      ),
    },
    required: ['station', 'list'],
  ),
  widgetBuilder: (context) {
    return TransitDeparturesCard.fromJson(context.data as JsonMap);
  },
  exampleData: [
    () => jsonEncode([
      {
        'id': 'root',
        'component': 'TransitDepartures',
        'station': 'Embarcadero',
        'live': false,
        'list': [
          {
            'line': 'bart-yellow',
            'dest': 'SFO / Millbrae',
            'plat': '2',
            'mins': 2,
          },
          {
            'line': 'muni-n',
            'dest': 'Ocean Beach',
            'mins': 3,
          },
        ],
      },
    ]),
  ],
);

final CatalogItem transitLiveDeparturesItem = CatalogItem(
  name: 'TransitLiveDepartures',
  dataSchema: S.object(
    description:
        'A live departure board fetched from BART or 511 for a known stop.',
    properties: {
      'source': S.string(
        description: 'Live data source.',
        enumValues: ['bart', '511'],
      ),
      'stationName': S.string(description: 'Human-readable BART station name.'),
      'stationAbbr': S.string(
        description: 'Four-letter BART station abbreviation, e.g. EMBR.',
      ),
      'agency': S.string(
        description: '511 agency/operator id, e.g. SF, CT, AC, VT, SM, GG.',
      ),
      'agencyName': S.string(
        description: '511 agency/operator name when id is unknown.',
      ),
      'stopCode': S.string(description: '511 stop code.'),
      'stopName': S.string(
        description: 'Exact 511 stop name when stop code is unknown.',
      ),
      'lineFilter': S.string(description: 'Optional exact route or line name.'),
    },
    required: [],
  ),
  widgetBuilder: (context) {
    return LiveTransitDeparturesBoard.fromJson(context.data as JsonMap);
  },
  exampleData: [
    () => jsonEncode([
      {
        'id': 'root',
        'component': 'TransitLiveDepartures',
        'stationName': 'Embarcadero',
        'stationAbbr': 'EMBR',
      },
    ]),
    () => jsonEncode([
      {
        'id': 'root',
        'component': 'TransitLiveDepartures',
        'source': '511',
        'agency': 'SF',
        'stopCode': '15184',
      },
    ]),
  ],
);

final CatalogItem transitExploreBranchItem = CatalogItem(
  name: 'TransitExploreBranch',
  dataSchema: S.object(
    description:
        'A tappable Explore handoff tied to a route destination, transfer '
        'station, or transit corridor.',
    properties: {
      'title': S.string(description: 'Short generated branch title.'),
      'subtitle': S.string(description: 'One-line context for the branch.'),
      'badge': S.string(description: 'Small category label.'),
      'destination': S.string(
        description: 'Destination, station, or corridor the branch references.',
      ),
      'query': S.string(
        description: 'Plain-language Explore request to send after tapping.',
      ),
      'actionName': S.string(
        description: 'Action name to dispatch.',
        enumValues: ['open_explore'],
      ),
    },
    required: ['title', 'query'],
  ),
  widgetBuilder: (context) {
    return TransitExploreBranch.fromContext(context);
  },
  exampleData: [
    () => jsonEncode([
      {
        'id': 'root',
        'component': 'TransitExploreBranch',
        'title': 'Explore near SFO',
        'subtitle': 'Food, coffee, and arrival-friendly ideas',
        'badge': 'Explore',
        'destination': 'SFO',
        'query': 'Explore places near SFO after arriving by BART',
        'actionName': 'open_explore',
      },
    ]),
  ],
);

final CatalogItem transitPlaceSearchItem = CatalogItem(
  name: 'TransitPlaceSearch',
  dataSchema: S.object(
    description:
        'A Google Places-backed POI list for places near a route stop, '
        'destination, transfer, or saved itinerary area. Include a non-empty '
        'query for every search; latitude and longitude only bias the query. '
        'Coordinate-bearing results can also appear as Google Map markers.',
    properties: {
      'title': S.string(description: 'Search block title.'),
      'query': S.string(
        description:
            'Required text search query, e.g. coffee near Downtown Berkeley.',
      ),
      'includedType': S.string(
        description: 'Optional Google Places type, such as cafe or museum.',
      ),
      'latitude': S.number(description: 'Optional location bias latitude.'),
      'longitude': S.number(description: 'Optional location bias longitude.'),
      'radiusMeters': S.number(
        description: 'Optional bias/restriction radius in meters.',
      ),
      'maxResultCount': S.integer(
        description: 'Number of places to show, 1 to 8.',
      ),
    },
    required: ['title', 'query'],
  ),
  widgetBuilder: TransitPlaceSearch.fromContext,
  exampleData: [
    () => jsonEncode([
      {
        'id': 'root',
        'component': 'TransitPlaceSearch',
        'title': 'Coffee near arrival',
        'query': 'coffee near Downtown Berkeley BART',
        'includedType': 'cafe',
        'maxResultCount': 4,
      },
    ]),
  ],
);

final CatalogItem transitAlertItem = CatalogItem(
  name: 'TransitAlert',
  dataSchema: S.object(
    description: 'A service status card for a BART, Muni, or Caltrain line.',
    properties: {
      'line': S.string(description: 'Exact line id.'),
      'status': S.string(
        description: 'Service status.',
        enumValues: ['good', 'minor', 'major'],
      ),
      'detail': S.string(description: 'Short plain-language status detail.'),
      'updated': S.string(
        description: 'Optional clock time the status was last checked, H:MM.',
      ),
    },
    required: ['line', 'status'],
  ),
  widgetBuilder: (context) {
    return TransitAlertCard.fromJson(context.data as JsonMap);
  },
  exampleData: [
    () => jsonEncode([
      {
        'id': 'root',
        'component': 'TransitAlert',
        'line': 'bart-yellow',
        'status': 'minor',
        'detail': 'About 10-minute delays while trains recover.',
      },
    ]),
  ],
);

final CatalogItem transitNoteItem = CatalogItem(
  name: 'TransitNote',
  dataSchema: S.object(
    description: 'A short note for fare, transfer, or uncertainty context.',
    properties: {
      'text': S.string(description: 'Note text.'),
      'tone': S.string(
        description: 'Use warning for blocked live data or caution.',
        enumValues: ['neutral', 'warning'],
      ),
    },
    required: ['text'],
  ),
  widgetBuilder: (context) {
    return TransitNoteCard.fromJson(context.data as JsonMap);
  },
  exampleData: [
    () => jsonEncode([
      {
        'id': 'root',
        'component': 'TransitNote',
        'text':
            'Caltrain and BART charge separate fares. '
            'Tap Clipper for each leg.',
      },
    ]),
  ],
);

final Schema _legSchema = S.object(
  properties: {
    'type': S.string(enumValues: ['ride', 'change', 'walk']),
    'line': S.string(
      description:
          'Exact line id for ride legs. Omit for change and walk legs.',
    ),
    'from': S.string(description: 'Ride origin station, stop, or anchor.'),
    'to': S.string(description: 'Ride or walk destination station or anchor.'),
    'station': S.string(description: 'Transfer station for change legs.'),
    'mins': S.integer(description: 'Leg duration in minutes.'),
    'stops': S.integer(description: 'Ride stop count.'),
  },
  required: ['type', 'mins'],
);

final Schema _departureSchema = S.object(
  properties: {
    'line': S.string(description: 'Exact line id.'),
    'dest': S.string(description: 'Train destination or terminus.'),
    'plat': S.string(description: 'Optional platform.'),
    'mins': S.integer(description: 'Minutes until departure.'),
    'live': S.boolean(description: 'Whether this entry is live.'),
    'serviceTime': S.string(
      description: 'Optional ISO 8601 absolute departure or arrival time.',
    ),
    'serviceTimeKind': S.string(
      description:
          'Optional source field for serviceTime, e.g. ExpectedDepartureTime.',
    ),
    'timeStatusLabel': S.string(
      description:
          'Optional time label, e.g. Expected, Scheduled, or BART estimate.',
    ),
    'lineLabel': S.string(description: 'Optional route label from live data.'),
    'operatorName': S.string(description: 'Optional operator name.'),
    'operatorId': S.string(description: 'Optional operator id.'),
    'mode': S.string(description: 'Optional transit mode.'),
  },
  required: ['line', 'dest', 'mins'],
);

const String transitCatalogRules = '''
Prefer the custom Bay Area transit components over generic cards or text:
- Use TransitSummary once at the top of each answer.
- Use TransitJourney for trip options.
- Use TransitExploreBranch after trip routes when there is useful destination,
  transfer-station, or route-corridor exploration context.
- Use TransitPlaceSearch for points of interest around a destination, saved
  itinerary stop, transfer station, or route corridor. Always include a
  non-empty query; latitude and longitude are optional search bias only.
  Results render as cards/lists, and Google Places results with valid
  coordinates are eligible for Google Maps POI markers.
- Use TransitJourney ride legs with line "regional-bus" for bus connections.
  Walk legs are only true foot paths, not bus placeholders.
- Use TransitLiveDepartures for live BART departure requests when you know the BART abbreviation.
- Use TransitLiveDepartures with source "511" for live non-BART departures only when you know a 511 agency plus stop code, or an exact agency and stop name.
- For Muni at 4th & King, use source "511", agency "SF", and stopName "4th & King".
- Use TransitDepartures for planned estimates only when a live source cannot be resolved. Never fabricate live rows.
- Use TransitAlert for service status.
- Use TransitNote for brief extra context and warning fallbacks.
- For saved-itinerary planner-backed requests, render available segments as
  TransitJourney cards in the supplied JSON order. Copy depart, arrive,
  duration, changes, fare when present, and ordered legs exactly. Do not
  recompute arrive or duration from leg minutes.
- Render unavailable saved-itinerary segments as TransitNote cards with tone
  "warning" only. Do not estimate fallback TransitJourney timing.

Line ids must be one of: bart-yellow, bart-orange, bart-green, bart-blue,
bart-red, bart-beige, muni-j, muni-k, muni-l, muni-m, muni-n, muni-t,
caltrain, regional-bus, regional-rail, regional-ferry, regional-transit.
''';
