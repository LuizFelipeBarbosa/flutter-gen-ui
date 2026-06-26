import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/conversation.dart';
import 'package:genui_template/model/featherless_model_client.dart';
import 'package:genui_template/widgets/widgets.dart';

const List<String> _suggestions = [
  'Next trains from Embarcadero',
  'Live Muni departures at stop 15184',
  'Next AC Transit buses at my stop',
  'Departures at 12th St Oakland',
  'Downtown Berkeley to SFO',
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final GenUiSession _session;
  final _textController = TextEditingController();
  StreamSubscription<ConversationEvent>? _eventsSub;

  @override
  void initState() {
    super.initState();

    _session = GenUiSession(modelClientBuilder: FeatherlessModelClient.new);

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
    _textController.dispose();
    _session.dispose();
    super.dispose();
  }

  void sendMessage(String text) {
    final request = text.trim();
    if (request.isEmpty) return;

    _session.sendMessage(request);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.train_rounded),
            SizedBox(width: 10),
            Text('Bay Area Transit'),
          ],
        ),
      ),
      body: ValueListenableBuilder<ConversationState>(
        valueListenable: _session.conversationState,
        builder: (context, state, _) {
          final latestSurfaceId = state.surfaces.isEmpty
              ? null
              : state.surfaces.last;

          return Column(
            children: [
              Expanded(
                child: _TransitWorkspace(
                  isProcessing: state.isWaiting,
                  latestSurfaceId: latestSurfaceId,
                  session: _session,
                ),
              ),
              if (state.isWaiting) const LinearProgressIndicator(minHeight: 2),
              MessageInput(
                controller: _textController,
                isProcessing: state.isWaiting,
                onSend: sendMessage,
                suggestions: _suggestions,
                hintText: 'Try "Mission to the airport"...',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TransitWorkspace extends StatelessWidget {
  const _TransitWorkspace({
    required this.isProcessing,
    required this.latestSurfaceId,
    required this.session,
  });

  final bool isProcessing;
  final String? latestSurfaceId;
  final GenUiSession session;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final surfacePane = _SurfacePane(
          isProcessing: isProcessing,
          latestSurfaceId: latestSurfaceId,
          session: session,
        );

        if (constraints.maxWidth < 900) return surfacePane;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: surfacePane),
            const VerticalDivider(width: 1),
            SizedBox(
              width: 420,
              child: isProcessing
                  ? const SizedBox.shrink()
                  : A2uiSourceView(source: session.a2uiSource),
            ),
          ],
        );
      },
    );
  }
}

class _SurfacePane extends StatelessWidget {
  const _SurfacePane({
    required this.isProcessing,
    required this.latestSurfaceId,
    required this.session,
  });

  final bool isProcessing;
  final String? latestSurfaceId;
  final GenUiSession session;

  @override
  Widget build(BuildContext context) {
    if (isProcessing) return const _TransitLoadingState();

    final surfaceId = latestSurfaceId;
    if (surfaceId == null) {
      return const _TransitEmptyState();
    }

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Surface(surfaceContext: session.contextFor(surfaceId)),
          ),
        ),
      ),
    );
  }
}

class _TransitEmptyState extends StatelessWidget {
  const _TransitEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Where are you headed?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Ask for BART, Muni, Caltrain, bus, ferry, or VTA trips, '
                  'departures, and line status in plain language.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransitLoadingState extends StatelessWidget {
  const _TransitLoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reading the request and assembling the screen...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
