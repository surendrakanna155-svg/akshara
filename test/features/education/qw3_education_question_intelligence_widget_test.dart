import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/education/education_bank_import_sheet.dart';
import 'package:akshara_erp/features/education/education_bank_item_form.dart';
import 'package:akshara_erp/features/education/education_models.dart';
import 'package:akshara_erp/features/education/education_provider.dart';
import 'package:akshara_erp/features/education/education_question_paper_detail_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-045 (CSV/sheet question import: file paste → preview → invalid-row
/// flagging → confirm import), QA-F-046 (add/edit question dialog validation +
/// the paper-level "N marks unfilled" banner) and QA-F-047 (AI-candidate
/// moderation queue: Approve/Reject a candidate → mutation fires).
///
/// The import + add forms are private bottom-sheet bodies reachable only via the
/// public `showImportBankSheet` / `showAddBankItemSheet`, so each is opened from a
/// tiny host button (the real call-site shape). The moderation queue lives on
/// `QuestionPaperDetailScreen`; the demo seed paper carries no pending AI items,
/// so `paperDetailProvider` is overridden with a detail that has two pending
/// candidates (the documented "force the screen's own state provider" pattern).

const _paperId = 'paper_qw3_mod';

/// Records moderateItem calls so the Approve/Reject taps can be asserted without
/// reaching the demo repo (which only seeds `paper_demo_1`).
class _RecordingEducationMutations extends EducationMutationsNotifier {
  final List<({String paperId, String itemId, String decision})> calls = [];

  @override
  Future<QuestionPaperItem> moderateItem(
    String paperId,
    String itemId,
    String decision,
  ) async {
    calls.add((paperId: paperId, itemId: itemId, decision: decision));
    return QuestionPaperItem(
      id: itemId,
      questionNumber: 1,
      questionType: EduQuestionType.mcq,
      marks: 1,
      questionText: 'moderated',
      source: 'ai_candidate',
      reviewStatus: decision == 'approved' ? 'approved' : 'rejected',
    );
  }
}

QuestionPaperDetail _detailWithPendingCandidates() {
  return const QuestionPaperDetail(
    paper: QuestionPaperSummary(
      id: _paperId,
      title: '8 — Science unit test',
      className: '8',
      sectionName: 'A',
      subjectName: 'Science',
      examType: EduExamType.unitTest,
      totalMarks: 4, // matches the two placed marks below → no unfilled banner
      difficulty: EduDifficulty.medium,
      status: 'draft',
      reviewStatus: EduPaperReviewStatus.draft,
    ),
    items: [
      QuestionPaperItem(
        id: 'cand_a',
        questionNumber: 1,
        questionType: EduQuestionType.mcq,
        marks: 2,
        questionText: 'Which gas do plants absorb during photosynthesis?',
        options: ['Oxygen', 'Carbon dioxide', 'Nitrogen', 'Hydrogen'],
        answerText: 'Carbon dioxide',
        source: 'ai_candidate',
        reviewStatus: 'pending',
      ),
      QuestionPaperItem(
        id: 'cand_b',
        questionNumber: 2,
        questionType: EduQuestionType.shortAnswer,
        marks: 2,
        questionText: 'Define an ecosystem.',
        source: 'ai_candidate',
        reviewStatus: 'pending',
      ),
    ],
    blueprint: {},
    answerKey: [],
  );
}

/// Finds the [TextField] whose [InputDecoration.labelText] matches [label].
Finder _fieldByLabel(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );

