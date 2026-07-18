import '../../errors/api_failure.dart';
import '../../exams/exam_administration_store.dart';
import '../../repositories/interfaces/exam_administration_repository.dart';
import '../../repositories/mock/mock_exam_administration_repository.dart';
import '../../repositories/repository_query.dart';
import '../approval_center_service.dart';
import '../approval_models.dart';
import '../approval_request_type.dart';
import '../approval_requests.dart';
import 'approval_type_adapter.dart';

/// Connects exam publication to the unified approval center (M-D3 / F4).
class ExamResultsApprovalAdapter implements ApprovalTypeAdapter {
  ExamResultsApprovalAdapter({
    ExamAdministrationRepository? repository,
    ExamAdministrationStore? store,
  })  : _repository = repository ?? MockExamAdministrationRepository(store: store),
        _store = store ?? ExamAdministrationStore.instance;

  final ExamAdministrationRepository _repository;
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
    final exam = await _repository.getExam(query: query, examId: examId);
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
        const ApiFailure(
          type: ApiFailureType.unknown,
          message: 'Exam results are already published.',
          code: 'EXAM_ALREADY_PUBLISHED',
        ),
      );
    }

    await _ensureProcessed(query, examId, exam);
    await _ensureCoordinatorVerified(query, examId, exam);
    _store.clearRejectionComment(examId);

    final refreshed = await _repository.getExam(query: query, examId: examId);
    final marks = await _repository.listMarks(query: query, examId: examId);
    final entered = marks.where((m) => m.marksObtained != null).length;

    return service.submitApprovalRequest(
      query: query,
      request: SubmitApprovalRequest(
        type: ApprovalRequestType.examResults,
        title: 'Publish ${refreshed!.classLabel} ${refreshed.subject} results',
        summary:
            '${refreshed.title} — $entered/${marks.length} marks entered',
        requesterId: requesterId,
        requesterName: requesterName,
        entityType: entityType,
        entityId: examId,
        payload: await buildSubmitPayload(query, examId),
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
    // PRA-N-9 (S0/T2-C): read the approval request's own payload (populated by
    // `buildSubmitPayload` at submit time) rather than the in-memory
    // `ExamAdministrationStore`, which is never populated in API mode — so this
    // previously rendered "Exam session not found in store" for every real exam.
    // Mirrors the finance/inventory/leave adapters, which read `request.payload`.
    final p = request.payload;
    final entered = p['marksEntered'];
    final total = p['marksTotal'];
    final completion = (entered is int && total is int && total > 0)
        ? '${((entered / total) * 100).round()}%'
        : '0%';

    return {
      'Class': '${p['classLabel'] ?? '—'}',
      'Subject': '${p['subject'] ?? '—'}',
      'Exam': '${p['examTitle'] ?? '—'}',
      'Term': '${p['termLabel'] ?? '—'}',
      'Marks completion': '${entered ?? 0}/${total ?? 0} ($completion)',
      'Phase': '${p['phase'] ?? '—'}',
      'Coordinator verified': p['coordinatorVerified'] == true ? 'Yes' : 'No',
    };
  }

  /// Shared payload for submit + detail enrichment.
  Future<Map<String, Object?>> buildSubmitPayload(
    RepositoryQuery query,
    String examId,
  ) async {
    final exam = await _repository.getExam(query: query, examId: examId);
    if (exam == null) return const {};

    final marks = await _repository.listMarks(query: query, examId: examId);
    final entered = marks.where((m) => m.marksObtained != null).length;

    return {
      'classLabel': exam.classLabel,
      'subject': exam.subject,
      'examTitle': exam.title,
      'termLabel': exam.termLabel,
      'marksEntered': entered,
      'marksTotal': marks.length,
      'phase': exam.phase.name,
      'coordinatorVerified': exam.coordinatorVerified,
    };
  }

  Future<void> _ensureCoordinatorVerified(
    RepositoryQuery query,
    String examId,
    ExamSession exam,
  ) async {
    if (exam.coordinatorVerified || _store.isCoordinatorVerified(examId)) return;
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.unknown,
        message:
            'Exam results must be verified by the exam coordinator before principal approval.',
        code: 'EXAM_COORDINATOR_VERIFICATION_REQUIRED',
      ),
    );
  }

  Future<void> _ensureProcessed(
    RepositoryQuery query,
    String examId,
    ExamSession exam,
  ) async {
    if (exam.phase == ExamLifecyclePhase.processed) return;

    if (exam.phase == ExamLifecyclePhase.marksEntry ||
        exam.phase == ExamLifecyclePhase.scheduled) {
      try {
        await _repository.processResults(query: query, examId: examId);
      } on ApiFailureException {
        rethrow;
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
