import '../../features/hr/hr_models.dart';
import 'daily_timetable_engine.dart';

/// Teachers (employeeIds) with APPROVED leave covering [date]. This is what
/// drives substitution — no one marks attendance/leave on the timetable
/// manually; an approved leave automatically reflects on those dates.
Set<String> teachersOnLeaveForDate(
  List<HrLeaveRequest> leaveRequests,
  DateTime date,
) {
  final day = DateTime(date.year, date.month, date.day);
  final onLeave = <String>{};
  for (final r in leaveRequests) {
    if (r.status != HrLeaveStatus.approved) continue;
    final from = DateTime.tryParse(r.fromDate);
    final to = DateTime.tryParse(r.toDate);
    if (from == null || to == null) continue;
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    if (!day.isBefore(start) && !day.isAfter(end)) {
      onLeave.add(r.employeeId);
    }
  }
  return onLeave;
}

/// Holds the FIXED class grid (set occasionally, not daily) and resolves the
/// substituted timetable for whoever is on leave. Coordinator overrides are
/// kept durably and re-applied on every recompute.
class MockDailyTimetableStore {
  MockDailyTimetableStore._();
  static final MockDailyTimetableStore instance = MockDailyTimetableStore._();

  static const teachers = <TimetableTeacher>[
    TimetableTeacher(id: 'HR-EMP-101', name: 'Priya Sharma',
        subjects: {'Mathematics'}),
    TimetableTeacher(id: 'HR-EMP-103', name: 'Mr. Patel', subjects: {'Science'}),
    TimetableTeacher(id: 'HR-EMP-102', name: 'Mrs. Rao',
        subjects: {'Mathematics', 'English'}),
  ];

  static List<ScheduledPeriod> _seedGrid() => const [
        ScheduledPeriod(periodId: 'p1', periodLabel: 'Period 1',
            classLabel: '8-A', subject: 'Mathematics',
            teacherId: 'HR-EMP-101', teacherName: 'Priya Sharma'),
        ScheduledPeriod(periodId: 'p1', periodLabel: 'Period 1',
            classLabel: '9-B', subject: 'Science',
            teacherId: 'HR-EMP-103', teacherName: 'Mr. Patel'),
        ScheduledPeriod(periodId: 'p2', periodLabel: 'Period 2',
            classLabel: '8-A', subject: 'Science',
            teacherId: 'HR-EMP-103', teacherName: 'Mr. Patel'),
        ScheduledPeriod(periodId: 'p2', periodLabel: 'Period 2',
            classLabel: '9-B', subject: 'English',
            teacherId: 'HR-EMP-102', teacherName: 'Mrs. Rao'),
        ScheduledPeriod(periodId: 'p3', periodLabel: 'Period 3',
            classLabel: '8-A', subject: 'Mathematics',
            teacherId: 'HR-EMP-102', teacherName: 'Mrs. Rao'),
        ScheduledPeriod(periodId: 'p3', periodLabel: 'Period 3',
            classLabel: '9-B', subject: 'Mathematics',
            teacherId: 'HR-EMP-101', teacherName: 'Priya Sharma'),
      ];

  Set<String> _onLeave = {};
  final Map<String, TimetableTeacher> _overrides = {}; // 'periodId|classLabel'
  List<ScheduledPeriod>? _resolved;

  Set<String> get onLeave => Set.unmodifiable(_onLeave);

  /// Set the full on-leave set (e.g. derived from approved leave for a date).
  void applyLeave(Set<String> teacherIdsOnLeave) {
    _onLeave = {...teacherIdsOnLeave};
    _resolved = null;
  }

  List<ScheduledPeriod> _recompute() {
    var grid = DailyTimetableEngine.assignSubstitutes(
      grid: _seedGrid(),
      teacherIdsOnLeave: _onLeave,
      teachers: teachers,
    );
    for (final entry in _overrides.entries) {
      final parts = entry.key.split('|');
      grid = DailyTimetableEngine.overrideAssignment(
        grid: grid,
        periodId: parts[0],
        classLabel: parts[1],
        teacher: entry.value,
      );
    }
    _resolved = grid;
    return grid;
  }

  List<ScheduledPeriod> resolved() => _resolved ?? _recompute();

  void overrideAssignment({
    required String periodId,
    required String classLabel,
    required TimetableTeacher teacher,
  }) {
    _overrides['$periodId|$classLabel'] = teacher;
    _resolved = null;
  }

  /// Today's periods for one teacher (including classes they're covering).
  List<ScheduledPeriod> forTeacher(String teacherId) =>
      resolved().where((p) => p.teacherId == teacherId).toList();

  void reset() {
    _onLeave = {};
    _overrides.clear();
    _resolved = null;
  }
}
