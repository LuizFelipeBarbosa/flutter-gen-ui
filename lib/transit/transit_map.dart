import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// An animated "BayHop" Bay Area transit map rendered as a background.
///
/// Place this inside a [Positioned.fill] (or any sized parent). It fills its
/// parent and runs an ambient entrance animation on mount plus a continuous
/// pulse on the user-location pin.
class BayHopTransitMap extends StatefulWidget {
  const BayHopTransitMap({super.key});

  @override
  State<BayHopTransitMap> createState() => _BayHopTransitMapState();
}

class _BayHopTransitMapState extends State<BayHopTransitMap>
    with TickerProviderStateMixin {
  // Primary entrance animation: draws the route, fades the base network and
  // slides the pins in.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  // Continuous pulse used by the user-location ring.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    // Fire-and-forget the animations; we intentionally ignore the futures.
    _entrance.forward().ignore();
    _pulse.repeat().ignore();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size.infinite,
          painter: _BayHopPainter(
            entrance: _entrance,
            pulse: _pulse,
          ),
        );
      },
    );
  }
}

/// Parses a whitespace-separated string of `x,y` pairs into [Offset]s.
List<Offset> _pts(String s) {
  final result = <Offset>[];
  for (final token in s.split(RegExp(r'\s+'))) {
    if (token.isEmpty) continue;
    final parts = token.split(',');
    if (parts.length != 2) continue;
    final x = double.tryParse(parts[0]);
    final y = double.tryParse(parts[1]);
    if (x == null || y == null) continue;
    result.add(Offset(x, y));
  }
  return result;
}

class _BayHopPainter extends CustomPainter {
  _BayHopPainter({
    required this.entrance,
    required this.pulse,
  }) : super(repaint: Listenable.merge([entrance, pulse]));

  final Animation<double> entrance;
  final Animation<double> pulse;

  // ViewBox dimensions all coordinates are expressed in.
  static const double _vbW = 402;
  static const double _vbH = 874;

