import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/forms/akshara_form_field.dart';
import '../../../shared/widgets/akshara_dialog.dart';
import '../../../shared/widgets/akshara_motion.dart';
import 'control_center_mutations_provider.dart';
import 'control_center_requests.dart';

void _showControlCenterMutationError(BuildContext context, Object error) {
  final failure = error is ApiFailureException
      ? error.failure
      : apiFailureMapper.fromException(error);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(failure.message)),
  );
}

Future<void> showCreateSchoolDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final nameController = TextEditingController();
  final planController = TextEditingController();
  final regionController = TextEditingController();
  final studentCountController = TextEditingController();

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Onboard school',
      icon: Icons.apartment_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            label: 'School name',
            controller: nameController,
            required: true,
          ),
          AksharaFormField(
            label: 'Plan',
            controller: planController,
            hint: 'Standard, Premium or Enterprise',
          ),
          AksharaFormField(
            label: 'Region',
            controller: regionController,
            hint: 'e.g. South',
          ),
          AksharaFormField(
            label: 'Student count',
            controller: studentCountController,
            keyboardType: TextInputType.number,
            hint: 'e.g. 1200',
          ),
        ],
      ),
      actions: [
        AksharaDialogActions(
          confirmLabel: 'Onboard school',
          confirmKey: QaTestKeys.controlCenterCreateSchoolDialogSubmitButton,
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () {
            if (nameController.text.trim().isEmpty) return;
            Navigator.of(context).pop(true);
          },
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final school = await ref.read(createSchoolProvider.notifier).execute(
          CreateSchoolRequest(
            name: nameController.text.trim(),
            plan: planController.text.trim(),
            region: regionController.text.trim(),
            studentCount: studentCountController.text.trim(),
          ),
        );
    if (!context.mounted || school == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.controlCenterCreateSchoolSuccessSnackbar,
        content: Text('Onboarded ${school.name} (trial)'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showControlCenterMutationError(context, error);
  }
}

Future<void> showCreateLeadDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final schoolNameController = TextEditingController();
  final contactNameController = TextEditingController();
  final ownerController = TextEditingController();
  final estimatedMrrController = TextEditingController();

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Add lead',
      icon: Icons.person_add_alt_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            label: 'School name',
            controller: schoolNameController,
            required: true,
          ),
          AksharaFormField(
            label: 'Contact name',
            controller: contactNameController,
            hint: 'e.g. Rajesh Mehta',
          ),
          AksharaFormField(
            label: 'Sales owner',
            controller: ownerController,
            hint: 'e.g. Anita Sales',
          ),
          AksharaFormField(
            label: 'Estimated MRR (₹L)',
            controller: estimatedMrrController,
            keyboardType: TextInputType.number,
            hint: 'e.g. 3.5',
          ),
        ],
      ),
      actions: [
        AksharaDialogActions(
          confirmLabel: 'Add lead',
          confirmKey: QaTestKeys.controlCenterCreateLeadDialogSubmitButton,
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () {
            if (schoolNameController.text.trim().isEmpty) return;
            Navigator.of(context).pop(true);
          },
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final deal = await ref.read(createCrmLeadProvider.notifier).execute(
          CreateCrmLeadRequest(
            schoolName: schoolNameController.text.trim(),
            contactName: contactNameController.text.trim(),
            owner: ownerController.text.trim(),
            estimatedMrr: estimatedMrrController.text.trim(),
          ),
        );
    if (!context.mounted || deal == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.controlCenterCreateLeadSuccessSnackbar,
        content: Text('Added ${deal.schoolName} to the pipeline'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showControlCenterMutationError(context, error);
  }
}
