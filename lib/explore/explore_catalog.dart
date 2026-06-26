import 'dart:convert';

import 'package:genui/genui.dart';
import 'package:genui_template/explore/explore_widgets.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

Catalog buildExploreCatalog() =>
    BasicCatalogItems.asCatalog(
      systemPromptFragments: const [_exploreCatalogPromptRules],
    ).copyWith(
      newItems: [
        exploreSummaryItem,
        explorerOptionCardItem,
        explorePlaceSearchItem,
        exploreNoteItem,
      ],
    );

const String _exploreCatalogPromptRules = '''
Use ExploreSummary, ExplorerOptionCard, ExplorePlaceSearch, and ExploreNote
for Bay Area exploration flows. Prefer rich generated option cards with
description, distanceLabel, priceLabel, durationMinutes, category, and imagery
when those fields are useful. Use ExplorePlaceSearch for grounded venues and
POIs because the client can enrich those cards with Google photos, distance,
rating, price, and open status.
''';

final CatalogItem exploreSummaryItem = CatalogItem(
  name: 'ExploreSummary',
  dataSchema: S.object(
    description: 'A compact top summary for a Bay Area exploration response.',
    properties: {
      'title': S.string(description: 'Short heading.'),
      'summary': S.string(description: 'One short plain-language summary.'),
      'badge': S.string(description: 'Optional small label.'),
    },
    required: ['title', 'summary'],
  ),
  widgetBuilder: (context) {
    return ExploreSummaryCard.fromJson(context.data as JsonMap);
  },
  exampleData: [
    () => jsonEncode([
      {
        'id': 'root',
        'component': 'ExploreSummary',
        'title': 'San Francisco afternoon',
        'summary': 'Pick a branch and I will build around your saved stops.',
      },
    ]),
  ],
);

final CatalogItem explorerOptionCardItem = CatalogItem(
  name: 'ExplorerOptionCard',
  dataSchema: S.object(
    description:
        'A tappable generated branch for a city, neighborhood, vibe, route, '
        'or itinerary refinement.',
    properties: {
      'title': S.string(description: 'Short option title.'),
      'subtitle': S.string(description: 'One-line detail.'),
      'description': S.string(
        description:
            'One or two concise sentences explaining why this option is fun.',
      ),
      'badge': S.string(description: 'Small category label.'),
      'query': S.string(
        description: 'Plain-language request to continue this branch.',
      ),
      'actionName': S.string(
        description: 'Action name to dispatch.',
        enumValues: ['explore_option', 'explore_place', 'add_itinerary_stop'],
      ),
      'durationMinutes': S.integer(
        description: 'Optional estimated stop or branch duration.',
      ),
      'distanceLabel': S.string(
        description:
            'Optional human-readable distance, such as "0.8 km away", '
            '"15 min by BART", or "across town".',
      ),
      'priceLabel': S.string(
        description:
            'Optional estimated price label, such as Free, $, $$, or '
            r'$15-25.',
      ),
      'imageUrl': S.string(
        description:
            'Optional HTTPS image URL for a broad city, neighborhood, or vibe '
            'image. Prefer ExplorePlaceSearch for exact venue photos.',
      ),
      'imageAltText': S.string(
        description: 'Short accessibility label for imageUrl.',
      ),
      'category': S.string(description: 'Optional category.'),
    },
    required: ['title', 'query'],
  ),
  widgetBuilder: (context) {
    return ExplorerOptionCard.fromContext(context);
  },
  exampleData: [
    () => jsonEncode([
      {
        'id': 'root',
        'component': 'ExplorerOptionCard',
        'title': 'Mission food crawl',
        'subtitle': 'Tacos, murals, coffee, Dolores Park',
        'description': 'A colorful, walkable route with easy transit access.',
        'badge': 'Food',
        'priceLabel': r'$',
        'durationMinutes': 150,
        'query': 'Build a Mission food crawl',
      },
    ]),
  ],
);

final CatalogItem explorePlaceSearchItem = CatalogItem(
  name: 'ExplorePlaceSearch',
  dataSchema: S.object(
    description:
        'A Google Places-backed card list. Use for real venues and POIs. '
        'Results must stay as cards/lists, not OSM map markers.',
    properties: {
      'title': S.string(description: 'Search block title.'),
      'query': S.string(description: 'Text search query.'),
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
    required: ['title'],
  ),
  widgetBuilder: (context) {
    return ExplorePlaceSearch.fromContext(context);
  },
  exampleData: [
    () => jsonEncode([
      {
        'id': 'root',
        'component': 'ExplorePlaceSearch',
        'title': 'Coffee nearby',
        'query': 'coffee shops in the Mission San Francisco',
        'includedType': 'cafe',
        'maxResultCount': 4,
      },
    ]),
  ],
);

final CatalogItem exploreNoteItem = CatalogItem(
  name: 'ExploreNote',
  dataSchema: S.object(
    description: 'A short note for uncertainty, missing keys, or constraints.',
    properties: {
      'text': S.string(description: 'Note text.'),
      'tone': S.string(
        description: 'Use warning for blocked data or caution.',
        enumValues: ['neutral', 'warning'],
      ),
    },
    required: ['text'],
  ),
  widgetBuilder: (context) {
    return ExploreNoteCard.fromJson(context.data as JsonMap);
  },
  exampleData: [
    () => jsonEncode([
      {
        'id': 'root',
        'component': 'ExploreNote',
        'text': 'Location is unavailable, so choose a starting neighborhood.',
        'tone': 'warning',
      },
    ]),
  ],
);
