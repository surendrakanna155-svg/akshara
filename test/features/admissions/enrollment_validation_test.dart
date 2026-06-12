import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/features/admissions/admissions_models.dart';
import 'package:akshara_erp/features/admissions/enrollment/enrollment_validation.dart';

void main() {
  group('enrollment validation', () {
    test('blocks empty student profile step', () {
      const state = EnrollmentFormState();
      final result = validateEnrollmentStep(EnrollmentStep.studentProfile, state);
      expect(result.isValid, isFalse);
      expect(result.fieldErrors.containsKey('fullName'), isTrue);
      expect(result.fieldErrors.containsKey('aadhaar'), isTrue);
    });

    test('accepts valid student profile step', () {
      const state = EnrollmentFormState(
        student: EnrollmentStudentProfile(
          fullName: 'Ravi Kumar',
          dateOfBirth: '01 Jan 2012',
          gender: 'Male',
          aadhaar: '123456789012',
        ),
      );
      final result = validateEnrollmentStep(EnrollmentStep.studentProfile, state);
      expect(result.isValid, isTrue);
    });

    test('validates parent phone and optional email', () {
      const state = EnrollmentFormState(
        parent: EnrollmentParentInfo(
          guardianName: 'Suresh Kumar',
          relationship: 'Father',
          phone: '12345',
          email: 'bad-email',
        ),
      );
      final result = validateEnrollmentStep(EnrollmentStep.parentInformation, state);
      expect(result.fieldErrors['phone'], isNotNull);
      expect(result.fieldErrors['email'], isNotNull);
    });
  });
}
