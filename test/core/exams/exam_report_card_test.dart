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
