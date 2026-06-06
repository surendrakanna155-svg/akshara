import 'package:flutter/material.dart';

/// Raw palette values from [DesignSystem.md] §4.
abstract final class AksharaColorPrimitives {
  // Blue
  static const Color blue800 = Color(0xFF1565C0);
  static const Color blue50 = Color(0xFFE3F2FD);
  static const Color blue900 = Color(0xFF0D47A1);

  // Neutral
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF8FAFC);
  static const Color neutral200 = Color(0xFFE2E8F0);
  static const Color neutral500 = Color(0xFF64748B);
  static const Color neutral900 = Color(0xFF1E293B);
  static const Color neutral800 = Color(0xFFE8EDF3);

  // Semantic primitives
  static const Color red500 = Color(0xFFD32F2F);
  static const Color red50 = Color(0xFFFFEBEE);
  static const Color green600 = Color(0xFF2E7D32);
  static const Color green50 = Color(0xFFE8F5E9);
  static const Color amber600 = Color(0xFFF57C00);
  static const Color amber50 = Color(0xFFFFF3E0);

  // Charts
  static const Color chart1 = Color(0xFF1565C0);
  static const Color chart2 = Color(0xFF42A5F5);
  static const Color chart3 = Color(0xFF7E57C2);
  static const Color chart4 = Color(0xFF26A69A);
  static const Color chartGrid = Color(0xFFE2E8F0);

  // Scrim — #1E293B @ 40%
  static const Color scrim = Color(0x661E293B);
}

