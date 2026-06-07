import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import 'admissions_models.dart';
import 'admissions_mutations_provider.dart';
import 'admissions_requests.dart';

Future<void> showCreateLeadDialog(BuildContext context, WidgetRef ref) async {
  final parentController = TextEditingController();
  final studentController = TextEditingController();
  final classController = TextEditingController(text: '5');
  final phoneController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('New lead'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: parentController,
              decoration: const InputDecoration(labelText: 'Parent name'),
            ),
            TextField(
              controller: studentController,
              decoration: const InputDecoration(labelText: 'Student name'),
            ),
            TextField(
              controller: classController,
              decoration: const InputDecoration(labelText: 'Class'),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
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
          child: const Text('Create'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(createLeadProvider.notifier).execute(
          CreateLeadRequest(
            parentName: parentController.text.trim(),
            studentName: studentController.text.trim(),
            classLabel: classController.text.trim(),
            phone: phoneController.text.trim(),
          ),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lead created successfully')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

Future<void> showAssignCounselorDialog(
  BuildContext context,
  WidgetRef ref,
  AdmissionsLead lead,
) async {
  final controller = TextEditingController(text: lead.counselor);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Assign counselor'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: 'Counselor name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Assign'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(assignCounselorProvider.notifier).execute(
          leadId: lead.id,
          request: AssignCounselorRequest(counselor: controller.text.trim()),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Counselor assigned')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

Future<void> showChangeLeadStageDialog(
  BuildContext context,
  WidgetRef ref,
  AdmissionsLead lead,
) async {
  var selected = lead.stage;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Change stage'),
        content: DropdownButton<LeadStage>(
          value: selected,
          isExpanded: true,
          items: [
            for (final stage in LeadStage.values)
              DropdownMenuItem(value: stage, child: Text(stage.label)),
          ],
          onChanged: (value) {
            if (value != null) setState(() => selected = value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Update'),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(changeLeadStageProvider.notifier).execute(
          leadId: lead.id,
          request: ChangeLeadStageRequest(stage: selected),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lead stage updated')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

Future<void> showAddLeadNoteDialog(
  BuildContext context,
  WidgetRef ref,
  String leadId,
) async {
  final controller = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add note'),
      content: TextField(
        controller: controller,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Note'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(addLeadNoteProvider.notifier).execute(
          leadId: leadId,
          request: LeadNoteRequest(content: controller.text.trim()),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note added')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

Future<void> showAddFollowUpDialog(
  BuildContext context,
  WidgetRef ref,
  String leadId,
) async {
  final taskController = TextEditingController();
  final scheduleController = TextEditingController(text: 'Tomorrow 10:00 AM');
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add follow-up'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: taskController,
            decoration: const InputDecoration(labelText: 'Task'),
          ),
          TextField(
            controller: scheduleController,
            decoration: const InputDecoration(labelText: 'Scheduled'),
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
          child: const Text('Add'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(addLeadFollowUpProvider.notifier).execute(
          leadId: leadId,
          request: FollowUpRequest(
            task: taskController.text.trim(),
            scheduledLabel: scheduleController.text.trim(),
          ),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Follow-up added')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

Future<void> runApproveDocument(
  BuildContext context,
  WidgetRef ref,
  String documentId,
) async {
  try {
    await ref.read(approveDocumentProvider.notifier).execute(
          documentId: documentId,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document approved')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

Future<void> runRejectDocument(
  BuildContext context,
  WidgetRef ref,
  String documentId,
) async {
  try {
    await ref.read(rejectDocumentProvider.notifier).execute(
          documentId: documentId,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document rejected')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

Future<void> runApproveAdmission(
  BuildContext context,
  WidgetRef ref,
  String approvalId,
) async {
  try {
    await ref.read(approveAdmissionProvider.notifier).execute(
          approvalId: approvalId,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Admission approved')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

Future<void> runRejectAdmission(
  BuildContext context,
  WidgetRef ref,
  String approvalId,
) async {
  try {
    await ref.read(rejectAdmissionProvider.notifier).execute(
          approvalId: approvalId,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Admission rejected')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

Future<void> runSendToFinance(
  BuildContext context,
  WidgetRef ref, {
  required String handoffId,
  required String feeStructureId,
}) async {
  try {
    await ref.read(sendToFinanceProvider.notifier).execute(
          FinanceHandoffRequest(
            handoffId: handoffId,
            feeStructureId: feeStructureId,
          ),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sent to Finance')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

void _showMutationError(BuildContext context, WidgetRef ref, Object error) {
  final failure = error is ApiFailure
      ? error
      : error is ApiFailureException
          ? error.failure
          : apiFailureMapper.fromException(error);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(failure.displayMessage)),
  );
}
