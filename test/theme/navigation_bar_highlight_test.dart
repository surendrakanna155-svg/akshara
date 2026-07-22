import 'dart:math' as math;

import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// DS V2 P2-1 — the selected bottom-nav item reads in the persona accent: a
/// full-strength `primary` icon + label sitting on a crisp accent-tinted pill
/// (`primary` @ 16%). This replaces the old washed `primaryContainer` pill +
/// dark `onPrimaryContainer` icon, which looked near-identical across personas.
/// The 16% tint keeps the pill pale enough that the full-strength icon clears
/// the 3:1 non-text contrast floor.
void main() {
  for (final entry in {
    'light': AksharaAppTheme.light(),
    'dark': AksharaAppTheme.dark(),
  }.entries) {
    final theme = entry.value;
    final scheme = theme.colorScheme;
    final iconTheme = theme.navigationBarTheme.iconTheme!;

    test('${entry.key}: selected nav icon uses the accent (primary)', () {
      final selected = iconTheme.resolve({WidgetState.selected})!;
      expect(selected.color, scheme.primary);
    });

    test('${entry.key}: unselected nav icon uses onSurfaceVariant', () {
      final unselected = iconTheme.resolve(<WidgetState>{})!;
      expect(unselected.color, scheme.onSurfaceVariant);
    });

    test('${entry.key}: indicator pill is a crisp accent tint', () {
      expect(
        theme.navigationBarTheme.indicatorColor,
        scheme.primary.withValues(alpha: 0.16),
      );
    });

    test('${entry.key}: indicator pill is a stadium', () {
      expect(theme.navigationBarTheme.indicatorShape, isA<StadiumBorder>());
    });

    test('${entry.key}: selected nav icon clears 3:1 on its tinted pill', () {
      // The pill is `primary` @ 16% composited over the nav surface; the icon
      // is full-strength `primary`. Verify the rendered pair clears 3:1.
      final pill = Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.16),
        theme.navigationBarTheme.backgroundColor ?? scheme.surface,
      );
      final ratio = _contrastRatio(scheme.primary, pill);
      expect(ratio, greaterThanOrEqualTo(3.0),
          reason: '${entry.key} selected icon on pill was $ratio:1');
    });
  }
}

double _channel(double v) =>
    v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double _contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}
