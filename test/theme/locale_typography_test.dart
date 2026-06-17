import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/theme/locale_typography.dart';
import 'package:akshara_erp/theme/typography.dart';

void main() {
  group('AksharaLocaleTypography', () {
    test('maps supported Indian language codes to Noto families', () {
      expect(
        AksharaLocaleTypography.scriptFontFamilyFor(const Locale('te')),
        AksharaLocaleTypography.telugu,
      );
      expect(
        AksharaLocaleTypography.scriptFontFamilyFor(const Locale('hi', 'IN')),
        AksharaLocaleTypography.devanagari,
      );
      expect(
        AksharaLocaleTypography.scriptFontFamilyFor(const Locale('ta')),
        AksharaLocaleTypography.tamil,
      );
      expect(
        AksharaLocaleTypography.scriptFontFamilyFor(const Locale('kn')),
        AksharaLocaleTypography.kannada,
      );
      expect(
        AksharaLocaleTypography.scriptFontFamilyFor(const Locale('ml')),
        AksharaLocaleTypography.malayalam,
      );
      expect(
        AksharaLocaleTypography.scriptFontFamilyFor(const Locale('ur')),
        AksharaLocaleTypography.urdu,
      );
    });

    test('English locale keeps Roboto primary family', () {
      final base = AksharaTextStyles.roboto();
      final applied = AksharaLocaleTypography.applyLocale(
        base,
        const Locale('en'),
      );

      expect(applied.bodyLarge.fontFamily, AksharaTextStyles.robotoFamily);
    });

    test('Telugu locale swaps primary family with Roboto fallback', () {
      final base = AksharaTextStyles.roboto();
      final applied = AksharaLocaleTypography.applyLocale(
        base,
        const Locale('te'),
      );

      expect(applied.bodyLarge.fontFamily, AksharaLocaleTypography.telugu);
      expect(
        applied.bodyLarge.fontFamilyFallback,
        contains(AksharaTextStyles.robotoFamily),
      );
    });

    test('Urdu locale is flagged RTL', () {
      expect(AksharaLocaleTypography.isRtlLocale(const Locale('ur')), isTrue);
      expect(AksharaLocaleTypography.isRtlLocale(const Locale('hi')), isFalse);
    });

    test('supportedLanguageCodes covers M15 regional set', () {
      expect(
        AksharaLocaleTypography.supportedLanguageCodes,
        containsAll(['en', 'te', 'hi', 'ta', 'kn', 'ml', 'ur']),
      );
    });
  });
}
