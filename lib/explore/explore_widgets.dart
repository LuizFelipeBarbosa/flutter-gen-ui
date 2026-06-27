import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/location/location_point.dart';
import 'package:genui_template/places/places.dart';
import 'package:genui_template/transit/bayhop_atoms.dart';
import 'package:genui_template/transit/bayhop_tokens.dart';

class ExploreSummaryCard extends StatelessWidget {
  const ExploreSummaryCard({
    required this.title,
    required this.summary,
    this.badge,
    super.key,
  });

  factory ExploreSummaryCard.fromJson(JsonMap json) {
    return ExploreSummaryCard(
      title: _string(json['title'], 'Explore the Bay Area'),
      summary: _string(json['summary']),
      badge: _nullableString(json['badge']),
    );
  }

  final String title;
  final String summary;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: bayHopCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BayHopAiSpark(size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: BayHopText.display(size: 19)),
              ),
              if (badge != null) BayHopChip(label: badge!),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              summary,
              style: BayHopText.body(color: BayHopColors.ink2, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class ExploreHero extends StatelessWidget {
  const ExploreHero({
    required this.title,
    required this.summary,
    required this.onAction,
    this.badges = const [],
    this.imageUrl,
    this.imageAltText,
    this.query,
    this.actionName = 'explore_option',
    super.key,
  });

  factory ExploreHero.fromContext(CatalogItemContext context) {
    final json = context.data as JsonMap;
    return ExploreHero(
      title: _string(json['title'], 'Explore the Bay Area'),
      summary: _string(json['summary']),
      badges: _stringList(json['badges']),
      imageUrl: _nullableString(json['imageUrl']),
      imageAltText: _nullableString(json['imageAltText']),
      query: _nullableString(json['query']),
      actionName: _string(json['actionName'], 'explore_option'),
      onAction: (name, actionContext) {
        context.dispatchEvent(
          UserActionEvent(
            name: name,
            sourceComponentId: context.id,
            context: actionContext,
          ),
        );
      },
    );
  }

  final String title;
  final String summary;
  final List<String> badges;
  final String? imageUrl;
  final String? imageAltText;
  final String? query;
  final String actionName;
  final void Function(String actionName, JsonMap context) onAction;

  @override
  Widget build(BuildContext context) {
    final actionQuery = query;
    final actionContext = <String, Object?>{
      'title': title,
      'summary': summary,
      'query': actionQuery,
      if (badges.isNotEmpty) 'badges': badges,
      'imageUrl': imageUrl,
    }..removeWhere((_, value) => value == null);

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: double.infinity,
        height: 260,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl == null)
              const _ExploreVisualFallback(icon: Icons.travel_explore_rounded)
            else
              Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                semanticLabel: imageAltText,
                errorBuilder: (_, _, _) {
                  return const _ExploreVisualFallback(
                    icon: Icons.travel_explore_rounded,
                  );
                },
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badges.isNotEmpty)
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final badge in badges) _OverlayChip(label: badge),
                      ],
                    ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BayHopText.display(
                      size: 26,
                      color: Colors.white,
                      height: 1.05,
                    ),
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: BayHopText.body(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.32,
                      ),
                    ),
                  ],
                  if (actionQuery != null) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => onAction(actionName, actionContext),
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Explore'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (actionQuery == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onAction(actionName, actionContext),
        child: content,
      ),
    );
  }
}

class ExploreImageMosaic extends StatelessWidget {
  const ExploreImageMosaic({
    required this.tiles,
    required this.onAction,
    this.title,
    this.summary,
    super.key,
  });

  factory ExploreImageMosaic.fromContext(CatalogItemContext context) {
    final json = context.data as JsonMap;
    return ExploreImageMosaic(
      title: _nullableString(json['title']),
      summary: _nullableString(json['summary']),
      tiles: [
        for (final item in _jsonMapList(json['images']))
          ExploreMosaicImage.fromJson(item),
      ].take(5).toList(growable: false),
      onAction: (name, actionContext) {
        context.dispatchEvent(
          UserActionEvent(
            name: name,
            sourceComponentId: context.id,
            context: actionContext,
          ),
        );
      },
    );
  }

