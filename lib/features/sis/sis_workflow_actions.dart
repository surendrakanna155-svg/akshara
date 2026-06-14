import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import 'profile/sis_profile_edit_sheet.dart';
import 'sis_models.dart';
import 'sis_mutations_provider.dart';
import 'sis_requests.dart';

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
      SnackBar(content: Text('$error')),
    );
  }
}