Future<void> _pumpHostButton(
  WidgetTester tester, {
  required Future<void> Function(BuildContext context, WidgetRef ref) onTap,
  List<Override> overrides = const [],
}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => onTap(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const QuestionPaperDetailScreen(paperId: _paperId),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('QA-F-045 · ImportBankSheet', () {
    testWidgets('previews valid rows and flags invalid rows', (tester) async {
      await _pumpHostButton(
        tester,
        onTap: (context, _) => showImportBankSheet(context),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // One valid row + one row missing the chapter → flagged as skipped.
      const csv =
          'subject,chapter,topic,difficulty,type,marks,question,answer,options\n'
          'Mathematics,Real Numbers,HCF,easy,mcq,1,What is the HCF of 12 and 18?,6,2|3|6\n'
          'Mathematics,,Bad row,easy,mcq,1,,6,';
      await tester.enterText(find.byType(TextField), csv);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Preview'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 valid row(s)'), findsOneWidget);
      expect(find.textContaining('1 skipped'), findsOneWidget);
      // Import button enabled + labelled with the valid count.
      final button = tester.widget<FilledButton>(
        find.byKey(QaTestKeys.educationImportBankButton),
      );
      expect(button.onPressed, isNotNull);
      expect(find.text('Import 1 question(s)'), findsOneWidget);
    });

    testWidgets('confirm returns the parsed valid items to the caller',
        (tester) async {
      List<QuestionBankItem>? imported;
      await _pumpHostButton(
        tester,
        onTap: (context, _) async {
          imported = await showImportBankSheet(context);
        },
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      const csv =
          'subject,chapter,topic,difficulty,type,marks,question,answer,options\n'
          'Science,Light,Reflection,medium,mcq,2,What is the angle of incidence?,equal,a|b|c';
      await tester.enterText(find.byType(TextField), csv);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Preview'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(QaTestKeys.educationImportBankButton));
      await tester.pumpAndSettle();

      // Import fires → the sheet pops the valid parsed rows back.
      expect(imported, isNotNull);
      expect(imported!.length, 1);
      expect(imported!.single.subjectName, 'Science');
      expect(imported!.single.chapter, 'Light');
    });

    testWidgets('disables import when there are no valid rows', (tester) async {
      await _pumpHostButton(
        tester,
        onTap: (context, _) => showImportBankSheet(context),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      const csv =
          'subject,chapter,topic,difficulty,type,marks,question,answer,options\n'
          'Mathematics,,No chapter,easy,mcq,1,,6,';
      await tester.enterText(find.byType(TextField), csv);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Preview'));
      await tester.pumpAndSettle();

      expect(find.textContaining('0 valid row(s)'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byKey(QaTestKeys.educationImportBankButton),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('QA-F-046 · AddBankItemForm', () {
    testWidgets('disables save until subject/chapter/question are filled',
        (tester) async {
      await _pumpHostButton(
        tester,
        onTap: (context, _) => showAddBankItemSheet(context),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Add question to bank'), findsOneWidget);
      // Empty form → save gated off.
      final disabled = tester.widget<FilledButton>(
        find.byKey(QaTestKeys.educationSaveBankItemButton),
      );
      expect(disabled.onPressed, isNull);
    });

    testWidgets('enables save and returns the built item once valid',
        (tester) async {
      QuestionBankItem? saved;
      await _pumpHostButton(
        tester,
        onTap: (context, _) async {
          saved = await showAddBankItemSheet(context);
        },
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(_fieldByLabel('Subject'), 'Mathematics');
      await tester.enterText(_fieldByLabel('Chapter'), 'Algebra');
      await tester.enterText(_fieldByLabel('Question text'), 'Solve x + 2 = 5');
      await tester.pump();

      final enabled = tester.widget<FilledButton>(
        find.byKey(QaTestKeys.educationSaveBankItemButton),
      );
      expect(enabled.onPressed, isNotNull);

      await tester.ensureVisible(
        find.byKey(QaTestKeys.educationSaveBankItemButton),
      );
      await tester.tap(find.byKey(QaTestKeys.educationSaveBankItemButton));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.subjectName, 'Mathematics');
      expect(saved!.chapter, 'Algebra');
      expect(saved!.questionText, 'Solve x + 2 = 5');
    });

    testWidgets('paper detail shows the N-marks-unfilled banner when blueprint '
        'is not covered', (tester) async {
      // totalMarks 50 with no placed items → 50 marks unfilled banner.
      await _pumpDetail(
        tester,
        overrides: [
          paperDetailProvider(_paperId).overrideWith(
            (ref) async => const QuestionPaperDetail(
              paper: QuestionPaperSummary(
                id: _paperId,
                title: 'Gap paper',
                className: '8',
                subjectName: 'Science',
                examType: EduExamType.unitTest,
                totalMarks: 50,
                difficulty: EduDifficulty.medium,
                status: 'draft',
              ),
              items: [],
              blueprint: {},
              answerKey: [],
            ),
          ),
        ],
      );

      expect(find.byKey(QaTestKeys.educationUnfilledMarksBanner), findsOneWidget);
      expect(find.textContaining('50 marks unfilled'), findsOneWidget);
    });
  });

  group('QA-F-047 · AI moderation queue', () {
    testWidgets('renders pending AI candidates with Approve/Reject actions',
        (tester) async {
      await _pumpDetail(
        tester,
        overrides: [
          paperDetailProvider(_paperId)
              .overrideWith((ref) async => _detailWithPendingCandidates()),
        ],
      );

      expect(find.text('AI moderation queue'), findsOneWidget);
      expect(
        find.textContaining('2 AI candidate(s) awaiting moderation'),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.educationModerateApproveButton('cand_a')),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.educationModerateRejectButton('cand_b')),
        findsOneWidget,
      );
    });

    testWidgets('approving a candidate fires the moderate mutation', (tester) async {
      final recorder = _RecordingEducationMutations();
      await _pumpDetail(
        tester,
        overrides: [
          paperDetailProvider(_paperId)
              .overrideWith((ref) async => _detailWithPendingCandidates()),
          educationMutationsProvider.overrideWith(() => recorder),
        ],
      );

      await tester.ensureVisible(
        find.byKey(QaTestKeys.educationModerateApproveButton('cand_a')),
      );
      await tester.tap(
        find.byKey(QaTestKeys.educationModerateApproveButton('cand_a')),
      );
      await tester.pump(); // surface the snackbar
      await tester.pump(const Duration(milliseconds: 50));

      // The Approve tap fired moderateItem with the right candidate + decision,
      // and the standard success snackbar surfaced.
      expect(recorder.calls.length, 1);
      expect(recorder.calls.single.itemId, 'cand_a');
      expect(recorder.calls.single.decision, 'approved');
      expect(find.text('AI candidate approved'), findsOneWidget);
    });
  });
}
