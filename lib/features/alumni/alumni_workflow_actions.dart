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

Future<void> showCreateEventDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final titleController = TextEditingController();
  final dateController = TextEditingController();
  final venueController = TextEditingController();
  final capacityController = TextEditingController();
  final organizerController = TextEditingController();

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Create event',
      icon: Icons.event_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            label: 'Event title',
            controller: titleController,
            required: true,
          ),
          AksharaFormField(
            label: 'Date',
            controller: dateController,
            hint: 'e.g. 15 Aug 2026',
          ),
          AksharaFormField(
            label: 'Venue',
            controller: venueController,
            hint: 'e.g. Akshara Main Campus',
          ),
          AksharaFormField(
            label: 'Capacity',
            controller: capacityController,
            keyboardType: TextInputType.number,
            hint: 'e.g. 200',
          ),
          AksharaFormField(
            label: 'Organizer',
            controller: organizerController,
            hint: 'e.g. Alumni Association',
          ),
        ],
      ),
      actions: [
        AksharaDialogActions(
          confirmLabel: 'Create event',
          confirmKey: QaTestKeys.alumniCreateEventDialogSubmitButton,
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () {
            if (titleController.text.trim().isEmpty) return;
            Navigator.of(context).pop(true);
          },
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final event = await ref.read(createAlumniEventProvider.notifier).execute(
          CreateAlumniEventRequest(
            title: titleController.text.trim(),
            date: dateController.text.trim(),
            venue: venueController.text.trim(),
            capacity: capacityController.text.trim(),
            organizer: organizerController.text.trim(),
          ),
        );
    if (!context.mounted || event == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.alumniCreateEventSuccessSnackbar,
        content: Text('Scheduled ${event.title}'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showAlumniMutationError(context, error);
  }
}

Future<void> showCreateCampaignDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final nameController = TextEditingController();
  final goalController = TextEditingController();
  final deadlineController = TextEditingController();
  final accountController = TextEditingController();

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Create campaign',
      icon: Icons.campaign_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            label: 'Campaign name',
            controller: nameController,
            required: true,
          ),
          AksharaFormField(
            label: 'Goal amount',
            controller: goalController,
            hint: 'e.g. ₹10L',
          ),
          AksharaFormField(
            label: 'Deadline',
            controller: deadlineController,
            hint: 'e.g. 31 Dec 2026',
          ),
          AksharaFormField(
            label: 'Finance account code',
            controller: accountController,
            hint: 'e.g. FN-ALM-LIB-2026',
          ),
        ],
      ),
      actions: [
        AksharaDialogActions(
          confirmLabel: 'Create campaign',
          confirmKey: QaTestKeys.alumniCreateCampaignDialogSubmitButton,
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
    final campaign =
        await ref.read(createAlumniCampaignProvider.notifier).execute(
              CreateAlumniCampaignRequest(
                name: nameController.text.trim(),
                goalAmount: goalController.text.trim(),
                deadline: deadlineController.text.trim(),
                financeAccountCode: accountController.text.trim(),
              ),
            );
    if (!context.mounted || campaign == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.alumniCreateCampaignSuccessSnackbar,
        content: Text('Created campaign ${campaign.name}'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showAlumniMutationError(context, error);
  }
}

Future<void> showAddMentorshipDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final mentorNameController = TextEditingController();
  final mentorIdController = TextEditingController();
  final menteeNameController = TextEditingController();
  final menteeBatchController = TextEditingController();
  final focusController = TextEditingController();

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Match mentorship pair',
      icon: Icons.handshake_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            label: 'Mentor name',
            controller: mentorNameController,
            required: true,
          ),
          AksharaFormField(
            label: 'Mentor alumni ID',
            controller: mentorIdController,
            hint: 'e.g. ALM-001',
          ),
          AksharaFormField(
            label: 'Mentee name',
            controller: menteeNameController,
            required: true,
          ),
          AksharaFormField(
            label: 'Mentee batch',
            controller: menteeBatchController,
            hint: 'e.g. Class 11 (2026)',
          ),
          AksharaFormField(
            label: 'Focus area',
            controller: focusController,
            hint: 'e.g. Software engineering careers',
          ),
        ],
      ),
      actions: [
        AksharaDialogActions(
          confirmLabel: 'Match pair',
          confirmKey: QaTestKeys.alumniAddMentorshipDialogSubmitButton,
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () {
            if (mentorNameController.text.trim().isEmpty ||
                menteeNameController.text.trim().isEmpty) {
              return;
            }
            Navigator.of(context).pop(true);
          },
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final pair = await ref.read(addMentorshipPairProvider.notifier).execute(
          AddMentorshipPairRequest(
            mentorName: mentorNameController.text.trim(),
            mentorAlumniId: mentorIdController.text.trim(),
            menteeName: menteeNameController.text.trim(),
            menteeBatch: menteeBatchController.text.trim(),
            focusArea: focusController.text.trim(),
          ),
        );
    if (!context.mounted || pair == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.alumniAddMentorshipSuccessSnackbar,
        content: Text('Matched ${pair.mentorName} with ${pair.menteeName}'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showAlumniMutationError(context, error);
  }
}
