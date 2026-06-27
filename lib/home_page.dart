import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/conversation.dart';
import 'package:genui_template/explore/itinerary.dart';
import 'package:genui_template/explore/transit_route_handoff_controller.dart';
import 'package:genui_template/location/location.dart';
import 'package:genui_template/model/inception_model_client.dart';
import 'package:genui_template/model/model_client.dart';
import 'package:genui_template/transit/bayhop_atoms.dart';
import 'package:genui_template/transit/bayhop_tokens.dart';
import 'package:genui_template/transit/google_routes_transit_client.dart';
import 'package:genui_template/transit/saved_itinerary_transit_planner.dart';
import 'package:genui_template/transit/transit_route_geometry.dart';
import 'package:genui_template/transit/transit_widgets.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

typedef HomeModelClientBuilder =
    ModelClient Function({
      required String systemPrompt,
    });

class HomePage extends StatefulWidget {
  const HomePage({
    this.locationController,
    this.itineraryController,
    this.routeHandoffController,
    this.onOpenExplore,
    this.modelClientBuilder,
    this.transitPlanner,
    this.currentTime,
    super.key,
  });

  final UserLocationController? locationController;
  final ItineraryController? itineraryController;
  final TransitRouteHandoffController? routeHandoffController;
  final ValueChanged<String>? onOpenExplore;
  final HomeModelClientBuilder? modelClientBuilder;
  final SavedItineraryTransitPlanner? transitPlanner;
  final DateTime Function()? currentTime;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final GenUiSession _session;
  late final UserLocationController _locationController;
  late final SavedItineraryTransitPlanner _transitPlanner;
  late final bool _ownsLocationController;
  late final bool _ownsTransitPlanner;
  late ActionDelegate _actionDelegate;
  final _textController = TextEditingController();
  final _sheetController = DraggableScrollableController();
  final _routeOverlay = ValueNotifier<MapRouteOverlay?>(null);
  StreamSubscription<ConversationEvent>? _eventsSub;
  int? _lastRouteHandoffId;

  static const double _minSize = 0.16;
  static const double _halfSize = 0.52;
  static const double _fullSize = 0.92;

  @override
  void initState() {
    super.initState();

    _locationController = widget.locationController ?? UserLocationController();
    _ownsLocationController = widget.locationController == null;
    _transitPlanner =
        widget.transitPlanner ??
        SavedItineraryTransitPlanner(client: GoogleRoutesTransitClient());
    _ownsTransitPlanner = widget.transitPlanner == null;
    if (_ownsLocationController) unawaited(_locationController.refresh());
    _actionDelegate = _TransitActionDelegate(
      onOpenExplore: widget.onOpenExplore,
      itineraryController: widget.itineraryController,
    );
    _session = GenUiSession(
      modelClientBuilder: widget.modelClientBuilder ?? InceptionModelClient.new,
      contextProvider: _contextForModel,
      currentTime: widget.currentTime,
    );

    _eventsSub = _session.events.listen((event) {
      if (event is ConversationError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request failed: ${event.error}')),
        );
      }
    });

