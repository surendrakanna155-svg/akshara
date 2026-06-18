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

/// Where an exam sits in the approve → publish chain. Surfaced in the Exam
/// Workspace hub so coordinators and principals see, at a glance, what each
/// exam is waiting on. Derived purely from the lifecycle phase plus the
/// coordinator-verified and rejection flags the repository enriches onto the
/// session — no approval-center round-trip needed.
enum ExamApprovalStatus {
  /// Draft / scheduled — nothing to approve or publish yet.
  none,

  /// Teacher is still entering marks.
  marksInProgress,

  /// Marks processed; waiting for the exam coordinator to verify.
  awaitingVerification,

  /// Coordinator verified; waiting for the principal's approval to publish.
  awaitingApproval,

  /// Principal sent the results back to the teacher with feedback.
  returned,

  /// Results are live to students and parents.
  published,
}

ExamApprovalStatus examApprovalStatus(ExamSession exam) {
  if (exam.phase == ExamLifecyclePhase.published) {
    return ExamApprovalStatus.published;
  }
  final rejection = exam.rejectionComment;
  if (rejection != null && rejection.isNotEmpty) {
    return ExamApprovalStatus.returned;
  }
  return switch (exam.phase) {
    ExamLifecyclePhase.marksEntry => ExamApprovalStatus.marksInProgress,
    ExamLifecyclePhase.processed => exam.coordinatorVerified
        ? ExamApprovalStatus.awaitingApproval
        : ExamApprovalStatus.awaitingVerification,
    _ => ExamApprovalStatus.none,
  };
}

String examApprovalStatusLabel(ExamApprovalStatus status) => switch (status) {
      ExamApprovalStatus.none => '',
      ExamApprovalStatus.marksInProgress => 'Marks in progress',
      ExamApprovalStatus.awaitingVerification =>
        'Awaiting coordinator verification',
      ExamApprovalStatus.awaitingApproval => 'Awaiting principal approval',
      ExamApprovalStatus.returned => 'Returned by principal',
      ExamApprovalStatus.published => 'Published to students & parents',
    };
