import 'dart:async';
import 'dart:convert';

import 'package:bayhop/conversation.dart';
import 'package:bayhop/explore/explore_catalog.dart';
import 'package:bayhop/explore/explore_handoff_controller.dart';
import 'package:bayhop/explore/explore_prompt.dart';
import 'package:bayhop/explore/explore_widgets.dart';
import 'package:bayhop/explore/itinerary.dart';
import 'package:bayhop/location/location.dart';
import 'package:bayhop/model/inception_model_client.dart';
import 'package:bayhop/model/model_client.dart';
import 'package:bayhop/transit/bayhop_atoms.dart';
import 'package:bayhop/transit/bayhop_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

const List<_ExploreStarterSuggestion> _exploreSuggestions = [
  _ExploreStarterSuggestion(
    title: 'Surprise me with a transit-friendly mini adventure',
    placeQuery: 'Lake Merritt Oakland',
  ),
  _ExploreStarterSuggestion(
    title: 'Build a snack quest with views near me',
    placeQuery: 'Ferry Building San Francisco',
  ),
  _ExploreStarterSuggestion(
    title: 'Plan a playful Oakland food crawl',
    placeQuery: "Swan's Market Oakland",
  ),
  _ExploreStarterSuggestion(
    title: 'Turn Berkeley by BART into a side-quest',
    placeQuery: 'Berkeley Art Museum and Pacific Film Archive',
  ),
];

class _ExploreStarterSuggestion {
  const _ExploreStarterSuggestion({
    required this.title,
    required this.placeQuery,
  });

  final String title;
  final String placeQuery;
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({
    required this.itineraryController,
    required this.locationListenable,
    this.handoffController,
    this.onRouteInTransit,
    this.modelClientBuilder,
    super.key,
  });

  final ItineraryController itineraryController;
  final ValueListenable<LocationSnapshot> locationListenable;
  final ExploreHandoffController? handoffController;
  final VoidCallback? onRouteInTransit;
  final ModelClient Function({required String systemPrompt})?
  modelClientBuilder;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  late final Catalog _catalog = buildExploreCatalog();
  late final GenUiSession _session;
  late ActionDelegate _actionDelegate;
  final _textController = TextEditingController();
  final _latestSurfaceDefinitions = <String, SurfaceDefinition>{};
  final _history = <_ExploreSurfaceSnapshot>[];
  StreamSubscription<ConversationEvent>? _eventsSub;
  int? _lastHandoffId;
  int _historyIndex = -1;
  bool _mobileItineraryExpanded = false;
  String _latestRequest = '';

  @override
  void initState() {
    super.initState();
    _actionDelegate = _ExploreActionDelegate(widget.itineraryController);
    _session = GenUiSession(
      catalogBuilder: () => _catalog,
      systemPrompt: exploreSystemPrompt,
      contextProvider: _contextForModel,
      modelClientBuilder: widget.modelClientBuilder ?? InceptionModelClient.new,
    );

    _eventsSub = _session.events.listen((event) {
      switch (event) {
        case ConversationSurfaceAdded(:final surfaceId, :final definition):
          _latestSurfaceDefinitions[surfaceId] = definition;
          _syncHistoryWithConversation();
        case ConversationComponentsUpdated(:final surfaceId, :final definition):
          _latestSurfaceDefinitions[surfaceId] = definition;
          _syncHistoryWithConversation();
        case _:
      }

      if (event is ConversationError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Explore request failed: ${event.error}')),
        );
      }
    });
    _session.conversationState.addListener(_syncHistoryWithConversation);

