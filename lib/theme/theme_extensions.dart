import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'color_tokens.dart';
import 'spacing.dart';
import 'typography.dart';

/// Semantic tokens not covered by stock [ColorScheme], plus M15 layout constants.
@immutable
class AksharaThemeExtension extends ThemeExtension<AksharaThemeExtension> {
  const AksharaThemeExtension({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.indigo,
    required this.indigoContainer,
    required this.tertiary,
    required this.tertiaryContainer,
    required this.surfaceContainerHighest,
    required this.scrim,
    required this.chart1,
    required this.chart2,
    required this.chart3,
    required this.chart4,
    required this.chartGrid,
    required this.navRailExpandedWidth,
    required this.navRailCollapsedWidth,
    required this.filterBarHeight,
    required this.bottomNavHeight,
    required this.focusRingWidth,
    required this.focusRingGap,
    required this.glassOpacity,
    required this.glassBorderOpacity,
    required this.dashboardWatermarkOpacity,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color indigo;
  final Color indigoContainer;
  final Color tertiary;
  final Color tertiaryContainer;
  final Color surfaceContainerHighest;
  final Color scrim;
  final Color chart1;
  final Color chart2;
  final Color chart3;
  final Color chart4;
  final Color chartGrid;
  final double navRailExpandedWidth;
  final double navRailCollapsedWidth;
  final double filterBarHeight;
  final double bottomNavHeight;
  final double focusRingWidth;
  final double focusRingGap;

  /// Glass surface fill opacity (Phase 8 — hero sections, dialogs).
  final double glassOpacity;

  /// Glass border stroke opacity.
  final double glassBorderOpacity;

  /// AI-native dashboard watermark opacity (3%–8%).
  final double dashboardWatermarkOpacity;

  factory AksharaThemeExtension.fromTokens(
    AksharaColorTokens tokens, {
    Brightness brightness = Brightness.light,
  }) {
    final isDark = brightness == Brightness.dark;
    return AksharaThemeExtension(
      success: tokens.success,
      onSuccess: tokens.onPrimary,
      successContainer: tokens.successContainer,
      warning: tokens.warning,
      onWarning: tokens.onSurface,
      warningContainer: tokens.warningContainer,
      indigo: tokens.indigo,
      indigoContainer: tokens.indigoContainer,
      tertiary: tokens.tertiary,
      tertiaryContainer: tokens.tertiaryContainer,
      surfaceContainerHighest: tokens.surfaceContainerHighest,
      scrim: tokens.scrim,
      chart1: tokens.chart1,
      chart2: tokens.chart2,
      chart3: tokens.chart3,
      chart4: tokens.chart4,
      chartGrid: tokens.chartGrid,
      navRailExpandedWidth: AksharaSpacing.navRailExpandedWidth,
      navRailCollapsedWidth: AksharaSpacing.navRailCollapsedWidth,
      filterBarHeight: AksharaSpacing.filterBarHeight,
      bottomNavHeight: AksharaSpacing.bottomNavHeight,
      focusRingWidth: 2,
      focusRingGap: 2,
      glassOpacity: isDark ? 0.60 : 0.82,
      glassBorderOpacity: isDark ? 0.08 : 0.12,
      dashboardWatermarkOpacity: isDark ? 0.06 : 0.04,
    );
  }

  @override
  AksharaThemeExtension copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? indigo,
    Color? indigoContainer,
    Color? tertiary,
    Color? tertiaryContainer,
    Color? surfaceContainerHighest,
    Color? scrim,
    Color? chart1,
    Color? chart2,
    Color? chart3,
    Color? chart4,
    Color? chartGrid,
    double? navRailExpandedWidth,
    double? navRailCollapsedWidth,
    double? filterBarHeight,
    double? bottomNavHeight,
    double? focusRingWidth,
    double? focusRingGap,
    double? glassOpacity,
    double? glassBorderOpacity,
    double? dashboardWatermarkOpacity,
  }) {
    return AksharaThemeExtension(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      indigo: indigo ?? this.indigo,
      indigoContainer: indigoContainer ?? this.indigoContainer,
      tertiary: tertiary ?? this.tertiary,
      tertiaryContainer: tertiaryContainer ?? this.tertiaryContainer,
      surfaceContainerHighest:
          surfaceContainerHighest ?? this.surfaceContainerHighest,
      scrim: scrim ?? this.scrim,
      chart1: chart1 ?? this.chart1,
      chart2: chart2 ?? this.chart2,
      chart3: chart3 ?? this.chart3,
      chart4: chart4 ?? this.chart4,
      chartGrid: chartGrid ?? this.chartGrid,
      navRailExpandedWidth: navRailExpandedWidth ?? this.navRailExpandedWidth,
      navRailCollapsedWidth:
          navRailCollapsedWidth ?? this.navRailCollapsedWidth,
      filterBarHeight: filterBarHeight ?? this.filterBarHeight,
      bottomNavHeight: bottomNavHeight ?? this.bottomNavHeight,
      focusRingWidth: focusRingWidth ?? this.focusRingWidth,
      focusRingGap: focusRingGap ?? this.focusRingGap,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      glassBorderOpacity: glassBorderOpacity ?? this.glassBorderOpacity,
      dashboardWatermarkOpacity:
          dashboardWatermarkOpacity ?? this.dashboardWatermarkOpacity,
    );
  }

