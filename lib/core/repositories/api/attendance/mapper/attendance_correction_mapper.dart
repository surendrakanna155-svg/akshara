import '../../../../attendance/attendance_correction_models.dart';

class AttendanceCorrectionMapper {
  const AttendanceCorrectionMapper();

  AttendanceCorrectionRequest toDomain(Map<String, dynamic> json) {
    return AttendanceCorrectionRequest(
      id: json['id'] as String,
      sisStudentId: json['sisStudentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      classLabel: json['classLabel'] as String? ?? '',
      section: json['section'] as String? ?? '',
      dateLabel: json['dateLabel'] as String? ?? '',
      fromMark: json['fromMark'] as String? ?? '',
      toMark: json['toMark'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      requesterId: json['requesterId'] as String? ?? '',
      requesterName: json['requesterName'] as String? ?? '',
      requesterRole: json['requesterRole'] as String? ?? '',
      status: _statusFromApi(json['status'] as String? ?? 'pending'),
      requestedAt: DateTime.tryParse(json['requestedAt'] as String? ?? '') ??
          DateTime.now(),
      studentsAffected: (json['studentsAffected'] as num?)?.toInt() ?? 1,
      presentDelta: (json['presentDelta'] as num?)?.toInt() ?? 1,
    );
  }

  List<AttendanceCorrectionRequest> toDomainList(List<dynamic> items) => items
      .map((item) => toDomain(item as Map<String, dynamic>))
      .toList(growable: false);

  Map<String, dynamic> createBody(CreateAttendanceCorrectionRequest request) {
    return {
      'sisStudentId': request.sisStudentId,
      'studentName': request.studentName,
      'classLabel': request.classLabel,
      'section': request.section,
      'dateLabel': request.dateLabel,
      'fromMark': request.fromMark,
      'toMark': request.toMark,
      'reason': request.reason,
      'requesterId': request.requesterId,
      'requesterName': request.requesterName,
      'requesterRole': request.requesterRole,
      'presentDelta': request.presentDelta,
    };
  }

  AttendanceCorrectionStatus _statusFromApi(String value) => switch (value) {
        'approved' => AttendanceCorrectionStatus.approved,
        'rejected' => AttendanceCorrectionStatus.rejected,
        'cancelled' => AttendanceCorrectionStatus.cancelled,
        _ => AttendanceCorrectionStatus.pending,
      };

  String statusToApi(AttendanceCorrectionStatus status) => switch (status) {
        AttendanceCorrectionStatus.approved => 'approved',
        AttendanceCorrectionStatus.rejected => 'rejected',
        AttendanceCorrectionStatus.cancelled => 'cancelled',
        AttendanceCorrectionStatus.pending => 'pending',
      };
}
