import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui_template/transit/bart_departures_client.dart';
import 'package:genui_template/transit/transit_lines.dart';

class TransitSummaryCard extends StatelessWidget {
  const TransitSummaryCard({
    required this.summary,
    this.intent = 'trip',
    this.sourceLabel,
    super.key,
  });

  factory TransitSummaryCard.fromJson(Map<String, Object?> json) {
    return TransitSummaryCard(
      intent: _string(json['intent'], 'trip'),
      summary: _string(json['summary']),
      sourceLabel: _nullableString(json['sourceLabel']),
    );
  }

  final String intent;
  final String summary;
  final String? sourceLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = sourceLabel ?? intent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Pill(
            icon: Icons.auto_awesome_rounded,
            label: label,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            summary,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class TransitJourneyCard extends StatefulWidget {
  const TransitJourneyCard({required this.journey, super.key});

  factory TransitJourneyCard.fromJson(Map<String, Object?> json) {
    return TransitJourneyCard(journey: TransitJourney.fromJson(json));
  }

  final TransitJourney journey;

  @override
  State<TransitJourneyCard> createState() => _TransitJourneyCardState();
}

class _TransitJourneyCardState extends State<TransitJourneyCard> {
  late bool _isOpen = widget.journey.recommended;

  @override
  void didUpdateWidget(covariant TransitJourneyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_journeyStateKey(oldWidget.journey) !=
        _journeyStateKey(widget.journey)) {
      _isOpen = widget.journey.recommended;
    }
  }

  @override
  Widget build(BuildContext context) {
    final journey = widget.journey;
    final theme = Theme.of(context);
    final timeline = journey.timeline;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _isOpen = !_isOpen),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(
            context,
            emphasized: _isOpen || journey.recommended,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DurationBadge(duration: journey.duration),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${journey.depart} -> ${timeline.arrive}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (journey.recommended)
                              const _StatusChip(
                                label: 'Recommended',
                                color: Color(0xFF3DD17F),
                              ),
                            if (journey.tag.isNotEmpty)
                              _StatusChip(
                                label: journey.tag,
                                icon: journey.tag.toLowerCase() == 'fastest'
                                    ? Icons.bolt_rounded
                                    : null,
                                color: theme.colorScheme.primary,
                              ),
                            _MutedChip(label: journey.factsLabel),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _JourneyStrip(journey: journey, timeline: timeline),
              if (_isOpen) ...[
                const SizedBox(height: 16),
                _JourneySteps(timeline: timeline),
                if (journey.crowd.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _CrowdIndicator(crowd: journey.crowd),
                      const Spacer(),
                      _MutedChip(label: 'Depart ${journey.depart}'),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TransitDeparturesCard extends StatelessWidget {
  const TransitDeparturesCard({
    required this.station,
    required this.departures,
    this.live = false,
    super.key,
  });

  factory TransitDeparturesCard.fromJson(Map<String, Object?> json) {
    return TransitDeparturesCard(
      station: _string(json['station'], 'Station'),
      live: _bool(json['live'], fallback: false),
      departures: _mapList(
        json['list'],
      ).map(TransitDeparture.fromJson).toList(),
    );
  }

  factory TransitDeparturesCard.fromBartBoard(BartDepartureBoard board) {
    return TransitDeparturesCard(
      station: board.station,
      live: board.live,
      departures: [
        for (final departure in board.departures)
          TransitDeparture(
            line: departure.line,
            destination: departure.destination,
            platform: departure.platform,
            minutes: departure.minutes,
            live: departure.live,
          ),
      ],
    );
  }

  final String station;
  final List<TransitDeparture> departures;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: _cardDecoration(context),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.place_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  station,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (live)
                const _LivePill()
              else
                const _MutedChip(label: 'Planned'),
            ],
          ),
          const SizedBox(height: 8),
          for (final departure in departures)
            _DepartureRow(departure: departure),
        ],
      ),
    );
  }
}

class LiveBartDeparturesBoard extends StatefulWidget {
  const LiveBartDeparturesBoard({
    required this.stationAbbr,
    this.stationName,
    this.client,
    super.key,
  });

