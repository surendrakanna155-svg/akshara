import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'director_models.dart';

final directorCanViewProvider = Provider<bool>((ref) {
  return ref
      .watch(rbacServiceProvider)
      .hasPermission(Permission.viewDirectorPortal);
});

final directorCanManageProvider = Provider<bool>((ref) {
  return ref
      .watch(rbacServiceProvider)
      .hasPermission(Permission.manageDirectorPortal);
});

final directorExecutiveDashboardProvider =
    FutureProvider<DirectorDashboardData>((ref) async {
  return ref.read(directorRepositoryProvider).getExecutiveDashboard(
        query: ref.watch(repositoryQueryProvider),
      );
});

final directorSchoolsProvider = FutureProvider<List<DirectorSchoolRow>>((
  ref,
) async {
  return ref.read(directorRepositoryProvider).getMultiSchoolOverview(
        query: ref.watch(repositoryQueryProvider),
      );
});

final directorPortfolioProvider =
    FutureProvider<DirectorGrowthSnapshot>((ref) async {
  return ref.read(directorRepositoryProvider).getPortfolioAnalytics(
        query: ref.watch(repositoryQueryProvider),
      );
});

final directorRevenueProvider =
    FutureProvider<DirectorRevenueSnapshot>((ref) async {
  return ref.read(directorRepositoryProvider).getRevenueOverview(
        query: ref.watch(repositoryQueryProvider),
      );
});

final directorGrowthProvider =
    FutureProvider<DirectorGrowthSnapshot>((ref) async {
  return ref.read(directorRepositoryProvider).getGrowthAnalytics(
        query: ref.watch(repositoryQueryProvider),
      );
});

final directorMarketingProvider =
    FutureProvider<DirectorMarketingSnapshot>((ref) async {
  return ref.read(directorRepositoryProvider).getMarketingPerformance(
        query: ref.watch(repositoryQueryProvider),
      );
});

final directorAdmissionsProvider =
    FutureProvider<DirectorAdmissionsSnapshot>((ref) async {
  return ref.read(directorRepositoryProvider).getAdmissionsPerformance(
        query: ref.watch(repositoryQueryProvider),
      );
});

final directorComplianceProvider =
    FutureProvider<List<DirectorComplianceItem>>((ref) async {
  return ref.read(directorRepositoryProvider).getComplianceMonitoring(
        query: ref.watch(repositoryQueryProvider),
      );
});

final directorReportsProvider =
    FutureProvider<List<DirectorReportItem>>((ref) async {
  return ref.read(directorRepositoryProvider).getStrategicReports(
        query: ref.watch(repositoryQueryProvider),
      );
});
