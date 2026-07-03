import 'package:akshara_erp/core/repositories/interfaces/timetable_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/teaching/teacher_assignment_registry.dart';
import 'package:akshara_erp/core/timetable/mock_daily_timetable_store.dart';
import 'package:akshara_erp/features/academics/timetable/substitutions/daily_substitutions_provider.dart';
import 'package:akshara_erp/features/academics/timetable/timetable_models.dart';
import 'package:akshara_erp/features/teacher/communication/teacher_teaching_context_provider.dart';
import 'package:akshara_erp/features/teacher/timetable/teacher_today_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

/// Fake repo that returns a single server-resolved cover for HR-EMP-102.
class _CoverRepo implements TimetableRepository {
  @override
  Future<DailySubstitutionsBundle> listSubstitutions({
    required RepositoryQuery query,
    required String date,
  }) async {
    return DailySubstitutionsBundle(
      date: date,
      substitutions: const [
        TimetableSubstitution(
          id: 'sub_cover_1',
          periodId: 'period_1',
          subDate: '2026-07-03',
          substituteTeacherId: 'HR-EMP-102',
          periodNumber: 2,
          subjectLabel: 'Science',
        ),
        TimetableSubstitution(
          id: 'sub_cover_2',
          periodId: 'period_2',
          subDate: '2026-07-03',
          substituteTeacherId: 'HR-EMP-999', // someone else's cover
          periodNumber: 3,
          subjectLabel: 'English',
        ),
      ],
      onLeave: const [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

void main() {
  setUp(MockDailyTimetableStore.instance.reset);

  test("a covering teacher sees the assigned class in today's schedule", () {
    // Priya on leave → Rao covers her 8-A Period 1 Maths.
    MockDailyTimetableStore.instance.applyLeave({'HR-EMP-101'});

    final container = createMobileProviderTestContainer(overrides: [
      teacherTeachingContextOverrideProvider.overrideWith(
        (ref) => TeacherAssignmentRegistry.resolveContext(
          teacherId: TeacherAssignmentRegistry.mrsRaoId, // HR-EMP-102
          teacherName: 'Mrs. Rao',
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final today = container.read(teacherTodayScheduleProvider);
    final covering = today.where((p) => p.isSubstitute).toList();
    expect(
      covering.any((p) => p.classLabel == '8-A' && p.subject == 'Mathematics'),
      isTrue,
    );
  });

  test('teacherTodayCoverProvider surfaces only the logged-in teacher\'s '
      'server-resolved cover', () async {
    final container = createMobileProviderTestContainer(overrides: [
      timetableRepositoryProvider.overrideWithValue(_CoverRepo()),
      teacherTeachingContextOverrideProvider.overrideWith(
        (ref) => TeacherAssignmentRegistry.resolveContext(
          teacherId: TeacherAssignmentRegistry.mrsRaoId, // HR-EMP-102
          teacherName: 'Mrs. Rao',
        ),
      ),
    ]);
    addTearDown(container.dispose);

    // Keep the cover provider subscribed, then await the backing list future.
    final sub = container.listen(teacherTodayCoverProvider, (_, __) {});
    addTearDown(sub.close);
    await container.read(dailySubstitutionsProvider.future);

    final cover = container.read(teacherTodayCoverProvider);
    final subs = cover.value ?? const <TimetableSubstitution>[];
    expect(subs, hasLength(1));
    expect(subs.single.substituteTeacherId, 'HR-EMP-102');
    expect(subs.single.periodNumber, 2);
  });
}
