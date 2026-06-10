import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/repositories/academic/academic_catalog_provider.dart';
import '../../../../core/repositories/academic/academic_catalog_selection.dart';
import '../../../../core/repositories/academic/academic_year_label.dart';
import '../../../../theme/spacing.dart';
import '../../admissions_models.dart';

/// Step form sections for the AD-05 enrollment wizard.
class AdmissionsEnrollmentStudentStep extends StatelessWidget {
  const AdmissionsEnrollmentStudentStep({
    super.key,
    required this.student,
    required this.onChanged,
  });

  final EnrollmentStudentProfile student;
  final ValueChanged<EnrollmentStudentProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Student profile step',
      child: Material(
        type: MaterialType.transparency,
        child: Column(
        children: [
          TextFormField(
            initialValue: student.fullName,
            decoration: const InputDecoration(labelText: 'Student full name *'),
            onChanged: (v) => onChanged(student.copyWith(fullName: v)),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          TextFormField(
            initialValue: student.dateOfBirth,
            decoration: const InputDecoration(labelText: 'Date of birth *'),
            onChanged: (v) => onChanged(student.copyWith(dateOfBirth: v)),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          TextFormField(
            initialValue: student.gender,
            decoration: const InputDecoration(labelText: 'Gender *'),
            onChanged: (v) => onChanged(student.copyWith(gender: v)),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          TextFormField(
            initialValue: student.aadhaar,
            decoration: const InputDecoration(labelText: 'Aadhaar number *'),
            onChanged: (v) => onChanged(student.copyWith(aadhaar: v)),
          ),
        ],
        ),
      ),
    );
  }
}

class AdmissionsEnrollmentParentStep extends StatelessWidget {
  const AdmissionsEnrollmentParentStep({
    super.key,
    required this.parent,
    required this.onChanged,
  });

