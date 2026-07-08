import 'package:flutter/material.dart';

/// M15 raw palette — premium academic identity with slate, indigo, and teal accents.
///
/// Desaturated, enterprise-grade tones inspired by Linear / Stripe Dashboard.
abstract final class AksharaColorPrimitives {
  // Premium Academic Blue (primary identity)
  static const Color blue950 = Color(0xFF0F2A5C);
  static const Color blue900 = Color(0xFF123A8C);
  static const Color blue800 = Color(0xFF1A56DB);
  static const Color blue700 = Color(0xFF2563EB);
  static const Color blue100 = Color(0xFFDBEAFE);
  static const Color blue50 = Color(0xFFEEF4FF);

  // Slate (secondary — professional neutral)
  static const Color slate950 = Color(0xFF0F172A);
  static const Color slate900 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate50 = Color(0xFFF8FAFC);

  // Indigo accent
  static const Color indigo600 = Color(0xFF4F46E5);
  static const Color indigo100 = Color(0xFFE0E7FF);

  // Professional teal accent
  static const Color teal600 = Color(0xFF0D9488);
  static const Color teal100 = Color(0xFFCCFBF1);

  // Semantic — refined, not oversaturated
  static const Color red600 = Color(0xFFDC2626);
  static const Color red50 = Color(0xFFFEF2F2);
  static const Color green700 = Color(0xFF15803D);
  static const Color green50 = Color(0xFFF0FDF4);
  static const Color amber600 = Color(0xFFD97706);
  static const Color amber50 = Color(0xFFFFFBEB);

  // Obsidian dark surfaces (not pure black)
  static const Color obsidian950 = Color(0xFF0A0B0D);
  static const Color obsidian900 = Color(0xFF12141A);
  static const Color obsidian800 = Color(0xFF1A1D24);
  static const Color obsidian700 = Color(0xFF23262F);
  static const Color obsidian600 = Color(0xFF2E323C);
  static const Color obsidian500 = Color(0xFF3D4250);

  // Charts — executive palette
  static const Color chart1 = Color(0xFF1A56DB);
  static const Color chart2 = Color(0xFF0D9488);
  static const Color chart3 = Color(0xFF4F46E5);
  static const Color chart4 = Color(0xFF64748B);
  static const Color chartGrid = Color(0xFFE2E8F0);

  // Scrim
  static const Color scrim = Color(0x661E293B);

  // Legacy aliases (backward compat for direct primitive references)
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = slate50;
  static const Color neutral200 = slate200;
  static const Color neutral500 = slate500;
  static const Color neutral900 = slate900;
  static const Color red500 = red600;
  static const Color green600 = green700;
}

