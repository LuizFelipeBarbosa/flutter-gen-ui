import 'dart:ui' as ui;

import 'package:bayhop/transit/bayhop_tokens.dart';
import 'package:flutter/material.dart';

/// Shared BayHop building blocks used across the result cards and app shell.
///
/// Keeping the atoms here — line bullets, the journey strip, the frosted
/// surface, the live dot, and the loading shimmer — means every card composes
/// the same primitives and the look stays consistent.

enum BayHopBulletVariant { pill, swatch, dot }

/// A transit line marker. The pill is a filled, auto-contrast chip; the
/// swatch is a small square + label; the dot is a circle + label.
class BayHopLineBullet extends StatelessWidget {
  const BayHopLineBullet({
    required this.label,
    required this.color,
    this.variant = BayHopBulletVariant.pill,
    super.key,
  });

  final String label;
  final Color color;
  final BayHopBulletVariant variant;

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case BayHopBulletVariant.pill:
        return Container(
          constraints: const BoxConstraints(minWidth: 46),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: BayHopText.body(
              size: 11,
              weight: FontWeight.w700,
              color: BayHopColors.contrastOn(color),
              letterSpacing: 0.2,
              height: 1,
            ),
          ),
        );
      case BayHopBulletVariant.swatch:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: BayHopText.body(weight: FontWeight.w600),
              ),
            ),
          ],
        );
      case BayHopBulletVariant.dot:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: BayHopText.body(size: 13, weight: FontWeight.w600),
              ),
            ),
          ],
        );
    }
  }
}

/// One leg of a [BayHopJourneyStrip]. A [transfer] segment is preceded by a
/// dark interchange node; a [dashed] segment renders as a dotted (walk) leg.
class BayHopSegment {
  const BayHopSegment({
    required this.color,
    this.weight = 1,
    this.transfer = false,
    this.dashed = false,
  });

  final Color color;
  final double weight;
  final bool transfer;
  final bool dashed;
}

class _StripDims {
  const _StripDims({
    required this.walk,
    required this.node,
    required this.nodeBorder,
    required this.tNode,
    required this.tBorder,
    required this.bar,
  });

  final double walk;
  final double node;
  final double nodeBorder;
  final double tNode;
  final double tBorder;
  final double bar;
}

/// The horizontal journey diagram: dotted walk tails, colored ride segments,
/// hollow start/end nodes, and dark transfer nodes between segments.
class BayHopJourneyStrip extends StatelessWidget {
  const BayHopJourneyStrip({
    required this.segments,
    required this.startColor,
    required this.endColor,
    this.walkStart = '3',
    this.walkEnd = '4',
    this.size = BayHopStripSize.lg,
    this.showWalkLabels = true,
    super.key,
  });

  final List<BayHopSegment> segments;
  final Color startColor;
  final Color endColor;
  final String walkStart;
  final String walkEnd;
  final BayHopStripSize size;
  final bool showWalkLabels;

  @override
  Widget build(BuildContext context) {
    final dims = size == BayHopStripSize.lg
        ? const _StripDims(
            walk: 18,
            node: 13,
            nodeBorder: 3.5,
            tNode: 14,
            tBorder: 3,
            bar: 9,
          )
        : const _StripDims(
            walk: 12,
            node: 10,
            nodeBorder: 3,
            tNode: 11,
            tBorder: 2.5,
            bar: 7,
          );

    final children = <Widget>[
      _walkTail(dims),
      _node(dims, startColor),
    ];

    for (final segment in segments) {
      if (segment.transfer) children.add(_transferNode(dims));
      children.add(
        Expanded(
          flex: (segment.weight * 100).round().clamp(1, 100000),
          child: segment.dashed
              ? _DottedLine(color: segment.color, thickness: dims.bar)
              : Container(
                  height: dims.bar,
                  decoration: BoxDecoration(
                    color: segment.color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
        ),
      );
    }

    children
      ..add(_node(dims, endColor))
      ..add(_walkTail(dims));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: children),
        if (showWalkLabels) ...[
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('walk ${walkStart}m', style: _walkLabelStyle),
              Text('walk ${walkEnd}m', style: _walkLabelStyle),
            ],
          ),
        ],
      ],
    );
  }

  Widget _walkTail(_StripDims dims) => SizedBox(
    width: dims.walk,
    child: const _DottedLine(
      color: Color(0xFFB4BCC2),
      thickness: 2.5,
    ),
  );

  Widget _node(_StripDims dims, Color color) => Container(
    width: dims.node,
    height: dims.node,
    decoration: BoxDecoration(
      color: BayHopColors.surface,
      shape: BoxShape.circle,
      border: Border.all(color: color, width: dims.nodeBorder),
    ),
  );

  Widget _transferNode(_StripDims dims) => Container(
    width: dims.tNode,
    height: dims.tNode,
    decoration: BoxDecoration(
      color: BayHopColors.surface,
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF2A3036), width: dims.tBorder),
    ),
  );

  static final TextStyle _walkLabelStyle = BayHopText.mono(
    size: 10,
    weight: FontWeight.w500,
    color: BayHopColors.faint,
  );
}

