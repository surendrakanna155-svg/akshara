import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/environment_provider.dart';
import '../core/repositories/repository_config.dart';

/// P0-CODE-2 (ENG-3 / MOD-4): hide backend-less surfaces in a LIVE build.
///
/// These shipped surfaces have no live backend and, in the live release, no
/// enabled API flag — so their mock repositories would fabricate reads a real
/// user can reach. Per the owner decision (2026-07-04, "hide all for pilot"),
/// a surface whose API flag is OFF while `enableApiMode` is ON is **hidden**:
/// its route is blocked (via [ErpRouteGuard]) and its nav entries are dropped
/// (via the sub-nav filters) rather than served as mock. In a local/mock build
/// (`enableApiMode` off) the mock is the intended dev behaviour, so the surfaces
/// stay visible — this only fires for a real (API-mode) build.
///
/// The per-surface `*ApiEnabledProvider` already returns false when
/// `enableApiMode` is off, so the explicit `enableApiMode` gate below is what
/// keeps the surfaces visible in local/dev builds.
typedef _SurfaceGate = ({List<String> prefixes, Provider<bool> flag});

final List<_SurfaceGate> _backendLessSurfaces = <_SurfaceGate>[
  (prefixes: const ['/management/workflow-automation'], flag: workflowApiEnabledProvider),
  (
    prefixes: const ['/sis/promotion', '/sis/reshuffle', '/sis/section-balance'],
    flag: academicOperationsApiEnabledProvider,
  ),
  (prefixes: const ['/sis/continuity'], flag: continuityApiEnabledProvider),
  // Both platform-intelligence surfaces share the flag: the Control-Center
  // dashboard AND the Trust Intelligence Hub (`/organization/intelligence`,
  // TrustIntelligenceHubScreen). The trust hub was reachable by deep-link for
  // everyday roles (schoolAdmin/principal via viewOrganizationIntelligence) and
  // rendered MockPlatformIntelligenceRepository's fabricated cross-school trust
  // dashboard as if real — CFC-1 item-2 fix (2026-07-13). No backend exists, so
  // the flag stays OFF in live_release.json; the surface is hidden instead.
  (
    prefixes: const ['/control-center/intelligence', '/organization/intelligence'],
    flag: platformIntelligenceApiEnabledProvider,
  ),
  (prefixes: const ['/platform-operations'], flag: platformOperationsApiEnabledProvider),
  (prefixes: const ['/multi-school'], flag: multiSchoolOperationsApiEnabledProvider),
  (prefixes: const ['/healthcare'], flag: healthcareApiEnabledProvider),
  (prefixes: const ['/salon'], flag: salonApiEnabledProvider),
  (prefixes: const ['/restaurant'], flag: restaurantApiEnabledProvider),
  (prefixes: const ['/accommodation'], flag: accommodationApiEnabledProvider),
  (
    prefixes: const ['/white-label', '/control-center/white-label'],
    flag: whiteLabelPlatformApiEnabledProvider,
  ),
  // RT round-3 RT-5-3: Branch & Franchise operations have no live backend
  // (mock-only repositories) yet were reachable by a chain-org schoolAdmin,
  // rendering a fabricated multi-branch revenue dashboard as real. Same class
  // as the CFC-1 item-2 Trust-Hub fix; the flags stay OFF (no backend), so the
  // routes are hidden and the nav entries dropped in a live build. Four sibling
  // modules from the same 2026-07-04 audit were already gated; these two had
  // been dropped from that wave.
  (prefixes: const ['/branches'], flag: branchOperationsApiEnabledProvider),
  (prefixes: const ['/franchise'], flag: franchiseOperationsApiEnabledProvider),
];

/// True when [location] belongs to a backend-less surface that must be hidden in
/// the current (live) build. Reused by the route guard and the nav filters so
/// both agree exactly.
bool isBackendLessSurfaceHidden(WidgetRef ref, String location) {
  if (!ref.watch(enableApiModeProvider)) return false;
  for (final surface in _backendLessSurfaces) {
    for (final prefix in surface.prefixes) {
      if (location == prefix || location.startsWith('$prefix/')) {
        return !ref.watch(surface.flag);
      }
    }
  }
  return false;
}
