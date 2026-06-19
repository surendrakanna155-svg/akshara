import 'package:akshara_erp/core/timetable/daily_timetable_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const teachers = [
    TimetableTeacher(id: 't_priya', name: 'Priya', subjects: {'Mathematics'}),
    TimetableTeacher(id: 't_patel', name: 'Patel', subjects: {'Science'}),
    TimetableTeacher(id: 't_rao', name: 'Rao', subjects: {'Mathematics', 'English'}),
  ];

  // Period 1: Priya teaches 8-A Maths, Patel teaches 9-B Science.
  // Period 2: Patel teaches 8-A Science. (Priya and Rao free in P2.)
  List<ScheduledPeriod> grid() => const [
        ScheduledPeriod(
          periodId: 'p1',
          periodLabel: 'Period 1',
          classLabel: '8-A',
          subject: 'Mathematics',
          teacherId: 't_priya',
          teacherName: 'Priya',
        ),
        ScheduledPeriod(
          periodId: 'p1',
          periodLabel: 'Period 1',
          classLabel: '9-B',
          subject: 'Science',
          teacherId: 't_patel',
          teacherName: 'Patel',
        ),
        ScheduledPeriod(
          periodId: 'p2',
          periodLabel: 'Period 2',
          classLabel: '8-A',
          subject: 'Science',
          teacherId: 't_patel',
          teacherName: 'Patel',
        ),
      ];

  test('a teacher on leave gets covered by a free, subject-matching teacher', () {
    // Priya on leave → her P1 8-A Maths must be covered. In P1, Patel is busy
    // (9-B), so the only free teacher is Rao — who also teaches Mathematics.
    final result = DailyTimetableEngine.assignSubstitutes(
      grid: grid(),
      teacherIdsOnLeave: {'t_priya'},
      teachers: teachers,
    );
    final covered =
        result.firstWhere((p) => p.periodId == 'p1' && p.classLabel == '8-A');
    expect(covered.isSubstitute, isTrue);
    expect(covered.teacherId, 't_rao');
    expect(covered.originalTeacherName, 'Priya');
    expect(covered.isUnfilled, isFalse);
  });

  test('periods of teachers not on leave are untouched', () {
    final result = DailyTimetableEngine.assignSubstitutes(
      grid: grid(),
      teacherIdsOnLeave: {'t_priya'},
      teachers: teachers,
    );
    final patelP1 =
        result.firstWhere((p) => p.periodId == 'p1' && p.classLabel == '9-B');
    expect(patelP1.isSubstitute, isFalse);
    expect(patelP1.teacherId, 't_patel');
  });

  test('a substitute is never double-booked in the same period', () {
    // Both Priya (P1 8-A) and Patel (P1 9-B) on leave. Only Rao is free in P1,
    // so Rao covers one; the other is left unfilled (no double-booking).
    final result = DailyTimetableEngine.assignSubstitutes(
      grid: grid(),
      teacherIdsOnLeave: {'t_priya', 't_patel'},
      teachers: teachers,
    );
    final p1 = result.where((p) => p.periodId == 'p1').toList();
    final covered = p1.where((p) => p.teacherId == 't_rao').toList();
    final unfilled = p1.where((p) => p.isUnfilled).toList();
    expect(covered, hasLength(1));
    expect(unfilled, hasLength(1));
  });

  test('coordinator can override an assignment', () {
    var result = DailyTimetableEngine.assignSubstitutes(
      grid: grid(),
      teacherIdsOnLeave: {'t_priya'},
      teachers: teachers,
    );
    result = DailyTimetableEngine.overrideAssignment(
      grid: result,
      periodId: 'p1',
      classLabel: '8-A',
      teacher: const TimetableTeacher(id: 't_patel', name: 'Patel'),
    );
    final p =
        result.firstWhere((x) => x.periodId == 'p1' && x.classLabel == '8-A');
    expect(p.teacherId, 't_patel');
    expect(p.originalTeacherName, 'Priya'); // trail preserved
  });
}
