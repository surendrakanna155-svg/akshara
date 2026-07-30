/// NIKSHA M15 Design System — centralized token export.
///
/// Visual modernization foundation (Phase 1). Import this barrel for all
/// theme tokens; features should prefer [AksharaThemeContext] accessors.
library;

export 'accessibility.dart';
export 'app_theme.dart';
export 'breakpoints.dart';
export 'color_tokens.dart';
export 'elevation.dart';
export 'glass.dart';
export 'stitch_palettes.dart';
export 'mesh_background.dart';
export 'locale_typography.dart';
export 'motion.dart';
export 'page_transitions.dart';
export 'radius.dart';
export 'shadows.dart';
export 'spacing.dart';
export 'theme_extensions.dart';
export 'typography.dart';

/// M15 design system version identifier for certification reports.
abstract final class AksharaM15DesignSystem {
  static const String version = '15.5.0';
  static const String codename = 'Premium AI-Native';
}
