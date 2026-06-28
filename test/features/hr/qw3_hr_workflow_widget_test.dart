import 'package:akshara_erp/core/config/leave_approval_config.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/hr/employees/hr_employee_profile_screen.dart';
import 'package:akshara_erp/features/hr/employees/hr_employees_screen.dart';
import 'package:akshara_erp/features/hr/hr_models.dart';
import 'package:akshara_erp/features/hr/hr_mutations_provider.dart';
import 'package:akshara_erp/features/hr/hr_providers.dart';
import 'package:akshara_erp/features/hr/hr_requests.dart';
import 'package:akshara_erp/features/hr/leave/hr_leave_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-049 (HR approve-leave button → comment dialog → approve mutation
/// fires; activate/deactivate employee actions render + fire), QA-F-050 (add /
/// edit employee form renders its fields and the submit fires the create
/// mutation).
///
/// HR screens pump cleanly at a desktop viewport without a router (see the
/// existing `hr_screens_test.dart`). The Approve action only renders when
/// `leaveApprovalRequiredProvider` is false (otherwise the unified Approval
/// Center redirect banner shows), so that provider is overridden for the
/// approve-path tests. Mutations are recorded via thin notifier subclasses that
/// delegate to the real demo-backed `execute`, so the assertion is on a real
/// fired mutation, not a stub.

/// Records approve-leave calls and returns a deterministic result (no audit /
/// broadcast side-effects) so the screen's success snackbar surfaces reliably.
class _RecordingApproveLeave extends ApproveHrLeaveNotifier {
  final List<String> approvedIds = [];

  @override
  Future<HrLeaveRequest?> execute({
    required String leaveRequestId,
    required ApproveLeaveRequest request,
  }) async {
    approvedIds.add(leaveRequestId);
    return const HrLeaveRequest(
      id: 'lv_req_1',
      employeeId: 'HR-EMP-108',
      employeeName: 'Sunita Nair',
      department: HrDepartment.academics,
      leaveType: HrLeaveType.sick,
      fromDate: '2026-06-06',
      toDate: '2026-06-08',
      days: 3,
      status: HrLeaveStatus.approved,
      approver: 'Rajesh Iyer',
      reason: 'Medical leave',
    );
  }
}

/// Records create-employee calls and returns a deterministic employee so the
/// screen's "created" snackbar surfaces reliably.
class _RecordingCreateEmployee extends CreateHrEmployeeNotifier {
  final List<CreateHrEmployeeRequest> created = [];

  @override
  Future<HrEmployee?> execute(CreateHrEmployeeRequest request) async {
    created.add(request);
    return HrEmployee(
      id: 'HR-EMP-NEW',
      name: request.name,
      employeeCode: request.employeeCode,
      department: request.department,
      role: request.role,
      designation: request.designation,
      email: request.email,
      phone: request.phone,
      joinDate: '2026-06-28',
      status: HrEmployeeStatus.probation,
    );
  }
}

/// Records set-status calls, then runs the real demo execute.
class _RecordingSetStatus extends SetHrEmployeeStatusNotifier {
  final List<SetHrEmployeeStatusRequest> calls = [];

