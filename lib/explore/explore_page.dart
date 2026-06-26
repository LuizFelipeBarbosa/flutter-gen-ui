import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/conversation.dart';
import 'package:genui_template/explore/explore_catalog.dart';
import 'package:genui_template/explore/explore_handoff_controller.dart';
import 'package:genui_template/explore/explore_prompt.dart';
import 'package:genui_template/explore/explore_widgets.dart';
import 'package:genui_template/explore/itinerary.dart';
import 'package:genui_template/location/location.dart';
import 'package:genui_template/model/inception_model_client.dart';
import 'package:genui_template/transit/bayhop_atoms.dart';
import 'package:genui_template/transit/bayhop_tokens.dart';

const List<String> _exploreSuggestions = [
  'Surprise me with a transit-friendly mini adventure',
  'Build a snack quest with views near me',
  'Plan a playful Oakland food crawl',
  'Turn Berkeley by BART into a side-quest',
];

class ExplorePage extends StatefulWidget {
  const ExplorePage({
    required this.itineraryController,
    required this.locationListenable,
    this.handoffController,
    this.onRouteInTransit,
    super.key,
  });

  final ItineraryController itineraryController;
  final ValueListenable<LocationSnapshot> locationListenable;
  final ExploreHandoffController? handoffController;
  final VoidCallback? onRouteInTransit;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  late final GenUiSession _session;
  late ActionDelegate _actionDelegate;
  final _textController = TextEditingController();
  StreamSubscription<ConversationEvent>? _eventsSub;
  int? _lastHandoffId;

  @override
  void initState() {
    super.initState();
    _actionDelegate = _ExploreActionDelegate(widget.itineraryController);
    _session = GenUiSession(
      catalogBuilder: buildExploreCatalog,
      systemPrompt: exploreSystemPrompt,
      contextProvider: _contextForModel,
      modelClientBuilder: InceptionModelClient.new,
    );

    _eventsSub = _session.events.listen((event) {
      if (event is ConversationError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Explore request failed: ${event.error}')),
        );
      }
    });

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
    unawaited(_eventsSub?.cancel());
    widget.handoffController?.removeListener(_handleExploreHandoff);
    _textController.dispose();
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
    _session.sendMessage(request);
    _textController.clear();
    FocusScope.of(context).unfocus();
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

        return LayoutBuilder(
          builder: (context, constraints) {
            final itinerary = _ItineraryPanel(
              controller: widget.itineraryController,
              onRouteInTransit: widget.onRouteInTransit,
            );
            final explorer = _ExplorerSurface(
              state: state,
              surfaceId: surfaceId,
              session: _session,
              actionDelegate: _actionDelegate,
              textController: _textController,
              onSend: _sendMessage,
            );

            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  Expanded(child: explorer),
                  SizedBox(
                    height: 230,
                    child: itinerary,
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
    required this.session,
    required this.actionDelegate,
    required this.textController,
    required this.onSend,
  });

  final ConversationState state;
  final String? surfaceId;
  final GenUiSession session;
  final ActionDelegate actionDelegate;
  final TextEditingController textController;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BayHopColors.bgTop,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _ExploreComposer(
                controller: textController,
                isProcessing: state.isWaiting,
                onSend: onSend,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: _GeneratedExploreContent(
                      state: state,
                      surfaceId: surfaceId,
                      session: session,
                      actionDelegate: actionDelegate,
                      onSend: onSend,
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

class _GeneratedExploreContent extends StatelessWidget {
  const _GeneratedExploreContent({
    required this.state,
    required this.surfaceId,
    required this.session,
    required this.actionDelegate,
    required this.onSend,
  });

  final ConversationState state;
  final String? surfaceId;
  final GenUiSession session;
  final ActionDelegate actionDelegate;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    if (state.isWaiting) return const _ExploreLoadingState();

    final id = surfaceId;
    if (id == null) return _ExploreIntro(onSend: onSend);

    return Surface(
      surfaceContext: session.contextFor(id),
      actionDelegate: actionDelegate,
    );
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
              title: suggestion,
              query: suggestion,
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
    if (event is! UserActionEvent || !_isAddToItineraryAction(event.name)) {
      return false;
    }

    final added = itinerary.addFromAction(_itineraryContext(event.context));
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(added ? 'Added to itinerary' : 'Already in itinerary'),
      ),
    );
    return true;
  }

  bool _isAddToItineraryAction(String name) {
    return name == 'add_itinerary_stop';
  }

  Map<String, Object?> _itineraryContext(JsonMap context) {
    final place = context['place'];
    if (place is Map) {
      return place.map((key, value) => MapEntry(key.toString(), value));
    }
    return context;
  }
}
