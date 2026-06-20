import 'package:flutter/foundation.dart';

enum TimetableStatus { draft, validated, published, archived }

enum TimetableConflictType { teacher, section, room }

extension TimetableStatusApi on TimetableStatus {
  static TimetableStatus? fromApi(String value) {
    for (final status in TimetableStatus.values) {
      if (status.name == value) return status;
    }
    return null;
  }
}

@immutable
class TimetableSummary {
  const TimetableSummary({
    required this.academicYearId,
    required this.totalTimetables,
    required this.draftCount,
    required this.validatedCount,
    required this.publishedCount,
    required this.conflictCount,
    required this.gapCount,
    required this.overloadedTeacherCount,
  });

  final String academicYearId;
  final int totalTimetables;
  final int draftCount;
  final int validatedCount;
  final int publishedCount;
  final int conflictCount;
  final int gapCount;
  final int overloadedTeacherCount;
}

@immutable
class TimetableEntry {
  const TimetableEntry({
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

  final String id;
  final String academicYearId;
  final String sectionId;
  final TimetableStatus status;
  final int version;
  final int periodsPerDay;
  final int daysPerWeek;
  final DateTime updatedAt;
  final DateTime? publishedAt;
}

@immutable
class TimetablePeriod {
  const TimetablePeriod({
    required this.id,
    required this.timetableId,
    required this.dayOfWeek,
    required this.periodNumber,
    required this.subjectLabel,
    required this.roomLabel,
    this.teacherId,
  });

  final String id;
  final String timetableId;
  final int dayOfWeek;
  final int periodNumber;
  final String subjectLabel;
  final String roomLabel;
  final String? teacherId;
}

@immutable
class TimetableDetail {
  const TimetableDetail({
    required this.timetable,
    required this.periods,
  });

  final TimetableEntry timetable;
  final List<TimetablePeriod> periods;
}

@immutable
class TimetableConflict {
  const TimetableConflict({
    required this.type,
    required this.message,
    required this.dayOfWeek,
    required this.periodNumber,
    required this.entityId,
  });

  final TimetableConflictType type;
  final String message;
  final int dayOfWeek;
  final int periodNumber;
  final String entityId;
}

@immutable
class TeacherWorkloadEntry {
  const TeacherWorkloadEntry({
    required this.teacherId,
    required this.teacherName,
    required this.periodCount,
    required this.isOverloaded,
  });

  final String teacherId;
  final String teacherName;
  final int periodCount;
  final bool isOverloaded;
}

@immutable
class TimetableValidationResult {
  const TimetableValidationResult({
    required this.valid,
    required this.conflictCount,
    required this.gapCount,
    required this.conflicts,
  });

  final bool valid;
  final int conflictCount;
  final int gapCount;
  final List<TimetableConflict> conflicts;
}

@immutable
class TimetableConflictsBundle {
  const TimetableConflictsBundle({
    required this.conflicts,
    required this.recommendations,
  });

  final List<TimetableConflict> conflicts;
  final List<String> recommendations;
}

@immutable
class GenerateTimetableRequest {
  const GenerateTimetableRequest({
    required this.academicYearId,
    this.sectionId,
    this.periodsPerDay = 6,
    this.daysPerWeek = 5,
  });

  final String academicYearId;
  final String? sectionId;
  final int periodsPerDay;
  final int daysPerWeek;
}

@immutable
class MoveTimetablePeriodRequest {
  const MoveTimetablePeriodRequest({
    required this.periodId,
    required this.targetDayOfWeek,
    required this.targetPeriodNumber,
    this.roomLabel,
  });

  final String periodId;
  final int targetDayOfWeek;
  final int targetPeriodNumber;
  final String? roomLabel;
}

@immutable
class ReassignPeriodTeacherRequest {
  const ReassignPeriodTeacherRequest({
    required this.periodId,
    required this.teacherId,
  });

  final String periodId;
  final String teacherId;
}
