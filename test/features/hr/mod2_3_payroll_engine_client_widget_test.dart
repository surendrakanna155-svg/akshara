import 'package:akshara_erp/core/repositories/mock/mock_hr_write_store.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/auth_provider.dart' show kMockTeacherName;
import 'package:akshara_erp/features/hr/hr_models.dart';
import 'package:akshara_erp/features/hr/hr_mutations_provider.dart';
import 'package:akshara_erp/features/hr/hr_requests.dart';
import 'package:akshara_erp/features/hr/hr_workflow_actions.dart';
import 'package:akshara_erp/features/hr/leave/hr_leave_screen.dart';
import 'package:akshara_erp/features/hr/payroll/hr_payroll_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// P1-CODE-5 · MOD-2 (client) — the payroll ENGINE workflow: define a salary
/// structure → generate a draft run → process it, all against the real
/// demo-backed mock write store (no stubbed mutations for the flow test).
/// P1-CODE-5 · MOD-3 (client) — the "New leave request" dialog picks a REAL
/// employee, so the submitted employeeId always matches the selected name
/// (previously the id was hardcoded to HR-EMP-102 with a free-text name).

/// Records generate-run calls and returns a deterministic draft run.
class _RecordingGenerateRun extends GenerateHrPayrollRunNotifier {
  final List<GenerateHrPayrollRunRequest> calls = [];

  @override
  Future<HrPayrollRun?> execute(GenerateHrPayrollRunRequest request) async {
    calls.add(request);
    return HrPayrollRun(
      id: request.runId,
      period: request.period,
      employeeCount: 3,
      grossAmount: '₹1,35,000',
      netAmount: '₹1,29,000',
      status: HrPayrollStatus.draft,
      processedOn: '—',
    );
  }
}

/// Records create-leave calls and returns a deterministic result.
class _RecordingCreateLeave extends CreateHrLeaveNotifier {
  final List<CreateHrLeaveRequest> calls = [];

  @override
  Future<HrLeaveRequest?> execute(CreateHrLeaveRequest request) async {
    calls.add(request);
    return HrLeaveRequest(
      id: 'lv_req_new',
      employeeId: request.employeeId,
      employeeName: request.employeeName,
      department: request.department,
      leaveType: request.leaveType,
      fromDate: request.fromDate,
      toDate: request.toDate,
      days: request.days,
      status: HrLeaveStatus.pending,
      approver: request.approver,
      reason: request.reason,
    );
  }
}

