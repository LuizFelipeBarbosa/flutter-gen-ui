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

class ExplorePlaceSearch extends StatefulWidget {
  const ExplorePlaceSearch({
    required this.title,
    required this.onAction,
    this.query = '',
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
            for (final result in _results)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PlaceResultCard(
                  place: result,
                  distanceLabel: _distanceLabelFor(result),
                  photoUri: _photoUriFor(result),
                  onExplore: () => widget.onAction(
                    'explore_place',
                    result.toJson(),
                  ),
                  onAdd: () => widget.onAction(
                    'add_itinerary_stop',
                    result.toJson(),
                  ),
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

String _searchKey(ExplorePlaceSearch widget) {
  return [
    widget.title,
    widget.query,
    widget.includedType,
    widget.latitude,
    widget.longitude,
    widget.radiusMeters,
    widget.maxResultCount,
  ].join('|');
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
