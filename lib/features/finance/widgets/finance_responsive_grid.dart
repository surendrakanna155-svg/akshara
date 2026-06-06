import 'package:flutter/material.dart';

import '../../../theme/breakpoints.dart';
import '../../../theme/spacing.dart';

/// Responsive column count for KPI / card grids in finance screens.
int financeGridColumns(
  double width, {
  required int desktop,
  int? tablet,
  int? mobile,
}) {
  final bp = AksharaBreakpoints.fromWidth(width);
  return switch (bp) {
    LayoutBreakpoint.desktop => desktop,
    LayoutBreakpoint.tablet => tablet ?? (desktop > 3 ? 3 : desktop),
    LayoutBreakpoint.mobile => mobile ?? 2,
  };
}

/// Lays out [children] in a responsive grid for finance dashboards.
class FinanceResponsiveGrid extends StatelessWidget {
  const FinanceResponsiveGrid({
    super.key,
    required this.children,
    this.desktopColumns = 3,
    this.tabletColumns,
    this.mobileColumns = 2,
    this.spacing = AksharaSpacing.s4,
    this.runSpacing = AksharaSpacing.s4,
  });

  final List<Widget> children;
  final int desktopColumns;
  final int? tabletColumns;
  final int mobileColumns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = financeGridColumns(
      width,
      desktop: desktopColumns,
      tablet: tabletColumns,
      mobile: mobileColumns,
    );

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: [
        for (final child in children)
          SizedBox(
            width: _itemWidth(width, columns, spacing),
            child: child,
          ),
      ],
    );
  }

  double _itemWidth(double totalWidth, int columns, double gap) {
    final horizontalPadding = AksharaBreakpoints.isDesktop(totalWidth)
        ? AksharaSpacing.desktopMargin * 2
        : AksharaBreakpoints.isTablet(totalWidth)
            ? AksharaSpacing.tabletMargin * 2
            : AksharaSpacing.mobileMargin * 2;
    final contentWidth = totalWidth - horizontalPadding;
    final gaps = gap * (columns - 1);
    return (contentWidth - gaps) / columns;
  }
}
