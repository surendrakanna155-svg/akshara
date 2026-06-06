import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../theme/spacing.dart';
import '../admissions_models.dart';
import '../admissions_navigation.dart';
import '../widgets/admissions_module_scaffold.dart';
import 'admissions_enrollment_provider.dart';
import 'widgets/admissions_enrollment_form_steps.dart';
import 'widgets/admissions_enrollment_step_indicator.dart';

/// AD-05 — Student Enrollment multi-step wizard.
class AdmissionsEnrollmentScreen extends ConsumerWidget {
  const AdmissionsEnrollmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(admissionsEnrollmentLoadingProvider);
    final isError = ref.watch(admissionsEnrollmentErrorProvider);
    final form = ref.watch(admissionsEnrollmentProvider);
    final notifier = ref.read(admissionsEnrollmentProvider.notifier);

    return AdmissionsModuleScaffold(
      screen: AdmissionsScreen.enrollment,
      showFilterBar: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
              child: AksharaLoadingState(
                semanticLabel: 'Loading enrollment wizard',
              ),
            )
          else if (isError)
            const AksharaErrorState(
              message: 'Unable to load enrollment wizard.',
            )
          else ...[
            AdmissionsEnrollmentStepIndicator(currentStep: form.currentStep),
            const SizedBox(height: AksharaSpacing.s6),
            _buildStepContent(form, notifier),
            const SizedBox(height: AksharaSpacing.s6),
            _buildActions(context, form, notifier),
          ],
        ],
      ),
    );
  }

  Widget _buildStepContent(
    EnrollmentFormState form,
    EnrollmentFormNotifier notifier,
  ) {
    return switch (form.currentStep) {
      EnrollmentStep.studentProfile => AdmissionsEnrollmentStudentStep(
          student: form.student,
          onChanged: notifier.updateStudent,
        ),
      EnrollmentStep.parentInformation => AdmissionsEnrollmentParentStep(
          parent: form.parent,
          onChanged: notifier.updateParent,
        ),
      EnrollmentStep.academicInformation => AdmissionsEnrollmentAcademicStep(
          academic: form.academic,
          onChanged: notifier.updateAcademic,
        ),
      EnrollmentStep.reviewSubmit => AdmissionsEnrollmentReviewStep(form: form),
    };
  }

  Widget _buildActions(
    BuildContext context,
    EnrollmentFormState form,
    EnrollmentFormNotifier notifier,
  ) {
    final isFirst = form.currentStep == EnrollmentStep.studentProfile;
    final isLast = form.currentStep == EnrollmentStep.reviewSubmit;

    return Row(
      children: [
        if (!isFirst)
          OutlinedButton(
            onPressed: form.isSubmitting ? null : notifier.previousStep,
            child: const Text('Back'),
          ),
        const Spacer(),
        if (!isLast)
          FilledButton(
            onPressed: notifier.nextStep,
            child: const Text('Continue'),
          )
        else
          FilledButton(
            onPressed: form.isSubmitting || form.isSubmitted
                ? null
                : notifier.submit,
            child: form.isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(form.isSubmitted ? 'Submitted' : 'Submit enrollment'),
          ),
      ],
    );
  }
}
