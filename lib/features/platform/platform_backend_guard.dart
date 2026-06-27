import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/environment_provider.dart';
import '../../core/errors/api_failure.dart';
import '../../core/repositories/repository_config.dart';

/// Guards super-admin platform write actions that resolve to in-memory `Mock*`
/// repositories when no live backend route exists.
///
/// These platform modules (branch / franchise / multi-school operations /
/// platform operations / white-label) have no server seeds and, in the live
/// release, no enabled API flag — so their mock repositories would otherwise
/// fabricate a success snackbar while persisting nothing.
///
/// In a live build (`enableApiMode` on) without a live backend for the module,
/// this throws an explicit [ApiFailureType.notConnected] so the UI surfaces an
/// honest "not available yet" state instead of a fake success. In a local
/// (non-API) build the mock fallback is the intended behaviour, so the write is
/// allowed through.
void assertPlatformBackendAvailable(
  Ref ref, {
  required bool backendAvailable,
  required String feature,
  required String code,
}) {
  // Local / offline builds legitimately run against mocks; only block the
  // fabricated-success path in a live build.
  if (!ref.read(enableApiModeProvider)) return;
  if (backendAvailable) return;
  throw ApiFailureException(
    ApiFailure(
      type: ApiFailureType.notConnected,
      message:
          '$feature is not available yet. This feature has no live backend, '
          'so changes cannot be saved.',
      code: code,
    ),
  );
}

/// Branch operations are always mock-backed (no API flag / route exists).
void assertBranchBackendAvailable(Ref ref) => assertPlatformBackendAvailable(
      ref,
      backendAvailable: false,
      feature: 'Branch operations',
      code: 'PLATFORM_BACKEND_UNAVAILABLE_BRANCH',
    );

/// Franchise operations are always mock-backed (no API flag / route exists).
void assertFranchiseBackendAvailable(Ref ref) => assertPlatformBackendAvailable(
      ref,
      backendAvailable: false,
      feature: 'Franchise operations',
      code: 'PLATFORM_BACKEND_UNAVAILABLE_FRANCHISE',
    );

void assertMultiSchoolBackendAvailable(Ref ref) =>
    assertPlatformBackendAvailable(
      ref,
      backendAvailable:
          isModuleApiEnabled(ref, multiSchoolOperationsApiEnabledProvider),
      feature: 'Multi-school operations',
      code: 'PLATFORM_BACKEND_UNAVAILABLE_MULTI_SCHOOL',
    );

void assertPlatformOperationsBackendAvailable(Ref ref) =>
    assertPlatformBackendAvailable(
      ref,
      backendAvailable:
          isModuleApiEnabled(ref, platformOperationsApiEnabledProvider),
      feature: 'Platform operations',
      code: 'PLATFORM_BACKEND_UNAVAILABLE_PLATFORM_OPS',
    );

void assertWhiteLabelBackendAvailable(Ref ref) =>
    assertPlatformBackendAvailable(
      ref,
      backendAvailable:
          isModuleApiEnabled(ref, whiteLabelPlatformApiEnabledProvider),
      feature: 'White-label platform',
      code: 'PLATFORM_BACKEND_UNAVAILABLE_WHITE_LABEL',
    );
