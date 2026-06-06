/// Responsive breakpoints from [DesignSystem.md] §18 and FlutterDesignSystem.md §8.
enum LayoutBreakpoint {
  mobile,
  tablet,
  desktop,
}

/// Width thresholds and helpers for admin / web ERP layouts.
abstract final class AksharaBreakpoints {
  static const double mobileMax = 767;
  static const double tabletMax = 1199;

  /// Desktop content column inside the 1440 frame (256px nav + margins).
  static const double desktopContentMaxWidth = 1136;
  static const double desktopFrameWidth = 1440;

  static LayoutBreakpoint fromWidth(double width) {
    if (width <= mobileMax) return LayoutBreakpoint.mobile;
    if (width <= tabletMax) return LayoutBreakpoint.tablet;
    return LayoutBreakpoint.desktop;
  }

  static bool isMobile(double width) => fromWidth(width) == LayoutBreakpoint.mobile;

  static bool isTablet(double width) => fromWidth(width) == LayoutBreakpoint.tablet;

  static bool isDesktop(double width) => fromWidth(width) == LayoutBreakpoint.desktop;
}
