import '../../attendance/attendance_correction_models.dart';
import '../../attendance/attendance_correction_store.dart';
import '../../repositories/interfaces/attendance_correction_repository.dart';
import '../../repositories/mock/mock_attendance_correction_repository.dart';
import '../../repositories/mock/mock_attendance_sync_store.dart';
import '../../repositories/repository_query.dart';
import '../approval_center_service.dart';
import '../approval_models.dart';
import '../approval_request_type.dart';
import '../approval_requests.dart';
import 'approval_type_adapter.dart';

/// Attendance correction approval adapter — F2/F5 integration.
class AttendanceCorrectionApprovalAdapter implements ApprovalTypeAdapter {
  AttendanceCorrectionApprovalAdapter({
    AttendanceCorrectionRepository? repository,
    MockAttendanceSyncStore? store,
    AttendanceCorrectionStore? correctionStore,
  })  : _repository = repository ??
            MockAttendanceCorrectionRepository(store: correctionStore),
        _store = store ?? MockAttendanceSyncStore.instance,
        _correctionStore =
            correctionStore ?? AttendanceCorrectionStore.instance;

  final AttendanceCorrectionRepository _repository;
  final MockAttendanceSyncStore _store;
  final AttendanceCorrectionStore _correctionStore;

  static const entityType = 'attendance_day';

  Future<ApprovalRequest> submitForApproval({
    required ApprovalCenterService service,
    required RepositoryQuery query,
    required String entityId,
    required String requesterId,
    required String requesterName,
    required Map<String, Object?> payload,
    required String title,
    required String summary,
  }) {
    return service.submitApprovalRequest(
      query: query,
      request: SubmitApprovalRequest(
        type: ApprovalRequestType.attendanceCorrection,
        title: title,
        summary: summary,
        requesterId: requesterId,
        requesterName: requesterName,
        entityType: entityType,
        entityId: entityId,
        payload: payload,
      ),
    );
  }

  @override
  void onApproved({
    required RepositoryQuery query,
    required ApprovalRequest request,
  }) {
    if (request.type != ApprovalRequestType.attendanceCorrection) return;
    final payload = request.payload;
    final delta = payload['presentDelta'] is int
        ? payload['presentDelta'] as int
        : int.tryParse('${payload['presentDelta']}') ?? 1;
    _store.recordCorrectionApproved(
      presentDelta: delta,
      note: request.decisionComment ?? 'Attendance correction approved',
    );
    _correctionStore.updateStatus(
      id: request.entityId,
      status: AttendanceCorrectionStatus.approved,
    );
    // ignore: discarded_futures
    _repository.updateStatus(
      query: query,
      correctionId: request.entityId,
      status: AttendanceCorrectionStatus.approved,
    );
  }

  @override
  void onRejected({
    required RepositoryQuery query,
    required ApprovalRequest request,
    required String comment,
  }) {
    if (request.type != ApprovalRequestType.attendanceCorrection) return;
    _store.recordCorrectionRejected(comment: comment);
    _correctionStore.updateStatus(
      id: request.entityId,
      status: AttendanceCorrectionStatus.rejected,
    );
    // ignore: discarded_futures
    _repository.updateStatus(
      query: query,
      correctionId: request.entityId,
      status: AttendanceCorrectionStatus.rejected,
    );
  }

  @override
  Map<String, String> enrichDetail(ApprovalRequest request) {
    if (request.type != ApprovalRequestType.attendanceCorrection) return const {};
    final payload = request.payload;
    return {
      'Class': '${payload['classLabel'] ?? '—'}',
      'Date': '${payload['date'] ?? '—'}',
      'Students affected': '${payload['studentsAffected'] ?? '—'}',
      'From → To': '${payload['fromMark'] ?? '—'} → ${payload['toMark'] ?? '—'}',
      'Requester': '${payload['requesterRole'] ?? request.requesterName}',
    };
  }
}
