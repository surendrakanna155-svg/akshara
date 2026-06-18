import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:akshara_erp/features/teacher/exams/exam_models.dart';
import 'package:akshara_erp/features/teacher/exams/teacher_exams_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

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
      final container = ProviderContainer(overrides: providerTestOverrides());
      addTearDown(container.dispose);

      final options =
          await container.read(teacherMarksExamOptionsProvider.future);
      expect(options, isNotEmpty);
      expect(
        options.every((exam) =>
            exam.phaseLabel == 'marksEntry' || exam.phaseLabel == 'processed'),
        isTrue,
      );
    });

    test('teacherSelectedExamIdProvider switches active marks roster', () async {
      final container = ProviderContainer(overrides: providerTestOverrides());
      addTearDown(container.dispose);

      final options =
          await container.read(teacherMarksExamOptionsProvider.future);
      if (options.length < 2) return;

      container.read(teacherSelectedExamIdProvider.notifier).state =
          options.last.id;
      expect(container.read(teacherActiveExamIdProvider), options.last.id);

      final marks =
          await container.read(teacherExamMarksForActiveProvider.future);
      expect(marks, isNotEmpty);
      expect(marks.first.maxMarks, options.last.maxMarks);
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
