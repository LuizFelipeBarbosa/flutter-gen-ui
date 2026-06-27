import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/explore/explore_image_resolver.dart';
import 'package:genui_template/location/location_point.dart';
import 'package:genui_template/location/map_place_overlay.dart';
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

class ExploreHero extends StatefulWidget {
  const ExploreHero({
    required this.title,
    required this.summary,
    required this.onAction,
    this.badges = const [],
    this.imageUrl,
    this.imageAltText,
    this.placeQuery,
    this.query,
    this.actionName = 'explore_option',
    this.client,
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
      placeQuery: _nullableString(json['placeQuery']),
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
  final String? placeQuery;
  final String? query;
  final String actionName;
  final GooglePlacesClient? client;
  final void Function(String actionName, JsonMap context) onAction;

  @override
  State<ExploreHero> createState() => _ExploreHeroState();
}

class _ExploreHeroState extends State<ExploreHero> {
  late final GooglePlacesClient _client = widget.client ?? GooglePlacesClient();
  _HeroPlaceEnrichment? _enrichment;

  @override
  void initState() {
    super.initState();
    unawaited(_loadEnrichment());
  }

  @override
  void didUpdateWidget(covariant ExploreHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeQuery != widget.placeQuery) {
      _enrichment = null;
      unawaited(_loadEnrichment());
    }
  }

  @override
  void dispose() {
    if (widget.client == null) _client.close();
    super.dispose();
  }

  Future<void> _loadEnrichment() async {
    final placeQuery = widget.placeQuery?.trim();
    if (placeQuery == null || placeQuery.isEmpty) return;

    try {
      final results = await _client.searchText(
        query: placeQuery,
        maxResultCount: 1,
        regionCode: 'US',
      );
      if (!mounted || widget.placeQuery?.trim() != placeQuery) return;
      if (results.isEmpty) return;

      final place = results.first;
      setState(() {
        _enrichment = _HeroPlaceEnrichment(
          place: place,
          photoUri: _photoUriFor(place),
        );
      });
    } on Object {
      if (!mounted || widget.placeQuery?.trim() != placeQuery) return;
    }
  }

  Uri? _photoUriFor(PlaceResult place) {
    final photo = place.primaryPhoto;
    if (photo == null) return null;

    return _client.photoMediaUri(photo, maxWidthPx: 1200, maxHeightPx: 720);
  }

  @override
  Widget build(BuildContext context) {
    final actionQuery = widget.query;
    final placeQuery = widget.placeQuery;
    final heroImageUrl = placeQuery == null
        ? widget.imageUrl
        : _enrichment?.photoUri?.toString();
    final fallbackImageUrl = _fallbackImageUrlFor([
      widget.title,
      widget.summary,
      ...widget.badges,
    ]);
    final actionContext = <String, Object?>{
      'title': _enrichment?.place.displayName ?? widget.title,
      'summary': widget.summary,
      'query': actionQuery,
      'placeQuery': placeQuery,
      if (widget.badges.isNotEmpty) 'badges': widget.badges,
      if (placeQuery == null) 'imageUrl': widget.imageUrl,
      if (_enrichment != null) 'place': _enrichment!.place.toJson(),
    }..removeWhere((_, value) => value == null);

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: double.infinity,
        height: 260,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _ExploreNetworkImage(
              imageUrl: heroImageUrl,
              fallbackImageUrl: fallbackImageUrl,
              semanticLabel: widget.imageAltText,
              fallbackIcon: Icons.travel_explore_rounded,
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
                  if (widget.badges.isNotEmpty)
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final badge in widget.badges)
                          _OverlayChip(label: badge),
                      ],
                    ),
                  const Spacer(),
                  Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BayHopText.display(
                      size: 26,
                      color: Colors.white,
                      height: 1.05,
                    ),
                  ),
                  if (widget.summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.summary,
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
                      onPressed: () =>
                          widget.onAction(widget.actionName, actionContext),
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
        onTap: () => widget.onAction(widget.actionName, actionContext),
        child: content,
      ),
    );
  }
}

class _HeroPlaceEnrichment {
  const _HeroPlaceEnrichment({
    required this.place,
    this.photoUri,
  });

  final PlaceResult place;
  final Uri? photoUri;
}

class _MosaicPlaceEnrichment {
  const _MosaicPlaceEnrichment({
    required this.place,
    this.photoUri,
  });

  final PlaceResult place;
  final Uri? photoUri;

  String? get photoAttributionLabel => place.primaryPhoto?.attributionLabel;
}

class ExploreImageMosaic extends StatefulWidget {
  const ExploreImageMosaic({
    required this.tiles,
    required this.onAction,
    this.title,
    this.summary,
    this.client,
    super.key,
  });

