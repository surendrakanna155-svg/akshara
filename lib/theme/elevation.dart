import 'package:flutter/material.dart';

import 'theme_extensions.dart';

/// Elevation levels from [DesignSystem.md] §7.
abstract final class AksharaElevation {
  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 2;
  static const double level3 = 3;
  static const double level4 = 4;

  static double shadowOpacity(int level) => switch (level) {
        1 => 0.08,
        2 => 0.10,
        3 => 0.12,
        4 => 0.14,
        _ => 0.0,
      };

  static List<BoxShadow> boxShadow(
    BuildContext context,
    int level, {
    Color? shadowColor,
  }) {
    if (level <= 0) {
      return const [];
    }

    final color = (shadowColor ?? context.colors.onSurface).withValues(
      alpha: shadowOpacity(level),
    );

    return switch (level) {
      1 => [
          BoxShadow(
            color: color,
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      2 => [
          BoxShadow(
            color: color,
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      3 => [
          BoxShadow(
            color: color,
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      4 => [
          BoxShadow(
            color: color,
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      _ => const [],
    };
  }

  /// Material [elevation] value for [Material], [Card], [Dialog], etc.
  static double materialElevation(int level) => switch (level) {
        1 => level1,
        2 => level2,
        3 => level3,
        4 => level4,
        _ => level0,
      };
}
