import 'dart:convert';

import 'package:genui/genui.dart';
import 'package:genui_template/explore/explore_widgets.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

Catalog buildExploreCatalog() =>
    BasicCatalogItems.asCatalog(
      systemPromptFragments: const [_exploreCatalogPromptRules],
    ).copyWith(
      newItems: [
        exploreHeroItem,
        exploreSummaryItem,
        exploreImageMosaicItem,
        exploreAdventurePlanItem,
        explorerOptionCardItem,
        explorePlaceSearchItem,
        exploreNoteItem,
      ],
    );

const String _exploreCatalogPromptRules = '''
Use ExploreHero, ExploreSummary, ExploreImageMosaic, ExploreAdventurePlan,
ExplorerOptionCard, ExplorePlaceSearch, and ExploreNote for Bay Area
exploration flows. Prefer image-rich modular surfaces: creative bento mosaics
for broad visual branching, option cards for refinements, ExploreAdventurePlan
for one-shot ordered previews, and Google Places-backed ExplorePlaceSearch for
grounded venues and POIs because the client can enrich those cards with Google
photos, distance, rating, price, and open status. Treat imageUrl as a rare
optional field for broad non-venue inspiration only; omit it by default. Never
use Unsplash, Pexels, Pixabay, example, placeholder, lorem, picsum, stock, or
invented image URLs. Use ExploreHero.placeQuery when the header should depict
a specific venue, landmark, park, neighborhood anchor, or representative exact
place through Google Places photos. Use ExploreImageMosaic images[].placeQuery
when a bento tile should show an actual venue, landmark, park, neighborhood
anchor, or representative exact place. Use ExplorerOptionCard.placeQuery when
a follow-up branch card should show a representative actual place. Never emit
imageUrl for exact venues. Never auto-save stops; use add actions only when the
user taps.
''';

final CatalogItem exploreHeroItem = CatalogItem(
  name: 'ExploreHero',
  dataSchema: S.object(
    description:
        'A large image-forward intro for a Bay Area exploration branch.',
    properties: {
      'title': S.string(description: 'Short hero heading.'),
      'summary': S.string(description: 'One or two concise sentences.'),
      'badges': S.list(
        description: 'Optional compact labels.',
        items: S.string(),
        maxItems: 4,
      ),
      'imageUrl': S.string(
        description:
            'Rare optional HTTPS URL for broad non-venue inspiration only. '
            'Omit by default. Never use for exact venues, named POIs, '
            'Unsplash, Pexels, Pixabay, example, placeholder, lorem, picsum, '
            'stock, or invented URLs.',
      ),
      'imageAltText': S.string(description: 'Short image accessibility label.'),
      'placeQuery': S.string(
        description:
            'Optional Google Places text query for a specific header photo. '
            'Use for exact venues, landmarks, parks, neighborhood anchors, or '
            'a representative exact place. Prefer this over imageUrl whenever '
            'the hero should show an actual place.',
      ),
      'query': S.string(
        description:
            'Optional follow-up query when the hero itself is tappable.',
      ),
      'actionName': S.string(
        description: 'Action name to dispatch.',
        enumValues: ['explore_option', 'explore_place'],
      ),
    },
    required: ['title', 'summary'],
  ),
  widgetBuilder: (context) {
    return ExploreHero.fromContext(context);
  },
  exampleData: [
    () => jsonEncode([
      {
        'id': 'root',
        'component': 'ExploreHero',
        'title': 'Ferry, food, and a view',
        'summary':
            'A waterfront-first adventure with a flexible snack stop and an '
            'easy sunset branch.',
        'badges': ['Views', 'Food', 'Transit-friendly'],
        'placeQuery': 'Ferry Building San Francisco',
        'query': 'Build a waterfront snack and views adventure',
      },
    ]),
  ],
);

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

final CatalogItem exploreImageMosaicItem = CatalogItem(
  name: 'ExploreImageMosaic',
  dataSchema: S.object(
    description:
        'A two-to-five tile visual browser for broad inspiration or grounded '
        'place branches.',
    properties: {
      'title': S.string(description: 'Optional block title.'),
      'summary': S.string(description: 'Optional short block summary.'),
      'images': S.list(
        description:
            'Bento tiles for broad city, neighborhood, vibe, or actual-place '
            'branching.',
        items: _mosaicImageSchema,
        minItems: 2,
        maxItems: 5,
      ),
    },
    required: ['images'],
  ),
  widgetBuilder: (context) {
    return ExploreImageMosaic.fromContext(context);
  },
  exampleData: [
    () => jsonEncode([
      {
        'id': 'root',
        'component': 'ExploreImageMosaic',
        'title': 'Pick a vibe',
        'images': [
          {
            'title': 'Hilltop reward',
            'badge': 'Views',
            'placeQuery': 'Twin Peaks San Francisco',
            'query': 'Find a transit-friendly hilltop view',
          },
          {
            'title': 'Snack crawl',
            'badge': 'Food',
            'placeQuery': 'Ferry Building San Francisco',
            'query': 'Build a snack crawl nearby',
          },
        ],
      },
    ]),
  ],
);

