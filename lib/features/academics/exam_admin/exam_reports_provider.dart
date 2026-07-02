import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exams/exam_administration_store.dart';
import '../../../core/exams/exam_grading.dart';
import '../../../core/exams/exam_reports.dart';
import '../../../core/repositories/interfaces/exam_administration_repository.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/repositories/repository_query.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../school_completion/school_branding_theme_provider.dart';
import 'exam_administration_provider.dart';

/// EXM-3/4/5/7 — state + reads for the Exam Reports area.
///
/// The reports are class + term scoped (tabulation, merit, datesheet) or exam
/// scoped (subject toppers, distribution). These providers hold the selected
/// scope and expose one [FutureProvider] per report, each RBAC-gated at the
/// route/handler layer on viewExams. Non-present (AB/ML/DB) rows are excluded
/// from every statistic by the repository / backend.

/// Which of the four report views is active.
enum ExamReportTab { tabulation, meritToppers, distribution, datesheet }

extension ExamReportTabX on ExamReportTab {
  String get label => switch (this) {
        ExamReportTab.tabulation => 'Tabulation',
        ExamReportTab.meritToppers => 'Merit & Toppers',
        ExamReportTab.distribution => 'Pass / Fail',
        ExamReportTab.datesheet => 'Datesheet',
      };

  String get keyName => switch (this) {
        ExamReportTab.tabulation => 'tabulation',
        ExamReportTab.meritToppers => 'merit_toppers',
        ExamReportTab.distribution => 'distribution',
        ExamReportTab.datesheet => 'datesheet',
      };
}

final examReportsTabProvider =
    StateProvider<ExamReportTab>((ref) => ExamReportTab.tabulation);

/// Selected class label (`grade-section`, e.g. "8-A"). Defaults to the first
/// class that has any exam session, else empty.
final examReportsClassProvider = StateProvider<String>((ref) {
  final exams = ref.watch(examAdministrationListProvider).valueOrNull;
  return exams != null && exams.isNotEmpty ? exams.first.classLabel : '';
});

/// Selected term. Defaults to the first term seen across exam sessions.
final examReportsTermProvider = StateProvider<String>((ref) {
  final exams = ref.watch(examAdministrationListProvider).valueOrNull;
  return exams != null && exams.isNotEmpty ? exams.first.termLabel : '';
});

/// Selected exam id for the exam-scoped reports (toppers / distribution).
/// Defaults to the first exam of the selected class + term, else the first exam.
final examReportsExamIdProvider = StateProvider<String?>((ref) {
  final exams = ref.watch(examAdministrationListProvider).valueOrNull;
  if (exams == null || exams.isEmpty) return null;
  final classLabel = ref.watch(examReportsClassProvider);
  final term = ref.watch(examReportsTermProvider);
  final match = exams.where(
    (e) => e.classLabel == classLabel && e.termLabel == term,
  );
  if (match.isNotEmpty) return match.first.id;
  return exams.first.id;
});

/// Distinct class labels across all exam sessions (for the class picker).
final examReportsClassOptionsProvider = Provider<List<String>>((ref) {
  final exams = ref.watch(examAdministrationListProvider).valueOrNull ?? const [];
  final labels = <String>{for (final e in exams) e.classLabel};
  final sorted = labels.toList()..sort();
  return sorted;
});

/// Distinct terms across all exam sessions (for the term picker).
final examReportsTermOptionsProvider = Provider<List<String>>((ref) {
  final exams = ref.watch(examAdministrationListProvider).valueOrNull ?? const [];
  final terms = <String>{for (final e in exams) e.termLabel};
  final sorted = terms.toList()..sort();
  return sorted;
});

/// Exams available for the exam-scoped report pickers (selected class + term).
final examReportsExamOptionsProvider = Provider<List<ExamSession>>((ref) {
  final exams = ref.watch(examAdministrationListProvider).valueOrNull ?? const [];
  final classLabel = ref.watch(examReportsClassProvider);
  final term = ref.watch(examReportsTermProvider);
  return exams
      .where((e) => e.classLabel == classLabel && e.termLabel == term)
      .toList(growable: false);
});

ExamAdministrationRepository _repo(Ref ref) =>
    ref.read(examAdministrationRepositoryProvider);
RepositoryQuery _query(Ref ref) => ref.read(repositoryQueryProvider);

