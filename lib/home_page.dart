import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/conversation.dart';
import 'package:genui_template/location/location.dart';
import 'package:genui_template/model/inception_model_client.dart';
import 'package:genui_template/transit/bayhop_atoms.dart';
import 'package:genui_template/transit/bayhop_tokens.dart';
import 'package:genui_template/transit/transit_route_geometry.dart';
import 'package:genui_template/transit/transit_widgets.dart';

const List<_Suggestion> _suggestions = [
  _Suggestion(
    title: 'Downtown Berkeley → SFO',
    subtitle: 'Trip · fastest 58 min',
    query: 'Downtown Berkeley to SFO, leave now',
    icon: Icons.alt_route_rounded,
    tint: Color(0x1FED1C24),
    iconColor: BayHopColors.red,
  ),
  _Suggestion(
    title: 'Next trains from Embarcadero',
    subtitle: 'Live departures',
    query: 'Next trains from Embarcadero',
    icon: Icons.departure_board_rounded,
    tint: Color(0x1F0091D2),
    iconColor: BayHopColors.aiBlue,
  ),
  _Suggestion(
    title: 'Is the Yellow Line delayed?',
    subtitle: 'Service status',
    query: 'Is the Yellow Line delayed?',
    icon: Icons.warning_amber_rounded,
    tint: Color(0x24E8920B),
    iconColor: BayHopColors.warn,
  ),
];

class HomePage extends StatefulWidget {
  const HomePage({
    this.locationController,
    this.onOpenExplore,
    super.key,
  });

  final UserLocationController? locationController;
  final ValueChanged<String>? onOpenExplore;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final GenUiSession _session;
  late final UserLocationController _locationController;
  late final bool _ownsLocationController;
  late final ActionDelegate _actionDelegate;
  final _textController = TextEditingController();
  final _sheetController = DraggableScrollableController();
  final _routeOverlay = ValueNotifier<MapRouteOverlay?>(null);
  StreamSubscription<ConversationEvent>? _eventsSub;

  static const double _minSize = 0.16;
  static const double _halfSize = 0.52;
  static const double _fullSize = 0.92;

