import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/repositories/academic/academic_catalog_provider.dart';
import '../../../../core/repositories/academic/academic_catalog_selection.dart';
import '../../../../core/repositories/academic/academic_year_label.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../../shared/forms/forms.dart';
import '../../../../theme/spacing.dart';
import '../../admissions_models.dart';

/// Step form sections for the AD-05 enrollment wizard.
class AdmissionsEnrollmentStudentStep extends StatefulWidget {
  const AdmissionsEnrollmentStudentStep({
    super.key,
    required this.student,
    required this.onChanged,
    this.fieldErrors = const {},
  });

  final EnrollmentStudentProfile student;
  final ValueChanged<EnrollmentStudentProfile> onChanged;
  final Map<String, String> fieldErrors;

  @override
  State<AdmissionsEnrollmentStudentStep> createState() =>
      _AdmissionsEnrollmentStudentStepState();
}

class _AdmissionsEnrollmentStudentStepState
    extends State<AdmissionsEnrollmentStudentStep> {
  late final FocusNode _nameFocus;
  late final FocusNode _dobFocus;
  late final FocusNode _genderFocus;
  late final FocusNode _aadhaarFocus;

  @override
  void initState() {
    super.initState();
    _nameFocus = FocusNode();
    _dobFocus = FocusNode();
    _genderFocus = FocusNode();
    _aadhaarFocus = FocusNode();
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _dobFocus.dispose();
    _genderFocus.dispose();
    _aadhaarFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AksharaFormSection(
      title: 'Student profile',
      subtitle: 'Enter details exactly as on official documents.',
      children: [
        AksharaFormField(
          key: QaTestKeys.enrollmentStudentNameField,
          label: 'Student full name',
          required: true,
          hint: 'e.g. Ravi Kumar',
          initialValue: widget.student.fullName,
          focusNode: _nameFocus,
          textInputAction: TextInputAction.next,
          errorText: widget.fieldErrors['fullName'],
          onFieldSubmitted: (_) => focusNextField(_nameFocus, _dobFocus),
          onChanged: (v) => widget.onChanged(widget.student.copyWith(fullName: v)),
        ),
        AksharaFormField(
          label: 'Date of birth',
          required: true,
          hint: 'DD MMM YYYY',
          initialValue: widget.student.dateOfBirth,
          focusNode: _dobFocus,
          textInputAction: TextInputAction.next,
          readOnly: true,
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(2012, 6, 1),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                final label =
                    '${picked.day.toString().padLeft(2, '0')} ${_month(picked.month)} ${picked.year}';
                widget.onChanged(widget.student.copyWith(dateOfBirth: label));
              }
            },
          ),
          errorText: widget.fieldErrors['dateOfBirth'],
          onFieldSubmitted: (_) => focusNextField(_dobFocus, _genderFocus),
          onChanged: (v) =>
              widget.onChanged(widget.student.copyWith(dateOfBirth: v)),
        ),
        AksharaFormField(
          label: 'Gender',
          required: true,
          hint: 'Male / Female / Other',
          initialValue: widget.student.gender,
          focusNode: _genderFocus,
          textInputAction: TextInputAction.next,
          errorText: widget.fieldErrors['gender'],
          onFieldSubmitted: (_) => focusNextField(_genderFocus, _aadhaarFocus),
          onChanged: (v) => widget.onChanged(widget.student.copyWith(gender: v)),
        ),
        AksharaFormField(
          label: 'Aadhaar number',
          required: true,
          hint: '12-digit Aadhaar',
          keyboardType: TextInputType.number,
          initialValue: widget.student.aadhaar,
          focusNode: _aadhaarFocus,
          textInputAction: TextInputAction.done,
          errorText: widget.fieldErrors['aadhaar'],
          onChanged: (v) => widget.onChanged(widget.student.copyWith(aadhaar: v)),
        ),
      ],
    );
  }

  String _month(int month) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][month - 1];
}

class AdmissionsEnrollmentParentStep extends StatefulWidget {
  const AdmissionsEnrollmentParentStep({
    super.key,
    required this.parent,
    required this.onChanged,
    this.fieldErrors = const {},
  });

  final EnrollmentParentInfo parent;
  final ValueChanged<EnrollmentParentInfo> onChanged;
  final Map<String, String> fieldErrors;

  @override
  State<AdmissionsEnrollmentParentStep> createState() =>
      _AdmissionsEnrollmentParentStepState();
}