  factory LiveBartDeparturesBoard.fromJson(Map<String, Object?> json) {
    return LiveBartDeparturesBoard(
      stationAbbr: _string(json['stationAbbr'], 'EMBR'),
      stationName: _nullableString(json['stationName']),
    );
  }

  final String stationAbbr;
  final String? stationName;
  final BartDeparturesClient? client;

  @override
  State<LiveBartDeparturesBoard> createState() =>
      _LiveBartDeparturesBoardState();
}

class _LiveBartDeparturesBoardState extends State<LiveBartDeparturesBoard> {
  late final BartDeparturesClient _client =
      widget.client ?? BartDeparturesClient();
  Timer? _refreshTimer;
  BartDepartureBoard? _board;
  Object? _error;
  DateTime? _updatedAt;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_load()),
    );
  }

  @override
  void didUpdateWidget(covariant LiveBartDeparturesBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stationAbbr != widget.stationAbbr) {
      _board = null;
      _error = null;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (widget.client == null) _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    final requestedStation = widget.stationAbbr;
    setState(() {
      _loading = _board == null;
      _error = null;
    });

    try {
      final board = await _client.fetchDepartures(requestedStation);
      if (!mounted || widget.stationAbbr != requestedStation) return;
      setState(() {
        _board = board;
        _updatedAt = DateTime.now();
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || widget.stationAbbr != requestedStation) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    if (_loading && board == null) {
      return const _LoadingCard(message: 'Reaching BART real-time feed...');
    }

    if (board == null) {
      return TransitNoteCard(
        tone: TransitNoteTone.warning,
        text:
            'Could not reach BART live departures for '
            '${widget.stationName ?? widget.stationAbbr}: $_error',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: _LiveHeader(updatedAt: _updatedAt, retrying: _error != null),
        ),
        TransitDeparturesCard.fromBartBoard(board),
      ],
    );
  }
}

class TransitAlertCard extends StatelessWidget {
  const TransitAlertCard({
    required this.line,
    required this.status,
    required this.detail,
    super.key,
  });

  factory TransitAlertCard.fromJson(Map<String, Object?> json) {
    return TransitAlertCard(
      line: _string(json['line'], 'bart-yellow'),
      status: _string(json['status'], 'good'),
      detail: _string(json['detail']),
    );
  }

  final String line;
  final String status;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final transitLine = lineFor(line);
    final statusInfo = _AlertStatusInfo.fromStatus(status);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration(context),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: transitLine.color,
              child: const SizedBox(width: 4),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TransitLineBullet(id: line),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            transitLine.label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _StatusChip(
                          label: statusInfo.label,
                          color: statusInfo.color,
                          icon: statusInfo.icon,
                        ),
                      ],
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        detail,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum TransitNoteTone { neutral, warning }

class TransitNoteCard extends StatelessWidget {
  const TransitNoteCard({
    required this.text,
    this.tone = TransitNoteTone.neutral,
    super.key,
  });

  factory TransitNoteCard.fromJson(Map<String, Object?> json) {
    final tone = _string(json['tone']) == 'warning'
        ? TransitNoteTone.warning
        : TransitNoteTone.neutral;
    return TransitNoteCard(text: _string(json['text']), tone: tone);
  }

  final String text;
  final TransitNoteTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warning = tone == TransitNoteTone.warning;
    final color = warning ? const Color(0xFFFFB020) : theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: warning
                    ? const Color(0xFFFFD79A)
                    : theme.colorScheme.onSurfaceVariant,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TransitLineBullet extends StatelessWidget {
  const TransitLineBullet({
    required this.id,
    this.size = 24,
    super.key,
  });

  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    final line = lineFor(id);
    final isCircle = line.shape == TransitBulletShape.circle;
    final iconSize = size * 0.56;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: line.color,
        borderRadius: BorderRadius.circular(isCircle ? size / 2 : size * 0.28),
      ),
      child: isCircle
          ? Text(
              line.shortLabel,
              style: TextStyle(
                color: line.textColor,
                fontSize: size * 0.48,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            )
          : Icon(
              Icons.train_rounded,
              size: iconSize,
              color: line.textColor,
            ),
    );
  }
}

