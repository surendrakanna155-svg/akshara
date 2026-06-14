import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import 'hostel_models.dart';
import 'hostel_mutations_provider.dart';
import 'hostel_requests.dart';

Future<void> showAdmitHostelStudentDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final sisIdController = TextEditingController(text: 'SIS-STU-10425');
  final nameController = TextEditingController(text: 'Karthik Sharma');
  final admissionController = TextEditingController(text: 'ADM-2026-0145');
  final classController = TextEditingController(text: '8');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Hostel admission'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: sisIdController,
            decoration: const InputDecoration(labelText: 'SIS student ID'),
          ),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Student name'),
          ),
          TextField(
            controller: admissionController,
            decoration: const InputDecoration(labelText: 'Admission number'),
          ),
          TextField(
            controller: classController,
            decoration: const InputDecoration(labelText: 'Class'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.hostelAdmitDialogSubmitButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Admit'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final student =
        await ref.read(admitHostelStudentProvider.notifier).execute(
              AdmitHostelStudentRequest(
                sisStudentId: sisIdController.text.trim(),
                studentName: nameController.text.trim(),
                admissionNumber: admissionController.text.trim(),
                classLabel: classController.text.trim(),
              ),
            );
    if (!context.mounted || student == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hostelAdmitSuccessSnackbar,
        content: Text('Admitted ${student.studentName} — assign a room next'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to admit student: $error')),
    );
  }
}

Future<void> showAssignHostelRoomDialog(
  BuildContext context,
  WidgetRef ref, {
  HostelStudent? student,
}) async {
  final studentIdController = TextEditingController(
    text: student?.id ?? 'ho_stu_5',
  );
  final roomIdController = TextEditingController(text: 'room_4');
  final bedController = TextEditingController(text: 'B1');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Assign room'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: studentIdController,
            decoration: const InputDecoration(labelText: 'Hostel student ID'),
          ),
          TextField(
            controller: roomIdController,
            decoration: const InputDecoration(labelText: 'Room ID'),
          ),
          TextField(
            controller: bedController,
            decoration: const InputDecoration(labelText: 'Bed'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.hostelAssignDialogSubmitButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Assign'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final assigned =
        await ref.read(assignHostelRoomProvider.notifier).execute(
              AssignHostelRoomRequest(
                hostelStudentId: studentIdController.text.trim(),
                roomId: roomIdController.text.trim(),
                bed: bedController.text.trim(),
              ),
            );
    if (!context.mounted || assigned == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hostelAssignSuccessSnackbar,
        content: Text(
          'Assigned ${assigned.studentName} to ${assigned.block} ${assigned.room} ${assigned.bed}',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to assign room: $error')),
    );
  }
}

Future<void> checkoutHostelStudent(
  BuildContext context,
  WidgetRef ref,
  HostelStudent student,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Check out student'),
      content: Text(
        'Check out ${student.studentName} from ${student.room}? '
        'The bed will be marked vacant.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.hostelCheckoutDialogSubmitButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Check out'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final checkedOut =
        await ref.read(checkoutHostelStudentProvider.notifier).execute(
              CheckoutHostelStudentRequest(hostelStudentId: student.id),
            );
    if (!context.mounted || checkedOut == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hostelCheckoutSuccessSnackbar,
        content: Text('Checked out ${checkedOut.studentName}'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to check out student: $error')),
    );
  }
}

Future<void> transferHostelStudentRoom(
  BuildContext context,
  WidgetRef ref,
  HostelStudent student,
) =>
    showAssignHostelRoomDialog(context, ref, student: student);
