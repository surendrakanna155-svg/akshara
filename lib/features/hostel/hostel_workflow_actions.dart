import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/forms/akshara_form_field.dart';
import '../../shared/widgets/akshara_dialog.dart';
import '../../shared/widgets/akshara_motion.dart';
import 'hostel_models.dart';
import 'hostel_mutations_provider.dart';
import 'hostel_providers.dart';
import 'hostel_requests.dart';

void _showHostelMutationError(BuildContext context, Object error) {
  final failure = error is ApiFailureException
      ? error.failure
      : apiFailureMapper.fromException(error);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(failure.message)),
  );
}

String _hostelRoomTypeLabel(HostelRoomType type) => switch (type) {
      HostelRoomType.standard => 'Standard',
      HostelRoomType.ac => 'AC',
      HostelRoomType.dormitory => 'Dormitory',
      HostelRoomType.staff => 'Staff',
    };

String _hostelAttendanceStatusLabel(HostelAttendanceStatus status) =>
    switch (status) {
      HostelAttendanceStatus.present => 'Present',
      HostelAttendanceStatus.absent => 'Absent',
      HostelAttendanceStatus.onLeave => 'On leave',
    };

String _hostelMealTypeLabel(HostelMealType type) => switch (type) {
      HostelMealType.breakfast => 'Breakfast',
      HostelMealType.lunch => 'Lunch',
      HostelMealType.snacks => 'Snacks',
      HostelMealType.dinner => 'Dinner',
    };

Future<void> showAdmitHostelStudentDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final sisIdController = TextEditingController();
  final nameController = TextEditingController();
  final admissionController = TextEditingController();
  final classController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Hostel admission'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: sisIdController,
            decoration: const InputDecoration(
              labelText: 'SIS student ID',
              hintText: 'e.g. SIS-STU-10425',
            ),
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
  final studentIdController = TextEditingController(text: student?.id ?? '');
  final roomIdController = TextEditingController();
  final bedController = TextEditingController();

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

