import 'package:flutter/foundation.dart';

import '../admissions_models.dart';

/// Per-field validation errors for enrollment wizard steps.
@immutable
class EnrollmentStepValidation {
  const EnrollmentStepValidation({this.fieldErrors = const {}});

  final Map<String, String> fieldErrors;

  bool get isValid => fieldErrors.isEmpty;

  String? errorFor(String field) => fieldErrors[field];
}

EnrollmentStepValidation validateEnrollmentStep(
  EnrollmentStep step,
  EnrollmentFormState state,
) {
  final errors = <String, String>{};

  switch (step) {
    case EnrollmentStep.studentProfile:
      if (state.student.fullName.trim().length < 2) {
        errors['fullName'] = 'Enter the student full name';
      }
      if (state.student.dateOfBirth.trim().isEmpty) {
        errors['dateOfBirth'] = 'Date of birth is required';
      }
      if (state.student.gender.trim().isEmpty) {
        errors['gender'] = 'Gender is required';
      }
      final aadhaar = state.student.aadhaar.replaceAll(RegExp(r'\D'), '');
      if (aadhaar.length != 12) {
        errors['aadhaar'] = 'Aadhaar must be 12 digits';
      }
    case EnrollmentStep.parentInformation:
      if (state.parent.guardianName.trim().length < 2) {
        errors['guardianName'] = 'Guardian name is required';
      }
      if (state.parent.relationship.trim().isEmpty) {
        errors['relationship'] = 'Relationship is required';
      }
      final phone = state.parent.phone.replaceAll(RegExp(r'\D'), '');
      if (phone.length < 10) {
        errors['phone'] = 'Enter a valid 10-digit phone number';
      }
      final email = state.parent.email.trim();
      if (email.isNotEmpty &&
          (!email.contains('@') || !email.contains('.'))) {
        errors['email'] = 'Enter a valid email address';
      }
    case EnrollmentStep.academicInformation:
      if (state.academic.seekingClass.trim().isEmpty) {
        errors['seekingClass'] = 'Select a class';
      }
      if (state.academic.academicYear.trim().isEmpty) {
        errors['academicYear'] = 'Select an academic year';
      }
    case EnrollmentStep.reviewSubmit:
      break;
  }

  return EnrollmentStepValidation(fieldErrors: errors);
}

bool enrollmentFormHasDraftChanges(EnrollmentFormState state) {
  return state.student.fullName.isNotEmpty ||
      state.student.dateOfBirth.isNotEmpty ||
      state.parent.guardianName.isNotEmpty ||
      state.parent.phone.isNotEmpty ||
      state.academic.previousSchool.isNotEmpty;
}