enum BayHopStripSize { sm, lg }

/// A horizontal dotted line (round dots) for walk legs and tails.
class _DottedLine extends StatelessWidget {
  const _DottedLine({required this.color, required this.thickness});

  final Color color;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: thickness,
      child: CustomPaint(
        painter: _DottedLinePainter(color: color, thickness: thickness),
        size: Size.infinite,
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  const _DottedLinePainter({required this.color, required this.thickness});

  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final radius = thickness / 2;
    final gap = thickness * 2.0;
    final cy = size.height / 2;
    for (var x = radius; x <= size.width; x += gap) {
      canvas.drawCircle(Offset(x, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedLinePainter old) =>
      old.color != color || old.thickness != thickness;
}

/// A frosted-glass surface (blur + translucent white + highlight border).
/// Used by the search bar and the bottom sheet.
class BayHopFrostedSurface extends StatelessWidget {
  const BayHopFrostedSurface({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.blur = 22,
    this.opacity = 0.78,
    this.borderOpacity = 0.8,
    this.boxShadow,
    super.key,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final double opacity;
  final double borderOpacity;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final surface = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
            ),
          ),
          child: child,
        ),
      ),
    );

    final shadows = boxShadow;
    if (shadows == null) return surface;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadows),
      child: surface,
    );
  }
}

/// The blue→purple gradient sparkle that marks "generative" moments.
class BayHopAiSpark extends StatelessWidget {
  const BayHopAiSpark({this.size = 32, this.radius = 10, super.key});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: BayHopColors.aiGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: BayHopColors.aiPurple.withValues(alpha: 0.34),
            blurRadius: 13,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(Icons.auto_awesome, size: size * 0.5, color: Colors.white),
    );
  }
}

/// A pulsing "live" dot with a soft halo ring.
class BayHopLiveDot extends StatefulWidget {
  const BayHopLiveDot({
    this.size = 8,
    this.color = BayHopColors.live,
    super.key,
  });

  final double size;
  final Color color;

  @override
  State<BayHopLiveDot> createState() => _BayHopLiveDotState();
}

class _BayHopLiveDotState extends State<BayHopLiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final scale = 1 - 0.22 * t;
        final opacity = 1 - 0.72 * t;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Center(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.18),
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A shimmering placeholder bar for the "Generating…" state.
class BayHopSkeletonBar extends StatefulWidget {
  const BayHopSkeletonBar({
    required this.width,
    required this.height,
    this.radius = 6,
    super.key,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<BayHopSkeletonBar> createState() => _BayHopSkeletonBarState();
}

class _BayHopSkeletonBarState extends State<BayHopSkeletonBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final shift = (_controller.value * 2 - 1) * 2;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 - shift, 0),
              end: Alignment(1 - shift, 0),
              colors: const [
                Color(0xFFE7EBEE),
                Color(0xFFF5F8F9),
                Color(0xFFE7EBEE),
              ],
              stops: const [0.25, 0.37, 0.63],
            ),
          ),
        );
      },
    );
  }
}

/// A quiet rounded chip used for compact transit metadata.
class BayHopChip extends StatelessWidget {
  const BayHopChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: BayHopColors.chipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: BayHopText.body(
          size: 12.5,
          weight: FontWeight.w600,
          color: BayHopColors.ink2,
        ),
      ),
    );
  }
}

/// How the [BayHopLogo] hop mark is colored.
enum BayHopLogoStyle {
  /// Gradient arc + ink stop dots — the default mark for light surfaces.
  gradient,

  /// Brighter gradient arc + white stop dots — for dark surfaces.
  onDark,

  /// A single flat color for the whole mark — favicon / tiny / monochrome use.
  mono,
}

