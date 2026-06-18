import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/teaching/teacher_assignment_registry.dart';
import 'package:akshara_erp/features/teacher/communication/teacher_teaching_context_provider.dart';
import 'package:akshara_erp/features/teacher/exams/exam_models.dart';
import 'package:akshara_erp/features/teacher/exams/teacher_exams_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

/// Default persona for these tests: Priya Sharma (Maths 8-A + 9-B). Pinning the
/// teaching context keeps exam scoping deterministic without auth/prefs setup.
final _priyaContext = teacherTeachingContextOverrideProvider.overrideWith(
  (ref) => TeacherAssignmentRegistry.resolveContext(
    teacherId: TeacherAssignmentRegistry.priyaSharmaId,
    teacherName: 'Priya Sharma',
  ),
);

ProviderContainer _container() =>
    createMobileProviderTestContainer(overrides: [_priyaContext]);

Future<void> _awaitTeacherExams(ProviderContainer container) async {
  await container.read(teacherUpcomingExamsFutureProvider.future);
  await container.read(teacherExamMarksFutureProvider.future);
  await container.read(teacherMarksExamOptionsProvider.future);
}

void main() {
  group('teacherExams providers', () {
    test('teacherExamsProvider exposes upcoming exams and marks', () async {
      final container = _container();
      addTearDown(container.dispose);

      await _awaitTeacherExams(container);
      final data = container.read(teacherExamsProvider);

      // Scoped to Priya's assignments: the seeded Maths 8-A session shows;
      // Mr. Patel's Science 8-A session does not.
      expect(data.upcomingExams, hasLength(1));
      expect(data.upcomingExams.single.subject, 'Mathematics');
      expect(data.markEntries, isNotEmpty);
      expect(data.classAveragePercent, greaterThan(0));
    });

    test('teacherExamSectionProvider switches active section', () async {
      final container = _container();
      addTearDown(container.dispose);

      container.read(teacherExamSectionProvider.notifier).state =
          TeacherExamSection.results;
      final section = container.read(teacherExamSectionProvider);

      expect(section, TeacherExamSection.results);
    });

    test('teacherExamsEmptyProvider clears exam data', () async {
      final container = _container();
      addTearDown(container.dispose);

      container.read(teacherExamsEmptyProvider.notifier).state = true;
      final data = container.read(teacherExamsProvider);

      expect(data.upcomingExams, isEmpty);
      expect(data.markEntries, isEmpty);
      expect(data.classAveragePercent, 0);
    });

    test('mark entries include pending marks for entry', () async {
      final container = _container();
      addTearDown(container.dispose);

      await _awaitTeacherExams(container);
      final pending = container
          .read(teacherExamsProvider)
          .markEntries
          .where((entry) => entry.marksObtained == null);

      expect(pending, isNotEmpty);
    });
  });

  group('Slice 3 — marks entry wiring', () {
    setUp(() {
      ExamAdministrationStore.instance.reset();
    });

    test('getMarksEntryExams returns only marksEntry/processed exams', () async {
      final container = _container();
      addTearDown(container.dispose);

      final options =
          await container.read(teacherMarksExamOptionsProvider.future);

      for (final opt in options) {
        expect(
          opt.phaseLabel == 'marksEntry' || opt.phaseLabel == 'processed',
          isTrue,
          reason: '${opt.title} has unexpected phase ${opt.phaseLabel}',
        );
      }
    });

    test('marks entry exams include exam setup context', () async {
      final container = _container();
      addTearDown(container.dispose);

      final options =
          await container.read(teacherMarksExamOptionsProvider.future);
      expect(options, isNotEmpty);

      final first = options.first;
      expect(first.subject, isNotEmpty);
      expect(first.termLabel, isNotEmpty);
      expect(first.dateLabel, isNotEmpty);
      expect(first.classLabel, isNotEmpty);
      expect(first.maxMarks, greaterThan(0));
    });

    test('upcoming exams include canEnterMarks flag', () async {
      final container = _container();
      addTearDown(container.dispose);

      final exams =
          await container.read(teacherUpcomingExamsFutureProvider.future);
      expect(exams, isNotEmpty);

      final marksOpen = exams.where((e) => e.canEnterMarks);
      expect(marksOpen, isNotEmpty);
    });

    test('getExamMarks with examId returns marks for that exam', () async {
      final container = _container();
      addTearDown(container.dispose);

      final options =
          await container.read(teacherMarksExamOptionsProvider.future);
      expect(options, isNotEmpty);

      container.read(teacherSelectedExamIdProvider.notifier).state =
          options.first.id;
      final marks =
          await container.read(teacherExamMarksForActiveProvider.future);
      expect(marks, isNotEmpty);
      expect(marks.first.maxMarks, options.first.maxMarks);
    });

    test('admin-created exam appears in teacher marks entry', () async {
      // Created for a class-section the persona (Priya) actually teaches.
      final store = ExamAdministrationStore.instance..ensureSeeded();
      final created = store.createExam(
        title: 'Midterm — Mathematics',
        subject: 'Mathematics',
        grade: '8',
        section: 'A',
        termLabel: 'Term 2',
        dateLabel: '20 Jun 2026',
        timeLabel: '10:00 AM',
        venueLabel: 'Room 8A',
        syllabusLabel: 'Mensuration',
        maxMarks: 100,
      );
      store.scheduleExam(created.id);
      store.openMarksEntry(created.id);

      final container = _container();
      addTearDown(container.dispose);

      final options =
          await container.read(teacherMarksExamOptionsProvider.future);
      final match = options.where((o) => o.id == created.id);
      expect(match, hasLength(1));
      expect(match.first.subject, 'Mathematics');
      expect(match.first.termLabel, 'Term 2');
    });

    test('teacherActiveExamProvider exposes enriched exam context', () async {
      final container = _container();
      addTearDown(container.dispose);

      await container.read(teacherMarksExamOptionsProvider.future);
      final exam = container.read(teacherActiveExamProvider);
      expect(exam, isNotNull);
      expect(exam!.subject, isNotEmpty);
      expect(exam.termLabel, isNotEmpty);
    });

    test('teacherExamPhaseProvider derives from repository data', () async {
      final container = _container();
      addTearDown(container.dispose);

      await container.read(teacherMarksExamOptionsProvider.future);
      final phase = container.read(teacherExamPhaseProvider);
      expect(phase, isNotNull);
      expect(
        phase == ExamLifecyclePhase.marksEntry ||
            phase == ExamLifecyclePhase.processed,
        isTrue,
      );
    });
  });
}
