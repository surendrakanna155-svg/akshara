import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/utils/phone_call_launcher.dart';
import 'admissions_journey_context_provider.dart';
import 'admissions_models.dart';
import 'admissions_mutations_provider.dart';
import 'admissions_requests.dart';
import 'enrollment/admissions_offer_letter_pdf_service.dart';
import 'leads/admissions_lead_detail_provider.dart';
import 'leads/admissions_leads_provider.dart';
import 'leads/widgets/admissions_create_lead_dialog.dart';

/// Refreshes the lead detail timeline/follow-up history and the leads list so
/// a CRM mutation is reflected immediately from the backend.
void _refreshLead(WidgetRef ref, String leadId) {
  ref.invalidate(admissionsLeadDetailDataProvider(leadId));
  ref.invalidate(admissionsLeadsFutureProvider);
}

Future<void> showCreateLeadDialog(BuildContext context, WidgetRef ref) async {
  // ADM-D2: the dialog runs a warn-only duplicate-phone check on blur.
  final result = await showDialog<CreateLeadDialogResult>(
    context: context,
    builder: (context) => const AdmissionsCreateLeadDialog(),
  );

  if (result == null || !context.mounted) return;

  try {
    final lead = await ref.read(createLeadProvider.notifier).execute(
          CreateLeadRequest(
            parentName: result.parentName,
            studentName: result.studentName,
            classLabel: result.classLabel,
            phone: result.phone,
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

// ─── ADM-2: auto-log a WhatsApp contact onto the lead timeline ───────────────

/// Silently records a `whatsapp` activity on the lead timeline after the
/// operator opens WhatsApp from the contact button. Best-effort: a logging
/// failure never blocks the (already-opened) WhatsApp deep link, and the manual
/// "Log WhatsApp" dialog remains as an explicit fallback.
Future<void> autoLogWhatsAppNote(
  WidgetRef ref, {
  required String leadId,
  required String studentName,
}) async {
  try {
    await ref.read(addLeadNoteProvider.notifier).execute(
          leadId: leadId,
          request: LeadNoteRequest(
            content: 'WhatsApp message sent to parent of $studentName.',
            activityType: 'whatsapp',
          ),
        );
    _refreshLead(ref, leadId);
  } catch (_) {
    // Non-blocking: the WhatsApp chat is already open; a timeline write failure
    // must not surface as an error here.
  }
}

// ─── ADM-D1: mark lead lost with a fixed-picklist reason ─────────────────────

Future<void> showMarkLeadLostDialog(
  BuildContext context,
  WidgetRef ref,
  AdmissionsLead lead,
) async {
  var selected = LeadLostReason.feesHigh;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Mark lead lost'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reason for losing ${lead.studentName}:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            DropdownButton<LeadLostReason>(
              value: selected,
              isExpanded: true,
              items: [
                for (final reason in LeadLostReason.values)
                  DropdownMenuItem(
                    value: reason,
                    child: Text(reason.label),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => selected = value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.admissionsMarkLostConfirmButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mark lost'),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(markLeadLostProvider.notifier).execute(
          leadId: lead.id,
          request: MarkLeadLostRequest(reason: selected),
        );
    _refreshLead(ref, lead.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.admissionsMarkLostSnackbar,
        content: Text('Lead marked lost — ${selected.label}'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

// ─── ADM-4: follow-up complete / reschedule / call (dashboard) ───────────────

Future<void> runCompleteFollowUp(
  BuildContext context,
  WidgetRef ref, {
  required String leadId,
  required String followUpId,
  String outcome = '',
}) async {
  try {
    await ref.read(completeFollowUpProvider.notifier).execute(
          leadId: leadId,
          followUpId: followUpId,
          request: CompleteFollowUpRequest(outcome: outcome),
        );
    _refreshLead(ref, leadId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: QaTestKeys.admissionsFollowUpActionSnackbar,
        content: Text('Follow-up completed'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

Future<void> showRescheduleFollowUpDialog(
  BuildContext context,
  WidgetRef ref, {
  required String leadId,
  required String followUpId,
}) async {
  final controller = TextEditingController(text: 'Tomorrow 10:00 AM');
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Reschedule follow-up'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: 'New schedule'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.admissionsFollowUpRescheduleButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Reschedule'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(rescheduleFollowUpProvider.notifier).execute(
          leadId: leadId,
          followUpId: followUpId,
          request:
              RescheduleFollowUpRequest(scheduledLabel: controller.text.trim()),
        );
    _refreshLead(ref, leadId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: QaTestKeys.admissionsFollowUpActionSnackbar,
        content: Text('Follow-up rescheduled'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

/// ADM-4: opens the native dialer for a lead's phone (no logging — the call is
/// placed by the OS).
Future<void> runCallPhone(
  BuildContext context,
  String phone,
) async {
  final opened = await PhoneCallLauncher.dial(phone);
  if (!context.mounted || opened) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('No dialable number for this contact.')),
  );
}

/// ADM-4: bottom sheet for a dashboard follow-up — Complete / Reschedule / Call.
///
/// The dashboard's "due today" rows are lead-derived, so [followUp] carries a
/// lead id (`resolvedLeadId`) but not a concrete follow-up id or phone. This
/// sheet resolves the lead's detail on demand to find the latest *pending*
/// follow-up (for complete/reschedule) and the parent's phone (for call).
Future<void> showFollowUpActionSheet(
  BuildContext context,
  WidgetRef ref,
  AdmissionsFollowUp followUp,
) async {
  final leadId = followUp.resolvedLeadId;
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Follow-up · ${followUp.leadName}',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
          ),
          ListTile(
            key: QaTestKeys.admissionsFollowUpCompleteButton,
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('Complete'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _completeLatestFollowUp(context, ref, leadId);
            },
          ),
          ListTile(
            key: QaTestKeys.admissionsFollowUpRescheduleButton,
            leading: const Icon(Icons.event_repeat_outlined),
            title: const Text('Reschedule'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _rescheduleLatestFollowUp(context, ref, leadId);
            },
          ),
          ListTile(
            key: QaTestKeys.admissionsFollowUpCallButton,
            leading: const Icon(Icons.call_outlined),
            title: const Text('Call'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _callLeadFromDashboard(context, ref, leadId);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Resolves the lead's latest pending follow-up id, or null if none exists.
Future<String?> _latestPendingFollowUpId(WidgetRef ref, String leadId) async {
  final detail = await ref.read(admissionsLeadDetailDataProvider(leadId).future);
  for (final record in detail.followUpHistory) {
    if (record.status == FollowUpStatus.pending && record.id.isNotEmpty) {
      return record.id;
    }
  }
  return null;
}

Future<void> _completeLatestFollowUp(
  BuildContext context,
  WidgetRef ref,
  String leadId,
) async {
  try {
    final followUpId = await _latestPendingFollowUpId(ref, leadId);
    if (followUpId == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No open follow-up to complete.')),
      );
      return;
    }
    if (!context.mounted) return;
    await runCompleteFollowUp(
      context,
      ref,
      leadId: leadId,
      followUpId: followUpId,
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

Future<void> _rescheduleLatestFollowUp(
  BuildContext context,
  WidgetRef ref,
  String leadId,
) async {
  try {
    final followUpId = await _latestPendingFollowUpId(ref, leadId);
    if (followUpId == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No open follow-up to reschedule.')),
      );
      return;
    }
    if (!context.mounted) return;
    await showRescheduleFollowUpDialog(
      context,
      ref,
      leadId: leadId,
      followUpId: followUpId,
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

Future<void> _callLeadFromDashboard(
  BuildContext context,
  WidgetRef ref,
  String leadId,
) async {
  try {
    final detail =
        await ref.read(admissionsLeadDetailDataProvider(leadId).future);
    if (!context.mounted) return;
    await runCallPhone(context, detail.lead.phone);
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

// ─── ADM-3: bulk lead actions (assign counselor / change stage) ──────────────

Future<void> showBulkAssignDialog(
  BuildContext context,
  WidgetRef ref,
  List<String> leadIds,
) async {
  final controller = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Assign ${leadIds.length} lead(s)'),
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
  final counselor = controller.text.trim();
  if (counselor.isEmpty) return;

  await _runBulkAction(
    context,
    ref,
    BulkLeadActionRequest.assign(leadIds: leadIds, counselor: counselor),
  );
}

Future<void> showBulkStageDialog(
  BuildContext context,
  WidgetRef ref,
  List<String> leadIds,
) async {
  var selected = LeadStage.contacted;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Change stage · ${leadIds.length} lead(s)'),
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

  await _runBulkAction(
    context,
    ref,
    BulkLeadActionRequest.stage(leadIds: leadIds, stage: selected),
  );
}

Future<void> _runBulkAction(
  BuildContext context,
  WidgetRef ref,
  BulkLeadActionRequest request,
) async {
  try {
    final result =
        await ref.read(bulkLeadActionProvider.notifier).execute(request);
    // Clear the selection once the batch resolves so the bar collapses.
    ref.read(admissionsSelectedLeadsProvider.notifier).state = <String>{};
    if (!context.mounted || result == null) return;
    final summary = result.skippedCount == 0
        ? 'Updated ${result.updatedCount} lead(s)'
        : 'Updated ${result.updatedCount}, skipped ${result.skippedCount}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.admissionsBulkActionSnackbar,
        content: Text(summary),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, ref, error);
  }
}

// ─── ADM-D4: generate + share/print an offer letter for an enrollment ────────

Future<void> runGenerateOfferLetter(
  BuildContext context,
  WidgetRef ref, {
  required String enrollmentId,
}) async {
  try {
    final data = await ref
        .read(admissionsOfferLetterProvider(enrollmentId).future);
    const service = AdmissionsOfferLetterPdfService();
    final bytes = await service.buildOfferLetterPdf(data: data);
    await service.printOfferLetter(bytes);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.admissionsOfferLetterSnackbar,
        content: Text('Offer letter ready for ${data.studentName}'),
      ),
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
