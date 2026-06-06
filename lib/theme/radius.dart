import 'package:flutter/material.dart';

/// Border radius tokens from [DesignSystem.md] §7.
abstract final class AksharaRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double full = 999;

  /// M3 outlined text field corner per Figma spec.
  static const double input = 4;

  static BorderRadius get chip => BorderRadius.circular(sm);

  /// Compile-time chip radius for const theme shapes.
  static const BorderRadius chipBorder = BorderRadius.all(Radius.circular(sm));
  static BorderRadius get card => BorderRadius.circular(md);
  static BorderRadius get dialog => BorderRadius.circular(lg);
  static BorderRadius get button => BorderRadius.circular(xl);
  static BorderRadius get bottomSheet => const BorderRadius.vertical(
        top: Radius.circular(lg),
      );
  static BorderRadius get avatar => BorderRadius.circular(full);
  static BorderRadius get inputBorder => BorderRadius.circular(input);
  static BorderRadius get fab => BorderRadius.circular(lg);
}
