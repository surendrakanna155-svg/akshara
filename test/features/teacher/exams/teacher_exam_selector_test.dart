import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:akshara_erp/core/teaching/teacher_assignment_registry.dart';
import 'package:akshara_erp/features/teacher/communication/teacher_teaching_context_provider.dart';
import 'package:akshara_erp/features/teacher/exams/exam_models.dart';
import 'package:akshara_erp/features/teacher/exams/teacher_exams_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

/// Pins the teaching context to a known persona so exam scoping is deterministic
/// without standing up auth/shared-preferences in a unit container.
Override _teacherContext(String teacherId, String teacherName) =>
    teacherTeachingContextOverrideProvider.overrideWith(
      (ref) => TeacherAssignmentRegistry.resolveContext(
        teacherId: teacherId,
        teacherName: teacherName,
      ),
    );

final _priya = _teacherContext(
  TeacherAssignmentRegistry.priyaSharmaId,
  'Priya Sharma',
);

void main() {
  setUp(() {
    ExamAdministrationStore.instance.reset();
    ExamAdministrationStore.instance.ensureSeeded();
  });

  group('M-A4 teacher exam selectors', () {
    test('validateTeacherExamMarkInput rejects over-max marks', () {
      expect(validateTeacherExamMarkInput('95', 80), isNotNull);
      expect(validateTeacherExamMarkInput('40', 50), isNull);
    });

    test('teacherMarksExamOptionsProvider scopes marks-entry exams', () async {
      final container =
          ProviderContainer(overrides: providerTestOverrides([_priya]));
      addTearDown(container.dispose);

      final options =
          await container.read(teacherMarksExamOptionsProvider.future);
      expect(options, isNotEmpty);
      expect(
        options.every((exam) =>
            exam.phaseLabel == 'marksEntry' || exam.phaseLabel == 'processed'),
        isTrue,
      );
      // Priya teaches Mathematics only — Mr. Patel's Science exam is hidden.
      expect(options.every((exam) => exam.subject == 'Mathematics'), isTrue);
    });

    test('teacherSelectedExamIdProvider switches active marks roster', () async {
      // Give Priya a second Maths 8-A session so the roster switch is exercised.
      final store = ExamAdministrationStore.instance;
      final second = store.createExam(
        title: 'Midterm — Mathematics',
        subject: 'Mathematics',
        grade: '8',
        section: 'A',
        termLabel: 'Term 2',
        dateLabel: '22 Jun 2026',
        timeLabel: '9:00 AM',
        venueLabel: 'Room 8A',
        syllabusLabel: 'Mensuration',
        maxMarks: 40,
      );
      store.scheduleExam(second.id);
      store.openMarksEntry(second.id);

      final container =
          ProviderContainer(overrides: providerTestOverrides([_priya]));
      addTearDown(container.dispose);

      final options =
          await container.read(teacherMarksExamOptionsProvider.future);
      expect(options.length, greaterThanOrEqualTo(2));

      container.read(teacherSelectedExamIdProvider.notifier).state =
          options.last.id;
      expect(container.read(teacherActiveExamIdProvider), options.last.id);

      final marks =
          await container.read(teacherExamMarksForActiveProvider.future);
      expect(marks, isNotEmpty);
      expect(marks.first.maxMarks, options.last.maxMarks);
    });

    test('subject teacher sees only exams for subjects they teach', () async {
      // Mr. Patel teaches Science (8-A/8-B/10-A). Move a Science 8-B session
      // into marks entry; he should see it, but never Priya's Maths 8-A.
      final store = ExamAdministrationStore.instance;
      final science = store.createExam(
        title: 'Unit Test — Science (8-B)',
        subject: 'Science',
        grade: '8',
        section: 'B',
        termLabel: 'Term 2',
        dateLabel: '24 Jun 2026',
        timeLabel: '11:00 AM',
        venueLabel: 'Science Lab 2',
        syllabusLabel: 'Cell Structure',
        maxMarks: 50,
      );
      store.scheduleExam(science.id);
      store.openMarksEntry(science.id);

      final container = ProviderContainer(
        overrides: providerTestOverrides([
          _teacherContext(TeacherAssignmentRegistry.mrPatelId, 'Mr. Patel'),
        ]),
      );
      addTearDown(container.dispose);

      final options =
          await container.read(teacherMarksExamOptionsProvider.future);
      expect(options.any((o) => o.id == science.id), isTrue);
      expect(options.every((o) => o.subject == 'Science'), isTrue);
      expect(options.any((o) => o.id == 'exam_math_8a'), isFalse);
    });
  });

  group('AksharaReportExportService', () {
    test('buildTabularReportPdf returns non-empty bytes', () async {
      const service = AksharaReportExportService();
      final bytes = await service.buildTabularReportPdf(
        reportTitle: 'Collection Report',
        moduleLabel: 'Finance',
        rows: const [
          MapEntry('Total collected', '₹12,50,000'),
        ],
      );
      expect(bytes, isNotEmpty);
    });
  });
}
