import '../../../../features/platform/white_label/white_label_models.dart';
import '../../interfaces/white_label_platform_repository.dart';
import '../../repository_query.dart';
import 'remote/white_label_remote_datasource.dart';

class ApiWhiteLabelPlatformRepository implements WhiteLabelPlatformRepository {
  ApiWhiteLabelPlatformRepository({required WhiteLabelRemoteDataSource remote})
      : _remote = remote;

  final WhiteLabelRemoteDataSource _remote;

  @override
  Future<WhiteLabelDashboard> getDashboard({
    required RepositoryQuery query,
  }) async {
    await _remote.fetchDashboard(query: query);
    return WhiteLabelDashboard(
      profiles: const [],
      themes: const [],
      logos: const [],
      deployments: const [],
      activeConfiguration: WhiteLabelConfiguration(
        brandingProfileId: '',
        themeConfigId: '',
        logoAssetId: '',
        deploymentProfileId: '',
        updatedAt: DateTime(2026, 6, 15),
      ),
    );
  }

  @override
  Future<List<BrandingProfile>> listBrandingProfiles({
    required RepositoryQuery query,
  }) async =>
      const [];

  @override
  Future<List<ThemeConfig>> listThemeConfigs({
    required RepositoryQuery query,
  }) async =>
      const [];

  @override
  Future<List<LogoAsset>> listLogoAssets({
    required RepositoryQuery query,
  }) async =>
      const [];

  @override
  Future<List<DeploymentProfile>> listDeploymentProfiles({
    required RepositoryQuery query,
  }) async =>
      const [];

  @override
  Future<BrandingProfile> saveBrandingProfile({
    required RepositoryQuery query,
    required BrandingProfile profile,
  }) async =>
      profile;

  @override
  Future<ThemeConfig> applyTheme({
    required RepositoryQuery query,
    required String themeId,
  }) async =>
      ThemeConfig(
        id: themeId,
        name: '',
        mode: 'light',
        primaryColor: '#000000',
        surfaceColor: '#FFFFFF',
        isActive: true,
      );

  @override
  Future<LogoAsset> uploadLogo({
    required RepositoryQuery query,
    required String label,
    required String variant,
  }) async =>
      LogoAsset(
        id: '',
        label: label,
        url: '',
        variant: variant,
        uploadedAt: DateTime.now(),
      );
}
