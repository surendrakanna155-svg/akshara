import 'package:flutter/material.dart';

import '../../theme/breakpoints.dart';
import '../../theme/spacing.dart';

/// Shared responsive layout helpers for persona mobile dashboards.
///
/// Thresholds forward to [AksharaBreakpoints] — the single source of truth —
/// so persona screens and the admin shell never reflow at different widths.
abstract final class MobileDashboardLayout {
  static const double tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double largeMobileBreakpoint =
      AksharaBreakpoints.largeMobileMinWidth;
  static const double tabletMaxContentWidth =
      AksharaBreakpoints.compactContentMaxWidth;

  static bool isTablet(double width) => AksharaBreakpoints.isTabletUp(width);

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
