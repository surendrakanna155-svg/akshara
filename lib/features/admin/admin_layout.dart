import 'package:flutter/material.dart';

import '../../theme/breakpoints.dart';
import '../../theme/spacing.dart';

/// Layout helpers for the web ERP admin shell (1440 grid, 1136 content).
abstract final class AdminLayout {
  static const double desktopContentMaxWidth =
      AksharaBreakpoints.desktopContentMaxWidth;

  static LayoutBreakpoint breakpointOf(BuildContext context) {
    return AksharaBreakpoints.fromWidth(MediaQuery.sizeOf(context).width);
  }

  static bool isMobile(BuildContext context) =>
      breakpointOf(context) == LayoutBreakpoint.mobile;

  static bool isTablet(BuildContext context) =>
      breakpointOf(context) == LayoutBreakpoint.tablet;

  static bool isDesktop(BuildContext context) =>
      breakpointOf(context) == LayoutBreakpoint.desktop;

  /// Horizontal padding for admin body sections per breakpoint.
  static EdgeInsets contentPadding(BuildContext context) {
    return switch (breakpointOf(context)) {
      LayoutBreakpoint.mobile =>
        const EdgeInsets.symmetric(horizontal: AksharaSpacing.mobileMargin),
      LayoutBreakpoint.tablet =>
        const EdgeInsets.symmetric(horizontal: AksharaSpacing.tabletMargin),
      LayoutBreakpoint.desktop =>
        const EdgeInsets.symmetric(horizontal: AksharaSpacing.desktopMargin),
    };
  }

  /// Centers body content within the 1136px desktop column.
  static Widget constrainContent({
    required BuildContext context,
    required Widget child,
    bool fillHeight = false,
  }) {
    final padded = Padding(
      padding: contentPadding(context),
      child: child,
    );

    if (!isDesktop(context)) {
      return fillHeight
          ? SizedBox(width: double.infinity, child: padded)
          : padded;
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: desktopContentMaxWidth,
          minHeight: fillHeight ? double.infinity : 0,
        ),
        child: padded,
      ),
    );
  }
}
