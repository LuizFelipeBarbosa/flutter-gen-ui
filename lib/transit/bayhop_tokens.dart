import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// BayHop design tokens: the colors, gradients, and typography shared by the
/// whole app so the light-mode "generative transit" look stays consistent.
///
/// Values are transcribed from the BayHop design kit. Components reference
/// these instead of hard-coding hex so the palette can move in one place.
abstract final class BayHopColors {
  // Surfaces.
  static const bgTop = Color(0xFFEEF2F4);
  static const bgBottom = Color(0xFFE6EBEE);
  static const surface = Color(0xFFFFFFFF);

  // Ink ramp (text + iconography).
  static const ink = Color(0xFF16191C);
  static const ink2 = Color(0xFF39424A);
  static const muted = Color(0xFF7A828A);
  static const faint = Color(0xFF9AA2A9);
  static const faintLine = Color(0xFFBAC1C7);

  /// Hairline borders: rgba(20, 24, 28, .05).
  static const hairline = Color(0x0D14181C);

  // The "generative" accent — a blue→purple gradient used for AI moments.
  static const aiBlue = Color(0xFF0091D2);
  static const aiPurple = Color(0xFF5A4BE0);

  // Status.
  static const live = Color(0xFF2E9E5B);
  static const good = Color(0xFF2E9E5B);
  static const warn = Color(0xFFE8920B);
  static const warnText = Color(0xFFB07400);
  static const severe = Color(0xFFED1C24);
  static const severeText = Color(0xFFC81C23);

  // Transit line colors.
  static const red = Color(0xFFED1C24);
  static const yellow = Color(0xFFFFC72C);
  static const orange = Color(0xFFF4922A);
  static const green = Color(0xFF4DB848);
  static const blue = Color(0xFF0091D2);
  static const caltrain = Color(0xFF9B2D3A);

  /// Translucent fill used by chips and quiet rows: rgba(118, 128, 138, .11).
  static const chipBg = Color(0x1C76808A);

  static const aiGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [aiBlue, aiPurple],
  );

  static const bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgBottom],
  );

  /// Legible text color over [background], following the BayHop kit's
  /// auto-contrast rule: WCAG relative luminance > 0.55 reads dark ink,
  /// everything else reads white.
  static Color contrastOn(Color background) {
    double channel(double c) => c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    final luminance =
        0.2126 * channel(background.r) +
        0.7152 * channel(background.g) +
        0.0722 * channel(background.b);
    return luminance > 0.55 ? ink : Colors.white;
  }
}

/// BayHop typography. Three families do all the work: Space Grotesk for
/// display headings and big numbers, Hanken Grotesk for body, and JetBrains
/// Mono for times, fares, and minute counts.
abstract final class BayHopText {
  static TextStyle display({
    double size = 20,
    FontWeight weight = FontWeight.w700,
    Color color = BayHopColors.ink,
    double? height,
    double letterSpacing = -0.2,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = BayHopColors.ink,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.hankenGrotesk(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle mono({
    double size = 12,
    FontWeight weight = FontWeight.w600,
    Color color = BayHopColors.muted,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}

/// Shared responsive rules for the BayHop static chrome.
///
/// Every helper keys off the current width and only *tightens* on narrow phones
/// (≤[narrowPhoneMax]); on common phones (360–430dp) and on tablet/desktop it
/// returns the same values the layout used before, so the design is unchanged
/// where it already looked right. This keeps the spacing/sizing decisions in one
/// place instead of scattered magic numbers at each call site.
abstract final class BayHopResponsive {
  /// At or below this width a phone is "narrow" (iPhone SE, small Android).
  static const double narrowPhoneMax = 360;

  /// Upper bound of the common single-hand phone band.
  static const double phoneMax = 430;

  /// At or above this width the layout is a tablet/desktop split.
  static const double tabletMin = 900;

  /// Side gutter for chrome sections: tighter on narrow phones, 16dp otherwise.
  static double sidePaddingFor(BuildContext context) =>
      MediaQuery.sizeOf(context).width <= narrowPhoneMax ? 14 : 16;

  /// Bottom inset under the transit result area. The flat 120dp wastes a third
  /// of a half-open sheet on short phones, so reclaim it there while keeping
  /// the generous breathing room on common phones and tablets.
  static double resultAreaBottomPaddingFor(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= narrowPhoneMax) return 84;
    if (width >= tabletMin) return 160;
    return 120;
  }

  /// Tinted icon box in action tiles: shrink the box on narrow phones only.
  /// Callers keep their own corner radius and tint.
  static double actionIconBoxFor(BuildContext context) =>
      MediaQuery.sizeOf(context).width <= narrowPhoneMax ? 32 : 34;

  /// Width of a place-search carousel card: tighten only on narrow phones so
  /// the second card still peeks instead of being clipped.
  static double carouselCardWidthFor(BuildContext context) =>
      MediaQuery.sizeOf(context).width <= narrowPhoneMax ? 264 : 292;

  /// Google Map camera padding. Sides are unchanged; the bottom (which keeps
  /// the focus above the sheet) only tightens on narrow phones.
  static EdgeInsets mapCameraPaddingFor(BuildContext context) =>
      MediaQuery.sizeOf(context).width <= narrowPhoneMax
      ? const EdgeInsets.fromLTRB(52, 116, 52, 240)
      : const EdgeInsets.fromLTRB(52, 116, 52, 360);
}