  final EnrollmentParentInfo parent;
  final ValueChanged<EnrollmentParentInfo> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Parent information step',
      child: Material(
        type: MaterialType.transparency,
        child: Column(
        children: [
          TextFormField(
            initialValue: parent.guardianName,
            decoration: const InputDecoration(labelText: 'Guardian name *'),
            onChanged: (v) => onChanged(parent.copyWith(guardianName: v)),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          TextFormField(
            initialValue: parent.relationship,
            decoration: const InputDecoration(labelText: 'Relationship *'),
            onChanged: (v) => onChanged(parent.copyWith(relationship: v)),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          TextFormField(
            initialValue: parent.phone,
            decoration: const InputDecoration(labelText: 'Phone number *'),
            onChanged: (v) => onChanged(parent.copyWith(phone: v)),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          TextFormField(
            initialValue: parent.email,
            decoration: const InputDecoration(labelText: 'Email'),
            onChanged: (v) => onChanged(parent.copyWith(email: v)),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          TextFormField(
            initialValue: parent.address,
            decoration: const InputDecoration(labelText: 'Address'),
            maxLines: 2,
            onChanged: (v) => onChanged(parent.copyWith(address: v)),
          ),
        ],
        ),
      ),
    );
  }
}

class AdmissionsEnrollmentAcademicStep extends ConsumerWidget {
  const AdmissionsEnrollmentAcademicStep({
    super.key,
    required this.academic,
    required this.onChanged,
  });

  final EnrollmentAcademicInfo academic;
  final ValueChanged<EnrollmentAcademicInfo> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(classOptionsForYearProvider(academic.academicYear));
    final sections = ref.watch(
      sectionOptionsForYearClassProvider(
        YearClassSelection(
          yearLabel: academic.academicYear,
          className: academic.seekingClass,
        ),
      ),
    );
    final years = ref.watch(yearOptionsProvider);

    ref.listen<List<String>>(yearOptionsProvider, (_, next) {
      if (next.isEmpty) return;
      final resolved = resolveAcademicYearSelection(academic.academicYear, next);
      if (!academicYearLabelsEqual(resolved, academic.academicYear)) {
        onChanged(academic.copyWith(academicYear: resolved));
      }
    });

    return Semantics(
      container: true,
      label: 'Academic information step',
      child: Material(
        type: MaterialType.transparency,
        child: Column(
        children: [
          _CatalogDropdown(
            label: 'Seeking class *',
            value: academic.seekingClass,
            options: classes,
            onChanged: (value) {
              final filtered = ref.read(
                sectionOptionsForYearClassProvider(
                  YearClassSelection(
                    yearLabel: academic.academicYear,
                    className: value,
                  ),
                ),
              );
              onChanged(
                academic.copyWith(
                  seekingClass: value,
                  section: filtered.contains(academic.section)
                      ? academic.section
                      : (filtered.isNotEmpty ? filtered.first : academic.section),
                ),
              );
            },
          ),
          const SizedBox(height: AksharaSpacing.s4),
          _CatalogDropdown(
            label: 'Section',
            value: academic.section,
            options: sections,
            onChanged: (value) => onChanged(academic.copyWith(section: value)),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          _CatalogDropdown(
            label: 'Academic year *',
            value: academic.academicYear,
            options: years,
            resolveSelection: resolveAcademicYearSelection,
            onChanged: (value) {
              final filteredClasses = ref.read(classOptionsForYearProvider(value));
              onChanged(
                academic.copyWith(
                  academicYear: value,
                  seekingClass: filteredClasses.contains(academic.seekingClass)
                      ? academic.seekingClass
                      : (filteredClasses.isNotEmpty
                          ? filteredClasses.first
                          : academic.seekingClass),
                ),
              );
            },
          ),
          const SizedBox(height: AksharaSpacing.s4),
          TextFormField(
            initialValue: academic.previousSchool,
            decoration: const InputDecoration(labelText: 'Previous school'),
            onChanged: (v) => onChanged(academic.copyWith(previousSchool: v)),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          SwitchListTile(
            title: const Text('Needs transport'),
            value: academic.needsTransport,
            onChanged: (v) => onChanged(academic.copyWith(needsTransport: v)),
          ),
          SwitchListTile(
            title: const Text('Needs hostel'),
            value: academic.needsHostel,
            onChanged: (v) => onChanged(academic.copyWith(needsHostel: v)),
          ),
        ],
        ),
      ),
    );
  }
}

class AdmissionsEnrollmentReviewStep extends StatelessWidget {
  const AdmissionsEnrollmentReviewStep({
    super.key,
    required this.form,
  });

  final EnrollmentFormState form;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Review and submit enrollment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReviewSection(
            title: 'Student',
            lines: [
              form.student.fullName,
              form.student.dateOfBirth,
              form.student.gender,
              form.student.aadhaar,
            ],
          ),
          const SizedBox(height: AksharaSpacing.s4),
          _ReviewSection(
            title: 'Parent / Guardian',
            lines: [
              form.parent.guardianName,
              form.parent.relationship,
              form.parent.phone,
              form.parent.email,
              form.parent.address,
            ],
          ),
          const SizedBox(height: AksharaSpacing.s4),
          _ReviewSection(
            title: 'Academic',
            lines: [
              'Class ${form.academic.seekingClass} · Section ${form.academic.section}',
              'Year ${form.academic.academicYear}',
              form.academic.previousSchool,
              'Transport: ${form.academic.needsTransport ? 'Yes' : 'No'}',
              'Hostel: ${form.academic.needsHostel ? 'Yes' : 'No'}',
            ],
          ),
          if (form.isSubmitted && form.generatedAdmissionNumber != null) ...[
            const SizedBox(height: AksharaSpacing.s4),
            Text(
              'Admission number: ${form.generatedAdmissionNumber}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _CatalogDropdown extends StatelessWidget {
  const _CatalogDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.resolveSelection,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final String Function(String selected, List<String> options)? resolveSelection;

  @override
  Widget build(BuildContext context) {
    final selection = resolveSelection != null
        ? resolveSelection!(value, options)
        : options.contains(value)
            ? value
            : (options.isNotEmpty ? options.first : value);
    return Material(
      child: DropdownMenu<String>(
        key: ValueKey('$label-$selection'),
        initialSelection: selection,
        label: Text(label),
        expandedInsets: EdgeInsets.zero,
        dropdownMenuEntries: [
          for (final option in options)
            DropdownMenuEntry(value: option, label: option),
        ],
        onSelected: (selected) {
          if (selected != null) onChanged(selected);
        },
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AksharaSpacing.s2),
        for (final line in lines)
          if (line.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AksharaSpacing.s1),
              child: Text(line),
            ),
      ],
    );
  }
}