class TransitJourney {
  const TransitJourney({
    required this.from,
    required this.to,
    required this.depart,
    required this.arrive,
    required this.duration,
    required this.changes,
    required this.fare,
    required this.crowd,
    required this.legs,
    required this.recommended,
    required this.tag,
  });

  factory TransitJourney.fromJson(Map<String, Object?> json) {
    final legs = _mapList(json['legs']).map(TransitLeg.fromJson).toList();
    final duration = _int(
      json['duration'],
      fallback: legs.fold<int>(0, (total, leg) => total + leg.minutes),
    );

    return TransitJourney(
      from: _string(json['from'], 'Origin'),
      to: _string(json['to'], 'Destination'),
      depart: _string(json['depart'], '--:--'),
      arrive: _string(json['arrive']),
      duration: duration,
      changes: _int(json['changes']),
      fare: _string(json['fare']),
      crowd: _string(json['crowd']),
      legs: legs,
      recommended: _bool(json['recommended'], fallback: false),
      tag: _string(json['tag']),
    );
  }

  final String from;
  final String to;
  final String depart;
  final String arrive;
  final int duration;
  final int changes;
  final String fare;
  final String crowd;
  final List<TransitLeg> legs;
  final bool recommended;
  final String tag;

  TransitTimeline get timeline => TransitTimeline.fromJourney(this);

  TransitLeg? get firstRide {
    for (final leg in legs) {
      if (leg.type == TransitLegType.ride) return leg;
    }
    return null;
  }

  TransitLeg? get lastRide {
    for (final leg in legs.reversed) {
      if (leg.type == TransitLegType.ride) return leg;
    }
    return null;
  }

  String get fareLabel {
    if (fare.isEmpty) return '';
    return fare.startsWith(r'$') ? fare : '\$$fare';
  }

  String get factsLabel {
    final changeText = changes == 0
        ? 'Direct'
        : changes == 1
        ? '1 change'
        : '$changes changes';
    if (fareLabel.isEmpty) return changeText;
    return '$changeText - $fareLabel';
  }
}

enum TransitLegType { ride, change, walk }

class TransitLeg {
  const TransitLeg({
    required this.type,
    required this.minutes,
    this.line = '',
    this.from = '',
    this.to = '',
    this.station = '',
    this.stops,
  });

  factory TransitLeg.fromJson(Map<String, Object?> json) {
    return TransitLeg(
      type: switch (_string(json['type'])) {
        'change' => TransitLegType.change,
        'walk' => TransitLegType.walk,
        _ => TransitLegType.ride,
      },
      line: _string(json['line']),
      from: _string(json['from']),
      to: _string(json['to']),
      station: _string(json['station']),
      minutes: _int(json['mins']),
      stops: _nullableInt(json['stops']),
    );
  }

  final TransitLegType type;
  final String line;
  final String from;
  final String to;
  final String station;
  final int minutes;
  final int? stops;
}

class TransitDeparture {
  const TransitDeparture({
    required this.line,
    required this.destination,
    required this.minutes,
    this.platform,
    this.live = false,
  });

  factory TransitDeparture.fromJson(Map<String, Object?> json) {
    return TransitDeparture(
      line: _string(json['line'], 'bart-red'),
      destination: _string(json['dest'], 'Train'),
      platform: _nullableString(json['plat']),
      minutes: _int(json['mins']),
      live: _bool(json['live'], fallback: false),
    );
  }

  final String line;
  final String destination;
  final String? platform;
  final int minutes;
  final bool live;

  String get etaLabel => minutes <= 0 ? 'Now' : '$minutes min';
}

class TransitTimeline {
  const TransitTimeline({required this.steps, required this.arrive});

