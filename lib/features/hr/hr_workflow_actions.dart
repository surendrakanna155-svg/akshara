import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../shared/forms/akshara_date_field.dart';
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

/// Loads the HR employee list for pickers on screens that don't watch it
/// (leave + payroll), so the dialogs always have real employees to choose from.
Future<List<HrEmployee>> _loadHrEmployeesForPicker(WidgetRef ref) async {
  final employees = ref.read(hrEmployeesProvider);
  if (employees.isNotEmpty) return employees;
  final page = await ref.read(hrEmployeesFutureProvider.future);
  return page.items;
}

Future<void> showCreateHrLeaveDialog(BuildContext context, WidgetRef ref) async {
  // MOD-3 — a real employee picker (the old free-text name field paired with a
  // hardcoded employeeId, so the saved leave never matched the typed name).
  final employees = await _loadHrEmployeesForPicker(ref);
  if (!context.mounted) return;
  final reasonController = TextEditingController();
  final fromController = TextEditingController();
  final toController = TextEditingController();
  final daysController = TextEditingController(text: '1');
  HrEmployee? employee = employees.isNotEmpty ? employees.first : null;
  var department = employee?.department ?? HrDepartment.academics;
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
              DropdownButtonFormField<HrEmployee>(
                key: QaTestKeys.hrLeaveEmployeePicker,
                initialValue: employee,
                decoration: const InputDecoration(labelText: 'Employee'),
                items: [
                  for (final e in employees)
                    DropdownMenuItem(value: e, child: Text(e.name)),
                ],
                onChanged: (v) => setState(() {
                  employee = v ?? employee;
                  department = employee?.department ?? department;
                }),
              ),
              DropdownButtonFormField<HrDepartment>(
                key: ValueKey<HrDepartment>(department),
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
              AksharaDateField(
                controller: fromController,
                labelText: 'From date',
              ),
              AksharaDateField(
                controller: toController,
                labelText: 'To date',
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
  final selected = employee;
  if (selected == null) return;

  try {
    await ref.read(createHrLeaveProvider.notifier).execute(
          CreateHrLeaveRequest(
            employeeId: selected.id,
            employeeName: selected.name,
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
        content: Text('Leave request submitted for ${selected.name}'),
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
  final employees = await _loadHrEmployeesForPicker(ref);
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
              AksharaDateField(
                controller: fromController,
                labelText: 'From date',
              ),
              AksharaDateField(
                controller: toController,
                labelText: 'To date',
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

/// MOD-2 — define/update an employee's monthly salary structure (the payroll
/// engine's input). Money guards (basic > 0, non-negative net) are enforced by
/// the backend (422 SALARY_STRUCTURE_INVALID); the dialog only requires
/// parseable numbers so errors surface through the standard failure snackbar.
Future<void> showUpsertSalaryStructureDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final employees = await _loadHrEmployeesForPicker(ref);
  if (!context.mounted) return;
  final basicController = TextEditingController();
  final allowancesController = TextEditingController(text: '0');
  final deductionsController = TextEditingController(text: '0');
  HrEmployee? employee = employees.isNotEmpty ? employees.first : null;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Salary structure'),
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
              TextField(
                controller: basicController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Basic pay (₹/month)'),
              ),
              TextField(
                controller: allowancesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Allowances (₹/month)'),
              ),
              TextField(
                controller: deductionsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Deductions (₹/month)'),
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
            key: QaTestKeys.hrSalaryStructureDialogSubmitButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;
  final selected = employee;
  if (selected == null) return;

  try {
    final saved =
        await ref.read(upsertHrSalaryStructureProvider.notifier).execute(
              UpsertHrSalaryStructureRequest(
                employeeId: selected.id,
                employeeCode: selected.employeeCode,
                employeeName: selected.name,
                department: selected.department,
                basicPay: double.tryParse(basicController.text.trim()) ?? 0,
                allowances:
                    double.tryParse(allowancesController.text.trim()) ?? 0,
                deductions:
                    double.tryParse(deductionsController.text.trim()) ?? 0,
              ),
            );
    if (!context.mounted || saved == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hrSalaryStructureSuccessSnackbar,
        content: Text('Salary structure saved for ${saved.employeeName}'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(aksharaErrorMessage(error))),
    );
  }
}

/// MOD-2 — generate a DRAFT payroll run for a period from the stored salary
/// structures. The run id is derived from the period so regenerating the same
/// period is the backend's idempotent draft-regenerate (a processed run is
/// refused with 409).
Future<void> showGeneratePayrollRunDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final periodController = TextEditingController(text: _currentPayrollPeriod());

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Generate payroll run'),
      content: TextField(
        controller: periodController,
        decoration: const InputDecoration(
          labelText: 'Period (e.g. July 2026)',
          helperText: 'A draft run is generated from the saved salary structures.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.hrGeneratePayrollRunDialogSubmitButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Generate draft'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;
  final period = periodController.text.trim();
  if (period.isEmpty) return;

  try {
    final run = await ref.read(generateHrPayrollRunProvider.notifier).execute(
          GenerateHrPayrollRunRequest(
            runId: payrollRunIdForPeriod(period),
            period: period,
          ),
        );
    if (!context.mounted || run == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hrPayrollRunGeneratedSnackbar,
        content: Text(
          'Draft payroll run generated for ${run.period} '
          '(${run.employeeCount} employees)',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(aksharaErrorMessage(error))),
    );
  }
}

/// Deterministic run id for a period ("July 2026" → pay_run_july_2026) so
/// regenerating a period hits the backend's idempotent draft-regenerate path.
String payrollRunIdForPeriod(String period) {
  final slug = period
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return 'pay_run_$slug';
}

String _currentPayrollPeriod() {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final now = DateTime.now();
  return '${months[now.month - 1]} ${now.year}';
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
      content: AksharaDateField(
        controller: dateController,
        labelText: 'New probation end date',
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