/// Semantic color tokens consumed by [ColorScheme] and [AksharaThemeExtension].
@immutable
class AksharaColorTokens {
  const AksharaColorTokens({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.surface,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
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
    required this.indigo,
    required this.indigoContainer,
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
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color surface;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
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
  final Color indigo;
  final Color indigoContainer;
  final Color chart1;
  final Color chart2;
  final Color chart3;
  final Color chart4;
  final Color chartGrid;

  /// M15 premium light tokens — clean academic surfaces with layered hierarchy.
  factory AksharaColorTokens.light({Color? primaryOverride}) {
    const defaults = AksharaColorTokens(
      primary: AksharaColorPrimitives.blue800,
      onPrimary: AksharaColorPrimitives.neutral0,
      primaryContainer: AksharaColorPrimitives.blue50,
      onPrimaryContainer: AksharaColorPrimitives.blue900,
      secondary: AksharaColorPrimitives.slate700,
      onSecondary: AksharaColorPrimitives.neutral0,
      secondaryContainer: AksharaColorPrimitives.slate100,
      onSecondaryContainer: AksharaColorPrimitives.slate900,
      tertiary: AksharaColorPrimitives.teal600,
      onTertiary: AksharaColorPrimitives.neutral0,
      tertiaryContainer: AksharaColorPrimitives.teal100,
      onTertiaryContainer: Color(0xFF115E59),
      surface: AksharaColorPrimitives.neutral0,
      surfaceContainerLow: AksharaColorPrimitives.slate50,
      surfaceContainer: AksharaColorPrimitives.slate100,
      surfaceContainerHigh: Color(0xFFE8EDF3),
      surfaceContainerHighest: AksharaColorPrimitives.slate200,
      onSurface: AksharaColorPrimitives.slate900,
      onSurfaceVariant: AksharaColorPrimitives.slate500,
      outlineVariant: AksharaColorPrimitives.slate200,
      error: AksharaColorPrimitives.red600,
      errorContainer: AksharaColorPrimitives.red50,
      success: AksharaColorPrimitives.green700,
      successContainer: AksharaColorPrimitives.green50,
      warning: AksharaColorPrimitives.amber600,
      warningContainer: AksharaColorPrimitives.amber50,
      scrim: AksharaColorPrimitives.scrim,
      indigo: AksharaColorPrimitives.indigo600,
      indigoContainer: AksharaColorPrimitives.indigo100,
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

  /// M15 obsidian dark tokens — deep charcoal layered surfaces.
  factory AksharaColorTokens.dark({Color? primaryOverride}) {
    final primary = primaryOverride ?? AksharaColorPrimitives.blue700;
    final seed = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    );

    return AksharaColorTokens(
      primary: seed.primary,
      onPrimary: seed.onPrimary,
      primaryContainer: seed.primaryContainer,
      onPrimaryContainer: seed.onPrimaryContainer,
      secondary: AksharaColorPrimitives.slate300,
      onSecondary: AksharaColorPrimitives.obsidian900,
      secondaryContainer: AksharaColorPrimitives.obsidian700,
      onSecondaryContainer: AksharaColorPrimitives.slate100,
      tertiary: AksharaColorPrimitives.teal600,
      onTertiary: AksharaColorPrimitives.neutral0,
      // P2-UX-5 dark contrast fix: darkened from #134E4A to #0F3D38 so the
      // `tertiary` tone reads >= 3.0:1 on its container (was ~2.53:1; now
      // ~3.21:1). Deepening the fill also lifts onSurface / onSurfaceVariant /
      // onTertiaryContainer contrast on it. See
      // test/theme/rendered_contrast_audit_test.dart.
      tertiaryContainer: const Color(0xFF0F3D38),
      onTertiaryContainer: AksharaColorPrimitives.teal100,
      surface: AksharaColorPrimitives.obsidian800,
      surfaceContainerLow: AksharaColorPrimitives.obsidian900,
      surfaceContainer: AksharaColorPrimitives.obsidian700,
      surfaceContainerHigh: AksharaColorPrimitives.obsidian600,
      surfaceContainerHighest: AksharaColorPrimitives.obsidian500,
      onSurface: const Color(0xFFF1F5F9),
      onSurfaceVariant: AksharaColorPrimitives.slate300,
      outlineVariant: AksharaColorPrimitives.obsidian500,
      error: const Color(0xFFF87171),
      errorContainer: const Color(0xFF5C1A1A),
      success: const Color(0xFF4ADE80),
      successContainer: const Color(0xFF1B3D1D),
      warning: const Color(0xFFFBBF24),
      warningContainer: const Color(0xFF5C3D0A),
      scrim: AksharaColorPrimitives.scrim,
      indigo: const Color(0xFF818CF8),
      indigoContainer: const Color(0xFF312E81),
      chart1: AksharaColorPrimitives.chart2,
      chart2: AksharaColorPrimitives.chart3,
      chart3: AksharaColorPrimitives.chart4,
      chart4: AksharaColorPrimitives.chart1,
      chartGrid: AksharaColorPrimitives.obsidian500,
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
    Color? secondary,
    Color? onSecondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? tertiary,
    Color? onTertiary,
    Color? tertiaryContainer,
    Color? onTertiaryContainer,
    Color? surface,
    Color? surfaceContainerLow,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
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
    Color? indigo,
    Color? indigoContainer,
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
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      tertiary: tertiary ?? this.tertiary,
      onTertiary: onTertiary ?? this.onTertiary,
      tertiaryContainer: tertiaryContainer ?? this.tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer ?? this.onTertiaryContainer,
      surface: surface ?? this.surface,
      surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
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
      indigo: indigo ?? this.indigo,
      indigoContainer: indigoContainer ?? this.indigoContainer,
      chart1: chart1 ?? this.chart1,
      chart2: chart2 ?? this.chart2,
      chart3: chart3 ?? this.chart3,
      chart4: chart4 ?? this.chart4,
      chartGrid: chartGrid ?? this.chartGrid,
    );
  }

  /// Maps semantic tokens to Material 3 [ColorScheme].
  ColorScheme toColorScheme({Brightness brightness = Brightness.light}) {
    final isLight = brightness == Brightness.light;

    return ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: tertiary,
      onTertiary: onTertiary,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      error: error,
      onError: isLight
          ? onPrimary
          : AksharaColorPrimitives.obsidian900,
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
      surfaceTint: Colors.transparent,
      surfaceContainerHighest: surfaceContainerHighest,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainer: surfaceContainer,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainerLowest: isLight ? surface : surfaceContainerLow,
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