  factory TransitTimeline.fromJourney(TransitJourney journey) {
    var time = _parseClock(journey.depart);
    final steps = <TransitTimelineStep>[
      TransitTimelineStep.origin(
        station: journey.from,
        time: _formatClock(time),
      ),
    ];

    for (final leg in journey.legs) {
      final start = time;
      time += leg.minutes;
      switch (leg.type) {
        case TransitLegType.ride:
          steps.add(
            TransitTimelineStep.ride(
              line: leg.line,
              to: leg.to,
              minutes: leg.minutes,
              stops: leg.stops,
              startTime: _formatClock(start),
            ),
          );
        case TransitLegType.change:
          steps.add(
            TransitTimelineStep.change(
              station: leg.station,
              minutes: leg.minutes,
              time: _formatClock(start),
            ),
          );
        case TransitLegType.walk:
          steps.add(
            TransitTimelineStep.walk(
              to: leg.to,
              minutes: leg.minutes,
              startTime: _formatClock(start),
            ),
          );
      }
    }

    final computedArrive = journey.arrive.isEmpty
        ? _formatClock(time)
        : journey.arrive;
    steps.add(
      TransitTimelineStep.destination(
        station: journey.to,
        time: computedArrive,
      ),
    );
    return TransitTimeline(steps: steps, arrive: computedArrive);
  }

  final List<TransitTimelineStep> steps;
  final String arrive;
}

enum TransitTimelineStepKind { origin, ride, change, walk, destination }

class TransitTimelineStep {
  const TransitTimelineStep._({
    required this.kind,
    required this.time,
    this.line = '',
    this.station = '',
    this.to = '',
    this.minutes = 0,
    this.stops,
  });

  factory TransitTimelineStep.origin({
    required String station,
    required String time,
  }) {
    return TransitTimelineStep._(
      kind: TransitTimelineStepKind.origin,
      station: station,
      time: time,
    );
  }

  factory TransitTimelineStep.ride({
    required String line,
    required String to,
    required int minutes,
    required String startTime,
    int? stops,
  }) {
    return TransitTimelineStep._(
      kind: TransitTimelineStepKind.ride,
      line: line,
      to: to,
      minutes: minutes,
      stops: stops,
      time: startTime,
    );
  }

  factory TransitTimelineStep.change({
    required String station,
    required int minutes,
    required String time,
  }) {
    return TransitTimelineStep._(
      kind: TransitTimelineStepKind.change,
      station: station,
      minutes: minutes,
      time: time,
    );
  }

  factory TransitTimelineStep.walk({
    required String to,
    required int minutes,
    required String startTime,
  }) {
    return TransitTimelineStep._(
      kind: TransitTimelineStepKind.walk,
      to: to,
      minutes: minutes,
      time: startTime,
    );
  }

  factory TransitTimelineStep.destination({
    required String station,
    required String time,
  }) {
    return TransitTimelineStep._(
      kind: TransitTimelineStepKind.destination,
      station: station,
      time: time,
    );
  }