/// The exam repository (for the EXM-D5 seating generate action from the screen).
final examReportsRepositoryProvider =
    Provider<ExamAdministrationRepository>((ref) =>
        ref.read(examAdministrationRepositoryProvider));

/// The active repository query (tenant/school scope) for the reports screen.
final examReportsQueryProvider =
    Provider<RepositoryQuery>((ref) => ref.read(repositoryQueryProvider));

/// School name for the printed report-card / hall-ticket header.
final examReportsSchoolNameProvider = Provider<String>((ref) {
  final name = ref.watch(schoolDisplayNameProvider);
  return name.isNotEmpty ? name : 'School';
});

/// The per-school grading / rank-visibility settings applied to report cards.
final examReportSettingsProvider = Provider<ExamReportSettings>(
  (ref) => ExamAdministrationStore.instance.reportSettings,
);

// ── EXM-3 — tabulation register ──────────────────────────────────────────────

final examTabulationProvider = FutureProvider<TabulationRegister>((ref) async {
  ref.watch(examAdminRefreshTickProvider);
  final classLabel = ref.watch(examReportsClassProvider);
  final term = ref.watch(examReportsTermProvider);
  return _repo(ref).tabulation(
    query: _query(ref),
    classLabel: classLabel,
    term: term,
  );
});

// ── EXM-4 — merit list + subject toppers ─────────────────────────────────────

final examMeritProvider = FutureProvider<List<MeritEntry>>((ref) async {
  ref.watch(examAdminRefreshTickProvider);
  final classLabel = ref.watch(examReportsClassProvider);
  final term = ref.watch(examReportsTermProvider);
  return _repo(ref).meritList(
    query: _query(ref),
    classLabel: classLabel,
    term: term,
  );
});

final examToppersProvider = FutureProvider<List<ExamTopper>>((ref) async {
  ref.watch(examAdminRefreshTickProvider);
  final examId = ref.watch(examReportsExamIdProvider);
  if (examId == null) return const [];
  return _repo(ref).examToppers(query: _query(ref), examId: examId, limit: 5);
});

// ── EXM-5 — pass/fail + grade distribution ───────────────────────────────────

final examDistributionProvider =
    FutureProvider<ExamGradeDistribution?>((ref) async {
  ref.watch(examAdminRefreshTickProvider);
  final examId = ref.watch(examReportsExamIdProvider);
  if (examId == null) return null;
  return _repo(ref).examDistribution(query: _query(ref), examId: examId);
});

// ── EXM-7 — datesheet ────────────────────────────────────────────────────────

final examDatesheetProvider = FutureProvider<List<DatesheetRow>>((ref) async {
  ref.watch(examAdminRefreshTickProvider);
  final classLabel = ref.watch(examReportsClassProvider);
  final term = ref.watch(examReportsTermProvider);
  return _repo(ref).datesheet(
    query: _query(ref),
    classLabel: classLabel,
    term: term,
  );
});

// ── EXM-D1 — batch report cards (published, effective marks) ──────────────────

/// EXM-D1 — the per-student report cards for the selected class + term. Used by
/// the "Print report cards" action to build the multi-page bundle.
final examReportCardsProvider = FutureProvider<List<ReportCardData>>((ref) async {
  ref.watch(examAdminRefreshTickProvider);
  final classLabel = ref.watch(examReportsClassProvider);
  final term = ref.watch(examReportsTermProvider);
  return _repo(ref).reportCards(
    query: _query(ref),
    classLabel: classLabel,
    term: term,
  );
});

// ── EXM-D4 — hall tickets (admit cards) for the selected exam ─────────────────

final examHallTicketsProvider = FutureProvider<List<HallTicket>>((ref) async {
  ref.watch(examAdminRefreshTickProvider);
  final examId = ref.watch(examReportsExamIdProvider);
  if (examId == null) return const [];
  return _repo(ref).hallTickets(query: _query(ref), examId: examId);
});

// ── EXM-D5 — seating plan for the selected exam ───────────────────────────────

final examSeatingProvider = FutureProvider<SeatingPlan?>((ref) async {
  ref.watch(examAdminRefreshTickProvider);
  final examId = ref.watch(examReportsExamIdProvider);
  if (examId == null) return null;
  return _repo(ref).seating(query: _query(ref), examId: examId);
});
