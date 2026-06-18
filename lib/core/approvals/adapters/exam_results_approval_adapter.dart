import '../../errors/api_failure.dart';
import '../../exams/exam_administration_store.dart';
import '../../repositories/repository_query.dart';
import '../approval_center_service.dart';
import '../approval_models.dart';
import '../approval_request_type.dart';
import '../approval_requests.dart';
import 'approval_type_adapter.dart';

/// Connects exam publication to the unified approval center (M-D3).
class ExamResultsApprovalAdapter implements ApprovalTypeAdapter {
  ExamResultsApprovalAdapter({ExamAdministrationStore? store})
      : _store = store ?? ExamAdministrationStore.instance;

  final ExamAdministrationStore _store;

  static const entityType = 'exam_session';

  /// Submits processed exam results for principal approval.
  Future<ApprovalRequest> submitForApproval({
    required ApprovalCenterService service,
    required RepositoryQuery query,
    required String examId,
    required String requesterId,
    required String requesterName,
  }) async {
    _store.ensureSeeded();
    final exam = _store.examById(examId);
    if (exam == null) {
      throw ApiFailureException(
        ApiFailure(
          type: ApiFailureType.unknown,
          message: 'Exam not found: $examId',
          code: 'EXAM_NOT_FOUND',
        ),
      );
    }
    if (exam.phase == ExamLifecyclePhase.published) {
      throw ApiFailureException(
        ApiFailure(
          type: ApiFailureType.unknown,
          message: 'Exam results are already published.',
          code: 'EXAM_ALREADY_PUBLISHED',
        ),
      );
    }

    _ensureProcessed(examId);
    _ensureCoordinatorVerified(examId);
    _store.clearRejectionComment(examId);

    final refreshed = _store.examById(examId)!;
    final marks = _store.marksForExam(examId);
    final entered = marks.where((m) => m.marksObtained != null).length;

    return service.submitApprovalRequest(
      query: query,
      request: SubmitApprovalRequest(
        type: ApprovalRequestType.examResults,
        title: 'Publish ${refreshed.classLabel} ${refreshed.subject} results',
        summary:
            '${refreshed.title} — $entered/${marks.length} marks entered',
        requesterId: requesterId,
        requesterName: requesterName,
        entityType: entityType,
        entityId: examId,
        payload: buildSubmitPayload(examId),
      ),
    );
  }

  @override
  void onApproved({
    required RepositoryQuery query,
    required ApprovalRequest request,
  }) {
    if (request.type != ApprovalRequestType.examResults) return;
    _store.ensureSeeded();
    _store.clearRejectionComment(request.entityId);
    _store.publishExamResults(request.entityId);
  }

  @override
  void onRejected({
    required RepositoryQuery query,
    required ApprovalRequest request,
    required String comment,
  }) {
    if (request.type != ApprovalRequestType.examResults) return;
    _store.ensureSeeded();
    final exam = _store.examById(request.entityId);
    if (exam == null) return;
    if (exam.phase == ExamLifecyclePhase.published) return;

    if (exam.phase == ExamLifecyclePhase.marksEntry) {
      try {
        _store.processResults(request.entityId);
      } catch (_) {
        // Keep current phase when marks are incomplete.
      }
    }

    _store.recordRejectionComment(request.entityId, comment);
    _store.clearCoordinatorVerification(request.entityId);
  }

  @override
  Map<String, String> enrichDetail(ApprovalRequest request) {
    if (request.type != ApprovalRequestType.examResults) return const {};
    _store.ensureSeeded();
    final exam = _store.examById(request.entityId);
    if (exam == null) {
      return const {'Status': 'Exam session not found in store'};
    }

    final marks = _store.marksForExam(exam.id);
    final entered = marks.where((m) => m.marksObtained != null).length;
    final total = marks.length;
    final completion =
        total == 0 ? '0%' : '${((entered / total) * 100).round()}%';

    return {
      'Class': exam.classLabel,
      'Subject': exam.subject,
      'Exam': exam.title,
      'Term': exam.termLabel,
      'Marks completion': '$entered/$total ($completion)',
      'Phase': exam.phase.name,
      'Coordinator verified': _store.isCoordinatorVerified(exam.id) ? 'Yes' : 'No',
    };
  }

  /// Shared payload for submit + detail enrichment.
  Map<String, Object?> buildSubmitPayload(String examId) {
    _store.ensureSeeded();
    final exam = _store.examById(examId);
    if (exam == null) return const {};

    final marks = _store.marksForExam(examId);
    final entered = marks.where((m) => m.marksObtained != null).length;

    return {
      'classLabel': exam.classLabel,
      'subject': exam.subject,
      'examTitle': exam.title,
      'termLabel': exam.termLabel,
      'marksEntered': entered,
      'marksTotal': marks.length,
      'phase': exam.phase.name,
      'coordinatorVerified': _store.isCoordinatorVerified(examId),
    };
  }

  void _ensureCoordinatorVerified(String examId) {
    if (_store.isCoordinatorVerified(examId)) return;
    throw ApiFailureException(
      ApiFailure(
        type: ApiFailureType.unknown,
        message:
            'Exam results must be verified by the exam coordinator before principal approval.',
        code: 'EXAM_COORDINATOR_VERIFICATION_REQUIRED',
      ),
    );
  }

  void _ensureProcessed(String examId) {
    final exam = _store.examById(examId)!;
    if (exam.phase == ExamLifecyclePhase.processed) return;

    if (exam.phase == ExamLifecyclePhase.marksEntry ||
        exam.phase == ExamLifecyclePhase.scheduled) {
      try {
        _store.processResults(examId);
      } on StateError catch (e) {
        throw ApiFailureException(
          ApiFailure(
            type: ApiFailureType.unknown,
            message: e.message,
            code: 'EXAM_MARKS_INCOMPLETE',
          ),
        );
      }
      return;
    }

    throw ApiFailureException(
      ApiFailure(
        type: ApiFailureType.unknown,
        message:
            'Exam must be in marks entry or processed phase before submission (current: ${exam.phase.name}).',
        code: 'EXAM_INVALID_PHASE',
      ),
    );
  }
}
