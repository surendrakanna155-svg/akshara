import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'white_label_models.dart';

final whiteLabelCanViewProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(
        Permission.viewWhiteLabelPlatform,
      );
});

final whiteLabelDashboardProvider =
    FutureProvider<WhiteLabelDashboard>((ref) async {
  return ref.read(whiteLabelPlatformRepositoryProvider).getDashboard(
        query: ref.watch(repositoryQueryProvider),
      );
});

final brandingProfilesProvider =
    FutureProvider<List<BrandingProfile>>((ref) async {
  return ref.read(whiteLabelPlatformRepositoryProvider).listBrandingProfiles(
        query: ref.watch(repositoryQueryProvider),
      );
});

final themeConfigsProvider = FutureProvider<List<ThemeConfig>>((ref) async {
  return ref.read(whiteLabelPlatformRepositoryProvider).listThemeConfigs(
        query: ref.watch(repositoryQueryProvider),
      );
});

final logoAssetsProvider = FutureProvider<List<LogoAsset>>((ref) async {
  return ref.read(whiteLabelPlatformRepositoryProvider).listLogoAssets(
        query: ref.watch(repositoryQueryProvider),
      );
});

final deploymentProfilesProvider =
    FutureProvider<List<DeploymentProfile>>((ref) async {
  return ref.read(whiteLabelPlatformRepositoryProvider).listDeploymentProfiles(
        query: ref.watch(repositoryQueryProvider),
      );
});
