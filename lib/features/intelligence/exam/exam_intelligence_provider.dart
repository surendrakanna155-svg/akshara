import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../intelligence_provider.dart';
import 'exam_intelligence_models.dart';

final examIntelligenceCanViewProvider = Provider<bool>((ref) {
  final rbac = ref.watch(rbacServiceProvider);
  return rbac.hasPermission(Permission.viewExamIntelligence) ||
      rbac.hasPermission(Permission.viewEducation) ||
      rbac.hasPermission(Permission.viewAnalytics);
});

typedef ExamIntelFilters = ({String? className, String? subjectName});

final examAnalyticsProvider = FutureProvider.family<ExamAnalytics, ExamIntelFilters>(
  (ref, filters) async {
    return ref.read(intelligenceRepositoryProvider).getExamAnalytics(
          query: ref.watch(intelligenceQueryProvider),
          className: filters.className,
          subjectName: filters.subjectName,
        );
  },
);

final subjectPerformanceProvider =
    FutureProvider.family<List<SubjectPerformanceItem>, ExamIntelFilters>(
  (ref, filters) async {
    return ref.read(intelligenceRepositoryProvider).getSubjectPerformance(
          query: ref.watch(intelligenceQueryProvider),
          className: filters.className,
          subjectName: filters.subjectName,
        );
  },
);

final weakChaptersProvider = FutureProvider.family<List<WeakChapterItem>, ExamIntelFilters>(
  (ref, filters) async {
    return ref.read(intelligenceRepositoryProvider).getWeakChapters(
          query: ref.watch(intelligenceQueryProvider),
          className: filters.className,
          subjectName: filters.subjectName,
        );
  },
);

final resultIntelligenceProvider =
    FutureProvider.family<ResultIntelligence, String?>((ref, className) async {
  return ref.read(intelligenceRepositoryProvider).getResultIntelligence(
        query: ref.watch(intelligenceQueryProvider),
        className: className,
      );
});

final academicForecastProvider =
    FutureProvider.family<AcademicForecast, ExamIntelFilters>((ref, filters) async {
  return ref.read(intelligenceRepositoryProvider).getAcademicForecast(
        query: ref.watch(intelligenceQueryProvider),
        className: filters.className,
        subjectName: filters.subjectName,
      );
});

final rankMovementProvider = FutureProvider.family<List<RankMovementItem>, String?>(
  (ref, className) async {
    return ref.read(intelligenceRepositoryProvider).getRankMovement(
          query: ref.watch(intelligenceQueryProvider),
          className: className,
        );
  },
);
