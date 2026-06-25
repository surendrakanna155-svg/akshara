import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
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

  final _classController = TextEditingController(text: '8-A');
  final _subjectController = TextEditingController(text: 'Mathematics');
  final _titleController = TextEditingController(text: 'Mathematics Practice');
  final _dueController = TextEditingController(text: 'Due next Monday');
  final _studentController = TextEditingController(text: 'Ravi Kumar');

  @override
  void dispose() {
    _classController.dispose();
    _subjectController.dispose();
    _titleController.dispose();
    _dueController.dispose();
    _studentController.dispose();
    super.dispose();
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
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AksharaSpacing.s3),
              TextFormField(
                controller: _dueController,
                decoration: const InputDecoration(
                  labelText: 'Due label',
                  border: OutlineInputBorder(),
                ),
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
                onPressed: () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;

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
                            dueLabel: _dueController.text.trim(),
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
