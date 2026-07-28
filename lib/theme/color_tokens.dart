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

  // Professional teal accent.
  //
  // A11y-P0: `teal700` is the light-scheme tertiary *foreground* (4.86:1 on
  // teal100 — teal600 was only 3.32:1). `teal400` is the dark-scheme tertiary
  // foreground (6.47:1 on the deep tertiaryContainer — teal600 was 3.21:1),
  // matching the 400-level step the dark scheme already uses for
  // success/warning/error/indigo. `teal600` remains the chart-series tone.
  static const Color teal700 = Color(0xFF0F766E);
  static const Color teal600 = Color(0xFF0D9488);
  static const Color teal400 = Color(0xFF2DD4BF);
  static const Color teal100 = Color(0xFFCCFBF1);

  // Semantic — refined, not oversaturated.
  //
  // A11y-P0 (status-chip contrast): the *foreground* steps are 700-level, not
  // 600. `AksharaStatusChip` defaults to `AksharaStatusChipSize.compact` →
  // `labelSmall` = 11px, which is NORMAL text under WCAG 2.1 (large = ≥24px
  // regular / ≥18.66px bold), so tone-foreground-on-tone-container must clear
  // 4.5:1 — NOT the 3.0:1 large-text floor. The 600 steps only reached
  // 3.07–4.41:1 on their 50-level containers. Do not lighten these back.
  static const Color red700 = Color(0xFFB91C1C); // 5.92:1 on red50
  static const Color red50 = Color(0xFFFEF2F2);
  static const Color green700 = Color(0xFF15803D); // 4.79:1 on green50
  static const Color green50 = Color(0xFFF0FDF4);
  static const Color amber700 = Color(0xFFB45309); // 4.84:1 on amber50
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
  static const Color red500 = red700;
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
      tertiary: AksharaColorPrimitives.teal700,
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
      error: AksharaColorPrimitives.red700,
      errorContainer: AksharaColorPrimitives.red50,
      success: AksharaColorPrimitives.green700,
      successContainer: AksharaColorPrimitives.green50,
      warning: AksharaColorPrimitives.amber700,
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
      // A11y-P0: the dark tertiary tone is a 400-level teal, like every other
      // dark semantic tone (success #4ADE80 / warning #FBBF24 / error #F87171 /
      // indigo). teal600 read only 3.21:1 on the container below — fine for the
      // 3.0 large-text floor but NOT for the 11px `labelSmall` an
      // `AksharaStatusChip` actually paints, which is normal text (4.5:1).
      // teal400 on the same container is 6.47:1.
      tertiary: AksharaColorPrimitives.teal400,
      // The tone is now a light fill, so a white glyph on it would be ~1.86:1.
      // Match `onSecondary` and use the deep obsidian.
      onTertiary: AksharaColorPrimitives.obsidian900,
      // P2-UX-5 dark contrast fix: darkened from #134E4A to #0F3D38. Deepening
      // the fill lifts onSurface / onSurfaceVariant / onTertiaryContainer
      // contrast on it as well. See
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
      // A11y-P0: indigo-300, not indigo-400. #818CF8 on the indigo-900
      // container is 3.83:1 — below the 4.5:1 an 11px chip label needs.
      // #A5B4FC on the same container is 5.73:1.
      indigo: const Color(0xFFA5B4FC),
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
      // DS V2 P2-2 — a true shadow color per mode. Light uses the deep slate
      // `onSurface` (a soft cool-grey cast). Dark must use near-black: the old
      // `shadow: onSurface` painted a *light* halo on dark surfaces (an inverted
      // shadow), so card elevation glowed instead of dropping.
      shadow: isLight ? onSurface : const Color(0xFF000000),
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
