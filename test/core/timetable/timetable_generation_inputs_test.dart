import 'package:akshara_erp/core/repositories/mock/mock_timetable_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:akshara_erp/core/teaching/teacher_assignment_registry.dart';
import 'package:akshara_erp/core/timetable/class_teacher_assignments.dart';
import 'package:akshara_erp/core/timetable/timetable_generation_inputs.dart';
import 'package:akshara_erp/core/timetable/timetable_generator.dart';
import 'package:akshara_erp/features/academics/timetable/timetable_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ClassTeacherAssignmentStore.instance.reset());
  tearDown(() => ClassTeacherAssignmentStore.instance.reset());

  group('class teacher store', () {
    test('seeds 8-A to Priya and 8-B to Mr. Patel', () {
      final store = ClassTeacherAssignmentStore.instance;
      expect(store.teacherFor('8-A'), TeacherAssignmentRegistry.priyaSharmaId);
      expect(store.teacherFor('8-B'), TeacherAssignmentRegistry.mrPatelId);
    });

    test('assign overrides and clear removes', () {
      final store = ClassTeacherAssignmentStore.instance;
      store.assign(classLabel: '8-A', teacherId: TeacherAssignmentRegistry.mrsRaoId);
      expect(store.teacherFor('8-A'), TeacherAssignmentRegistry.mrsRaoId);
      store.clear('8-A');
      expect(store.teacherFor('8-A'), isNull);
    });
  });

  group('generation inputs', () {
    test('every curriculum subject has at least one qualified teacher', () {
      final inputs = buildMockGenerationInputs(curriculum: SchoolCurriculum.cbse);
      for (final cls in inputs.classes) {
        for (final spec in cls.subjects) {
          final hasTeacher = inputs.teachers
              .any((t) => t.subjects.contains(spec.subjectName));
          expect(hasTeacher, isTrue,
              reason: 'no teacher for ${spec.subjectName}');
        }
      }
    });

    test('class teachers from the store are carried into the classes', () {
      final inputs = buildMockGenerationInputs(curriculum: SchoolCurriculum.cbse);
      final a = inputs.classes.firstWhere((c) => c.classLabel == '8-A');
      expect(a.classTeacherId, TeacherAssignmentRegistry.priyaSharmaId);
    });

    test('a clash-free grid can be produced from the inputs', () {
      final inputs = buildMockGenerationInputs(curriculum: SchoolCurriculum.cbse);
      final result = generateTimetable(
        classes: inputs.classes,
        teachers: inputs.teachers,
        periodsPerDay: 8,
        daysPerWeek: 6,
      );
      // No subject left unplaced, no class without a class teacher.
      expect(result.warnings, isEmpty, reason: result.warnings.join('\n'));
    });
  });

  group('mock repository generate()', () {
    test('produces real periods with class-teacher first periods', () async {
      final repo = MockTimetableRepository();
      final entries = await repo.generate(
        query: RepositoryQuery.demo,
        request: const GenerateTimetableRequest(
            academicYearId: 'mock-year-current'),
      );
      expect(entries, isNotEmpty);

      final detail = await repo.getTimetable(
        query: RepositoryQuery.demo,
        timetableId: entries.first.id,
      );
      expect(detail.periods, isNotEmpty);

      // Period 1 of each day is taught by the section's class teacher.
      final firsts = detail.periods.where((p) => p.periodNumber == 1);
      expect(firsts, isNotEmpty);
      for (final p in firsts) {
        expect(p.teacherId, TeacherAssignmentRegistry.priyaSharmaId);
      }
    });

    test('a coordinator can reassign a period to another teacher', () async {
      final repo = MockTimetableRepository();
      final entries = await repo.generate(
        query: RepositoryQuery.demo,
        request: const GenerateTimetableRequest(
            academicYearId: 'mock-year-current'),
      );
      final detail = await repo.getTimetable(
        query: RepositoryQuery.demo,
        timetableId: entries.first.id,
      );
      final target = detail.periods.firstWhere((p) => p.periodNumber > 1);
      final updated = await repo.reassignPeriodTeacher(
        query: RepositoryQuery.demo,
        request: ReassignPeriodTeacherRequest(
          periodId: target.id,
          teacherId: TeacherAssignmentRegistry.mrsRaoId,
        ),
      );
      expect(updated.teacherId, TeacherAssignmentRegistry.mrsRaoId);

      // The change persists on the stored grid.
      final after = await repo.getTimetable(
        query: RepositoryQuery.demo,
        timetableId: entries.first.id,
      );
      final reloaded = after.periods.firstWhere((p) => p.id == target.id);
      expect(reloaded.teacherId, TeacherAssignmentRegistry.mrsRaoId);
    });

    test('no teacher is double-booked across sections in a slot', () async {
      final repo = MockTimetableRepository();
      final entries = await repo.generate(
        query: RepositoryQuery.demo,
        request: const GenerateTimetableRequest(
            academicYearId: 'mock-year-current'),
      );
      final all = <TimetablePeriod>[];
      for (final e in entries) {
        final d = await repo.getTimetable(
            query: RepositoryQuery.demo, timetableId: e.id);
        all.addAll(d.periods);
      }
      final seen = <String>{};
      for (final p in all) {
        if (p.teacherId == null) continue;
        final key = '${p.teacherId}|${p.dayOfWeek}|${p.periodNumber}';
        expect(seen.add(key), isTrue,
            reason: 'teacher ${p.teacherId} double-booked at '
                'day ${p.dayOfWeek} period ${p.periodNumber}');
      }
    });
  });
}
