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

/// Over / under / balanced classification for the unified workload rollup, in
/// the exact vocabulary the backend uses (`workload_rollup.ts`).
enum TeacherWorkloadStatus { over, under, balanced }

extension TeacherWorkloadStatusApi on TeacherWorkloadStatus {
  static TeacherWorkloadStatus fromApi(String value) {
    for (final status in TeacherWorkloadStatus.values) {
      if (status.name == value) return status;
    }
    return TeacherWorkloadStatus.balanced;
  }
}

/// One teacher's row in the unified per-teacher workload rollup (roadmap gap #9).
/// Unlike [TeacherWorkloadEntry] (a flat period count) this carries the populated
/// [sections] + [subjectIds] and the over/under/balanced [status].
@immutable
class TeacherWorkloadRollup {
  const TeacherWorkloadRollup({
    required this.teacherId,
    required this.teacherName,
    required this.periodCount,
    required this.sections,
    required this.subjectIds,
    required this.status,
    required this.isOverloaded,
  });

  final String teacherId;
  final String teacherName;

  /// Scheduled periods per week (canonical: academic_timetable_periods).
  final int periodCount;

  /// DISTINCT sections this teacher is scheduled to teach.
  final List<String> sections;

  /// DISTINCT subjects: union of scheduled subject labels + assignment catalog.
  final List<String> subjectIds;

  final TeacherWorkloadStatus status;
  final bool isOverloaded;
}

/// School aggregate for the unified workload rollup.
@immutable
class WorkloadRollupSummary {
  const WorkloadRollupSummary({
    required this.totalTeachers,
    required this.overloaded,
    required this.underloaded,
    required this.balanced,
    required this.avgPeriods,
  });

  final int totalTeachers;
  final int overloaded;
  final int underloaded;
  final int balanced;

  /// Mean scheduled periods across teachers (0 when there are no teachers).
  final double avgPeriods;

  static const empty = WorkloadRollupSummary(
    totalTeachers: 0,
    overloaded: 0,
    underloaded: 0,
    balanced: 0,
    avgPeriods: 0,
  );
}

/// The unified per-teacher workload rollup for a school + academic year: the
/// per-teacher rows plus the school aggregate. Honest empty: [teachers] is `[]`
/// and [summary] is all-zero when no timetable exists for the year.
@immutable
class WorkloadRollup {
  const WorkloadRollup({
    required this.teachers,
    required this.summary,
  });

  final List<TeacherWorkloadRollup> teachers;
  final WorkloadRollupSummary summary;

  static const empty = WorkloadRollup(
    teachers: [],
    summary: WorkloadRollupSummary.empty,
  );
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

/// A dated cover overlay on a published period: "for THIS period, on THIS date,
/// [substituteTeacher] stands in for [originalTeacher]". Resolved per-date by the
/// backend (`academic_timetable_substitutions`) — never edits the base grid.
@immutable
class TimetableSubstitution {
  const TimetableSubstitution({
    required this.id,
    required this.periodId,
    required this.subDate,
    this.originalTeacherId,
    this.originalTeacherName,
    this.substituteTeacherId,
    this.substituteTeacherName,
    this.reason = '',
    this.status = 'assigned',
    this.sectionId,
    this.dayOfWeek,
    this.periodNumber,
    this.subjectLabel,
    this.roomLabel,
  });

  final String id;
  final String periodId;

  /// The date this cover applies to (YYYY-MM-DD).
  final String subDate;

  final String? originalTeacherId;
  final String? originalTeacherName;
  final String? substituteTeacherId;
  final String? substituteTeacherName;
  final String reason;

  /// Lifecycle marker — 'assigned' for an active cover.
  final String status;

  // Period context resolved server-side (list endpoint only).
  final String? sectionId;
  final int? dayOfWeek;
  final int? periodNumber;
  final String? subjectLabel;
  final String? roomLabel;
}

/// A teacher derived server-side as on approved leave for a date.
@immutable
class TimetableTeacherOnLeave {
  const TimetableTeacherOnLeave({
    required this.teacherId,
    this.fromDate,
    this.toDate,
    this.reason = '',
  });

  final String teacherId;
  final String? fromDate;
  final String? toDate;
  final String reason;
}

/// The resolved cover picture for a single date: active substitutions plus the
/// server-derived on-leave teachers.
@immutable
class DailySubstitutionsBundle {
  const DailySubstitutionsBundle({
    required this.date,
    required this.substitutions,
    required this.onLeave,
  });

  final String date;
  final List<TimetableSubstitution> substitutions;
  final List<TimetableTeacherOnLeave> onLeave;

  static const empty = DailySubstitutionsBundle(
    date: '',
    substitutions: [],
    onLeave: [],
  );
}

@immutable
class CreateSubstitutionRequest {
  const CreateSubstitutionRequest({
    required this.periodId,
    required this.subDate,
    required this.substituteTeacherId,
    this.reason,
  });

  final String periodId;
  final String subDate;
  final String substituteTeacherId;
  final String? reason;
}

/// Thrown when the backend rejects a substitution because the chosen substitute
/// is already teaching that slot on that date (409 SUBSTITUTE_BUSY).
class SubstituteBusyException implements Exception {
  const SubstituteBusyException([this.message = 'That teacher is already teaching this period.']);

  final String message;

  @override
  String toString() => 'SubstituteBusyException: $message';
}
