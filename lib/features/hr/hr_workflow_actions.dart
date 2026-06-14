import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import 'hr_models.dart';
import 'hr_mutations_provider.dart';
import 'hr_requests.dart';

Future<void> showCreateHrLeaveDialog(BuildContext context, WidgetRef ref) async {
  final employeeController = TextEditingController(text: 'Mrs. Rao');
  final reasonController = TextEditingController(text: 'Personal leave');
  final fromController = TextEditingController(text: '2026-06-15');
  final toController = TextEditingController(text: '2026-06-15');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('New leave request'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: employeeController,
            decoration: const InputDecoration(labelText: 'Employee name'),
          ),
          TextField(
            controller: reasonController,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          TextField(
            controller: fromController,
            decoration: const InputDecoration(labelText: 'From date'),
          ),
          TextField(
            controller: toController,
            decoration: const InputDecoration(labelText: 'To date'),
          ),
        ],
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
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(createHrLeaveProvider.notifier).execute(
          CreateHrLeaveRequest(
            employeeId: 'HR-EMP-102',
            employeeName: employeeController.text.trim(),
            department: HrDepartment.academics,
            leaveType: HrLeaveType.casual,
            fromDate: fromController.text.trim(),
            toDate: toController.text.trim(),
            days: 1,
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
      SnackBar(content: Text('$error')),
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
      SnackBar(content: Text('$error')),
    );
  }
}

Future<void> showCreateHrEmployeeDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final nameController = TextEditingController(text: 'QA Staff Member');
  final codeController = TextEditingController(text: 'EMP-900');
  final designationController = TextEditingController(text: 'Office Assistant');
  final emailController = TextEditingController(text: 'qa.staff@akshara.edu');
  final phoneController = TextEditingController(text: '+91 90000 11122');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add employee'),
      content: Column(
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
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final employee = await ref.read(createHrEmployeeProvider.notifier).execute(
          CreateHrEmployeeRequest(
            name: nameController.text.trim(),
            employeeCode: codeController.text.trim(),
            department: HrDepartment.administration,
            role: HrEmployeeRole.staff,
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
      SnackBar(content: Text('$error')),
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
      SnackBar(content: Text('$error')),
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
      SnackBar(content: Text('$error')),
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
      SnackBar(content: Text('$error')),
    );
  }
}
