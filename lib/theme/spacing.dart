/// 8pt spacing scale from [DesignSystem.md] §6.
abstract final class AksharaSpacing {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s12 = 48;

  // Layout defaults
  static const double sectionPadding = s6;
  static const double cardGap = s4;
  static const double formFieldGap = s6;
  static const double tableCellPaddingH = s3;
  static const double tableCellPaddingV = s4;
  static const double iconTextGap = s2;
  static const double navItemGap = s1;

  // Shell margins & gutters
  static const double mobileMargin = s4;
  static const double tabletMargin = s6;
  static const double desktopMargin = s6;
  static const double mobileGutter = s4;
  static const double tabletGutter = s6;
  static const double desktopGutter = s6;

  // Component heights (design system)
  static const double appBarHeightMobile = 56;
  static const double appBarHeightWeb = 64;
  static const double filterBarHeight = 56;
  static const double bottomNavHeight = 80;
  static const double navRailExpandedWidth = 256;
  static const double navRailCollapsedWidth = 72;
  static const double minTouchTarget = s12;
}
