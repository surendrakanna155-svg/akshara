import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'color_tokens.dart';
import 'spacing.dart';
import 'typography.dart';

/// Semantic tokens not covered by stock [ColorScheme], plus layout constants.
@immutable
class AksharaThemeExtension extends ThemeExtension<AksharaThemeExtension> {
  const AksharaThemeExtension({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
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
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
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

  factory AksharaThemeExtension.fromTokens(AksharaColorTokens tokens) {
    return AksharaThemeExtension(
      success: tokens.success,
      onSuccess: tokens.onPrimary,
      successContainer: tokens.successContainer,
      warning: tokens.warning,
      onWarning: tokens.onSurface,
      warningContainer: tokens.warningContainer,
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
  }) {
    return AksharaThemeExtension(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
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
    );
  }
}

/// KPI card accent colors per [DesignSystem.md] §13.
enum KpiAccent { primary, success, warning, error, neutral }

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
