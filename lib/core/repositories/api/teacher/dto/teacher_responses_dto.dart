import '../../admissions/dto/api_envelope_dto.dart';
import '../../admissions/dto/pagination_dto.dart';

class TeacherDashboardDto {
  const TeacherDashboardDto({required this.raw});

  factory TeacherDashboardDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TeacherDashboardDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class TeacherAttendanceClassDto {
  const TeacherAttendanceClassDto({required this.raw});

  factory TeacherAttendanceClassDto.fromJson(Map<String, dynamic> json) {
    return TeacherAttendanceClassDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class TeacherAttendanceClassesResponseDto {
  const TeacherAttendanceClassesResponseDto({
    required this.items,
    this.pagination,
  });

  factory TeacherAttendanceClassesResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TeacherAttendanceClassesResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          TeacherAttendanceClassDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<TeacherAttendanceClassDto> items;
  final PaginationDto? pagination;
}

class TeacherAttendanceStudentsResponseDto {
  const TeacherAttendanceStudentsResponseDto({required this.raw});

  factory TeacherAttendanceStudentsResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TeacherAttendanceStudentsResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class TeacherHomeworkAssignmentDto {
  const TeacherHomeworkAssignmentDto({required this.raw});

  factory TeacherHomeworkAssignmentDto.fromJson(Map<String, dynamic> json) {
    return TeacherHomeworkAssignmentDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class TeacherHomeworkResponseDto {
  const TeacherHomeworkResponseDto({
    required this.items,
    this.pagination,
  });

  factory TeacherHomeworkResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TeacherHomeworkResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          TeacherHomeworkAssignmentDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<TeacherHomeworkAssignmentDto> items;
  final PaginationDto? pagination;
}

class TeacherUpcomingExamDto {
  const TeacherUpcomingExamDto({required this.raw});

  factory TeacherUpcomingExamDto.fromJson(Map<String, dynamic> json) {
    return TeacherUpcomingExamDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class TeacherUpcomingExamsResponseDto {
  const TeacherUpcomingExamsResponseDto({
    required this.items,
    this.pagination,
  });

  factory TeacherUpcomingExamsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TeacherUpcomingExamsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          TeacherUpcomingExamDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<TeacherUpcomingExamDto> items;
  final PaginationDto? pagination;
}

class TeacherMarksEntryExamDto {
  const TeacherMarksEntryExamDto({required this.raw});

  factory TeacherMarksEntryExamDto.fromJson(Map<String, dynamic> json) {
    return TeacherMarksEntryExamDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class TeacherMarksEntryExamsResponseDto {
  const TeacherMarksEntryExamsResponseDto({
    required this.items,
    this.pagination,
  });

  factory TeacherMarksEntryExamsResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TeacherMarksEntryExamsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          TeacherMarksEntryExamDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<TeacherMarksEntryExamDto> items;
  final PaginationDto? pagination;
}

class ExamMarkEntryDto {
  const ExamMarkEntryDto({required this.raw});

  factory ExamMarkEntryDto.fromJson(Map<String, dynamic> json) {
    return ExamMarkEntryDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class TeacherExamMarksResponseDto {
  const TeacherExamMarksResponseDto({
    required this.items,
    this.pagination,
  });

  factory TeacherExamMarksResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TeacherExamMarksResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          ExamMarkEntryDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<ExamMarkEntryDto> items;
  final PaginationDto? pagination;
}

class TeacherTimetableResponseDto {
  const TeacherTimetableResponseDto({required this.raw});

  factory TeacherTimetableResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TeacherTimetableResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class TeacherLeaveRequestDto {
  const TeacherLeaveRequestDto({required this.raw});

  factory TeacherLeaveRequestDto.fromJson(Map<String, dynamic> json) {
    return TeacherLeaveRequestDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class TeacherLeaveResponseDto {
  const TeacherLeaveResponseDto({
    required this.items,
    this.pagination,
  });

  factory TeacherLeaveResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TeacherLeaveResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          TeacherLeaveRequestDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<TeacherLeaveRequestDto> items;
  final PaginationDto? pagination;
}

class TeacherLeaveBalanceResponseDto {
  const TeacherLeaveBalanceResponseDto({required this.raw});

  factory TeacherLeaveBalanceResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TeacherLeaveBalanceResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class MessageThreadDto {
  const MessageThreadDto({required this.raw});

  factory MessageThreadDto.fromJson(Map<String, dynamic> json) {
    return MessageThreadDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

/// TCH-9 — the caller's OWN staff attendance history. The server wraps its
/// `{ month, days, summary, today, yesterday }` payload in the standard API
/// envelope; the mapper reads [raw] directly.
class MyAttendanceHistoryDto {
  const MyAttendanceHistoryDto({required this.raw});

  factory MyAttendanceHistoryDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return MyAttendanceHistoryDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class TeacherMessagesResponseDto {
  const TeacherMessagesResponseDto({
    required this.items,
    this.pagination,
  });

  factory TeacherMessagesResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TeacherMessagesResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          MessageThreadDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<MessageThreadDto> items;
  final PaginationDto? pagination;
}
