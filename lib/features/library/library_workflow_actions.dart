import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/forms/akshara_form_field.dart';
import '../../shared/widgets/akshara_dialog.dart';
import '../../shared/widgets/akshara_motion.dart';
import 'library_models.dart';
import 'library_mutations_provider.dart';
import 'library_requests.dart';

void _showLibraryMutationError(BuildContext context, Object error) {
  final failure = error is ApiFailureException
      ? error.failure
      : apiFailureMapper.fromException(error);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(failure.message)),
  );
}

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

Future<void> showAddLibraryBookDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final isbnController = TextEditingController();
  final titleController = TextEditingController();
  final authorController = TextEditingController();
  final categoryController = TextEditingController(text: 'General');
  final copiesController = TextEditingController(text: '1');
  final shelfController = TextEditingController();

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Add book',
      icon: Icons.menu_book_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            label: 'ISBN',
            controller: isbnController,
            required: true,
            hint: 'e.g. 978-0-07-802563-1',
          ),
          AksharaFormField(
            label: 'Title',
            controller: titleController,
            required: true,
          ),
          AksharaFormField(
            label: 'Author',
            controller: authorController,
          ),
          AksharaFormField(
            label: 'Category',
            controller: categoryController,
            hint: 'e.g. Science, Fiction',
          ),
          AksharaFormField(
            label: 'Total copies',
            controller: copiesController,
            keyboardType: TextInputType.number,
            required: true,
          ),
          AksharaFormField(
            label: 'Shelf',
            controller: shelfController,
            hint: 'e.g. SCI-12',
          ),
        ],
      ),
      actions: [
        AksharaDialogActions(
          confirmLabel: 'Add book',
          confirmKey: QaTestKeys.libraryAddBookDialogSubmitButton,
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () {
            if (isbnController.text.trim().isEmpty ||
                titleController.text.trim().isEmpty) {
              return;
            }
            Navigator.of(context).pop(true);
          },
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final book = await ref.read(addLibraryBookProvider.notifier).execute(
          AddLibraryBookRequest(
            isbn: isbnController.text.trim(),
            title: titleController.text.trim(),
            author: authorController.text.trim(),
            category: categoryController.text.trim(),
            totalCopies: int.tryParse(copiesController.text.trim()) ?? 1,
            shelf: shelfController.text.trim(),
          ),
        );
    if (!context.mounted || book == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.libraryAddBookSuccessSnackbar,
        content: Text('Added "${book.title}" to the catalog'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showLibraryMutationError(context, error);
  }
}

String _libraryResourceTypeLabel(LibraryResourceType type) => switch (type) {
      LibraryResourceType.ebook => 'E-book',
      LibraryResourceType.pdf => 'PDF',
      LibraryResourceType.link => 'Link',
      LibraryResourceType.video => 'Video',
    };

Future<void> showAddLibraryResourceDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final titleController = TextEditingController();
  final classAccessController = TextEditingController(text: 'All classes');
  var type = LibraryResourceType.pdf;
  var studentAppVisible = true;
  var teacherAppVisible = true;

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AksharaAlertDialog(
        title: 'Add resource',
        icon: Icons.upload_outlined,
        scrollable: true,
        content: AksharaDialogFormBody(
          children: [
            AksharaFormField(
              label: 'Title',
              controller: titleController,
              required: true,
              hint: 'e.g. NCERT Maths Class 9 (PDF)',
            ),
            DropdownMenu<LibraryResourceType>(
              initialSelection: type,
              label: const Text('Type'),
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries: [
                for (final option in LibraryResourceType.values)
                  DropdownMenuEntry(
                    value: option,
                    label: _libraryResourceTypeLabel(option),
                  ),
              ],
              onSelected: (value) {
                if (value != null) setState(() => type = value);
              },
            ),
            AksharaFormField(
              label: 'Class access',
              controller: classAccessController,
              hint: 'e.g. Class 8–10 or Staff only',
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible in Student App'),
              value: studentAppVisible,
              onChanged: (value) => setState(() => studentAppVisible = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible in Teacher App'),
              value: teacherAppVisible,
              onChanged: (value) => setState(() => teacherAppVisible = value),
            ),
          ],
        ),
        actions: [
          AksharaDialogActions(
            confirmLabel: 'Add resource',
            confirmKey: QaTestKeys.libraryAddResourceDialogSubmitButton,
            onCancel: () => Navigator.of(context).pop(false),
            onConfirm: () {
              if (titleController.text.trim().isEmpty) return;
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final resource =
        await ref.read(addLibraryResourceProvider.notifier).execute(
              AddLibraryResourceRequest(
                title: titleController.text.trim(),
                type: type,
                classAccess: classAccessController.text.trim(),
                studentAppVisible: studentAppVisible,
                teacherAppVisible: teacherAppVisible,
              ),
            );
    if (!context.mounted || resource == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.libraryAddResourceSuccessSnackbar,
        content: Text('Added "${resource.title}" to digital resources'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showLibraryMutationError(context, error);
  }
}
