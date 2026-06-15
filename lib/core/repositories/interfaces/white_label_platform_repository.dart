import '../../../features/white_label/white_label_models.dart';
import '../repository_query.dart';

abstract class WhiteLabelPlatformRepository {
  Future<WhiteLabelDashboard> getDashboard({
    required RepositoryQuery query,
  });

  Future<List<BrandingProfile>> listBrandingProfiles({
    required RepositoryQuery query,
  });

  Future<List<ThemeConfig>> listThemeConfigs({
    required RepositoryQuery query,
  });

  Future<List<LogoAsset>> listLogoAssets({
    required RepositoryQuery query,
  });

  Future<List<DeploymentProfile>> listDeploymentProfiles({
    required RepositoryQuery query,
  });

  Future<BrandingProfile> saveBrandingProfile({
    required RepositoryQuery query,
    required BrandingProfile profile,
  });

  Future<ThemeConfig> applyTheme({
    required RepositoryQuery query,
    required String themeId,
  });

  Future<LogoAsset> uploadLogo({
    required RepositoryQuery query,
    required String label,
    required String variant,
  });
}
