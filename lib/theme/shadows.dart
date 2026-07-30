import 'package:flutter/material.dart';

import 'theme_extensions.dart';

/// M15 soft shadow presets — premium enterprise elevation without harsh contrast.
///
/// Used by [AksharaElevation] and glass/interaction surfaces (Phase 3+).
abstract final class AksharaShadows {
  /// Subtle border-adjacent shadow for resting cards.
  static const double ambientBlur = 2;
  static const double ambientSpread = 0;
  static const Offset ambientOffset = Offset(0, 1);

  /// Primary lift shadow for interactive surfaces.
  static const double liftBlur = 8;
  static const double liftSpread = -2;
  static const Offset liftOffset = Offset(0, 4);

  /// Dialog / modal emphasis shadow.
  static const double modalBlur = 24;
  static const double modalSpread = -4;
  static const Offset modalOffset = Offset(0, 12);

  // DS V2 P2-2 — nudged up ~0.01 per level so resting/hover cards read as a soft
  // premium float on the light near-white canvas (was so faint cards looked flat
  // and "default Material"). Still well under the 0.10 soft ceiling at level 2.
  static double opacityForLevel(int level) => switch (level) {
        1 => 0.05,
        2 => 0.07,
        3 => 0.09,
        4 => 0.11,
        5 => 0.13,
        _ => 0.0,
      };

  /// Layered soft shadows for premium card surfaces.
  static List<BoxShadow> layered(
    BuildContext context,
    int level, {
    Color? shadowColor,
  }) {
    if (level <= 0) {
      return const [];
    }

    final base = shadowColor ?? context.colors.shadow;
    final opacity = opacityForLevel(level);

    return [
      BoxShadow(
        color: base.withValues(alpha: opacity * 0.6),
        offset: ambientOffset,
        blurRadius: ambientBlur + (level * 0.5),
        spreadRadius: ambientSpread,
      ),
      BoxShadow(
        color: base.withValues(alpha: opacity),
        offset: Offset(liftOffset.dx, liftOffset.dy * (level * 0.5)),
        blurRadius: liftBlur + (level * 2),
        spreadRadius: liftSpread,
      ),
    ];
  }

  /// Single-shadow fallback matching legacy [AksharaElevation.boxShadow] API.
  static List<BoxShadow> single(
    BuildContext context,
    int level, {
    Color? shadowColor,
  }) {
    if (level <= 0) {
      return const [];
    }

    final color = (shadowColor ?? context.colors.onSurface).withValues(
      alpha: opacityForLevel(level),
    );

    return switch (level) {
      // DS V2 P2-2 — resting cards get a soft, diffuse premium float (a wider
      // blur pulled in with a negative spread) instead of the old 1px hairline,
      // so they lift gently off the canvas without looking heavy.
      1 => [
          BoxShadow(
            color: color,
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      2 => [
          BoxShadow(
            color: color,
            offset: const Offset(0, 2),
            blurRadius: 6,
            spreadRadius: -1,
          ),
        ],
      3 => [
          BoxShadow(
            color: color,
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      4 => [
          BoxShadow(
            color: color,
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      _ => const [],
    };
  }
}
