import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/homework/school_homework_store.dart';
import '../../../core/repositories/mock/mock_canonical_student_registry.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'teacher_homework_provider.dart';

/// TA-04 — Homework create wired to shared [SchoolHomeworkStore].
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
                onPressed: () {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  final classLabel = _classController.text.trim();
                  final parsed = SchoolHomeworkStore.parseClassLabel(classLabel);
                  final title = _titleController.text.trim();
                  final dueLabel = _dueController.text.trim();
                  final studentName = _studentController.text.trim();
                  final teacherName =
                      ref.read(authProvider).displayName ?? 'Priya Sharma';

                  CanonicalStudentRecord? targetStudent;
                  if (studentName.isNotEmpty) {
                    for (final record in MockCanonicalStudentRegistry.all) {
                      if (record.studentName.toLowerCase() ==
                          studentName.toLowerCase()) {
                        targetStudent = record;
                        break;
                      }
                    }
                  }

                  final record = SchoolHomeworkStore.instance.create(
                    grade: parsed.grade,
                    section: parsed.section,
                    subject: _subjectController.text.trim(),
                    title: title,
                    dueLabel: dueLabel.isEmpty ? '—' : dueLabel,
                    teacherName: teacherName,
                    targetSisStudentIds: targetStudent == null
                        ? const []
                        : [targetStudent.sisStudentId],
                  );

                  final assignment =
                      SchoolHomeworkStore.instance.toTeacherAssignment(record);

                  final createdNotifier = ref
                      .read(teacherHomeworkCreatedAssignmentsProvider.notifier);
                  createdNotifier.state = [
                    assignment,
                    ...ref.read(teacherHomeworkCreatedAssignmentsProvider),
                  ];

                  ref
                      .read(teacherHomeworkAssignmentProvider.notifier)
                      .state = record.id;
                  ref.read(teacherHomeworkEmptyProvider.notifier).state = false;

                  context.go(RouteNames.teacherHomework);
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
