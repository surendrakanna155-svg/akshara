import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/admin/models/admin_nav_models.dart';
import '../../features/auth/auth_provider.dart';
import '../../router/route_names.dart';

/// Chain (multi-school tenant) gating for the org/tenant-tier modules.
///
/// Owner decision (M3, 2026-06-22): franchise, multi-school and
/// organization-builder surfaces are only meaningful when the signed-in org is
/// actually part of a CHAIN (a multi-school tenant). A single independent
/// school never sees them; a real chain does.
///
/// This is the runtime counterpart to [SchoolBuildScope]: where SchoolBuildScope
/// is a compile-time switch for the school-only build, ChainScope gates by the
/// LIVE chain status of the active org (see [isChainOrgProvider]). It is purely
/// additive — pure RBAC permissions still apply on top, and the gate only ever
/// HIDES, never grants.
///
/// IMPORTANT — nothing is deleted. When the active org is a chain, every gated
/// route/module becomes reachable again (subject to the user's permissions).
abstract final class ChainScope {
  /// Route prefixes that require the active org to be a chain. Each prefix
  /// covers its nested sub-routes (e.g. `/organization-builder/interview`).
  static const Set<String> chainOnlyRoutePrefixes = {
    RouteNames.franchise,
    RouteNames.multiSchoolPortfolio,
    RouteNames.multiSchoolOnboarding,
    RouteNames.organizationBuilder, // also interview/preview/provisioning
    RouteNames.schoolDiscovery, // org-builder school discovery
  };

  /// Admin-hub modules that require a chain org to appear in navigation.
  static const Set<AdminModule> chainOnlyModules = {
    AdminModule.organizationBuilder,
  };

  /// Whether [location] is gated behind chain status.
  static bool isChainOnlyRoute(String location) {
    for (final prefix in chainOnlyRoutePrefixes) {
      if (location == prefix || location.startsWith('$prefix/')) {
        return true;
      }
    }
    return false;
  }

  /// Whether [module] is gated behind chain status in the admin navigation.
  static bool isChainOnlyModule(AdminModule module) =>
      chainOnlyModules.contains(module);
}

/// Whether the active org is a chain (multi-school tenant).
///
/// Single independent schools are NOT chains and never see chain-only modules
/// (M3, 2026-06-22). Defaults to `false` when unauthenticated or when the
/// backend does not flag the org as a chain.
final isChainOrgProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).claims?.isChainOrganization ?? false;
});
