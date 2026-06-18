import '../../../core/exams/exam_administration_store.dart';

/// Filter chips for the exam administration list.
enum ExamAdminPhaseFilter {
  all,
  draft,
  scheduled,
  marksEntry,
  processed,
  published,
}

extension ExamAdminPhaseFilterX on ExamAdminPhaseFilter {
  String get label => switch (this) {
        ExamAdminPhaseFilter.all => 'All',
        ExamAdminPhaseFilter.draft => 'Draft',
        ExamAdminPhaseFilter.scheduled => 'Scheduled',
        ExamAdminPhaseFilter.marksEntry => 'Marks entry',
        ExamAdminPhaseFilter.processed => 'Processed',
        ExamAdminPhaseFilter.published => 'Published',
      };

  bool matches(ExamSession exam) => switch (this) {
        ExamAdminPhaseFilter.all => true,
        ExamAdminPhaseFilter.draft =>
          exam.phase == ExamLifecyclePhase.draft,
        ExamAdminPhaseFilter.scheduled =>
          exam.phase == ExamLifecyclePhase.scheduled,
        ExamAdminPhaseFilter.marksEntry =>
          exam.phase == ExamLifecyclePhase.marksEntry,
        ExamAdminPhaseFilter.processed =>
          exam.phase == ExamLifecyclePhase.processed,
        ExamAdminPhaseFilter.published =>
          exam.phase == ExamLifecyclePhase.published,
      };
}

String examPhaseLabel(ExamLifecyclePhase phase) => switch (phase) {
      ExamLifecyclePhase.draft => 'Draft',
      ExamLifecyclePhase.scheduled => 'Scheduled',
      ExamLifecyclePhase.marksEntry => 'Marks entry',
      ExamLifecyclePhase.processed => 'Processed',
      ExamLifecyclePhase.published => 'Published',
    };
