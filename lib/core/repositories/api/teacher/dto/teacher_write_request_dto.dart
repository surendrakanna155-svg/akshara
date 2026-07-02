import '../../../../../features/teacher/teacher_requests.dart';
import '../dto/teacher_enum_codec.dart';

class TeacherAttendanceDraftRequestDto {
  const TeacherAttendanceDraftRequestDto({required this.raw});

  factory TeacherAttendanceDraftRequestDto.fromDomain(
    TeacherAttendanceDraftRequest request,
  ) {
    return TeacherAttendanceDraftRequestDto(
      raw: {
        'class_id': request.classId,
        'entries': [
          for (final entry in request.entries)
            {
              'student_id': entry.studentId,
              'mark': TeacherEnumCodec.studentAttendanceMarkToApi(entry.mark),
            },
        ],
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class TeacherAttendanceSubmitRequestDto {
  const TeacherAttendanceSubmitRequestDto({required this.raw});

  factory TeacherAttendanceSubmitRequestDto.fromDomain(
    TeacherAttendanceSubmitRequest request,
  ) {
    return TeacherAttendanceSubmitRequestDto(
      raw: {
        'class_id': request.classId,
        'entries': [
          for (final entry in request.entries)
            {
              'student_id': entry.studentId,
              'mark': TeacherEnumCodec.studentAttendanceMarkToApi(entry.mark),
            },
        ],
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class TeacherAttendanceDraftResponseDto {
  const TeacherAttendanceDraftResponseDto({required this.raw});

  factory TeacherAttendanceDraftResponseDto.fromJson(Map<String, dynamic> json) {
    return TeacherAttendanceDraftResponseDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class TeacherAttendanceSubmitResponseDto {
  const TeacherAttendanceSubmitResponseDto({required this.raw});

  factory TeacherAttendanceSubmitResponseDto.fromJson(Map<String, dynamic> json) {
    return TeacherAttendanceSubmitResponseDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class TeacherHomeworkReviewRequestDto {
  const TeacherHomeworkReviewRequestDto({required this.raw});

  factory TeacherHomeworkReviewRequestDto.fromDomain(
    TeacherHomeworkReviewRequest request,
  ) {
    return TeacherHomeworkReviewRequestDto(
      raw: {
        'grade': request.grade,
        'comment': request.comment,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class TeacherHomeworkReviewResponseDto {
  const TeacherHomeworkReviewResponseDto({required this.raw});

  factory TeacherHomeworkReviewResponseDto.fromJson(Map<String, dynamic> json) {
    return TeacherHomeworkReviewResponseDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class TeacherExamMarkUpdateRequestDto {
  const TeacherExamMarkUpdateRequestDto({required this.raw});

  factory TeacherExamMarkUpdateRequestDto.fromDomain(
    TeacherExamMarkUpdateRequest request,
  ) {
    return TeacherExamMarkUpdateRequestDto(
      raw: {
        'marks_obtained': request.marksObtained,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class TeacherLeaveSubmitRequestDto {
  const TeacherLeaveSubmitRequestDto({required this.raw});

  factory TeacherLeaveSubmitRequestDto.fromDomain(
    TeacherLeaveSubmitRequest request,
  ) {
    return TeacherLeaveSubmitRequestDto(
      raw: {
        'type_label': request.typeLabel,
        'from_date_label': request.fromDateLabel,
        'to_date_label': request.toDateLabel,
        'reason': request.reason,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class TeacherHomeworkCreateRequestDto {
  const TeacherHomeworkCreateRequestDto({required this.raw});

  factory TeacherHomeworkCreateRequestDto.fromDomain(
    TeacherHomeworkCreateRequest request,
  ) {
    final studentName = request.studentName?.trim();
    final dueLabel = request.dueLabel.trim();
    final attachmentName = request.attachmentName?.trim();
    final attachmentRef = request.attachmentRef?.trim();
    // HWK-3 — de-dupe the multi-section list; fall back to the single class label.
    final classLabels = {
      for (final label in request.classLabels) label.trim(),
    }..removeWhere((l) => l.isEmpty);
    return TeacherHomeworkCreateRequestDto(
      raw: {
        'class_label': request.classLabel,
        // HWK-3 — multi-section assign (server fans out one delivery per class).
        if (classLabels.isNotEmpty) 'class_labels': classLabels.toList(),
        'subject': request.subject,
        'title': request.title,
        // HWK-1 — real ISO due date; the backend validates it (422 on blank/bad).
        'due_date': request.dueDate,
        // Optional human label; when blank the backend derives it from due_date.
        if (dueLabel.isNotEmpty) 'due_label': dueLabel,
        if (studentName != null && studentName.isNotEmpty)
          'student_name': studentName,
        // HWK-4 — optional teacher attachment reference (not a real upload).
        if (attachmentName != null && attachmentName.isNotEmpty)
          'attachment_name': attachmentName,
        if (attachmentRef != null && attachmentRef.isNotEmpty)
          'attachment_ref': attachmentRef,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class TeacherMessageSendRequestDto {
  const TeacherMessageSendRequestDto({required this.raw});

  factory TeacherMessageSendRequestDto.fromDomain(
    TeacherMessageSendRequest request,
  ) {
    return TeacherMessageSendRequestDto(
      raw: {
        'recipient': request.recipient,
        'subject': request.subject,
        'body': request.body,
        if (request.threadId != null) 'thread_id': request.threadId,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
