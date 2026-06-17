import 'package:flutter/material.dart';

/// M15 border radius tokens — refined corners for premium enterprise surfaces.
abstract final class AksharaRadius {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double full = 999;

  /// Outlined text field corner — slightly softer than legacy 4px.
  static const double input = 8;

  static BorderRadius get chip => BorderRadius.circular(sm);

  /// Compile-time chip radius for const theme shapes.
  static const BorderRadius chipBorder = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius cardBorder = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius kpiCardBorder =
      BorderRadius.all(Radius.circular(xl));
  static BorderRadius get card => cardBorder;
  static BorderRadius get kpiCard => kpiCardBorder;
  static BorderRadius get dialog => BorderRadius.circular(xxl);
  static BorderRadius get button => BorderRadius.circular(md);
  static BorderRadius get bottomSheet => const BorderRadius.vertical(
        top: Radius.circular(xxl),
      );
  static BorderRadius get avatar => BorderRadius.circular(full);
  static BorderRadius get inputBorder => BorderRadius.circular(input);
  static BorderRadius get fab => BorderRadius.circular(lg);
  static BorderRadius get glass => BorderRadius.circular(xl);
}
