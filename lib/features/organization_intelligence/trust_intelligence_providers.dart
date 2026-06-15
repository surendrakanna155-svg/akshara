import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import '../control_center/intelligence/platform_intelligence_models.dart';
import '../control_center/intelligence/platform_intelligence_providers.dart';

final trustIntelligenceCanViewProvider = Provider<bool>((ref) {
  return ref
      .watch(rbacServiceProvider)
      .hasPermission(Permission.viewOrganizationIntelligence);
});

final trustOrganizationIdProvider = StateProvider<String>((ref) => 'TRUST-001');

final trustDashboardProvider = FutureProvider<TrustDashboardIntelligence>(
  (ref) async {
    return ref.read(platformIntelligenceRepositoryProvider).getTrustDashboard(
          query: ref.watch(repositoryQueryProvider),
          trustId: ref.watch(trustOrganizationIdProvider),
        );
  },
);

final trustRecommendationsProvider =
    FutureProvider<List<CrossSchoolRecommendation>>((ref) async {
  final selectedSchools = ref.watch(schoolComparisonSelectionProvider);
  return ref
      .read(platformIntelligenceRepositoryProvider)
      .getCrossSchoolRecommendations(
        query: ref.watch(repositoryQueryProvider),
        schoolIds: selectedSchools,
      );
});

final trustExecutiveSummaryProvider =
    FutureProvider<ExecutiveSummaryIntelligence>(
  (ref) async {
    return ref.read(platformIntelligenceRepositoryProvider).getExecutiveSummary(
          query: ref.watch(repositoryQueryProvider),
          trustId: ref.watch(trustOrganizationIdProvider),
        );
  },
);
