import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'platform_intelligence_models.dart';

final platformIntelligenceCanViewProvider = Provider<bool>((ref) {
  return ref
      .watch(rbacServiceProvider)
      .hasPermission(Permission.viewControlCenter);
});

final platformIntelligenceDashboardProvider =
    FutureProvider<PlatformIntelligenceDashboard>((ref) async {
  return ref
      .read(platformIntelligenceRepositoryProvider)
      .getPlatformIntelligenceDashboard(
        query: ref.watch(repositoryQueryProvider),
      );
});

final platformOrganizationIdProvider =
    StateProvider<String>((ref) => 'ORG-001');

final organizationIntelligenceProvider =
    FutureProvider<OrganizationIntelligence>((ref) async {
  return ref
      .read(platformIntelligenceRepositoryProvider)
      .getOrganizationIntelligence(
        query: ref.watch(repositoryQueryProvider),
        orgId: ref.watch(platformOrganizationIdProvider),
      );
});

final schoolComparisonSelectionProvider = StateProvider<List<String>>(
  (ref) => const ['SCH-1001', 'SCH-1003', 'SCH-1004', 'SCH-1005'],
);

final schoolComparisonIntelligenceProvider =
    FutureProvider<SchoolComparisonIntelligence>((ref) async {
  return ref.read(platformIntelligenceRepositoryProvider).compareSchools(
        query: ref.watch(repositoryQueryProvider),
        schoolIds: ref.watch(schoolComparisonSelectionProvider),
      );
});

final revenueIntelligenceProvider =
    FutureProvider<RevenueIntelligence>((ref) async {
  return ref
      .read(platformIntelligenceRepositoryProvider)
      .getRevenueIntelligence(
        query: ref.watch(repositoryQueryProvider),
      );
});

final growthIntelligenceProvider =
    FutureProvider<GrowthIntelligence>((ref) async {
  return ref.read(platformIntelligenceRepositoryProvider).getGrowthIntelligence(
        query: ref.watch(repositoryQueryProvider),
      );
});

final portfolioRiskIntelligenceProvider =
    FutureProvider<PortfolioRiskIntelligence>((ref) async {
  return ref
      .read(platformIntelligenceRepositoryProvider)
      .getPortfolioRiskIntelligence(
        query: ref.watch(repositoryQueryProvider),
      );
});