/// Semantic color tokens consumed by [ColorScheme] and [AksharaThemeExtension].
@immutable
class AksharaColorTokens {
  const AksharaColorTokens({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.surface,
    required this.surfaceContainerLow,
    required this.surfaceContainerHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outlineVariant,
    required this.error,
    required this.errorContainer,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.scrim,
    required this.chart1,
    required this.chart2,
    required this.chart3,
    required this.chart4,
    required this.chartGrid,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color surface;
  final Color surfaceContainerLow;
  final Color surfaceContainerHighest;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outlineVariant;
  final Color error;
  final Color errorContainer;
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color scrim;
  final Color chart1;
  final Color chart2;
  final Color chart3;
  final Color chart4;
  final Color chartGrid;

  /// Default Akshara brand light tokens.
  factory AksharaColorTokens.light({Color? primaryOverride}) {
    const defaults = AksharaColorTokens(
      primary: AksharaColorPrimitives.blue800,
      onPrimary: AksharaColorPrimitives.neutral0,
      primaryContainer: AksharaColorPrimitives.blue50,
      onPrimaryContainer: AksharaColorPrimitives.blue900,
      surface: AksharaColorPrimitives.neutral0,
      surfaceContainerLow: AksharaColorPrimitives.neutral50,
      surfaceContainerHighest: AksharaColorPrimitives.neutral800,
      onSurface: AksharaColorPrimitives.neutral900,
      onSurfaceVariant: AksharaColorPrimitives.neutral500,
      outlineVariant: AksharaColorPrimitives.neutral200,
      error: AksharaColorPrimitives.red500,
      errorContainer: AksharaColorPrimitives.red50,
      success: AksharaColorPrimitives.green600,
      successContainer: AksharaColorPrimitives.green50,
      warning: AksharaColorPrimitives.amber600,
      warningContainer: AksharaColorPrimitives.amber50,
      scrim: AksharaColorPrimitives.scrim,
      chart1: AksharaColorPrimitives.chart1,
      chart2: AksharaColorPrimitives.chart2,
      chart3: AksharaColorPrimitives.chart3,
      chart4: AksharaColorPrimitives.chart4,
      chartGrid: AksharaColorPrimitives.chartGrid,
    );

    if (primaryOverride == null) {
      return defaults;
    }

    return defaults.withPrimaryOverride(primaryOverride);
  }

  /// Dark placeholder tokens (P2). Surfaces invert; brand primary unchanged.
  factory AksharaColorTokens.dark({Color? primaryOverride}) {
    final primary = primaryOverride ?? AksharaColorPrimitives.blue800;
    final seed = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    );

    return AksharaColorTokens(
      primary: seed.primary,
      onPrimary: seed.onPrimary,
      primaryContainer: seed.primaryContainer,
      onPrimaryContainer: seed.onPrimaryContainer,
      surface: const Color(0xFF1E293B),
      surfaceContainerLow: const Color(0xFF0F172A),
      surfaceContainerHighest: const Color(0xFF334155),
      onSurface: AksharaColorPrimitives.neutral0,
      onSurfaceVariant: AksharaColorPrimitives.neutral200,
      outlineVariant: const Color(0xFF475569),
      error: AksharaColorPrimitives.red500,
      errorContainer: const Color(0xFF5C1A1A),
      success: AksharaColorPrimitives.green600,
      successContainer: const Color(0xFF1B3D1D),
      warning: AksharaColorPrimitives.amber600,
      warningContainer: const Color(0xFF5C3D0A),
      scrim: AksharaColorPrimitives.scrim,
      chart1: AksharaColorPrimitives.chart2,
      chart2: AksharaColorPrimitives.chart3,
      chart3: AksharaColorPrimitives.chart4,
      chart4: AksharaColorPrimitives.chart1,
      chartGrid: const Color(0xFF475569),
    );
  }

  /// White-label: override primary only; derive container pair from M3 seed.
  AksharaColorTokens withPrimaryOverride(Color primaryOverride) {
    final seed = ColorScheme.fromSeed(
      seedColor: primaryOverride,
      brightness: Brightness.light,
    );

    return copyWith(
      primary: primaryOverride,
      onPrimary: seed.onPrimary,
      primaryContainer: seed.primaryContainer,
      onPrimaryContainer: seed.onPrimaryContainer,
    );
  }

  AksharaColorTokens copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? surface,
    Color? surfaceContainerLow,
    Color? surfaceContainerHighest,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? outlineVariant,
    Color? error,
    Color? errorContainer,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? scrim,
    Color? chart1,
    Color? chart2,
    Color? chart3,
    Color? chart4,
    Color? chartGrid,
  }) {
    return AksharaColorTokens(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      surface: surface ?? this.surface,
      surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
      surfaceContainerHighest:
          surfaceContainerHighest ?? this.surfaceContainerHighest,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      outlineVariant: outlineVariant ?? this.outlineVariant,
      error: error ?? this.error,
      errorContainer: errorContainer ?? this.errorContainer,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      scrim: scrim ?? this.scrim,
      chart1: chart1 ?? this.chart1,
      chart2: chart2 ?? this.chart2,
      chart3: chart3 ?? this.chart3,
      chart4: chart4 ?? this.chart4,
      chartGrid: chartGrid ?? this.chartGrid,
    );
  }

  /// Maps semantic tokens to Material 3 [ColorScheme] (light).
  ColorScheme toColorScheme({Brightness brightness = Brightness.light}) {
    final isLight = brightness == Brightness.light;

    return ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: primary,
      onSecondary: onPrimary,
      secondaryContainer: primaryContainer,
      onSecondaryContainer: onPrimaryContainer,
      tertiary: primary,
      onTertiary: onPrimary,
      tertiaryContainer: primaryContainer,
      onTertiaryContainer: onPrimaryContainer,
      error: error,
      onError: isLight ? onPrimary : AksharaColorPrimitives.neutral0,
      errorContainer: errorContainer,
      onErrorContainer: error,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outlineVariant,
      outlineVariant: outlineVariant,
      shadow: onSurface,
      scrim: scrim,
      inverseSurface: onSurface,
      onInverseSurface: surface,
      inversePrimary: primaryContainer,
      surfaceTint: primary,
      surfaceContainerHighest: surfaceContainerHighest,
      surfaceContainerHigh: Color.alphaBlend(
        surfaceContainerHighest.withValues(alpha: 0.5),
        surfaceContainerLow,
      ),
      surfaceContainer: surfaceContainerLow,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainerLowest: surface,
      surfaceBright: surface,
      surfaceDim: surfaceContainerLow,
    );
  }
}

/// Optional white-label input for [AksharaAppTheme.light].
@immutable
class WhiteLabelThemeConfig {
  const WhiteLabelThemeConfig({this.primary});

  /// School-specific primary brand color. Container pair is derived automatically.
  final Color? primary;

  bool get hasOverride => primary != null;
}
