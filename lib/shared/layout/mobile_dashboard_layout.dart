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

  /// Bounds shell tab bodies so [SingleChildScrollView] scrolls and
  /// [Column] + [Expanded] layouts do not bottom-overflow.
  static Widget boundedShellBody({
    required BoxConstraints constraints,
    required Widget child,
    double? maxContentWidth,
  }) {
    final contentWidth = maxContentWidth ??
        (isTablet(constraints.maxWidth)
            ? tabletMaxContentWidth
            : constraints.maxWidth);

    return SizedBox(
      height: constraints.maxHeight,
      width: constraints.maxWidth,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: contentWidth,
          height: constraints.maxHeight,
          child: child,
        ),
      ),
    );
  }
}
