import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_text.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/forms/akshara_form_field.dart';
import '../../shared/widgets/akshara_dialog.dart';
import '../../shared/widgets/akshara_motion.dart';
import 'school_completion_models.dart';
import 'school_completion_providers.dart';

/// Known subject categories offered in the create/edit forms. Stored as plain
/// strings on [AcademicSubject.category]; the picker keeps the data clean
/// instead of free-typing.
const List<String> kSubjectCategories = <String>[
  'core',
  'elective',
  'language',
  'optional',
  'co-curricular',
];

/// Lifecycle states a subject can be moved between from the edit form.
const List<String> kSubjectStatuses = <String>[
  'active',
  'inactive',
  'archived',
];

/// Create-subject dialog: collects code + name + category and calls
/// [SchoolCompletionRepository.createSubject], then refreshes the list.
Future<void> showCreateSubjectDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final formKey = GlobalKey<FormState>();
  final codeController = TextEditingController();
  final nameController = TextEditingController();
  var category = kSubjectCategories.first;

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Add subject',
      icon: Icons.menu_book_outlined,
      scrollable: true,
      content: Form(
        key: formKey,
        child: AksharaDialogFormBody(
          children: [
            AksharaFormField(
              label: 'Subject code',
              required: true,
              controller: codeController,
              hint: 'e.g. MATH',
              textInputAction: TextInputAction.next,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a subject code'
                  : null,
            ),
            AksharaFormField(
              label: 'Subject name',
              required: true,
              controller: nameController,
              hint: 'e.g. Mathematics',
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a subject name'
                  : null,
            ),
            _SubjectCategoryField(
              initial: category,
              onChanged: (value) => category = value,
            ),
          ],
        ),
      ),
      actions: [
        AksharaDialogActions(
          confirmLabel: 'Create',
          confirmKey: QaTestKeys.subjectCreateSubmitButton,
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(true);
            }
          },
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final created =
        await ref.read(schoolCompletionRepositoryProvider).createSubject(
              query: ref.read(schoolCompletionQueryProvider),
              subjectCode: codeController.text.trim(),
              subjectName: nameController.text.trim(),
              category: category,
            );
    ref.invalidate(subjectsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Subject "${created.subjectName}" added')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not add subject: ${aksharaErrorMessage(error)}'),
      ),
    );
  }
}

/// Edit-subject dialog: name + category + status. The subject code is
/// immutable (the repository does not accept a code change), so it is shown
/// read-only.
Future<void> showEditSubjectDialog(
  BuildContext context,
  WidgetRef ref, {
  required AcademicSubject subject,
}) async {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: subject.subjectName);
  var category = kSubjectCategories.contains(subject.category)
      ? subject.category
      : kSubjectCategories.first;
  var status = kSubjectStatuses.contains(subject.status)
      ? subject.status
      : kSubjectStatuses.first;

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Edit subject',
      icon: Icons.edit_outlined,
      scrollable: true,
      content: Form(
        key: formKey,
        child: AksharaDialogFormBody(
          children: [
            AksharaFormField(
              label: 'Subject code',
              controller: TextEditingController(text: subject.subjectCode),
              readOnly: true,
              helperText: 'Subject code cannot be changed',
            ),
            AksharaFormField(
              label: 'Subject name',
              required: true,
              controller: nameController,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a subject name'
                  : null,
            ),
            _SubjectCategoryField(
              initial: category,
              onChanged: (value) => category = value,
            ),
            _SubjectStatusField(
              initial: status,
              onChanged: (value) => status = value,
            ),
          ],
        ),
      ),
      actions: [
        AksharaDialogActions(
          confirmLabel: 'Save',
          confirmKey: QaTestKeys.subjectEditSubmitButton,
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(true);
            }
          },
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final updated =
        await ref.read(schoolCompletionRepositoryProvider).updateSubject(
              query: ref.read(schoolCompletionQueryProvider),
              subjectId: subject.id,
              subjectName: nameController.text.trim(),
              category: category,
              status: status,
            );
    ref.invalidate(subjectsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Subject "${updated.subjectName}" updated')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not update subject: ${aksharaErrorMessage(error)}'),
      ),
    );
  }
}

class _SubjectCategoryField extends StatefulWidget {
  const _SubjectCategoryField({required this.initial, required this.onChanged});

  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_SubjectCategoryField> createState() => _SubjectCategoryFieldState();
}

class _SubjectCategoryFieldState extends State<_SubjectCategoryField> {
  late String _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _value,
      decoration: const InputDecoration(labelText: 'Category'),
      items: [
        for (final c in kSubjectCategories)
          DropdownMenuItem<String>(value: c, child: Text(_titleCase(c))),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() => _value = value);
        widget.onChanged(value);
      },
    );
  }
}

class _SubjectStatusField extends StatefulWidget {
  const _SubjectStatusField({required this.initial, required this.onChanged});

  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_SubjectStatusField> createState() => _SubjectStatusFieldState();
}

class _SubjectStatusFieldState extends State<_SubjectStatusField> {
  late String _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _value,
      decoration: const InputDecoration(labelText: 'Status'),
      items: [
        for (final s in kSubjectStatuses)
          DropdownMenuItem<String>(value: s, child: Text(_titleCase(s))),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() => _value = value);
        widget.onChanged(value);
      },
    );
  }
}

String _titleCase(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
