import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import 'certificates/sis_certificate_pdf_service.dart';
import 'profile/sis_profile_edit_sheet.dart';
import 'sis_models.dart';
import 'sis_mutations_provider.dart';
import 'sis_requests.dart';
import '../../core/errors/error_text.dart';

Future<void> showSisProfileEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required SisStudentProfile profile,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SisProfileEditSheet(profile: profile),
  );
  if (saved != true || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Student profile updated')),
  );
}

Future<void> showSisDocumentUploadDialog(
  BuildContext context,
  WidgetRef ref, {
  required SisStudentProfile profile,
}) async {
  final typeController = TextEditingController(text: 'Transfer Certificate');
  final fileController =
      TextEditingController(text: 'transfer_certificate.pdf');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Upload student document'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: typeController,
            decoration: const InputDecoration(labelText: 'Document type'),
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
          key: QaTestKeys.sisUploadDocumentSubmitButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Upload'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final document =
        await ref.read(uploadStudentDocumentProvider.notifier).execute(
              studentId: profile.student.id,
              request: UploadStudentDocumentRequest(
                type: typeController.text.trim(),
                fileName: fileController.text.trim(),
              ),
            );
    if (!context.mounted || document == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.sisDocumentUploadSuccessSnackbar,
        content: Text('Document uploaded: ${document.type}'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(aksharaErrorMessage(error))),
    );
  }
}

/// SIS-3 — confirm dialog (with optional reviewer note) that verifies or
/// rejects a pending student document via [verifyStudentDocumentProvider].
Future<void> showSisDocumentVerifyDialog(
  BuildContext context,
  WidgetRef ref, {
  required SisStudentProfile profile,
  required SisDocumentSummary document,
  required SisDocumentDecision decision,
}) async {
  final documentId = document.id;
  if (documentId == null) return;
  final noteController = TextEditingController();
  final isVerify = decision == SisDocumentDecision.verified;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(isVerify ? 'Verify document' : 'Reject document'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(document.type),
          const SizedBox(height: 12),
          TextField(
            key: QaTestKeys.sisDocumentVerifyNoteField,
            controller: noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'e.g. rejection reason',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.sisDocumentVerifySubmitButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(isVerify ? 'Verify' : 'Reject'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final note = noteController.text.trim();
    final updated =
        await ref.read(verifyStudentDocumentProvider.notifier).execute(
              studentId: profile.student.id,
              documentId: documentId,
              request: VerifyStudentDocumentRequest(
                decision: decision,
                note: note.isEmpty ? null : note,
              ),
            );
    if (!context.mounted || updated == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.sisDocumentVerifySuccessSnackbar,
        content: Text(
          isVerify
              ? 'Document verified: ${updated.type}'
              : 'Document rejected: ${updated.type}',
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

/// SIS-1 — pick a certificate type + optional reason, issue it (manageSis), then
/// render/share the resulting certificate PDF.
Future<void> showSisIssueCertificateDialog(
  BuildContext context,
  WidgetRef ref, {
  required SisStudentProfile profile,
}) async {
  var selectedType = SisCertificateType.bonafide;
  final reasonController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Issue certificate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<SisCertificateType>(
              key: QaTestKeys.sisIssueCertificateTypeField,
              initialValue: selectedType,
              decoration: const InputDecoration(labelText: 'Certificate type'),
              items: const [
                DropdownMenuItem(
                  value: SisCertificateType.bonafide,
                  child: Text('Bonafide'),
                ),
                DropdownMenuItem(
                  value: SisCertificateType.study,
                  child: Text('Study'),
                ),
                DropdownMenuItem(
                  value: SisCertificateType.conduct,
                  child: Text('Conduct'),
                ),
              ],
              onChanged: (value) => setState(
                () => selectedType = value ?? SisCertificateType.bonafide,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: QaTestKeys.sisIssueCertificateReasonField,
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. for bank account opening',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.sisIssueCertificateSubmitButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Issue'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final reason = reasonController.text.trim();
    final data = await ref.read(issueCertificateProvider.notifier).execute(
          studentId: profile.student.id,
          request: IssueCertificateRequest(
            type: selectedType,
            reason: reason.isEmpty ? null : reason,
          ),
        );
    if (data == null) {
      if (!context.mounted) return;
      final failure = ref.read(issueCertificateProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failure != null
                ? aksharaErrorMessage(failure)
                : 'Could not issue the certificate. Please try again.',
          ),
        ),
      );
      return;
    }
    await _renderCertificate(data);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.sisIssueCertificateSuccessSnackbar,
        content: Text('${data.type.certificateTitle} ready for ${data.studentName}'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(aksharaErrorMessage(error))),
    );
  }
}

/// SIS-D1 — confirm + issue a Transfer Certificate. Surfaces 409 DUES_PENDING
/// with the friendly outstanding amount; on success renders the TC PDF and the
/// student's status reflects transferred.
Future<void> showSisTransferCertificateDialog(
  BuildContext context,
  WidgetRef ref, {
  required SisStudentProfile profile,
}) async {
  final reasonController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Issue transfer certificate'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This relieves ${profile.student.studentName} from the school and '
            'sets their status to Transferred. All dues must be cleared first.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: QaTestKeys.sisTransferCertificateReasonField,
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'e.g. relocation',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.sisTransferCertificateSubmitButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Issue TC'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final reason = reasonController.text.trim();
    final data =
        await ref.read(issueTransferCertificateProvider.notifier).execute(
              studentId: profile.student.id,
              request: IssueTransferCertificateRequest(
                reason: reason.isEmpty ? null : reason,
              ),
            );
    if (data == null) {
      if (!context.mounted) return;
      // The 409 DUES_PENDING message from the backend already carries the
      // outstanding amount — surface it verbatim so the user knows what to clear.
      final failure = ref.read(issueTransferCertificateProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failure != null
                ? aksharaErrorMessage(failure)
                : 'Could not issue the transfer certificate. Please try again.',
          ),
        ),
      );
      return;
    }
    await _renderCertificate(data);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.sisTransferCertificateSuccessSnackbar,
        content: Text(
          'Transfer certificate ${data.serialNo ?? ''} issued for '
          '${data.studentName}',
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

/// Builds and prints the certificate PDF. Split out so widget tests can override
/// [sisCertificatePdfRenderer] to avoid the printing platform channel.
Future<void> _renderCertificate(SisCertificateData data) =>
    sisCertificatePdfRenderer(data);

/// Injectable certificate renderer (build + print). Default uses the real PDF
/// service + Printing; tests replace it with a no-op to dodge the plugin.
typedef SisCertificateRenderer = Future<void> Function(SisCertificateData data);

SisCertificateRenderer sisCertificatePdfRenderer = _defaultCertificateRenderer;

Future<void> _defaultCertificateRenderer(SisCertificateData data) async {
  const service = SisCertificatePdfService();
  final bytes = await service.buildCertificatePdf(data: data);
  await service.printCertificate(bytes);
}