    widget.handoffController?.addListener(_handleExploreHandoff);
    _handleExploreHandoff();
  }

  @override
  void didUpdateWidget(covariant ExplorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itineraryController != widget.itineraryController) {
      _actionDelegate = _ExploreActionDelegate(widget.itineraryController);
    }

    if (oldWidget.handoffController != widget.handoffController) {
      oldWidget.handoffController?.removeListener(_handleExploreHandoff);
      widget.handoffController?.addListener(_handleExploreHandoff);
      _handleExploreHandoff();
    }
  }

  @override
  void dispose() {
    _session.conversationState.removeListener(_syncHistoryWithConversation);
    unawaited(_eventsSub?.cancel());
    widget.handoffController?.removeListener(_handleExploreHandoff);
    _textController.dispose();
    for (final snapshot in _history) {
      snapshot.dispose();
    }
    _session.dispose();
    super.dispose();
  }

  String _contextForModel() {
    return [
      _locationContextForModel(),
      widget.itineraryController.toPromptContext(),
    ].join(' ');
  }

  String _locationContextForModel() {
    return widget.locationListenable.value.promptContext ??
        'User location snapshot: unavailable (location has not been shared). '
            "Do not infer the user's current neighborhood.";
  }

  void _sendMessage(String text) {
    final request = text.trim();
    if (request.isEmpty) return;
    _truncateForwardHistory();
    _latestRequest = request;
    unawaited(_session.sendMessage(request));
    _textController.clear();
    FocusScope.of(context).unfocus();
  }

  void _syncHistoryWithConversation() {
    final state = _session.conversationState.value;
    if (state.isWaiting || state.surfaces.isEmpty) return;

    final surfaceId = state.surfaces.last;
    final definition = _latestSurfaceDefinitions[surfaceId];
    if (definition == null || !definition.components.containsKey('root')) {
      return;
    }

    final signature = jsonEncode(definition.toJson());
    if (_history.isNotEmpty && _history.last.signature == signature) {
      if (_historyIndex != _history.length - 1 && mounted) {
        setState(() => _historyIndex = _history.length - 1);
      }
      return;
    }

    final liveContext = _session.contextFor(surfaceId);
    final snapshot = _ExploreSurfaceSnapshot(
      request: _latestRequest,
      signature: signature,
      context: _ExploreSnapshotSurfaceContext(
        surfaceId: surfaceId,
        definition: SurfaceDefinition.fromJson(definition.toJson()),
        catalog: _catalog,
        dataModel: liveContext.dataModel,
        onUiEvent: _session.handleUiEvent,
        onError: liveContext.reportError,
      ),
    );

    if (!mounted) {
      snapshot.dispose();
      return;
    }

    setState(() {
      _disposeForwardHistory();
      _history.add(snapshot);
      _historyIndex = _history.length - 1;
    });
  }

  void _goBack() {
    if (_historyIndex <= 0) return;
    setState(() => _historyIndex--);
  }

  void _truncateForwardHistory() {
    if (_historyIndex < 0 || _historyIndex >= _history.length - 1) return;
    setState(_disposeForwardHistory);
  }

  void _disposeForwardHistory() {
    final keepCount = _historyIndex + 1;
    if (keepCount >= _history.length) return;

    for (final snapshot in _history.skip(keepCount)) {
      snapshot.dispose();
    }
    _history.removeRange(keepCount, _history.length);
  }

  void _handleExploreHandoff() {
    final handoff = widget.handoffController?.value;
    if (handoff == null || handoff.id == _lastHandoffId) return;
    _lastHandoffId = handoff.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastHandoffId != handoff.id) return;
      _sendMessage(handoff.query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ConversationState>(
      valueListenable: _session.conversationState,
      builder: (context, state, _) {
        final surfaceId = state.surfaces.isEmpty ? null : state.surfaces.last;
        final selectedSnapshot = _historyIndex < 0
            ? null
            : _history[_historyIndex];

        return LayoutBuilder(
          builder: (context, constraints) {
            final itinerary = _ItineraryPanel(
              controller: widget.itineraryController,
              onRouteInTransit: widget.onRouteInTransit,
            );
            final explorer = _ExplorerSurface(
              state: state,
              surfaceId: surfaceId,
              snapshot: selectedSnapshot,
              session: _session,
              actionDelegate: _actionDelegate,
              textController: _textController,
              latestRequest: _latestRequest,
              onSend: _sendMessage,
              onBack: _goBack,
              canGoBack: _historyIndex > 0,
            );

            if (constraints.maxWidth < 900) {
              final bottomInset = MediaQuery.of(context).padding.bottom;
              final compactSheetHeight =
                  _MobileItinerarySheet.compactHeight + bottomInset;
              final sheetHeight = _mobileItineraryExpanded
                  ? _expandedMobileItineraryHeight(constraints.maxHeight) +
                        bottomInset
                  : compactSheetHeight;

              return Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: compactSheetHeight),
                      child: explorer,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _MobileItinerarySheet(
                      controller: widget.itineraryController,
                      height: sheetHeight,
                      expanded: _mobileItineraryExpanded,
                      onExpandedChanged: (expanded) {
                        setState(() => _mobileItineraryExpanded = expanded);
                      },
                      onRouteInTransit: widget.onRouteInTransit,
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: explorer),
                const VerticalDivider(width: 1, color: BayHopColors.hairline),
                SizedBox(width: 380, child: itinerary),
              ],
            );
          },
        );
      },
    );
  }
}

