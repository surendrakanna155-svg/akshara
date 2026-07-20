import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/academic/academic_catalog_provider.dart';
import '../../core/repositories/academic/academic_models.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/forms/akshara_form_field.dart';
import '../../shared/widgets/akshara_dialog.dart';
import '../../shared/widgets/akshara_motion.dart';
import 'school_completion_models.dart';
import 'school_completion_providers.dart';

/// Lesson-log outcomes accepted by the backend
/// (`teacher_lesson_logs.outcome` CHECK constraint). "Partial" is the real,
/// already-supported way a teacher records "in progress" — there is no
/// separate topic-status write path for it server-side.
const List<String> kLessonOutcomes = <String>[
  'completed',
  'partial',
  'needs_revision',
  'cancelled',
];

String lessonOutcomeLabel(String outcome) => switch (outcome) {
      'completed' => 'Completed',
      'partial' => 'Partial / in progress',
      'needs_revision' => 'Needs revision',
      'cancelled' => 'Cancelled',
      _ => outcome,
    };

/// Real "log lesson" capture: a REAL class (from the academic catalog), a
/// REAL subject (from the subject catalog), a topic description, an outcome,
/// and an optional note — replaces the previous hardcoded
/// `className: 'Grade 8', topic: 'Fractions revision', subjectId: 'sub_2'`
/// demo values (P1 fix, caps 58-60).
Future<void> showLogLessonDialog(BuildContext context, WidgetRef ref) async {
  final List<AcademicClass> classes;
  final List<AcademicSubject> subjects;
  try {
    classes = (await ref.read(academicCatalogFutureProvider.future)).classes;
    subjects = await ref.read(subjectsProvider.future);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
      SnackBar(content: Text('Could not load classes/subjects: $error')),
    );
    return;
  }
  if (!context.mounted) return;
  if (classes.isEmpty || subjects.isEmpty) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
      const SnackBar(
        content: Text(
          'Add at least one class and one subject before logging a lesson.',
        ),
      ),
    );
    return;
  }

  final formKey = GlobalKey<FormState>();
  final topicController = TextEditingController();
  final notesController = TextEditingController();
  var selectedClassName = classes.first.className;
  var selectedSubjectId = subjects.first.id;
  var outcome = kLessonOutcomes.first;

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AksharaAlertDialog(
        title: 'Log lesson',
        icon: Icons.history_edu_outlined,
        scrollable: true,
        content: Form(
          key: formKey,
          child: AksharaDialogFormBody(
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedClassName,
                decoration: const InputDecoration(labelText: 'Class'),
                items: [
                  for (final c in classes)
                    DropdownMenuItem<String>(
                      value: c.className,
                      child: Text(c.className),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => selectedClassName = value);
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: selectedSubjectId,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: [
                  for (final s in subjects)
                    DropdownMenuItem<String>(
                      value: s.id,
                      child: Text(s.subjectName),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => selectedSubjectId = value);
                },
              ),
              AksharaFormField(
                label: 'Topic taught',
                required: true,
                controller: topicController,
                hint: 'e.g. Linear equations — word problems',
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Describe the topic taught'
                    : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: outcome,
                decoration: const InputDecoration(labelText: 'Outcome'),
                items: [
                  for (final o in kLessonOutcomes)
                    DropdownMenuItem<String>(
                      value: o,
                      child: Text(lessonOutcomeLabel(o)),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => outcome = value);
                },
              ),
              AksharaFormField(
                label: 'Notes',
                controller: notesController,
                hint: 'Optional',
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          AksharaDialogActions(
            confirmLabel: 'Save',
            confirmKey: QaTestKeys.lessonLogCreateSubmitButton,
            onCancel: () => Navigator.of(context).pop(false),
            onConfirm: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(true);
              }
            },
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final created =
        await ref.read(schoolCompletionRepositoryProvider).createLessonLog(
              query: ref.read(schoolCompletionQueryProvider),
              className: selectedClassName,
              topic: topicController.text.trim(),
              subjectId: selectedSubjectId,
              outcome: outcome,
              notes: notesController.text.trim().isEmpty
                  ? null
                  : notesController.text.trim(),
            );
    ref.invalidate(lessonLogsProvider(null));
    ref.invalidate(teacherProgressProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Lesson logged')));

    // Only a "completed" outcome can legitimately close out a syllabus topic —
    // offer to link it immediately while the log is fresh in context.
    if (outcome == 'completed') {
      await showLinkSyllabusTopicDialog(context, ref, log: created);
    }
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
      SnackBar(content: Text('Could not log lesson: $error')),
    );
  }
}

/// Lets the teacher pick the REAL syllabus topic (a real `syllabus_topics.id`)
/// that a completed lesson log corresponds to, then calls
/// [SchoolCompletionRepository.completeTopic] with that real id — replacing
/// the previous `topic_${log.id}` fabrication that failed the
/// `syllabus_topic_completions` FK (P1 fix, cap 61).
Future<void> showLinkSyllabusTopicDialog(
  BuildContext context,
  WidgetRef ref, {
  required LessonLogEntry log,
}) async {
  final subjectId = log.subjectId;
  if (subjectId == null) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
      const SnackBar(
        content: Text(
          'This lesson log has no subject on record, so it cannot be linked '
          'to a syllabus topic.',
        ),
      ),
    );
    return;
  }

  final List<SyllabusTopic> topics;
  try {
    topics = await ref.read(schoolCompletionRepositoryProvider).listSyllabusTopics(
          query: ref.read(schoolCompletionQueryProvider),
          className: log.className,
          subjectId: subjectId,
        );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
      SnackBar(content: Text('Could not load syllabus topics: $error')),
    );
    return;
  }
  if (!context.mounted) return;

  final pending = topics.where((t) => t.status != 'completed').toList();
  if (pending.isEmpty) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
      SnackBar(
        content: Text(
          topics.isEmpty
              ? 'No syllabus topics found for ${log.className}. Generate the '
                  'syllabus first (Syllabus Automation) to link progress.'
              : 'Every syllabus topic for ${log.className} is already marked '
                  'complete.',
        ),
      ),
    );
    return;
  }

  var selectedTopicId = pending.first.id;
  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AksharaAlertDialog(
        title: 'Link syllabus topic',
        icon: Icons.fact_check_outlined,
        scrollable: true,
        content: AksharaDialogFormBody(
          children: [
            Text('Which syllabus topic does "${log.topic}" complete?'),
            for (final topic in pending)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                selected: topic.id == selectedTopicId,
                leading: Icon(
                  topic.id == selectedTopicId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(topic.topicName),
                onTap: () => setState(() => selectedTopicId = topic.id),
              ),
          ],
        ),
        actions: [
          AksharaDialogActions(
            confirmLabel: 'Mark complete',
            confirmKey: QaTestKeys.lessonLogTopicLinkSubmitButton,
            onCancel: () => Navigator.of(context).pop(false),
            onConfirm: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(schoolCompletionRepositoryProvider).completeTopic(
          query: ref.read(schoolCompletionQueryProvider),
          topicId: selectedTopicId,
          lessonLogId: log.id,
        );
    ref.invalidate(syllabusTopicsProvider);
    ref.invalidate(syllabusChaptersProvider);
    ref.invalidate(teacherProgressProvider);
    ref.invalidate(principalAcademicProgressProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
      const SnackBar(content: Text('Syllabus topic marked complete.')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
      SnackBar(content: Text('Could not complete topic: $error')),
    );
  }
}
