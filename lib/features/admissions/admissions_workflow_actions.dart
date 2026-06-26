import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import 'admissions_journey_context_provider.dart';
import 'admissions_models.dart';
import 'admissions_mutations_provider.dart';
import 'admissions_requests.dart';
import 'leads/admissions_lead_detail_provider.dart';
import 'leads/admissions_leads_provider.dart';

/// Refreshes the lead detail timeline/follow-up history and the leads list so
/// a CRM mutation is reflected immediately from the backend.
void _refreshLead(WidgetRef ref, String leadId) {
  ref.invalidate(admissionsLeadDetailDataProvider(leadId));
  ref.invalidate(admissionsLeadsFutureProvider);
}

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
              key: QaTestKeys.admissionsLeadParentNameField,
              controller: parentController,
              decoration: const InputDecoration(labelText: 'Parent name'),
            ),
            TextField(
              key: QaTestKeys.admissionsLeadStudentNameField,
              controller: studentController,
              decoration: const InputDecoration(labelText: 'Student name'),
            ),
            TextField(
              key: QaTestKeys.admissionsLeadClassField,
              controller: classController,
              decoration: const InputDecoration(labelText: 'Class'),
            ),
            TextField(
              key: QaTestKeys.admissionsLeadPhoneField,
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
          key: QaTestKeys.admissionsLeadDialogCreateButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Create'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final lead = await ref.read(createLeadProvider.notifier).execute(
          CreateLeadRequest(
            parentName: parentController.text.trim(),
            studentName: studentController.text.trim(),
            classLabel: classController.text.trim(),
            phone: phoneController.text.trim(),
          ),
        );
    if (lead != null) {
      ref.read(admissionsLastCreatedLeadProvider.notifier).state = lead;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.admissionsLeadCreatedSnackbar,
        content: Text('Lead created successfully (${lead?.id ?? ''})'),
      ),
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
    _refreshLead(ref, lead.id);
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
    _refreshLead(ref, lead.id);
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
  String leadId, {
  String activityType = 'note',
  String dialogTitle = 'Add note',
  String fieldLabel = 'Note',
  String successMessage = 'Note added',
}) async {
  final controller = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(dialogTitle),
      content: TextField(
        controller: controller,
        maxLines: 3,
        decoration: InputDecoration(labelText: fieldLabel),
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
          request: LeadNoteRequest(
            content: controller.text.trim(),
            activityType: activityType,
          ),
        );
    _refreshLead(ref, leadId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successMessage)),
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
    _refreshLead(ref, leadId);
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
      const SnackBar(
        key: QaTestKeys.admissionsApprovedSnackbar,
        content: Text('Admission approved'),
      ),
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

/// ADMIS-5: collects document metadata, then uploads a real file to Storage
/// (presign → PUT bytes → confirm) so it is retrievable during verification.
Future<void> showUploadDocumentDialog(
  BuildContext context,
  WidgetRef ref, {
  required String leadId,
  String studentName = '',
  String classLabel = '',
}) async {
  var documentType = DocumentType.birthCertificate;
  final fileController =
      TextEditingController(text: 'birth_certificate.pdf');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Upload document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<DocumentType>(
              value: documentType,
              isExpanded: true,
              items: [
                for (final type in DocumentType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => documentType = value);
              },
            ),
            TextField(
              controller: fileController,
              decoration: const InputDecoration(labelText: 'File name'),
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
            child: const Text('Upload'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final fileName = fileController.text.trim().isEmpty
      ? '${documentType.name}.pdf'
      : fileController.text.trim();

  try {
    final document = await ref.read(uploadDocumentProvider.notifier).execute(
          leadId: leadId,
          documentType: documentType,
          fileName: fileName,
          bytes: _documentBytes(),
          contentType: 'application/pdf',
          studentName: studentName,
          classLabel: classLabel,
        );
    if (!context.mounted || document == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Document uploaded: ${document.documentType.label}')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

/// ADMIS-5: opens the stored file for a document via a short-lived signed URL.
Future<void> runOpenDocument(
  BuildContext context,
  WidgetRef ref,
  String documentId,
) async {
  try {
    final url = await ref
        .read(documentDownloadUrlProvider.notifier)
        .execute(documentId: documentId);
    if (url == null || url.isEmpty) {
      throw const ApiFailure(
        type: ApiFailureType.unknown,
        message: 'No stored file for this document.',
        code: 'NO_DOCUMENT_FILE',
      );
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the document.')),
      );
    }
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

/// Minimal valid single-page PDF payload. Mirrors the device-memories module's
/// synthetic-bytes upload precedent (no OS file picker dependency in the app).
Uint8List _documentBytes() {
  const pdf =
      '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n'
      '2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n'
      '3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]>>endobj\n'
      'trailer<</Root 1 0 R>>\n%%EOF';
  return Uint8List.fromList(pdf.codeUnits);
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