  @override
  void initState() {
    super.initState();

    _locationController = widget.locationController ?? UserLocationController();
    _ownsLocationController = widget.locationController == null;
    if (_ownsLocationController) unawaited(_locationController.refresh());
    _actionDelegate = _TransitActionDelegate(
      onOpenExplore: widget.onOpenExplore,
    );
    _session = GenUiSession(
      modelClientBuilder: InceptionModelClient.new,
      contextProvider: _locationContextForModel,
    );

    _eventsSub = _session.events.listen((event) {
      if (event is ConversationError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request failed: ${event.error}')),
        );
      }
    });
  }

  @override
  void dispose() {
    unawaited(_eventsSub?.cancel());
    if (_ownsLocationController) _locationController.dispose();
    _textController.dispose();
    _sheetController.dispose();
    _routeOverlay.dispose();
    _session.dispose();
    super.dispose();
  }

  void sendMessage(String text) {
    final request = text.trim();
    if (request.isEmpty) return;

    _routeOverlay.value = null;
    _session.sendMessage(request);
    _textController.clear();
    FocusScope.of(context).unfocus();
    _expandSheet();
  }

  void _handleJourneySelected(TransitJourney journey) {
    _routeOverlay.value = buildTransitJourneyRouteOverlay(
      journey,
      currentLocation: _locationController.value.fix?.coordinate,
    );
  }

  void _expandSheet() {
    if (!_sheetController.isAttached) return;
    if (_sheetController.size < _halfSize - 0.01) {
      unawaited(
        _sheetController.animateTo(
          _halfSize,
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  String _locationContextForModel() {
    return _locationController.value.promptContext ??
        'User location snapshot: unavailable (location has not been shared). '
            "Do not infer the user's current station.";
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: ValueListenableBuilder<ConversationState>(
        valueListenable: _session.conversationState,
        builder: (context, state, _) {
          final surfaceId = state.surfaces.isEmpty ? null : state.surfaces.last;

          return Stack(
            children: [
              Positioned.fill(
                child: OsmMapBackground(
                  location: _locationController,
                  onRequestLocation: _locationController.refresh,
                  routeOverlayListenable: _routeOverlay,
                ),
              ),
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: _halfSize,
                minChildSize: _minSize,
                maxChildSize: _fullSize,
                snap: true,
                snapSizes: const [_minSize, _halfSize, _fullSize],
                builder: (context, scrollController) {
                  return _BottomSheet(
                    scrollController: scrollController,
                    state: state,
                    surfaceId: surfaceId,
                    session: _session,
                    locationController: _locationController,
                    actionDelegate: _actionDelegate,
                    onJourneySelected: _handleJourneySelected,
                    onSuggestion: sendMessage,
                  );
                },
              ),
              Positioned(
                top: topInset + 12,
                left: 14,
                right: 14,
                child: _BayHopSearchBar(
                  controller: _textController,
                  isProcessing: state.isWaiting,
                  onSend: sendMessage,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The frosted bottom sheet: a drag handle, quick chips, a live "nearby" row,
/// and the result area that hosts the model-generated surface.
class _BottomSheet extends StatelessWidget {
  const _BottomSheet({
    required this.scrollController,
    required this.state,
    required this.surfaceId,
    required this.session,
    required this.locationController,
    required this.actionDelegate,
    required this.onJourneySelected,
    required this.onSuggestion,
  });

  final ScrollController scrollController;
  final ConversationState state;
  final String? surfaceId;
  final GenUiSession session;
  final UserLocationController locationController;
  final ActionDelegate actionDelegate;
  final ValueChanged<TransitJourney> onJourneySelected;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return BayHopFrostedSurface(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      blur: 26,
      opacity: 0.8,
      boxShadow: const [
        BoxShadow(
          color: Color(0x21121C26),
          blurRadius: 40,
          offset: Offset(0, -8),
        ),
      ],
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xD9FFFFFF)),
          ),
        ),
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.zero,
          children: [
            const _DragHandle(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: Row(
                children: [
                  BayHopChip(label: 'Nearby'),
                  SizedBox(width: 8),
                  BayHopChip(label: 'Home'),
                  SizedBox(width: 8),
                  BayHopChip(label: 'Work'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: _NearbyRow(
                locationController: locationController,
                onSuggestion: onSuggestion,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
              child: _ResultArea(
                state: state,
                surfaceId: surfaceId,
                session: session,
                actionDelegate: actionDelegate,
                onJourneySelected: onJourneySelected,
                onSuggestion: onSuggestion,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 11, bottom: 7),
      child: Center(
        child: Container(
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFF14181C).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({
    required this.locationController,
    required this.onSuggestion,
  });

  final UserLocationController locationController;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LocationSnapshot>(
      valueListenable: locationController,
      builder: (context, snapshot, _) {
        final nearest = snapshot.nearestStop;
        final hasStop = snapshot.hasLocation && nearest != null;
        final title = hasStop ? nearest.stop.name : _titleFor(snapshot);
        final subtitle = hasStop
            ? '${nearest.stop.modeLabel} · ${nearest.distanceLabel} away'
            : _subtitleFor(snapshot);

        return _NearbyRowSurface(
          title: title,
          subtitle: subtitle,
          isLocating: snapshot.status == LocationSnapshotStatus.locating,
          hasLocation: snapshot.hasLocation,
          onTap: () => _handleTap(snapshot),
        );
      },
    );
  }

  void _handleTap(LocationSnapshot snapshot) {
    final stop = snapshot.nearestStop?.stop;
    if (snapshot.hasLocation && stop != null) {
      onSuggestion('Next departures from ${stop.name}');
      return;
    }

    unawaited(locationController.refresh());
  }

  String _titleFor(LocationSnapshot snapshot) {
    switch (snapshot.status) {
      case LocationSnapshotStatus.locating:
        return 'Finding nearby stops';
      case LocationSnapshotStatus.serviceDisabled:
        return 'Location services off';
      case LocationSnapshotStatus.permissionDenied:
      case LocationSnapshotStatus.permissionDeniedForever:
        return 'Location permission needed';
      case LocationSnapshotStatus.unavailable:
        return 'Location unavailable';
      case LocationSnapshotStatus.idle:
      case LocationSnapshotStatus.available:
        return 'Use current location';
    }
  }

  String _subtitleFor(LocationSnapshot snapshot) {
    switch (snapshot.status) {
      case LocationSnapshotStatus.locating:
        return 'Checking BART, Muni, and Caltrain stops';
      case LocationSnapshotStatus.serviceDisabled:
        return 'Turn on services or search by station';
      case LocationSnapshotStatus.permissionDenied:
      case LocationSnapshotStatus.permissionDeniedForever:
        return 'Search by station or update permissions';
      case LocationSnapshotStatus.unavailable:
        return snapshot.message ?? 'Search by station instead';
      case LocationSnapshotStatus.idle:
      case LocationSnapshotStatus.available:
        return 'Find the closest Bay Area transit stop';
    }
  }
}

class _NearbyRowSurface extends StatelessWidget {
  const _NearbyRowSurface({
    required this.title,
    required this.subtitle,
    required this.isLocating,
    required this.hasLocation,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isLocating;
  final bool hasLocation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFF76808A).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              if (hasLocation)
                const BayHopLiveDot(size: 9)
              else
                const Icon(
                  Icons.my_location_rounded,
                  size: 17,
                  color: BayHopColors.aiBlue,
                ),
              const SizedBox(width: 11),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: title,
                        style: BayHopText.body(
                          size: 13,
                          weight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ' · $subtitle',
                        style: BayHopText.body(
                          size: 13,
                          color: BayHopColors.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isLocating)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: BayHopColors.faint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultArea extends StatelessWidget {
  const _ResultArea({
    required this.state,
    required this.surfaceId,
    required this.session,
    required this.actionDelegate,
    required this.onJourneySelected,
    required this.onSuggestion,
  });

  final ConversationState state;
  final String? surfaceId;
  final GenUiSession session;
  final ActionDelegate actionDelegate;
  final ValueChanged<TransitJourney> onJourneySelected;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    if (state.isWaiting) return const _GeneratingResult();

    final id = surfaceId;
    if (id == null) return _IntroResult(onSuggestion: onSuggestion);

    return TransitRouteSelectionScope(
      onJourneySelected: onJourneySelected,
      child: Surface(
        surfaceContext: session.contextFor(id),
        actionDelegate: actionDelegate,
      ),
    );
  }
}

/// Shown before any request: a friendly prompt plus tappable suggestions.
class _IntroResult extends StatelessWidget {
  const _IntroResult({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const BayHopAiSpark(size: 30),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Where are you headed?',
                    style: BayHopText.display(size: 19),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ask for trips, live departures, or service status.',
                    style: BayHopText.body(size: 13, color: BayHopColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'TRY ASKING',
          style: BayHopText.body(
            size: 10.5,
            weight: FontWeight.w700,
            color: BayHopColors.faint,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        for (final suggestion in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SuggestionTile(
              suggestion: suggestion,
              onTap: () => onSuggestion(suggestion.query),
            ),
          ),
      ],
    );
  }
}

/// The brief "composing" beat shown while the model streams its surface.
class _GeneratingResult extends StatelessWidget {
  const _GeneratingResult();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const BayHopAiSpark(),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generating result…',
                    style: BayHopText.body(size: 15, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Composing the best view across BART & Muni',
                    style: BayHopText.body(
                      size: 12,
                      color: const Color(0xFF8A929A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: bayHopCardDecoration(),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonRow(widthFactor: 0.34, height: 13),
              SizedBox(height: 14),
              _SkeletonRow(widthFactor: 0.6, height: 42, radius: 11),
              SizedBox(height: 20),
              _SkeletonRow(widthFactor: 1, height: 9, radius: 5),
              SizedBox(height: 9),
              _SkeletonRow(widthFactor: 0.78, height: 9, radius: 5),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({
    required this.widthFactor,
    required this.height,
    this.radius = 7,
  });

  final double widthFactor;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widthFactor,
        child: BayHopSkeletonBar(
          width: double.infinity,
          height: height,
          radius: radius,
        ),
      ),
    );
  }
}

/// The floating frosted search bar; tapping it reveals "TRY ASKING".
class _BayHopSearchBar extends StatefulWidget {
  const _BayHopSearchBar({
    required this.controller,
    required this.isProcessing,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isProcessing;
  final ValueChanged<String> onSend;

  @override
  State<_BayHopSearchBar> createState() => _BayHopSearchBarState();
}

class _BayHopSearchBarState extends State<_BayHopSearchBar> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  void _onFocusChange() => setState(() {});

  void _pick(String query) {
    _focus.unfocus();
    widget.onSend(query);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BayHopFrostedSurface(
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          blur: 18,
          opacity: 0.64,
          borderOpacity: 0.75,
          boxShadow: const [
            BoxShadow(
              color: Color(0x29121C26),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
            BoxShadow(
              color: Color(0x1A121C26),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
          child: SizedBox(
            height: 54,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 8, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: Color(0xFF4F585F),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      enabled: !widget.isProcessing,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _pick,
                      style: BayHopText.body(size: 16),
                      decoration: InputDecoration.collapsed(
                        hintText: 'Search BART, Muni, Caltrain…',
                        hintStyle: BayHopText.body(
                          size: 16,
                          color: BayHopColors.muted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE1E8ED),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 22,
                      color: Color(0xFF9BA7AF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_focus.hasFocus) ...[
          const SizedBox(height: 10),
          _SearchSuggestions(onPick: _pick),
        ],
      ],
    );
  }
}

class _SearchSuggestions extends StatelessWidget {
  const _SearchSuggestions({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return BayHopFrostedSurface(
      opacity: 0.82,
      boxShadow: const [
        BoxShadow(
          color: Color(0x33121C26),
          blurRadius: 36,
          offset: Offset(0, 14),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 6),
              child: Text(
                'TRY ASKING',
                style: BayHopText.body(
                  size: 10.5,
                  weight: FontWeight.w700,
                  color: BayHopColors.faint,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            for (final suggestion in _suggestions)
              _SuggestionTile(
                suggestion: suggestion,
                onTap: () => onPick(suggestion.query),
              ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.suggestion, required this.onTap});

  final _Suggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: suggestion.tint,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  suggestion.icon,
                  size: 18,
                  color: suggestion.iconColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BayHopText.body(
                        size: 14.5,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      suggestion.subtitle,
                      style: BayHopText.body(
                        size: 12,
                        color: BayHopColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Suggestion {
  const _Suggestion({
    required this.title,
    required this.subtitle,
    required this.query,
    required this.icon,
    required this.tint,
    required this.iconColor,
  });

  final String title;
  final String subtitle;
  final String query;
  final IconData icon;
  final Color tint;
  final Color iconColor;
}

class _TransitActionDelegate implements ActionDelegate {
  const _TransitActionDelegate({required this.onOpenExplore});

  final ValueChanged<String>? onOpenExplore;

  @override
  bool handleEvent(
    BuildContext context,
    UiEvent event,
    SurfaceContext genUiContext,
    Widget Function(SurfaceDefinition, Catalog, String, DataContext)
    buildWidget,
  ) {
    if (event is! UserActionEvent || event.name != 'open_explore') {
      return false;
    }

    final query = _actionString(event.context['query']);
    if (query == null) return false;
    onOpenExplore?.call(query);
    return true;
  }

  String? _actionString(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
