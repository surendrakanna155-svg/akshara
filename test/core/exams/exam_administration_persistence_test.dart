import 'package:akshara_erp/core/exams/exam_administration_persistence.dart';
import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/exams/exam_grading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P0-EXAM-004 exam administration persistence', () {
    late ExamAdministrationStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = ExamAdministrationStore.instance;
      store.reset();
      store.attachPersistence(ExamAdministrationPersistence(prefs));
      store.ensureSeeded();
    });

    test('survives simulated restart via SharedPreferences', () async {
      store.recordMark(markEntryId: 'exam_math_8a_06', marksObtained: 41);
      store.processResults('exam_math_8a');

      final prefs = await SharedPreferences.getInstance();
      final reloaded = ExamAdministrationStore.instance;
      reloaded.reset(clearPersistence: false);
      reloaded.attachPersistence(ExamAdministrationPersistence(prefs));
      reloaded.ensureSeeded();

      expect(reloaded.examById('exam_math_8a')!.phase, ExamLifecyclePhase.processed);
      expect(
        reloaded.markById('exam_math_8a_06')!.marksObtained,
        41,
      );
    });

    test('reset clears persisted snapshot', () async {
      store.recordMark(markEntryId: 'exam_math_8a_06', marksObtained: 41);
      store.reset();

      final prefs = await SharedPreferences.getInstance();
      final persistence = ExamAdministrationPersistence(prefs);
      expect(persistence.loadSnapshot(), isNull);
    });

    test('persists coordinator verification and rejection comments', () async {
      store.recordMark(markEntryId: 'exam_math_8a_06', marksObtained: 41);
      store.processResults('exam_math_8a');
      store.markCoordinatorVerified('exam_math_8a', verifiedBy: 'Coordinator');
      store.recordRejectionComment('exam_math_8a', 'Recheck roll 06');

      final prefs = await SharedPreferences.getInstance();
      final reloaded = ExamAdministrationStore.instance;
      reloaded.reset(clearPersistence: false);
      reloaded.attachPersistence(ExamAdministrationPersistence(prefs));
      reloaded.ensureSeeded();

      expect(reloaded.isCoordinatorVerified('exam_math_8a'), isTrue);
      expect(
        reloaded.rejectionCommentFor('exam_math_8a'),
        'Recheck roll 06',
      );
    });

    test('persists report settings (grading scale + rank + terms)', () async {
      store.configureReportSettings(
        const ExamReportSettings(
          gradingScale: ExamGradingScale.cbseScholastic,
          showRankToParents: true,
          suggestedTerms: ['Unit Test 1', 'Annual'],
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final reloaded = ExamAdministrationStore.instance;
      reloaded.reset(clearPersistence: false);
      reloaded.attachPersistence(ExamAdministrationPersistence(prefs));
      reloaded.ensureSeeded();

      final restored = reloaded.reportSettings;
      expect(restored.gradingScale.name, 'CBSE (A1–E)');
      expect(restored.showRankToParents, isTrue);
      expect(restored.suggestedTerms, const ['Unit Test 1', 'Annual']);
    });

    test('migrates legacy sync store snapshot', () async {
      store.reset();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        kLegacyExamResultsStorageKey,
        '''
{
  "published": [
    {
      "markEntryId": "exam_legacy_01",
      "sisStudentId": "SIS-STU-10418",
      "studentName": "Arjun Reddy",
      "examId": "exam_legacy",
      "examTitle": "Legacy Unit Test",
      "termLabel": "Term 1",
      "dateLabel": "01 Jun 2026",
      "scoreObtained": 42,
      "maxScore": 50,
      "grade": "B+",
      "subject": "Mathematics"
    }
  ]
}
''',
      );

      final persistence = ExamAdministrationPersistence(prefs);
      final migrated = persistence.loadSnapshot();
      expect(migrated, isNotNull);
      expect(migrated!['migratedFrom'], kLegacyExamResultsStorageKey);
      expect(prefs.getString(kLegacyExamResultsStorageKey), isNull);

      final reloaded = ExamAdministrationStore.instance;
      reloaded.reset(clearPersistence: false);
      reloaded.attachPersistence(persistence);
      reloaded.ensureSeeded();
      expect(
        reloaded.resultForMarkEntry('exam_legacy_01')?.examTitle,
        'Legacy Unit Test',
      );
    });
  });
}
