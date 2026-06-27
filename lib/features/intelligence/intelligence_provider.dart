import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/repositories/repository_query.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import 'intelligence_models.dart';
import '../../core/errors/mutation_in_progress.dart';

final intelligenceQueryProvider = Provider<RepositoryQuery>(
  (ref) => ref.watch(repositoryQueryProvider),
);

final intelligenceCanViewRiskProvider = Provider<bool>((ref) {
  final rbac = ref.watch(rbacServiceProvider);
  return rbac.hasPermission(Permission.viewStudentRisk) ||
      rbac.hasPermission(Permission.viewAnalytics);
});

final intelligenceCanGenerateProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.generateIntelligence);
});

final intelligenceCanViewPrincipalProvider = Provider<bool>((ref) {
  final rbac = ref.watch(rbacServiceProvider);
  return rbac.hasPermission(Permission.viewAnalytics) ||
      rbac.hasPermission(Permission.viewSchoolHealth);
});

final studentRisksListProvider = FutureProvider<List<StudentRiskSnapshot>>((ref) async {
  return ref.read(intelligenceRepositoryProvider).listStudentRisks(
        query: ref.watch(intelligenceQueryProvider),
      );
});

final classRisksListProvider = FutureProvider<List<ClassRiskSummary>>((ref) async {
  return ref.read(intelligenceRepositoryProvider).listClassRisks(
        query: ref.watch(intelligenceQueryProvider),
      );
});

final teacherSuccessCenterProvider = FutureProvider<TeacherSuccessCenter>((ref) async {
  return ref.read(intelligenceRepositoryProvider).getTeacherSuccessCenter(
        query: ref.watch(intelligenceQueryProvider),
      );
});

final principalIntelligenceProvider =
    FutureProvider.family<PrincipalIntelligenceCenter, String>((ref, period) async {
  return ref.read(intelligenceRepositoryProvider).getPrincipalCenter(
        query: ref.watch(intelligenceQueryProvider),
        period: period,
      );
});

final principalQueryProvider =
    FutureProvider.family<PrincipalQueryResult, String>((ref, queryText) async {
  return ref.read(intelligenceRepositoryProvider).queryPrincipal(
        query: ref.watch(intelligenceQueryProvider),
        queryText: queryText,
      );
});

final intelligenceMutationsProvider =
    AsyncNotifierProvider<IntelligenceMutationsNotifier, void>(IntelligenceMutationsNotifier.new);

class IntelligenceMutationsNotifier extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<int> computeRisks({String? academicYearLabel}) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    try {
      final rows = await ref.read(intelligenceRepositoryProvider).computeStudentRisks(
            query: ref.read(intelligenceQueryProvider),
            academicYearLabel: academicYearLabel,
          );
      ref.invalidate(studentRisksListProvider);
      ref.invalidate(classRisksListProvider);
      ref.invalidate(teacherSuccessCenterProvider);
      ref.invalidate(principalIntelligenceProvider('monthly'));
      ref.invalidate(principalIntelligenceProvider('quarterly'));
      state = const AsyncData(null);
      return rows.length;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<List<CommunicationDraft>> generateCommunication({
    required CommunicationScenario scenario,
    String? studentName,
    String? className,
    String? customNote,
    List<IntelLanguage> languages = const [IntelLanguage.english],
    IntelLanguage? parentPreferredLanguage,
    String? feeAmount,
    String? dueDate,
    String? examName,
    String? meetingDate,
  }) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    try {
      final drafts = await ref.read(intelligenceRepositoryProvider).generateCommunication(
            query: ref.read(intelligenceQueryProvider),
            scenario: scenario,
            studentName: studentName,
            className: className,
            customNote: customNote,
            languages: languages,
            parentPreferredLanguage: parentPreferredLanguage,
            feeAmount: feeAmount,
            dueDate: dueDate,
            examName: examName,
            meetingDate: meetingDate,
          );
      state = const AsyncData(null);
      return drafts;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<ParentGuidanceReport> generateParentGuidance({
    required String studentId,
    required GuidanceMode mode,
    IntelLanguage language = IntelLanguage.english,
    Map<String, dynamic> inputs = const {},
    bool publish = true,
    bool autoFillFromRisk = true,
  }) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    try {
      final report = await ref.read(intelligenceRepositoryProvider).generateParentGuidance(
            query: ref.read(intelligenceQueryProvider),
            studentId: studentId,
            mode: mode,
            language: language,
            inputs: inputs,
            publish: publish,
            autoFillFromRisk: autoFillFromRisk,
          );
      state = const AsyncData(null);
      return report;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