  final TransitTimelineStepKind kind;
  final String time;
  final String line;
  final String station;
  final String to;
  final int minutes;
  final int? stops;
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.duration});

  final int duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$duration',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
            height: 0.95,
          ),
        ),
        const SizedBox(width: 3),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            'min',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _JourneyStrip extends StatelessWidget {
  const _JourneyStrip({required this.journey, required this.timeline});

  final TransitJourney journey;
  final TransitTimeline timeline;

  @override
  Widget build(BuildContext context) {
    final firstLine = lineFor(journey.firstRide?.line);
    final lastLine = lineFor(journey.lastRide?.line);
    final segments = <Widget>[
      _EndpointDot(color: firstLine.color),
    ];

    for (final leg in journey.legs) {
      switch (leg.type) {
        case TransitLegType.ride:
          segments.add(
            Expanded(
              flex: leg.minutes.clamp(1, 100),
              child: _RideSegment(leg: leg),
            ),
          );
        case TransitLegType.change:
          segments.add(const _ChangeSegment());
        case TransitLegType.walk:
          segments.add(
            Expanded(
              flex: leg.minutes.clamp(2, 100),
              child: _WalkSegment(minutes: leg.minutes),
            ),
          );
      }
    }
    segments.add(_EndpointDot(color: lastLine.color, isEnd: true));

    return Column(
      children: [
        SizedBox(height: 16, child: Row(children: segments)),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(child: _StationTimeLabel(journey.from, journey.depart)),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: _StationTimeLabel(journey.to, timeline.arrive),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RideSegment extends StatelessWidget {
  const _RideSegment({required this.leg});

  final TransitLeg leg;

  @override
  Widget build(BuildContext context) {
    final line = lineFor(leg.line);
    return Container(
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: line.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${leg.minutes}',
        overflow: TextOverflow.fade,
        softWrap: false,
        style: TextStyle(
          color: line.textColor,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _WalkSegment extends StatelessWidget {
  const _WalkSegment({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: color.withValues(alpha: 0.7),
            width: 2,
          ),
        ),
      ),
      child: Text(
        '$minutes',
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _ChangeSegment extends StatelessWidget {
  const _ChangeSegment();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      alignment: Alignment.center,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface,
            width: 2.5,
          ),
        ),
      ),
    );
  }
}

class _EndpointDot extends StatelessWidget {
  const _EndpointDot({required this.color, this.isEnd = false});

  final Color color;
  final bool isEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: isEnd ? Theme.of(context).colorScheme.surface : color,
        shape: BoxShape.circle,
        border: isEnd ? Border.all(color: color, width: 3) : null,
      ),
    );
  }
}

class _StationTimeLabel extends StatelessWidget {
  const _StationTimeLabel(this.station, this.time);

  final String station;
  final String time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        text: station,
        children: [
          TextSpan(
            text: '  $time',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ],
      ),
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _JourneySteps extends StatelessWidget {
  const _JourneySteps({required this.timeline});

  final TransitTimeline timeline;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _hairlineColor(context))),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          children: [
            for (final step in timeline.steps) _TimelineRow(step: step),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step});

  final TransitTimelineStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = lineFor(step.line);
    final content = _contentForStep(step, line);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 16,
          child: _RailMarker(step: step, line: line),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 44,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              step.time,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: content,
          ),
        ),
      ],
    );
  }

  Widget _contentForStep(TransitTimelineStep step, TransitLine line) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        );
        final metaStyle = theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );

        return switch (step.kind) {
          TransitTimelineStepKind.origin => Text(
            step.station,
            style: bodyStyle,
          ),
          TransitTimelineStepKind.destination => Text(
            '${step.station} - Arrive',
            style: bodyStyle,
          ),
          TransitTimelineStepKind.ride => Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TransitLineBullet(id: step.line, size: 20),
              Text('Ride to ${step.to}', style: bodyStyle),
              SizedBox(
                width: double.infinity,
                child: Text(
                  '${line.operatorName} ${line.label}'
                  '${step.stops == null ? '' : ' - ${step.stops} stops'}'
                  ' - ${step.minutes} min',
                  style: metaStyle,
                ),
              ),
            ],
          ),
          TransitTimelineStepKind.change => Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.swap_vert_rounded,
                size: 17,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              Text('Change at ${step.station}', style: bodyStyle),
              SizedBox(
                width: double.infinity,
                child: Text('${step.minutes} min', style: metaStyle),
              ),
            ],
          ),
          TransitTimelineStepKind.walk => Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.directions_walk_rounded,
                size: 17,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              Text('Walk to ${step.to}', style: bodyStyle),
              SizedBox(
                width: double.infinity,
                child: Text('${step.minutes} min', style: metaStyle),
              ),
            ],
          ),
        };
      },
    );
  }
}

class _RailMarker extends StatelessWidget {
  const _RailMarker({required this.step, required this.line});

  final TransitTimelineStep step;
  final TransitLine line;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Center(
        child: switch (step.kind) {
          TransitTimelineStepKind.ride => Container(
            width: 4,
            height: 42,
            decoration: BoxDecoration(
              color: line.color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          TransitTimelineStepKind.walk => Container(
            width: 4,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          TransitTimelineStepKind.change => const _SmallDot(outlined: true),
          _ => const _SmallDot(),
        },
      ),
    );
  }
}

class _SmallDot extends StatelessWidget {
  const _SmallDot({this.outlined = false});

  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: outlined
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.onSurface,
        shape: BoxShape.circle,
        border: outlined
            ? Border.all(
                color: Theme.of(context).colorScheme.onSurface,
                width: 2,
              )
            : null,
      ),
    );
  }
}