  @override
  Future<HrEmployee?> execute(SetHrEmployeeStatusRequest request) {
    calls.add(request);
    return super.execute(request);
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
  group('QA-F-049 · HrLeaveScreen approve-leave', () {
    testWidgets('renders the Approve/Reject actions for a pending request',
        (tester) async {
      await _pumpHr(
        tester,
        const HrLeaveScreen(),
        overrides: [
          leaveApprovalRequiredProvider.overrideWith((ref) => false),
        ],
      );

      // lv_req_1 (Sunita Nair) is a pending demo request.
      expect(
        find.byKey(QaTestKeys.hrApproveLeaveButton('lv_req_1')),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.hrRejectLeaveButton('lv_req_1')),
        findsOneWidget,
      );
    });

    testWidgets('approve → comment dialog → confirm fires the approve mutation',
        (tester) async {
      final recorder = _RecordingApproveLeave();
      await _pumpHr(
        tester,
        const HrLeaveScreen(),
        // Card layout (mobile width) renders the Approve/Reject buttons inline,
        // not inside the horizontally-scrolling desktop data table.
        viewport: const Size(600, 1400),
        overrides: [
          leaveApprovalRequiredProvider.overrideWith((ref) => false),
          approveHrLeaveProvider.overrideWith(() => recorder),
        ],
      );

      await tester.ensureVisible(
        find.byKey(QaTestKeys.hrApproveLeaveButton('lv_req_1')),
      );
      await tester.tap(find.byKey(QaTestKeys.hrApproveLeaveButton('lv_req_1')));
      await tester.pumpAndSettle();

      // Comment dialog opens.
      expect(find.text('Approve leave'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Approved by manager');
      await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
      await tester.pumpAndSettle();

      expect(recorder.approvedIds, ['lv_req_1']);
      expect(find.byKey(QaTestKeys.hrLeaveApprovalSnackbar), findsOneWidget);
    });
  });

  group('QA-F-049 · HrEmployeeProfileScreen activate/deactivate', () {
    testWidgets('renders Edit + Deactivate for an active employee',
        (tester) async {
      await _pumpHr(
        tester,
        const HrEmployeeProfileScreen(employeeId: 'HR-EMP-101'),
      );

      expect(
        find.byKey(QaTestKeys.hrEditEmployeeButton('HR-EMP-101')),
        findsOneWidget,
      );
      // Demo employee is active → the Deactivate action is the reachable one.
      expect(
        find.byKey(QaTestKeys.hrDeactivateEmployeeButton('HR-EMP-101')),
        findsOneWidget,
      );
    });

    testWidgets('deactivate fires the set-status mutation', (tester) async {
      final recorder = _RecordingSetStatus();
      await _pumpHr(
        tester,
        const HrEmployeeProfileScreen(employeeId: 'HR-EMP-101'),
        overrides: [
          setHrEmployeeStatusProvider.overrideWith(() => recorder),
        ],
      );

      await tester.tap(
        find.byKey(QaTestKeys.hrDeactivateEmployeeButton('HR-EMP-101')),
      );
      await tester.pumpAndSettle();

      expect(recorder.calls.length, 1);
      expect(recorder.calls.single.employeeId, 'HR-EMP-101');
      expect(recorder.calls.single.status, HrEmployeeStatus.inactive);
    });

    testWidgets('renders the Activate action when the employee is inactive',
        (tester) async {
      // Force an inactive detail so the Activate (rather than Deactivate)
      // branch renders; the real demo seeds no inactive employee.
      final inactive = _inactiveEmployeeDetail('HR-EMP-101');
      await _pumpHr(
        tester,
        const HrEmployeeProfileScreen(employeeId: 'HR-EMP-101'),
        overrides: [
          hrEmployeeDetailProvider('HR-EMP-101').overrideWithValue(inactive),
        ],
      );

      expect(
        find.byKey(QaTestKeys.hrActivateEmployeeButton('HR-EMP-101')),
        findsOneWidget,
      );
    });
  });

  group('QA-F-050 · Add/edit employee form', () {
    testWidgets('Add employee dialog renders its fields', (tester) async {
      await _pumpHr(tester, const HrEmployeesScreen());

      await tester.tap(find.byKey(QaTestKeys.hrCreateEmployeeButton));
      await tester.pumpAndSettle();

      // Dialog open (title also appears on the screen's launch button, so scope
      // the title assertion to the AlertDialog).
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(of: dialog, matching: find.text('Add employee')),
        findsOneWidget,
      );
      // Name / code / designation / email / phone text fields + dept/role
      // dropdowns + the keyed submit button.
      expect(find.widgetWithText(TextField, 'Name'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Employee code'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Phone'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<HrDepartment>), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<HrEmployeeRole>), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.hrCreateEmployeeDialogSubmitButton),
        findsOneWidget,
      );
    });

    testWidgets('submitting a valid employee fires the create mutation',
        (tester) async {
      final recorder = _RecordingCreateEmployee();
      await _pumpHr(
        tester,
        const HrEmployeesScreen(),
        overrides: [
          createHrEmployeeProvider.overrideWith(() => recorder),
        ],
      );

      await tester.tap(find.byKey(QaTestKeys.hrCreateEmployeeButton));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Name'), 'New Teacher');
      await tester.enterText(
          find.widgetWithText(TextField, 'Employee code'), 'EMP-NEW-01');
      await tester.enterText(
          find.widgetWithText(TextField, 'Designation'), 'Science Teacher');
      await tester.enterText(
          find.widgetWithText(TextField, 'Email'), 'new@school.test');
      await tester.enterText(
          find.widgetWithText(TextField, 'Phone'), '9876500001');
      await tester.ensureVisible(
        find.byKey(QaTestKeys.hrCreateEmployeeDialogSubmitButton),
      );
      await tester.tap(find.byKey(QaTestKeys.hrCreateEmployeeDialogSubmitButton));
      await tester.pumpAndSettle();

      expect(recorder.created.length, 1);
      expect(recorder.created.single.name, 'New Teacher');
      expect(recorder.created.single.employeeCode, 'EMP-NEW-01');
      expect(find.byKey(QaTestKeys.hrEmployeeCreatedSnackbar), findsOneWidget);
    });
  });
}

HrEmployeeDetail _inactiveEmployeeDetail(String id) => HrEmployeeDetail(
      employee: HrEmployee(
        id: id,
        name: 'Inactive Staff',
        employeeCode: 'EMP-INACT-01',
        department: HrDepartment.administration,
        role: HrEmployeeRole.staff,
        designation: 'Clerk',
        email: 'inactive@school.test',
        phone: '9876500099',
        joinDate: '2024-01-01',
        status: HrEmployeeStatus.inactive,
      ),
      reportingManager: 'Rajesh Iyer',
      address: '—',
      emergencyContact: '—',
      leaveBalances: const [],
      documents: const [],
      recentAttendance: const [],
      integrationNotes: const [],
    );
