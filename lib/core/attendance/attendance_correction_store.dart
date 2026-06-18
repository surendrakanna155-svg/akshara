import '../attendance/attendance_correction_models.dart';

/// In-memory attendance correction requests (Phase B scaffold).
final class AttendanceCorrectionStore {
  AttendanceCorrectionStore._();

  static final AttendanceCorrectionStore instance = AttendanceCorrectionStore._();

  final List<AttendanceCorrectionRequest> _requests = [];
  int _sequence = 0;

  void reset() {
    _requests.clear();
    _sequence = 0;
  }

  List<AttendanceCorrectionRequest> listAll() =>
      List<AttendanceCorrectionRequest>.unmodifiable(_requests);

  AttendanceCorrectionRequest? byId(String id) {
    for (final request in _requests) {
      if (request.id == id) return request;
    }
    return null;
  }

  AttendanceCorrectionRequest create(CreateAttendanceCorrectionRequest input) {
    final request = AttendanceCorrectionRequest(
      id: 'att_corr_${++_sequence}',
      sisStudentId: input.sisStudentId,
      studentName: input.studentName,
      classLabel: input.classLabel,
      section: input.section,
      dateLabel: input.dateLabel,
      fromMark: input.fromMark,
      toMark: input.toMark,
      reason: input.reason,
      requesterId: input.requesterId,
      requesterName: input.requesterName,
      requesterRole: input.requesterRole,
      status: AttendanceCorrectionStatus.pending,
      requestedAt: DateTime.now(),
      presentDelta: input.presentDelta,
    );
    _requests.insert(0, request);
    return request;
  }

  AttendanceCorrectionRequest updateStatus({
    required String id,
    required AttendanceCorrectionStatus status,
  }) {
    final index = _requests.indexWhere((item) => item.id == id);
    if (index < 0) throw StateError('Attendance correction not found: $id');
    final updated = _requests[index].copyWith(status: status);
    _requests[index] = updated;
    return updated;
  }
}
