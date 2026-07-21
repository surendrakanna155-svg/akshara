import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../communication/teacher_teaching_context_provider.dart';
import '../teacher_mutations_provider.dart';
import '../teacher_requests.dart';
import '../teacher_unread_provider.dart';

/// TA-04 — Homework create persisted via [createTeacherHomeworkProvider].
class TeacherHomeworkCreateScreen extends ConsumerStatefulWidget {
  const TeacherHomeworkCreateScreen({super.key});

  @override
  ConsumerState<TeacherHomeworkCreateScreen> createState() =>
      _TeacherHomeworkCreateScreenState();
}

class _TeacherHomeworkCreateScreenState
    extends ConsumerState<TeacherHomeworkCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  // TCH-8: start blank (no demo defaults). Class/subject prefill from the
  // logged-in teacher's real assignment for convenience; the rest is empty.
  final _classController = TextEditingController();
  final _subjectController = TextEditingController();
  final _titleController = TextEditingController();
  final _studentController = TextEditingController();
  // HWK-4 / PRA-P1-30 — optional teacher attachment. When a name is entered the
  // client uploads a REAL worksheet file (presign → PUT → create with the
  // storage_path); the ref field stays a legacy free-text link.
  final _attachmentNameController = TextEditingController();
  final _attachmentRefController = TextEditingController();

  // HWK-3 — multi-section assign: the teacher builds up a list of target
  // class-sections. The class text field + "Add" button append to this set; the
  // homework is delivered to each. An empty list falls back to the single field.
  final List<String> _classLabels = [];

  // HWK-1 — a real due date chosen via a Material date picker (replaces the old
  // free-text due label). Null until the teacher picks one; Create is blocked
  // until it is set.
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    final teaching = ref.read(resolvedTeacherTeachingContextProvider);
    final prefill = teaching.classTeacherClassLabel ??
        (teaching.teachingClassLabels.isNotEmpty
            ? teaching.teachingClassLabels.first
            : '');
    if (prefill.isNotEmpty) _classLabels.add(prefill);
    _subjectController.text = teaching.primarySubject;
  }

  @override
  void dispose() {
    _classController.dispose();
    _subjectController.dispose();
    _titleController.dispose();
    _studentController.dispose();
    _attachmentNameController.dispose();
    _attachmentRefController.dispose();
    super.dispose();
  }

  void _addClassLabel() {
    final value = _classController.text.trim();
    if (value.isEmpty) return;
    if (!_classLabels.contains(value)) {
      setState(() => _classLabels.add(value));
    }
    _classController.clear();
  }

  /// ISO `YYYY-MM-DD` for the picked date (what the backend validates + stores).
  String? get _dueDateIso {
    final date = _dueDate;
    if (date == null) return null;
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Human "08 Jul 2026" label shown in the field and derived alongside the ISO.
  String _formatDue(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final d = date.day.toString().padLeft(2, '0');
    return '$d ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? today,
      // Allow a small past window (warn-not-block on the backend) plus a full
      // academic year ahead.
      firstDate: today.subtract(const Duration(days: 30)),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Create Homework',
        showAi: true,
        showProfile: true,
        unreadNotifications: ref.watch(teacherUnreadNotificationsProvider),
        onAiTap: () => context.push(RouteNames.aiAssistant),
        // F-128 — teacher-scoped notifications inbox (not the parent route).
        onNotificationsTap: () => context.push(RouteNames.teacherNotifications),
        // F-164 — the profile avatar opens the teacher profile, not Home.
        onProfileTap: () => context.go(RouteNames.teacherProfile),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'Assignment is delivered to parent and student in their preferred language.',
                style: context.aksharaText.bodyMedium,
              ),
              const SizedBox(height: AksharaSpacing.s4),
              // HWK-3 — multi-section: add one or more class-sections.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: QaTestKeys.teacherHomeworkClassChipsField,
                      controller: _classController,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _addClassLabel(),
                      decoration: const InputDecoration(
                        labelText: 'Class label',
                        hintText: 'e.g. 8-A',
                        border: OutlineInputBorder(),
                      ),
                      // Only required when no chips have been added yet.
                      validator: (v) => (_classLabels.isEmpty &&
                              (v == null || v.trim().isEmpty))
                          ? 'Add at least one class'
                          : null,
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s2),
                  IconButton.filledTonal(
                    key: QaTestKeys.teacherHomeworkAddClassButton,
                    onPressed: _addClassLabel,
                    icon: const Icon(Icons.add),
                    tooltip: 'Add class',
                  ),
                ],
              ),
              if (_classLabels.isNotEmpty) ...[
                const SizedBox(height: AksharaSpacing.s2),
                Wrap(
                  spacing: AksharaSpacing.s2,
                  runSpacing: AksharaSpacing.s1,
                  children: [
                    for (final label in _classLabels)
                      InputChip(
                        label: Text(label),
                        onDeleted: () =>
                            setState(() => _classLabels.remove(label)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AksharaSpacing.s3),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AksharaSpacing.s3),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Assignment title (English)',
                  hintText: 'e.g. Algebra practice worksheet',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AksharaSpacing.s3),
              FormField<DateTime>(
                validator: (_) =>
                    _dueDate == null ? 'Pick a due date' : null,
                builder: (field) {
                  return InkWell(
                    key: QaTestKeys.teacherHomeworkDueDateField,
                    onTap: () async {
                      await _pickDueDate();
                      field.didChange(_dueDate);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Due date',
                        border: const OutlineInputBorder(),
                        errorText: field.errorText,
                        suffixIcon: const Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(
                        _dueDate == null
                            ? 'Select a due date'
                            : _formatDue(_dueDate!),
                        style: context.aksharaText.bodyLarge,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AksharaSpacing.s3),
              TextFormField(
                controller: _studentController,
                decoration: const InputDecoration(
                  labelText: 'Student name (blank = whole class)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              // HWK-4 — optional teacher attachment (reference/label, not a real
              // file upload: paste a name + an optional link/reference).
              TextFormField(
                key: QaTestKeys.teacherHomeworkAttachmentNameField,
                controller: _attachmentNameController,
                decoration: const InputDecoration(
                  labelText: 'Attachment name (optional)',
                  hintText: 'e.g. worksheet.pdf',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              TextFormField(
                key: QaTestKeys.teacherHomeworkAttachmentRefField,
                controller: _attachmentRefController,
                decoration: const InputDecoration(
                  labelText: 'Attachment reference / link (optional)',
                  hintText: 'e.g. shared drive link',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AksharaSpacing.s5),
              FilledButton(
                key: QaTestKeys.teacherHomeworkCreateButton,
                onPressed: () async {
                  // HWK-3 — fold any typed-but-not-added class into the list so
                  // a teacher who types a class and taps Create isn't dropped.
                  final typed = _classController.text.trim();
                  if (typed.isNotEmpty && !_classLabels.contains(typed)) {
                    setState(() => _classLabels.add(typed));
                    _classController.clear();
                  }
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  if (_classLabels.isEmpty) return;
                  final dueIso = _dueDateIso;
                  if (dueIso == null) return;

                  final messenger = ScaffoldMessenger.of(context);
                  final router = GoRouter.of(context);
                  final studentName = _studentController.text.trim();
                  final attachmentName = _attachmentNameController.text.trim();
                  final attachmentRef = _attachmentRefController.text.trim();

                  try {
                    await ref
                        .read(createTeacherHomeworkProvider.notifier)
                        .execute(
                          TeacherHomeworkCreateRequest(
                            classLabel: _classLabels.first,
                            classLabels: List<String>.from(_classLabels),
                            subject: _subjectController.text.trim(),
                            title: _titleController.text.trim(),
                            dueDate: dueIso,
                            dueLabel: _formatDue(_dueDate!),
                            studentName:
                                studentName.isEmpty ? null : studentName,
                            attachmentName:
                                attachmentName.isEmpty ? null : attachmentName,
                            attachmentRef:
                                attachmentRef.isEmpty ? null : attachmentRef,
                          ),
                        );

                    final error =
                        ref.read(createTeacherHomeworkProvider).error;
                    if (error != null) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Could not create homework.'),
                        ),
                      );
                      return;
                    }

                    messenger.showSnackBar(
                      const SnackBar(content: Text('Homework created.')),
                    );
                    router.go(RouteNames.teacherHomework);
                  } catch (_) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Could not create homework.'),
                      ),
                    );
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
