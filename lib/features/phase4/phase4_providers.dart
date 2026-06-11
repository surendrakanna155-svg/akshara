import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/repositories/repository_query.dart';
import '../../core/tenant/tenant_provider.dart';

final phase4QueryProvider = Provider<RepositoryQuery>(
  (ref) => ref.watch(repositoryQueryProvider),
);

final homeworkIntelligencePlanProvider = FutureProvider.family<
    dynamic,
    ({String className, String subjectName, String examType})>((ref, input) async {
  return ref.read(homeworkIntelligenceRepositoryProvider).getPlan(
        query: ref.watch(phase4QueryProvider),
        className: input.className,
        subjectName: input.subjectName,
        examType: input.examType,
      );
});

final student360ProfileProvider = FutureProvider.family<dynamic, String>((ref, studentId) async {
  return ref.read(student360RepositoryProvider).getProfile(
        query: ref.watch(phase4QueryProvider),
        studentId: studentId,
      );
});

final student360TimelineProvider = FutureProvider.family<dynamic, String>((ref, studentId) async {
  return ref.read(student360RepositoryProvider).getTimeline(
        query: ref.watch(phase4QueryProvider),
        studentId: studentId,
      );
});

final employeeDashboardProvider = FutureProvider((ref) async {
  return ref.read(employeeRepositoryProvider).getDashboard(
        query: ref.watch(phase4QueryProvider),
      );
});

final employeesListProvider = FutureProvider((ref) async {
  return ref.read(employeeRepositoryProvider).listEmployees(
        query: ref.watch(phase4QueryProvider),
      );
});

final inventoryDistributionDashboardProvider = FutureProvider((ref) async {
  return ref.read(inventoryDistributionRepositoryProvider).getDashboard(
        query: ref.watch(phase4QueryProvider),
      );
});

final inventoryDistributionsListProvider = FutureProvider((ref) async {
  return ref.read(inventoryDistributionRepositoryProvider).listDistributions(
        query: ref.watch(phase4QueryProvider),
      );
});
