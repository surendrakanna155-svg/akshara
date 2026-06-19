import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/exams/exam_report_card.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/exam_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ravi = 'SIS-STU-10430'; // roll 01, 8-A, 42/50 = 84%
  const ananya = 'SIS-STU-10431'; // roll 02, 8-A, 45/50 = 90%
  const term = 'Term 2';

  late ExamAdministrationStore store;

  setUp(() async {
    await resetExamAdministrationForTest();
    store = ExamAdministrationStore.instance;
  });

  test('returns null when the student has no published results for the term',
      () {
    expect(
      ExamReportCardBuilder.build(store, sisStudentId: ravi, termLabel: term),
      isNull,
    );
  });

  test('aggregates published subjects into totals and overall grade', () {
    store.publishExamResults('exam_math_8a');

    final card =
        ExamReportCardBuilder.build(store, sisStudentId: ravi, termLabel: term);

    expect(card, isNotNull);
    expect(card!.subjects.map((s) => s.subject), contains('Mathematics'));
    expect(card.totalScore, 42);
    expect(card.totalMax, 50);
    expect(card.overallPercent, 84);
    expect(card.overallGrade, isNotEmpty);
  });

  test('passes through caller-supplied attendance percent', () {
    store.publishExamResults('exam_math_8a');
    final card = ExamReportCardBuilder.build(
      store,
      sisStudentId: ravi,
      termLabel: term,
      attendancePercent: 95,
    );
    expect(card!.attendancePercent, 95);
  });

  test('computes 1-based class rank by term total percentage', () {
    store.publishExamResults('exam_math_8a');

    final raviCard =
        ExamReportCardBuilder.build(store, sisStudentId: ravi, termLabel: term)!;
    final ananyaCard = ExamReportCardBuilder.build(
      store,
      sisStudentId: ananya,
      termLabel: term,
    )!;

    // Ananya (90%) is the top scorer; Ravi (84%) sits just behind her.
    expect(ananyaCard.rank, 1);
    expect(raviCard.rank, 2);
    expect(raviCard.classSize, greaterThanOrEqualTo(2));
  });

  test('report card includes the class-teacher remark for the term', () {
    store.publishExamResults('exam_math_8a');
    store.upsertRemark(
      examId: 'exam_math_8a',
      sisStudentId: ravi,
      text: 'Strong improvement in algebra.',
      authorId: 'HR-EMP-101',
      authorName: 'Priya Sharma',
      timestamp: '2026-06-19T00:00:00Z',
    );

    final card =
        ExamReportCardBuilder.build(store, sisStudentId: ravi, termLabel: term)!;
    expect(card.remark, 'Strong improvement in algebra.');
    expect(card.remarkAuthorName, 'Priya Sharma');
  });

  test('editing a remark preserves createdAt and grows the audit trail', () {
    store.upsertRemark(
      examId: 'exam_math_8a',
      sisStudentId: ravi,
      text: 'Needs more practice.',
      authorId: 'HR-EMP-101',
      authorName: 'Priya Sharma',
      timestamp: '2026-06-19T00:00:00Z',
    );
    final updated = store.upsertRemark(
      examId: 'exam_math_8a',
      sisStudentId: ravi,
      text: 'Much improved this term.',
      authorId: 'HR-EMP-101',
      authorName: 'Priya Sharma',
      timestamp: '2026-06-19T01:00:00Z',
    );

    expect(updated.text, 'Much improved this term.');
    expect(updated.createdAt, '2026-06-19T00:00:00Z');
    expect(updated.updatedAt, '2026-06-19T01:00:00Z');
    expect(updated.history, hasLength(2));
    expect(updated.history.first.text, 'Needs more practice.');
    expect(updated.history.last.text, 'Much improved this term.');
  });

  test('rank is always computed but rankShown follows the school setting', () {
    // Default scale hides rank from parents.
    store.publishExamResults('exam_math_8a');
    final hidden =
        ExamReportCardBuilder.build(store, sisStudentId: ravi, termLabel: term)!;
    expect(hidden.rankShown, isFalse);
    expect(hidden.rank, greaterThan(0)); // still computed

    // Turn the school setting on.
    store.configureReportSettings(
      store.reportSettings.copyWith(showRankToParents: true),
    );
    final shown =
        ExamReportCardBuilder.build(store, sisStudentId: ravi, termLabel: term)!;
    expect(shown.rankShown, isTrue);
  });
}
