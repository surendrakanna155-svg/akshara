import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'academic_operations_models.dart';

final promotionSourceYearProvider = StateProvider<String>((ref) => '2026–27');
final promotionTargetYearProvider = StateProvider<String>((ref) => '2027–28');
final promotionJobIdProvider = StateProvider<String?>((ref) => null);
final reshuffleClassProvider = StateProvider<String>((ref) => '7');
final reshuffleYearProvider = StateProvider<String>((ref) => '2026–27');
final reshuffleStrategyProvider = StateProvider<String>((ref) => 'alphabetical');
final sectionBalanceTargetSizeProvider = StateProvider<int?>((ref) => null);
final quarterlyQuarterProvider = StateProvider<int>((ref) => 1);

final suggestedMappingsFutureProvider = FutureProvider<List<ClassMappingRule>>((
  ref,
) async {
  return ref.read(academicOperationsRepositoryProvider).suggestClassMappings(
        query: ref.watch(repositoryQueryProvider),
        sourceYearId: ref.watch(promotionSourceYearProvider),
        targetYearId: ref.watch(promotionTargetYearProvider),
      );
});

final promotionPreviewFutureProvider = FutureProvider<AcademicTransitionJob?>((
  ref,
) async {
  final jobId = ref.watch(promotionJobIdProvider);
  if (jobId == null) return null;
  return ref.read(academicOperationsRepositoryProvider).getTransitionJob(
        query: ref.watch(repositoryQueryProvider),
        jobId: jobId,
      );
});

final reshufflePreviewFutureProvider = FutureProvider<ReshufflePlan>((ref) async {
  return ref.read(academicOperationsRepositoryProvider).previewStudentReshuffle(
        query: ref.watch(repositoryQueryProvider),
        classLabel: ref.watch(reshuffleClassProvider),
        academicYear: ref.watch(reshuffleYearProvider),
        strategy: ref.watch(reshuffleStrategyProvider),
      );
});

final sectionBalancePreviewFutureProvider = FutureProvider<SectionBalancePlan>((
  ref,
) async {
  return ref.read(academicOperationsRepositoryProvider).previewSectionBalance(
        query: ref.watch(repositoryQueryProvider),
        classLabel: ref.watch(reshuffleClassProvider),
        academicYear: ref.watch(reshuffleYearProvider),
        targetSize: ref.watch(sectionBalanceTargetSizeProvider),
      );
});

final quarterlyReshufflePreviewFutureProvider =
    FutureProvider<QuarterlyReshufflePlan>((ref) async {
  return ref
      .read(academicOperationsRepositoryProvider)
      .previewQuarterlyReshuffle(
        query: ref.watch(repositoryQueryProvider),
        classLabel: ref.watch(reshuffleClassProvider),
        academicYear: ref.watch(reshuffleYearProvider),
        quarter: ref.watch(quarterlyQuarterProvider),
      );
});

final performanceBalancePreviewFutureProvider =
    FutureProvider<PerformanceBalancePlan>((ref) async {
  return ref.read(academicOperationsRepositoryProvider).previewPerformanceBalance(
        query: ref.watch(repositoryQueryProvider),
        classLabel: ref.watch(reshuffleClassProvider),
        academicYear: ref.watch(reshuffleYearProvider),
      );
});
