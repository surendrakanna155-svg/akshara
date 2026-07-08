import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/theme/m15_design_system.dart';

/// P2-UX-3 — the contrast checker, run as an enforced gate (the "contrast
/// checker in CI" leg is CI/live-lane-gated and staged separately; this is the
/// runnable checker it wraps). Every M15 critical foreground/background pair in
/// BOTH the light and dark schemes must clear its WCAG 2.1 AA minimum.
void main() {
  void assertScheme(String label, ColorScheme scheme) {
    group('contrast · $label scheme', () {
      for (final pair in AksharaAccessibility.criticalSchemePairs(scheme)) {
        test('${pair.name} ≥ ${pair.minRatio}:1', () {
          final ratio = AksharaAccessibility.contrastRatio(
            pair.foreground,
            pair.background,
          );
          expect(
            ratio,
            greaterThanOrEqualTo(pair.minRatio),
            reason: '${pair.name} is ${ratio.toStringAsFixed(2)}:1 — below the '
                'WCAG AA floor of ${pair.minRatio}:1 for the $label scheme.',
          );
        });
      }
    });
  }

  assertScheme('light', AksharaColorTokens.light().toColorScheme());
  assertScheme('dark', AksharaColorTokens.dark().toColorScheme());

  test('the contrast helper is calibrated (black on white ≈ 21:1)', () {
    expect(
      AksharaAccessibility.contrastRatio(
        const Color(0xFF000000),
        const Color(0xFFFFFFFF),
      ),
      closeTo(21, 0.5),
    );
  });
}