class _CrowdIndicator extends StatelessWidget {
  const _CrowdIndicator({required this.crowd});

  final String crowd;

  @override
  Widget build(BuildContext context) {
    final crowdKey = crowd.toLowerCase();
    final color = crowdKey.startsWith('busy')
        ? const Color(0xFFFF6B6B)
        : crowdKey.startsWith('some')
        ? const Color(0xFFFFB020)
        : const Color(0xFF3DD17F);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          crowd,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DepartureRow extends StatelessWidget {
  const _DepartureRow({required this.departure});

  final TransitDeparture departure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = lineFor(departure.line);
    final subline = [
      line.label,
      line.operatorName,
      if (departure.platform != null) 'Plat ${departure.platform}',
    ].where((part) => part.isNotEmpty).join(' - ');

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _hairlineColor(context))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            TransitLineBullet(id: departure.line),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    departure.destination,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subline,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              departure.etaLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                color: departure.minutes <= 2
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveHeader extends StatelessWidget {
  const _LiveHeader({required this.updatedAt, required this.retrying});

  final DateTime? updatedAt;
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    final suffix = updatedAt == null
        ? ''
        : ' - updated '
              '${_formatClock(updatedAt!.hour * 60 + updatedAt!.minute)}';
    return Row(
      children: [
        const _LiveDot(),
        const SizedBox(width: 8),
        Text(
          'BART real-time$suffix${retrying ? ' - retrying' : ''}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF3DD17F),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LiveDot(),
        SizedBox(width: 6),
        Text(
          'LIVE',
          style: TextStyle(
            color: Color(0xFF4FB0E8),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: Color(0xFF4FB0E8),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MutedChip extends StatelessWidget {
  const _MutedChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AlertStatusInfo {
  const _AlertStatusInfo({
    required this.label,
    required this.color,
    required this.icon,
  });

  factory _AlertStatusInfo.fromStatus(String status) {
    return switch (status) {
      'major' => const _AlertStatusInfo(
        label: 'Major disruption',
        color: Color(0xFFFF6B6B),
        icon: Icons.error_outline_rounded,
      ),
      'minor' => const _AlertStatusInfo(
        label: 'Minor delays',
        color: Color(0xFFFFB020),
        icon: Icons.warning_amber_rounded,
      ),
      _ => const _AlertStatusInfo(
        label: 'Good service',
        color: Color(0xFF3DD17F),
        icon: Icons.check_circle_outline_rounded,
      ),
    };
  }

  final String label;
  final Color color;
  final IconData icon;
}

BoxDecoration _cardDecoration(BuildContext context, {bool emphasized = false}) {
  final scheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: emphasized ? scheme.surfaceContainerHigh : scheme.surfaceContainer,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: emphasized
          ? scheme.outlineVariant.withValues(alpha: 0.8)
          : _hairlineColor(context),
    ),
  );
}

Color _hairlineColor(BuildContext context) =>
    Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45);

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, value) => MapEntry(key.toString(), value)),
  ];
}

String _string(Object? value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  return _int(value);
}

bool _bool(Object? value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

int _parseClock(String value) {
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
  if (match == null) return 0;
  final hours = int.tryParse(match.group(1) ?? '') ?? 0;
  final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
  return hours * 60 + minutes;
}

String _formatClock(int minutes) {
  final normalized = minutes % 1440;
  final hours = normalized ~/ 60;
  final mins = normalized % 60;
  return '$hours:${mins.toString().padLeft(2, '0')}';
}

String _journeyStateKey(TransitJourney journey) {
  final legs = journey.legs
      .map(
        (leg) =>
            '${leg.type.name}:${leg.line}:${leg.from}:${leg.to}:'
            '${leg.station}:${leg.minutes}:${leg.stops}',
      )
      .join('|');
  return '${journey.from}|${journey.to}|${journey.depart}|${journey.arrive}|'
      '${journey.duration}|${journey.changes}|$legs';
}