class _ExplorerSurface extends StatelessWidget {
  const _ExplorerSurface({
    required this.state,
    required this.surfaceId,
    required this.snapshot,
    required this.session,
    required this.actionDelegate,
    required this.textController,
    required this.latestRequest,
    required this.onSend,
    required this.onBack,
    required this.canGoBack,
  });

  final ConversationState state;
  final String? surfaceId;
  final _ExploreSurfaceSnapshot? snapshot;
  final GenUiSession session;
  final ActionDelegate actionDelegate;
  final TextEditingController textController;
  final String latestRequest;
  final ValueChanged<String> onSend;
  final VoidCallback onBack;
  final bool canGoBack;

  @override
  Widget build(BuildContext context) {
    final sidePadding = BayHopResponsive.sidePaddingFor(context);
    return ColoredBox(
      color: BayHopColors.bgTop,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(sidePadding, 12, sidePadding, 8),
              child: _ExploreComposer(
                controller: textController,
                isProcessing: state.isWaiting,
                onSend: onSend,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, 8),
              child: _ExploreNavigationBar(
                canGoBack: canGoBack,
                onBack: onBack,
                onPrompt: onSend,
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      sidePadding,
                      8,
                      sidePadding,
                      24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: _exploreContentMaxWidth(
                            constraints.maxWidth,
                          ),
                        ),
                        child: _GeneratedExploreContent(
                          state: state,
                          surfaceId: surfaceId,
                          snapshot: snapshot,
                          session: session,
                          actionDelegate: actionDelegate,
                          latestRequest: latestRequest,
                          onSend: onSend,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _exploreContentMaxWidth(double availableWidth) {
  if (availableWidth < 760) return 680;
  if (availableWidth < 1100) return availableWidth - 32;
  return 1120;
}

class _GeneratedExploreContent extends StatelessWidget {
  const _GeneratedExploreContent({
    required this.state,
    required this.surfaceId,
    required this.snapshot,
    required this.session,
    required this.actionDelegate,
    required this.latestRequest,
    required this.onSend,
  });

  final ConversationState state;
  final String? surfaceId;
  final _ExploreSurfaceSnapshot? snapshot;
  final GenUiSession session;
  final ActionDelegate actionDelegate;
  final String latestRequest;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    if (state.isWaiting) return const _ExploreLoadingState();

    final id = surfaceId;
    final selectedSnapshot = snapshot;
    if (selectedSnapshot != null) {
      return _ExploreResultWithRemixes(
        request: selectedSnapshot.request,
        onSend: onSend,
        child: Surface(
          surfaceContext: selectedSnapshot.context,
          actionDelegate: actionDelegate,
        ),
      );
    }

    if (id == null) return _ExploreIntro(onSend: onSend);

    return _ExploreResultWithRemixes(
      request: latestRequest,
      onSend: onSend,
      child: Surface(
        surfaceContext: session.contextFor(id),
        actionDelegate: actionDelegate,
      ),
    );
  }
}

class _ExploreResultWithRemixes extends StatelessWidget {
  const _ExploreResultWithRemixes({
    required this.child,
    required this.request,
    required this.onSend,
  });

  final Widget child;
  final String request;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child,
        const SizedBox(height: 10),
        _ExploreRemixStrip(request: request, onSend: onSend),
      ],
    );
  }
}