Future<void> showCreateHostelRoomDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final blockController = TextEditingController(text: 'A');
  final roomNumberController = TextEditingController();
  final floorController = TextEditingController(text: '1');
  final bedsController = TextEditingController(text: '2');
  final facilitiesController = TextEditingController();
  var type = HostelRoomType.standard;

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Add room',
      icon: Icons.meeting_room_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            label: 'Block',
            controller: blockController,
            required: true,
            hint: 'e.g. A',
          ),
          AksharaFormField(
            label: 'Room number',
            controller: roomNumberController,
            required: true,
            hint: 'e.g. 204',
          ),
          AksharaFormField(
            label: 'Floor',
            controller: floorController,
            keyboardType: TextInputType.number,
          ),
          DropdownMenu<HostelRoomType>(
            initialSelection: type,
            label: const Text('Type'),
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: [
              for (final option in HostelRoomType.values)
                DropdownMenuEntry(
                  value: option,
                  label: _hostelRoomTypeLabel(option),
                ),
            ],
            onSelected: (value) {
              if (value != null) type = value;
            },
          ),
          AksharaFormField(
            label: 'Total beds',
            controller: bedsController,
            keyboardType: TextInputType.number,
            required: true,
          ),
          AksharaFormField(
            label: 'Facilities',
            controller: facilitiesController,
            hint: 'e.g. Study desk, attached bath',
          ),
        ],
      ),
      actions: [
        AksharaDialogActions(
          confirmLabel: 'Create',
          confirmKey: QaTestKeys.hostelCreateRoomDialogSubmitButton,
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () {
            if (blockController.text.trim().isEmpty ||
                roomNumberController.text.trim().isEmpty) {
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
    final room = await ref.read(createHostelRoomProvider.notifier).execute(
          CreateHostelRoomRequest(
            block: blockController.text.trim(),
            roomNumber: roomNumberController.text.trim(),
            floor: int.tryParse(floorController.text.trim()) ?? 1,
            type: type,
            totalBeds: int.tryParse(bedsController.text.trim()) ?? 1,
            facilities: facilitiesController.text.trim(),
          ),
        );
    if (!context.mounted || room == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hostelCreateRoomSuccessSnackbar,
        content: Text('Room ${room.block} ${room.roomNumber} added'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showHostelMutationError(context, error);
  }
}

Future<void> showLogVisitorDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final visitorNameController = TextEditingController();
  final relationController = TextEditingController();
  final studentNameController = TextEditingController();
  final sisIdController = TextEditingController();

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Log visitor',
      icon: Icons.person_add_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            label: 'Visitor name',
            controller: visitorNameController,
            required: true,
          ),
          AksharaFormField(
            label: 'Relation',
            controller: relationController,
            hint: 'e.g. Father',
          ),
          AksharaFormField(
            label: 'Student name',
            controller: studentNameController,
            required: true,
            hint: 'Resident being visited',
          ),
          AksharaFormField(
            label: 'SIS student ID',
            controller: sisIdController,
            hint: 'e.g. SIS-STU-10430',
          ),
        ],
      ),
      actions: [
        AksharaDialogActions(
          confirmLabel: 'Register visitor',
          confirmKey: QaTestKeys.hostelLogVisitorDialogSubmitButton,
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () {
            if (visitorNameController.text.trim().isEmpty ||
                studentNameController.text.trim().isEmpty) {
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
    final visitor = await ref.read(logVisitorProvider.notifier).execute(
          LogVisitorRequest(
            visitorName: visitorNameController.text.trim(),
            relation: relationController.text.trim(),
            studentName: studentNameController.text.trim(),
            sisStudentId: sisIdController.text.trim(),
          ),
        );
    if (!context.mounted || visitor == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hostelLogVisitorSuccessSnackbar,
        content: Text('Issued ${visitor.passId} to ${visitor.visitorName}'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showHostelMutationError(context, error);
  }
}

/// HOSTE-1 — records a hostel attendance roster row. The resident picker is
/// driven from the live hostel students list (no hardcoded mock IDs); room and
/// roll auto-fill from the chosen resident.
Future<void> showRecordHostelAttendanceDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final students = ref.read(hostelStudentsProvider) ?? const <HostelStudent>[];
  final residents = students
      .where((s) => s.status != HostelStudentStatus.checkedOut)
      .toList();

  HostelStudent? selected = residents.isNotEmpty ? residents.first : null;
  final roomController = TextEditingController(text: selected?.room ?? '');
  final rollController = TextEditingController();
  final remarkController = TextEditingController();
  var morning = HostelAttendanceStatus.present;
  var evening = HostelAttendanceStatus.present;
  var night = HostelAttendanceStatus.present;

  Widget statusDropdown(
    String label,
    HostelAttendanceStatus value,
    ValueChanged<HostelAttendanceStatus> onChanged,
  ) {
    return DropdownMenu<HostelAttendanceStatus>(
      initialSelection: value,
      label: Text(label),
      expandedInsets: EdgeInsets.zero,
      dropdownMenuEntries: [
        for (final option in HostelAttendanceStatus.values)
          DropdownMenuEntry(
            value: option,
            label: _hostelAttendanceStatusLabel(option),
          ),
      ],
      onSelected: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AksharaAlertDialog(
        title: 'Record attendance',
        icon: Icons.fact_check_outlined,
        scrollable: true,
        content: AksharaDialogFormBody(
          children: [
            if (residents.isEmpty)
              const Text('No hostel residents available to record.')
            else
              DropdownMenu<HostelStudent>(
                initialSelection: selected,
                label: const Text('Resident'),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: [
                  for (final resident in residents)
                    DropdownMenuEntry(
                      value: resident,
                      label: '${resident.studentName} · ${resident.room}',
                    ),
                ],
                onSelected: (next) {
                  setState(() {
                    selected = next;
                    roomController.text = next?.room ?? '';
                  });
                },
              ),
            AksharaFormField(
              label: 'Room',
              controller: roomController,
              hint: 'e.g. A-204',
            ),
            AksharaFormField(
              label: 'Roll number',
              controller: rollController,
              hint: 'e.g. 10-A-12',
            ),
            statusDropdown('Morning', morning, (v) => morning = v),
            statusDropdown('Evening', evening, (v) => evening = v),
            statusDropdown('Night', night, (v) => night = v),
            AksharaFormField(
              label: 'Remark',
              controller: remarkController,
              hint: 'Optional note',
            ),
          ],
        ),
        actions: [
          AksharaDialogActions(
            confirmLabel: 'Record',
            confirmKey: QaTestKeys.hostelRecordAttendanceDialogSubmitButton,
            onCancel: () => Navigator.of(context).pop(false),
            onConfirm: () {
              if (selected == null) return;
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;
  final resident = selected;
  if (resident == null) return;

  try {
    final record =
        await ref.read(recordHostelAttendanceProvider.notifier).execute(
              RecordHostelAttendanceRequest(
                studentName: resident.studentName,
                room: roomController.text.trim(),
                rollNumber: rollController.text.trim(),
                morning: morning,
                evening: evening,
                night: night,
                remark: remarkController.text.trim(),
                sisStudentId: resident.sisStudentId,
              ),
            );
    if (!context.mounted || record == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hostelRecordAttendanceSuccessSnackbar,
        content: Text(
          'Recorded ${record.studentName} — '
          '${_hostelAttendanceStatusLabel(record.overallStatus)}',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showHostelMutationError(context, error);
  }
}

/// HOSTE-3 — records a mess menu entry with headcount and cost.
Future<void> showRecordMessDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final dayController = TextEditingController();
  final itemsController = TextEditingController();
  final dietaryController = TextEditingController();
  final headcountController = TextEditingController();
  final costController = TextEditingController();
  var mealType = HostelMealType.lunch;

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Record mess menu',
      icon: Icons.restaurant_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            label: 'Day',
            controller: dayController,
            required: true,
            hint: 'e.g. Mon',
          ),
          DropdownMenu<HostelMealType>(
            initialSelection: mealType,
            label: const Text('Meal'),
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: [
              for (final option in HostelMealType.values)
                DropdownMenuEntry(
                  value: option,
                  label: _hostelMealTypeLabel(option),
                ),
            ],
            onSelected: (value) {
              if (value != null) mealType = value;
            },
          ),
          AksharaFormField(
            label: 'Menu items',
            controller: itemsController,
            required: true,
            hint: 'e.g. Rice · Dal · Sabzi',
          ),
          AksharaFormField(
            label: 'Dietary tags',
            controller: dietaryController,
            hint: 'Comma separated, e.g. Veg, Jain option',
          ),
          AksharaFormField(
            label: 'Headcount',
            controller: headcountController,
            keyboardType: TextInputType.number,
          ),
          AksharaFormField(
            label: 'Cost (₹)',
            controller: costController,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        AksharaDialogActions(
          confirmLabel: 'Record',
          confirmKey: QaTestKeys.hostelRecordMessDialogSubmitButton,
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () {
            if (dayController.text.trim().isEmpty ||
                itemsController.text.trim().isEmpty) {
              return;
            }
            Navigator.of(context).pop(true);
          },
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final dietaryTags = dietaryController.text
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toList();

  try {
    final menu = await ref.read(recordMessProvider.notifier).execute(
          RecordMessRequest(
            day: dayController.text.trim(),
            mealType: mealType,
            items: itemsController.text.trim(),
            dietaryTags: dietaryTags,
            headcount: int.tryParse(headcountController.text.trim()) ?? 0,
            costRupees: int.tryParse(costController.text.trim()) ?? 0,
          ),
        );
    if (!context.mounted || menu == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hostelRecordMessSuccessSnackbar,
        content: Text(
          'Recorded ${menu.day} ${_hostelMealTypeLabel(menu.mealType)} menu',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showHostelMutationError(context, error);
  }
}