/// The BayHop "hop" mark: a journey arc between two stop dots, carrying the
/// blue→purple GenUI gradient — "two stops, one hop".
///
/// Transcribed verbatim from `BayHop Logo.dc.html`: the `M22 64 Q50 -2 78 64`
/// arc (stroke-width 9, round caps) with r9 stop dots, all in a 0–100 design
/// space scaled to [size].
class BayHopLogo extends StatelessWidget {
  const BayHopLogo({
    this.size = 28,
    this.style = BayHopLogoStyle.gradient,
    this.monoColor = BayHopColors.ink,
    super.key,
  });

  final double size;
  final BayHopLogoStyle style;

  /// Arc + dot color when [style] is [BayHopLogoStyle.mono].
  final Color monoColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _BayHopMarkPainter(style: style, monoColor: monoColor),
    );
  }
}

class _BayHopMarkPainter extends CustomPainter {
  _BayHopMarkPainter({required this.style, required this.monoColor});

  final BayHopLogoStyle style;
  final Color monoColor;

  // Brighter gradient used on dark backgrounds (BayHop Logo.dc.html · F4).
  static const _onDarkA = Color(0xFF19A9E8);
  static const _onDarkB = Color(0xFF7E6FF0);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100; // 0–100 design space → pixels.

    final arc = Path()
      ..moveTo(22 * s, 64 * s)
      ..quadraticBezierTo(50 * s, -2 * s, 78 * s, 64 * s);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9 * s
      ..strokeCap = StrokeCap.round;
    final dots = Paint()..style = PaintingStyle.fill;

    switch (style) {
      case BayHopLogoStyle.gradient:
        stroke.shader = _arcShader(
          s,
          BayHopColors.aiBlue,
          BayHopColors.aiPurple,
        );
        dots.color = BayHopColors.ink;
      case BayHopLogoStyle.onDark:
        stroke.shader = _arcShader(s, _onDarkA, _onDarkB);
        dots.color = Colors.white;
      case BayHopLogoStyle.mono:
        stroke.color = monoColor;
        dots.color = monoColor;
    }

    canvas
      ..drawPath(arc, stroke)
      ..drawCircle(Offset(22 * s, 64 * s), 9 * s, dots)
      ..drawCircle(Offset(78 * s, 64 * s), 9 * s, dots);
  }

  // Gradient vector (14,30)→(86,66) — the F1 `hopA` linear.
  Shader _arcShader(double s, Color a, Color b) => ui.Gradient.linear(
    Offset(14 * s, 30 * s),
    Offset(86 * s, 66 * s),
    [a, b],
  );

  @override
  bool shouldRepaint(_BayHopMarkPainter old) =>
      old.style != style || old.monoColor != monoColor;
}

/// The horizontal BayHop lockup: the [BayHopLogo] mark + the "BayHop" wordmark
/// in Space Grotesk 700. On light surfaces "Hop" carries the AI gradient (the
/// design's F3 small lockup); on dark the whole word reads light (F4).
class BayHopWordmark extends StatelessWidget {
  const BayHopWordmark({
    this.markSize = 34,
    this.fontSize = 27,
    this.gap = 12,
    this.gradientHop = true,
    this.onDark = false,
    super.key,
  });

  final double markSize;
  final double fontSize;
  final double gap;

  /// Paint "Hop" with the AI gradient. Ignored when [onDark] is true.
  final bool gradientHop;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final wordStyle = BayHopText.display(
      size: fontSize,
      color: onDark ? const Color(0xFFEDF1F3) : BayHopColors.ink,
      letterSpacing: -fontSize * 0.037, // ≈ -1px at 27pt (design lockup).
      height: 1,
    );

    final Widget word;
    if (gradientHop && !onDark) {
      word = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Bay', style: wordStyle),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) =>
                BayHopColors.aiGradient.createShader(bounds),
            child: Text('Hop', style: wordStyle),
          ),
        ],
      );
    } else {
      word = Text('BayHop', style: wordStyle);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BayHopLogo(
          size: markSize,
          style: onDark ? BayHopLogoStyle.onDark : BayHopLogoStyle.gradient,
        ),
        SizedBox(width: gap),
        word,
      ],
    );
  }
}

/// The white rounded card surface every result card sits on.
BoxDecoration bayHopCardDecoration({double radius = 22}) => BoxDecoration(
  color: BayHopColors.surface,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: BayHopColors.hairline),
  boxShadow: const [
    BoxShadow(
      color: Color(0x0F14181C),
      blurRadius: 22,
      offset: Offset(0, 8),
    ),
    BoxShadow(color: Color(0x08141C1C), offset: Offset(0, 1)),
  ],
);