  factory ExploreImageMosaic.fromContext(CatalogItemContext context) {
    final json = context.data as JsonMap;
    return ExploreImageMosaic(
      title: _nullableString(json['title']),
      summary: _nullableString(json['summary']),
      tiles: _dedupeMosaicImages([
        for (final item in _jsonMapList(json['images']))
          ExploreMosaicImage.fromJson(item),
      ]).take(5).toList(growable: false),
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
  final GooglePlacesClient? client;
  final void Function(String actionName, JsonMap context) onAction;

  @override
  State<ExploreImageMosaic> createState() => _ExploreImageMosaicState();
}

class _ExploreImageMosaicState extends State<ExploreImageMosaic> {
  late final GooglePlacesClient _client = widget.client ?? GooglePlacesClient();
  Map<String, _MosaicPlaceEnrichment> _enrichments = const {};
  String _enrichmentKey = '';

  @override
  void initState() {
    super.initState();
    _reloadEnrichments();
  }

  @override
  void didUpdateWidget(covariant ExploreImageMosaic oldWidget) {
    super.didUpdateWidget(oldWidget);
    final key = _mosaicEnrichmentKey(_visibleTiles);
    if (key == _enrichmentKey) return;

    _enrichments = const {};
    _reloadEnrichments();
  }

  @override
  void dispose() {
    if (widget.client == null) _client.close();
    super.dispose();
  }

  List<ExploreMosaicImage> get _visibleTiles {
    return _dedupeMosaicImages(widget.tiles).take(5).toList(growable: false);
  }

  void _reloadEnrichments() {
    final visibleTiles = _visibleTiles;
    final key = _mosaicEnrichmentKey(visibleTiles);
    _enrichmentKey = key;
    if (key.isEmpty) {
      _enrichments = const {};
      return;
    }

    unawaited(_loadEnrichments(visibleTiles, key));
  }

  Future<void> _loadEnrichments(
    List<ExploreMosaicImage> visibleTiles,
    String enrichmentKey,
  ) async {
    final enrichments = <String, _MosaicPlaceEnrichment>{};

    for (var index = 0; index < visibleTiles.length; index++) {
      final tile = visibleTiles[index];
      final tileKey = _mosaicTilePlaceKey(tile, index);
      if (tileKey == null) continue;

      final placeQuery = tile.placeQuery!.trim();
      try {
        final results = await _client.searchText(
          query: placeQuery,
          maxResultCount: 1,
          regionCode: 'US',
        );
        if (!mounted || _enrichmentKey != enrichmentKey) return;
        if (results.isEmpty) continue;

        final place = results.first;
        enrichments[tileKey] = _MosaicPlaceEnrichment(
          place: place,
          photoUri: _photoUriFor(place),
        );
      } on Object {
        if (!mounted || _enrichmentKey != enrichmentKey) return;
      }
    }

    if (!mounted || _enrichmentKey != enrichmentKey) return;
    setState(() {
      _enrichments = enrichments;
    });
  }

  Uri? _photoUriFor(PlaceResult place) {
    final photo = place.primaryPhoto;
    if (photo == null) return null;

    return _client.photoMediaUri(photo, maxWidthPx: 640, maxHeightPx: 480);
  }

  @override
  Widget build(BuildContext context) {
    final visibleTiles = _visibleTiles;
    if (visibleTiles.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: bayHopCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null) ...[
            Text(
              widget.title!,
              style: BayHopText.body(size: 15, weight: FontWeight.w800),
            ),
            if (widget.summary != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.summary!,
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
              return _ExploreImageBentoLayout(
                tiles: visibleTiles,
                enrichments: _enrichments,
                maxWidth: constraints.maxWidth,
                onAction: widget.onAction,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExploreImageBentoLayout extends StatelessWidget {
  const _ExploreImageBentoLayout({
    required this.tiles,
    required this.enrichments,
    required this.maxWidth,
    required this.onAction,
  });

  final List<ExploreMosaicImage> tiles;
  final Map<String, _MosaicPlaceEnrichment> enrichments;
  final double maxWidth;
  final void Function(String actionName, JsonMap context) onAction;

  @override
  Widget build(BuildContext context) {
    final width = maxWidth.isFinite ? maxWidth : 320.0;
    if (tiles.length == 1 || width < 380) return _stackedLayout();

    final slots = _bentoSlotsFor(tiles.length);
    return AspectRatio(
      aspectRatio: _imageMosaicAspectRatio(tiles.length),
      child: _BentoStack(
        children: [
          for (var index = 0; index < tiles.length; index++)
            _BentoStackItem(
              slot: slots[index],
              child: _MosaicTile(
                data: tiles[index],
                enrichment: _enrichmentFor(tiles[index], index),
                density: _mosaicTileDensity(index, tiles.length),
                onAction: onAction,
              ),
            ),
        ],
      ),
    );
  }

  Widget _stackedLayout() {
    return Column(
      children: [
        for (var index = 0; index < tiles.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == tiles.length - 1 ? 0 : 8,
            ),
            child: _MosaicTile(
              data: tiles[index],
              enrichment: _enrichmentFor(tiles[index], index),
              aspectRatio: index == 0 && tiles.length > 2 ? 1.28 : 1.48,
              density: index == 0
                  ? _MosaicTileDensity.featured
                  : _MosaicTileDensity.regular,
              onAction: onAction,
            ),
          ),
      ],
    );
  }

  _MosaicPlaceEnrichment? _enrichmentFor(ExploreMosaicImage tile, int index) {
    final tileKey = _mosaicTilePlaceKey(tile, index);
    if (tileKey == null) return null;

    return enrichments[tileKey];
  }
}

class ExploreMosaicImage {
  const ExploreMosaicImage({
    this.imageUrl,
    this.title,
    this.badge,
    this.imageAltText,
    this.placeQuery,
    this.query,
    this.actionName = 'explore_option',
  });

  factory ExploreMosaicImage.fromJson(JsonMap json) {
    return ExploreMosaicImage(
      imageUrl: _nullableString(json['imageUrl']),
      title: _nullableString(json['title']),
      badge: _nullableString(json['badge']),
      imageAltText: _nullableString(json['imageAltText']),
      placeQuery: _nullableString(json['placeQuery']),
      query: _nullableString(json['query']),
      actionName: _string(json['actionName'], 'explore_option'),
    );
  }

  final String? imageUrl;
  final String? title;
  final String? badge;
  final String? imageAltText;
  final String? placeQuery;
  final String? query;
  final String actionName;

  JsonMap get actionContext {
    final trimmedPlaceQuery = placeQuery?.trim();
    return {
      'title': title,
      'badge': badge,
      'placeQuery': trimmedPlaceQuery == null || trimmedPlaceQuery.isEmpty
          ? null
          : trimmedPlaceQuery,
      'query': query,
      if (trimmedPlaceQuery == null || trimmedPlaceQuery.isEmpty)
        'imageUrl': imageUrl,
    }..removeWhere((_, value) => value == null);
  }
}

enum _MosaicTileDensity { featured, regular, compact }

class _MosaicTile extends StatelessWidget {
  const _MosaicTile({
    required this.data,
    required this.onAction,
    this.enrichment,
    this.aspectRatio,
    this.density = _MosaicTileDensity.regular,
  });

  final ExploreMosaicImage data;
  final void Function(String actionName, JsonMap context) onAction;
  final _MosaicPlaceEnrichment? enrichment;
  final double? aspectRatio;
  final _MosaicTileDensity density;

  @override
  Widget build(BuildContext context) {
    final hasPlaceQuery = _hasMosaicPlaceQuery(data);
    final imageUrl = hasPlaceQuery
        ? enrichment?.photoUri?.toString()
        : data.imageUrl;
    final fallbackImageUrl = hasPlaceQuery
        ? null
        : _fallbackImageUrlFor([
            data.title,
            data.badge,
            data.query,
          ]);
    final tile = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _ExploreNetworkImage(
                imageUrl: imageUrl,
                fallbackImageUrl: fallbackImageUrl,
                semanticLabel: data.imageAltText,
                fallbackIcon: Icons.image_rounded,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.04),
                      Colors.black.withValues(alpha: 0.68),
                    ],
                  ),
                ),
              ),
              if (enrichment?.photoAttributionLabel != null &&
                  constraints.maxWidth >= 170 &&
                  constraints.maxHeight >= 150)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: _PhotoAttributionPill(
                    label: enrichment!.photoAttributionLabel!,
                  ),
                ),
              Positioned.fill(
                child: _MosaicTileCaption(
                  data: data,
                  density: density,
                  maxWidth: constraints.maxWidth,
                  maxHeight: constraints.maxHeight,
                ),
              ),
            ],
          );
        },
      ),
    );
    final child = aspectRatio == null
        ? tile
        : AspectRatio(aspectRatio: aspectRatio!, child: tile);

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

