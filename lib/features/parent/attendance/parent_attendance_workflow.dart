import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/forms/akshara_form_field.dart';
import '../../../shared/widgets/akshara_dialog.dart';
import '../../../shared/widgets/akshara_motion.dart';
import '../parent_mutations_provider.dart';
import '../parent_requests.dart';
import 'attendance_models.dart';

Future<void> showParentAttendanceCorrectionDialog(
  BuildContext context,
  WidgetRef ref, {
  ScaffoldMessengerState? scaffoldMessenger,
  required AttendanceDayLog log,
  required String childName,
  required String childClass,
}) async {
  if (log.status != AttendanceDayStatus.absent) return;

  final reasonController = TextEditingController(
    text: 'Student was present — request attendance correction',
  );
  final toMark = 'Present';

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Request attendance correction',
      icon: Icons.edit_calendar_outlined,
      content: AksharaDialogFormBody(
        children: [
          Text('${log.detailTitle} · Recorded absent'),
          const SizedBox(height: 12),
          AksharaFormField(
            label: 'Reason',
            controller: reasonController,
            required: true,
          ),
        ],
      ),
      actions: [
        AksharaDialogActions(
          cancelLabel: 'Cancel',
          confirmLabel: 'Submit for approval',
          confirmKey: QaTestKeys.parentAttendanceCorrectionSubmitButton,
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final messenger = scaffoldMessenger ?? ScaffoldMessenger.of(context);

  try {
    final result = await ref
        .read(submitParentAttendanceCorrectionProvider.notifier)
        .execute(
          ParentAttendanceCorrectionRequest(
            childName: childName,
            classLabel: childClass,
            dateLabel: log.detailTitle,
            fromMark: 'Absent',
            toMark: toMark,
            reason: reasonController.text.trim(),
          ),
        );
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        key: QaTestKeys.parentAttendanceCorrectionSuccessSnackbar,
        content: Text(
          result == null
              ? 'Correction could not be submitted'
              : 'Correction submitted for principal approval (${result.approvalId})',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        key: QaTestKeys.parentAttendanceCorrectionSuccessSnackbar,
        content: Text('$error'),
      ),
    );
  }
}
