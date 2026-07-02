import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import 'hr_models.dart';
import 'hr_mutations_provider.dart';
import 'hr_providers.dart';
import 'hr_requests.dart';
import '../../core/errors/error_text.dart';

String _hrDepartmentLabel(HrDepartment d) => switch (d) {
      HrDepartment.academics => 'Academics',
      HrDepartment.administration => 'Administration',
      HrDepartment.transport => 'Transport',
      HrDepartment.finance => 'Finance',
      HrDepartment.hr => 'HR',
      HrDepartment.support => 'Support',
    };

String _hrLeaveTypeLabel(HrLeaveType t) => switch (t) {
      HrLeaveType.casual => 'Casual',
      HrLeaveType.sick => 'Sick',
      HrLeaveType.earned => 'Earned',
      HrLeaveType.maternity => 'Maternity',
      HrLeaveType.unpaid => 'Unpaid',
    };

String _hrRoleLabel(HrEmployeeRole r) => switch (r) {
      HrEmployeeRole.teacher => 'Teacher',
      HrEmployeeRole.driver => 'Driver',
      HrEmployeeRole.admin => 'Admin',
      HrEmployeeRole.principal => 'Principal',
      HrEmployeeRole.staff => 'Staff',
    };

Future<void> showCreateHrLeaveDialog(BuildContext context, WidgetRef ref) async {
  final employeeController = TextEditingController();
  final reasonController = TextEditingController();
  final fromController = TextEditingController();
  final toController = TextEditingController();
  final daysController = TextEditingController(text: '1');
  var department = HrDepartment.academics;
  var leaveType = HrLeaveType.casual;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('New leave request'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: employeeController,
                decoration: const InputDecoration(labelText: 'Employee name'),
              ),
              DropdownButtonFormField<HrDepartment>(
                initialValue: department,
                decoration: const InputDecoration(labelText: 'Department'),
                items: [
                  for (final d in HrDepartment.values)
                    DropdownMenuItem(value: d, child: Text(_hrDepartmentLabel(d))),
                ],
                onChanged: (v) => setState(() => department = v ?? department),
              ),
              DropdownButtonFormField<HrLeaveType>(
                initialValue: leaveType,
                decoration: const InputDecoration(labelText: 'Leave type'),
                items: [
                  for (final t in HrLeaveType.values)
                    DropdownMenuItem(value: t, child: Text(_hrLeaveTypeLabel(t))),
                ],
                onChanged: (v) => setState(() => leaveType = v ?? leaveType),
              ),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              TextField(
                controller: fromController,
                decoration: const InputDecoration(
                  labelText: 'From date (YYYY-MM-DD)',
                ),
              ),
              TextField(
                controller: toController,
                decoration: const InputDecoration(
                  labelText: 'To date (YYYY-MM-DD)',
                ),
              ),
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Number of days'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(createHrLeaveProvider.notifier).execute(
          CreateHrLeaveRequest(
            employeeId: 'HR-EMP-102',
            employeeName: employeeController.text.trim(),
            department: department,
            leaveType: leaveType,
            fromDate: fromController.text.trim(),
            toDate: toController.text.trim(),
            days: int.tryParse(daysController.text.trim()) ?? 1,
            reason: reasonController.text.trim(),
          ),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hrLeaveSuccessSnackbar,
        content: Text('Leave request submitted for ${employeeController.text.trim()}'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(aksharaErrorMessage(error))),
    );
  }
}