  @override
  void paint(Canvas canvas, Size size) {
    final t = entrance.value;

    // 1) Background gradient over the raw paint area (before cover transform).
    final bgRect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFEEF2F4), Color(0xFFE6EBEE)],
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // Cover-fit the 402x874 viewBox into the paint size and center it.
    final scale = math.max(size.width / _vbW, size.height / _vbH);
    final dx = (size.width - _vbW * scale) / 2;
    final dy = (size.height - _vbH * scale) / 2;

    canvas
      ..save()
      ..translate(dx, dy)
      ..scale(scale);

    // Derived animation values.
    final routeFraction = Curves.easeInOutCubic.transform(
      (t * 1.5).clamp(0.0, 1.0),
    );
    final baseOpacity = _lerp(
      1,
      0.22,
      ((t - 0.15) / 0.5).clamp(0.0, 1.0),
    );
    final pinsT = ((t - 0.42) / 0.32).clamp(0.0, 1.0);

    // 2) Bay + parks.
    _paintBayAndParks(canvas);

    // 3) Base network (fades out as the route draws in).
    _paintBaseNetwork(canvas, baseOpacity);

    // 4) Highlighted route (draws on).
    _paintRoute(canvas, routeFraction);

    // 5) Overlay pins (fade + slide in; pulse on user location).
    _paintPins(canvas, pinsT, pulse.value);

    canvas.restore();
  }

  /// Simple double lerp (avoids importing extra helpers).
  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  // --- Layer 2: Bay + parks -------------------------------------------------

  void _paintBayAndParks(Canvas canvas) {
    final bayRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(176, -80, 150, 1040),
      const Radius.circular(75),
    );
    final bayPaint = Paint()
      ..color = const Color(0xFFC5DAE6).withValues(alpha: 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);

    canvas
      // The Bay: rotated, softly blurred rounded rect.
      ..save()
      ..translate(250, 400)
      ..rotate(22 * math.pi / 180)
      ..translate(-250, -400)
      ..drawRRect(bayRect, bayPaint)
      ..restore()
      // Park A: small rotated rounded rect.
      ..save()
      ..translate(84, 482)
      ..rotate(-7 * math.pi / 180)
      ..translate(-84, -482)
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(20, 470, 128, 24),
          const Radius.circular(12),
        ),
        Paint()..color = const Color(0xFFD7E3D2).withValues(alpha: 0.8),
      )
      ..restore()
      // Park B: larger rounded rect.
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(262, 206, 150, 120),
          const Radius.circular(40),
        ),
        Paint()..color = const Color(0xFFD7E3D2).withValues(alpha: 0.5),
      );
  }

  // --- Layer 3: Base network ------------------------------------------------

  void _paintBaseNetwork(Canvas canvas, double groupOpacity) {
    _paintMuniFan(canvas, groupOpacity);
    _paintCaltrain(canvas, groupOpacity);
    _paintBart(canvas, groupOpacity);
    _paintStations(canvas, groupOpacity);
    _paintStationLabels(canvas, groupOpacity);
  }

  void _paintMuniFan(Canvas canvas, double groupOpacity) {
    const muni = <(int, String)>[
      (0xFFC99700, '241,393 168,491 150,556'),
      (0xFF4FA6D9, '238,391 165,489 120,600'),
      (0xFF8E44AD, '236,390 163,488 92,648'),
      (0xFF2E9E5B, '233,388 160,486 108,712'),
      (0xFF2D5BD0, '231,386 158,484 60,560'),
      (0xFFE0383E, '235,389 244,470 252,560 258,648'),
    ];
    for (final (color, pts) in muni) {
      final paint = Paint()
        ..color = Color(color).withValues(alpha: 0.9 * groupOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(_polyline(_pts(pts)), paint);
    }
  }

  void _paintCaltrain(Canvas canvas, double groupOpacity) {
    final pts = _pts('120,500 106,548 98,600 92,660');
    final paint = Paint()
      ..color = const Color(0xFF9B2D3A).withValues(alpha: 0.85 * groupOpacity)
      ..style = PaintingStyle.fill;
    // Render evenly spaced round dots along the path (dotted line).
    const dotRadius = 2.25;
    const gap = 9.0;
    var carry = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      final segLen = (b - a).distance;
      if (segLen == 0) continue;
      final dir = (b - a) / segLen;
      var d = carry;
      while (d <= segLen) {
        final p = a + dir * d;
        canvas.drawCircle(p, dotRadius, paint);
        d += gap;
      }
      carry = d - segLen;
    }
  }

  void _paintBart(Canvas canvas, double groupOpacity) {
    // Order matters: red is drawn after yellow so it sits on top.
    const bart = <(int, String)>[
      (
        0xFFFFC72C,
        '303,98 319,160 337,240 356,302 316,358 242,391 216,423 '
            '191,454 169,489 161,548 159,576 163,602 175,634 197,664',
      ),
      (0xFFFFC72C, '197,664 243,690'),
      (0xFFFFC72C, '197,664 203,708'),
      (0xFFF4922A, '402,360 374,336 351,304'),
      (0xFF4DB848, '402,398 380,366 356,320'),
      (0xFF0091D2, '402,438 386,398 360,330'),
      (
        0xFFED1C24,
        '296,96 312,158 330,238 349,300 309,356 235,389 209,421 '
            '184,452 162,487 154,546 152,574 156,600 168,632 190,662',
      ),
      (0xFFED1C24, '190,662 236,688'),
      (0xFFED1C24, '190,662 196,706'),
    ];
    for (final (color, pts) in bart) {
      final paint = Paint()
        ..color = Color(color).withValues(alpha: groupOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(_polyline(_pts(pts)), paint);
    }
  }

  void _paintStations(Canvas canvas, double groupOpacity) {
    const minor = <(double, double)>[
      (296, 96),
      (309, 356),
      (209, 421),
      (184, 452),
      (154, 546),
      (152, 574),
      (168, 632),
      (190, 662),
      (196, 706),
      (106, 548),
      (98, 600),
    ];
    const interchange = <(double, double)>[
      (312, 158),
      (330, 238),
      (349, 300),
      (235, 389),
      (162, 487),
      (156, 600),
      (236, 688),
    ];

    final fill = Paint()
      ..color = Colors.white.withValues(alpha: groupOpacity)
      ..style = PaintingStyle.fill;

    final minorStroke = Paint()
      ..color = const Color(0xFF9AA4AB).withValues(alpha: groupOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final (x, y) in minor) {
      canvas
        ..drawCircle(Offset(x, y), 3.6, fill)
        ..drawCircle(Offset(x, y), 3.6, minorStroke);
    }

    final interStroke = Paint()
      ..color = const Color(0xFF2A3036).withValues(alpha: groupOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final (x, y) in interchange) {
      canvas
        ..drawCircle(Offset(x, y), 6.4, fill)
        ..drawCircle(Offset(x, y), 6.4, interStroke);
    }
  }

  void _paintStationLabels(Canvas canvas, double groupOpacity) {
    // (label, lx, ly, anchorEnd).
    const labels = <(String, double, double, bool)>[
      ('MACARTHUR', 343, 241, false),
      ('12TH ST', 362, 303, false),
      ('EMBARCADERO', 222, 386, true),
      ('CIVIC CENTER', 149, 490, true),
      ('DALY CITY', 143, 603, true),
    ];
    for (final (text, lx, ly, anchorEnd) in labels) {
      _paintLabel(canvas, text, lx, ly, anchorEnd, groupOpacity);
    }
  }

  void _paintLabel(
    Canvas canvas,
    String text,
    double lx,
    double ly,
    bool anchorEnd,
    double groupOpacity,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 7.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: const Color(0xFF7E888F).withValues(alpha: groupOpacity),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final x = anchorEnd ? lx - tp.width : lx;
    final y = ly - tp.height / 2;

    // Light halo: a slightly inflated background block behind the text.
    final halo = Paint()
      ..color = const Color(0xFFEAEEF1).withValues(alpha: 0.7 * groupOpacity);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 1, y, tp.width + 2, tp.height),
        const Radius.circular(2),
      ),
      halo,
    );
    tp.paint(canvas, Offset(x, y));
  }

  // --- Layer 4: Highlighted route -------------------------------------------

  void _paintRoute(Canvas canvas, double routeFraction) {
    final pts = _pts(
      '312,158 330,238 349,300 309,356 235,389 209,421 184,452 '
      '162,487 154,546 152,574 156,600 168,632 190,662 236,688',
    );
    final path = _partialPolyline(pts, routeFraction);

    canvas
      // Blurred glow underneath.
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0xFFED1C24).withValues(alpha: 0.26)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.4),
      )
      // Solid stroke on top.
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0xFFED1C24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
  }

  // --- Layer 5: Overlay pins ------------------------------------------------

  void _paintPins(Canvas canvas, double pinsT, double pulseValue) {
    // Pins slide up from y-7 to y0 and fade in with pinsT.
    final slide = _lerp(-7, 0, pinsT);

    _paintUserLocation(canvas, const Offset(289, 180), pulseValue);
    _paintOrigin(canvas, Offset(312, 158 + slide), pinsT);
    _paintDestination(canvas, Offset(236, 688 + slide), pinsT);
  }

  void _paintUserLocation(Canvas canvas, Offset c, double pulseValue) {
    // Outer pulse ring: radius grows, opacity fades.
    final ringRadius = _lerp(8, 28, pulseValue);
    final ringOpacity = _lerp(0.4, 0, pulseValue);
    canvas
      ..drawCircle(
        c,
        ringRadius,
        Paint()..color = const Color(0xFF0A84FF).withValues(alpha: ringOpacity),
      )
      // Soft drop shadow, white ring, then solid blue dot.
      ..drawCircle(
        c + const Offset(0, 2),
        7,
        Paint()
          ..color = const Color(0xFF0A84FF).withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
      )
      ..drawCircle(c, 7 + 2.5, Paint()..color = Colors.white)
      ..drawCircle(c, 7, Paint()..color = const Color(0xFF0A84FF));
  }

  void _paintOrigin(Canvas canvas, Offset c, double pinsT) {
    if (pinsT <= 0) return;
    // White border + dark dot (18px diameter -> radius 9).
    canvas
      ..drawCircle(
        c + const Offset(0, 3),
        9,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.32 * pinsT)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawCircle(
        c,
        9 + 3,
        Paint()..color = Colors.white.withValues(alpha: pinsT),
      )
      ..drawCircle(
        c,
        9,
        Paint()..color = const Color(0xFF16191C).withValues(alpha: pinsT),
      );
    _paintTag(
      canvas,
      'Downtown Berkeley',
      Offset(c.dx, c.dy - 9 - 6),
      const Color(0xFF16191C),
      Colors.white,
      pinsT,
      bold: false,
    );
  }

  void _paintDestination(Canvas canvas, Offset c, double pinsT) {
    if (pinsT <= 0) return;
    // Red ring + white dot (20px diameter -> radius 10).
    canvas
      ..drawCircle(
        c + const Offset(0, 3),
        10,
        Paint()
          ..color = const Color(0xFFED1C24).withValues(alpha: 0.4 * pinsT)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5),
      )
      ..drawCircle(
        c,
        10 + 4,
        Paint()..color = const Color(0xFFED1C24).withValues(alpha: pinsT),
      )
      ..drawCircle(
        c,
        10,
        Paint()..color = Colors.white.withValues(alpha: pinsT),
      );
    _paintTag(
      canvas,
      'SFO',
      Offset(c.dx, c.dy - 10 - 6),
      const Color(0xFFED1C24),
      Colors.white,
      pinsT,
      bold: true,
    );
  }

  /// Draws a small rounded-rect label centered horizontally above [anchor].
  void _paintTag(
    Canvas canvas,
    String text,
    Offset anchor,
    Color bg,
    Color fg,
    double opacity, {
    required bool bold,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.hankenGrotesk(
          fontSize: 10,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: fg.withValues(alpha: opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padX = 8.0;
    const padY = 3.0;
    final w = tp.width + padX * 2;
    final h = tp.height + padY * 2;
    final rect = Rect.fromLTWH(
      anchor.dx - w / 2,
      anchor.dy - h,
      w,
      h,
    );
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          rect.shift(const Offset(0, 5)),
          const Radius.circular(7),
        ),
        Paint()
          ..color = bg.withValues(alpha: 0.3 * opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(7)),
        Paint()..color = bg.withValues(alpha: opacity),
      );
    tp.paint(canvas, Offset(rect.left + padX, rect.top + padY));
  }

  // --- Geometry helpers -----------------------------------------------------

  /// Builds an open polyline path through [pts].
  Path _polyline(List<Offset> pts) {
    final path = Path();
    if (pts.isEmpty) return path;
    path.moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    return path;
  }

  /// Builds a polyline path covering only the first [fraction] of its total
  /// length (full segments then a partial final segment).
  Path _partialPolyline(List<Offset> pts, double fraction) {
    final path = Path();
    if (pts.isEmpty) return path;
    final f = fraction.clamp(0.0, 1.0);
    if (f <= 0) return path;

    var total = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      total += (pts[i + 1] - pts[i]).distance;
    }
    final target = total * f;

    path.moveTo(pts.first.dx, pts.first.dy);
    var travelled = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      final segLen = (b - a).distance;
      if (segLen == 0) continue;
      if (travelled + segLen <= target) {
        path.lineTo(b.dx, b.dy);
        travelled += segLen;
      } else {
        final remain = target - travelled;
        final p = a + (b - a) * (remain / segLen);
        path.lineTo(p.dx, p.dy);
        break;
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _BayHopPainter oldDelegate) => false;
}
