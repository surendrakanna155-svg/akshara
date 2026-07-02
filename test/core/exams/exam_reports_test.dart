import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/exams/exam_reports.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/exam_test_helpers.dart';

/// EXM-3/4/5/7 — the client-side report computation, focused on the frozen
/// present-only exclusion: a non-present (AB/ML/DB) result is shown via its code
/// but EXCLUDED from totals, averages, percent, ranking, pass/fail and the
/// grade distribution.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Seeded class 8-A, Term 2, exam_math_8a (/50):
  //   Ravi (roll 01)  42/50 = 84%
  //   Ananya (roll 02) 45/50 = 90%
  //   Karthik (roll 03) 40/50 = 80%
  //   Priya (roll 04) 38/50 = 76%
  const ravi = 'SIS-STU-10430';
  const ananya = 'SIS-STU-10431';
  const karthik = 'SIS-STU-10432';
  const term = 'Term 2';
  const classLabel = '8-A';

  late ExamAdministrationStore store;

  setUp(() async {
    await resetExamAdministrationForTest();
    store = ExamAdministrationStore.instance;
  });

  group('ExamReportsBuilder — present-only exclusion', () {
    test('EXM-3: tabulation EXCLUDES an absent student from total/percent/rank',
        () {
      // Mark Karthik absent BEFORE publishing.
      store.recordMark(
        markEntryId: 'exam_math_8a_03',
        marksObtained: 0,
        status: ExamMarkStatus.absent,
      );
      store.publishExamResults('exam_math_8a');

      final reg = ExamReportsBuilder.tabulation(
        store,
        classLabel: classLabel,
        term: term,
      );

      final karthikRow =
          reg.students.firstWhere((s) => s.sisStudentId == karthik);
      final cell = karthikRow.cellsBySubject['Mathematics']!;
      // Absent cell shows the code, contributes nothing.
      expect(cell.statusCode, 'AB');
      expect(cell.marks, isNull);
      expect(cell.display, 'AB');
      expect(karthikRow.total, 0);
      expect(karthikRow.totalMax, 0);
      // A fully-absent student is NOT ranked.
      expect(karthikRow.rank, isNull);

      // Present students keep their totals + ranks; the absent classmate never
      // shifts them. Ananya 90% (1), Ravi 84% (2), Priya 76% (3 — Karthik gone).
      final ananyaRow =
          reg.students.firstWhere((s) => s.sisStudentId == ananya);
      final raviRow = reg.students.firstWhere((s) => s.sisStudentId == ravi);
      expect(ananyaRow.total, 45);
      expect(ananyaRow.rank, 1);
      expect(raviRow.total, 42);
      expect(raviRow.rank, 2);
    });

    test('EXM-4b: merit list omits the absent student and ranks present-only',
        () {
      store.recordMark(
        markEntryId: 'exam_math_8a_03',
        marksObtained: 0,
        status: ExamMarkStatus.medicalLeave,
      );
      store.publishExamResults('exam_math_8a');

      final merit = ExamReportsBuilder.merit(
        store,
        classLabel: classLabel,
        term: term,
      );
      // The medical-leave student is excluded entirely.
      expect(merit.any((m) => m.sisStudentId == karthik), isFalse);
      expect(merit.first.rank, 1);
      expect(merit.first.sisStudentId, ananya);
    });

    test('EXM-4a: toppers never include a non-present student', () {
      store.recordMark(
        markEntryId: 'exam_math_8a_02', // Ananya — top scorer — mark her absent
        marksObtained: 0,
        status: ExamMarkStatus.absent,
      );
      store.publishExamResults('exam_math_8a');

      final toppers =
          ExamReportsBuilder.toppers(store, examId: 'exam_math_8a', limit: 5);
      // The absent (formerly top) student is gone; a present student leads.
      expect(toppers.any((t) => t.sisStudentId == ananya), isFalse);
      expect(toppers.first.rank, 1);
      // Ravi (84%) now leads the present pool.
      expect(toppers.first.sisStudentId, ravi);
    });

    test('EXM-5: distribution counts PRESENT rows only; AB is excluded', () {
      // 5 seeded students; mark one absent, one debarred → 2 excluded.
      store.recordMark(
        markEntryId: 'exam_math_8a_03',
        marksObtained: 0,
        status: ExamMarkStatus.absent,
      );
      store.recordMark(
        markEntryId: 'exam_math_8a_04',
        marksObtained: 0,
        status: ExamMarkStatus.debarred,
      );
      store.publishExamResults('exam_math_8a');

      final dist =
          ExamReportsBuilder.distribution(store, examId: 'exam_math_8a');
      expect(dist.excludedCount, 2);
      // presentCount + excludedCount equals the whole published roster.
      expect(dist.presentCount + dist.excludedCount,
          store.marksForExam('exam_math_8a').where((m) => m.published).length);
      // Every present student here scored >= 40% of 50 → all pass, none fail.
      expect(dist.failCount, 0);
      expect(dist.passCount, dist.presentCount);
      // Grade buckets total the PRESENT count only (never the AB/DB rows).
      final bucketTotal =
          dist.gradeBreakdown.fold<int>(0, (sum, g) => sum + g.count);
      expect(bucketTotal, dist.presentCount);
      expect(dist.passMarkPercent, kDefaultPassMarkPercent);
      expect(dist.passMarkSource, 'default');
    });

    test('EXM-7: datesheet lists the class term schedule sorted by date', () {
      final rows = ExamReportsBuilder.datesheet(
        store,
        classLabel: classLabel,
        term: term,
      );
      // Seeded 8-A Term 2 has Maths (12 Jun) + Science (14 Jun).
      expect(rows.length, greaterThanOrEqualTo(2));
      expect(rows.map((r) => r.subject), containsAll(['Mathematics', 'Science']));
      // Sorted by date label ascending (12 Jun before 14 Jun).
      final dates = rows.map((r) => r.dateLabel).toList();
      final sorted = [...dates]..sort();
      expect(dates, sorted);
    });
  });
}