class _AdmissionsEnrollmentParentStepState
    extends State<AdmissionsEnrollmentParentStep> {
  late final FocusNode _nameFocus;
  late final FocusNode _relationshipFocus;
  late final FocusNode _phoneFocus;
  late final FocusNode _emailFocus;

  @override
  void initState() {
    super.initState();
    _nameFocus = FocusNode();
    _relationshipFocus = FocusNode();
    _phoneFocus = FocusNode();
    _emailFocus = FocusNode();
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _relationshipFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AksharaFormSection(
      title: 'Parent / guardian',
      subtitle: 'Primary contact for school communication.',
      children: [
        AksharaFormField(
          label: 'Guardian name',
          required: true,
          initialValue: widget.parent.guardianName,
          focusNode: _nameFocus,
          textInputAction: TextInputAction.next,
          errorText: widget.fieldErrors['guardianName'],
          onFieldSubmitted: (_) => focusNextField(_nameFocus, _relationshipFocus),
          onChanged: (v) =>
              widget.onChanged(widget.parent.copyWith(guardianName: v)),
        ),
        AksharaFormField(
          label: 'Relationship',
          required: true,
          hint: 'Father / Mother / Guardian',
          initialValue: widget.parent.relationship,
          focusNode: _relationshipFocus,
          textInputAction: TextInputAction.next,
          errorText: widget.fieldErrors['relationship'],
          onFieldSubmitted: (_) => focusNextField(_relationshipFocus, _phoneFocus),
          onChanged: (v) =>
              widget.onChanged(widget.parent.copyWith(relationship: v)),
        ),
        AksharaFormField(
          label: 'Phone number',
          required: true,
          keyboardType: TextInputType.phone,
          initialValue: widget.parent.phone,
          focusNode: _phoneFocus,
          textInputAction: TextInputAction.next,
          errorText: widget.fieldErrors['phone'],
          onFieldSubmitted: (_) => focusNextField(_phoneFocus, _emailFocus),
          onChanged: (v) => widget.onChanged(widget.parent.copyWith(phone: v)),
        ),
        AksharaFormField(
          label: 'Email',
          hint: 'Optional',
          keyboardType: TextInputType.emailAddress,
          initialValue: widget.parent.email,
          focusNode: _emailFocus,
          textInputAction: TextInputAction.next,
          errorText: widget.fieldErrors['email'],
          onChanged: (v) => widget.onChanged(widget.parent.copyWith(email: v)),
        ),
        AksharaFormField(
          label: 'Address',
          hint: 'Residential address',
          maxLines: 2,
          initialValue: widget.parent.address,
          onChanged: (v) => widget.onChanged(widget.parent.copyWith(address: v)),
        ),
      ],
    );
  }
}

class AdmissionsEnrollmentAcademicStep extends ConsumerWidget {
  const AdmissionsEnrollmentAcademicStep({
    super.key,
    required this.academic,
    required this.onChanged,
    this.fieldErrors = const {},
  });

  final EnrollmentAcademicInfo academic;
  final ValueChanged<EnrollmentAcademicInfo> onChanged;
  final Map<String, String> fieldErrors;

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

    return AksharaFormSection(
      title: 'Academic information',
      subtitle: 'Class placement for the upcoming academic year.',
      children: [
        AksharaSearchableDropdown(
          label: 'Seeking class',
          required: true,
          value: academic.seekingClass,
          options: classes,
          errorText: fieldErrors['seekingClass'],
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
        AksharaSearchableDropdown(
          label: 'Section',
          value: academic.section,
          options: sections,
          onChanged: (value) => onChanged(academic.copyWith(section: value)),
        ),
        AksharaSearchableDropdown(
          label: 'Academic year',
          required: true,
          value: academic.academicYear,
          options: years,
          errorText: fieldErrors['academicYear'],
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
        AksharaFormField(
          label: 'Previous school',
          hint: 'Optional',
          initialValue: academic.previousSchool,
          onChanged: (v) => onChanged(academic.copyWith(previousSchool: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Needs transport'),
          subtitle: const Text('School bus route assignment'),
          value: academic.needsTransport,
          onChanged: (v) => onChanged(academic.copyWith(needsTransport: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Needs hostel'),
          subtitle: const Text('Residential facility request'),
          value: academic.needsHostel,
          onChanged: (v) => onChanged(academic.copyWith(needsHostel: v)),
        ),
      ],
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
    return AksharaFormSection(
      title: 'Review & submit',
      subtitle: 'Confirm details before generating the admission record.',
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
