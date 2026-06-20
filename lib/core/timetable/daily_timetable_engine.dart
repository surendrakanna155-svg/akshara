/// Rule-based daily timetable substitution (no AI). Given the day's class grid
/// and which teachers are on leave, it assigns a free teacher to each uncovered
/// period. Deterministic and explainable — same inputs always give the same
/// result. A coordinator/principal can override any assignment afterward.
library;

/// A teacher available to be scheduled / used as a substitute.
class TimetableTeacher {
  const TimetableTeacher({
    required this.id,
    required this.name,
    this.subjects = const {},
  });

  final String id;
  final String name;
  final Set<String> subjects; // subjects this teacher can teach (optional)
}

/// One class period on the day's grid.
class ScheduledPeriod {
  const ScheduledPeriod({
    required this.periodId,
    required this.periodLabel,
    required this.classLabel,
    required this.subject,
    required this.teacherId,
    required this.teacherName,
    this.originalTeacherId,
    this.originalTeacherName,
  });

  final String periodId; // e.g. 'p1' — same id = same time slot across the grid
  final String periodLabel;
  final String classLabel;
  final String subject;

  /// Currently-assigned teacher (a substitute after [assignSubstitutes]).
  final String teacherId;
  final String teacherName;

  /// Set when this period was covered by a substitute.
  final String? originalTeacherId;
  final String? originalTeacherName;

  bool get isSubstitute => originalTeacherId != null;

  /// True when the teacher is on leave and no one could cover it.
  bool get isUnfilled => originalTeacherId != null && teacherId.isEmpty;

  ScheduledPeriod copyWith({
    String? teacherId,
    String? teacherName,
    String? originalTeacherId,
    String? originalTeacherName,
  }) {
    return ScheduledPeriod(
      periodId: periodId,
      periodLabel: periodLabel,
      classLabel: classLabel,
      subject: subject,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      originalTeacherId: originalTeacherId ?? this.originalTeacherId,
      originalTeacherName: originalTeacherName ?? this.originalTeacherName,
    );
  }
}

abstract final class DailyTimetableEngine {
  /// Returns the grid with leave-affected periods reassigned to a free teacher.
  /// "Free" = not on leave and teaching nothing else in that period. Prefers a
  /// teacher who can teach the subject; falls back to any free teacher; leaves
  /// the period unfilled (empty teacher) if no one is free.
  static List<ScheduledPeriod> assignSubstitutes({
    required List<ScheduledPeriod> grid,
    required Set<String> teacherIdsOnLeave,
    required List<TimetableTeacher> teachers,
  }) {
    // Who is busy in each period (from the original grid).
    final busyByPeriod = <String, Set<String>>{};
    for (final p in grid) {
      busyByPeriod.putIfAbsent(p.periodId, () => <String>{}).add(p.teacherId);
    }

    final result = <ScheduledPeriod>[];
    for (final period in grid) {
      if (!teacherIdsOnLeave.contains(period.teacherId)) {
        result.add(period);
        continue;
      }

      final busy = busyByPeriod[period.periodId] ?? const <String>{};
      bool isFree(TimetableTeacher t) =>
          !teacherIdsOnLeave.contains(t.id) &&
          t.id != period.teacherId &&
          !busy.contains(t.id);

      // Prefer a free teacher who can teach the subject; else any free teacher.
      final candidates = teachers.where(isFree).toList()
        ..sort((a, b) => a.name.compareTo(b.name)); // deterministic
      final pick = candidates.firstWhere(
        (t) => t.subjects.contains(period.subject),
        orElse: () => candidates.isEmpty
            ? const TimetableTeacher(id: '', name: '')
            : candidates.first,
      );

      if (pick.id.isEmpty) {
        // No one free — mark unfilled for the coordinator to resolve.
        result.add(period.copyWith(
          teacherId: '',
          teacherName: 'Unfilled — needs cover',
          originalTeacherId: period.teacherId,
          originalTeacherName: period.teacherName,
        ));
      } else {
        // Reserve the substitute so they aren't double-booked this period.
        busyByPeriod[period.periodId]!.add(pick.id);
        result.add(period.copyWith(
          teacherId: pick.id,
          teacherName: pick.name,
          originalTeacherId: period.teacherId,
          originalTeacherName: period.teacherName,
        ));
      }
    }
    return result;
  }

  /// Coordinator/principal override: force [periodId] for [classLabel] onto a
  /// chosen teacher, keeping the original-teacher trail.
  static List<ScheduledPeriod> overrideAssignment({
    required List<ScheduledPeriod> grid,
    required String periodId,
    required String classLabel,
    required TimetableTeacher teacher,
  }) {
    return [
      for (final p in grid)
        if (p.periodId == periodId && p.classLabel == classLabel)
          p.copyWith(
            teacherId: teacher.id,
            teacherName: teacher.name,
            originalTeacherId: p.originalTeacherId ?? p.teacherId,
            originalTeacherName: p.originalTeacherName ?? p.teacherName,
          )
        else
          p,
    ];
  }
}
