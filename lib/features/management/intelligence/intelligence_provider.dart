import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/repositories/repository_query.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'intelligence_models.dart';

final intelligenceQueryProvider = Provider<RepositoryQuery>(
  (ref) => ref.watch(repositoryQueryProvider),
);

final intelligenceDashboardProvider = FutureProvider<IntelligenceDashboardMetrics>((ref) async {
  return ref.read(analyticsIntelligenceRepositoryProvider).getDashboardMetrics(
        query: ref.watch(intelligenceQueryProvider),
      );
});

final intelligenceTrendsProvider = FutureProvider<IntelligenceTrendBundle>((ref) async {
  return ref.read(analyticsIntelligenceRepositoryProvider).getTrends(
        query: ref.watch(intelligenceQueryProvider),
      );
});

final intelligenceRisksProvider = FutureProvider<IntelligenceRiskBundle>((ref) async {
  return ref.read(analyticsIntelligenceRepositoryProvider).getRisks(
        query: ref.watch(intelligenceQueryProvider),
      );
});

final intelligenceHealthProvider = FutureProvider<IntelligenceSchoolHealthSummary>((ref) async {
  return ref.read(analyticsIntelligenceRepositoryProvider).getSchoolHealth(
        query: ref.watch(intelligenceQueryProvider),
      );
});

final intelligenceRecommendationsProvider = FutureProvider<List<IntelligenceRecommendation>>((ref) async {
  return ref.read(analyticsIntelligenceRepositoryProvider).getRecommendations(
        query: ref.watch(intelligenceQueryProvider),
      );
});

final intelligencePrincipalSummaryProvider = FutureProvider<IntelligencePrincipalSummary>((ref) async {
  return ref.read(analyticsIntelligenceRepositoryProvider).getPrincipalSummary(
        query: ref.watch(intelligenceQueryProvider),
      );
});

final intelligenceWeeklyBriefingProvider = FutureProvider<IntelligenceWeeklyBriefing>((ref) async {
  return ref.read(analyticsIntelligenceRepositoryProvider).getWeeklyBriefing(
        query: ref.watch(intelligenceQueryProvider),
      );
});

final intelligenceCanViewProvider = Provider<bool>(
  (ref) => ref.watch(rbacServiceProvider).hasPermission(Permission.viewAnalytics),
);

final intelligenceCanViewHealthProvider = Provider<bool>(
  (ref) => ref.watch(rbacServiceProvider).hasPermission(Permission.viewSchoolHealth),
);

void invalidateIntelligenceReads(WidgetRef ref) {
  ref.invalidate(intelligenceDashboardProvider);
  ref.invalidate(intelligenceTrendsProvider);
  ref.invalidate(intelligenceRisksProvider);
  ref.invalidate(intelligenceHealthProvider);
  ref.invalidate(intelligenceRecommendationsProvider);
  ref.invalidate(intelligencePrincipalSummaryProvider);
  ref.invalidate(intelligenceWeeklyBriefingProvider);
}