    widget.routeHandoffController?.addListener(_handleRouteHandoff);
    _handleRouteHandoff();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itineraryController != widget.itineraryController ||
        oldWidget.onOpenExplore != widget.onOpenExplore) {
      _actionDelegate = _TransitActionDelegate(
        onOpenExplore: widget.onOpenExplore,
        itineraryController: widget.itineraryController,
      );
    }

    if (oldWidget.routeHandoffController != widget.routeHandoffController) {
      oldWidget.routeHandoffController?.removeListener(_handleRouteHandoff);
      widget.routeHandoffController?.addListener(_handleRouteHandoff);
      _handleRouteHandoff();
    }
  }

  @override
  void dispose() {
    unawaited(_eventsSub?.cancel());
    widget.routeHandoffController?.removeListener(_handleRouteHandoff);
    if (_ownsTransitPlanner) _transitPlanner.close();
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

  void _handleRouteHandoff() {
    final handoff = widget.routeHandoffController?.value;
    if (handoff == null || handoff.id == _lastRouteHandoffId) return;
    _lastRouteHandoffId = handoff.id;

    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (!mounted || _lastRouteHandoffId != handoff.id) return;
        unawaited(
          _sendSavedItineraryRoute(
            handoff.stops,
            fallbackQuery: handoff.query,
          ),
        );
      })
      ..scheduleFrame();
  }

  void _handleJourneySelected(TransitJourney journey) {
    _routeOverlay.value = buildTransitJourneyRouteOverlay(
      journey,
      currentLocation: _locationController.value.fix?.coordinate,
    );
  }

  void _routeSavedItinerary() {
    unawaited(
      _sendSavedItineraryRoute(
        widget.itineraryController?.value ?? const [],
      ),
    );
  }

  Future<void> _sendSavedItineraryRoute(
    List<ItineraryStop> stops, {
    String? fallbackQuery,
  }) async {
    final query = fallbackQuery ?? transitRouteRequestFor(stops);
    if (query == null) return;

    final plan = await _transitPlanner.plan(
      stops: stops,
      currentLocation: _locationController.value.fix?.coordinate,
      departureTime: (widget.currentTime ?? DateTime.now)(),
    );
    if (!mounted) return;

    sendMessage(_routeRequestWithPlannerFacts(query, plan));
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

  String _contextForModel() {
    return [
      _locationContextForModel(),
      widget.itineraryController?.toTransitPromptContext() ??
          'Saved itinerary: unavailable.',
    ].join(' ');
  }

  String _locationContextForModel() {
    return _locationController.value.promptContext ??
        'User location snapshot: unavailable (location has not been shared). '
            "Do not infer the user's current station.";
  }

  String _routeRequestWithPlannerFacts(
    String query,
    SavedItineraryTransitPlan plan,
  ) {
    if (!plan.hasAvailableSegments) {
      return '$query Transit planner facts are unavailable: '
          '${plan.toPromptContext()} Render a warning TransitNote only. '
          'Do not render TransitJourney or TransitDepartures cards for this '
          'request. Never use 0-minute placeholder route times.';
    }

    return '$query Planner-backed route facts: ${plan.toPromptContext()} '
        'Use these planner-backed TransitJourney fields exactly when '
        'available. '
        'Only render TransitJourney cards for available planner-backed '
        'segments with nonzero leg minutes. For unavailable segments, render '
        'a TransitNote instead of estimating. Never use 0-minute placeholder '
        'route times.';
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final placeOverlayController = MapPlaceOverlayScope.maybeOf(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: ValueListenableBuilder<ConversationState>(
        valueListenable: _session.conversationState,
        builder: (context, state, _) {
          final surfaceId = state.surfaces.isEmpty ? null : state.surfaces.last;

          return Stack(
            children: [
              Positioned.fill(
                child: GoogleMapBackground(
                  location: _locationController,
                  onRequestLocation: _locationController.refresh,
                  routeOverlayListenable: _routeOverlay,
                  placeOverlayListenable: placeOverlayController,
                ),
              ),
              ScrollConfiguration(
                behavior: const _TransitSheetScrollBehavior(),
                child: DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: _halfSize,
                  minChildSize: _minSize,
                  maxChildSize: _fullSize,
                  snap: true,
                  snapSizes: const [_minSize, _halfSize, _fullSize],
                  builder: (context, scrollController) {
                    return PointerInterceptor(
                      intercepting: kIsWeb,
                      child: _BottomSheet(
                        scrollController: scrollController,
                        state: state,
                        surfaceId: surfaceId,
                        session: _session,
                        locationController: _locationController,
                        itineraryController: widget.itineraryController,
                        actionDelegate: _actionDelegate,
                        onJourneySelected: _handleJourneySelected,
                        onRouteSavedItinerary: _routeSavedItinerary,
                        onSuggestion: sendMessage,
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: topInset + 12,
                left: 14,
                right: 14,
                child: PointerInterceptor(
                  intercepting: kIsWeb,
                  child: _BayHopSearchBar(
                    controller: _textController,
                    isProcessing: state.isWaiting,
                    locationController: _locationController,
                    itineraryController: widget.itineraryController,
                    onSend: sendMessage,
                    onRouteSavedItinerary: _routeSavedItinerary,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TransitSheetScrollBehavior extends MaterialScrollBehavior {
  const _TransitSheetScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
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
    required this.itineraryController,
    required this.actionDelegate,
    required this.onJourneySelected,
    required this.onRouteSavedItinerary,
    required this.onSuggestion,
  });

  final ScrollController scrollController;
  final ConversationState state;
  final String? surfaceId;
  final GenUiSession session;
  final UserLocationController locationController;
  final ItineraryController? itineraryController;
  final ActionDelegate actionDelegate;
  final ValueChanged<TransitJourney> onJourneySelected;
  final VoidCallback onRouteSavedItinerary;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return BayHopFrostedSurface(
      key: const ValueKey('transit-bottom-sheet'),
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
          key: const ValueKey('transit-sheet-scrollable'),
          controller: scrollController,
          padding: EdgeInsets.zero,
          children: [
            const _DragHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: _NearbyRow(
                locationController: locationController,
                onSuggestion: onSuggestion,
              ),
            ),
            if (itineraryController != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _SavedItineraryPanel(
                  controller: itineraryController!,
                  onRoute: onRouteSavedItinerary,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
              child: _ResultArea(
                state: state,
                surfaceId: surfaceId,
                session: session,
                locationController: locationController,
                itineraryController: itineraryController,
                actionDelegate: actionDelegate,
                onJourneySelected: onJourneySelected,
                onRouteSavedItinerary: onRouteSavedItinerary,
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
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: Padding(
        padding: const EdgeInsets.only(top: 11, bottom: 7),
        child: Center(
          child: Container(
            key: const ValueKey('transit-sheet-drag-handle'),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFF14181C).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedItineraryPanel extends StatelessWidget {
  const _SavedItineraryPanel({
    required this.controller,
    required this.onRoute,
  });

  final ItineraryController controller;
  final VoidCallback onRoute;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ItineraryStop>>(
      valueListenable: controller,
      builder: (context, stops, _) {
        if (stops.isEmpty) return const SizedBox.shrink();

        final first = stops.first;
        final last = stops.last;
        final routeLabel = stops.length == 1
            ? first.title
            : '${first.title} → ${last.title}';
        final stopLabel = stops.length == 1
            ? '1 saved stop'
            : '${stops.length} saved stops';
        final duration = stops.fold<int>(
          0,
          (total, stop) => total + stop.durationMinutes,
        );

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: bayHopCardDecoration(radius: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: BayHopColors.aiPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.bookmark_added_rounded,
                      color: BayHopColors.aiPurple,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saved itinerary',
                          style: BayHopText.body(
                            size: 14.5,
                            weight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          routeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BayHopText.body(
                            size: 12.5,
                            color: BayHopColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onRoute,
                    icon: const Icon(Icons.alt_route_rounded, size: 18),
                    label: const Text('Route'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  BayHopChip(label: stopLabel),
                  BayHopChip(label: '$duration min planned'),
                  if (first.category != null)
                    BayHopChip(label: first.category!),
                ],
              ),
            ],
          ),
        );
      },
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
    required this.locationController,
    required this.itineraryController,
    required this.actionDelegate,
    required this.onJourneySelected,
    required this.onRouteSavedItinerary,
    required this.onSuggestion,
  });

  final ConversationState state;
  final String? surfaceId;
  final GenUiSession session;
  final UserLocationController locationController;
  final ItineraryController? itineraryController;
  final ActionDelegate actionDelegate;
  final ValueChanged<TransitJourney> onJourneySelected;
  final VoidCallback onRouteSavedItinerary;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    if (state.isWaiting) return const _GeneratingResult();

    final id = surfaceId;
    if (id == null) {
      return _TransitIdleContentBuilder(
        locationController: locationController,
        itineraryController: itineraryController,
        builder: (context, content) {
          return _TransitIdleResult(
            content: content,
            onAction: (action) {
              if (action.actionKey == 'route_saved_itinerary') {
                onRouteSavedItinerary();
                return;
              }
              onSuggestion(action.query);
            },
          );
        },
      );
    }

    return TransitRouteSelectionScope(
      onJourneySelected: onJourneySelected,
      child: Surface(
        surfaceContext: session.contextFor(id),
        actionDelegate: actionDelegate,
      ),
    );
  }
}

class _TransitIdleContentBuilder extends StatelessWidget {
  const _TransitIdleContentBuilder({
    required this.locationController,
    required this.itineraryController,
    required this.builder,
  });

  static const _generator = _TransitIdleContentGenerator();

  final UserLocationController locationController;
  final ItineraryController? itineraryController;
  final Widget Function(BuildContext, _TransitIdleContent) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LocationSnapshot>(
      valueListenable: locationController,
      builder: (context, snapshot, _) {
        final itinerary = itineraryController;
        if (itinerary == null) {
          return builder(
            context,
            _generator.generate(
              location: snapshot,
              itineraryStops: const [],
            ),
          );
        }

        return ValueListenableBuilder<List<ItineraryStop>>(
          valueListenable: itinerary,
          builder: (context, stops, _) {
            return builder(
              context,
              _generator.generate(
                location: snapshot,
                itineraryStops: stops,
              ),
            );
          },
        );
      },
    );
  }
}

class _TransitIdleContentGenerator {
  const _TransitIdleContentGenerator();

  static const _starterRoute = _TransitIdleAction(
    actionKey: 'starter_route',
    title: 'Downtown Berkeley → SFO',
    subtitle: 'Trip · fastest 58 min',
    query: 'Downtown Berkeley to SFO, leave now',
    icon: Icons.alt_route_rounded,
    tint: Color(0x1FED1C24),
    iconColor: BayHopColors.red,
  );

  static const _starterDepartures = _TransitIdleAction(
    actionKey: 'starter_departures',
    title: 'Next trains from Embarcadero',
    subtitle: 'Live departures',
    query: 'Next trains from Embarcadero',
    icon: Icons.departure_board_rounded,
    tint: Color(0x1F0091D2),
    iconColor: BayHopColors.aiBlue,
  );

  static const _starterStatus = _TransitIdleAction(
    actionKey: 'starter_status',
    title: 'Is the Yellow Line delayed?',
    subtitle: 'Service status',
    query: 'Is the Yellow Line delayed?',
    icon: Icons.warning_amber_rounded,
    tint: Color(0x24E8920B),
    iconColor: BayHopColors.warn,
  );

  _TransitIdleContent generate({
    required LocationSnapshot location,
    required List<ItineraryStop> itineraryStops,
  }) {
    final nearest = _nearestStopFor(location);
    final hasItinerary = itineraryStops.isNotEmpty;

    if (nearest != null && hasItinerary) {
      return _TransitIdleContent(
        headline: 'Ready near ${nearest.stop.name}',
        actions: [
          _routeSavedItinerary(itineraryStops),
          _nearbyDepartures(nearest),
          _starterStatus,
        ],
      );
    }

    if (nearest != null) {
      return _TransitIdleContent(
        headline: 'Ready near ${nearest.stop.name}',
        actions: [
          _nearbyDepartures(nearest),
          _starterRoute,
          _starterStatus,
        ],
      );
    }

    if (hasItinerary) {
      return _TransitIdleContent(
        headline: 'Saved itinerary ready',
        actions: [
          _routeSavedItinerary(itineraryStops),
          _starterDepartures,
          _starterStatus,
        ],
      );
    }

    return const _TransitIdleContent(
      headline: 'Where are you headed?',
      subhead: 'Ask for trips, live departures, or service status.',
      actions: [
        _starterRoute,
        _starterDepartures,
        _starterStatus,
      ],
    );
  }

  NearestTransitStop? _nearestStopFor(LocationSnapshot snapshot) {
    if (!snapshot.hasLocation) return null;
    return snapshot.nearestStop;
  }

  _TransitIdleAction _routeSavedItinerary(List<ItineraryStop> stops) {
    final stopLabel = stops.length == 1
        ? '1 saved stop'
        : '${stops.length} saved stops';

    return _TransitIdleAction(
      actionKey: 'route_saved_itinerary',
      title: 'Route saved itinerary',
      subtitle: 'Trip · $stopLabel',
      query: transitRouteRequestFor(stops)!,
      icon: Icons.bookmark_added_rounded,
      tint: const Color(0x22A855F7),
      iconColor: BayHopColors.aiPurple,
    );
  }

  _TransitIdleAction _nearbyDepartures(NearestTransitStop nearest) {
    final stop = nearest.stop;

    return _TransitIdleAction(
      actionKey: 'nearby_departures',
      title: 'Next departures from ${stop.name}',
      subtitle: '${stop.modeLabel} · ${nearest.distanceLabel} away',
      query: 'Next departures from ${stop.name}',
      icon: Icons.departure_board_rounded,
      tint: const Color(0x1F0091D2),
      iconColor: BayHopColors.aiBlue,
    );
  }
}

class _TransitIdleContent {
  const _TransitIdleContent({
    required this.headline,
    required this.actions,
    this.subhead,
  });

  final String headline;
  final String? subhead;
  final List<_TransitIdleAction> actions;
}

class _TransitIdleAction {
  const _TransitIdleAction({
    required this.actionKey,
    required this.title,
    required this.subtitle,
    required this.query,
    required this.icon,
    required this.tint,
    required this.iconColor,
  });

  final String actionKey;
  final String title;
  final String subtitle;
  final String query;
  final IconData icon;
  final Color tint;
  final Color iconColor;
}

/// Shown before any request: contextual prompts plus tappable actions.
class _TransitIdleResult extends StatelessWidget {
  const _TransitIdleResult({
    required this.content,
    required this.onAction,
  });

  final _TransitIdleContent content;
  final ValueChanged<_TransitIdleAction> onAction;

  @override
  Widget build(BuildContext context) {
    final subhead = content.subhead;

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
                    content.headline,
                    style: BayHopText.display(size: 19),
                  ),
                  if (subhead != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subhead,
                      style: BayHopText.body(
                        size: 13,
                        color: BayHopColors.muted,
                      ),
                    ),
                  ],
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
        for (final action in content.actions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TransitIdleActionTile(
              key: ValueKey('idle-action-${action.actionKey}'),
              action: action,
              onTap: () => onAction(action),
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
    required this.locationController,
    required this.itineraryController,
    required this.onSend,
    required this.onRouteSavedItinerary,
  });

  final TextEditingController controller;
  final bool isProcessing;
  final UserLocationController locationController;
  final ItineraryController? itineraryController;
  final ValueChanged<String> onSend;
  final VoidCallback onRouteSavedItinerary;

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

  void _pickAction(_TransitIdleAction action) {
    _focus.unfocus();
    if (action.actionKey == 'route_saved_itinerary') {
      widget.onRouteSavedItinerary();
      return;
    }
    widget.onSend(action.query);
  }

  @override
  Widget build(BuildContext context) {
    return TextFieldTapRegion(
      child: Column(
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
                    const BayHopLogo(size: 23),
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
            _SearchSuggestions(
              locationController: widget.locationController,
              itineraryController: widget.itineraryController,
              onPick: _pickAction,
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchSuggestions extends StatelessWidget {
  const _SearchSuggestions({
    required this.locationController,
    required this.itineraryController,
    required this.onPick,
  });

  final UserLocationController locationController;
  final ItineraryController? itineraryController;
  final ValueChanged<_TransitIdleAction> onPick;

  @override
  Widget build(BuildContext context) {
    return _TransitIdleContentBuilder(
      locationController: locationController,
      itineraryController: itineraryController,
      builder: (context, content) {
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
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Row(
                    children: [
                      const BayHopWordmark(
                        markSize: 20,
                        fontSize: 16,
                        gap: 9,
                      ),
                      const Spacer(),
                      Text(
                        'TRY ASKING',
                        style: BayHopText.body(
                          size: 10.5,
                          weight: FontWeight.w700,
                          color: BayHopColors.faint,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final action in content.actions)
                  _TransitIdleActionTile(
                    key: ValueKey('search-suggestion-${action.actionKey}'),
                    action: action,
                    onTap: () => onPick(action),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TransitIdleActionTile extends StatelessWidget {
  const _TransitIdleActionTile({
    required this.action,
    required this.onTap,
    super.key,
  });

  final _TransitIdleAction action;
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
                  color: action.tint,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  action.icon,
                  size: 18,
                  color: action.iconColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BayHopText.body(
                        size: 14.5,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      action.subtitle,
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

class _TransitActionDelegate implements ActionDelegate {
  const _TransitActionDelegate({
    required this.onOpenExplore,
    required this.itineraryController,
  });

  final ValueChanged<String>? onOpenExplore;
  final ItineraryController? itineraryController;

  @override
  bool handleEvent(
    BuildContext context,
    UiEvent event,
    SurfaceContext genUiContext,
    Widget Function(SurfaceDefinition, Catalog, String, DataContext)
    buildWidget,
  ) {
    if (event is! UserActionEvent) return false;

    switch (event.name) {
      case 'open_explore':
        final query = _actionString(event.context['query']);
        if (query == null) return false;
        onOpenExplore?.call(query);
        return true;

      case 'explore_place':
        final title =
            _actionString(event.context['displayName']) ??
            _actionString(event.context['title']);
        if (title == null) return false;
        onOpenExplore?.call('Explore around $title');
        return true;

      case 'add_itinerary_stop':
        final itinerary = itineraryController;
        if (itinerary == null) return false;

        final added = itinerary.addFromAction(
          _itineraryContext(event.context),
        );
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              added ? 'Added to itinerary' : 'Already in itinerary',
            ),
          ),
        );
        return true;
    }

    return false;
  }

  String? _actionString(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  Map<String, Object?> _itineraryContext(JsonMap context) {
    final place = context['place'];
    if (place is Map) {
      return place.map((key, value) => MapEntry(key.toString(), value));
    }
    return context;
  }
}
