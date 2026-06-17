import 'package:flutter/material.dart';

/// M15 accessibility helpers — WCAG contrast checks and readable type floors.
abstract final class AksharaAccessibility {
  /// WCAG 2.1 AA minimum for normal body text.
  static const double minContrastNormalText = 4.5;

  /// WCAG 2.1 AA minimum for large text (18pt+ regular or 14pt+ bold).
  static const double minContrastLargeText = 3.0;

  /// WCAG 2.1 AA minimum for UI boundaries and graphical objects.
  static const double minContrastUiComponent = 3.0;

  /// Smallest M15 token size used for labels — do not go below for legibility.
  static const double minLabelFontSize = 11;

  /// Returns contrast ratio between [foreground] and [background] (1:1 … 21:1).
  static double contrastRatio(Color foreground, Color background) {
    final fg = foreground.computeLuminance();
    final bg = background.computeLuminance();
    final lighter = fg > bg ? fg : bg;
    final darker = fg > bg ? bg : fg;
    return (lighter + 0.05) / (darker + 0.05);
  }

  static bool meetsNormalTextContrast(Color foreground, Color background) {
    return contrastRatio(foreground, background) >= minContrastNormalText;
  }

  static bool meetsLargeTextContrast(Color foreground, Color background) {
    return contrastRatio(foreground, background) >= minContrastLargeText;
  }

  /// Critical [ColorScheme] pairs validated in M15 certification.
  static List<({String name, Color foreground, Color background, double minRatio})>
      criticalSchemePairs(ColorScheme scheme) {
    return [
      (
        name: 'onSurface on surface',
        foreground: scheme.onSurface,
        background: scheme.surface,
        minRatio: minContrastNormalText,
      ),
      (
        name: 'onSurfaceVariant on surface',
        foreground: scheme.onSurfaceVariant,
        background: scheme.surface,
        minRatio: minContrastLargeText,
      ),
      (
        name: 'onPrimary on primary',
        foreground: scheme.onPrimary,
        background: scheme.primary,
        minRatio: minContrastNormalText,
      ),
      (
        name: 'onPrimaryContainer on primaryContainer',
        foreground: scheme.onPrimaryContainer,
        background: scheme.primaryContainer,
        minRatio: minContrastNormalText,
      ),
      (
        name: 'onSecondary on secondary',
        foreground: scheme.onSecondary,
        background: scheme.secondary,
        minRatio: minContrastNormalText,
      ),
      (
        name: 'onError on error',
        foreground: scheme.onError,
        background: scheme.error,
        minRatio: minContrastNormalText,
      ),
      (
        name: 'primary on surface',
        foreground: scheme.primary,
        background: scheme.surface,
        minRatio: minContrastUiComponent,
      ),
    ];
  }
}