const List<_ExploreRemixItem> _exploreRemixItems = [
  _ExploreRemixItem(
    label: 'More scenic',
    instruction:
        'Make it more scenic with views, waterfronts, overlooks, parks, or '
        'memorable visual moments.',
    icon: Icons.landscape_rounded,
  ),
  _ExploreRemixItem(
    label: 'Cheaper',
    instruction:
        'Make it cheaper with free or low-cost stops and fewer paid tickets.',
    icon: Icons.savings_rounded,
  ),
  _ExploreRemixItem(
    label: 'Foodier',
    instruction:
        'Make it foodier with snacks, cafes, bakeries, markets, or casual '
        'meal stops.',
    icon: Icons.restaurant_rounded,
  ),
  _ExploreRemixItem(
    label: 'Less walking',
    instruction:
        'Reduce the walking and favor short hops, close clusters, and easy '
        'transit connections.',
    icon: Icons.directions_walk_rounded,
  ),
  _ExploreRemixItem(
    label: 'Surprise twist',
    instruction:
        'Add one playful surprise twist while keeping the plan practical.',
    icon: Icons.auto_awesome_rounded,
  ),
];

class _ExploreRemixItem {
  const _ExploreRemixItem({
    required this.label,
    required this.instruction,
    required this.icon,
  });

  final String label;
  final String instruction;
  final IconData icon;
}

class _ExploreRemixStrip extends StatelessWidget {
  const _ExploreRemixStrip({
    required this.request,
    required this.onSend,
  });

  final String request;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return BayHopEdgeFadeChipStrip(
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _exploreRemixItems.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = _exploreRemixItems[index];
            return ActionChip(
              label: Text(item.label),
              avatar: Icon(item.icon, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: () => onSend(_remixPrompt(item, request)),
            );
          },
        ),
      ),
    );
  }
}

String _remixPrompt(_ExploreRemixItem item, String request) {
  final subject = _remixSubject(request);
  return 'Remix $subject. ${item.instruction} Keep it Bay Area and '
      'transit-friendly, preserve what still works from the current result, '
      'and render a fresh Explore answer.';
}

String _remixSubject(String request) {
  final normalized = request.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return 'the current Explore result';
  return 'the current Explore result/request "$normalized"';
}

const List<_ExploreNavItem> _exploreNavItems = [
  _ExploreNavItem(
    label: 'For You',
    prompt: 'Show personalized Bay Area exploration ideas for me.',
  ),
  _ExploreNavItem(
    label: 'One Shot',
    prompt:
        'Build a one shot transit-friendly Bay Area adventure. Preview every '
        'stop before adding anything to my itinerary.',
  ),
  _ExploreNavItem(
    label: 'Nearby',
    prompt: 'Find nearby mini adventures and grounded places.',
  ),
  _ExploreNavItem(
    label: 'Food',
    prompt: 'Explore food stops, snack crawls, and coffee nearby.',
  ),
  _ExploreNavItem(
    label: 'Views',
    prompt: 'Find scenic Bay Area views and transit-friendly lookout stops.',
  ),
  _ExploreNavItem(
    label: 'Culture',
    prompt: 'Explore museums, murals, music, bookstores, and culture stops.',
  ),
  _ExploreNavItem(
    label: 'Outdoors',
    prompt: 'Explore parks, waterfronts, hikes, and outdoor stops.',
  ),
  _ExploreNavItem(
    label: 'Saved Stops',
    prompt: 'Suggest branches that complement my saved itinerary stops.',
  ),
];

class _ExploreNavItem {
  const _ExploreNavItem({
    required this.label,
    required this.prompt,
  });

  final String label;
  final String prompt;
}

double _expandedMobileItineraryHeight(double maxHeight) {
  if (maxHeight < 520) return maxHeight * 0.72;
  return (maxHeight * 0.58).clamp(320.0, 430.0);
}

