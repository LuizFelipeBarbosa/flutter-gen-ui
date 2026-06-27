import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/explore/explore_widgets.dart' as explore_widgets;
import 'package:genui_template/transit/_json.dart' as json_value;
import 'package:genui_template/transit/bart_departures_client.dart';
import 'package:genui_template/transit/bayhop_atoms.dart';
import 'package:genui_template/transit/bayhop_tokens.dart';
import 'package:genui_template/transit/transit_lines.dart';

class TransitRouteSelectionScope extends InheritedWidget {
  const TransitRouteSelectionScope({
    required this.onJourneySelected,
    required super.child,
    super.key,
  });

  final ValueChanged<TransitJourney> onJourneySelected;

  static TransitRouteSelectionScope? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<TransitRouteSelectionScope>();
  }

  void selectJourney(TransitJourney journey) => onJourneySelected(journey);

  @override
  bool updateShouldNotify(TransitRouteSelectionScope oldWidget) {
    return oldWidget.onJourneySelected != onJourneySelected;
  }
}

/// The lead-in card: the assistant's one-line answer for a transit request,
/// marked with the "generative" sparkle so it reads as a composed result.
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
    final label = sourceLabel ?? intent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: bayHopCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BayHopAiSpark(size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: BayHopText.body(
                    size: 10,
                    weight: FontWeight.w700,
                    color: BayHopColors.faint,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  summary,
                  style: BayHopText.body(
                    size: 15.5,
                    weight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TransitExploreBranch extends StatelessWidget {
  const TransitExploreBranch({
    required this.title,
    required this.query,
    required this.onAction,
    this.subtitle = '',
    this.badge,
    this.destination,
    this.actionName = 'open_explore',
    super.key,
  });

  factory TransitExploreBranch.fromContext(CatalogItemContext context) {
    final json = json_value.map(context.data);
    return TransitExploreBranch(
      title: _string(json['title'], 'Explore nearby'),
      subtitle: _string(json['subtitle']),
      badge: _nullableString(json['badge']),
      destination: _nullableString(json['destination']),
      query: _string(json['query']),
      actionName: _string(json['actionName'], 'open_explore'),
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
  final String? badge;
  final String? destination;
  final String query;
  final String actionName;
  final void Function(String actionName, JsonMap context) onAction;

  @override
  Widget build(BuildContext context) {
    final actionContext = <String, Object?>{
      'title': title,
      'query': query,
      'destination': destination,
    }..removeWhere((_, value) => value == null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onAction(actionName, actionContext),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: bayHopCardDecoration(radius: 18),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: BayHopColors.aiBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.travel_explore_rounded,
                  color: BayHopColors.aiBlue,
                  size: 21,
                ),
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
                              size: 14.5,
                              weight: FontWeight.w800,
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
                      const SizedBox(height: 3),
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

abstract final class TransitPlaceSearch {
  static Widget fromContext(CatalogItemContext context) {
    return explore_widgets.ExplorePlaceSearch.fromContext(context);
  }
}

/// A single trip option, rendered as BayHop's featured-route card: a hero
/// duration, a [BayHopJourneyStrip], and an expandable step-by-step timeline.
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
  String? _lastAutoSelectedJourneyKey;

  @override
  void initState() {
    super.initState();
    _scheduleRecommendedRouteSelection();
  }

  @override
  void didUpdateWidget(covariant TransitJourneyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_journeyStateKey(oldWidget.journey) !=
        _journeyStateKey(widget.journey)) {
      _isOpen = widget.journey.recommended;
      _scheduleRecommendedRouteSelection();
    }
  }

  void _scheduleRecommendedRouteSelection() {
    if (!widget.journey.recommended) return;

    final key = _journeyStateKey(widget.journey);
    if (_lastAutoSelectedJourneyKey == key) return;
    _lastAutoSelectedJourneyKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TransitRouteSelectionScope.maybeOf(context)?.selectJourney(
        widget.journey,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final journey = widget.journey;
    final timeline = journey.timeline;
    final strip = _JourneyStripData.fromJourney(journey);
    final badge = journey.recommended
        ? 'Recommended'
        : (journey.tag.isNotEmpty ? journey.tag : 'Route');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          TransitRouteSelectionScope.maybeOf(context)?.selectJourney(journey);
          setState(() => _isOpen = !_isOpen);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
          decoration: bayHopCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _BadgePill(
                    label: badge,
                    recommended: journey.recommended,
                  ),
                  const Spacer(),
                  if (journey.fareLabel.isNotEmpty)
                    Text(
                      journey.fareLabel,
                      style: BayHopText.mono(
                        size: 14,
                        color: BayHopColors.ink,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 11),
              _JourneyHero(journey: journey, arrive: timeline.arrive),
              const SizedBox(height: 16),
              BayHopJourneyStrip(
                segments: strip.segments,
                startColor: strip.startColor,
                endColor: strip.endColor,
                walkStart: strip.walkStart,
                walkEnd: strip.walkEnd,
                showWalkLabels: strip.showWalkLabels,
              ),
              if (!_isOpen)
                const Padding(
                  padding: EdgeInsets.only(top: 13),
                  child: _StepByStepHint(),
                ),
              if (_isOpen) ...[
                const SizedBox(height: 15),
                _JourneySteps(timeline: timeline),
                const SizedBox(height: 2),
                const _HideStepsHint(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyHero extends StatelessWidget {
  const _JourneyHero({required this.journey, required this.arrive});

  final TransitJourney journey;
  final String arrive;

  @override
  Widget build(BuildContext context) {
    final changesText = journey.changes == 0
        ? 'Direct'
        : journey.changes == 1
        ? '1 change'
        : '${journey.changes} changes';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${journey.duration}',
          style: BayHopText.display(
            size: 48,
            height: 0.85,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(width: 11),
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'min',
                style: BayHopText.body(size: 13, weight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${journey.depart} → $arrive',
                style: BayHopText.mono(),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                changesText,
                style: BayHopText.body(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: BayHopColors.ink2,
                ),
              ),
              if (journey.crowd.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  journey.crowd,
                  style: BayHopText.body(size: 11, color: BayHopColors.faint),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.label, required this.recommended});

  final String label;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: BayHopColors.ink,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (recommended) ...[
            const Icon(Icons.star_rounded, size: 13, color: Colors.white),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: BayHopText.body(
              size: 11,
              weight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepByStepHint extends StatelessWidget {
  const _StepByStepHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Step-by-step',
          style: BayHopText.body(
            size: 12,
            weight: FontWeight.w600,
            color: BayHopColors.aiBlue,
          ),
        ),
        const SizedBox(width: 5),
        const Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 16,
          color: BayHopColors.aiBlue,
        ),
      ],
    );
  }
}

class _HideStepsHint extends StatelessWidget {
  const _HideStepsHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Hide steps',
          style: BayHopText.body(
            size: 12,
            weight: FontWeight.w600,
            color: BayHopColors.faint,
          ),
        ),
        const SizedBox(width: 5),
        const Icon(
          Icons.keyboard_arrow_up_rounded,
          size: 16,
          color: BayHopColors.faint,
        ),
      ],
    );
  }
}

class _JourneySteps extends StatelessWidget {
  const _JourneySteps({required this.timeline});

  final TransitTimeline timeline;

  @override
  Widget build(BuildContext context) {
    final steps = timeline.steps;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BayHopColors.hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          children: [
            for (var i = 0; i < steps.length; i++)
              _StepRow(
                step: steps[i],
                isFirst: i == 0,
                isLast: i == steps.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.isFirst,
    required this.isLast,
  });

  final TransitTimelineStep step;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final line = lineFor(step.line);
    final spec = _RailSpec.forStep(step.kind, line.color);
    final detail = _detailFor(line);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 42,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                _timeLabel(),
                textAlign: TextAlign.right,
                style: BayHopText.mono(
                  size: 11,
                  color: const Color(0xFF59626A),
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          SizedBox(
            width: 16,
            child: CustomPaint(
              painter: _StepRailPainter(
                spec: spec,
                isFirst: isFirst,
                isLast: isLast,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleFor(),
                    style: BayHopText.body(weight: FontWeight.w600),
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: BayHopText.body(
                        size: 12.5,
                        color: BayHopColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Design convention: ride rows show a relative duration in the time column,
  // every other kind shows its clock time.
  String _timeLabel() {
    if (step.kind == TransitTimelineStepKind.ride) {
      return '${step.minutes} min';
    }
    return step.time;
  }

  String _titleFor() {
    return switch (step.kind) {
      TransitTimelineStepKind.origin => 'Depart ${step.station}',
      TransitTimelineStepKind.destination => 'Arrive ${step.station}',
      TransitTimelineStepKind.ride => 'Ride to ${step.to}',
      TransitTimelineStepKind.change => 'Change at ${step.station}',
      TransitTimelineStepKind.walk => 'Walk to ${step.to}',
    };
  }

  String _detailFor(TransitLine line) {
    switch (step.kind) {
      case TransitTimelineStepKind.ride:
        final lineText = '${line.operatorName} ${line.label}'.trim();
        final stopsText = step.stops == null ? '' : '${step.stops} stops · ';
        return '$lineText · $stopsText${step.minutes} min';
      case TransitTimelineStepKind.change:
      case TransitTimelineStepKind.walk:
        return '${step.minutes} min';
      case TransitTimelineStepKind.origin:
      case TransitTimelineStepKind.destination:
        return '';
    }
  }
}

class _RailSpec {
  const _RailSpec({
    required this.railColor,
    required this.dashed,
    required this.nodeRadius,
    required this.nodeBorder,
  });

  factory _RailSpec.forStep(TransitTimelineStepKind kind, Color lineColor) {
    const dashGray = Color(0xFFC6CDD2);
    return switch (kind) {
      TransitTimelineStepKind.ride => _RailSpec(
        railColor: lineColor,
        dashed: false,
        nodeRadius: 0,
        nodeBorder: Colors.transparent,
      ),
      TransitTimelineStepKind.change => const _RailSpec(
        railColor: dashGray,
        dashed: true,
        nodeRadius: 7,
        nodeBorder: Color(0xFF2A3036),
      ),
      TransitTimelineStepKind.walk => const _RailSpec(
        railColor: dashGray,
        dashed: true,
        nodeRadius: 5.5,
        nodeBorder: Color(0xFFAAB2B8),
      ),
      TransitTimelineStepKind.origin ||
      TransitTimelineStepKind.destination => _RailSpec(
        railColor: lineColor,
        dashed: false,
        nodeRadius: 7,
        nodeBorder: lineColor,
      ),
    };
  }

  final Color railColor;
  final bool dashed;
  final double nodeRadius;
  final Color nodeBorder;
}

class _StepRailPainter extends CustomPainter {
  const _StepRailPainter({
    required this.spec,
    required this.isFirst,
    required this.isLast,
  });

  final _RailSpec spec;
  final bool isFirst;
  final bool isLast;

  static const double _nodeY = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final top = isFirst ? _nodeY : 0.0;
    final bottom = isLast ? _nodeY : size.height;

    if (spec.dashed) {
      // Dashes (3px wide, ~5px on / 5px off) to match the design rail.
      final paint = Paint()
        ..color = spec.railColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (var y = top; y < bottom; y += 10) {
        final end = (y + 5 > bottom) ? bottom : y + 5;
        canvas.drawLine(Offset(cx, y), Offset(cx, end), paint);
      }
    } else {
      final paint = Paint()
        ..color = spec.railColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx, top), Offset(cx, bottom), paint);
    }

    if (spec.nodeRadius > 0) {
      canvas
        ..drawCircle(
          Offset(cx, _nodeY),
          spec.nodeRadius,
          Paint()..color = BayHopColors.surface,
        )
        ..drawCircle(
          Offset(cx, _nodeY),
          spec.nodeRadius - 1.5,
          Paint()
            ..color = spec.nodeBorder
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
    }
  }

  @override
  bool shouldRepaint(_StepRailPainter old) =>
      old.spec != spec || old.isFirst != isFirst || old.isLast != isLast;
}

/// Builds [BayHopJourneyStrip] inputs from a journey's legs: leading/trailing
/// walks become the dotted tails, rides become colored segments, and changes
/// insert a dark transfer node before the following ride.
class _JourneyStripData {
  const _JourneyStripData({
    required this.segments,
    required this.startColor,
    required this.endColor,
    required this.walkStart,
    required this.walkEnd,
    required this.showWalkLabels,
  });

  factory _JourneyStripData.fromJourney(TransitJourney journey) {
    final legs = journey.legs;
    var start = 0;
    var end = legs.length;
    var walkStart = '3';
    var walkEnd = '4';
    var hasWalkLabel = false;

    if (legs.isNotEmpty && legs.first.type == TransitLegType.walk) {
      walkStart = '${legs.first.minutes}';
      hasWalkLabel = true;
      start = 1;
    }
    if (end > start && legs[end - 1].type == TransitLegType.walk) {
      walkEnd = '${legs[end - 1].minutes}';
      hasWalkLabel = true;
      end = end - 1;
    }

    final middle = legs.sublist(start, end);
    final segments = <BayHopSegment>[];
    var pendingTransfer = false;
    for (final leg in middle) {
      switch (leg.type) {
        case TransitLegType.ride:
          segments.add(
            BayHopSegment(
              color: lineFor(leg.line).color,
              weight: leg.minutes.clamp(1, 100).toDouble(),
              transfer: pendingTransfer,
            ),
          );
          pendingTransfer = false;
        case TransitLegType.change:
          pendingTransfer = true;
        case TransitLegType.walk:
          segments.add(
            BayHopSegment(
              color: BayHopColors.faintLine,
              weight: leg.minutes.clamp(2, 100).toDouble(),
              dashed: true,
            ),
          );
      }
    }

    if (segments.isEmpty) {
      segments.add(
        BayHopSegment(color: lineFor(journey.firstRide?.line).color),
      );
    }

    return _JourneyStripData(
      segments: segments,
      startColor: lineFor(journey.firstRide?.line).color,
      endColor: lineFor(journey.lastRide?.line).color,
      walkStart: walkStart,
      walkEnd: walkEnd,
      showWalkLabels: hasWalkLabel,
    );
  }

  final List<BayHopSegment> segments;
  final Color startColor;
  final Color endColor;
  final String walkStart;
  final String walkEnd;
  final bool showWalkLabels;
}

/// A departures board: a station header with a live/planned status, then a
/// white list of upcoming departures with line bullets and minute counts.
class TransitDeparturesCard extends StatelessWidget {
  const TransitDeparturesCard({
    required this.station,
    required this.departures,
    this.live = false,
    this.statusLabel,
    super.key,
  });

  factory TransitDeparturesCard.fromJson(Map<String, Object?> json) {
    return TransitDeparturesCard(
      station: _string(json['station'], 'Station'),
      live: _bool(json['live'], fallback: false),
      statusLabel: _nullableString(json['statusLabel']),
      departures: _mapList(
        json['list'],
      ).map(TransitDeparture.fromJson).toList(),
    );
  }

  factory TransitDeparturesCard.fromBartBoard(
    BartDepartureBoard board, {
    String? statusLabel,
  }) {
    return TransitDeparturesCard(
      station: board.station,
      live: board.live,
      statusLabel: statusLabel ?? board.statusLabel,
      departures: [
        for (final departure in board.departures)
          TransitDeparture(
            line: departure.line,
            destination: departure.destination,
            platform: departure.platform,
            minutes: departure.minutes,
            live: departure.live,
            lineLabel: departure.lineLabel,
            operatorName: departure.operatorName,
            operatorId: departure.operatorId,
            mode: departure.mode,
            serviceTime: departure.serviceTime,
            serviceTimeKind: departure.serviceTimeKind,
            timeStatusLabel: departure.timeStatusLabel,
          ),
      ],
    );
  }

  final String station;
  final List<TransitDeparture> departures;
  final bool live;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station,
                    style: BayHopText.display(size: 23),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Upcoming departures',
                    style: BayHopText.body(size: 12, color: BayHopColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: live && statusLabel == null
                  ? const _LivePill()
                  : _MutedStatusChip(label: statusLabel ?? 'Planned'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: bayHopCardDecoration(radius: 18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              children: [
                for (final departure in departures)
                  _DepartureRow(departure: departure),
              ],
            ),
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
    final line = lineFor(departure.line);
    final subline = _departureSubline(departure, line);

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BayHopColors.hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            BayHopLineBullet(
              label: _shortLineName(line),
              color: line.color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    departure.destination,
                    overflow: TextOverflow.ellipsis,
                    style: BayHopText.body(weight: FontWeight.w600),
                  ),
                  if (subline.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      subline,
                      overflow: TextOverflow.ellipsis,
                      style: BayHopText.body(
                        size: 11,
                        color: BayHopColors.faint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _DepartureEta(departure: departure),
          ],
        ),
      ),
    );
  }
}

class _DepartureEta extends StatelessWidget {
  const _DepartureEta({required this.departure});

  final TransitDeparture departure;

  @override
  Widget build(BuildContext context) {
    final serviceTime = departure.serviceTime;
    if (serviceTime != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatServiceTime(serviceTime),
            style: BayHopText.mono(
              size: 18,
              weight: FontWeight.w700,
              color: BayHopColors.ink,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            _serviceTimeSubLabel(departure),
            style: BayHopText.body(size: 11, color: BayHopColors.faint),
          ),
        ],
      );
    }

    final minutes = departure.minutes;
    if (minutes <= 0) {
      return Text(
        'Now',
        style: BayHopText.mono(
          size: 18,
          weight: FontWeight.w700,
          color: BayHopColors.aiBlue,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$minutes',
          style: BayHopText.mono(
            size: 25,
            weight: FontWeight.w700,
            color: BayHopColors.ink,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          'min',
          style: BayHopText.body(size: 11, color: BayHopColors.faint),
        ),
      ],
    );
  }
}

class LiveTransitDeparturesBoard extends StatefulWidget {
  const LiveTransitDeparturesBoard({
    required this.request,
    this.displayName,
    this.client,
    super.key,
  });

  factory LiveTransitDeparturesBoard.fromJson(Map<String, Object?> json) {
    final source = _string(json['source']).toLowerCase();
    final stationAbbr = _nullableString(json['stationAbbr']);
    if (source != '511' && stationAbbr != null) {
      return LiveTransitDeparturesBoard(
        request: LiveDeparturesRequest.bart(stationAbbr: stationAbbr),
        displayName: _nullableString(json['stationName']),
      );
    }

    if (source == '511' || _nullableString(json['agency']) != null) {
      return LiveTransitDeparturesBoard(
        request: LiveDeparturesRequest.sf511(
          agency: _nullableString(json['agency']),
          agencyName: _nullableString(json['agencyName']),
          stopCode: _nullableString(json['stopCode']),
          stopName: _nullableString(json['stopName']),
          lineFilter: _nullableString(json['lineFilter']),
        ),
        displayName: _nullableString(json['stopName']),
      );
    }

    return LiveTransitDeparturesBoard(
      request: LiveDeparturesRequest.bart(
        stationAbbr: _string(json['stationAbbr'], 'EMBR'),
      ),
      displayName: _nullableString(json['stationName']),
    );
  }

  final LiveDeparturesRequest request;
  final String? displayName;
  final LiveDeparturesClient? client;

  @override
  State<LiveTransitDeparturesBoard> createState() =>
      _LiveTransitDeparturesBoardState();
}

class LiveBartDeparturesBoard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return LiveTransitDeparturesBoard(
      request: LiveDeparturesRequest.bart(stationAbbr: stationAbbr),
      displayName: stationName,
      client: client,
    );
  }
}

class _LiveTransitDeparturesBoardState
    extends State<LiveTransitDeparturesBoard> {
  late final LiveDeparturesClient _client =
      widget.client ?? LiveDeparturesClient();
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
  void didUpdateWidget(covariant LiveTransitDeparturesBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.cacheKey != widget.request.cacheKey) {
      _board = null;
      _error = null;
      _updatedAt = null;
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
    final request = widget.request;
    setState(() {
      _loading = _board == null;
      _error = null;
    });

    try {
      final board = await _client.fetch(request);
      if (!mounted || widget.request.cacheKey != request.cacheKey) return;
      setState(() {
        _board = board;
        _error = null;
        _updatedAt = DateTime.now();
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || widget.request.cacheKey != request.cacheKey) return;
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
      return _LoadingCard(
        message:
            'Reaching ${_sourceLabelFor(widget.request)} real-time feed...',
      );
    }

    final status = _liveDepartureStatusFor(board);
    final displayBoard =
        board ??
        _fallbackBoardFor(
          widget.request,
          widget.displayName,
        );
    if (displayBoard == null) {
      return TransitNoteCard(
        tone: TransitNoteTone.warning,
        text:
            'Could not reach ${_sourceLabelFor(widget.request)} live '
            'departures for ${widget.displayName ?? 'this stop'}: $_error',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: _LiveHeader(
            updatedAt: _updatedAt,
            retrying: _error != null,
            status: status,
            sourceLabel: displayBoard.sourceLabel,
          ),
        ),
        TransitDeparturesCard.fromBartBoard(
          displayBoard,
          statusLabel: status.departuresLabel,
        ),
      ],
    );
  }

  _LiveDepartureStatus _liveDepartureStatusFor(BartDepartureBoard? board) {
    if (board == null) return _LiveDepartureStatus.offlineEstimate;
    if (_error != null) return _LiveDepartureStatus.cached;
    if (!board.live) return _LiveDepartureStatus.planned;
    return _LiveDepartureStatus.live;
  }
}

/// A service-status card: a colored line badge, a tone-coded status, and a
/// short plain-language detail.
class TransitAlertCard extends StatelessWidget {
  const TransitAlertCard({
    required this.line,
    required this.status,
    required this.detail,
    this.updated,
    super.key,
  });

  factory TransitAlertCard.fromJson(Map<String, Object?> json) {
    return TransitAlertCard(
      line: _string(json['line'], 'bart-yellow'),
      status: _string(json['status'], 'good'),
      detail: _string(json['detail']),
      updated: _nullableString(json['updated']),
    );
  }

  final String line;
  final String status;
  final String detail;
  final String? updated;

  @override
  Widget build(BuildContext context) {
    final transitLine = lineFor(line);
    final info = _AlertStatusInfo.fromStatus(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: bayHopCardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: transitLine.color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  transitLine.label,
                  style: BayHopText.body(
                    size: 12,
                    weight: FontWeight.w700,
                    color: BayHopColors.contrastOn(transitLine.color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: info.dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        info.label,
                        style: BayHopText.body(
                          size: 15,
                          weight: FontWeight.w700,
                          color: info.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 13),
            Text(
              detail,
              style: BayHopText.body(
                size: 14.5,
                color: BayHopColors.ink2,
                height: 1.5,
              ),
            ),
          ],
          if (updated != null && updated!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const _StaticDot(color: BayHopColors.live),
                const SizedBox(width: 7),
                Text(
                  'Updated $updated',
                  style: BayHopText.mono(
                    size: 11,
                    weight: FontWeight.w500,
                    color: BayHopColors.faint,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum TransitNoteTone { neutral, warning }

/// A soft tinted note for fares, transfers, or live-data caveats.
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
    final warning = tone == TransitNoteTone.warning;
    final accent = warning ? BayHopColors.warn : BayHopColors.aiBlue;
    final textColor = warning ? BayHopColors.warnText : BayHopColors.ink2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            color: accent,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: BayHopText.body(
                weight: FontWeight.w600,
                color: textColor,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data models — parsed from model output; shared by the cards above.
// ---------------------------------------------------------------------------

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
    final rawLegs = _mapList(json['legs']).map(TransitLeg.fromJson).toList();
    final legs = _normalizeOakConnectorLegs(rawLegs);
    final legDuration = legs.fold<int>(0, (total, leg) => total + leg.minutes);
    final depart = _string(json['depart'], '--:--');
    final duration = legDuration > 0
        ? legDuration
        : _int(json['duration'], fallback: legDuration);
    final arrive = legDuration > 0
        ? _formatClock(_parseClock(depart) + legDuration)
        : _string(json['arrive']);

    return TransitJourney(
      from: _string(json['from'], 'Origin'),
      to: _string(json['to'], 'Destination'),
      depart: depart,
      arrive: arrive,
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

  TransitLeg copyWith({
    int? minutes,
    int? stops,
  }) {
    return TransitLeg(
      type: type,
      line: line,
      from: from,
      to: to,
      station: station,
      minutes: minutes ?? this.minutes,
      stops: stops ?? this.stops,
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
    this.lineLabel,
    this.operatorName,
    this.operatorId,
    this.mode,
    this.serviceTime,
    this.serviceTimeKind,
    this.timeStatusLabel,
  });

  factory TransitDeparture.fromJson(Map<String, Object?> json) {
    return TransitDeparture(
      line: _string(json['line'], fallbackTransitLine.id),
      destination: _string(json['dest'], 'Train'),
      platform: _nullableString(json['plat']),
      minutes: _int(json['mins']),
      live: _bool(json['live'], fallback: false),
      lineLabel: _nullableString(json['lineLabel']),
      operatorName: _nullableString(json['operatorName']),
      operatorId: _nullableString(json['operatorId']),
      mode: _nullableString(json['mode']),
      serviceTime: _dateTime(json['serviceTime']),
      serviceTimeKind: _nullableString(json['serviceTimeKind']),
      timeStatusLabel: _nullableString(json['timeStatusLabel']),
    );
  }

  final String line;
  final String destination;
  final String? platform;
  final int minutes;
  final bool live;
  final String? lineLabel;
  final String? operatorName;
  final String? operatorId;
  final String? mode;
  final DateTime? serviceTime;
  final String? serviceTimeKind;
  final String? timeStatusLabel;

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

// ---------------------------------------------------------------------------
// Presentation helpers shared by the cards.
// ---------------------------------------------------------------------------

String _shortLineName(TransitLine line) {
  final label = line.label;
  if (label.endsWith(' Line')) {
    return label.substring(0, label.length - ' Line'.length);
  }
  return label;
}

String _departureSubline(TransitDeparture departure, TransitLine line) {
  final parts = <String>[];

  void add(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return;
    final duplicate = parts.any(
      (part) => part.toLowerCase() == text.toLowerCase(),
    );
    if (!duplicate) parts.add(text);
  }

  add(departure.lineLabel ?? line.label);
  add(departure.operatorName ?? line.operatorName);
  add(departure.mode);
  if (departure.platform != null) add('Plat ${departure.platform}');

  return parts.join(' - ');
}

String _serviceTimeSubLabel(TransitDeparture departure) {
  final label = departure.timeStatusLabel?.trim();
  if (label == null || label.isEmpty) return departure.etaLabel;
  return '$label - ${departure.etaLabel}';
}

class _MutedStatusChip extends StatelessWidget {
  const _MutedStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: BayHopColors.chipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: BayHopText.body(
          size: 11.5,
          weight: FontWeight.w700,
          color: BayHopColors.muted,
        ),
      ),
    );
  }
}

enum _LiveDepartureStatus { live, planned, cached, offlineEstimate }

extension on _LiveDepartureStatus {
  String headerLabel(String sourceLabel) {
    return switch (this) {
      _LiveDepartureStatus.live => '$sourceLabel real-time',
      _LiveDepartureStatus.planned => '$sourceLabel planned service',
      _LiveDepartureStatus.cached => '$sourceLabel cached departures',
      _LiveDepartureStatus.offlineEstimate => '$sourceLabel offline estimates',
    };
  }

  String? get departuresLabel {
    return switch (this) {
      _LiveDepartureStatus.live => null,
      _LiveDepartureStatus.planned => 'Planned',
      _LiveDepartureStatus.cached => 'Cached',
      _LiveDepartureStatus.offlineEstimate => 'Estimated',
    };
  }

  Color get color {
    return switch (this) {
      _LiveDepartureStatus.live => BayHopColors.live,
      _LiveDepartureStatus.planned => BayHopColors.faint,
      _LiveDepartureStatus.cached => BayHopColors.warn,
      _LiveDepartureStatus.offlineEstimate => BayHopColors.warn,
    };
  }
}

class _LiveHeader extends StatelessWidget {
  const _LiveHeader({
    required this.updatedAt,
    required this.retrying,
    required this.status,
    required this.sourceLabel,
  });

  final DateTime? updatedAt;
  final bool retrying;
  final _LiveDepartureStatus status;
  final String sourceLabel;

  @override
  Widget build(BuildContext context) {
    final suffix = updatedAt == null
        ? ''
        : ' - updated '
              '${_formatClock(updatedAt!.hour * 60 + updatedAt!.minute)}';
    return Row(
      children: [
        _StaticDot(color: status.color),
        const SizedBox(width: 8),
        Text(
          '${status.headerLabel(sourceLabel)}$suffix'
          '${retrying ? ' - retrying' : ''}',
          style: BayHopText.body(
            size: 12,
            weight: FontWeight.w700,
            color: status.color,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _StaticDot(color: BayHopColors.live),
        const SizedBox(width: 6),
        Text(
          'LIVE',
          style: BayHopText.body(
            size: 11,
            weight: FontWeight.w700,
            color: BayHopColors.live,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _StaticDot extends StatelessWidget {
  const _StaticDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.18), spreadRadius: 3),
        ],
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
      decoration: bayHopCardDecoration(),
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
              style: BayHopText.body(
                weight: FontWeight.w600,
                color: BayHopColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertStatusInfo {
  const _AlertStatusInfo({
    required this.label,
    required this.dotColor,
    required this.textColor,
  });

  factory _AlertStatusInfo.fromStatus(String status) {
    return switch (status) {
      'major' => const _AlertStatusInfo(
        label: 'Major disruption',
        dotColor: BayHopColors.severe,
        textColor: BayHopColors.severeText,
      ),
      'minor' => const _AlertStatusInfo(
        label: 'Minor delays',
        dotColor: BayHopColors.warn,
        textColor: BayHopColors.warnText,
      ),
      _ => const _AlertStatusInfo(
        label: 'Good service',
        dotColor: BayHopColors.good,
        textColor: BayHopColors.good,
      ),
    };
  }

  final String label;
  final Color dotColor;
  final Color textColor;
}

// ---------------------------------------------------------------------------
// JSON + clock helpers and offline BART estimates (unchanged behavior).
// ---------------------------------------------------------------------------

List<Map<String, Object?>> _mapList(Object? value) => json_value.mapList(value);

String _string(Object? value, [String fallback = '']) =>
    json_value.string(value, fallback);

String? _nullableString(Object? value) => json_value.nullableString(value);

DateTime? _dateTime(Object? value) {
  if (value is DateTime) return value;
  final text = _nullableString(value);
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}

int _int(Object? value, {int fallback = 0}) =>
    json_value.integer(value, fallback: fallback);

int? _nullableInt(Object? value) => json_value.nullableInteger(value);

bool _bool(Object? value, {required bool fallback}) =>
    json_value.boolean(value, fallback: fallback);

String _formatServiceTime(DateTime serviceTime) {
  final local = serviceTime.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

BartDepartureBoard _estimatedBartDepartureBoard(
  String stationAbbr,
  String? stationName,
) {
  return BartDepartureBoard(
    station: _estimatedBartStationName(stationAbbr, stationName),
    live: false,
    departures: _estimatedBartDeparturesFor(stationAbbr),
  );
}

BartDepartureBoard? _fallbackBoardFor(
  LiveDeparturesRequest request,
  String? displayName,
) {
  if (request.source != LiveDeparturesSource.bart) return null;
  return _estimatedBartDepartureBoard(request.stationAbbr ?? '', displayName);
}

String _sourceLabelFor(LiveDeparturesRequest request) {
  return switch (request.source) {
    LiveDeparturesSource.bart => 'BART',
    LiveDeparturesSource.sf511 => _stringFromParts([
      request.agencyName,
      request.agency,
      '511',
    ]),
  };
}

String _stringFromParts(List<String?> parts) {
  for (final part in parts) {
    final text = part?.trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return '';
}

String _estimatedBartStationName(String stationAbbr, String? stationName) {
  if (stationName != null && stationName.isNotEmpty) return stationName;

  final station = _bartStationForLiveInput(stationAbbr);
  if (station != null) return station.name;

  final normalizedStation = _normalizeBartStationAbbr(stationAbbr);
  return normalizedStation.isEmpty ? 'BART station' : normalizedStation;
}

List<BartDeparture> _estimatedBartDeparturesFor(String stationAbbr) {
  final normalizedStation = _normalizeBartStationAbbr(stationAbbr);
  if (normalizedStation == 'OAKL') return _oakConnectorDepartures;
  if (normalizedStation == 'COLS') return _coliseumDepartures;
  if (_sfCoreStations.contains(normalizedStation)) return _sfCoreDepartures;
  if (_eastBayNorthStations.contains(normalizedStation)) {
    return _eastBayNorthDepartures;
  }
  if (_peninsulaStations.contains(normalizedStation)) {
    return _peninsulaDepartures;
  }

  return _defaultBartDepartures;
}

String _normalizeBartStationAbbr(String stationAbbr) {
  final station = _bartStationForLiveInput(stationAbbr);
  if (station != null) return station.abbr;

  final cleaned = stationAbbr.toUpperCase().replaceAll(
    RegExp('[^A-Z0-9]'),
    '',
  );
  return cleaned.length == 4 ? cleaned : '';
}

BartStation? _bartStationForLiveInput(String input) {
  return resolveBartStation(input) ?? bartStationForAbbr(input);
}

List<TransitLeg> _normalizeOakConnectorLegs(List<TransitLeg> legs) {
  return [
    for (final leg in legs)
      _isOakConnectorRide(leg)
          ? leg.copyWith(
              minutes: oakAirportConnectorMinutes,
              stops: oakAirportConnectorStops,
            )
          : leg,
  ];
}

bool _isOakConnectorRide(TransitLeg leg) {
  if (leg.type != TransitLegType.ride ||
      leg.line != oakAirportConnectorLineId) {
    return false;
  }

  final from = _oakConnectorStationKind(leg.from);
  final to = _oakConnectorStationKind(leg.to);
  return (from == _OakConnectorStation.coliseum &&
          to == _OakConnectorStation.oakAirport) ||
      (from == _OakConnectorStation.oakAirport &&
          to == _OakConnectorStation.coliseum);
}

enum _OakConnectorStation { coliseum, oakAirport }

_OakConnectorStation? _oakConnectorStationKind(String value) {
  final normalized = value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  return switch (normalized) {
    'cols' || 'coliseum' || 'coliseumbart' => _OakConnectorStation.coliseum,
    'oak' ||
    'oakl' ||
    'oakairport' ||
    'oaklandairport' ||
    'oaklandinternationalairport' => _OakConnectorStation.oakAirport,
    _ => null,
  };
}

const _sfCoreStations = {
  'EMBR',
  'MONT',
  'POWL',
  'CIVC',
  '16TH',
  '24TH',
  'GLEN',
  'BALB',
  'DALY',
};

const _eastBayNorthStations = {
  'RICH',
  'DELN',
  'PLZA',
  'NBRK',
  'DBRK',
  'ASHB',
  'MCAR',
  '19TH',
  '12TH',
  'WOAK',
};

const _peninsulaStations = {
  'COLM',
  'SSAN',
  'SBRN',
  'SFIA',
  'MLBR',
};

const _sfCoreDepartures = [
  BartDeparture(
    line: 'bart-yellow',
    destination: 'SFO / Millbrae',
    minutes: 4,
    live: false,
  ),
  BartDeparture(
    line: 'bart-red',
    destination: 'Richmond',
    minutes: 7,
    live: false,
  ),
  BartDeparture(
    line: 'bart-blue',
    destination: 'Dublin/Pleasanton',
    minutes: 10,
    live: false,
  ),
  BartDeparture(
    line: 'bart-green',
    destination: 'Berryessa/North San Jose',
    minutes: 13,
    live: false,
  ),
];

const _eastBayNorthDepartures = [
  BartDeparture(
    line: 'bart-red',
    destination: 'SFO / Millbrae',
    minutes: 5,
    live: false,
  ),
  BartDeparture(
    line: 'bart-orange',
    destination: 'Berryessa/North San Jose',
    minutes: 8,
    live: false,
  ),
  BartDeparture(
    line: 'bart-yellow',
    destination: 'Antioch',
    minutes: 12,
    live: false,
  ),
];

const _peninsulaDepartures = [
  BartDeparture(
    line: 'bart-yellow',
    destination: 'Antioch',
    minutes: 6,
    live: false,
  ),
  BartDeparture(
    line: 'bart-red',
    destination: 'Richmond',
    minutes: 14,
    live: false,
  ),
];

const _coliseumDepartures = [
  BartDeparture(
    line: oakAirportConnectorLineId,
    destination: 'Oakland Airport',
    minutes: oakAirportConnectorMinutes,
    live: false,
  ),
  BartDeparture(
    line: 'bart-orange',
    destination: 'Richmond',
    minutes: 6,
    live: false,
  ),
  BartDeparture(
    line: 'bart-green',
    destination: 'Berryessa/North San Jose',
    minutes: 11,
    live: false,
  ),
];

const _oakConnectorDepartures = [
  BartDeparture(
    line: oakAirportConnectorLineId,
    destination: 'Coliseum',
    minutes: 3,
    live: false,
  ),
  BartDeparture(
    line: oakAirportConnectorLineId,
    destination: 'Coliseum',
    minutes: oakAirportConnectorMinutes,
    live: false,
  ),
  BartDeparture(
    line: oakAirportConnectorLineId,
    destination: 'Coliseum',
    minutes: 15,
    live: false,
  ),
];

const _defaultBartDepartures = [
  BartDeparture(
    line: 'bart-yellow',
    destination: 'SFO / Millbrae',
    minutes: 5,
    live: false,
  ),
  BartDeparture(
    line: 'bart-orange',
    destination: 'Richmond',
    minutes: 9,
    live: false,
  ),
  BartDeparture(
    line: 'bart-blue',
    destination: 'Dublin/Pleasanton',
    minutes: 14,
    live: false,
  ),
];

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