final CatalogItem exploreAdventurePlanItem = CatalogItem(
  name: 'ExploreAdventurePlan',
  dataSchema: S.object(
    description:
        'A one-shot ordered adventure preview with three to five concrete '
        'stops and an Add all action. Use for complete-adventure requests.',
    properties: {
      'title': S.string(description: 'Adventure title.'),
      'summary': S.string(description: 'Short plan overview.'),
      'durationLabel': S.string(description: 'Total duration hint.'),
      'priceLabel': S.string(description: r'Estimated total price, e.g. $$.'),
      'transitHint': S.string(description: 'Transit or walking hint.'),
      'addAllLabel': S.string(description: 'Bulk add button label.'),
      'stops': S.list(
        description: 'Ordered concrete stops to preview before saving.',
        items: _adventureStopSchema,
        minItems: 3,
        maxItems: 5,
      ),
    },
    required: ['title', 'summary', 'stops'],
  ),
  widgetBuilder: (context) {
    return ExploreAdventurePlan.fromContext(context);
  },
  exampleData: [
    () => jsonEncode([
      {
        'id': 'root',
        'component': 'ExploreAdventurePlan',
        'title': 'One-shot Oakland afternoon',
        'summary':
            'Coffee, lake air, a museum stop, and an easy dinner finish.',
        'durationLabel': '3h 30m',
        'priceLabel': r'$-$$',
        'transitHint': 'BART + walking',
        'stops': [
          {
            'title': 'Awaken Cafe',
            'placeQuery': 'Awaken Cafe Oakland',
            'category': 'Coffee',
            'durationMinutes': 35,
          },
          {
            'title': 'Lake Merritt',
            'placeQuery': 'Lake Merritt Oakland',
            'category': 'Outdoors',
            'durationMinutes': 60,
          },
          {
            'title': 'Oakland Museum of California',
            'placeQuery': 'Oakland Museum of California',
            'category': 'Culture',
            'durationMinutes': 90,
          },
        ],
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
            r'Optional estimated price label, such as Free, $, $$, or $15-25.',
      ),
      'imageUrl': S.string(
        description:
            'Rare optional HTTPS image URL for broad city, neighborhood, or '
            'vibe inspiration only. Omit by default. Prefer '
            'placeQuery or ExplorePlaceSearch for actual place photos. Never '
            'use when placeQuery is present. Never use Unsplash, Pexels, '
            'Pixabay, example, placeholder, lorem, picsum, stock, or invented '
            'URLs.',
      ),
      'imageAltText': S.string(
        description: 'Short accessibility label for imageUrl.',
      ),
      'placeQuery': S.string(
        description:
            'Optional Google Places text query for an actual representative '
            'photo on this branch card. Keep query as the follow-up action '
            'request. Prefer this over imageUrl when the option should show a '
            'real place.',
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
        'placeQuery': 'Mission Dolores Park San Francisco',
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
        'Coordinate-bearing results can also appear as Google Map markers.',
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
      'layout': S.string(
        description: 'Visual result layout. Default is list.',
        enumValues: ['list', 'carousel', 'mosaic'],
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
        'layout': 'carousel',
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

final Schema _mosaicImageSchema = S.object(
  properties: {
    'imageUrl': S.string(
      description:
          'Rare optional HTTPS image URL for broad non-venue inspiration only. '
          'Omit by default. Never use when placeQuery is present, and never '
          'use stock, placeholder, or invented URLs.',
    ),
    'title': S.string(description: 'Optional tile title.'),
    'badge': S.string(description: 'Optional tile label.'),
    'imageAltText': S.string(description: 'Short image accessibility label.'),
    'placeQuery': S.string(
      description:
          'Optional Google Places text query for an actual tile photo. Use for '
          'exact venues, landmarks, parks, neighborhood anchors, or a '
          'representative exact place. Prefer over imageUrl whenever the tile '
          'should show a real place.',
    ),
    'query': S.string(description: 'Optional follow-up query.'),
    'actionName': S.string(
      description: 'Action name to dispatch.',
      enumValues: ['explore_option', 'explore_place'],
    ),
  },
  required: ['title', 'query'],
);

final Schema _adventureStopSchema = S.object(
  properties: {
    'title': S.string(description: 'Concrete stop name.'),
    'description': S.string(description: 'Short preview note.'),
    'address': S.string(description: 'Optional address when known.'),
    'category': S.string(description: 'Stop category.'),
    'durationMinutes': S.integer(description: 'Estimated stop duration.'),
    'priceLabel': S.string(description: 'Optional stop price hint.'),
    'transitHint': S.string(description: 'Optional transit or walk hint.'),
    'notes': S.string(description: 'Optional itinerary note.'),
    'placeId': S.string(description: 'Optional Google place id when known.'),
    'placeQuery': S.string(
      description: 'Google Places text query for this exact stop.',
    ),
    'latitude': S.number(description: 'Optional latitude when known.'),
    'longitude': S.number(description: 'Optional longitude when known.'),
    'googleMapsUri': S.string(description: 'Optional Google Maps URI.'),
    'imageUrl': S.string(
      description:
          'Do not use for exact venues. Prefer placeQuery/placeId so Google '
          'Places photos can be used; omit imageUrl when photos are '
          'unavailable.',
    ),
    'imageAltText': S.string(description: 'Short image accessibility label.'),
  },
  required: ['title'],
);
