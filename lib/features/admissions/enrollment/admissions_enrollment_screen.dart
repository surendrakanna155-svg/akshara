import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/forms/forms.dart';
import '../../../shared/widgets/widgets.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';
import '../admissions_journey_context_provider.dart';
import '../admissions_navigation.dart';
import '../widgets/admissions_module_scaffold.dart';
import 'admissions_enrollment_provider.dart';
import 'enrollment_validation.dart';
import 'widgets/admissions_enrollment_form_steps.dart';

/// AD-05 — Student Enrollment multi-step wizard.
class AdmissionsEnrollmentScreen extends ConsumerStatefulWidget {
  const AdmissionsEnrollmentScreen({super.key});

  @override
  ConsumerState<AdmissionsEnrollmentScreen> createState() =>
      _AdmissionsEnrollmentScreenState();
}

class _AdmissionsEnrollmentScreenState
    extends ConsumerState<AdmissionsEnrollmentScreen> {
  final _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _continue(EnrollmentFormNotifier notifier) async {
    await scrollToFirstFormError(
      formKey: _formKey,
      scrollController: _scrollController,
    );
    if (!mounted) return;
    final advanced = notifier.nextStep();
    if (!advanced) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(admissionsEnrollmentViewStateProvider);
    final form = ref.watch(admissionsEnrollmentProvider);
    final notifier = ref.read(admissionsEnrollmentProvider.notifier);
    final hasDraft = enrollmentFormHasDraftChanges(form) && !form.isSubmitted;

    return AksharaUnsavedChangesGuard(
      hasUnsavedChanges: hasDraft,
      child: AdmissionsModuleScaffold(
        screen: AdmissionsScreen.enrollment,
        showFilterBar: false,
        scrollableBody: false,
        body: AdmissionsAsyncBody<EnrollmentFormState>(
          state: viewState,
          loadingLabel: 'Loading enrollment wizard',
          emptyMessage: 'Unable to initialize enrollment form.',
          emptyIcon: Icons.edit_note_outlined,
          onRetry: () => retryAdmissionsFuture(
            ref,
            admissionsEnrollmentPrefillFutureProvider,
          ),
          builder: (_) {
            final isFirst = form.currentStep == EnrollmentStep.studentProfile;
            return AksharaMultiStepForm(
              stepLabels: [
                for (final step in EnrollmentStep.values) step.label,
              ],
              currentIndex:
                  EnrollmentStep.values.indexOf(form.currentStep),
              formKey: _formKey,
              scrollController: _scrollController,
              autovalidateMode: form.stepFieldErrors != null
                  ? AutovalidateMode.always
                  : AutovalidateMode.disabled,
              leading: isFirst
                  ? null
                  : OutlinedButton(
                      onPressed:
                          form.isSubmitting ? null : notifier.previousStep,
                      child: const Text('Back'),
                    ),
              trailing: _buildPrimaryAction(context, ref, form, notifier),
              child: _buildStepContent(form, notifier),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStepContent(
    EnrollmentFormState form,
    EnrollmentFormNotifier notifier,
  ) {
    final errors = form.stepFieldErrors ?? const {};
    return switch (form.currentStep) {
      EnrollmentStep.studentProfile => AdmissionsEnrollmentStudentStep(
          student: form.student,
          fieldErrors: errors,
          onChanged: notifier.updateStudent,
        ),
      EnrollmentStep.parentInformation => AdmissionsEnrollmentParentStep(
          parent: form.parent,
          fieldErrors: errors,
          onChanged: notifier.updateParent,
        ),
      EnrollmentStep.academicInformation => AdmissionsEnrollmentAcademicStep(
          academic: form.academic,
          fieldErrors: errors,
          onChanged: notifier.updateAcademic,
        ),
      EnrollmentStep.reviewSubmit => AdmissionsEnrollmentReviewStep(form: form),
    };
  }

  Widget _buildPrimaryAction(
    BuildContext context,
    WidgetRef ref,
    EnrollmentFormState form,
    EnrollmentFormNotifier notifier,
  ) {
    final isLast = form.currentStep == EnrollmentStep.reviewSubmit;

    if (!isLast) {
      return FilledButton(
        key: QaTestKeys.enrollmentContinueButton,
        onPressed: form.isSubmitting ? null : () => _continue(notifier),
        child: const Text('Continue'),
      );
    }

    return AksharaManageAction(
      permission: Permission.manageAdmissions,
      child: FilledButton(
        key: QaTestKeys.enrollmentSubmitButton,
        onPressed: form.isSubmitting || form.isSubmitted
            ? null
            : () => _submitEnrollment(context, ref, notifier),
        child: form.isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(form.isSubmitted ? 'Submitted' : 'Submit enrollment'),
      ),
    );
  }

  Future<void> _submitEnrollment(
    BuildContext context,
    WidgetRef ref,
    EnrollmentFormNotifier notifier,
  ) async {
    try {
      await notifier.submit();
      if (!context.mounted) return;
      final enrollmentId = ref.read(admissionsLastEnrollmentIdProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.admissionsEnrollmentSubmittedSnackbar,
          content: Text(
            enrollmentId == null
                ? 'Enrollment submitted successfully'
                : 'Enrollment submitted ($enrollmentId)',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}