/// HR-D3 — a manager applies leave FOR an employee, with a half-day option and
/// an over-balance override confirm. The first submit is attempted WITHOUT
/// override; if the backend refuses it as over-balance, the manager is shown an
/// explicit confirm and the request is re-submitted with `override: true`.
Future<void> showApplyLeaveOnBehalfDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  // Ensure the employee list is loaded (the leave screen does not watch it), so
  // the on-behalf picker always has choices.
  var employees = ref.read(hrEmployeesProvider);
  if (employees.isEmpty) {
    final page = await ref.read(hrEmployeesFutureProvider.future);
    employees = page.items;
  }
  if (!context.mounted) return;
  final reasonController = TextEditingController();
  final fromController = TextEditingController();
  final toController = TextEditingController();
  final daysController = TextEditingController(text: '1');
  HrEmployee? employee = employees.isNotEmpty ? employees.first : null;
  var leaveType = HrLeaveType.casual;
  var halfDay = false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Apply leave on behalf'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<HrEmployee>(
                initialValue: employee,
                decoration: const InputDecoration(labelText: 'Employee'),
                items: [
                  for (final e in employees)
                    DropdownMenuItem(value: e, child: Text(e.name)),
                ],
                onChanged: (v) => setState(() => employee = v ?? employee),
              ),
              DropdownButtonFormField<HrLeaveType>(
                initialValue: leaveType,
                decoration: const InputDecoration(labelText: 'Leave type'),
                items: [
                  for (final t in HrLeaveType.values)
                    DropdownMenuItem(value: t, child: Text(_hrLeaveTypeLabel(t))),
                ],
                onChanged: (v) => setState(() => leaveType = v ?? leaveType),
              ),
              TextField(
                controller: fromController,
                decoration: const InputDecoration(
                  labelText: 'From date (YYYY-MM-DD)',
                ),
              ),
              TextField(
                controller: toController,
                decoration: const InputDecoration(
                  labelText: 'To date (YYYY-MM-DD)',
                ),
              ),
              TextField(
                controller: daysController,
                enabled: !halfDay,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Number of days'),
              ),
              CheckboxListTile(
                key: QaTestKeys.hrOnBehalfHalfDayCheckbox,
                value: halfDay,
                onChanged: (v) => setState(() => halfDay = v ?? false),
                title: const Text('Half day'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.hrOnBehalfSubmitButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;
  final selected = employee;
  if (selected == null) return;

  CreateHrLeaveRequest buildRequest({required bool override}) => CreateHrLeaveRequest(
        employeeId: selected.id,
        employeeName: selected.name,
        department: selected.department,
        leaveType: leaveType,
        fromDate: fromController.text.trim(),
        toDate: toController.text.trim(),
        days: int.tryParse(daysController.text.trim()) ?? 1,
        reason: reasonController.text.trim(),
        onBehalf: true,
        halfDay: halfDay,
        override: override,
      );

  Future<bool> submit({required bool override}) async {
    await ref
        .read(createHrLeaveProvider.notifier)
        .execute(buildRequest(override: override));
    return !ref.read(createHrLeaveProvider).hasError;
  }

  final ok = await submit(override: false);
  if (!context.mounted) return;
  if (ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hrOnBehalfSuccessSnackbar,
        content: Text('Leave applied on behalf of ${selected.name}'),
      ),
    );
    return;
  }

  // The first attempt failed — most likely an over-balance refusal. Offer an
  // explicit override confirm and, if accepted, re-submit with override.
  final overrideConfirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Over leave balance'),
      content: Text(
        'This leave exceeds ${selected.name}\'s balance for '
        '${_hrLeaveTypeLabel(leaveType)} leave. Apply anyway with an override? '
        'The override is recorded in the audit log.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.hrOnBehalfOverrideConfirmButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Override & apply'),
        ),
      ],
    ),
  );
  if (overrideConfirmed != true || !context.mounted) return;

  final overrideOk = await submit(override: true);
  if (!context.mounted) return;
  if (overrideOk) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hrOnBehalfSuccessSnackbar,
        content: Text(
          'Leave applied (balance overridden) for ${selected.name}',
        ),
      ),
    );
  } else {
    final error = ref.read(createHrLeaveProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? 'Unable to apply leave on behalf.'
              : aksharaErrorMessage(error),
        ),
      ),
    );
  }
}

Future<void> showProcessPayrollRunDialog(
  BuildContext context,
  WidgetRef ref, {
  required HrPayrollRun run,
}) async {
  if (run.status != HrPayrollStatus.draft) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Process payroll run'),
      content: Text(
        'Process payroll for ${run.period}? '
        'This will mark ${run.employeeCount} employee entries as processed.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Process'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(processHrPayrollRunProvider.notifier).execute(
          ProcessHrPayrollRunRequest(runId: run.id),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hrPayrollProcessedSnackbar,
        content: Text('Payroll processed for ${run.period}'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(aksharaErrorMessage(error))),
    );
  }
}

Future<void> showCreateHrEmployeeDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final nameController = TextEditingController();
  final codeController = TextEditingController();
  final designationController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  var department = HrDepartment.administration;
  var role = HrEmployeeRole.staff;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add employee'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Employee code'),
              ),
              DropdownButtonFormField<HrDepartment>(
                initialValue: department,
                decoration: const InputDecoration(labelText: 'Department'),
                items: [
                  for (final d in HrDepartment.values)
                    DropdownMenuItem(value: d, child: Text(_hrDepartmentLabel(d))),
                ],
                onChanged: (v) => setState(() => department = v ?? department),
              ),
              DropdownButtonFormField<HrEmployeeRole>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final r in HrEmployeeRole.values)
                    DropdownMenuItem(value: r, child: Text(_hrRoleLabel(r))),
                ],
                onChanged: (v) => setState(() => role = v ?? role),
              ),
              TextField(
                controller: designationController,
                decoration: const InputDecoration(labelText: 'Designation'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.hrCreateEmployeeDialogSubmitButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final employee = await ref.read(createHrEmployeeProvider.notifier).execute(
          CreateHrEmployeeRequest(
            name: nameController.text.trim(),
            employeeCode: codeController.text.trim(),
            department: department,
            role: role,
            designation: designationController.text.trim(),
            email: emailController.text.trim(),
            phone: phoneController.text.trim(),
          ),
        );
    if (!context.mounted || employee == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hrEmployeeCreatedSnackbar,
        content: Text('Employee ${employee.name} created'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(aksharaErrorMessage(error))),
    );
  }
}