  final String? title;
  final String? summary;
  final List<ExploreMosaicImage> tiles;
  final void Function(String actionName, JsonMap context) onAction;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: bayHopCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: BayHopText.body(size: 15, weight: FontWeight.w800),
            ),
            if (summary != null) ...[
              const SizedBox(height: 4),
              Text(
                summary!,
                style: BayHopText.body(
                  size: 12.5,
                  color: BayHopColors.muted,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final spacing = tiles.length == 2 ? 10.0 : 8.0;
              final width = constraints.maxWidth;
              final tileWidth = tiles.length == 2
                  ? (width - spacing) / 2
                  : (width - spacing) / 2;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (var index = 0; index < tiles.length; index++)
                    SizedBox(
                      width: tileWidth.clamp(132.0, width),
                      child: _MosaicTile(
                        data: tiles[index],
                        tall: index == 0 && tiles.length > 2,
                        onAction: onAction,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class ExploreMosaicImage {
  const ExploreMosaicImage({
    required this.imageUrl,
    this.title,
    this.badge,
    this.imageAltText,
    this.query,
    this.actionName = 'explore_option',
  });

  factory ExploreMosaicImage.fromJson(JsonMap json) {
    return ExploreMosaicImage(
      imageUrl: _string(json['imageUrl']),
      title: _nullableString(json['title']),
      badge: _nullableString(json['badge']),
      imageAltText: _nullableString(json['imageAltText']),
      query: _nullableString(json['query']),
      actionName: _string(json['actionName'], 'explore_option'),
    );
  }

  final String imageUrl;
  final String? title;
  final String? badge;
  final String? imageAltText;
  final String? query;
  final String actionName;

  JsonMap get actionContext {
    return {
      'title': title,
      'badge': badge,
      'query': query,
      'imageUrl': imageUrl,
    }..removeWhere((_, value) => value == null);
  }
}

class _MosaicTile extends StatelessWidget {
  const _MosaicTile({
    required this.data,
    required this.tall,
    required this.onAction,
  });

  final ExploreMosaicImage data;
  final bool tall;
  final void Function(String actionName, JsonMap context) onAction;

  @override
  Widget build(BuildContext context) {
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: tall ? 0.95 : 1.22,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              data.imageUrl,
              fit: BoxFit.cover,
              semanticLabel: data.imageAltText,
              errorBuilder: (_, _, _) {
                return const _ExploreVisualFallback(
                  icon: Icons.image_rounded,
                );
              },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.62),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data.badge != null) BayHopChip(label: data.badge!),
                  if (data.title != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      data.title!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BayHopText.body(
                        size: 13,
                        color: Colors.white,
                        weight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (data.query == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onAction(data.actionName, data.actionContext),
        child: child,
      ),
    );
  }
}

class ExploreAdventurePlan extends StatefulWidget {
  const ExploreAdventurePlan({
    required this.title,
    required this.stops,
    required this.onAction,
    this.summary = '',
    this.durationLabel,
    this.priceLabel,
    this.transitHint,
    this.addAllLabel = 'Add all',
    this.client,
    super.key,
  });

  factory ExploreAdventurePlan.fromContext(CatalogItemContext context) {
    final json = context.data as JsonMap;
    return ExploreAdventurePlan(
      title: _string(json['title'], 'One-shot adventure'),
      summary: _string(json['summary']),
      durationLabel: _nullableString(json['durationLabel']),
      priceLabel: _nullableString(json['priceLabel']),
      transitHint: _nullableString(json['transitHint']),
      addAllLabel: _string(json['addAllLabel'], 'Add all'),
      stops: [
        for (final item in _jsonMapList(json['stops']))
          ExploreAdventureStop.fromJson(item),
      ].take(5).toList(growable: false),
      onAction: (name, actionContext) {
        context.dispatchEvent(
          UserActionEvent(
            name: name,
            sourceComponentId: context.id,
            context: actionContext,
          ),
        );
      },
    );
  }

  final String title;
  final String summary;
  final String? durationLabel;
  final String? priceLabel;
  final String? transitHint;
  final String addAllLabel;
  final List<ExploreAdventureStop> stops;
  final GooglePlacesClient? client;
  final void Function(String actionName, JsonMap context) onAction;

  @override
  State<ExploreAdventurePlan> createState() => _ExploreAdventurePlanState();
}

class _ExploreAdventurePlanState extends State<ExploreAdventurePlan> {
  late final GooglePlacesClient _client = widget.client ?? GooglePlacesClient();
  final Map<int, _AdventurePlaceEnrichment> _enrichments = {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadEnrichments());
  }

  @override
  void didUpdateWidget(covariant ExploreAdventurePlan oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_adventureKey(oldWidget.stops) != _adventureKey(widget.stops)) {
      _enrichments.clear();
      unawaited(_loadEnrichments());
    }
  }

  @override
  void dispose() {
    if (widget.client == null) _client.close();
    super.dispose();
  }

  Future<void> _loadEnrichments() async {
    final key = _adventureKey(widget.stops);
    for (var index = 0; index < widget.stops.length; index++) {
      final stop = widget.stops[index];
      final query = stop.placeQuery ?? stop.title;
      if (query.trim().isEmpty) continue;

      try {
        final results = await _client.searchText(
          query: query,
          maxResultCount: 1,
          regionCode: 'US',
        );
        if (!mounted || _adventureKey(widget.stops) != key) return;
        if (results.isEmpty) continue;

        final place = results.first;
        setState(() {
          _enrichments[index] = _AdventurePlaceEnrichment(
            place: place,
            photoUri: _photoUriFor(place),
          );
        });
      } on Object {
        if (!mounted || _adventureKey(widget.stops) != key) return;
      }
    }
  }

  Uri? _photoUriFor(PlaceResult place) {
    final photo = place.primaryPhoto;
    if (photo == null) return null;

    return _client.photoMediaUri(photo);
  }

  @override
  Widget build(BuildContext context) {
    final labels = [
      ?widget.durationLabel,
      ?widget.priceLabel,
      ?widget.transitHint,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: bayHopCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BayHopAiSpark(size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: BayHopText.display(size: 19, height: 1.1),
                    ),
                    if (widget.summary.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        widget.summary,
                        style: BayHopText.body(
                          color: BayHopColors.ink2,
                          height: 1.34,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (labels.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [for (final label in labels) BayHopChip(label: label)],
            ),
          ],
          const SizedBox(height: 14),
          for (var index = 0; index < widget.stops.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == widget.stops.length - 1 ? 0 : 10,
              ),
              child: _AdventureStopTile(
                stop: widget.stops[index],
                enrichment: _enrichments[index],
                index: index,
                onExplore: () => widget.onAction(
                  'explore_place',
                  _enrichedActionContext(index),
                ),
                onAdd: () => widget.onAction(
                  'add_itinerary_stop',
                  _enrichedActionContext(index),
                ),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.stops.isEmpty
                  ? null
                  : () => widget.onAction(
                      'add_itinerary_stops',
                      {
                        'title': widget.title,
                        'stops': [
                          for (
                            var index = 0;
                            index < widget.stops.length;
                            index++
                          )
                            _enrichedActionContext(index),
                        ],
                      },
                    ),
              icon: const Icon(Icons.playlist_add_check_rounded),
              label: Text(widget.addAllLabel),
            ),
          ),
        ],
      ),
    );
  }

  JsonMap _enrichedActionContext(int index) {
    final enrichment = _enrichments[index];
    if (enrichment == null) return widget.stops[index].toActionContext();

    return {
      ...widget.stops[index].toActionContext(),
      ...enrichment.place.toJson(),
      'title': enrichment.place.displayName,
      'address': enrichment.place.formattedAddress,
      'category':
          _placeCategory(enrichment.place) ?? widget.stops[index].category,
    }..removeWhere((_, value) => value == null);
  }

  String? _placeCategory(PlaceResult place) {
    if (place.types.isEmpty) return null;
    return _typeLabel(place.types.first);
  }
}

