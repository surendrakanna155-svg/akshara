import 'package:flutter/material.dart';

import 'shadows.dart';

/// M15 elevation levels — soft layered shadows for premium enterprise surfaces.
abstract final class AksharaElevation {
  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 2;
  static const double level3 = 4;
  static const double level4 = 8;
  static const double level5 = 12;

  /// Press-state lift increment (Phase 3 interaction system).
  static const double pressLift = 2;

  static double shadowOpacity(int level) => AksharaShadows.opacityForLevel(level);

  /// Soft M15 box shadows — prefers layered preset for levels 2+.
  static List<BoxShadow> boxShadow(
    BuildContext context,
    int level, {
    Color? shadowColor,
    bool layered = true,
  }) {
    if (level <= 0) {
      return const [];
    }

    if (layered && level >= 2) {
      return AksharaShadows.layered(context, level, shadowColor: shadowColor);
    }

    return AksharaShadows.single(context, level, shadowColor: shadowColor);
  }

  /// Material [elevation] value for [Material], [Card], [Dialog], etc.
  static double materialElevation(int level) => switch (level) {
        1 => level1,
        2 => level2,
        3 => level3,
        4 => level4,
        5 => level5,
        _ => level0,
      };
}
