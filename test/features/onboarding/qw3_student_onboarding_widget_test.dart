import 'package:akshara_erp/core/repositories/mock/mock_onboarding_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/onboarding/onboarding_models.dart';
import 'package:akshara_erp/features/onboarding/student_onboarding_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-020 (single-student Add-one form validation + Save → provider) and
/// QA-F-023 (bulk student import preview UI: mixed valid/invalid rows flagged,
/// then Confirm fires the import job). Both live on `student_onboarding_screen.dart`
/// (Add-one tab + Upload tab) and run against the demo `MockOnboardingRepository`.

/// Fails the COMMIT leg with a realistic transport exception whose
/// `toString()` carries internal endpoint detail — exactly what must never
/// reach a principal's screen on the school's first import.
class _FailingCommitOnboardingRepository extends MockOnboardingRepository {
  @override
  Future<OnboardingImportJob> commitImport({
    required RepositoryQuery query,
    required String jobId,
  }) async {
    throw DioException(
      requestOptions: RequestOptions(
        path: '/functions/v1/onboarding-import-commit',
        baseUrl: 'https://internal-db.akshara.invalid',
      ),
      type: DioExceptionType.connectionError,
      message: 'SocketException: Failed host lookup',
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const StudentOnboardingScreen(),
      ),
    ),
  );
  await tester.pump();
}

/// Switches the lightweight tab selector to a tab by its label.
Future<void> _selectTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('QA-F-020 · StudentOnboarding single-student form', () {
    testWidgets('submitting the empty form shows required-field errors',
        (tester) async {
      await _pump(tester);
      await _selectTab(tester, 'Add one');

      // Open the inline single-student form.
      await tester.tap(find.byKey(const Key('onboarding_add_one_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding_add_one_form')), findsOneWidget);

      // Submit empty → the Form validators surface "Required" on each field.
      await tester.tap(find.text('Save student'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsWidgets);
      // Still on the form (no success snackbar).
      expect(find.byKey(const Key('onboarding_add_one_form')), findsOneWidget);
      expect(find.textContaining('Parent can now OTP-login'), findsNothing);
    });

    testWidgets('a valid student saves via the provider and surfaces success',
        (tester) async {
      await _pump(tester);
      await _selectTab(tester, 'Add one');

      await tester.tap(find.byKey(const Key('onboarding_add_one_btn')));
      await tester.pumpAndSettle();

      Future<void> fill(String label, String value) async {
        await tester.enterText(
          find.widgetWithText(TextFormField, label),
          value,
        );
      }

      await fill('Student name *', 'Asha Rao');
      await fill('Admission number *', 'ADM-2026-0001');
      await fill('Class *', 'Grade 6');
      await fill('Section *', 'A');
      await fill('Father / Parent name *', 'Ramesh Rao');
      await fill('Parent phone *', '9876500001');
      await tester.pump();

      await tester.tap(find.text('Save student'));
      // previewStudentImport + commitImport resolve (demo repo) → success.
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      // Success surface confirms the Save provider fired and committed 1 student.
      expect(find.textContaining('Added 1 student'), findsOneWidget);
      expect(find.text('Required'), findsNothing);
    });
  });

  group('QA-F-023 · StudentOnboarding bulk import preview', () {
    testWidgets('mixed valid/invalid rows are flagged and Confirm fires the job',
        (tester) async {
      await _pump(tester);
      await _selectTab(tester, 'Upload file');

      // Paste a CSV with one VALID row + one INVALID row (missing the required
      // admission number) so the preview must flag exactly one invalid row.
      const csv = 'Student Name,Admission Number,Class,Section\n'
          'Asha Rao,ADM-2026-0001,Grade 6,A\n'
          'Broken Row,,Grade 6,B\n';
      await tester.enterText(
        find.widgetWithText(TextField, 'Paste CSV (header + rows)'),
        csv,
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('onboarding_upload_file_btn')));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      // Preview surfaces the valid/invalid breakdown + per-row rows.
      expect(find.byKey(const Key('onboarding_preview_list')), findsOneWidget);
      expect(find.textContaining('1 valid'), findsOneWidget);
      expect(find.textContaining('1 invalid'), findsOneWidget);
      // The invalid row is flagged with its validation error.
      expect(find.textContaining('admissionNumber is required'), findsOneWidget);

      // Confirm → commitImport runs and the committed-count snackbar surfaces.
      await tester.ensureVisible(find.byKey(const Key('onboarding_commit_btn')));
      await tester.tap(find.byKey(const Key('onboarding_commit_btn')));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('Committed 1 students'), findsOneWidget);
    });

    testWidgets(
        'a failed commit shows a clean message, never the raw exception',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          onboardingRepositoryProvider
              .overrideWithValue(_FailingCommitOnboardingRepository()),
        ],
      );
      await _selectTab(tester, 'Upload file');

      const csv = 'Student Name,Admission Number,Class,Section\n'
          'Asha Rao,ADM-2026-0001,Grade 6,A\n';
      await tester.enterText(
        find.widgetWithText(TextField, 'Paste CSV (header + rows)'),
        csv,
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('onboarding_upload_file_btn')));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('onboarding_commit_btn')));
      await tester.tap(find.byKey(const Key('onboarding_commit_btn')));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      // The user is told the commit failed, in the standard mapped wording.
      expect(find.textContaining('Commit failed'), findsOneWidget);
      expect(
        find.textContaining('Unable to reach the server'),
        findsOneWidget,
      );

      // …and NOTHING from the exception itself leaks: no type name, no
      // internal host, no endpoint path, no socket detail.
      for (final leak in const [
        'DioException',
        'internal-db.akshara.invalid',
        'onboarding-import-commit',
        'SocketException',
        'Failed host lookup',
      ]) {
        expect(
          find.textContaining(leak),
          findsNothing,
          reason: 'raw exception detail "$leak" reached the UI',
        );
      }
    });
  });
}