class ExploreAdventureStop {
  const ExploreAdventureStop({
    required this.title,
    this.description = '',
    this.address,
    this.category,
    this.durationMinutes,
    this.priceLabel,
    this.transitHint,
    this.notes,
    this.placeId,
    this.placeQuery,
    this.latitude,
    this.longitude,
    this.googleMapsUri,
    this.imageUrl,
    this.imageAltText,
  });

  factory ExploreAdventureStop.fromJson(JsonMap json) {
    return ExploreAdventureStop(
      title: _string(json['title'], 'Stop'),
      description: _string(json['description']),
      address: _nullableString(json['address']),
      category: _nullableString(json['category']),
      durationMinutes: _nullableInt(json['durationMinutes']),
      priceLabel: _nullableString(json['priceLabel']),
      transitHint: _nullableString(json['transitHint']),
      notes: _nullableString(json['notes']),
      placeId: _nullableString(json['placeId']),
      placeQuery:
          _nullableString(json['placeQuery']) ?? _nullableString(json['query']),
      latitude: _nullableDouble(json['latitude']),
      longitude: _nullableDouble(json['longitude']),
      googleMapsUri: _nullableUri(json['googleMapsUri']),
      imageUrl: _nullableString(json['imageUrl']),
      imageAltText: _nullableString(json['imageAltText']),
    );
  }

