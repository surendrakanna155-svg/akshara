import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';
import '../admissions_mutations_provider.dart';
import '../admissions_requests.dart';
import 'enrollment_validation.dart';

final admissionsEnrollmentLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsEnrollmentErrorProvider = StateProvider<bool>((ref) => false);

final admissionsEnrollmentPrefillFutureProvider =
    FutureProvider<EnrollmentFormState>((ref) async {
  return ref.read(admissionsRepositoryProvider).getEnrollmentPrefill(
        query: ref.watch(repositoryQueryProvider),
      );
});

final admissionsEnrollmentPrefillProvider =
    Provider<EnrollmentFormState?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(admissionsEnrollmentPrefillFutureProvider),
    manualLoading: ref.watch(admissionsEnrollmentLoadingProvider),
    manualError: ref.watch(admissionsEnrollmentErrorProvider),
    manualEmpty: false,
  );
});

final admissionsEnrollmentViewStateProvider =
    Provider<AdmissionsViewState<EnrollmentFormState>>((ref) {
  return resolveAdmissionsAsync(
    ref.watch(admissionsEnrollmentPrefillFutureProvider),
    forceLoading: ref.watch(admissionsEnrollmentLoadingProvider),
    forceError: ref.watch(admissionsEnrollmentErrorProvider),
  );
});

class EnrollmentFormNotifier extends Notifier<EnrollmentFormState> {
  @override
  EnrollmentFormState build() =>
      ref.watch(admissionsEnrollmentPrefillProvider) ?? const EnrollmentFormState();

  void setStep(EnrollmentStep step) {
    state = state.copyWith(currentStep: step);
  }

  /// Returns validation errors for the current step, or null if valid.
  EnrollmentStepValidation? validateCurrentStep() {
    final result = validateEnrollmentStep(state.currentStep, state);
    return result.isValid ? null : result;
  }

  bool nextStep() {
    final validation = validateEnrollmentStep(state.currentStep, state);
    if (!validation.isValid) {
      state = state.copyWith(stepFieldErrors: validation.fieldErrors);
      return false;
    }
    state = state.copyWith(clearStepFieldErrors: true);
    final steps = EnrollmentStep.values;
    final index = steps.indexOf(state.currentStep);
    if (index < steps.length - 1) {
      state = state.copyWith(currentStep: steps[index + 1]);
    }
    return true;
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
    try {
      final record = await ref.read(submitEnrollmentProvider.notifier).execute(
            EnrollmentSubmitRequest(
              student: state.student,
              parent: state.parent,
              academic: state.academic,
            ),
          );
      state = state.copyWith(
        isSubmitting: false,
        isSubmitted: true,
        generatedAdmissionNumber: record?.generatedAdmissionNumber,
      );
    } catch (_) {
      state = state.copyWith(isSubmitting: false);
      rethrow;
    }
  }
}

final admissionsEnrollmentProvider =
    NotifierProvider<EnrollmentFormNotifier, EnrollmentFormState>(
  EnrollmentFormNotifier.new,
);
