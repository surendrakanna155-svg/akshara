import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/exams/exam_administration_requests.dart';
import '../../../../core/repositories/academic/academic_models.dart';
import '../../../../core/repositories/academic/academic_catalog_provider.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../education/education_models.dart';
import '../../../school_completion/school_completion_providers.dart';
import '../../../../shared/forms/akshara_form_field.dart';
import '../../../../shared/widgets/akshara_dialog.dart';
import '../../../../shared/widgets/akshara_motion.dart';
import '../../../../theme/spacing.dart';
import '../exam_administration_provider.dart';
import '../exam_settings_provider.dart';
import '../../../../core/errors/error_text.dart';

Future<void> showExamCreateDialog(BuildContext context, WidgetRef ref) async {
  final suggestedTerms = ref.read(examReportSettingsProvider).suggestedTerms;
  final titleController = TextEditingController();
  final termController = TextEditingController(text: 'Term 2');
  final dateController = TextEditingController(text: '15 Mar 2026');
  final timeController = TextEditingController(text: '9:00 AM - 10:30 AM');
  final venueController = TextEditingController(text: 'Room 8A');
  final syllabusController = TextEditingController();
  final maxMarksController = TextEditingController(text: '80');

  String? selectedGrade = '8';
  String? selectedSection = 'A';
  String? selectedSubjectName = 'Mathematics';
  EduExamType examType = EduExamType.halfYearly;

  final subjects = await ref.read(subjectsProvider.future);
  final catalog = await ref.read(academicCatalogFutureProvider.future);

  if (!context.mounted) return;

  List<AcademicSection> sectionsForGrade(String? grade) {
    if (grade == null || grade.isEmpty) return const [];
    return catalog.sections
        .where((section) => section.className == grade)
        .toList();
  }

  var gradeSections = sectionsForGrade(selectedGrade);
  if (gradeSections.isEmpty && catalog.sections.isNotEmpty) {
    selectedGrade = catalog.classes
        .map((cls) => cls.className)
        .firstWhere((name) => name == '8', orElse: () => catalog.classes.first.className);
    gradeSections = sectionsForGrade(selectedGrade);
  }
  if (gradeSections.isNotEmpty) {
    selectedSection = gradeSections.first.sectionName;
  }

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AksharaAlertDialog(
        title: 'Create exam',
        icon: Icons.assignment_outlined,
        scrollable: true,
        content: AksharaDialogFormBody(
          children: [
            AksharaFormField(
              label: 'Exam title',
              controller: titleController,
              required: true,
            ),
            DropdownButtonFormField<String>(
              initialValue: selectedGrade,
              decoration: const InputDecoration(labelText: 'Class'),
              items: [
                for (final cls in catalog.classes)
                  DropdownMenuItem(
                    value: cls.className,
                    child: Text(cls.className),
                  ),
              ],
              onChanged: (value) => setState(() {
                selectedGrade = value;
                final nextSections = sectionsForGrade(value);
                selectedSection =
                    nextSections.isNotEmpty ? nextSections.first.sectionName : null;
              }),
            ),
            DropdownButtonFormField<String>(
              initialValue: selectedSection,
              decoration: const InputDecoration(labelText: 'Section'),
              items: [
                for (final section in sectionsForGrade(selectedGrade))
                  DropdownMenuItem(
                    value: section.sectionName,
                    child: Text(section.sectionName),
                  ),
              ],
              onChanged: (value) => setState(() => selectedSection = value),
            ),
            DropdownButtonFormField<String>(
              initialValue: selectedSubjectName,
              decoration: const InputDecoration(labelText: 'Subject'),
              items: [
                for (final subject in subjects)
                  DropdownMenuItem(
                    value: subject.subjectName,
                    child: Text(subject.subjectName),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => selectedSubjectName = value),
            ),
            DropdownButtonFormField<EduExamType>(
              initialValue: examType,
              decoration: const InputDecoration(labelText: 'Exam type'),
              items: EduExamType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => examType = value);
              },
            ),
            AksharaFormField(
              label: 'Academic term',
              controller: termController,
            ),
            if (suggestedTerms.isNotEmpty)
              Wrap(
                spacing: AksharaSpacing.s2,
                children: [
                  for (final term in suggestedTerms)
                    ActionChip(
                      key: ValueKey('exam_term_chip_$term'),
                      label: Text(term),
                      onPressed: () =>
                          setState(() => termController.text = term),
                    ),
                ],
              ),
            AksharaFormField(
              label: 'Exam date',
              controller: dateController,
              required: true,
            ),
            AksharaFormField(
              label: 'Time',
              controller: timeController,
            ),
            AksharaFormField(
              label: 'Venue',
              controller: venueController,
            ),
            AksharaFormField(
              label: 'Syllabus scope',
              controller: syllabusController,
            ),
            AksharaFormField(
              label: 'Max marks',
              controller: maxMarksController,
              required: true,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          AksharaDialogActions(
            cancelLabel: 'Cancel',
            confirmLabel: 'Create',
            confirmKey: QaTestKeys.examAdminCreateSubmitButton,
            onCancel: () => Navigator.of(context).pop(false),
            onConfirm: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final maxMarks = int.tryParse(maxMarksController.text.trim());
  if (maxMarks == null || maxMarks <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Max marks must be greater than zero.')),
    );
    return;
  }

  if (titleController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exam title is required.')),
    );
    return;
  }

  try {
    await ref.read(examAdminMutationProvider.notifier).createExam(
          CreateExamAdministrationRequest(
            title: titleController.text.trim(),
            subject: selectedSubjectName ?? 'Mathematics',
            grade: selectedGrade ?? '8',
            section: selectedSection ?? 'A',
            termLabel: termController.text.trim(),
            dateLabel: dateController.text.trim(),
            timeLabel: timeController.text.trim(),
            venueLabel: venueController.text.trim(),
            syllabusLabel: syllabusController.text.trim(),
            maxMarks: maxMarks,
            examType: examType,
          ),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exam created')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(aksharaErrorMessage(error))),
    );
  }
}