  final String title;
  final String description;
  final String? address;
  final String? category;
  final int? durationMinutes;
  final String? priceLabel;
  final String? transitHint;
  final String? notes;
  final String? placeId;
  final String? placeQuery;
  final double? latitude;
  final double? longitude;
  final Uri? googleMapsUri;
  final String? imageUrl;
  final String? imageAltText;

  JsonMap toActionContext() {
    return {
      'placeId': placeId,
      'title': title,
      'address': address,
      'category': category,
      'durationMinutes': durationMinutes,
      'latitude': latitude,
      'longitude': longitude,
      'googleMapsUri': googleMapsUri?.toString(),
      'notes': notes ?? description,
    }..removeWhere((_, value) => value == null);
  }
}

class _AdventurePlaceEnrichment {
  const _AdventurePlaceEnrichment({
    required this.place,
    this.photoUri,
  });

  final PlaceResult place;
  final Uri? photoUri;
}

class _AdventureStopTile extends StatelessWidget {
  const _AdventureStopTile({
    required this.stop,
    required this.index,
    required this.onExplore,
    required this.onAdd,
    this.enrichment,
  });

  final ExploreAdventureStop stop;
  final int index;
  final VoidCallback onExplore;
  final VoidCallback onAdd;
  final _AdventurePlaceEnrichment? enrichment;

