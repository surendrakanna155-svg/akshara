import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/academics/exam_admin/exam_marks_entry_provider.dart';
import 'package:akshara_erp/features/management/approval/widgets/approval_unsubmitted_marks_card.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// PRI-2 — the Principal Approval Center "unsubmitted marks" exception card.
// The feature (widget + wiring into the Approval Center) shipped in C10/C18;
// these close the verified test-coverage gap on its three behaviours: it renders
// only for an exam viewer, only when marks are actually pending, and reuses the
// EXM-2 progress feed. Read-only — it never touches approvals or money.

MarksEntryProgress _progress({
  String examId = 'e1',
  String title = 'Unit Test 1',
  int entered = 10,
  int total = 30,
}) =>
    MarksEntryProgress(
      examId: examId,
      title: title,
      subject: 'Math',
      grade: '8',
      sectionName: 'A',
      enteredCount: entered,
      totalCount: total,
    );

Future<void> _pumpCard(
  WidgetTester tester, {
  required ErpRole role,
  required List<MarksEntryProgress> progress,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userPermissionsProvider
            .overrideWithValue(UserPermissions.forRole(role)),
        examMarksEntryProgressProvider.overrideWith((ref) async => progress),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const Scaffold(body: ApprovalUnsubmittedMarksCard()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PRI-2 ApprovalUnsubmittedMarksCard', () {
    testWidgets('renders for an exam viewer when marks are pending',
        (tester) async {
      await _pumpCard(
        tester,
        role: ErpRole.superAdmin,
        progress: [_progress(entered: 10, total: 30)], // 20 pending
      );

      expect(find.byKey(QaTestKeys.approvalUnsubmittedMarksCard), findsOneWidget);
      expect(find.text('Unsubmitted marks'), findsOneWidget);
      // Singular exam wording + the aggregated pending count.
      expect(find.textContaining('1 exam awaiting marks'), findsOneWidget);
      expect(find.textContaining('20 entries pending'), findsOneWidget);
    });

    testWidgets('stays hidden when every exam is complete (pending == 0)',
        (tester) async {
      await _pumpCard(
        tester,
        role: ErpRole.superAdmin,
        progress: [_progress(entered: 30, total: 30)], // 0 pending
      );

      expect(find.byKey(QaTestKeys.approvalUnsubmittedMarksCard), findsNothing);
    });

    testWidgets('stays hidden for a role without exam-view permission',
        (tester) async {
      await _pumpCard(
        tester,
        role: ErpRole.parent, // no viewExams / verifyExamResults
        progress: [_progress(entered: 10, total: 30)],
      );

      expect(find.byKey(QaTestKeys.approvalUnsubmittedMarksCard), findsNothing);
    });
  });
}
