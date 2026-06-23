import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/forms/akshara_form_field.dart';
import '../../shared/widgets/akshara_dialog.dart';
import '../../shared/widgets/akshara_motion.dart';
import 'alumni_mutations_provider.dart';
import 'alumni_requests.dart';

void _showAlumniMutationError(BuildContext context, Object error) {
  final failure = error is ApiFailureException
      ? error.failure
      : apiFailureMapper.fromException(error);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(failure.message)),
  );
}

Future<void> showAddAlumniDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final nameController = TextEditingController();
  final batchYearController = TextEditingController();
  final programController = TextEditingController();
  final roleController = TextEditingController();
  final cityController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Add alumni',
      icon: Icons.person_add_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            label: 'Name',
            controller: nameController,
            required: true,
          ),
          AksharaFormField(
            label: 'Batch year',
            controller: batchYearController,
            keyboardType: TextInputType.number,
            hint: 'e.g. 2014',
          ),
          AksharaFormField(
            label: 'Program',
            controller: programController,
            hint: 'e.g. Class 12 — Science',
          ),
          AksharaFormField(
            label: 'Current role',
            controller: roleController,
            hint: 'e.g. Software Engineer at Infosys',
          ),
          AksharaFormField(
            label: 'City',
            controller: cityController,
          ),
          AksharaFormField(
            label: 'Email',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          AksharaFormField(
            label: 'Phone',
            controller: phoneController,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
      actions: [
        AksharaDialogActions(
          confirmLabel: 'Add alumni',
          confirmKey: QaTestKeys.alumniAddDialogSubmitButton,
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
    final alumni = await ref.read(addAlumniProvider.notifier).execute(
          AddAlumniRequest(
            name: nameController.text.trim(),
            batchYear: batchYearController.text.trim(),
            program: programController.text.trim(),
            currentRole: roleController.text.trim(),
            city: cityController.text.trim(),
            email: emailController.text.trim(),
            phone: phoneController.text.trim(),
          ),
        );
    if (!context.mounted || alumni == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.alumniAddSuccessSnackbar,
        content: Text('Added ${alumni.name} to the alumni registry'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showAlumniMutationError(context, error);
  }
}
