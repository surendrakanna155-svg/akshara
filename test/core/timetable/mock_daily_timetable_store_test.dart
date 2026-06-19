import 'package:akshara_erp/core/timetable/daily_timetable_engine.dart';
import 'package:akshara_erp/core/timetable/mock_daily_timetable_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final store = MockDailyTimetableStore.instance;
  const priya = 'HR-EMP-101';
  const rao = 'HR-EMP-102';
  const patel = 'HR-EMP-103';

  setUp(store.reset);

  test('no one on leave → no substitutes', () {
    final grid = store.prepareToday();
    expect(grid.any((p) => p.isSubstitute), isFalse);
  });

  test('marking a teacher on leave auto-covers their periods', () {
    store.setOnLeave(priya, true);
    final grid = store.prepareToday();

    // Priya's 8-A Period 1 Maths → Rao is the only one free in P1 and teaches Maths.
    final p1 = grid.firstWhere(
        (p) => p.periodId == 'p1' && p.classLabel == '8-A');
    expect(p1.isSubstitute, isTrue);
    expect(p1.teacherId, rao);
    expect(p1.originalTeacherName, 'Priya Sharma');

    // Rao's own day now includes the cover.
    expect(store.forTeacher(rao).any((p) => p.classLabel == '8-A'), isTrue);
  });

  test('coordinator override reassigns a covered period', () {
    store.setOnLeave(priya, true);
    store.prepareToday();
    store.overrideAssignment(
      periodId: 'p1',
      classLabel: '8-A',
      teacher: const TimetableTeacher(id: patel, name: 'Mr. Patel'),
    );
    final p1 = store
        .resolved()
        .firstWhere((p) => p.periodId == 'p1' && p.classLabel == '8-A');
    expect(p1.teacherId, patel);
    expect(p1.originalTeacherName, 'Priya Sharma'); // trail kept
  });

  test('clearing leave removes substitutes', () {
    store.setOnLeave(priya, true);
    store.prepareToday();
    store.setOnLeave(priya, false);
    final grid = store.prepareToday();
    expect(grid.any((p) => p.isSubstitute), isFalse);
  });
}
