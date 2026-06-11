import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/repositories/repository_query.dart';
import '../parent/parent_active_child_provider.dart';
import '../phase4/phase4_providers.dart';
import 'phase5_models.dart';

final phase5QueryProvider = Provider<RepositoryQuery>(
  (ref) => ref.watch(phase4QueryProvider),
);

final parentExperienceHubProvider =
    FutureProvider.family<ParentExperienceHub, String>((ref, studentId) async {
  ref.watch(parentActiveStudentIdProvider);
  final resolved = studentId.isEmpty
      ? ref.watch(parentActiveStudentIdProvider)
      : studentId;
  return ref.read(parentExperienceRepositoryProvider).getHub(
        query: ref.watch(phase5QueryProvider),
        studentId: resolved,
      );
});

final employee360Provider =
    FutureProvider.family<Employee360Profile, String>((ref, employeeId) async {
  return ref.read(employeeIntelligenceRepositoryProvider).getEmployee360(
        query: ref.watch(phase5QueryProvider),
        employeeId: employeeId,
      );
});

final employeeIntelligenceDashboardProvider =
    FutureProvider<EmployeeIntelligenceDashboard>((ref) async {
  return ref.read(employeeIntelligenceRepositoryProvider).getIntelligenceDashboard(
        query: ref.watch(phase5QueryProvider),
      );
});

final operationsHubProvider = FutureProvider<OperationsHubSnapshot>((ref) async {
  return ref.read(operationsHubRepositoryProvider).getHub(
        query: ref.watch(phase5QueryProvider),
      );
});

final distributionReportsProvider = FutureProvider<InvDistributionReports>((ref) async {
  return ref.read(inventoryDistributionRepositoryProvider).getReports(
        query: ref.watch(phase5QueryProvider),
      );
});

final schoolMemoriesEventsProvider = FutureProvider<List<SchoolMemoryEvent>>((ref) async {
  return ref.read(schoolMemoriesRepositoryProvider).listEvents(
        query: ref.watch(phase5QueryProvider),
      );
});

final schoolMemoryEventProvider =
    FutureProvider.family<SchoolMemoryEvent, String>((ref, eventId) async {
  return ref.read(schoolMemoriesRepositoryProvider).getEvent(
        query: ref.watch(phase5QueryProvider),
        eventId: eventId,
      );
});

final achievementPromotionsProvider =
    FutureProvider<List<AchievementPromotion>>((ref) async {
  return ref.read(achievementPromotionRepositoryProvider).listPromotions(
        query: ref.watch(phase5QueryProvider),
      );
});
