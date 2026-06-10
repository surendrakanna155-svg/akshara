import '../../admissions/dto/api_envelope_dto.dart';

Map<String, dynamic> parseTimetableEnvelope(Map<String, dynamic> json) {
  return ApiEnvelopeDto.fromJson(json).data ?? const {};
}

List<Map<String, dynamic>> parseTimetableItems(Map<String, dynamic> json) {
  final data = parseTimetableEnvelope(json);
  final items = data['items'] as List<dynamic>? ?? const [];
  return items.map((item) => item as Map<String, dynamic>).toList();
}

class TimetableSummaryDto {
  TimetableSummaryDto({
    required this.academicYearId,
    required this.totalTimetables,
    required this.draftCount,
    required this.validatedCount,
    required this.publishedCount,
    required this.conflictCount,
    required this.gapCount,
    required this.overloadedTeacherCount,
  });

  factory TimetableSummaryDto.fromJson(Map<String, dynamic> json) {
    return TimetableSummaryDto(
      academicYearId: json['academicYearId'] as String? ?? '',
      totalTimetables: json['totalTimetables'] as int? ?? 0,
      draftCount: json['draftCount'] as int? ?? 0,
      validatedCount: json['validatedCount'] as int? ?? 0,
      publishedCount: json['publishedCount'] as int? ?? 0,
      conflictCount: json['conflictCount'] as int? ?? 0,
      gapCount: json['gapCount'] as int? ?? 0,
      overloadedTeacherCount: json['overloadedTeacherCount'] as int? ?? 0,
    );
  }

  final String academicYearId;
  final int totalTimetables;
  final int draftCount;
  final int validatedCount;
  final int publishedCount;
  final int conflictCount;
  final int gapCount;
  final int overloadedTeacherCount;
}

class TimetableEntryDto {
  TimetableEntryDto({
    required this.id,
    required this.academicYearId,
    required this.sectionId,
    required this.status,
    required this.version,
    required this.periodsPerDay,
    required this.daysPerWeek,
    required this.updatedAt,
    this.publishedAt,
  });

  factory TimetableEntryDto.fromJson(Map<String, dynamic> json) {
    return TimetableEntryDto(
      id: json['id'] as String? ?? '',
      academicYearId: json['academicYearId'] as String? ?? '',
      sectionId: json['sectionId'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      version: json['version'] as int? ?? 1,
      periodsPerDay: json['periodsPerDay'] as int? ?? 6,
      daysPerWeek: json['daysPerWeek'] as int? ?? 5,
      updatedAt: json['updatedAt'] as String? ?? '',
      publishedAt: json['publishedAt'] as String?,
    );
  }

  final String id;
  final String academicYearId;
  final String sectionId;
  final String status;
  final int version;
  final int periodsPerDay;
  final int daysPerWeek;
  final String updatedAt;
  final String? publishedAt;
}

class TimetablePeriodDto {
  TimetablePeriodDto({
    required this.id,
    required this.timetableId,
    required this.dayOfWeek,
    required this.periodNumber,
    required this.subjectLabel,
    required this.roomLabel,
    this.teacherId,
  });

  factory TimetablePeriodDto.fromJson(Map<String, dynamic> json) {
    return TimetablePeriodDto(
      id: json['id'] as String? ?? '',
      timetableId: json['timetableId'] as String? ?? '',
      dayOfWeek: json['dayOfWeek'] as int? ?? 1,
      periodNumber: json['periodNumber'] as int? ?? 1,
      subjectLabel: json['subjectLabel'] as String? ?? '',
      roomLabel: json['roomLabel'] as String? ?? '',
      teacherId: json['teacherId'] as String?,
    );
  }

  final String id;
  final String timetableId;
  final int dayOfWeek;
  final int periodNumber;
  final String subjectLabel;
  final String roomLabel;
  final String? teacherId;
}

class TeacherWorkloadDto {
  TeacherWorkloadDto({
    required this.teacherId,
    required this.teacherName,
    required this.periodCount,
    required this.isOverloaded,
  });

  factory TeacherWorkloadDto.fromJson(Map<String, dynamic> json) {
    return TeacherWorkloadDto(
      teacherId: json['teacherId'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      periodCount: json['periodCount'] as int? ?? 0,
      isOverloaded: json['isOverloaded'] as bool? ?? false,
    );
  }

  final String teacherId;
  final String teacherName;
  final int periodCount;
  final bool isOverloaded;
}

class TimetableConflictDto {
  TimetableConflictDto({
    required this.type,
    required this.message,
    required this.dayOfWeek,
    required this.periodNumber,
    required this.entityId,
  });

  factory TimetableConflictDto.fromJson(Map<String, dynamic> json) {
    return TimetableConflictDto(
      type: json['type'] as String? ?? 'teacher',
      message: json['message'] as String? ?? '',
      dayOfWeek: json['dayOfWeek'] as int? ?? 1,
      periodNumber: json['periodNumber'] as int? ?? 1,
      entityId: json['entityId'] as String? ?? '',
    );
  }

  final String type;
  final String message;
  final int dayOfWeek;
  final int periodNumber;
  final String entityId;
}

class TimetableValidationResultDto {
  TimetableValidationResultDto({
    required this.valid,
    required this.conflictCount,
    required this.gapCount,
    required this.conflicts,
  });

  factory TimetableValidationResultDto.fromJson(Map<String, dynamic> json) {
    final rawConflicts = json['conflicts'] as List<dynamic>? ?? const [];
    return TimetableValidationResultDto(
      valid: json['valid'] as bool? ?? false,
      conflictCount: json['conflictCount'] as int? ?? 0,
      gapCount: json['gapCount'] as int? ?? 0,
      conflicts: rawConflicts
          .map((c) => TimetableConflictDto.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  final bool valid;
  final int conflictCount;
  final int gapCount;
  final List<TimetableConflictDto> conflicts;
}
