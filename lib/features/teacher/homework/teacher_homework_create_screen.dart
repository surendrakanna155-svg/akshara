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

  // HWK-1 — a real due date chosen via a Material date picker (replaces the old
  // free-text due label). Null until the teacher picks one; Create is blocked
  // until it is set.
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    final teaching = ref.read(resolvedTeacherTeachingContextProvider);
    _classController.text = teaching.classTeacherClassLabel ??
        (teaching.teachingClassLabels.isNotEmpty
            ? teaching.teachingClassLabels.first
            : '');
    _subjectController.text = teaching.primarySubject;
  }

  @override
  void dispose() {
    _classController.dispose();
    _subjectController.dispose();
    _titleController.dispose();
    _studentController.dispose();
    super.dispose();
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
        unreadNotifications: 1,
        onAiTap: () => context.push(RouteNames.aiAssistant),
        onNotificationsTap: () => context.push(RouteNames.parentNotifications),
        onProfileTap: () => context.go(RouteNames.teacherDashboard),
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
              TextFormField(
                controller: _classController,
                decoration: const InputDecoration(
                  labelText: 'Class label',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
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
              const SizedBox(height: AksharaSpacing.s5),
              FilledButton(
                key: QaTestKeys.teacherHomeworkCreateButton,
                onPressed: () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  final dueIso = _dueDateIso;
                  if (dueIso == null) return;

                  final messenger = ScaffoldMessenger.of(context);
                  final router = GoRouter.of(context);
                  final studentName = _studentController.text.trim();

                  try {
                    await ref
                        .read(createTeacherHomeworkProvider.notifier)
                        .execute(
                          TeacherHomeworkCreateRequest(
                            classLabel: _classController.text.trim(),
                            subject: _subjectController.text.trim(),
                            title: _titleController.text.trim(),
                            dueDate: dueIso,
                            dueLabel: _formatDue(_dueDate!),
                            studentName:
                                studentName.isEmpty ? null : studentName,
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
