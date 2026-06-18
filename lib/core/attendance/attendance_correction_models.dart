/// Attendance correction workflow domain (Phase B).
enum AttendanceCorrectionStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

/// Request to correct a submitted attendance mark after lock.
class AttendanceCorrectionRequest {
  const AttendanceCorrectionRequest({
    required this.id,
    required this.sisStudentId,
    required this.studentName,
    required this.classLabel,
    required this.section,
    required this.dateLabel,
    required this.fromMark,
    required this.toMark,
    required this.reason,
    required this.requesterId,
    required this.requesterName,
    required this.requesterRole,
    required this.status,
    required this.requestedAt,
    this.studentsAffected = 1,
    this.presentDelta = 1,
  });

  final String id;
  final String sisStudentId;
  final String studentName;
  final String classLabel;
  final String section;
  final String dateLabel;
  final String fromMark;
  final String toMark;
  final String reason;
  final String requesterId;
  final String requesterName;
  final String requesterRole;
  final AttendanceCorrectionStatus status;
  final DateTime requestedAt;
  final int studentsAffected;
  final int presentDelta;

  AttendanceCorrectionRequest copyWith({
    AttendanceCorrectionStatus? status,
  }) {
    return AttendanceCorrectionRequest(
      id: id,
      sisStudentId: sisStudentId,
      studentName: studentName,
      classLabel: classLabel,
      section: section,
      dateLabel: dateLabel,
      fromMark: fromMark,
      toMark: toMark,
      reason: reason,
      requesterId: requesterId,
      requesterName: requesterName,
      requesterRole: requesterRole,
      status: status ?? this.status,
      requestedAt: requestedAt,
      studentsAffected: studentsAffected,
      presentDelta: presentDelta,
    );
  }
}

class CreateAttendanceCorrectionRequest {
  const CreateAttendanceCorrectionRequest({
    required this.sisStudentId,
    required this.studentName,
    required this.classLabel,
    required this.section,
    required this.dateLabel,
    required this.fromMark,
    required this.toMark,
    required this.reason,
    required this.requesterId,
    required this.requesterName,
    required this.requesterRole,
    this.presentDelta = 1,
  });

  final String sisStudentId;
  final String studentName;
  final String classLabel;
  final String section;
  final String dateLabel;
  final String fromMark;
  final String toMark;
  final String reason;
  final String requesterId;
  final String requesterName;
  final String requesterRole;
  final int presentDelta;
}
