import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/permissions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../admissions_async_state.dart';
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
    final viewState = ref.watch(admissionsEnrollmentViewStateProvider);
    final form = ref.watch(admissionsEnrollmentProvider);
    final notifier = ref.read(admissionsEnrollmentProvider.notifier);

    return AdmissionsModuleScaffold(
      screen: AdmissionsScreen.enrollment,
      showFilterBar: false,
      body: AdmissionsAsyncBody<EnrollmentFormState>(
        state: viewState,
        loadingLabel: 'Loading enrollment wizard',
        emptyMessage: 'Unable to initialize enrollment form.',
        emptyIcon: Icons.edit_note_outlined,
        onRetry: () => retryAdmissionsFuture(
          ref,
          admissionsEnrollmentPrefillFutureProvider,
        ),
        builder: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdmissionsEnrollmentStepIndicator(currentStep: form.currentStep),
            const SizedBox(height: AksharaSpacing.s6),
            _buildStepContent(form, notifier),
            const SizedBox(height: AksharaSpacing.s6),
            _buildActions(context, ref, form, notifier),
          ],
        ),
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
    WidgetRef ref,
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
          AksharaManageAction(
            permission: Permission.manageAdmissions,
            child: FilledButton(
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
          ),
      ],
    );
  }
}
