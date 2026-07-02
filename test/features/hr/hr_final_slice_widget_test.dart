import 'package:akshara_erp/core/config/leave_approval_config.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/hr/hr_models.dart';
import 'package:akshara_erp/features/hr/hr_mutations_provider.dart';
import 'package:akshara_erp/features/hr/hr_requests.dart';
import 'package:akshara_erp/features/hr/leave/hr_leave_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// Final HR slice widget tests:
///   HR-3  multi-select batch approve/reject bar (leave screen)
///   HR-D3 apply-leave-on-behalf dialog with the half-day option
///
/// Mutations are recorded via thin notifier subclasses that return deterministic
/// results (no audit / broadcast side-effects), so the assertion is on a real
/// fired mutation, not a stub.

class _RecordingBatchDecide extends BatchDecideHrLeaveNotifier {
  final List<BatchDecideHrLeaveRequest> calls = [];

  @override
  Future<HrBatchLeaveDecision?> execute(BatchDecideHrLeaveRequest request) async {
    calls.add(request);
    return HrBatchLeaveDecision(
      decided: request.ids,
      skipped: const [],
    );
  }
}

class _RecordingCreateLeave extends CreateHrLeaveNotifier {
  final List<CreateHrLeaveRequest> calls = [];

  @override
  Future<HrLeaveRequest?> execute(CreateHrLeaveRequest request) async {
    calls.add(request);
    return HrLeaveRequest(
      id: 'lv_on_behalf',
      employeeId: request.employeeId,
      employeeName: request.employeeName,
      department: request.department,
      leaveType: request.leaveType,
      fromDate: request.fromDate,
      toDate: request.toDate,
      days: request.halfDay ? 1 : request.days,
      status: HrLeaveStatus.pending,
      approver: request.approver,
      reason: request.reason,
    );
  }
}

Future<void> _pumpHr(
  WidgetTester tester,
  Widget screen, {
  Size viewport = const Size(600, 1400),
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('HR-3 · multi-select batch decide', () {
    testWidgets('selecting a pending row reveals the batch bar', (tester) async {
      await _pumpHr(
        tester,
        const HrLeaveScreen(),
        overrides: [
          leaveApprovalRequiredProvider.overrideWith((ref) => false),
        ],
      );

      // No selection yet → no batch bar.
      expect(find.byKey(QaTestKeys.hrBatchApproveButton), findsNothing);

      // Tick the pending demo request lv_req_1's checkbox.
      final checkbox = find.byKey(QaTestKeys.hrLeaveSelectCheckbox('lv_req_1'));
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // Batch bar appears with both actions.
      expect(find.byKey(QaTestKeys.hrBatchApproveButton), findsOneWidget);
      expect(find.byKey(QaTestKeys.hrBatchRejectButton), findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('batch approve → comment dialog → confirm fires batch mutation',
        (tester) async {
      final recorder = _RecordingBatchDecide();
      await _pumpHr(
        tester,
        const HrLeaveScreen(),
        overrides: [
          leaveApprovalRequiredProvider.overrideWith((ref) => false),
          batchDecideHrLeaveProvider.overrideWith(() => recorder),
        ],
      );

      // Select two pending demo rows.
      for (final id in ['lv_req_1', 'lv_req_2']) {
        final checkbox = find.byKey(QaTestKeys.hrLeaveSelectCheckbox(id));
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
      }
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.byKey(QaTestKeys.hrBatchApproveButton));
      await tester.pumpAndSettle();

      // Comment dialog opens; confirm.
      expect(find.text('Approve leave'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
      await tester.pumpAndSettle();

      expect(recorder.calls.length, 1);
      expect(recorder.calls.single.approve, isTrue);
      expect(
        recorder.calls.single.ids.toSet(),
        {'lv_req_1', 'lv_req_2'},
      );
      expect(find.byKey(QaTestKeys.hrBatchDecideSnackbar), findsOneWidget);
    });
  });

  group('HR-D3 · apply leave on behalf (half-day)', () {
    testWidgets('on-behalf dialog renders the half-day option', (tester) async {
      await _pumpHr(tester, const HrLeaveScreen());

      await tester.tap(find.byKey(QaTestKeys.hrApplyOnBehalfButton));
      await tester.pumpAndSettle();

      expect(find.text('Apply leave on behalf'), findsOneWidget);
      expect(find.byKey(QaTestKeys.hrOnBehalfHalfDayCheckbox), findsOneWidget);
      expect(find.byKey(QaTestKeys.hrOnBehalfSubmitButton), findsOneWidget);
    });

    testWidgets('submitting on-behalf half-day fires create with the flags set',
        (tester) async {
      final recorder = _RecordingCreateLeave();
      await _pumpHr(
        tester,
        const HrLeaveScreen(),
        overrides: [
          createHrLeaveProvider.overrideWith(() => recorder),
        ],
      );

      await tester.tap(find.byKey(QaTestKeys.hrApplyOnBehalfButton));
      await tester.pumpAndSettle();

      // Tick the half-day checkbox.
      await tester.tap(find.byKey(QaTestKeys.hrOnBehalfHalfDayCheckbox));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'From date (YYYY-MM-DD)'),
        '2026-07-05',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'To date (YYYY-MM-DD)'),
        '2026-07-05',
      );
      await tester.ensureVisible(find.byKey(QaTestKeys.hrOnBehalfSubmitButton));
      await tester.tap(find.byKey(QaTestKeys.hrOnBehalfSubmitButton));
      await tester.pumpAndSettle();

      expect(recorder.calls.length, 1);
      final call = recorder.calls.single;
      expect(call.onBehalf, isTrue);
      expect(call.halfDay, isTrue);
      expect(call.override, isFalse); // first attempt is never an override
      expect(find.byKey(QaTestKeys.hrOnBehalfSuccessSnackbar), findsOneWidget);
    });
  });
}
