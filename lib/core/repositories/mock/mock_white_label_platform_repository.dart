import '../../../features/platform/white_label/white_label_models.dart';
import '../interfaces/white_label_platform_repository.dart';
import '../repository_query.dart';

class MockWhiteLabelPlatformRepository implements WhiteLabelPlatformRepository {
  final List<BrandingProfile> _profiles = [
    const BrandingProfile(
      id: 'wl_profile_1',
      name: 'NIKSHA Default',
      primaryColor: '#1E88E5',
      accentColor: '#FFC107',
      isDefault: true,
      tagline: 'Education ERP',
    ),
    const BrandingProfile(
      id: 'wl_profile_2',
      name: 'Velora Salon',
      primaryColor: '#9C27B0',
      accentColor: '#E91E63',
      isDefault: false,
      tagline: 'Beauty & Wellness',
    ),
  ];

  final List<ThemeConfig> _themes = [
    const ThemeConfig(
      id: 'wl_theme_1',
      name: 'Light Professional',
      mode: 'light',
      primaryColor: '#1E88E5',
      surfaceColor: '#FFFFFF',
      isActive: true,
    ),
    const ThemeConfig(
      id: 'wl_theme_2',
      name: 'Dark Executive',
      mode: 'dark',
      primaryColor: '#90CAF9',
      surfaceColor: '#121212',
      isActive: false,
    ),
  ];

  final List<LogoAsset> _logos = [
    LogoAsset(
      id: 'wl_logo_1',
      label: 'Primary Logo',
      url: 'https://cdn.akshara.io/logo-primary.svg',
      variant: 'primary',
      uploadedAt: DateTime(2026, 6, 1),
    ),
  ];

  final List<DeploymentProfile> _deployments = [
    const DeploymentProfile(
      id: 'wl_deploy_1',
      name: 'Production',
      environment: 'production',
      domain: 'app.akshara.io',
      status: 'active',
      region: 'ap-south-1',
    ),
  ];

  WhiteLabelConfiguration _active = WhiteLabelConfiguration(
    brandingProfileId: 'wl_profile_1',
    themeConfigId: 'wl_theme_1',
    logoAssetId: 'wl_logo_1',
    deploymentProfileId: 'wl_deploy_1',
    updatedAt: DateTime(2026, 6, 15),
  );

  @override
  Future<WhiteLabelDashboard> getDashboard({
    required RepositoryQuery query,
  }) async {
    return WhiteLabelDashboard(
      profiles: List<BrandingProfile>.from(_profiles),
      themes: List<ThemeConfig>.from(_themes),
      logos: List<LogoAsset>.from(_logos),
      deployments: List<DeploymentProfile>.from(_deployments),
      activeConfiguration: _active,
    );
  }

  @override
  Future<List<BrandingProfile>> listBrandingProfiles({
    required RepositoryQuery query,
  }) async =>
      List<BrandingProfile>.from(_profiles);

  @override
  Future<List<ThemeConfig>> listThemeConfigs({
    required RepositoryQuery query,
  }) async =>
      List<ThemeConfig>.from(_themes);

  @override
  Future<List<LogoAsset>> listLogoAssets({
    required RepositoryQuery query,
  }) async =>
      List<LogoAsset>.from(_logos);

  @override
  Future<List<DeploymentProfile>> listDeploymentProfiles({
    required RepositoryQuery query,
  }) async =>
      List<DeploymentProfile>.from(_deployments);

  @override
  Future<BrandingProfile> saveBrandingProfile({
    required RepositoryQuery query,
    required BrandingProfile profile,
  }) async {
    final index = _profiles.indexWhere((p) => p.id == profile.id);
    if (index >= 0) {
      _profiles[index] = profile;
    } else {
      _profiles.add(profile);
    }
    _active = WhiteLabelConfiguration(
      brandingProfileId: profile.id,
      themeConfigId: _active.themeConfigId,
      logoAssetId: _active.logoAssetId,
      deploymentProfileId: _active.deploymentProfileId,
      updatedAt: DateTime.now(),
    );
    return profile;
  }

  @override
  Future<ThemeConfig> applyTheme({
    required RepositoryQuery query,
    required String themeId,
  }) async {
    for (var i = 0; i < _themes.length; i++) {
      final theme = _themes[i];
      _themes[i] = ThemeConfig(
        id: theme.id,
        name: theme.name,
        mode: theme.mode,
        primaryColor: theme.primaryColor,
        surfaceColor: theme.surfaceColor,
        isActive: theme.id == themeId,
      );
    }
    final active = _themes.firstWhere((t) => t.id == themeId);
    _active = WhiteLabelConfiguration(
      brandingProfileId: _active.brandingProfileId,
      themeConfigId: themeId,
      logoAssetId: _active.logoAssetId,
      deploymentProfileId: _active.deploymentProfileId,
      updatedAt: DateTime.now(),
    );
    return active;
  }

  @override
  Future<LogoAsset> uploadLogo({
    required RepositoryQuery query,
    required String label,
    required String variant,
  }) async {
    final asset = LogoAsset(
      id: 'wl_logo_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      url: 'https://cdn.akshara.io/mock-upload.svg',
      variant: variant,
      uploadedAt: DateTime.now(),
    );
    _logos.add(asset);
    _active = WhiteLabelConfiguration(
      brandingProfileId: _active.brandingProfileId,
      themeConfigId: _active.themeConfigId,
      logoAssetId: asset.id,
      deploymentProfileId: _active.deploymentProfileId,
      updatedAt: DateTime.now(),
    );
    return asset;
  }
}
