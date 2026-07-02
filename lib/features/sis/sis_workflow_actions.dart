import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
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
