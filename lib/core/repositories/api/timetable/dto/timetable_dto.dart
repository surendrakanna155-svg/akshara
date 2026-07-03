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

/// One resolved/created substitution row. Tolerates BOTH the camelCase
/// `ResolvedSubstitution` shape from the list endpoint and the snake_case
/// `SubstitutionRow` shape returned by create/delete.
class TimetableSubstitutionDto {
  TimetableSubstitutionDto({
    required this.id,
    required this.periodId,
    required this.subDate,
    this.originalTeacherId,
    this.substituteTeacherId,
    this.reason = '',
    this.sectionId,
    this.dayOfWeek,
    this.periodNumber,
    this.subjectLabel,
    this.roomLabel,
  });

  factory TimetableSubstitutionDto.fromJson(Map<String, dynamic> json) {
    String? str(String camel, String snake) =>
        (json[camel] ?? json[snake]) as String?;
    int? intOf(String camel, String snake) =>
        (json[camel] ?? json[snake]) as int?;
    return TimetableSubstitutionDto(
      id: json['id'] as String? ?? '',
      periodId: str('periodId', 'period_id') ?? '',
      subDate: str('subDate', 'sub_date') ?? '',
      originalTeacherId: str('originalTeacherId', 'original_teacher_id'),
      substituteTeacherId: str('substituteTeacherId', 'substitute_teacher_id'),
      reason: json['reason'] as String? ?? '',
      sectionId: str('sectionId', 'section_id'),
      dayOfWeek: intOf('dayOfWeek', 'day_of_week'),
      periodNumber: intOf('periodNumber', 'period_number'),
      subjectLabel: str('subjectLabel', 'subject_label'),
      roomLabel: str('roomLabel', 'room_label'),
    );
  }

  final String id;
  final String periodId;
  final String subDate;
  final String? originalTeacherId;
  final String? substituteTeacherId;
  final String reason;
  final String? sectionId;
  final int? dayOfWeek;
  final int? periodNumber;
  final String? subjectLabel;
  final String? roomLabel;
}

class TimetableTeacherOnLeaveDto {
  TimetableTeacherOnLeaveDto({
    required this.teacherId,
    this.fromDate,
    this.toDate,
    this.reason = '',
  });

  factory TimetableTeacherOnLeaveDto.fromJson(Map<String, dynamic> json) {
    return TimetableTeacherOnLeaveDto(
      teacherId: (json['teacherId'] ?? json['teacher_id']) as String? ?? '',
      fromDate: (json['fromDate'] ?? json['from_date']) as String?,
      toDate: (json['toDate'] ?? json['to_date']) as String?,
      reason: json['reason'] as String? ?? '',
    );
  }

  final String teacherId;
  final String? fromDate;
  final String? toDate;
  final String reason;
}

class DailySubstitutionsDto {
  DailySubstitutionsDto({
    required this.date,
    required this.substitutions,
    required this.onLeave,
  });

  factory DailySubstitutionsDto.fromJson(Map<String, dynamic> json) {
    final rawSubs = json['substitutions'] as List<dynamic>? ?? const [];
    final rawLeave = json['onLeave'] as List<dynamic>? ?? const [];
    return DailySubstitutionsDto(
      date: json['date'] as String? ?? '',
      substitutions: rawSubs
          .map((s) => TimetableSubstitutionDto.fromJson(s as Map<String, dynamic>))
          .toList(),
      onLeave: rawLeave
          .map((l) => TimetableTeacherOnLeaveDto.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }

  final String date;
  final List<TimetableSubstitutionDto> substitutions;
  final List<TimetableTeacherOnLeaveDto> onLeave;
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
