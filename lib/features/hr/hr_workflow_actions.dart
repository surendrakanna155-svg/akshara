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
