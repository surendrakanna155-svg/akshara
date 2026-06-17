import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/theme/m15_design_system.dart';

void main() {
  group('M15 Design System — Phase 1 tokens', () {
    test('light color tokens expose distinct secondary and tertiary', () {
      final tokens = AksharaColorTokens.light();

      expect(tokens.primary, const Color(0xFF1A56DB));
      expect(tokens.secondary, const Color(0xFF334155));
      expect(tokens.tertiary, const Color(0xFF0D9488));
      expect(tokens.indigo, const Color(0xFF4F46E5));
    });

    test('light surface hierarchy is layered low → high', () {
      final tokens = AksharaColorTokens.light();

      expect(tokens.surface, const Color(0xFFFFFFFF));
      expect(tokens.surfaceContainerLow, const Color(0xFFF8FAFC));
      expect(tokens.surfaceContainer, const Color(0xFFF1F5F9));
      expect(tokens.surfaceContainerHigh, const Color(0xFFE8EDF3));
      expect(tokens.surfaceContainerHighest, const Color(0xFFE2E8F0));
    });

    test('dark tokens use obsidian surfaces not pure black', () {
      final tokens = AksharaColorTokens.dark();

      expect(tokens.surface, const Color(0xFF1A1D24));
      expect(tokens.surfaceContainerLow, const Color(0xFF12141A));
      expect(tokens.surface, isNot(const Color(0xFF000000)));
    });

    test('ColorScheme maps secondary and tertiary from tokens', () {
      final scheme = AksharaColorTokens.light().toColorScheme();

      expect(scheme.secondary, const Color(0xFF334155));
      expect(scheme.tertiary, const Color(0xFF0D9488));
      expect(scheme.surfaceTint, Colors.transparent);
    });

    test('AksharaAppTheme.light includes M15 extensions', () {
      final theme = AksharaAppTheme.light();
      final ext = theme.extension<AksharaThemeExtension>()!;
      final text = theme.extension<AksharaTextStyles>()!;

      expect(ext.glassOpacity, 0.72);
      expect(ext.dashboardWatermarkOpacity, inInclusiveRange(0.03, 0.08));
      expect(text.kpiValue.fontSize, 32);
      expect(text.displayLarge.fontWeight, FontWeight.w600);
    });

    test('semantic colors are refined not oversaturated', () {
      final tokens = AksharaColorTokens.light();

      expect(tokens.success, const Color(0xFF15803D));
      expect(tokens.warning, const Color(0xFFD97706));
      expect(tokens.error, const Color(0xFFDC2626));
    });

    test('M15 design system version is set', () {
      expect(AksharaM15DesignSystem.version, '15.0.0');
    });

    test('AksharaAccessibility contrast helper is exported', () {
      expect(AksharaAccessibility.minContrastNormalText, 4.5);
    });

    test('AksharaRadius uses premium card and KPI corners', () {
      expect(AksharaRadius.card, BorderRadius.circular(16));
      expect(AksharaRadius.kpiCard, BorderRadius.circular(20));
      expect(AksharaRadius.glass, BorderRadius.circular(20));
      expect(AksharaRadius.input, 8);
    });

    test('AksharaGlass blur tokens are defined', () {
      expect(AksharaGlass.blurSigma, 12);
      expect(AksharaGlass.heroSheenOpacity, greaterThan(0));
    });

    test('AksharaElevation uses soft shadow levels', () {
      expect(AksharaElevation.level3, 4);
      expect(AksharaShadows.opacityForLevel(2), lessThan(0.10));
    });
  });
}