Future<void> showEditHrEmployeeDialog(
  BuildContext context,
  WidgetRef ref, {
  required HrEmployee employee,
}) async {
  final nameController = TextEditingController(text: employee.name);
  final designationController = TextEditingController(text: employee.designation);
  final phoneController = TextEditingController(text: employee.phone);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit employee'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: designationController,
            decoration: const InputDecoration(labelText: 'Designation'),
          ),
          TextField(
            controller: phoneController,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.hrEditEmployeeDialogSubmitButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final updated = await ref.read(updateHrEmployeeProvider.notifier).execute(
          UpdateHrEmployeeRequest(
            employeeId: employee.id,
            name: nameController.text.trim(),
            designation: designationController.text.trim(),
            phone: phoneController.text.trim(),
            department: employee.department,
          ),
        );
    if (!context.mounted || updated == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hrEmployeeUpdatedSnackbar,
        content: Text('Employee ${updated.name} updated'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(aksharaErrorMessage(error))),
    );
  }
}

/// HR-D2 — confirm an employee off probation (status → active).
Future<void> confirmHrEmployeeProbation(
  BuildContext context,
  WidgetRef ref,
  HrEmployee employee,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm employee'),
      content: Text(
        'Confirm ${employee.name} off probation? Their status becomes Active.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.hrProbationConfirmButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    final updated =
        await ref.read(setHrEmployeeProbationProvider.notifier).execute(
              SetHrEmployeeProbationRequest.confirm(employeeId: employee.id),
            );
    if (!context.mounted || updated == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hrProbationSuccessSnackbar,
        content: Text('${updated.name} confirmed off probation'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(aksharaErrorMessage(error))),
    );
  }
}

/// HR-D2 — extend an employee's probation to a new end date.
Future<void> extendHrEmployeeProbation(
  BuildContext context,
  WidgetRef ref,
  HrEmployee employee, {
  String? currentEndDate,
}) async {
  final dateController = TextEditingController(text: currentEndDate ?? '');
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Extend probation'),
      content: TextField(
        controller: dateController,
        decoration: const InputDecoration(
          labelText: 'New probation end date (YYYY-MM-DD)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.hrProbationExtendButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Extend'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final date = dateController.text.trim();
  if (date.isEmpty) return;

  try {
    final updated =
        await ref.read(setHrEmployeeProbationProvider.notifier).execute(
              SetHrEmployeeProbationRequest.extend(
                employeeId: employee.id,
                probationEndDate: date,
              ),
            );
    if (!context.mounted || updated == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hrProbationSuccessSnackbar,
        content: Text('${updated.name} probation extended to $date'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(aksharaErrorMessage(error))),
    );
  }
}

Future<void> deactivateHrEmployee(
  BuildContext context,
  WidgetRef ref,
  HrEmployee employee,
) async {
  try {
    final updated =
        await ref.read(setHrEmployeeStatusProvider.notifier).execute(
              SetHrEmployeeStatusRequest(
                employeeId: employee.id,
                status: HrEmployeeStatus.inactive,
              ),
            );
    if (!context.mounted || updated == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hrEmployeeStatusSuccessSnackbar,
        content: Text('${updated.name} deactivated'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(aksharaErrorMessage(error))),
    );
  }
}

Future<void> activateHrEmployee(
  BuildContext context,
  WidgetRef ref,
  HrEmployee employee,
) async {
  try {
    final updated =
        await ref.read(setHrEmployeeStatusProvider.notifier).execute(
              SetHrEmployeeStatusRequest(
                employeeId: employee.id,
                status: HrEmployeeStatus.active,
              ),
            );
    if (!context.mounted || updated == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hrEmployeeStatusSuccessSnackbar,
        content: Text('${updated.name} activated'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(aksharaErrorMessage(error))),
    );
  }
}
