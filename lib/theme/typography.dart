import 'package:flutter/material.dart';

/// Akshara type scale mapped to Material 3 [TextTheme] roles.
///
/// Font families: Roboto (UI), Roboto Mono (IDs/receipts).
/// Regional Noto families are applied at runtime via [AksharaTextStyles.withFontFamily].
@immutable
class AksharaTextStyles extends ThemeExtension<AksharaTextStyles> {
  const AksharaTextStyles({
    required this.headlineMedium,
    required this.headlineSmall,
    required this.titleLarge,
    required this.titleMedium,
    required this.titleSmall,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.labelSmall,
    required this.monoBody,
  });

  final TextStyle headlineMedium;
  final TextStyle headlineSmall;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle titleSmall;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle labelLarge;
  final TextStyle labelMedium;
  final TextStyle labelSmall;
  final TextStyle monoBody;

  static const String robotoFamily = 'Roboto';
  static const String robotoMonoFamily = 'RobotoMono';

  /// Default Latin type scale (`type/*` tokens).
  factory AksharaTextStyles.roboto({Color? color}) {
    return AksharaTextStyles(
      headlineMedium: _roboto(
        fontSize: 28,
        lineHeight: 36,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      headlineSmall: _roboto(
        fontSize: 24,
        lineHeight: 32,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      titleLarge: _roboto(
        fontSize: 22,
        lineHeight: 28,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      titleMedium: _roboto(
        fontSize: 16,
        lineHeight: 24,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      titleSmall: _roboto(
        fontSize: 14,
        lineHeight: 20,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      bodyLarge: _roboto(
        fontSize: 16,
        lineHeight: 24,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodyMedium: _roboto(
        fontSize: 14,
        lineHeight: 20,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodySmall: _roboto(
        fontSize: 12,
        lineHeight: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        color: color,
      ),
      labelLarge: _roboto(
        fontSize: 14,
        lineHeight: 20,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: color,
      ),
      labelMedium: _roboto(
        fontSize: 12,
        lineHeight: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: color,
      ),
      labelSmall: _roboto(
        fontSize: 11,
        lineHeight: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: color,
      ),
      monoBody: _mono(
        fontSize: 14,
        lineHeight: 20,
        color: color,
      ),
    );
  }

  /// Applies on-surface / on-surface-variant colors from [ColorScheme].
  AksharaTextStyles applyColorScheme(ColorScheme scheme) {
    return copyWith(
      headlineMedium: headlineMedium.copyWith(color: scheme.onSurface),
      headlineSmall: headlineSmall.copyWith(color: scheme.onSurface),
      titleLarge: titleLarge.copyWith(color: scheme.onSurface),
      titleMedium: titleMedium.copyWith(color: scheme.onSurface),
      titleSmall: titleSmall.copyWith(color: scheme.onSurface),
      bodyLarge: bodyLarge.copyWith(color: scheme.onSurface),
      bodyMedium: bodyMedium.copyWith(color: scheme.onSurface),
      bodySmall: bodySmall.copyWith(color: scheme.onSurfaceVariant),
      labelLarge: labelLarge.copyWith(color: scheme.onSurface),
      labelMedium: labelMedium.copyWith(color: scheme.onSurfaceVariant),
      labelSmall: labelSmall.copyWith(color: scheme.onSurfaceVariant),
      monoBody: monoBody.copyWith(color: scheme.onSurface),
    );
  }

  /// Swaps UI font family for regional locales (Noto families bundled in assets).
  AksharaTextStyles withFontFamily(String family, {List<String>? fallback}) {
    TextStyle apply(TextStyle style) => style.copyWith(
          fontFamily: family,
          fontFamilyFallback: fallback ?? style.fontFamilyFallback,
        );

    return AksharaTextStyles(
      headlineMedium: apply(headlineMedium),
      headlineSmall: apply(headlineSmall),
      titleLarge: apply(titleLarge),
      titleMedium: apply(titleMedium),
      titleSmall: apply(titleSmall),
      bodyLarge: apply(bodyLarge),
      bodyMedium: apply(bodyMedium),
      bodySmall: apply(bodySmall),
      labelLarge: apply(labelLarge),
      labelMedium: apply(labelMedium),
      labelSmall: apply(labelSmall),
      monoBody: monoBody,
    );
  }

  TextTheme toMaterialTextTheme() {
    return TextTheme(
      headlineMedium: headlineMedium,
      headlineSmall: headlineSmall,
      titleLarge: titleLarge,
      titleMedium: titleMedium,
      titleSmall: titleSmall,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: labelLarge,
      labelMedium: labelMedium,
      labelSmall: labelSmall,
    );
  }

  @override
  AksharaTextStyles copyWith({
    TextStyle? headlineMedium,
    TextStyle? headlineSmall,
    TextStyle? titleLarge,
    TextStyle? titleMedium,
    TextStyle? titleSmall,
    TextStyle? bodyLarge,
    TextStyle? bodyMedium,
    TextStyle? bodySmall,
    TextStyle? labelLarge,
    TextStyle? labelMedium,
    TextStyle? labelSmall,
    TextStyle? monoBody,
  }) {
    return AksharaTextStyles(
      headlineMedium: headlineMedium ?? this.headlineMedium,
      headlineSmall: headlineSmall ?? this.headlineSmall,
      titleLarge: titleLarge ?? this.titleLarge,
      titleMedium: titleMedium ?? this.titleMedium,
      titleSmall: titleSmall ?? this.titleSmall,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      bodyMedium: bodyMedium ?? this.bodyMedium,
      bodySmall: bodySmall ?? this.bodySmall,
      labelLarge: labelLarge ?? this.labelLarge,
      labelMedium: labelMedium ?? this.labelMedium,
      labelSmall: labelSmall ?? this.labelSmall,
      monoBody: monoBody ?? this.monoBody,
    );
  }

  @override
  AksharaTextStyles lerp(
    covariant ThemeExtension<AksharaTextStyles>? other,
    double t,
  ) {
    if (other is! AksharaTextStyles) {
      return this;
    }

    return AksharaTextStyles(
      headlineMedium: TextStyle.lerp(headlineMedium, other.headlineMedium, t)!,
      headlineSmall: TextStyle.lerp(headlineSmall, other.headlineSmall, t)!,
      titleLarge: TextStyle.lerp(titleLarge, other.titleLarge, t)!,
      titleMedium: TextStyle.lerp(titleMedium, other.titleMedium, t)!,
      titleSmall: TextStyle.lerp(titleSmall, other.titleSmall, t)!,
      bodyLarge: TextStyle.lerp(bodyLarge, other.bodyLarge, t)!,
      bodyMedium: TextStyle.lerp(bodyMedium, other.bodyMedium, t)!,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
      labelLarge: TextStyle.lerp(labelLarge, other.labelLarge, t)!,
      labelMedium: TextStyle.lerp(labelMedium, other.labelMedium, t)!,
      labelSmall: TextStyle.lerp(labelSmall, other.labelSmall, t)!,
      monoBody: TextStyle.lerp(monoBody, other.monoBody, t)!,
    );
  }

  static TextStyle _roboto({
    required double fontSize,
    required double lineHeight,
    required FontWeight fontWeight,
    double letterSpacing = 0,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: robotoFamily,
      fontFamilyFallback: const ['sans-serif'],
      fontSize: fontSize,
      height: lineHeight / fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  static TextStyle _mono({
    required double fontSize,
    required double lineHeight,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: robotoMonoFamily,
      fontFamilyFallback: const ['monospace'],
      fontSize: fontSize,
      height: lineHeight / fontSize,
      fontWeight: FontWeight.w400,
      color: color,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }
}
