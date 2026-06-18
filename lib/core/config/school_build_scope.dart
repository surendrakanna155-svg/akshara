import '../../features/admin/models/admin_nav_models.dart';
import '../../router/route_names.dart';

/// Central, reversible scope control for the **school-only** product build.
///
/// Owner decision (2026-06-18, post-audit): hide non-school verticals and
/// experimental / SaaS-platform modules from the app while KEEPING multi-school
/// management (multi-school portfolio, branches, control center, director).
///
/// IMPORTANT — nothing here is deleted. This is the "hide now, delete later"
/// switch the owner approved:
///   * Set [enabled] to `false` to instantly show every module again.
///   * Remove a single entry from [hiddenAdminModules] / [hiddenRoutePrefixes]
///     to bring just that one module back.
/// All screens, routes and code remain in the repository and can be restored
/// at any time.
abstract final class SchoolBuildScope {
  /// Master switch. `false` = full build (everything visible again).
  static const bool enabled = true;

  /// Admin Hub modules hidden from navigation in the school build.
  static const Set<AdminModule> hiddenAdminModules = {
    // Non-school business verticals
    AdminModule.healthcare,
    AdminModule.salon,
    AdminModule.restaurant,
    AdminModule.accommodation,
    AdminModule.industry, // multi-industry framework (feeds the verticals)
    // SaaS / white-label
    AdminModule.whiteLabel,
    // Experimental / "big-company" extras
    AdminModule.organizationBuilder,
    AdminModule.platformOperations,
    AdminModule.dynamicWidgets,
  };

  /// Route prefixes blocked in the school build (covers nested sub-routes).
  ///
  /// KEPT (deliberately not listed): multi-school portfolio, branches, control
  /// center, director, school-config discovery, real onboarding.
  static const Set<String> hiddenRoutePrefixes = {
    // Non-school verticals (parent prefix covers all sub-routes)
    RouteNames.industry, // also /industry/framework
    RouteNames.healthcare,
    RouteNames.salon,
    RouteNames.restaurant,
    RouteNames.accommodation,
    // SaaS / white-label
    RouteNames.whiteLabel,
    RouteNames.franchise,
    // Experimental / "big-company" extras
    RouteNames.organizationBuilder, // also interview/preview/provisioning
    RouteNames.platformOperations,
    RouteNames.dynamicWidgets, // also /dynamic-widgets/layout|runtime
    RouteNames.dynamicDashboard,
    RouteNames.resourceOptimization,
    RouteNames.schoolMemories,
    // Evolution suite (experimental, not wired into real persona flows)
    RouteNames.setupWizard, // demo wizard; real onboarding is separate
    RouteNames.teacherAssistant,
    RouteNames.parentInsights,
    RouteNames.principalCommand,
    RouteNames.growthPlatform,
  };

  /// Whether [module] is hidden from the admin navigation in this build.
  static bool isModuleHidden(AdminModule module) =>
      enabled && hiddenAdminModules.contains(module);

  /// Whether [location] belongs to a module hidden in this build.
  static bool isRouteHidden(String location) {
    if (!enabled) return false;
    for (final prefix in hiddenRoutePrefixes) {
      if (location == prefix || location.startsWith('$prefix/')) {
        return true;
      }
    }
    return false;
  }
}