  @override
  Widget build(BuildContext context) {
    final place = enrichment?.place;
    final title = place?.displayName ?? stop.title;
    final address = place?.formattedAddress ?? stop.address;
    final labels = [
      ?stop.category,
      ?stop.priceLabel,
      if (stop.durationMinutes != null) '${stop.durationMinutes} min',
      ?stop.transitHint,
    ];
    final photoUri = enrichment?.photoUri;
    final imageUrl = stop.imageUrl;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BayHopColors.bgTop,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BayHopColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AdventureStopVisual(
            index: index,
            photoUri: photoUri,
            imageUrl: imageUrl,
            imageAltText: stop.imageAltText,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onExplore,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BayHopText.body(weight: FontWeight.w800),
                    ),
                    if (address != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: BayHopText.body(
                          size: 12,
                          color: BayHopColors.muted,
                          height: 1.22,
                        ),
                      ),
                    ] else if (stop.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        stop.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: BayHopText.body(
                          size: 12,
                          color: BayHopColors.muted,
                          height: 1.22,
                        ),
                      ),
                    ],
                    if (labels.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final label in labels) BayHopChip(label: label),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Add stop',
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _AdventureStopVisual extends StatelessWidget {
  const _AdventureStopVisual({
    required this.index,
    this.photoUri,
    this.imageUrl,
    this.imageAltText,
  });

  final int index;
  final Uri? photoUri;
  final String? imageUrl;
  final String? imageAltText;

  @override
  Widget build(BuildContext context) {
    final networkImage = photoUri?.toString() ?? imageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 70,
        height: 70,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (networkImage == null)
              const _ExploreVisualFallback(icon: Icons.place_rounded)
            else
              Image.network(
                networkImage,
                fit: BoxFit.cover,
                semanticLabel: imageAltText,
                errorBuilder: (_, _, _) {
                  return const _ExploreVisualFallback(
                    icon: Icons.place_rounded,
                  );
                },
              ),
            Align(
              alignment: Alignment.topLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: BayHopText.mono(
                      color: Colors.white,
                      weight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExplorerOptionCard extends StatelessWidget {
  const ExplorerOptionCard({
    required this.title,
    required this.query,
    required this.onAction,
    this.subtitle = '',
    this.description = '',
    this.badge,
    this.actionName = 'explore_option',
    this.category,
    this.durationMinutes,
    this.distanceLabel,
    this.priceLabel,
    this.imageUrl,
    this.imageAltText,
    super.key,
  });

  factory ExplorerOptionCard.fromContext(CatalogItemContext context) {
    final json = context.data as JsonMap;
    return ExplorerOptionCard(
      title: _string(json['title'], 'Explore option'),
      subtitle: _string(json['subtitle']),
      description: _string(json['description']),
      badge: _nullableString(json['badge']),
      query: _string(json['query']),
      actionName: _string(json['actionName'], 'explore_option'),
      category: _nullableString(json['category']),
      durationMinutes: _nullableInt(json['durationMinutes']),
      distanceLabel: _nullableString(json['distanceLabel']),
      priceLabel: _nullableString(json['priceLabel']),
      imageUrl: _nullableString(json['imageUrl']),
      imageAltText: _nullableString(json['imageAltText']),
      onAction: (name, actionContext) {
        context.dispatchEvent(
          UserActionEvent(
            name: name,
            sourceComponentId: context.id,
            context: actionContext,
          ),
        );
      },
    );
  }

  final String title;
  final String subtitle;
  final String description;
  final String? badge;
  final String query;
  final String actionName;
  final String? category;
  final int? durationMinutes;
  final String? distanceLabel;
  final String? priceLabel;
  final String? imageUrl;
  final String? imageAltText;
  final void Function(String actionName, JsonMap context) onAction;

  @override
  Widget build(BuildContext context) {
    final durationLabel = switch (durationMinutes) {
      final minutes? when minutes > 0 => '$minutes min',
      _ => null,
    };
    final details = [
      ?distanceLabel,
      ?priceLabel,
      ?durationLabel,
    ];
    final actionContext = <String, Object?>{
      'title': title,
      'query': query,
      'description': description.isEmpty ? null : description,
      'category': category ?? badge,
      'durationMinutes': durationMinutes,
      'distanceLabel': distanceLabel,
      'priceLabel': priceLabel,
      'imageUrl': imageUrl,
    }..removeWhere((_, value) => value == null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onAction(actionName, actionContext),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: bayHopCardDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExplorerOptionVisual(
                imageUrl: imageUrl,
                imageAltText: imageAltText,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BayHopText.body(
                              size: 15,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          BayHopChip(label: badge!),
                        ],
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: BayHopText.body(
                          size: 12.5,
                          color: BayHopColors.muted,
                          height: 1.25,
                        ),
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: BayHopText.body(
                          size: 12.5,
                          color: BayHopColors.ink2,
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final label in details) BayHopChip(label: label),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: BayHopColors.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExplorerOptionVisual extends StatelessWidget {
  const _ExplorerOptionVisual({
    required this.imageUrl,
    required this.imageAltText,
  });

  final String? imageUrl;
  final String? imageAltText;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 74,
        height: 74,
        child: url == null
            ? const _ExploreVisualFallback(icon: Icons.explore_rounded)
            : Image.network(
                url,
                fit: BoxFit.cover,
                semanticLabel: imageAltText,
                errorBuilder: (_, _, _) {
                  return const _ExploreVisualFallback(
                    icon: Icons.explore_rounded,
                  );
                },
              ),
      ),
    );
  }
}

class _ExploreVisualFallback extends StatelessWidget {
  const _ExploreVisualFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: BayHopColors.aiGradient),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

enum ExplorePlaceSearchLayout { list, carousel, mosaic }

class ExplorePlaceSearch extends StatefulWidget {
  const ExplorePlaceSearch({
    required this.title,
    required this.onAction,
    this.query = '',
    this.layout = ExplorePlaceSearchLayout.list,
    this.includedType,
    this.latitude,
    this.longitude,
    this.radiusMeters,
    this.maxResultCount = 4,
    this.client,
    super.key,
  });

  factory ExplorePlaceSearch.fromContext(CatalogItemContext context) {
    final json = context.data as JsonMap;
    return ExplorePlaceSearch(
      title: _string(json['title'], 'Places'),
      query: _string(json['query']),
      layout: _placeSearchLayout(json['layout']),
      includedType: _nullableString(json['includedType']),
      latitude: _nullableDouble(json['latitude']),
      longitude: _nullableDouble(json['longitude']),
      radiusMeters: _nullableDouble(json['radiusMeters']),
      maxResultCount: _int(json['maxResultCount'], fallback: 4).clamp(1, 8),
      onAction: (name, actionContext) {
        context.dispatchEvent(
          UserActionEvent(
            name: name,
            sourceComponentId: context.id,
            context: actionContext,
          ),
        );
      },
    );
  }

  final String title;
  final String query;
  final ExplorePlaceSearchLayout layout;
  final String? includedType;
  final double? latitude;
  final double? longitude;
  final double? radiusMeters;
  final int maxResultCount;
  final GooglePlacesClient? client;
  final void Function(String actionName, JsonMap context) onAction;

  @override
  State<ExplorePlaceSearch> createState() => _ExplorePlaceSearchState();
}

class _ExplorePlaceSearchState extends State<ExplorePlaceSearch> {
  late final GooglePlacesClient _client = widget.client ?? GooglePlacesClient();
  List<PlaceResult> _results = const [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ExplorePlaceSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_searchKey(oldWidget) != _searchKey(widget)) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    if (widget.client == null) _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    final key = _searchKey(widget);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await _search();
      if (!mounted || _searchKey(widget) != key) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || _searchKey(widget) != key) return;
      setState(() {
        _error = error;
        _results = const [];
        _loading = false;
      });
    }
  }

  Future<List<PlaceResult>> _search() {
    final hasPoint = widget.latitude != null && widget.longitude != null;
    final radius = widget.radiusMeters ?? 1600;

    if (widget.query.trim().isNotEmpty) {
      return _client.searchText(
        query: widget.query,
        maxResultCount: widget.maxResultCount,
        includedType: widget.includedType,
        regionCode: 'US',
        locationBias: hasPoint
            ? PlaceSearchCircle(
                latitude: widget.latitude!,
                longitude: widget.longitude!,
                radiusMeters: radius,
              )
            : null,
      );
    }

    if (hasPoint) {
      return _client.searchNearby(
        latitude: widget.latitude!,
        longitude: widget.longitude!,
        radiusMeters: radius,
        maxResultCount: widget.maxResultCount,
        rankPreference: NearbyRankPreference.distance,
        regionCode: 'US',
        includedTypes: [
          ?widget.includedType,
        ],
      );
    }

    throw const PlacesException('A place query or location is required');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: bayHopCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.place_rounded,
                size: 18,
                color: BayHopColors.aiBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: BayHopText.body(size: 15, weight: FontWeight.w800),
                ),
              ),
              Text(
                'Google',
                style: BayHopText.body(
                  size: 11,
                  weight: FontWeight.w700,
                  color: BayHopColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            const _PlacesLoadingRows()
          else if (_error != null)
            ExploreNoteCard(
              text: _error.toString(),
              tone: ExploreNoteTone.warning,
            )
          else if (_results.isEmpty)
            const ExploreNoteCard(text: 'No places found for this search.')
          else
            _PlaceResultsView(
              layout: widget.layout,
              results: _results,
              distanceLabelFor: _distanceLabelFor,
              photoUriFor: _photoUriFor,
              onExplore: (result) => widget.onAction(
                'explore_place',
                result.toJson(),
              ),
              onAdd: (result) => widget.onAction(
                'add_itinerary_stop',
                result.toJson(),
              ),
            ),
          Text(
            'Places data from Google. Results are shown as cards only.',
            style: BayHopText.body(size: 10.5, color: BayHopColors.faint),
          ),
        ],
      ),
    );
  }

  String? _distanceLabelFor(PlaceResult place) {
    final origin = _origin;
    if (origin == null || place.latitude == null || place.longitude == null) {
      return null;
    }

    final destination = LocationCoordinate(
      latitude: place.latitude!,
      longitude: place.longitude!,
    );
    return '${formatDistanceMeters(origin.distanceTo(destination))} away';
  }

  Uri? _photoUriFor(PlaceResult place) {
    final photo = place.primaryPhoto;
    if (photo == null) return null;

    return _client.photoMediaUri(photo);
  }

  LocationCoordinate? get _origin {
    if (widget.latitude == null || widget.longitude == null) return null;

    return LocationCoordinate(
      latitude: widget.latitude!,
      longitude: widget.longitude!,
    );
  }
}

