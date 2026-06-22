/// Responsive breakpoints from [DesignSystem.md] §18 and FlutterDesignSystem.md §8.
///
/// This is the **single source of truth** for every width threshold in the app.
/// Persona helpers ([MobileDashboardLayout]) and per-screen constants forward to
/// the named values here — do not re-inline raw pixel literals (768/480/428/…)
/// in feature code; reference these instead so layouts never drift apart.
enum LayoutBreakpoint {
  mobile,
  tablet,
  desktop,
}

/// Width thresholds and helpers for admin / web ERP and persona layouts.
abstract final class AksharaBreakpoints {
  // ---- Tier thresholds -----------------------------------------------------

  /// Largest width still treated as a phone.
  static const double mobileMax = 767;

  /// Largest width still treated as a tablet.
  static const double tabletMax = 1199;

  /// First width that counts as a tablet (== [mobileMax] + 1). Use with the
  /// `width >= tabletMinWidth` idiom that persona screens already follow.
  static const double tabletMinWidth = 768;

  /// Large-phone threshold — two-column / wider-pill phone layouts kick in at
  /// or above this width (the old `largeMobileBreakpoint`).
  static const double largeMobileMinWidth = 428;

  /// Narrow-phone threshold — tightest single-column fallbacks below this.
  static const double narrowMobileMaxWidth = 360;

  // ---- Content column widths ----------------------------------------------

  /// Max readable column for persona detail screens on tablet+ (the old
  /// `tabletMaxContentWidth`).
  static const double compactContentMaxWidth = 480;

  /// Max width for centered reading surfaces (copilot dock / screen).
  static const double readingContentMaxWidth = 640;

  /// Desktop content column inside the 1440 frame (256px nav + margins).
  static const double desktopContentMaxWidth = 1136;
  static const double desktopFrameWidth = 1440;

  // ---- Tier helpers --------------------------------------------------------

  static LayoutBreakpoint fromWidth(double width) {
    if (width <= mobileMax) return LayoutBreakpoint.mobile;
    if (width <= tabletMax) return LayoutBreakpoint.tablet;
    return LayoutBreakpoint.desktop;
  }

  static bool isMobile(double width) => fromWidth(width) == LayoutBreakpoint.mobile;

  static bool isTablet(double width) => fromWidth(width) == LayoutBreakpoint.tablet;

  static bool isDesktop(double width) => fromWidth(width) == LayoutBreakpoint.desktop;

  /// True for tablets and desktops — the `width >= tabletMinWidth` idiom.
  static bool isTabletUp(double width) => width >= tabletMinWidth;

  /// True for large phones and up (two-column phone layouts).
  static bool isLargeMobileUp(double width) => width >= largeMobileMinWidth;

  /// True for the narrowest phones, where the tightest fallbacks apply.
  static bool isNarrowMobile(double width) => width < narrowMobileMaxWidth;

  /// True when wide table/`Wrap` layouts should collapse to a stacked card
  /// layout: every phone, **plus tablets held in portrait** (where a dense
  /// `DataTable` still overflows into a horizontal scroll). Desktops and
  /// landscape tablets keep the full table. Orientation-based on purpose — the
  /// width tiers above stay untouched.
  static bool useCardLayout(double width, double height) {
    if (isMobile(width)) return true;
    if (!isTablet(width)) return false; // desktop keeps tables
    return height >= width; // tablet portrait
  }
}
