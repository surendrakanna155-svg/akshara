import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admissions_models.dart';

final admissionsEnrollmentLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsEnrollmentErrorProvider = StateProvider<bool>((ref) => false);

class EnrollmentFormNotifier extends Notifier<EnrollmentFormState> {
  @override
  EnrollmentFormState build() => _mockPrefill();

  void setStep(EnrollmentStep step) {
    state = state.copyWith(currentStep: step);
  }

  void nextStep() {
    final steps = EnrollmentStep.values;
    final index = steps.indexOf(state.currentStep);
    if (index < steps.length - 1) {
      state = state.copyWith(currentStep: steps[index + 1]);
    }
  }

  void previousStep() {
    final steps = EnrollmentStep.values;
    final index = steps.indexOf(state.currentStep);
    if (index > 0) {
      state = state.copyWith(currentStep: steps[index - 1]);
    }
  }

  void updateStudent(EnrollmentStudentProfile student) {
    state = state.copyWith(student: student);
  }

  void updateParent(EnrollmentParentInfo parent) {
    state = state.copyWith(parent: parent);
  }

  void updateAcademic(EnrollmentAcademicInfo academic) {
    state = state.copyWith(academic: academic);
  }

  Future<void> submit() async {
    state = state.copyWith(isSubmitting: true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    state = state.copyWith(
      isSubmitting: false,
      isSubmitted: true,
      generatedAdmissionNumber: 'ADM-2026-0142',
    );
  }
}

final admissionsEnrollmentProvider =
    NotifierProvider<EnrollmentFormNotifier, EnrollmentFormState>(
  EnrollmentFormNotifier.new,
);

EnrollmentFormState _mockPrefill() {
  return const EnrollmentFormState(
    student: EnrollmentStudentProfile(
      fullName: 'Ananya Reddy',
      dateOfBirth: '12 Mar 2016',
      gender: 'Female',
      aadhaar: 'XXXX-XXXX-4521',
    ),
    parent: EnrollmentParentInfo(
      guardianName: 'Rajesh Reddy',
      relationship: 'Father',
      phone: '+91 98765 43210',
      email: 'rajesh.reddy@email.com',
      address: '12, Lake View Colony, Hyderabad',
    ),
    academic: EnrollmentAcademicInfo(
      seekingClass: '5',
      section: 'A',
      academicYear: '2026–27',
      previousSchool: 'Little Scholars Academy',
      needsTransport: true,
      needsHostel: false,
    ),
  );
}
