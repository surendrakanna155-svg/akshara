import 'daily_timetable_engine.dart';

/// Holds today's class grid, who's on leave, and the resolved (substituted)
/// timetable. Seeded with a small school grid so the auto-substitution is
/// demonstrable end-to-end.
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

  final Set<String> _onLeave = {};
  List<ScheduledPeriod>? _resolved;

  Set<String> get onLeave => Set.unmodifiable(_onLeave);

  void setOnLeave(String teacherId, bool isOnLeave) {
    if (isOnLeave) {
      _onLeave.add(teacherId);
    } else {
      _onLeave.remove(teacherId);
    }
    _resolved = null; // recompute on next read
  }

  /// Runs the substitution rules for today and caches the result.
  List<ScheduledPeriod> prepareToday() {
    final resolved = DailyTimetableEngine.assignSubstitutes(
      grid: _seedGrid(),
      teacherIdsOnLeave: _onLeave,
      teachers: teachers,
    );
    _resolved = resolved;
    return resolved;
  }

  List<ScheduledPeriod> resolved() => _resolved ?? prepareToday();

  void overrideAssignment({
    required String periodId,
    required String classLabel,
    required TimetableTeacher teacher,
  }) {
    _resolved = DailyTimetableEngine.overrideAssignment(
      grid: resolved(),
      periodId: periodId,
      classLabel: classLabel,
      teacher: teacher,
    );
  }

  /// Today's periods for one teacher (including periods they're covering).
  List<ScheduledPeriod> forTeacher(String teacherId) =>
      resolved().where((p) => p.teacherId == teacherId).toList();

  void reset() {
    _onLeave.clear();
    _resolved = null;
  }
}
