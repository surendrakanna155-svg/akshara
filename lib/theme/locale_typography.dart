import 'package:flutter/material.dart';

import 'typography.dart';

/// Regional script font mapping per [DesignSystem.md] §5.
///
/// Font families resolve via platform Noto bundles; Latin fallback stays Roboto.
abstract final class AksharaLocaleTypography {
  static const Set<String> supportedLanguageCodes = {
    'en',
    'te',
    'hi',
    'ta',
    'kn',
    'ml',
    'ur',
  };

  static const String telugu = 'NotoSansTelugu';
  static const String devanagari = 'NotoSansDevanagari';
  static const String tamil = 'NotoSansTamil';
  static const String kannada = 'NotoSansKannada';
  static const String malayalam = 'NotoSansMalayalam';
  static const String urdu = 'NotoNastaliqUrdu';

  /// Script-primary UI family for [locale], or null for default Roboto (English).
  static String? scriptFontFamilyFor(Locale locale) {
    return switch (locale.languageCode) {
      'te' => telugu,
      'hi' => devanagari,
      'ta' => tamil,
      'kn' => kannada,
      'ml' => malayalam,
      'ur' => urdu,
      _ => null,
    };
  }

  /// Whether [locale] uses a right-to-left script (Urdu).
  static bool isRtlLocale(Locale locale) => locale.languageCode == 'ur';

  /// Applies regional font family with Latin fallback for mixed-script UI.
  static AksharaTextStyles applyLocale(
    AksharaTextStyles base,
    Locale? locale,
  ) {
    if (locale == null) {
      return base;
    }

    final scriptFont = scriptFontFamilyFor(locale);
    if (scriptFont == null) {
      return base;
    }

    return base.withFontFamily(
      scriptFont,
      fallback: const [
        AksharaTextStyles.robotoFamily,
        'sans-serif',
      ],
    );
  }
}