class _ExploreNavigationBar extends StatelessWidget {
  const _ExploreNavigationBar({
    required this.canGoBack,
    required this.onBack,
    required this.onPrompt,
  });

  final bool canGoBack;
  final VoidCallback onBack;
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    return BayHopEdgeFadeChipStrip(
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _exploreNavItems.length + (canGoBack ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (canGoBack && index == 0) {
              return IconButton.filledTonal(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              );
            }

            final item = _exploreNavItems[index - (canGoBack ? 1 : 0)];
            return ActionChip(
              label: Text(item.label),
              onPressed: () => onPrompt(item.prompt),
              avatar: _navIconFor(item.label),
              visualDensity: VisualDensity.compact,
            );
          },
        ),
      ),
    );
  }

  Widget? _navIconFor(String label) {
    final icon = switch (label) {
      'For You' => Icons.auto_awesome_rounded,
      'One Shot' => Icons.bolt_rounded,
      'Nearby' => Icons.near_me_rounded,
      'Food' => Icons.restaurant_rounded,
      'Views' => Icons.landscape_rounded,
      'Culture' => Icons.museum_rounded,
      'Outdoors' => Icons.park_rounded,
      'Saved Stops' => Icons.bookmark_rounded,
      _ => null,
    };
    if (icon == null) return null;
    return Icon(icon, size: 16);
  }
}

class _ExploreIntro extends StatelessWidget {
  const _ExploreIntro({required this.onSend});

  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ExploreSummaryCard(
          title: 'Bay Area Explorer',
          summary:
              'Pick a quest, ground real places with Google, save the best '
              'stops, then route the day in Transit.',
          badge: 'Explore',
        ),
        const SizedBox(height: 14),
        Text(
          'TRY EXPLORING',
          style: BayHopText.body(
            size: 10.5,
            weight: FontWeight.w700,
            color: BayHopColors.faint,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        for (final suggestion in _exploreSuggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ExplorerOptionCard(
              title: suggestion.title,
              query: suggestion.title,
              placeQuery: suggestion.placeQuery,
              badge: 'Start',
              onAction: (_, context) => onSend(context['query'].toString()),
            ),
          ),
      ],
    );
  }
}

class _ExploreLoadingState extends StatelessWidget {
  const _ExploreLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: bayHopCardDecoration(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BayHopSkeletonBar(width: 180, height: 16),
          SizedBox(height: 16),
          BayHopSkeletonBar(width: double.infinity, height: 68, radius: 15),
          SizedBox(height: 10),
          BayHopSkeletonBar(width: double.infinity, height: 68, radius: 15),
        ],
      ),
    );
  }
}