  @override
  AksharaThemeExtension lerp(
    covariant ThemeExtension<AksharaThemeExtension>? other,
    double t,
  ) {
    if (other is! AksharaThemeExtension) {
      return this;
    }

    return AksharaThemeExtension(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      indigo: Color.lerp(indigo, other.indigo, t)!,
      indigoContainer: Color.lerp(indigoContainer, other.indigoContainer, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      tertiaryContainer:
          Color.lerp(tertiaryContainer, other.tertiaryContainer, t)!,
      surfaceContainerHighest: Color.lerp(
        surfaceContainerHighest,
        other.surfaceContainerHighest,
        t,
      )!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      chart1: Color.lerp(chart1, other.chart1, t)!,
      chart2: Color.lerp(chart2, other.chart2, t)!,
      chart3: Color.lerp(chart3, other.chart3, t)!,
      chart4: Color.lerp(chart4, other.chart4, t)!,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!,
      navRailExpandedWidth: lerpDouble(
            navRailExpandedWidth,
            other.navRailExpandedWidth,
            t,
          ) ??
          navRailExpandedWidth,
      navRailCollapsedWidth: lerpDouble(
            navRailCollapsedWidth,
            other.navRailCollapsedWidth,
            t,
          ) ??
          navRailCollapsedWidth,
      filterBarHeight:
          lerpDouble(filterBarHeight, other.filterBarHeight, t) ??
              filterBarHeight,
      bottomNavHeight:
          lerpDouble(bottomNavHeight, other.bottomNavHeight, t) ??
              bottomNavHeight,
      focusRingWidth:
          lerpDouble(focusRingWidth, other.focusRingWidth, t) ?? focusRingWidth,
      focusRingGap:
          lerpDouble(focusRingGap, other.focusRingGap, t) ?? focusRingGap,
      glassOpacity:
          lerpDouble(glassOpacity, other.glassOpacity, t) ?? glassOpacity,
      glassBorderOpacity: lerpDouble(
            glassBorderOpacity,
            other.glassBorderOpacity,
            t,
          ) ??
          glassBorderOpacity,
      dashboardWatermarkOpacity: lerpDouble(
            dashboardWatermarkOpacity,
            other.dashboardWatermarkOpacity,
            t,
          ) ??
          dashboardWatermarkOpacity,
    );
  }
}

/// KPI card accent colors — M15 semantic mapping.
enum KpiAccent { primary, success, warning, error, neutral, tertiary, indigo }

extension KpiAccentColors on KpiAccent {
  ({Color container, Color foreground}) resolve(BuildContext context) {
    final scheme = context.colors;
    final ext = context.akshara;

    return switch (this) {
      KpiAccent.primary => (
          container: scheme.primaryContainer,
          foreground: scheme.primary,
        ),
      KpiAccent.success => (
          container: ext.successContainer,
          foreground: ext.success,
        ),
      KpiAccent.warning => (
          container: ext.warningContainer,
          foreground: ext.warning,
        ),
      KpiAccent.error => (
          container: scheme.errorContainer,
          foreground: scheme.error,
        ),
      KpiAccent.neutral => (
          container: scheme.surfaceContainerLow,
          foreground: scheme.onSurfaceVariant,
        ),
      KpiAccent.tertiary => (
          container: ext.tertiaryContainer,
          foreground: ext.tertiary,
        ),
      KpiAccent.indigo => (
          container: ext.indigoContainer,
          foreground: ext.indigo,
        ),
    };
  }
}

/// Convenient theme accessors for widgets and features.
extension AksharaThemeContext on BuildContext {
  AksharaThemeExtension get akshara =>
      Theme.of(this).extension<AksharaThemeExtension>()!;

  AksharaTextStyles get aksharaText =>
      Theme.of(this).extension<AksharaTextStyles>()!;

  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get text => Theme.of(this).textTheme;

  /// Returns [AksharaThemeExtension] or null when theme is not fully initialized.
  AksharaThemeExtension? get aksharaOrNull =>
      Theme.of(this).extension<AksharaThemeExtension>();
}
