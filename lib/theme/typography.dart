import 'package:flutter/material.dart';

/// M15 type scale mapped to Material 3 [TextTheme] roles.
///
/// Font families: Roboto (UI), Roboto Mono (IDs/receipts).
/// Regional Noto families are applied at runtime via [AksharaTextStyles.withFontFamily].
///
/// Display styles support dashboard KPI hierarchy (Phase 2 applies to screens).
@immutable
class AksharaTextStyles extends ThemeExtension<AksharaTextStyles> {
  const AksharaTextStyles({
    required this.displayLarge,
    required this.displayMedium,
    required this.displaySmall,
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
    required this.kpiValue,
    required this.kpiLabel,
    required this.tableHeader,
    required this.tableCell,
  });

  final TextStyle displayLarge;
  final TextStyle displayMedium;
  final TextStyle displaySmall;
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
  final TextStyle kpiValue;
  final TextStyle kpiLabel;
  final TextStyle tableHeader;
  final TextStyle tableCell;

  static const String robotoFamily = 'Roboto';
  static const String robotoMonoFamily = 'RobotoMono';

  /// Default Latin type scale with M15 dashboard hierarchy tokens.
  factory AksharaTextStyles.roboto({Color? color}) {
    return AksharaTextStyles(
      displayLarge: _roboto(
        fontSize: 36,
        lineHeight: 44,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: color,
      ),
      displayMedium: _roboto(
        fontSize: 32,
        lineHeight: 40,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        color: color,
      ),
      displaySmall: _roboto(
        fontSize: 28,
        lineHeight: 36,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      headlineMedium: _roboto(
        fontSize: 28,
        lineHeight: 36,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      headlineSmall: _roboto(
        fontSize: 24,
        lineHeight: 32,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      titleLarge: _roboto(
        fontSize: 22,
        lineHeight: 28,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleMedium: _roboto(
        fontSize: 16,
        lineHeight: 24,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleSmall: _roboto(
        fontSize: 14,
        lineHeight: 20,
        fontWeight: FontWeight.w600,
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
      kpiValue: _roboto(
        fontSize: 32,
        lineHeight: 40,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        color: color,
      ),
      kpiLabel: _roboto(
        fontSize: 13,
        lineHeight: 18,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        color: color,
      ),
      tableHeader: _roboto(
        fontSize: 12,
        lineHeight: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: color,
      ),
      tableCell: _roboto(
        fontSize: 14,
        lineHeight: 20,
        fontWeight: FontWeight.w400,
        color: color,
      ),
    );
  }

  /// Applies on-surface / on-surface-variant colors from [ColorScheme].
  AksharaTextStyles applyColorScheme(ColorScheme scheme) {
    return copyWith(
      displayLarge: displayLarge.copyWith(color: scheme.onSurface),
      displayMedium: displayMedium.copyWith(color: scheme.onSurface),
      displaySmall: displaySmall.copyWith(color: scheme.onSurface),
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
      kpiValue: kpiValue.copyWith(color: scheme.onSurface),
      kpiLabel: kpiLabel.copyWith(color: scheme.onSurfaceVariant),
      tableHeader: tableHeader.copyWith(color: scheme.onSurfaceVariant),
      tableCell: tableCell.copyWith(color: scheme.onSurface),
    );
  }

  /// Swaps UI font family for regional locales (Noto families bundled in assets).
  AksharaTextStyles withFontFamily(String family, {List<String>? fallback}) {
    TextStyle apply(TextStyle style) => style.copyWith(
          fontFamily: family,
          fontFamilyFallback: fallback ?? style.fontFamilyFallback,
        );

    return AksharaTextStyles(
      displayLarge: apply(displayLarge),
      displayMedium: apply(displayMedium),
      displaySmall: apply(displaySmall),
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
      kpiValue: apply(kpiValue),
      kpiLabel: apply(kpiLabel),
      tableHeader: apply(tableHeader),
      tableCell: apply(tableCell),
    );
  }

  TextTheme toMaterialTextTheme() {
    return TextTheme(
      displayLarge: displayLarge,
      displayMedium: displayMedium,
      displaySmall: displaySmall,
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
    TextStyle? displayLarge,
    TextStyle? displayMedium,
    TextStyle? displaySmall,
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
    TextStyle? kpiValue,
    TextStyle? kpiLabel,
    TextStyle? tableHeader,
    TextStyle? tableCell,
  }) {
    return AksharaTextStyles(
      displayLarge: displayLarge ?? this.displayLarge,
      displayMedium: displayMedium ?? this.displayMedium,
      displaySmall: displaySmall ?? this.displaySmall,
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
      kpiValue: kpiValue ?? this.kpiValue,
      kpiLabel: kpiLabel ?? this.kpiLabel,
      tableHeader: tableHeader ?? this.tableHeader,
      tableCell: tableCell ?? this.tableCell,
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
      displayLarge: TextStyle.lerp(displayLarge, other.displayLarge, t)!,
      displayMedium: TextStyle.lerp(displayMedium, other.displayMedium, t)!,
      displaySmall: TextStyle.lerp(displaySmall, other.displaySmall, t)!,
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
      kpiValue: TextStyle.lerp(kpiValue, other.kpiValue, t)!,
      kpiLabel: TextStyle.lerp(kpiLabel, other.kpiLabel, t)!,
      tableHeader: TextStyle.lerp(tableHeader, other.tableHeader, t)!,
      tableCell: TextStyle.lerp(tableCell, other.tableCell, t)!,
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