Future<void> _pumpHr(
  WidgetTester tester,
  Widget screen, {
  Size viewport = const Size(1440, 900),
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
  setUp(() => MockHrWriteStore.instance.reset());

  test('payrollRunIdForPeriod derives a stable slug id', () {
    expect(payrollRunIdForPeriod('July 2026'), 'pay_run_july_2026');
    expect(payrollRunIdForPeriod('  July   2026 '), 'pay_run_july_2026');
    expect(payrollRunIdForPeriod('2026-07'), 'pay_run_2026_07');
  });

  group('MOD-2 · payroll engine actions', () {
    testWidgets('renders structure + generate + process actions', (tester) async {
      await _pumpHr(tester, const HrPayrollScreen());

      expect(find.byKey(QaTestKeys.hrSalaryStructureButton), findsOneWidget);
      expect(find.byKey(QaTestKeys.hrGeneratePayrollRunButton), findsOneWidget);
      expect(find.byKey(QaTestKeys.hrProcessPayrollButton), findsOneWidget);
    });

    testWidgets(
        'structure → generate → process flow against the real mock store',
        (tester) async {
      await _pumpHr(tester, const HrPayrollScreen());

      // 1 — Save a salary structure for the default-selected first employee
      // (Priya Sharma, HR-EMP-101).
      await tester.tap(find.byKey(QaTestKeys.hrSalaryStructureButton));
      await tester.pumpAndSettle();
      expect(find.text('Salary structure'), findsWidgets);
      await tester.enterText(
          find.widgetWithText(TextField, 'Basic pay (₹/month)'), '40000');
      await tester.enterText(
          find.widgetWithText(TextField, 'Allowances (₹/month)'), '5000');
      await tester.enterText(
          find.widgetWithText(TextField, 'Deductions (₹/month)'), '2000');
      await tester
          .tap(find.byKey(QaTestKeys.hrSalaryStructureDialogSubmitButton));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.hrSalaryStructureSuccessSnackbar),
        findsOneWidget,
      );
      final stored = MockHrWriteStore.instance.salaryStructures['HR-EMP-101'];
      expect(stored, isNotNull);
      expect(stored!.employeeName, kMockTeacherName);
      expect(stored.netPay, 43000);

      // Let the structure snackbar expire so the next one can display
      // (ScaffoldMessenger queues snackbars).
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // 2 — Generate a draft run for an explicit period.
      await tester.tap(find.byKey(QaTestKeys.hrGeneratePayrollRunButton));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Period (e.g. July 2026)'),
          'August 2026');
      await tester
          .tap(find.byKey(QaTestKeys.hrGeneratePayrollRunDialogSubmitButton));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.hrPayrollRunGeneratedSnackbar),
        findsOneWidget,
      );
      final generated =
          MockHrWriteStore.instance.generatedRuns['pay_run_august_2026'];
      expect(generated, isNotNull);
      expect(generated!.status, HrPayrollStatus.draft);
      expect(generated.employeeCount, 1);
      // The generated run + its money-safe entry surface on the screen.
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('August 2026'), findsWidgets);
      expect(find.text('₹43,000'), findsWidgets); // 40000 + 5000 − 2000

      // Let the generate snackbar expire before the process snackbar queues.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // 3 — Process the first draft (the seeded June 2026 run comes first).
      await tester.tap(find.byKey(QaTestKeys.hrProcessPayrollButton));
      await tester.pumpAndSettle();
      expect(find.text('Process payroll run'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Process'));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.hrPayrollProcessedSnackbar),
        findsOneWidget,
      );
      expect(
        MockHrWriteStore.instance.payrollRunStatuses['pay_run_2'],
        HrPayrollStatus.processed,
      );
    });

    testWidgets('generate dialog sends the derived run id for the period',
        (tester) async {
      final recorder = _RecordingGenerateRun();
      await _pumpHr(
        tester,
        const HrPayrollScreen(),
        overrides: [
          generateHrPayrollRunProvider.overrideWith(() => recorder),
        ],
      );

      await tester.tap(find.byKey(QaTestKeys.hrGeneratePayrollRunButton));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Period (e.g. July 2026)'),
          'September 2026');
      await tester
          .tap(find.byKey(QaTestKeys.hrGeneratePayrollRunDialogSubmitButton));
      await tester.pumpAndSettle();

      expect(recorder.calls.length, 1);
      expect(recorder.calls.single.runId, 'pay_run_september_2026');
      expect(recorder.calls.single.period, 'September 2026');
      expect(
        find.byKey(QaTestKeys.hrPayrollRunGeneratedSnackbar),
        findsOneWidget,
      );
    });
  });

  group('MOD-3 · leave dialog uses a real employee id', () {
    testWidgets('default selection submits the FIRST employee\'s real id',
        (tester) async {
      final recorder = _RecordingCreateLeave();
      await _pumpHr(
        tester,
        const HrLeaveScreen(),
        overrides: [
          createHrLeaveProvider.overrideWith(() => recorder),
        ],
      );

      await tester.tap(find.byKey(QaTestKeys.hrCreateLeaveButton));
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.hrLeaveEmployeePicker), findsOneWidget);
      // The old free-text "Employee name" field is gone (MOD-3).
      expect(find.widgetWithText(TextField, 'Employee name'), findsNothing);

      await tester.enterText(
          find.widgetWithText(TextField, 'From date (YYYY-MM-DD)'),
          '2026-07-10');
      await tester.enterText(
          find.widgetWithText(TextField, 'To date (YYYY-MM-DD)'), '2026-07-11');
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();

      expect(recorder.calls.length, 1);
      expect(recorder.calls.single.employeeId, 'HR-EMP-101');
      expect(recorder.calls.single.employeeName, kMockTeacherName);
      expect(find.byKey(QaTestKeys.hrLeaveSuccessSnackbar), findsOneWidget);
    });

    testWidgets('picking a different employee submits THAT employee\'s id',
        (tester) async {
      final recorder = _RecordingCreateLeave();
      await _pumpHr(
        tester,
        const HrLeaveScreen(),
        overrides: [
          createHrLeaveProvider.overrideWith(() => recorder),
        ],
      );

      await tester.tap(find.byKey(QaTestKeys.hrCreateLeaveButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(QaTestKeys.hrLeaveEmployeePicker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mrs. Rao').last);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'From date (YYYY-MM-DD)'),
          '2026-07-10');
      await tester.enterText(
          find.widgetWithText(TextField, 'To date (YYYY-MM-DD)'), '2026-07-11');
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();

      expect(recorder.calls.length, 1);
      expect(recorder.calls.single.employeeId, 'HR-EMP-102');
      expect(recorder.calls.single.employeeName, 'Mrs. Rao');
    });
  });
}
