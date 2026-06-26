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
import 'library_providers.dart';
import 'library_requests.dart';

void _showLibraryMutationError(BuildContext context, Object error) {
  final failure = error is ApiFailureException
      ? error.failure
      : apiFailureMapper.fromException(error);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(failure.message)),
  );
}

String _libraryMemberTypeLabel(LibraryMemberType type) => switch (type) {
      LibraryMemberType.student => 'Student',
      LibraryMemberType.teacher => 'Teacher',
      LibraryMemberType.staff => 'Staff',
    };

Future<void> showIssueLibraryBookDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  // Pick from LIVE data — never hardcoded mock-seed ids (MJ-H21 / LIBRA-1).
  final members = ref.read(libraryMembersProvider) ?? const [];
  final books = (ref.read(libraryCatalogProvider) ?? const [])
      .where((book) => book.availableCopies > 0)
      .toList(growable: false);

  if (members.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enrol a member before issuing a book.'),
      ),
    );
    return;
  }
  if (books.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No books with available copies to issue.'),
      ),
    );
    return;
  }

  LibraryMember? selectedMember;
  LibraryBook? selectedBook;

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AksharaAlertDialog(
        title: 'Issue book',
        icon: Icons.menu_book_outlined,
        scrollable: true,
        content: AksharaDialogFormBody(
          children: [
            DropdownMenu<LibraryMember>(
              initialSelection: selectedMember,
              label: const Text('Member'),
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries: [
                for (final member in members)
                  DropdownMenuEntry(
                    value: member,
                    label:
                        '${member.name} · ${_libraryMemberTypeLabel(member.memberType)}',
                  ),
              ],
              onSelected: (value) => setState(() => selectedMember = value),
            ),
            DropdownMenu<LibraryBook>(
              initialSelection: selectedBook,
              label: const Text('Book'),
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries: [
                for (final book in books)
                  DropdownMenuEntry(
                    value: book,
                    label:
                        '${book.title} (${book.availableCopies} avail.)',
                  ),
              ],
              onSelected: (value) => setState(() => selectedBook = value),
            ),
          ],
        ),
        actions: [
          AksharaDialogActions(
            confirmLabel: 'Issue',
            confirmKey: QaTestKeys.libraryIssueDialogSubmitButton,
            onCancel: () => Navigator.of(context).pop(false),
            onConfirm: () {
              if (selectedMember == null || selectedBook == null) return;
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
    ),
  );

  if (confirmed != true ||
      !context.mounted ||
      selectedMember == null ||
      selectedBook == null) {
    return;
  }

  try {
    final issue = await ref.read(issueLibraryBookProvider.notifier).execute(
          IssueLibraryBookRequest(
            isbn: selectedBook!.isbn,
            memberId: selectedMember!.id,
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
    _showLibraryMutationError(context, error);
  }
}

Future<void> showReturnLibraryBookDialog(
  BuildContext context,
  WidgetRef ref, {
  String? initialIssueId,
}) async {
  // Open loans come from LIVE data — no hardcoded mock-seed issue id.
  final openIssues = ref.read(libraryIssuesProvider) ?? const [];
  if (openIssues.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No open loans to return.')),
    );
    return;
  }

  LibraryIssueRecord? selectedIssue = initialIssueId == null
      ? null
      : openIssues.cast<LibraryIssueRecord?>().firstWhere(
            (issue) => issue?.id == initialIssueId,
            orElse: () => null,
          );
  var condition = LibraryReturnCondition.good;

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AksharaAlertDialog(
        title: 'Return book',
        icon: Icons.assignment_return_outlined,
        scrollable: true,
        content: AksharaDialogFormBody(
          children: [
            DropdownMenu<LibraryIssueRecord>(
              initialSelection: selectedIssue,
              label: const Text('Open loan'),
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries: [
                for (final issue in openIssues)
                  DropdownMenuEntry(
                    value: issue,
                    label: '${issue.bookTitle} · ${issue.memberName}',
                  ),
              ],
              onSelected: (value) => setState(() => selectedIssue = value),
            ),
            DropdownMenu<LibraryReturnCondition>(
              initialSelection: condition,
              label: const Text('Condition'),
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries: const [
                DropdownMenuEntry(
                  value: LibraryReturnCondition.good,
                  label: 'Good',
                ),
                DropdownMenuEntry(
                  value: LibraryReturnCondition.fair,
                  label: 'Fair',
                ),
                DropdownMenuEntry(
                  value: LibraryReturnCondition.damaged,
                  label: 'Damaged',
                ),
              ],
              onSelected: (value) {
                if (value != null) setState(() => condition = value);
              },
            ),
          ],
        ),
        actions: [
          AksharaDialogActions(
            confirmLabel: 'Return',
            confirmKey: QaTestKeys.libraryReturnDialogSubmitButton,
            onCancel: () => Navigator.of(context).pop(false),
            onConfirm: () {
              if (selectedIssue == null) return;
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted || selectedIssue == null) return;

  try {
    final record = await ref.read(returnLibraryBookProvider.notifier).execute(
          ReturnLibraryBookRequest(
            issueId: selectedIssue!.id,
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
  final urlController = TextEditingController();
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
              label: 'Resource URL',
              controller: urlController,
              required: true,
              keyboardType: TextInputType.url,
              hint: 'https://… (PDF, e-book or link)',
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
              if (titleController.text.trim().isEmpty ||
                  !_isHttpUrl(urlController.text.trim())) {
                return;
              }
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
                resourceUrl: urlController.text.trim(),
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

bool _isHttpUrl(String value) {
  if (value.isEmpty) return false;
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.hasScheme &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

Future<void> showEnrollLibraryMemberDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final nameController = TextEditingController();
  final identifierController = TextEditingController();
  final classController = TextEditingController();
  final sisController = TextEditingController();
  var memberType = LibraryMemberType.student;

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AksharaAlertDialog(
        title: 'Add member',
        icon: Icons.person_add_alt_1_outlined,
        scrollable: true,
        content: AksharaDialogFormBody(
          children: [
            AksharaFormField(
              label: 'Name',
              controller: nameController,
              required: true,
            ),
            DropdownMenu<LibraryMemberType>(
              initialSelection: memberType,
              label: const Text('Type'),
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries: [
                for (final option in LibraryMemberType.values)
                  DropdownMenuEntry(
                    value: option,
                    label: _libraryMemberTypeLabel(option),
                  ),
              ],
              onSelected: (value) {
                if (value != null) setState(() => memberType = value);
              },
            ),
            AksharaFormField(
              label: 'ID (admission / employee)',
              controller: identifierController,
              hint: 'e.g. ADM-2026-0138 or EMP-TCH-042',
            ),
            AksharaFormField(
              label: 'Class / Department',
              controller: classController,
              hint: 'e.g. Class 10 or English Dept',
            ),
            AksharaFormField(
              label: 'SIS student id (optional)',
              controller: sisController,
              hint: 'Links fines to Finance',
            ),
          ],
        ),
        actions: [
          AksharaDialogActions(
            confirmLabel: 'Add member',
            confirmKey: QaTestKeys.libraryEnrollMemberDialogSubmitButton,
            onCancel: () => Navigator.of(context).pop(false),
            onConfirm: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final sis = sisController.text.trim();
    final member = await ref.read(enrollLibraryMemberProvider.notifier).execute(
          EnrollLibraryMemberRequest(
            name: nameController.text.trim(),
            memberType: memberType,
            identifier: identifierController.text.trim(),
            classOrDepartment: classController.text.trim(),
            sisStudentId: sis.isEmpty ? null : sis,
          ),
        );
    if (!context.mounted || member == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.libraryEnrollMemberSuccessSnackbar,
        content: Text('Enrolled ${member.name} as a library member'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showLibraryMutationError(context, error);
  }
}

Future<void> waiveLibraryFine(
  BuildContext context,
  WidgetRef ref,
  LibraryFine fine,
) async {
  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Waive fine',
      icon: Icons.gavel_outlined,
      content: Text(
        'Waive the ${fine.amount} fine for ${fine.memberName} '
        '(${fine.bookTitle})? This is audit-logged.',
      ),
      actions: [
        AksharaDialogActions(
          confirmLabel: 'Waive fine',
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final waived = await ref.read(waiveLibraryFineProvider.notifier).execute(
          WaiveLibraryFineRequest(fineId: fine.id),
        );
    if (!context.mounted || waived == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.libraryWaiveFineSuccessSnackbar,
        content: Text('Waived ${waived.amount} fine for ${waived.memberName}'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showLibraryMutationError(context, error);
  }
}
