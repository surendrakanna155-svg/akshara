import '../../attendance/attendance_office_models.dart';
import '../interfaces/attendance_office_repository.dart';
import '../repository_query.dart';

/// In-memory OFFICE / ADMIN attendance reads for demo/QA mode. Deterministic so
/// widget tests and the demo persona see stable data. Read-only.
class MockAttendanceOfficeRepository implements AttendanceOfficeRepository {
  const MockAttendanceOfficeRepository();

  static const _classLabels = ['8-A', '8-B', '9-A', '10-A'];

  static const _register = <_MockStudent>[
    _MockStudent('stu_8a_01', 'Arjun Patel', '1', 'present'),
    _MockStudent('stu_8a_02', 'Bhavya Reddy', '2', 'present'),
    _MockStudent('stu_8a_03', 'Chetan Kumar', '3', 'absent'),
    _MockStudent('stu_8a_04', 'Divya Sharma', '4', 'late'),
    _MockStudent('stu_8a_05', 'Esha Nair', '5', 'present'),
    _MockStudent('stu_8a_06', 'Farhan Ali', '6', 'excused'),
    _MockStudent('stu_8a_07', 'Gauri Iyer', '7', 'absent'),
    _MockStudent('stu_8a_08', 'Harsh Verma', '8', 'present'),
  ];

  @override
  Future<List<AttendanceRegisterEntry>> fetchRegister({
    required RepositoryQuery query,
    required String classLabel,
    required DateTime date,
  }) async {
    return _register
        .map((s) => AttendanceRegisterEntry(
              studentId: s.id,
              name: s.name,
              classLabel: classLabel,
              mark: _capitalize(s.mark),
              roll: s.roll,
            ))
        .toList(growable: false);
  }

  @override
  Future<MonthlyRegister> fetchMonthlyRegister({
    required RepositoryQuery query,
    required String classLabel,
    required String month,
  }) async {
    final dayCount = _daysInMonth(month);
    final students = <MonthlyRegisterStudent>[];
    for (final s in _register) {
      final marks = <int, String>{};
      var present = 0;
      var marked = 0;
      for (var day = 1; day <= dayCount; day++) {
        // Skip weekends (deterministic pseudo-calendar): mark Mon-Fri only.
        final weekday = ((day - 1) % 7);
        if (weekday >= 5) continue;
        marked++;
        // Deterministic pattern seeded by roll + day.
        final seed = (int.parse(s.roll) * 7 + day) % 10;
        final code = seed == 0
            ? 'A'
            : seed == 1
                ? 'L'
                : seed == 2
                    ? 'E'
                    : 'P';
        marks[day] = code;
        if (code == 'P' || code == 'L') present++;
      }
      students.add(MonthlyRegisterStudent(
        studentId: s.id,
        name: s.name,
        classLabel: classLabel,
        marks: marks,
        presentDays: present,
        markedDays: marked,
        percentPresent: marked == 0 ? 0 : ((present / marked) * 100).round(),
        roll: s.roll,
      ));
    }
    return MonthlyRegister(
      classLabel: classLabel,
      month: month,
      dayCount: dayCount,
      students: students,
    );
  }

  @override
  Future<List<PendingAttendanceClass>> fetchPending({
    required RepositoryQuery query,
    required DateTime date,
  }) async {
    return [
      PendingAttendanceClass(
        classLabel: '9-A',
        status: 'draft',
        takenBy: 'teacher_9a',
        teacherName: 'Ms. Rao',
        lastSavedAt: date.subtract(const Duration(hours: 2)),
      ),
      const PendingAttendanceClass(
        classLabel: '10-A',
        status: 'missing',
        teacherName: 'Mr. Khan',
      ),
    ];
  }

  @override
  Future<List<ConsecutiveAbsenceStudent>> fetchConsecutiveAbsences({
    required RepositoryQuery query,
    int days = 3,
  }) async {
    return [
      ConsecutiveAbsenceStudent(
        studentId: 'stu_8a_03',
        name: 'Chetan Kumar',
        classLabel: '8-A',
        consecutiveDays: days,
        roll: '3',
        lastAbsentDate: DateTime.now(),
      ),
      ConsecutiveAbsenceStudent(
        studentId: 'stu_8a_07',
        name: 'Gauri Iyer',
        classLabel: '8-A',
        consecutiveDays: days,
        roll: '7',
        lastAbsentDate: DateTime.now(),
      ),
    ];
  }

  @override
  Future<List<ShortAttendanceStudent>> fetchShortAttendance({
    required RepositoryQuery query,
    int threshold = 75,
    int windowDays = 30,
  }) async {
    const rows = [
      ShortAttendanceStudent(
        studentId: 'stu_8a_03',
        name: 'Chetan Kumar',
        classLabel: '8-A',
        presentDays: 11,
        markedDays: 22,
        percentPresent: 50,
        roll: '3',
      ),
      ShortAttendanceStudent(
        studentId: 'stu_8a_07',
        name: 'Gauri Iyer',
        classLabel: '8-A',
        presentDays: 14,
        markedDays: 22,
        percentPresent: 64,
        roll: '7',
      ),
      ShortAttendanceStudent(
        studentId: 'stu_8a_06',
        name: 'Farhan Ali',
        classLabel: '8-A',
        presentDays: 16,
        markedDays: 22,
        percentPresent: 73,
        roll: '6',
      ),
    ];
    return rows.where((r) => r.percentPresent < threshold).toList(growable: false);
  }

  /// Class labels the office screen can filter on (demo/QA helper).
  static List<String> get classLabels => _classLabels;

  static String _capitalize(String mark) =>
      mark.isEmpty ? mark : mark[0].toUpperCase() + mark.substring(1);

  static int _daysInMonth(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return 31;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) return 31;
    return DateTime(y, m + 1, 0).day;
  }
}

class _MockStudent {
  const _MockStudent(this.id, this.name, this.roll, this.mark);
  final String id;
  final String name;
  final String roll;
  final String mark;
}
