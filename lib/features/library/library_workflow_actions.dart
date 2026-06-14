import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import 'library_models.dart';
import 'library_mutations_provider.dart';
import 'library_requests.dart';

Future<void> showIssueLibraryBookDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final isbnController =
      TextEditingController(text: '978-0-07-802563-1');
  final memberIdController = TextEditingController(text: 'mem_5');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Issue book'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: isbnController,
            decoration: const InputDecoration(labelText: 'ISBN'),
          ),
          TextField(
            controller: memberIdController,
            decoration: const InputDecoration(labelText: 'Member ID'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.libraryIssueDialogSubmitButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Issue'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final issue = await ref.read(issueLibraryBookProvider.notifier).execute(
          IssueLibraryBookRequest(
            isbn: isbnController.text.trim(),
            memberId: memberIdController.text.trim(),
          ),
        );
    if (!context.mounted || issue == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.libraryIssueSuccessSnackbar,
        content: Text('Issued ${issue.bookTitle} to ${issue.memberName}'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to issue book: $error')),
    );
  }
}

Future<void> showReturnLibraryBookDialog(
  BuildContext context,
  WidgetRef ref, {
  String? initialIssueId,
}) async {
  final issueIdController =
      TextEditingController(text: initialIssueId ?? 'iss_2');
  var condition = LibraryReturnCondition.good;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Return book'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: issueIdController,
              decoration: const InputDecoration(labelText: 'Issue ID'),
            ),
            const SizedBox(height: 12),
            DropdownButton<LibraryReturnCondition>(
              value: condition,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: LibraryReturnCondition.good,
                  child: Text('Good'),
                ),
                DropdownMenuItem(
                  value: LibraryReturnCondition.fair,
                  child: Text('Fair'),
                ),
                DropdownMenuItem(
                  value: LibraryReturnCondition.damaged,
                  child: Text('Damaged'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => condition = value);
                }
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
            key: QaTestKeys.libraryReturnDialogSubmitButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Return'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final record = await ref.read(returnLibraryBookProvider.notifier).execute(
          ReturnLibraryBookRequest(
            issueId: issueIdController.text.trim(),
            condition: condition,
          ),
        );
    if (!context.mounted || record == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.libraryReturnSuccessSnackbar,
        content: Text(
          'Returned ${record.bookTitle} from ${record.memberName}'
          '${record.fineAmount == '₹0' ? '' : ' · Fine ${record.fineAmount}'}',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to return book: $error')),
    );
  }
}

Future<void> returnLibraryIssue(
  BuildContext context,
  WidgetRef ref,
  LibraryIssueRecord issue,
) =>
    showReturnLibraryBookDialog(context, ref, initialIssueId: issue.id);
