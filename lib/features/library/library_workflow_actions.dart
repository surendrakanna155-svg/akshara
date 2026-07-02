import 'dart:convert';

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
  final isbnController = TextEditingController();

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        // LIB-3 — resolve a manually keyed / scanned ISBN to a live catalogue
        // book with available copies; auto-selects it so a barcode reader (or
        // hand-typed ISBN) drives the issue without touching the dropdown.
        void resolveIsbn(String raw) {
          final isbn = raw.trim();
          if (isbn.isEmpty) return;
          final match = books.cast<LibraryBook?>().firstWhere(
                (book) => book?.isbn == isbn,
                orElse: () => null,
              );
          if (match != null) {
            setState(() => selectedBook = match);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No available book with ISBN $isbn')),
            );
          }
        }

        return AksharaAlertDialog(
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
                key: ValueKey(selectedBook?.id),
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
              // LIB-3 — manual barcode / ISBN entry. The camera "Scan" button
              // lives on the screen and is device-gated (staged seam — no camera
              // package); staff on any device can still key the ISBN here.
              AksharaFormField(
                key: QaTestKeys.libraryIssueIsbnField,
                label: 'Or enter ISBN',
                controller: isbnController,
                keyboardType: TextInputType.text,
                hint: 'Scan or type, then done',
                textInputAction: TextInputAction.done,
                onFieldSubmitted: resolveIsbn,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Find by ISBN',
                  onPressed: () => resolveIsbn(isbnController.text),
                ),
              ),
            ],
          ),
          actions: [
            AksharaDialogActions(
              confirmLabel: 'Issue',
              confirmKey: QaTestKeys.libraryIssueDialogSubmitButton,
              onCancel: () => Navigator.of(context).pop(false),
              onConfirm: () {
                // Resolve any pending ISBN entry before validating.
                if (selectedBook == null && isbnController.text.trim().isNotEmpty) {
                  resolveIsbn(isbnController.text);
                }
                if (selectedMember == null || selectedBook == null) return;
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
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
  final isbnController = TextEditingController();

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        // LIB-3 — resolve a keyed / scanned ISBN to the matching open loan so a
        // barcode reader (or typed ISBN) drives the return without the dropdown.
        void resolveIsbn(String raw) {
          final isbn = raw.trim();
          if (isbn.isEmpty) return;
          final match = openIssues.cast<LibraryIssueRecord?>().firstWhere(
                (issue) => issue?.isbn == isbn,
                orElse: () => null,
              );
          if (match != null) {
            setState(() => selectedIssue = match);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No open loan with ISBN $isbn')),
            );
          }
        }

        return AksharaAlertDialog(
          title: 'Return book',
          icon: Icons.assignment_return_outlined,
          scrollable: true,
          content: AksharaDialogFormBody(
            children: [
              DropdownMenu<LibraryIssueRecord>(
                initialSelection: selectedIssue,
                key: ValueKey(selectedIssue?.id),
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
              // LIB-3 — manual barcode / ISBN entry (camera scan seam is on the
              // screen, device-gated; typing works on any device).
              AksharaFormField(
                key: QaTestKeys.libraryReturnIsbnField,
                label: 'Or enter ISBN',
                controller: isbnController,
                keyboardType: TextInputType.text,
                hint: 'Scan or type, then done',
                textInputAction: TextInputAction.done,
                onFieldSubmitted: resolveIsbn,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Find by ISBN',
                  onPressed: () => resolveIsbn(isbnController.text),
                ),
              ),
            ],
          ),
          actions: [
            AksharaDialogActions(
              confirmLabel: 'Return',
              confirmKey: QaTestKeys.libraryReturnDialogSubmitButton,
              onCancel: () => Navigator.of(context).pop(false),
              onConfirm: () {
                if (selectedIssue == null && isbnController.text.trim().isNotEmpty) {
                  resolveIsbn(isbnController.text);
                }
                if (selectedIssue == null) return;
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
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

// ── LIB-2 — edit a catalogue book ────────────────────────────────────────────

/// LIB-2 — edit an existing catalogue book (prefilled) → [updateLibraryBook].
Future<void> showEditLibraryBookDialog(
  BuildContext context,
  WidgetRef ref,
  LibraryBook book,
) async {
  final isbnController = TextEditingController(text: book.isbn);
  final titleController = TextEditingController(text: book.title);
  final authorController = TextEditingController(text: book.author);
  final categoryController = TextEditingController(text: book.category);
  final copiesController = TextEditingController(text: '${book.totalCopies}');
  final shelfController = TextEditingController(text: book.shelf);

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Edit book',
      icon: Icons.edit_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            label: 'ISBN',
            controller: isbnController,
            required: true,
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
          confirmLabel: 'Save changes',
          confirmKey: QaTestKeys.libraryEditBookDialogSubmitButton,
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
    final updated = await ref.read(updateLibraryBookProvider.notifier).execute(
          book.id,
          UpdateLibraryBookRequest(
            isbn: isbnController.text.trim(),
            title: titleController.text.trim(),
            author: authorController.text.trim(),
            category: categoryController.text.trim(),
            totalCopies: int.tryParse(copiesController.text.trim()) ??
                book.totalCopies,
            shelf: shelfController.text.trim(),
          ),
        );
    if (!context.mounted || updated == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.libraryEditBookSuccessSnackbar,
        content: Text('Updated "${updated.title}"'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showLibraryMutationError(context, error);
  }
}

// ── LIB-2 — delete a catalogue book ──────────────────────────────────────────

/// LIB-2 — delete a book with a confirm; a book on an active loan is rejected by
/// the server and surfaced as a friendly error.
Future<void> deleteLibraryBook(
  BuildContext context,
  WidgetRef ref,
  LibraryBook book,
) async {
  final confirmed = await showAksharaConfirmDialog(
    context,
    title: 'Delete book',
    message:
        'Delete "${book.title}" from the catalog? A book on an active loan '
        'cannot be deleted.',
    confirmLabel: 'Delete',
    destructive: true,
    icon: Icons.delete_outline,
    confirmKey: QaTestKeys.libraryDeleteBookConfirmButton,
  );

  if (!confirmed || !context.mounted) return;

  try {
    await ref.read(deleteLibraryBookProvider.notifier).execute(book.id);
    final state = ref.read(deleteLibraryBookProvider);
    if (!context.mounted) return;
    if (state.hasError) {
      _showLibraryMutationError(context, state.error!);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.libraryDeleteBookSuccessSnackbar,
        content: Text('Deleted "${book.title}"'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showLibraryMutationError(context, error);
  }
}

// ── LIB-2 — bulk import books (paste CSV) ─────────────────────────────────────

/// Splits one CSV line, honouring double-quoted fields (reuses the onboarding
/// parser approach — there is no file_picker in the app, staff paste CSV text).
List<String> _splitLibraryCsvLine(String line) {
  final out = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch == ',' && !inQuotes) {
      out.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(ch);
    }
  }
  out.add(buffer.toString());
  return out;
}

/// Parses pasted CSV text into import rows. Accepts an optional header row
/// (title,author,isbn,category,copies,shelf); if the first cell of row 1 is not
/// a known header it is treated as data.
List<ImportBookRow> _parseImportCsv(String text) {
  final lines = const LineSplitter()
      .convert(text.trim())
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return const [];

  var start = 0;
  final firstCells =
      _splitLibraryCsvLine(lines.first).map((c) => c.trim().toLowerCase());
  const headerTokens = {'title', 'author', 'isbn'};
  if (firstCells.any(headerTokens.contains)) {
    start = 1;
  }

  final rows = <ImportBookRow>[];
  for (var i = start; i < lines.length; i++) {
    final cells = _splitLibraryCsvLine(lines[i]).map((c) => c.trim()).toList();
    String at(int idx) => idx < cells.length ? cells[idx] : '';
    rows.add(
      ImportBookRow(
        title: at(0),
        author: at(1),
        isbn: at(2),
        category: at(3).isEmpty ? null : at(3),
        totalCopies: int.tryParse(at(4)),
        shelf: at(5).isEmpty ? null : at(5),
      ),
    );
  }
  return rows;
}

/// LIB-2 — paste-CSV bulk importer → [bulkImportBooks]; shows the per-row result
/// ({imported, failed:[{row, reason}]}).
Future<void> showImportLibraryBooksSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final csvController = TextEditingController();

  final submitted = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Import books (CSV)',
      icon: Icons.upload_file_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          const Text(
            'Paste rows as: title,author,isbn,category,copies,shelf. '
            'A header row is optional.',
          ),
          AksharaFormField(
            key: QaTestKeys.libraryImportBooksTextField,
            label: 'CSV rows',
            controller: csvController,
            maxLines: 8,
            minLines: 4,
            hint: 'The Alchemist,Paulo Coelho,978-0-06-112241-5,Fiction,3,FIC-2',
          ),
        ],
      ),
      actions: [
        AksharaDialogActions(
          confirmLabel: 'Import',
          confirmKey: QaTestKeys.libraryImportBooksSubmitButton,
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () {
            if (csvController.text.trim().isEmpty) return;
            Navigator.of(context).pop(true);
          },
        ),
      ],
    ),
  );

  if (submitted != true || !context.mounted) return;

  final rows = _parseImportCsv(csvController.text);
  if (rows.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No book rows found in the pasted CSV.')),
    );
    return;
  }

  try {
    final result = await ref.read(bulkImportBooksProvider.notifier).execute(
          BulkImportBooksRequest(rows: rows),
        );
    if (!context.mounted || result == null) return;
    final message = result.failedCount == 0
        ? 'Imported ${result.imported} book(s)'
        : 'Imported ${result.imported}, ${result.failedCount} failed: '
            '${result.failed.map((f) => 'row ${f.row} — ${f.reason}').join('; ')}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.libraryImportBooksResultSnackbar,
        content: Text(message),
        duration: const Duration(seconds: 6),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showLibraryMutationError(context, error);
  }
}

// ── LIB-4 — renew an active loan ──────────────────────────────────────────────

/// LIB-4 — renew an active loan → [renewLibraryLoan]; surfaces the renewal-cap
/// error as a friendly message.
Future<void> renewLibraryLoan(
  BuildContext context,
  WidgetRef ref,
  LibraryIssueRecord issue,
) async {
  try {
    final renewed = await ref.read(renewLibraryLoanProvider.notifier).execute(
          issue.id,
        );
    if (!context.mounted) return;
    final state = ref.read(renewLibraryLoanProvider);
    if (state.hasError) {
      _showLibraryMutationError(context, state.error!);
      return;
    }
    if (renewed == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.libraryRenewLoanSuccessSnackbar,
        content: Text(
          'Renewed "${renewed.bookTitle}" — now due ${renewed.dueDate}',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showLibraryMutationError(context, error);
  }
}

// ── LIB-5 — send overdue reminders ────────────────────────────────────────────

/// LIB-5 — enqueue in-app overdue reminders → [sendOverdueReminder]; snackbar
/// "Reminders sent to N".
Future<void> sendLibraryOverdueReminders(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    final count =
        await ref.read(sendOverdueReminderProvider.notifier).execute();
    if (!context.mounted) return;
    final state = ref.read(sendOverdueReminderProvider);
    if (state.hasError) {
      _showLibraryMutationError(context, state.error!);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.librarySendRemindersSuccessSnackbar,
        content: Text('Reminders sent to ${count ?? 0}'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showLibraryMutationError(context, error);
  }
}

// ── LIB-D1 — library circulation settings ─────────────────────────────────────

/// LIB-D1 — edit the circulation guardrails (max books per member, max renewals,
/// block-on-fine ₹ threshold) → [updateLibrarySettings]. manageLibrary-gated via
/// the mutation notifier.
Future<void> showLibrarySettingsDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final current =
      ref.read(librarySettingsProvider) ?? LibrarySettings.defaults;
  final maxBooksController =
      TextEditingController(text: '${current.maxBooksPerMember}');
  final maxRenewalsController =
      TextEditingController(text: '${current.maxRenewals}');
  final fineThresholdController =
      TextEditingController(text: '${current.blockOnFineThreshold}');

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Library settings',
      icon: Icons.settings_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            key: QaTestKeys.librarySettingsMaxBooksField,
            label: 'Max books per member',
            controller: maxBooksController,
            keyboardType: TextInputType.number,
            required: true,
          ),
          AksharaFormField(
            key: QaTestKeys.librarySettingsMaxRenewalsField,
            label: 'Max renewals',
            controller: maxRenewalsController,
            keyboardType: TextInputType.number,
            required: true,
          ),
          AksharaFormField(
            key: QaTestKeys.librarySettingsFineThresholdField,
            label: 'Block issue when fine exceeds (₹)',
            controller: fineThresholdController,
            keyboardType: TextInputType.number,
            required: true,
          ),
        ],
      ),
      actions: [
        AksharaDialogActions(
          confirmLabel: 'Save settings',
          confirmKey: QaTestKeys.librarySettingsSubmitButton,
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final updated =
        await ref.read(updateLibrarySettingsProvider.notifier).execute(
              LibrarySettings(
                maxBooksPerMember:
                    int.tryParse(maxBooksController.text.trim()) ??
                        current.maxBooksPerMember,
                maxRenewals: int.tryParse(maxRenewalsController.text.trim()) ??
                    current.maxRenewals,
                blockOnFineThreshold:
                    int.tryParse(fineThresholdController.text.trim()) ??
                        current.blockOnFineThreshold,
              ),
            );
    if (!context.mounted || updated == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.librarySettingsSuccessSnackbar,
        content: Text(
          'Saved — max ${updated.maxBooksPerMember} books, '
          '${updated.maxRenewals} renewals, block over ₹${updated.blockOnFineThreshold}',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showLibraryMutationError(context, error);
  }
}