class _ExploreComposer extends StatelessWidget {
  const _ExploreComposer({
    required this.controller,
    required this.isProcessing,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isProcessing;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return BayHopFrostedSurface(
      opacity: 0.86,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            const Icon(Icons.travel_explore_rounded, color: BayHopColors.ink2),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isProcessing,
                textInputAction: TextInputAction.search,
                onSubmitted: onSend,
                style: BayHopText.body(size: 15),
                decoration: InputDecoration.collapsed(
                  hintText: 'Explore a city, vibe, or stop...',
                  hintStyle: BayHopText.body(
                    size: 15,
                    color: BayHopColors.muted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Explore',
              onPressed: isProcessing ? null : () => onSend(controller.text),
              icon: isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItineraryPanel extends StatelessWidget {
  const _ItineraryPanel({
    required this.controller,
    this.onRouteInTransit,
  });

  final ItineraryController controller;
  final VoidCallback? onRouteInTransit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BayHopColors.surface,
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder<List<ItineraryStop>>(
          valueListenable: controller,
          builder: (context, stops, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Itinerary',
                          style: BayHopText.display(size: 18),
                        ),
                      ),
                      if (stops.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.filledTonal(
                              tooltip: 'Route in Transit',
                              onPressed: onRouteInTransit,
                              icon: const Icon(Icons.alt_route_rounded),
                            ),
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: controller.clear,
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (stops.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _ItineraryStats(stops: stops),
                  ),
                Expanded(
                  child: stops.isEmpty
                      ? const _EmptyItinerary()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          itemCount: stops.length,
                          itemBuilder: (context, index) {
                            return _ItineraryStopTile(
                              stop: stops[index],
                              index: index,
                              isFirst: index == 0,
                              isLast: index == stops.length - 1,
                              onMoveUp: () => controller.move(
                                stops[index].localId,
                                -1,
                              ),
                              onMoveDown: () => controller.move(
                                stops[index].localId,
                                1,
                              ),
                              onRemove: () =>
                                  controller.remove(stops[index].localId),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MobileItinerarySheet extends StatelessWidget {
  const _MobileItinerarySheet({
    required this.controller,
    required this.height,
    required this.expanded,
    required this.onExpandedChanged,
    this.onRouteInTransit,
  });

  static const double compactHeight = 112;

  final ItineraryController controller;
  final double height;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback? onRouteInTransit;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: height,
      decoration: const BoxDecoration(
        color: BayHopColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0x2414181C),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder<List<ItineraryStop>>(
          valueListenable: controller,
          builder: (context, stops, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MobileItineraryHeader(
                  stops: stops,
                  expanded: expanded,
                  onExpandedChanged: onExpandedChanged,
                  onRouteInTransit: onRouteInTransit,
                  onClear: controller.clear,
                ),
                if (expanded) ...[
                  if (stops.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _ItineraryStats(stops: stops),
                    ),
                  Expanded(
                    child: stops.isEmpty
                        ? const _EmptyItinerary()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                            itemCount: stops.length,
                            itemBuilder: (context, index) {
                              return _ItineraryStopTile(
                                stop: stops[index],
                                index: index,
                                isFirst: index == 0,
                                isLast: index == stops.length - 1,
                                onMoveUp: () => controller.move(
                                  stops[index].localId,
                                  -1,
                                ),
                                onMoveDown: () => controller.move(
                                  stops[index].localId,
                                  1,
                                ),
                                onRemove: () =>
                                    controller.remove(stops[index].localId),
                              );
                            },
                          ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MobileItineraryHeader extends StatelessWidget {
  const _MobileItineraryHeader({
    required this.stops,
    required this.expanded,
    required this.onExpandedChanged,
    required this.onClear,
    this.onRouteInTransit,
  });

  final List<ItineraryStop> stops;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback onClear;
  final VoidCallback? onRouteInTransit;

  @override
  Widget build(BuildContext context) {
    final stopLabel = stops.length == 1 ? '1 stop' : '${stops.length} stops';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onExpandedChanged(!expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 9),
                        decoration: BoxDecoration(
                          color: BayHopColors.hairline,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Itinerary',
                          style: BayHopText.display(size: 17),
                        ),
                        const SizedBox(width: 8),
                        BayHopChip(label: stopLabel),
                      ],
                    ),
                  ],
                ),
              ),
              if (expanded && stops.isNotEmpty) ...[
                IconButton.filledTonal(
                  tooltip: 'Route in Transit',
                  onPressed: onRouteInTransit,
                  icon: const Icon(Icons.alt_route_rounded),
                ),
                TextButton(
                  onPressed: onClear,
                  child: const Text('Clear'),
                ),
              ],
              IconButton(
                tooltip: expanded ? 'Collapse itinerary' : 'Expand itinerary',
                onPressed: () => onExpandedChanged(!expanded),
                icon: Icon(
                  expanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyItinerary extends StatelessWidget {
  const _EmptyItinerary();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Text(
        'Add places from generated Google result cards. Saved stops stay in '
        'this app and can be routed from Transit.',
        style: BayHopText.body(color: BayHopColors.muted, height: 1.35),
      ),
    );
  }
}

class _ItineraryStats extends StatelessWidget {
  const _ItineraryStats({required this.stops});

  final List<ItineraryStop> stops;

  @override
  Widget build(BuildContext context) {
    final duration = stops.fold<int>(
      0,
      (total, stop) => total + stop.durationMinutes,
    );
    final stopLabel = stops.length == 1 ? '1 stop' : '${stops.length} stops';
    final hours = duration ~/ 60;
    final minutes = duration % 60;
    final durationLabel = hours == 0
        ? '$minutes min'
        : minutes == 0
        ? '${hours}h'
        : '${hours}h ${minutes}m';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        BayHopChip(label: stopLabel),
        BayHopChip(label: durationLabel),
        if (stops.first.category != null)
          BayHopChip(label: 'Starts ${stops.first.category!}'),
      ],
    );
  }
}

class _ItineraryStopTile extends StatelessWidget {
  const _ItineraryStopTile({
    required this.stop,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final ItineraryStop stop;
  final int index;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BayHopColors.bgTop,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: BayHopColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}',
            style: BayHopText.mono(
              size: 16,
              weight: FontWeight.w800,
              color: BayHopColors.ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BayHopText.body(weight: FontWeight.w800),
                ),
                if (stop.address != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    stop.address!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BayHopText.body(
                      size: 12,
                      color: BayHopColors.muted,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Move up',
                onPressed: isFirst ? null : onMoveUp,
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
              IconButton(
                tooltip: 'Move down',
                onPressed: isLast ? null : onMoveDown,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExploreSurfaceSnapshot {
  _ExploreSurfaceSnapshot({
    required this.request,
    required this.signature,
    required this.context,
  });

  final String request;
  final String signature;
  final _ExploreSnapshotSurfaceContext context;

  void dispose() {
    context.dispose();
  }
}

class _ExploreSnapshotSurfaceContext implements SurfaceContext {
  _ExploreSnapshotSurfaceContext({
    required this.surfaceId,
    required SurfaceDefinition definition,
    required this._catalog,
    required this.dataModel,
    required this._onUiEvent,
    required this._onError,
  }) : _definition = ValueNotifier(definition);

  final ValueNotifier<SurfaceDefinition?> _definition;
  final Catalog _catalog;
  final void Function(UiEvent event) _onUiEvent;
  final void Function(Object error, StackTrace? stackTrace) _onError;

  @override
  final String surfaceId;

  @override
  final DataModel dataModel;

  @override
  ValueListenable<SurfaceDefinition?> get definition => _definition;

  @override
  Catalog? get catalog => _catalog;

  @override
  void handleUiEvent(UiEvent event) {
    _onUiEvent(event);
  }

  @override
  void reportError(Object error, StackTrace? stack) {
    _onError(error, stack);
  }

  void dispose() {
    _definition.dispose();
  }
}

class _ExploreActionDelegate implements ActionDelegate {
  const _ExploreActionDelegate(this.itinerary);

  final ItineraryController itinerary;

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
      case 'add_itinerary_stop':
        final added = itinerary.addFromAction(_itineraryContext(event.context));
        _showSnackBar(
          context,
          added ? 'Added to itinerary' : 'Already in itinerary',
        );
        return true;

      case 'add_itinerary_stops':
        final result = itinerary.addFromActions(
          _itineraryContexts(event.context['stops']),
        );
        _showSnackBar(context, _bulkAddMessage(result));
        return true;
    }

    return false;
  }

  Map<String, Object?> _itineraryContext(JsonMap context) {
    final place = context['place'];
    if (place is Map) {
      return place.map((key, value) => MapEntry(key.toString(), value));
    }
    return context;
  }

  List<Map<String, Object?>> _itineraryContexts(Object? value) {
    if (value is! List) return const [];

    return [
      for (final item in value)
        if (item is Map)
          _itineraryContext(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
    ];
  }

  String _bulkAddMessage(ItineraryAddResult result) {
    if (result.added == 0) return 'All stops already in itinerary';

    final addedLabel = result.added == 1
        ? 'Added 1 stop'
        : 'Added ${result.added} stops';
    if (result.skipped == 0) return addedLabel;

    final skippedLabel = result.skipped == 1
        ? 'skipped 1 duplicate'
        : 'skipped ${result.skipped} duplicates';
    return '$addedLabel, $skippedLabel';
  }

  void _showSnackBar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}
