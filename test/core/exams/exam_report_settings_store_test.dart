import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/exams/exam_grading.dart';
import 'package:flutter_test/flutter_test.dart';

/// Slice 1 integration: the configured per-school grading scale is what the
/// store actually uses when publishing results.
void main() {
  setUp(() => ExamAdministrationStore.instance.reset());
  tearDown(() => ExamAdministrationStore.instance.reset());

  String publishGradeFor95Percent() {
    final store = ExamAdministrationStore.instance;
    final exam = store.createExam(
      title: 'Config Test',
      subject: 'Science',
      grade: '8',
      section: 'A',
      termLabel: 'Term 1',
      dateLabel: '01 Jul 2026',
      timeLabel: '9:00 AM',
      venueLabel: 'Room 1',
      syllabusLabel: 'Ch 1',
      maxMarks: 100,
    );
    store.scheduleExam(exam.id); // provisions mark slots for class 8-A
    final markId = '${exam.id}_01';
    store.recordMark(markEntryId: markId, marksObtained: 95);
    store.publishExamResults(exam.id);
    return store.resultForMarkEntry(markId)!.grade;
  }

  test('default scale (standard) grades 95% as A+', () {
    expect(publishGradeFor95Percent(), 'A+');
  });

  test('configured CBSE scale grades 95% as A1', () {
    ExamAdministrationStore.instance.configureReportSettings(
      const ExamReportSettings(gradingScale: ExamGradingScale.cbseScholastic),
    );
    expect(publishGradeFor95Percent(), 'A1');
  });

  test('configured percentage/division scale grades 95% as Distinction', () {
    ExamAdministrationStore.instance.configureReportSettings(
      const ExamReportSettings(gradingScale: ExamGradingScale.percentageDivision),
    );
    expect(publishGradeFor95Percent(), 'Distinction');
  });

  test('reset restores the default scale', () {
    ExamAdministrationStore.instance.configureReportSettings(
      const ExamReportSettings(gradingScale: ExamGradingScale.cbseScholastic),
    );
    ExamAdministrationStore.instance.reset();
    expect(
      ExamAdministrationStore.instance.reportSettings.gradingScale.name,
      'Standard',
    );
  });
}
