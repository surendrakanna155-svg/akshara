import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../platform_backend_guard.dart';
import 'white_label_models.dart';
import 'white_label_providers.dart';

void assertManageWhiteLabelPlatform(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  if (permissions == null ||
      !permissions.has(Permission.manageWhiteLabelPlatform)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage white label platform.',
        code: 'RBAC_MANAGE_WHITE_LABEL_PLATFORM',
      ),
    );
  }
}

void _invalidateWhiteLabelReads(Ref ref) {
  ref.invalidate(whiteLabelDashboardProvider);
  ref.invalidate(brandingProfilesProvider);
  ref.invalidate(themeConfigsProvider);
  ref.invalidate(logoAssetsProvider);
  ref.invalidate(deploymentProfilesProvider);
}

class SaveBrandingProfileNotifier extends AsyncNotifier<BrandingProfile?> {
  @override
  FutureOr<BrandingProfile?> build() => null;

  Future<BrandingProfile?> execute({required BrandingProfile profile}) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageWhiteLabelPlatform(ref);
      assertWhiteLabelBackendAvailable(ref);
      try {
        final result = await ref
            .read(whiteLabelPlatformRepositoryProvider)
            .saveBrandingProfile(
              query: ref.read(repositoryQueryProvider),
              profile: profile,
            );
        _invalidateWhiteLabelReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final saveBrandingProfileProvider =
    AsyncNotifierProvider<SaveBrandingProfileNotifier, BrandingProfile?>(
  SaveBrandingProfileNotifier.new,
);

class ApplyThemeNotifier extends AsyncNotifier<ThemeConfig?> {
  @override
  FutureOr<ThemeConfig?> build() => null;

  Future<ThemeConfig?> execute({required String themeId}) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageWhiteLabelPlatform(ref);
      assertWhiteLabelBackendAvailable(ref);
      try {
        final result = await ref
            .read(whiteLabelPlatformRepositoryProvider)
            .applyTheme(
              query: ref.read(repositoryQueryProvider),
              themeId: themeId,
            );
        _invalidateWhiteLabelReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final applyThemeProvider =
    AsyncNotifierProvider<ApplyThemeNotifier, ThemeConfig?>(
  ApplyThemeNotifier.new,
);

class UploadLogoNotifier extends AsyncNotifier<LogoAsset?> {
  @override
  FutureOr<LogoAsset?> build() => null;

  Future<LogoAsset?> execute({
    required String label,
    required String variant,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageWhiteLabelPlatform(ref);
      assertWhiteLabelBackendAvailable(ref);
      try {
        final result = await ref
            .read(whiteLabelPlatformRepositoryProvider)
            .uploadLogo(
              query: ref.read(repositoryQueryProvider),
              label: label,
              variant: variant,
            );
        _invalidateWhiteLabelReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final uploadLogoProvider =
    AsyncNotifierProvider<UploadLogoNotifier, LogoAsset?>(
  UploadLogoNotifier.new,
);
