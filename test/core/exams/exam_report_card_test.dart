import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/exams/exam_remark.dart';
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

  test('report card carries class-teacher and leadership remarks in separate '
      'slots without overwriting each other', () {
    store.publishExamResults('exam_math_8a');
    // Class teacher writes the primary remark.
    store.upsertRemark(
      examId: 'exam_math_8a',
      sisStudentId: ravi,
      text: 'Strong improvement in algebra.',
      authorId: 'HR-EMP-101',
      authorName: 'Priya Sharma',
      timestamp: '2026-06-19T00:00:00Z',
    );
    // Principal adds a leadership remark — a different slot, not an overwrite.
    store.upsertRemark(
      examId: 'exam_math_8a',
      sisStudentId: ravi,
      text: 'Keep up the consistent effort.',
      authorId: 'HR-EMP-001',
      authorName: 'Anand Rao',
      authorRole: ExamRemarkAuthorRole.principal,
      timestamp: '2026-06-19T02:00:00Z',
    );

    // Both slots survive independently in the store.
    expect(
      store.remarkFor('exam_math_8a', ravi)?.text,
      'Strong improvement in algebra.',
    );
    expect(
      store.remarkFor('exam_math_8a', ravi, leadership: true)?.text,
      'Keep up the consistent effort.',
    );

    final card =
        ExamReportCardBuilder.build(store, sisStudentId: ravi, termLabel: term)!;
    expect(card.remark, 'Strong improvement in algebra.');
    expect(card.remarkAuthorName, 'Priya Sharma');
    expect(card.remarkAuthorRole, ExamRemarkAuthorRole.classTeacher);
    expect(card.leadershipRemark, 'Keep up the consistent effort.');
    expect(card.leadershipRemarkAuthorName, 'Anand Rao');
    expect(card.leadershipRemarkAuthorRole, ExamRemarkAuthorRole.principal);
  });

  test('a vice-principal remark uses the same leadership slot as the principal',
      () {
    store.upsertRemark(
      examId: 'exam_math_8a',
      sisStudentId: ravi,
      text: 'Initial principal note.',
      authorId: 'HR-EMP-001',
      authorName: 'Anand Rao',
      authorRole: ExamRemarkAuthorRole.principal,
      timestamp: '2026-06-19T00:00:00Z',
    );
    final updated = store.upsertRemark(
      examId: 'exam_math_8a',
      sisStudentId: ravi,
      text: 'Reviewed by VP.',
      authorId: 'HR-EMP-002',
      authorName: 'Meera Iyer',
      authorRole: ExamRemarkAuthorRole.vicePrincipal,
      timestamp: '2026-06-19T01:00:00Z',
    );

    expect(updated.text, 'Reviewed by VP.');
    expect(updated.createdAt, '2026-06-19T00:00:00Z'); // same slot, preserved
    expect(updated.history, hasLength(2));
    expect(
      store.remarkFor('exam_math_8a', ravi, leadership: true)?.authorRole,
      ExamRemarkAuthorRole.vicePrincipal,
    );
    // The class-teacher slot is untouched (empty).
    expect(store.remarkFor('exam_math_8a', ravi), isNull);
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

  // EXM-D6 — Absent (AB) / Medical Leave (ML) / Debarred (DB).
  const karthik = 'SIS-STU-10432'; // roll 03, 8-A, seeded 40/50 = 80%
  const priya = 'SIS-STU-10433'; // roll 04, 8-A, seeded 38/50 = 76%

  test('EXM-D6: an absent student is shown "AB", excluded from total/average, '
      'and is NOT ranked', () {
    // Mark Karthik absent for the maths exam BEFORE publishing.
    store.recordMark(
      markEntryId: 'exam_math_8a_03',
      marksObtained: 0,
      status: ExamMarkStatus.absent,
    );
    store.publishExamResults('exam_math_8a');

    final card = ExamReportCardBuilder.build(
      store,
      sisStudentId: karthik,
      termLabel: term,
    )!;

    // The maths subject line renders the display code and is excluded from stats.
    final maths = card.subjects.firstWhere((s) => s.subject == 'Mathematics');
    expect(maths.status, ExamMarkStatus.absent);
    expect(maths.statusCode, 'AB');
    expect(maths.countsTowardStats, isFalse);

    // AB is the student's ONLY subject → nothing counts → zero totals.
    expect(card.totalScore, 0);
    expect(card.totalMax, 0);
    expect(card.overallPercent, 0);

    // An absent student with no present results is NOT ranked.
    expect(card.isRanked, isFalse);
    expect(card.rank, 0);
  });

  test('EXM-D6: an absent classmate does not shift other students\' ranks', () {
    // Baseline ranks (all present): Ananya 90% (1), Ravi 84% (2),
    // Karthik 80% (3), Priya 76% (4).
    // Mark Karthik absent — he leaves the ranking pool entirely.
    store.recordMark(
      markEntryId: 'exam_math_8a_03',
      marksObtained: 0,
      status: ExamMarkStatus.absent,
    );
    store.publishExamResults('exam_math_8a');

    final ananyaCard =
        ExamReportCardBuilder.build(store, sisStudentId: ananya, termLabel: term)!;
    final raviCard =
        ExamReportCardBuilder.build(store, sisStudentId: ravi, termLabel: term)!;
    final priyaCard =
        ExamReportCardBuilder.build(store, sisStudentId: priya, termLabel: term)!;
    final karthikCard =
        ExamReportCardBuilder.build(store, sisStudentId: karthik, termLabel: term)!;

    // Ananya + Ravi keep their positions (Karthik sat between Ravi and Priya).
    expect(ananyaCard.rank, 1);
    expect(raviCard.rank, 2);
    // Priya moves up to 3 only because a NON-present student left the pool — not
    // because AB affected the computation; AB itself contributes nothing.
    expect(priyaCard.rank, 3);
    // The absent student is not ranked at all.
    expect(karthikCard.isRanked, isFalse);
    // Ranked class size counts only present-result holders (3, not 4).
    expect(ananyaCard.classSize, 3);
  });

  test('EXM-D6: medical_leave and debarred use ML / DB display codes', () {
    store.recordMark(
      markEntryId: 'exam_math_8a_03',
      marksObtained: 0,
      status: ExamMarkStatus.medicalLeave,
    );
    store.recordMark(
      markEntryId: 'exam_math_8a_04',
      marksObtained: 0,
      status: ExamMarkStatus.debarred,
    );
    store.publishExamResults('exam_math_8a');

    final ml =
        ExamReportCardBuilder.build(store, sisStudentId: karthik, termLabel: term)!;
    final db =
        ExamReportCardBuilder.build(store, sisStudentId: priya, termLabel: term)!;
    expect(ml.subjects.single.statusCode, 'ML');
    expect(db.subjects.single.statusCode, 'DB');
    // Neither counts toward stats or ranking.
    expect(ml.isRanked, isFalse);
    expect(db.isRanked, isFalse);
    // Present students still rank normally among themselves.
    final raviCard =
        ExamReportCardBuilder.build(store, sisStudentId: ravi, termLabel: term)!;
    expect(raviCard.rank, 2); // behind Ananya
    expect(raviCard.classSize, 2); // only Ananya + Ravi are present-ranked
  });

  test('EXM-D6: a partially-absent student is ranked on their PRESENT subjects '
      'only', () {
    // Publish maths for everyone (all present).
    store.publishExamResults('exam_math_8a');
    // Ravi sits science but is absent; his science AB must not drag his rank.
    // (Science is a separate exam in the same term.)
    store.openMarksEntry('exam_science_8a');
    store.recordMark(
      markEntryId: 'exam_science_8a_01', // Ravi
      marksObtained: 0,
      status: ExamMarkStatus.absent,
    );
    // Give the other classmates a present science mark so science publishes
    // (every provisioned 8-A slot must be decided: rolls 02, 03, 04, 06).
    for (final roll in ['02', '03', '04', '06']) {
      store.recordMark(
        markEntryId: 'exam_science_8a_$roll',
        marksObtained: 30,
        status: ExamMarkStatus.present,
      );
    }
    store.processResults('exam_science_8a');
    store.publishExamResults('exam_science_8a');

    final raviCard =
        ExamReportCardBuilder.build(store, sisStudentId: ravi, termLabel: term)!;
    // Ravi's science line is AB (excluded); his total reflects maths only.
    final science =
        raviCard.subjects.firstWhere((s) => s.subject == 'Science');
    expect(science.statusCode, 'AB');
    expect(raviCard.totalScore, 42); // maths only, science AB excluded
    expect(raviCard.totalMax, 50); // maths max only
    expect(raviCard.isRanked, isTrue); // still ranked on his present subject(s)
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
