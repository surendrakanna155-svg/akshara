import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/repositories/repository_query.dart';
import '../../core/tenant/tenant_provider.dart';
import 'school_completion_models.dart';

final schoolCompletionQueryProvider = Provider<RepositoryQuery>(
  (ref) => ref.watch(repositoryQueryProvider),
);

final subjectsProvider = FutureProvider<List<AcademicSubject>>((ref) async {
  return ref.read(schoolCompletionRepositoryProvider).listSubjects(
        query: ref.watch(schoolCompletionQueryProvider),
      );
});

final lessonLogsProvider = FutureProvider.family<List<LessonLogEntry>, String?>(
  (ref, className) async {
    return ref.read(schoolCompletionRepositoryProvider).listLessonLogs(
          query: ref.watch(schoolCompletionQueryProvider),
          className: className,
        );
  },
);

final schoolBrandingProvider = FutureProvider<SchoolBranding>((ref) async {
  return ref.read(schoolCompletionRepositoryProvider).getBranding(
        query: ref.watch(schoolCompletionQueryProvider),
      );
});

final whatsAppProviderConfigProvider =
    FutureProvider<WhatsAppProviderConfig>((ref) async {
  return ref.read(schoolCompletionRepositoryProvider).getWhatsAppProvider(
        query: ref.watch(schoolCompletionQueryProvider),
      );
});

final subjectsCatalogProvider = subjectsProvider;

final classSubjectAssignmentsProvider =
    FutureProvider<List<ClassSubjectAssignment>>((ref) async {
  return ref
      .read(schoolCompletionRepositoryProvider)
      .listClassSubjectAssignments(
        query: ref.watch(schoolCompletionQueryProvider),
      );
});

final teacherSubjectAssignmentsProvider =
    FutureProvider<List<TeacherSubjectAssignment>>((ref) async {
  return ref
      .read(schoolCompletionRepositoryProvider)
      .listTeacherSubjectAssignments(
        query: ref.watch(schoolCompletionQueryProvider),
      );
});

final subjectWorkloadProvider =
    FutureProvider<List<SubjectWorkloadEntry>>((ref) async {
  return ref.read(schoolCompletionRepositoryProvider).getSubjectWorkload(
        query: ref.watch(schoolCompletionQueryProvider),
      );
});

final teacherLessonAnalyticsProvider =
    FutureProvider<TeacherLessonAnalytics>((ref) async {
  return ref.read(schoolCompletionRepositoryProvider).getTeacherLessonAnalytics(
        query: ref.watch(schoolCompletionQueryProvider),
      );
});

final principalLessonAnalyticsProvider =
    FutureProvider<List<PrincipalCoverageEntry>>((ref) async {
  return ref
      .read(schoolCompletionRepositoryProvider)
      .getPrincipalLessonAnalytics(
        query: ref.watch(schoolCompletionQueryProvider),
      );
});

final timetableOptimizationProvider =
    FutureProvider.family<TimetableOptimizationResult, String>(
        (ref, academicYearId) async {
  return ref.read(schoolCompletionRepositoryProvider).getTimetableOptimization(
        query: ref.watch(schoolCompletionQueryProvider),
        academicYearId: academicYearId,
      );
});

final substituteCoverageProvider = FutureProvider.family<SubstituteCoverageData,
    ({String academicYearId, String? dayOfWeek})>(
  (ref, params) async {
    return ref.read(schoolCompletionRepositoryProvider).getSubstituteCoverage(
          query: ref.watch(schoolCompletionQueryProvider),
          academicYearId: params.academicYearId,
          dayOfWeek: params.dayOfWeek,
        );
  },
);

final teacherReassignmentOptionsProvider = FutureProvider.family<
    TeacherReassignmentData,
    ({String academicYearId, String? sourceTeacherId})>(
  (ref, params) async {
    return ref
        .read(schoolCompletionRepositoryProvider)
        .getTeacherReassignmentOptions(
          query: ref.watch(schoolCompletionQueryProvider),
          academicYearId: params.academicYearId,
          sourceTeacherId: params.sourceTeacherId,
        );
  },
);

final deliveryAnalyticsProvider =
    FutureProvider<DeliveryAnalytics>((ref) async {
  return ref.read(schoolCompletionRepositoryProvider).getDeliveryAnalytics(
        query: ref.watch(schoolCompletionQueryProvider),
      );
});

final communicationAnalyticsProvider =
    FutureProvider<CommunicationAnalyticsSummary>((ref) async {
  return ref.read(schoolCompletionRepositoryProvider).getCommunicationAnalytics(
        query: ref.watch(schoolCompletionQueryProvider),
      );
});

final pilotDashboardProvider =
    FutureProvider<PilotDashboardSnapshot>((ref) async {
  return ref.read(schoolCompletionRepositoryProvider).getPilotDashboard(
        query: ref.watch(schoolCompletionQueryProvider),
      );
});

final subjectTemplatesProvider =
    FutureProvider<List<SubjectTemplate>>((ref) async {
  return ref.read(schoolCompletionRepositoryProvider).listSubjectTemplates(
        query: ref.watch(schoolCompletionQueryProvider),
      );
});

final syllabusChaptersProvider =
    FutureProvider.family<List<SyllabusChapter>, String?>(
        (ref, academicYearId) async {
  return ref.read(schoolCompletionRepositoryProvider).listSyllabusChapters(
        query: ref.watch(schoolCompletionQueryProvider),
        academicYearId: academicYearId,
      );
});

final teacherProgressProvider =
    FutureProvider<TeacherProgressDashboard>((ref) async {
  return ref.read(schoolCompletionRepositoryProvider).getTeacherProgress(
        query: ref.watch(schoolCompletionQueryProvider),
      );
});

final principalAcademicProgressProvider =
    FutureProvider<PrincipalAcademicDashboard>((ref) async {
  return ref
      .read(schoolCompletionRepositoryProvider)
      .getPrincipalAcademicProgress(
        query: ref.watch(schoolCompletionQueryProvider),
      );
});

final academicRoomsProvider = FutureProvider<List<AcademicRoom>>((ref) async {
  return ref.read(schoolCompletionRepositoryProvider).listRooms(
        query: ref.watch(schoolCompletionQueryProvider),
      );
});

final timetableIntelligenceProvider =
    FutureProvider.family<TimetableIntelligenceResult, String>(
        (ref, academicYearId) async {
  return ref.read(schoolCompletionRepositoryProvider).getTimetableIntelligence(
        query: ref.watch(schoolCompletionQueryProvider),
        academicYearId: academicYearId,
      );
});

final parentActivationDashboardProvider =
    FutureProvider<PilotActivationStats>((ref) async {
  return ref
      .read(schoolCompletionRepositoryProvider)
      .getParentActivationDashboard(
        query: ref.watch(schoolCompletionQueryProvider),
      );
});