class _MosaicTileCaption extends StatelessWidget {
  const _MosaicTileCaption({
    required this.data,
    required this.density,
    required this.maxWidth,
    required this.maxHeight,
  });

  final ExploreMosaicImage data;
  final _MosaicTileDensity density;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final isCompact =
        density == _MosaicTileDensity.compact ||
        maxWidth < 150 ||
        maxHeight < 126;
    final title = data.title ?? (isCompact ? data.badge : null);
    final showBadge =
        data.badge != null && !isCompact && maxWidth >= 150 && maxHeight >= 132;
    final titleSize = switch (density) {
      _MosaicTileDensity.featured => 15.5,
      _MosaicTileDensity.regular => 13.5,
      _MosaicTileDensity.compact => 12.5,
    };
    final titleLines =
        density == _MosaicTileDensity.featured && maxHeight >= 168 ? 2 : 1;
    final inset = isCompact ? 8.0 : 10.0;

    return Padding(
      padding: EdgeInsets.all(inset),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBadge)
            _OverlayChip(
              label: data.badge!,
              maxWidth: maxWidth - inset * 2,
            ),
          if (title != null) ...[
            if (showBadge) const SizedBox(height: 5),
            Text(
              title,
              maxLines: titleLines,
              overflow: TextOverflow.ellipsis,
              style: BayHopText.body(
                size: titleSize,
                color: Colors.white,
                weight: FontWeight.w800,
                height: 1.08,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BentoStack extends StatelessWidget {
  const _BentoStack({required this.children});

  final List<_BentoStackItem> children;

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            for (final item in children)
              Positioned(
                left: item.slot.left * constraints.maxWidth,
                top: item.slot.top * constraints.maxHeight,
                width: item.slot.width * constraints.maxWidth,
                height: item.slot.height * constraints.maxHeight,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: item.slot.left == 0 ? 0 : spacing / 2,
                    top: item.slot.top == 0 ? 0 : spacing / 2,
                    right: item.slot.right >= 0.999 ? 0 : spacing / 2,
                    bottom: item.slot.bottom >= 0.999 ? 0 : spacing / 2,
                  ),
                  child: item.child,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BentoStackItem {
  const _BentoStackItem({
    required this.slot,
    required this.child,
  });

  final _BentoSlot slot;
  final Widget child;
}

class _BentoSlot {
  const _BentoSlot({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
}

List<_BentoSlot> _bentoSlotsFor(int count) {
  return switch (count) {
    1 => const [
      _BentoSlot(left: 0, top: 0, width: 1, height: 1),
    ],
    2 => const [
      _BentoSlot(left: 0, top: 0, width: 0.58, height: 1),
      _BentoSlot(left: 0.58, top: 0, width: 0.42, height: 1),
    ],
    3 => const [
      _BentoSlot(left: 0, top: 0, width: 0.58, height: 1),
      _BentoSlot(left: 0.58, top: 0, width: 0.42, height: 0.5),
      _BentoSlot(left: 0.58, top: 0.5, width: 0.42, height: 0.5),
    ],
    4 => const [
      _BentoSlot(left: 0, top: 0, width: 0.58, height: 0.64),
      _BentoSlot(left: 0.58, top: 0, width: 0.42, height: 0.64),
      _BentoSlot(left: 0, top: 0.64, width: 0.34, height: 0.36),
      _BentoSlot(left: 0.34, top: 0.64, width: 0.66, height: 0.36),
    ],
    _ => const [
      _BentoSlot(left: 0, top: 0, width: 0.5, height: 1),
      _BentoSlot(left: 0.5, top: 0, width: 0.25, height: 0.5),
      _BentoSlot(left: 0.75, top: 0, width: 0.25, height: 0.5),
      _BentoSlot(left: 0.5, top: 0.5, width: 0.25, height: 0.5),
      _BentoSlot(left: 0.75, top: 0.5, width: 0.25, height: 0.5),
    ],
  };
}

double _imageMosaicAspectRatio(int count) {
  return switch (count) {
    2 => 1.95,
    3 => 1.55,
    4 => 1.42,
    5 => 1.55,
    _ => 1.48,
  };
}

double _placeMosaicAspectRatio(int count) {
  return switch (count) {
    1 => 1.6,
    2 => 2.05,
    3 => 1.6,
    4 => 1.45,
    5 => 1.55,
    _ => 1.55,
  };
}

_MosaicTileDensity _mosaicTileDensity(int index, int count) {
  if (index == 0) return _MosaicTileDensity.featured;
  if (count == 4 && index >= 2) return _MosaicTileDensity.compact;
  if (count >= 5 && index > 0) return _MosaicTileDensity.compact;
  return _MosaicTileDensity.regular;
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
      stops: _dedupeAdventureStops([
        for (final item in _jsonMapList(json['stops']))
          ExploreAdventureStop.fromJson(item),
      ]).take(5).toList(growable: false),
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
    this.imageAltText,
  });

  final int index;
  final Uri? photoUri;
  final String? imageAltText;

  @override
  Widget build(BuildContext context) {
    final networkImage = photoUri?.toString();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 70,
        height: 70,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _ExploreNetworkImage(
              imageUrl: networkImage,
              fallbackImageUrl: null,
              semanticLabel: imageAltText,
              fallbackIcon: Icons.place_rounded,
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

class ExplorerOptionCard extends StatefulWidget {
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
    this.placeQuery,
    this.client,
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
      placeQuery: _nullableString(json['placeQuery']),
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
  final String? placeQuery;
  final GooglePlacesClient? client;
  final void Function(String actionName, JsonMap context) onAction;

  @override
  State<ExplorerOptionCard> createState() => _ExplorerOptionCardState();
}

class _ExplorerOptionCardState extends State<ExplorerOptionCard> {
  late final GooglePlacesClient _client = widget.client ?? GooglePlacesClient();
  _OptionPlaceEnrichment? _enrichment;

  @override
  void initState() {
    super.initState();
    unawaited(_loadEnrichment());
  }

  @override
  void didUpdateWidget(covariant ExplorerOptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeQuery != widget.placeQuery) {
      _enrichment = null;
      unawaited(_loadEnrichment());
    }
  }

  @override
  void dispose() {
    if (widget.client == null) _client.close();
    super.dispose();
  }

  Future<void> _loadEnrichment() async {
    final placeQuery = widget.placeQuery?.trim();
    if (placeQuery == null || placeQuery.isEmpty) return;

    try {
      final results = await _client.searchText(
        query: placeQuery,
        maxResultCount: 1,
        regionCode: 'US',
      );
      if (!mounted || widget.placeQuery?.trim() != placeQuery) return;
      if (results.isEmpty) return;

      final place = results.first;
      setState(() {
        _enrichment = _OptionPlaceEnrichment(
          place: place,
          photoUri: _photoUriFor(place),
        );
      });
    } on Object {
      if (!mounted || widget.placeQuery?.trim() != placeQuery) return;
    }
  }

  Uri? _photoUriFor(PlaceResult place) {
    final photo = place.primaryPhoto;
    if (photo == null) return null;

    return _client.photoMediaUri(photo, maxWidthPx: 320);
  }

  @override
  Widget build(BuildContext context) {
    final placeQuery = widget.placeQuery?.trim();
    final hasPlaceQuery = placeQuery != null && placeQuery.isNotEmpty;
    final imageUrl = hasPlaceQuery
        ? _enrichment?.photoUri?.toString()
        : widget.imageUrl;
    final durationLabel = switch (widget.durationMinutes) {
      final minutes? when minutes > 0 => '$minutes min',
      _ => null,
    };
    final details = [
      ?widget.distanceLabel,
      ?widget.priceLabel,
      ?durationLabel,
    ];
    final actionContext = <String, Object?>{
      'title': _enrichment?.place.displayName ?? widget.title,
      'query': widget.query,
      'description': widget.description.isEmpty ? null : widget.description,
      'category': widget.category ?? widget.badge,
      'durationMinutes': widget.durationMinutes,
      'distanceLabel': widget.distanceLabel,
      'priceLabel': widget.priceLabel,
      'placeQuery': hasPlaceQuery ? placeQuery : null,
      if (!hasPlaceQuery) 'imageUrl': widget.imageUrl,
      if (_enrichment != null) 'place': _enrichment!.place.toJson(),
    }..removeWhere((_, value) => value == null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => widget.onAction(widget.actionName, actionContext),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: bayHopCardDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExplorerOptionVisual(
                imageUrl: imageUrl,
                imageAltText: widget.imageAltText,
                fallbackImageUrl: hasPlaceQuery
                    ? null
                    : _fallbackImageUrlFor([
                        widget.title,
                        widget.subtitle,
                        widget.description,
                        widget.badge,
                        widget.category,
                      ]),
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
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BayHopText.body(
                              size: 15,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (widget.badge != null) ...[
                          const SizedBox(width: 8),
                          BayHopChip(label: widget.badge!),
                        ],
                      ],
                    ),
                    if (widget.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: BayHopText.body(
                          size: 12.5,
                          color: BayHopColors.muted,
                          height: 1.25,
                        ),
                      ),
                    ],
                    if (widget.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.description,
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

class _OptionPlaceEnrichment {
  const _OptionPlaceEnrichment({
    required this.place,
    this.photoUri,
  });

  final PlaceResult place;
  final Uri? photoUri;
}

class _ExplorerOptionVisual extends StatelessWidget {
  const _ExplorerOptionVisual({
    required this.imageUrl,
    required this.imageAltText,
    required this.fallbackImageUrl,
  });

  final String? imageUrl;
  final String? imageAltText;
  final String? fallbackImageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 74,
        height: 74,
        child: _ExploreNetworkImage(
          imageUrl: imageUrl,
          fallbackImageUrl: fallbackImageUrl,
          semanticLabel: imageAltText,
          fallbackIcon: Icons.explore_rounded,
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

class _ExploreNetworkImage extends StatelessWidget {
  const _ExploreNetworkImage({
    required this.imageUrl,
    required this.fallbackImageUrl,
    required this.fallbackIcon,
    this.semanticLabel,
  });

  final String? imageUrl;
  final String? fallbackImageUrl;
  final IconData fallbackIcon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final primaryUrl = _usableImageUrl(imageUrl);
    if (primaryUrl != null) {
      return _networkImage(
        primaryUrl,
        fallbackUrl: _usableImageUrl(fallbackImageUrl),
      );
    }

    final fallbackUrl = _usableImageUrl(fallbackImageUrl);
    if (fallbackUrl != null) {
      return _networkImage(fallbackUrl);
    }

    return _ExploreVisualFallback(icon: fallbackIcon);
  }

  Widget _networkImage(String url, {String? fallbackUrl}) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      semanticLabel: semanticLabel,
      errorBuilder: (_, _, _) {
        if (fallbackUrl != null && fallbackUrl != url) {
          return _networkImage(fallbackUrl);
        }
        return _ExploreVisualFallback(icon: fallbackIcon);
      },
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
  MapPlaceOverlayController? _placeOverlayController;
  List<PlaceResult> _results = const [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextController = MapPlaceOverlayScope.maybeOf(context);
    if (nextController == _placeOverlayController) return;

    _placeOverlayController = nextController;
    if (!_loading && _error == null) {
      _publishSearchMarkers(_results);
    }
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
      final results = _dedupePlaceResults(await _search());
      if (!mounted || _searchKey(widget) != key) return;
      setState(() {
        _results = results;
        _loading = false;
      });
      _publishSearchMarkers(results);
    } on Object catch (error) {
      if (!mounted || _searchKey(widget) != key) return;
      setState(() {
        _error = error;
        _results = const [];
        _loading = false;
      });
      _placeOverlayController?.clearSearchResults();
    }
  }

  void _publishSearchMarkers(List<PlaceResult> results) {
    _placeOverlayController?.showSearchResults(
      MapPlaceMarker.searchResultsFromPlaces(results),
    );
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
            'Places data from Google. Results are shown as cards and '
            'eligible map markers.',
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
        height: 224,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            return SizedBox(
              width: 292,
              child: _cardFor(results[index], compact: true),
            );
          },
        ),
      ),
      ExplorePlaceSearchLayout.mosaic => LayoutBuilder(
        builder: (context, constraints) {
          return _PlaceResultsMosaic(
            results: results,
            maxWidth: constraints.maxWidth,
            distanceLabelFor: distanceLabelFor,
            photoUriFor: photoUriFor,
            onExplore: onExplore,
            onAdd: onAdd,
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

  Widget _cardFor(PlaceResult result, {bool compact = false}) {
    return _PlaceResultCard(
      place: result,
      compact: compact,
      distanceLabel: distanceLabelFor(result),
      photoUri: photoUriFor(result),
      onExplore: () => onExplore(result),
      onAdd: () => onAdd(result),
    );
  }
}

class _PlaceResultsMosaic extends StatelessWidget {
  const _PlaceResultsMosaic({
    required this.results,
    required this.maxWidth,
    required this.distanceLabelFor,
    required this.photoUriFor,
    required this.onExplore,
    required this.onAdd,
  });

  final List<PlaceResult> results;
  final double maxWidth;
  final String? Function(PlaceResult result) distanceLabelFor;
  final Uri? Function(PlaceResult result) photoUriFor;
  final ValueChanged<PlaceResult> onExplore;
  final ValueChanged<PlaceResult> onAdd;

  @override
  Widget build(BuildContext context) {
    final width = maxWidth.isFinite ? maxWidth : 320.0;
    if (width < 380) return _stackedLayout();

    final groups = <List<PlaceResult>>[];
    for (var start = 0; start < results.length; start += 5) {
      final end = start + 5 > results.length ? results.length : start + 5;
      groups.add(results.sublist(start, end));
    }

    return Column(
      children: [
        for (var index = 0; index < groups.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == groups.length - 1 ? 0 : 8,
            ),
            child: _PlaceResultsBentoGroup(
              results: groups[index],
              distanceLabelFor: distanceLabelFor,
              photoUriFor: photoUriFor,
              onExplore: onExplore,
              onAdd: onAdd,
            ),
          ),
      ],
    );
  }

  Widget _stackedLayout() {
    return Column(
      children: [
        for (var index = 0; index < results.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == results.length - 1 ? 0 : 8,
            ),
            child: _PlaceResultMosaicCard(
              place: results[index],
              distanceLabel: distanceLabelFor(results[index]),
              photoUri: photoUriFor(results[index]),
              aspectRatio: index == 0 ? 1.35 : 1.55,
              density: index == 0
                  ? _MosaicTileDensity.featured
                  : _MosaicTileDensity.regular,
              onExplore: () => onExplore(results[index]),
              onAdd: () => onAdd(results[index]),
            ),
          ),
      ],
    );
  }
}

class _PlaceResultsBentoGroup extends StatelessWidget {
  const _PlaceResultsBentoGroup({
    required this.results,
    required this.distanceLabelFor,
    required this.photoUriFor,
    required this.onExplore,
    required this.onAdd,
  });

  final List<PlaceResult> results;
  final String? Function(PlaceResult result) distanceLabelFor;
  final Uri? Function(PlaceResult result) photoUriFor;
  final ValueChanged<PlaceResult> onExplore;
  final ValueChanged<PlaceResult> onAdd;

  @override
  Widget build(BuildContext context) {
    final slots = _bentoSlotsFor(results.length);
    return AspectRatio(
      aspectRatio: _placeMosaicAspectRatio(results.length),
      child: _BentoStack(
        children: [
          for (var index = 0; index < results.length; index++)
            _BentoStackItem(
              slot: slots[index],
              child: _PlaceResultMosaicCard(
                place: results[index],
                distanceLabel: distanceLabelFor(results[index]),
                photoUri: photoUriFor(results[index]),
                density: _mosaicTileDensity(index, results.length),
                onExplore: () => onExplore(results[index]),
                onAdd: () => onAdd(results[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaceResultMosaicCard extends StatelessWidget {
  const _PlaceResultMosaicCard({
    required this.place,
    required this.onExplore,
    required this.onAdd,
    this.distanceLabel,
    this.photoUri,
    this.aspectRatio,
    this.density = _MosaicTileDensity.regular,
  });

  final PlaceResult place;
  final VoidCallback onExplore;
  final VoidCallback onAdd;
  final String? distanceLabel;
  final Uri? photoUri;
  final double? aspectRatio;
  final _MosaicTileDensity density;

  @override
  Widget build(BuildContext context) {
    final card = place.toCardData();
    final labels = [
      ?distanceLabel,
      ...card.metadata,
      ...card.tags,
    ];
    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onExplore,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact =
                  density == _MosaicTileDensity.compact ||
                  constraints.maxWidth < 158 ||
                  constraints.maxHeight < 140;
              final visibleLabels = labels.take(switch (density) {
                _MosaicTileDensity.featured => 3,
                _MosaicTileDensity.regular => 2,
                _MosaicTileDensity.compact => 1,
              }).toList();
              final showLabels =
                  visibleLabels.isNotEmpty &&
                  constraints.maxWidth >= 130 &&
                  constraints.maxHeight >= (isCompact ? 132 : 158);
              final showSubtitle =
                  !isCompact &&
                  card.subtitle != null &&
                  constraints.maxHeight >= 170;
              final titleSize = switch (density) {
                _MosaicTileDensity.featured => 16.5,
                _MosaicTileDensity.regular => 14.0,
                _MosaicTileDensity.compact => 12.5,
              };
              final titleLines =
                  density == _MosaicTileDensity.featured &&
                      constraints.maxHeight >= 190
                  ? 2
                  : 1;
              final inset = isCompact ? 8.0 : 10.0;
              final chipMaxWidth = constraints.maxWidth - inset * 2;

              return Stack(
                fit: StackFit.expand,
                children: [
                  _ExploreNetworkImage(
                    imageUrl: photoUri?.toString(),
                    fallbackImageUrl: null,
                    semanticLabel: card.title,
                    fallbackIcon: Icons.place_rounded,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.18),
                          Colors.black.withValues(alpha: 0.76),
                        ],
                      ),
                    ),
                  ),
                  if (photoUri != null &&
                      card.photoAttributionLabel != null &&
                      constraints.maxWidth >= 170 &&
                      constraints.maxHeight >= 150)
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 50,
                      child: _PhotoAttributionPill(
                        label: card.photoAttributionLabel!,
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filledTonal(
                      tooltip: 'Add to itinerary',
                      onPressed: onAdd,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.88),
                        foregroundColor: BayHopColors.ink,
                        fixedSize: const Size(38, 38),
                        minimumSize: const Size(38, 38),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 21),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(inset),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.title,
                            maxLines: titleLines,
                            overflow: TextOverflow.ellipsis,
                            style: BayHopText.body(
                              size: titleSize,
                              color: Colors.white,
                              weight: FontWeight.w900,
                              height: 1.08,
                            ),
                          ),
                          if (showSubtitle) ...[
                            const SizedBox(height: 3),
                            Text(
                              card.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BayHopText.body(
                                size: 11.5,
                                color: Colors.white.withValues(alpha: 0.84),
                                height: 1.16,
                              ),
                            ),
                          ],
                          if (showLabels) ...[
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              children: [
                                for (final label in visibleLabels)
                                  _OverlayMetadataChip(
                                    label: label,
                                    maxWidth: chipMaxWidth,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    if (aspectRatio == null) return tile;
    return AspectRatio(aspectRatio: aspectRatio!, child: tile);
  }
}

class _OverlayMetadataChip extends StatelessWidget {
  const _OverlayMetadataChip({
    required this.label,
    required this.maxWidth,
  });

  final String label;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BayHopText.body(
            size: 10.5,
            color: Colors.white,
            weight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _PhotoAttributionPill extends StatelessWidget {
  const _PhotoAttributionPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Photo: $label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: BayHopText.body(
          size: 8.5,
          color: Colors.white,
          weight: FontWeight.w700,
          height: 1,
        ),
      ),
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
    this.compact = false,
  });

  final PlaceResult place;
  final VoidCallback onExplore;
  final VoidCallback onAdd;
  final String? distanceLabel;
  final Uri? photoUri;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final card = place.toCardData();
    final allLabels = [
      ?distanceLabel,
      ...card.metadata,
      ...card.tags,
    ];
    final labels = compact ? allLabels.take(4).toList() : allLabels;

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
              _PlacePhotoThumbnail(
                uri: photoUri,
                attributionLabel: card.photoAttributionLabel,
              ),
              const SizedBox(width: 10),
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
                            maxLines: compact ? 1 : 2,
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

  final Uri? uri;
  final String? attributionLabel;

  @override
  Widget build(BuildContext context) {
    final photoUri = uri;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 82,
        height: 82,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photoUri == null)
              const _ExploreVisualFallback(icon: Icons.place_rounded)
            else
              Image.network(
                photoUri.toString(),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) {
                  return const _ExploreVisualFallback(
                    icon: Icons.place_rounded,
                  );
                },
              ),
            if (photoUri != null && attributionLabel != null)
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
  const _OverlayChip({
    required this.label,
    this.maxWidth,
  });

  final String label;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: ConstrainedBox(
        constraints: maxWidth == null
            ? const BoxConstraints()
            : BoxConstraints(maxWidth: maxWidth!),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BayHopText.body(
            size: 11.5,
            weight: FontWeight.w800,
            color: Colors.white,
          ),
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

String _mosaicEnrichmentKey(List<ExploreMosaicImage> images) {
  final keys = <String>[];
  for (var index = 0; index < images.length; index++) {
    final key = _mosaicTilePlaceKey(images[index], index);
    if (key != null) keys.add(key);
  }

  return keys.join(';;');
}

String? _mosaicTilePlaceKey(ExploreMosaicImage image, int index) {
  final placeQuery = image.placeQuery?.trim();
  if (placeQuery == null || placeQuery.isEmpty) return null;

  return '$index|$placeQuery';
}

bool _hasMosaicPlaceQuery(ExploreMosaicImage image) {
  final placeQuery = image.placeQuery?.trim();
  return placeQuery != null && placeQuery.isNotEmpty;
}

List<PlaceResult> _dedupePlaceResults(Iterable<PlaceResult> results) {
  return _dedupeByKeys(results, _placeResultKeys);
}

List<ExploreAdventureStop> _dedupeAdventureStops(
  Iterable<ExploreAdventureStop> stops,
) {
  return _dedupeByKeys(stops, _adventureStopKeys);
}

List<ExploreMosaicImage> _dedupeMosaicImages(
  Iterable<ExploreMosaicImage> images,
) {
  return _dedupeByKeys(images, _mosaicImageKeys);
}

List<T> _dedupeByKeys<T>(
  Iterable<T> items,
  Iterable<String> Function(T item) keysFor,
) {
  final seen = <String>{};
  final unique = <T>[];

  for (final item in items) {
    final keys = keysFor(item).toList(growable: false);
    if (keys.isNotEmpty && keys.any(seen.contains)) continue;

    unique.add(item);
    seen.addAll(keys);
  }

  return unique;
}

Iterable<String> _placeResultKeys(PlaceResult place) sync* {
  final id = _normalizeDedupeText(place.id);
  if (id != null) yield 'place:$id';

  yield* _titleAddressKeys(
    title: place.displayName,
    address: place.formattedAddress,
    prefix: 'place-text',
  );
}

Iterable<String> _adventureStopKeys(ExploreAdventureStop stop) sync* {
  final placeId = _normalizeDedupeText(stop.placeId);
  if (placeId != null) yield 'place:$placeId';

  final placeQuery = _normalizeDedupeText(stop.placeQuery);
  if (placeQuery != null) yield 'query:$placeQuery';

  yield* _titleAddressKeys(
    title: stop.title,
    address: stop.address,
    prefix: 'adventure-text',
  );
}

Iterable<String> _mosaicImageKeys(ExploreMosaicImage image) sync* {
  final placeQuery = _normalizeDedupeText(image.placeQuery);
  if (placeQuery != null) yield 'place-query:$placeQuery';

  final query = _normalizeDedupeText(image.query);
  if (query != null) yield 'query:$query';

  final title = _normalizeDedupeText(image.title);
  if (title != null) yield 'title:$title';
}

Iterable<String> _titleAddressKeys({
  required String? title,
  required String? address,
  required String prefix,
}) sync* {
  final normalizedTitle = _normalizeDedupeText(title);
  if (normalizedTitle == null) return;

  final normalizedAddress = _normalizeDedupeText(address);
  if (normalizedAddress == null) {
    yield '$prefix:$normalizedTitle';
    return;
  }

  yield '$prefix:$normalizedTitle|$normalizedAddress';
}

String? _normalizeDedupeText(String? value) {
  final normalized = value?.trim().toLowerCase().replaceAll(
    RegExp(r'\s+'),
    ' ',
  );
  if (normalized == null || normalized.isEmpty) return null;
  return normalized;
}

String? _fallbackImageUrlFor(Iterable<String?> cues) {
  return fallbackExploreImageUrlFor(cues);
}

String? _usableImageUrl(String? value) {
  final text = _nullableString(value);
  if (!isUsableExploreImageUrl(text)) return null;
  return text;
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