class _PlaceResultsView extends StatelessWidget {
  const _PlaceResultsView({
    required this.layout,
    required this.results,
    required this.distanceLabelFor,
    required this.photoUriFor,
    required this.onExplore,
    required this.onAdd,
  });

  final ExplorePlaceSearchLayout layout;
  final List<PlaceResult> results;
  final String? Function(PlaceResult result) distanceLabelFor;
  final Uri? Function(PlaceResult result) photoUriFor;
  final ValueChanged<PlaceResult> onExplore;
  final ValueChanged<PlaceResult> onAdd;

  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      ExplorePlaceSearchLayout.carousel => SizedBox(
        height: 178,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            return SizedBox(width: 292, child: _cardFor(results[index]));
          },
        ),
      ),
      ExplorePlaceSearchLayout.mosaic => LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0;
          final width = ((constraints.maxWidth - spacing) / 2).clamp(
            148.0,
            constraints.maxWidth,
          );

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final result in results)
                SizedBox(width: width, child: _cardFor(result)),
            ],
          );
        },
      ),
      ExplorePlaceSearchLayout.list => Column(
        children: [
          for (final result in results)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _cardFor(result),
            ),
        ],
      ),
    };
  }

  Widget _cardFor(PlaceResult result) {
    return _PlaceResultCard(
      place: result,
      distanceLabel: distanceLabelFor(result),
      photoUri: photoUriFor(result),
      onExplore: () => onExplore(result),
      onAdd: () => onAdd(result),
    );
  }
}

