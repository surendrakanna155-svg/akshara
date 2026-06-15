import 'package:flutter/foundation.dart';

@immutable
class BrandingProfile {
  const BrandingProfile({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.accentColor,
    required this.isDefault,
    this.tagline,
  });

  final String id;
  final String name;
  final String primaryColor;
  final String accentColor;
  final bool isDefault;
  final String? tagline;
}

@immutable
class ThemeConfig {
  const ThemeConfig({
    required this.id,
    required this.name,
    required this.mode,
    required this.primaryColor,
    required this.surfaceColor,
    required this.isActive,
  });

  final String id;
  final String name;
  final String mode;
  final String primaryColor;
  final String surfaceColor;
  final bool isActive;
}

@immutable
class LogoAsset {
  const LogoAsset({
    required this.id,
    required this.label,
    required this.url,
    required this.variant,
    required this.uploadedAt,
  });

  final String id;
  final String label;
  final String url;
  final String variant;
  final DateTime uploadedAt;
}

@immutable
class DeploymentProfile {
  const DeploymentProfile({
    required this.id,
    required this.name,
    required this.environment,
    required this.domain,
    required this.status,
    this.region,
  });

  final String id;
  final String name;
  final String environment;
  final String domain;
  final String status;
  final String? region;
}

@immutable
class WhiteLabelConfiguration {
  const WhiteLabelConfiguration({
    required this.brandingProfileId,
    required this.themeConfigId,
    required this.logoAssetId,
    required this.deploymentProfileId,
    required this.updatedAt,
  });

  final String brandingProfileId;
  final String themeConfigId;
  final String logoAssetId;
  final String deploymentProfileId;
  final DateTime updatedAt;
}

@immutable
class WhiteLabelDashboard {
  const WhiteLabelDashboard({
    required this.profiles,
    required this.themes,
    required this.logos,
    required this.deployments,
    required this.activeConfiguration,
  });

  final List<BrandingProfile> profiles;
  final List<ThemeConfig> themes;
  final List<LogoAsset> logos;
  final List<DeploymentProfile> deployments;
  final WhiteLabelConfiguration activeConfiguration;
}
