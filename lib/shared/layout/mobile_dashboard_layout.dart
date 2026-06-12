import 'package:flutter/material.dart';

import '../../theme/spacing.dart';

/// Shared responsive layout helpers for persona mobile dashboards.
abstract final class MobileDashboardLayout {
  static const double tabletBreakpoint = 768;
  static const double largeMobileBreakpoint = 428;
  static const double tabletMaxContentWidth = 480;

  static bool isTablet(double width) => width >= tabletBreakpoint;

  static double horizontalPadding(double width) =>
      isTablet(width) ? AksharaSpacing.tabletMargin : AksharaSpacing.mobileMargin;

  static BoxConstraints contentConstraints(double width) => BoxConstraints(
        maxWidth: isTablet(width) ? tabletMaxContentWidth : double.infinity,
      );

  static EdgeInsets screenPadding(double width) => EdgeInsets.fromLTRB(
        horizontalPadding(width),
        AksharaSpacing.s4,
        horizontalPadding(width),
        AksharaSpacing.s6,
      );
}
