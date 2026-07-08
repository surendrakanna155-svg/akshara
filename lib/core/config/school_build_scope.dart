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
    AdminModule.platformOperations,
    AdminModule.dynamicWidgets,
    // Management executive-dashboard module (MG-01→MG-08) is not yet built — its
    // primary nav destination routes to an empty placeholder. Hide the entry until
    // the module ships (owner decision 2026-07-09) so users don't hit a dead screen.
    // Nav-only (isModuleHidden gates the sidebar, never routes): the real management
    // surfaces (/management/approvals principal approval center, office attendance)
    // keep their own routes and remain reachable.
    AdminModule.management,
    // NOTE: organizationBuilder is no longer hidden here — it is now gated by
    // chain status at runtime (M3, see ChainScope), so real chains can see it.
  };

  /// Route prefixes blocked in the school build (covers nested sub-routes).
  ///
  /// KEPT (deliberately not listed): branches, control center, director, real
  /// onboarding.
  // branches now also chain-gated via ChainScope (CORE-2, 2026-06-25) — unreachable in single-school pilot.
  ///
  /// CHAIN-GATED elsewhere (not here): franchise, multi-school portfolio/
  /// onboarding and organization-builder surface only for chain orgs at runtime
  /// — see [ChainScope] (M3, 2026-06-22). School-config discovery is NOT
  /// chain-gated (B1) — it is the per-school capability wizard, reachable from
  /// Management → Settings by any school admin/principal (gated on viewSchoolSetup).
  static const Set<String> hiddenRoutePrefixes = {
    // Non-school verticals (parent prefix covers all sub-routes)
    RouteNames.industry, // also /industry/framework
    RouteNames.healthcare,
    RouteNames.salon,
    RouteNames.restaurant,
    RouteNames.accommodation,
    // SaaS / white-label
    RouteNames.whiteLabel,
    // Experimental / "big-company" extras
    RouteNames.platformOperations,
    RouteNames.dynamicWidgets, // also /dynamic-widgets/layout|runtime
    RouteNames.dynamicDashboard,
    RouteNames.resourceOptimization,
    RouteNames.schoolMemories,
    // Evolution suite (experimental, not wired into real persona flows)
    RouteNames.setupWizard, // demo wizard; real onboarding is separate
    RouteNames.teacherAssistant,
    // Parent–Teacher Meetings (staff scheduling + parent PTM view): UI is built
    // but has NO backend, so it was mock-only and lost edits on restart
    // (CORE-1/PAR-4). Gated OFF until the PTM backend ships — remove these two
    // entries to bring it back. (Wave 1, 2026-06-25)
    RouteNames.parentMeetings,
    RouteNames.parentPtm,
    // parentInsights: surfaced for parents (B3, 2026-06-25) — live AI insights
    // wired into the parent flow; entitlement-gated via feature.parent_insights.
    // growthPlatform: surfaced as the Marketing engine (B6, 2026-06-25) — lead
    // capture + campaigns + source attribution, entitlement-gated via
    // module.marketing; reachable from the Marketing nav tile.
    RouteNames.principalCommand,
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
