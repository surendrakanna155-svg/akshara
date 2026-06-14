import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../theme/spacing.dart';
import '../sis_models.dart';
import '../sis_mutations_provider.dart';
import '../sis_requests.dart';

class SisProfileEditSheet extends ConsumerStatefulWidget {
  const SisProfileEditSheet({
    super.key,
    required this.profile,
  });

  final SisStudentProfile profile;

  @override
  ConsumerState<SisProfileEditSheet> createState() =>
      _SisProfileEditSheetState();
}

class _SisProfileEditSheetState extends ConsumerState<SisProfileEditSheet> {
  late final TextEditingController _studentNameController;
  late final TextEditingController _admissionController;
  late final TextEditingController _classController;
  late final TextEditingController _sectionController;
  late final TextEditingController _academicYearController;
  late final TextEditingController _genderController;
  late final TextEditingController _dobController;
  late final TextEditingController _guardianController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final student = widget.profile.student;
    _studentNameController = TextEditingController(text: student.studentName);
    _admissionController = TextEditingController(text: student.admissionNumber);
    _classController = TextEditingController(text: student.classLabel);
    _sectionController = TextEditingController(text: student.section);
    _academicYearController = TextEditingController(text: student.academicYear);
    _genderController = TextEditingController(text: student.gender);
    _dobController = TextEditingController(text: student.dateOfBirth);
    _guardianController =
        TextEditingController(text: widget.profile.parent.guardianName);
    _phoneController = TextEditingController(text: widget.profile.parent.phone);
    _emailController = TextEditingController(text: widget.profile.parent.email);
  }

  @override
  void dispose() {
    _studentNameController.dispose();
    _admissionController.dispose();
    _classController.dispose();
    _sectionController.dispose();
    _academicYearController.dispose();
    _genderController.dispose();
    _dobController.dispose();
    _guardianController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AksharaSpacing.s4,
        right: AksharaSpacing.s4,
        top: AksharaSpacing.s4,
        bottom: MediaQuery.of(context).viewInsets.bottom + AksharaSpacing.s4,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Edit student profile', style: TextStyle(fontSize: 18)),
            const SizedBox(height: AksharaSpacing.s3),
            _field(_studentNameController, 'Student name'),
            _field(_admissionController, 'Admission number'),
            _field(_classController, 'Class'),
            _field(_sectionController, 'Section'),
            _field(_academicYearController, 'Academic year'),
            _field(_genderController, 'Gender'),
            _field(_dobController, 'Date of birth'),
            _field(_guardianController, 'Parent / guardian name'),
            _field(_phoneController, 'Parent phone'),
            _field(_emailController, 'Parent email'),
            const SizedBox(height: AksharaSpacing.s3),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _saving ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AksharaSpacing.s2),
                FilledButton(
                  key: QaTestKeys.sisEditProfileSaveButton,
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(updateStudentProvider.notifier).execute(
            studentId: widget.profile.student.id,
            request: UpdateStudentRequest(
              studentName: _studentNameController.text.trim(),
              admissionNumber: _admissionController.text.trim(),
              classLabel: _classController.text.trim(),
              section: _sectionController.text.trim(),
              academicYear: _academicYearController.text.trim(),
              gender: _genderController.text.trim(),
              dateOfBirth: _dobController.text.trim(),
              guardianName: _guardianController.text.trim(),
              phone: _phoneController.text.trim(),
              email: _emailController.text.trim(),
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
