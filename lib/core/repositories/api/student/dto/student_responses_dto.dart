import '../../admissions/dto/api_envelope_dto.dart';
import '../../admissions/dto/pagination_dto.dart';

class StudentDashboardDto {
  const StudentDashboardDto({required this.raw});

  factory StudentDashboardDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return StudentDashboardDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class StudentAttendanceResponseDto {
  const StudentAttendanceResponseDto({required this.raw});

  factory StudentAttendanceResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return StudentAttendanceResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class StudentHomeworkItemDto {
  const StudentHomeworkItemDto({required this.raw});

  factory StudentHomeworkItemDto.fromJson(Map<String, dynamic> json) {
    return StudentHomeworkItemDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class StudentHomeworkResponseDto {
  const StudentHomeworkResponseDto({
    required this.items,
    this.pagination,
  });

  factory StudentHomeworkResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return StudentHomeworkResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          StudentHomeworkItemDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<StudentHomeworkItemDto> items;
  final PaginationDto? pagination;
}

class StudentExamsResponseDto {
  const StudentExamsResponseDto({required this.raw});

  factory StudentExamsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return StudentExamsResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class StudentTimetableResponseDto {
  const StudentTimetableResponseDto({required this.raw});

  factory StudentTimetableResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return StudentTimetableResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class StudentNoticeDto {
  const StudentNoticeDto({required this.raw});

  factory StudentNoticeDto.fromJson(Map<String, dynamic> json) {
    return StudentNoticeDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class StudentNoticesResponseDto {
  const StudentNoticesResponseDto({
    required this.items,
    this.pagination,
  });

  factory StudentNoticesResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return StudentNoticesResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          StudentNoticeDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<StudentNoticeDto> items;
  final PaginationDto? pagination;
}

class StudentProfileResponseDto {
  const StudentProfileResponseDto({required this.raw});

  factory StudentProfileResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return StudentProfileResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
