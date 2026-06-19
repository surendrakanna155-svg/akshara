import 'package:akshara_erp/core/timetable/daily_timetable_engine.dart';
import 'package:akshara_erp/core/timetable/mock_daily_timetable_store.dart';
import 'package:akshara_erp/features/hr/hr_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final store = MockDailyTimetableStore.instance;
  const priya = 'HR-EMP-101';
  const patel = 'HR-EMP-103';

  setUp(store.reset);

  test('no one on leave → no substitutes', () {
    store.applyLeave({});
    expect(store.resolved().any((p) => p.isSubstitute), isFalse);
  });

  test('an on-leave teacher (from approved leave) is auto-covered', () {
    store.applyLeave({priya});
    final p1 = store
        .resolved()
        .firstWhere((p) => p.periodId == 'p1' && p.classLabel == '8-A');
    expect(p1.isSubstitute, isTrue);
    expect(p1.teacherId, 'HR-EMP-102'); // Rao free in P1 and teaches Maths
    expect(p1.originalTeacherName, 'Priya Sharma');
  });

  test('override persists across recompute (leave change)', () {
    store.applyLeave({priya});
    store.overrideAssignment(
      periodId: 'p1',
      classLabel: '8-A',
      teacher: const TimetableTeacher(id: patel, name: 'Mr. Patel'),
    );
    expect(
      store.resolved().firstWhere((p) => p.periodId == 'p1' && p.classLabel == '8-A').teacherId,
      patel,
    );
    // Re-applying leave (e.g. date change) keeps the override.
    store.applyLeave({priya});
    expect(
      store.resolved().firstWhere((p) => p.periodId == 'p1' && p.classLabel == '8-A').teacherId,
      patel,
    );
  });
}