class _PlaceResultCard extends StatelessWidget {
  const _PlaceResultCard({
    required this.place,
    required this.onExplore,
    required this.onAdd,
    this.distanceLabel,
    this.photoUri,
  });

  final PlaceResult place;
  final VoidCallback onExplore;
  final VoidCallback onAdd;
  final String? distanceLabel;
  final Uri? photoUri;

  @override
  Widget build(BuildContext context) {
    final card = place.toCardData();
    final labels = [
      ?distanceLabel,
      ...card.metadata,
      ...card.tags,
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF76808A).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BayHopColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (photoUri != null) ...[
                _PlacePhotoThumbnail(
                  uri: photoUri!,
                  attributionLabel: card.photoAttributionLabel,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onExplore,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BayHopText.body(weight: FontWeight.w800),
                        ),
                        if (card.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            card.subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: BayHopText.body(
                              size: 12,
                              color: BayHopColors.muted,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Add to itinerary',
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (labels.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final label in labels) BayHopChip(label: label),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PlacePhotoThumbnail extends StatelessWidget {
  const _PlacePhotoThumbnail({
    required this.uri,
    required this.attributionLabel,
  });

  final Uri uri;
  final String? attributionLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 82,
        height: 82,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              uri.toString(),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return const _ExploreVisualFallback(icon: Icons.place_rounded);
              },
            ),
            if (attributionLabel != null)
              Align(
                alignment: Alignment.bottomLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.56),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      'Photo: $attributionLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BayHopText.body(
                        size: 8.5,
                        color: Colors.white,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum ExploreNoteTone { neutral, warning }

class ExploreNoteCard extends StatelessWidget {
  const ExploreNoteCard({
    required this.text,
    this.tone = ExploreNoteTone.neutral,
    super.key,
  });

  factory ExploreNoteCard.fromJson(JsonMap json) {
    return ExploreNoteCard(
      text: _string(json['text']),
      tone: _string(json['tone']) == 'warning'
          ? ExploreNoteTone.warning
          : ExploreNoteTone.neutral,
    );
  }

  final String text;
  final ExploreNoteTone tone;

  @override
  Widget build(BuildContext context) {
    final warning = tone == ExploreNoteTone.warning;
    final color = warning ? BayHopColors.warn : BayHopColors.aiBlue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: BayHopText.body(
                size: 12.5,
                color: warning ? BayHopColors.warnText : BayHopColors.ink2,
                height: 1.35,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlacesLoadingRows extends StatelessWidget {
  const _PlacesLoadingRows();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        BayHopSkeletonBar(width: double.infinity, height: 54, radius: 12),
        SizedBox(height: 8),
        BayHopSkeletonBar(width: double.infinity, height: 54, radius: 12),
      ],
    );
  }
}

class _OverlayChip extends StatelessWidget {
  const _OverlayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: BayHopText.body(
          size: 11.5,
          weight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

String _searchKey(ExplorePlaceSearch widget) {
  return [
    widget.title,
    widget.query,
    widget.layout.name,
    widget.includedType,
    widget.latitude,
    widget.longitude,
    widget.radiusMeters,
    widget.maxResultCount,
  ].join('|');
}

String _adventureKey(List<ExploreAdventureStop> stops) {
  return stops
      .map((stop) => '${stop.title}|${stop.placeQuery}|${stop.placeId}')
      .join(';;');
}

String _string(Object? value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  final text = _string(value);
  return text.isEmpty ? null : text;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value) ?_nullableString(item),
  ];
}

List<JsonMap> _jsonMapList(Object? value) {
  if (value is! List) return const [];

  return [
    for (final item in value)
      if (item is Map)
        item.map((key, value) => MapEntry(key.toString(), value)),
  ];
}

int _int(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  return _int(value, fallback: 0);
}

double? _nullableDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

Uri? _nullableUri(Object? value) {
  final text = _nullableString(value);
  if (text == null) return null;
  return Uri.tryParse(text);
}

ExplorePlaceSearchLayout _placeSearchLayout(Object? value) {
  return switch (_nullableString(value)) {
    'carousel' => ExplorePlaceSearchLayout.carousel,
    'mosaic' => ExplorePlaceSearchLayout.mosaic,
    _ => ExplorePlaceSearchLayout.list,
  };
}

String _typeLabel(String type) {
  final words = type
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}');
  return words.join(' ');
}
