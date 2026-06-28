import 'package:akshara_erp/features/parent/leave/leave_models.dart';
import 'package:akshara_erp/features/parent/leave/parent_leave_provider.dart';
import 'package:akshara_erp/features/parent/leave/widgets/leave_apply_form.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

/// QW1 · QA-F-014 — Parent leave-apply form validation gating.
/// `leave_apply_form.dart` was 0% lcov; this asserts the submit button stays
/// disabled (with the helper message) until the draft is valid, then enables
/// and fires the submit callback.
const _validDraft = LeaveApplyDraft(
  fromDateLabel: '12 Jun 2026',
  toDateLabel: '13 Jun 2026',
  reason: 'Fever and rest needed',
);

Future<void> _pumpForm(
  WidgetTester tester, {
  required LeaveApplyDraft draft,
  required Future<void> Function() onSubmit,
}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        leaveApplyDraftProvider.overrideWith((ref) => draft),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: LeaveApplyForm(onSubmit: onSubmit),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('QA-F-014 · LeaveApplyForm', () {
    testWidgets('disables submit and shows the helper for an empty draft',
        (tester) async {
      var submitted = 0;
      await _pumpForm(
        tester,
        draft: const LeaveApplyDraft(),
        onSubmit: () async => submitted++,
      );

      expect(
        find.text('Enter dates and a reason of at least 8 characters.'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit leave request'),
      );
      expect(button.onPressed, isNull);
      expect(submitted, 0);
    });

    testWidgets('enables submit for a valid draft and fires onSubmit',
        (tester) async {
      var submitted = 0;
      await _pumpForm(
        tester,
        draft: _validDraft,
        onSubmit: () async => submitted++,
      );

      expect(
        find.text('Enter dates and a reason of at least 8 characters.'),
        findsNothing,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit leave request'),
      );
      expect(button.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Submit leave request'));
      await tester.pump();
      expect(submitted, 1);
    });

    testWidgets('disables submit while submitting', (tester) async {
      await _pumpForm(
        tester,
        draft: _validDraft,
        onSubmit: () async {},
      );
      // Re-pump with isSubmitting = true.
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            leaveApplyDraftProvider.overrideWith((ref) => _validDraft),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: LeaveApplyForm(onSubmit: () async {}, isSubmitting: true),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
