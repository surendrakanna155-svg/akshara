import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/environment_provider.dart';
import '../core/repositories/repository_config.dart';

/// P0-CODE-2 (ENG-3 / MOD-4): hide backend-less surfaces in a LIVE build.
///
/// Eight shipped surfaces have no live backend and, in the live release, no
/// enabled API flag — so their mock repositories would fabricate reads a real
/// user can reach. Per the owner decision (2026-07-04, "hide all 8 for pilot"),
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
  (prefixes: const ['/control-center/intelligence'], flag: platformIntelligenceApiEnabledProvider),
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
  // PRA-N-7 / N-8 (S0/T2-D): backend-less mock surfaces — hidden in live builds.
  (prefixes: const ['/branches'], flag: branchApiEnabledProvider),
  (prefixes: const ['/franchise'], flag: franchiseApiEnabledProvider),
  (prefixes: const ['/resource-optimization'], flag: resourceOptimizationApiEnabledProvider),
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
