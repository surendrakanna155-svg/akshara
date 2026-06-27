import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import 'transport_models.dart';
import 'transport_mutations_provider.dart';
import 'transport_requests.dart';
import '../../core/errors/error_text.dart';

Future<void> showCreateTransportRouteDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final nameController = TextEditingController(text: 'Route QA — East Loop');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('New transport route'),
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(labelText: 'Route name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.transportSaveRouteDialogButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Save draft'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final route = await ref.read(createTransportRouteProvider.notifier).execute(
          CreateTransportRouteRequest(name: nameController.text.trim()),
        );
    if (!context.mounted || route == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.transportRouteSuccessSnackbar,
        content: Text('Route ${route.name} saved as draft'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
  }
}

Future<void> showActivateTransportRouteDialog(
  BuildContext context,
  WidgetRef ref, {
  required TransportRoute route,
}) async {
  if (route.status != TransportRouteStatus.draft) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Activate route'),
      content: Text('Activate "${route.name}" for student allocation?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.transportActivateRouteDialogButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Activate'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final activated = await ref
        .read(activateTransportRouteProvider.notifier)
        .execute(ActivateTransportRouteRequest(routeId: route.id));
    if (!context.mounted || activated == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.transportRouteActivatedSnackbar,
        content: Text('Route ${activated.name} is now active'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
  }
}

Future<void> showRecordTransportAttendanceDialog(
  BuildContext context,
  WidgetRef ref, {
  required TransportAttendanceRecord record,
}) async {
  var selected = record.status == TransportAttendanceStatus.notScheduled
      ? TransportAttendanceStatus.waiting
      : record.status;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Mark ${record.studentName}'),
        content: Wrap(
          spacing: 8,
          children: [
            for (final status in const [
              TransportAttendanceStatus.picked,
              TransportAttendanceStatus.waiting,
              TransportAttendanceStatus.absent,
            ])
              ChoiceChip(
                label: Text(_attendanceStatusLabel(status)),
                selected: selected == status,
                onSelected: (_) => setState(() => selected = status),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.transportMarkAttendanceDialogSubmitButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final updated =
        await ref.read(recordTransportAttendanceProvider.notifier).execute(
              RecordTransportAttendanceRequest(
                id: record.id,
                studentName: record.studentName,
                stopName: record.stopName,
                routeName: record.routeName,
                scheduledTime: record.scheduledTime,
                actualTime: record.actualTime,
                status: selected,
                parentNotified: record.parentNotified,
                shift: record.shift,
              ),
            );
    if (!context.mounted || updated == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.transportAttendanceRecordedSnackbar,
        content: Text(
          '${updated.studentName} marked ${_attendanceStatusLabel(updated.status)}',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
  }
}

String _attendanceStatusLabel(TransportAttendanceStatus status) {
  return switch (status) {
    TransportAttendanceStatus.picked => 'Picked',
    TransportAttendanceStatus.waiting => 'Waiting',
    TransportAttendanceStatus.absent => 'Absent',
    TransportAttendanceStatus.notScheduled => 'Not scheduled',
  };
}

Future<void> showNotifyRouteDelayDialog(
  BuildContext context,
  WidgetRef ref, {
  required List<TransportRoute> routes,
}) async {
  final selectableRoutes =
      routes.where((r) => r.status == TransportRouteStatus.active).toList();
  if (selectableRoutes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No active routes to notify.')),
    );
    return;
  }

  var selectedRouteId = selectableRoutes.first.id;
  final messageController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Notify parents of delay'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedRouteId,
              decoration: const InputDecoration(labelText: 'Route'),
              items: [
                for (final route in selectableRoutes)
                  DropdownMenuItem<String>(
                    value: route.id,
                    child: Text(route.name),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => selectedRouteId = value ?? selectedRouteId),
            ),
            TextField(
              controller: messageController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Delay message',
                hintText: 'e.g. Bus running 15 min late due to traffic',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.transportNotifyDelayDialogSubmitButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Notify'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final message = messageController.text.trim();
  if (message.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enter a delay message before notifying.')),
    );
    return;
  }

  try {
    final result = await ref.read(notifyRouteDelayProvider.notifier).execute(
          NotifyRouteDelayRequest(
            routeId: selectedRouteId,
            message: message,
          ),
        );
    if (!context.mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.transportNotifyDelaySuccessSnackbar,
        content: Text(
          'Notified ${result.recipientCount} parent(s) on ${result.routeName}',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
  }
}

Future<void> showAssignStudentTransportDialog(
  BuildContext context,
  WidgetRef ref, {
  required StudentTransportAllocation allocation,
  required List<TransportRoute> routes,
}) async {
  final selectableRoutes =
      routes.where((r) => r.status == TransportRouteStatus.active).toList();
  if (selectableRoutes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No active routes available to assign.')),
    );
    return;
  }

  var selectedRouteId = selectableRoutes.first.id;
  final pickupController = TextEditingController();
  final dropController = TextEditingController(text: 'Akshara Main Gate');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Assign ${allocation.studentName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'SIS ID ${allocation.sisStudentId} · ${allocation.admissionNumber}',
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedRouteId,
              decoration: const InputDecoration(labelText: 'Route'),
              items: [
                for (final route in selectableRoutes)
                  DropdownMenuItem<String>(
                    value: route.id,
                    child: Text(route.name),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => selectedRouteId = value ?? selectedRouteId),
            ),
            TextField(
              controller: pickupController,
              decoration: const InputDecoration(labelText: 'Pickup stop'),
            ),
            TextField(
              controller: dropController,
              decoration: const InputDecoration(labelText: 'Drop stop'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.transportAssignDialogSubmitButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Assign'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final pickup = pickupController.text.trim();
  final drop = dropController.text.trim();
  if (pickup.isEmpty || drop.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pickup and drop stops are required.')),
    );
    return;
  }

  try {
    final updated =
        await ref.read(assignStudentTransportProvider.notifier).execute(
              AssignStudentTransportRequest(
                allocationId: allocation.id,
                routeId: selectedRouteId,
                pickupStop: pickup,
                dropStop: drop,
                studentName: allocation.studentName,
                admissionNumber: allocation.admissionNumber,
                sisStudentId: allocation.sisStudentId,
                classLabel: allocation.classLabel,
              ),
            );
    if (!context.mounted || updated == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.transportAssignSuccessSnackbar,
        content: Text('${updated.studentName} assigned to ${updated.routeName}'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
  }
}

Future<void> showTransferStudentTransportDialog(
  BuildContext context,
  WidgetRef ref, {
  required StudentTransportAllocation allocation,
  required List<TransportRoute> routes,
}) async {
  final selectableRoutes = routes
      .where((r) =>
          r.status == TransportRouteStatus.active && r.id != allocation.routeId)
      .toList();
  if (selectableRoutes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No other active route to transfer to.')),
    );
    return;
  }

  var selectedRouteId = selectableRoutes.first.id;
  final pickupController = TextEditingController(text: allocation.pickupStop);
  final dropController = TextEditingController(text: allocation.dropStop);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Transfer ${allocation.studentName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedRouteId,
              decoration: const InputDecoration(labelText: 'Target route'),
              items: [
                for (final route in selectableRoutes)
                  DropdownMenuItem<String>(
                    value: route.id,
                    child: Text(route.name),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => selectedRouteId = value ?? selectedRouteId),
            ),
            TextField(
              controller: pickupController,
              decoration: const InputDecoration(labelText: 'Pickup stop'),
            ),
            TextField(
              controller: dropController,
              decoration: const InputDecoration(labelText: 'Drop stop'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.transportTransferDialogSubmitButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final pickup = pickupController.text.trim();
  final drop = dropController.text.trim();
  if (pickup.isEmpty || drop.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pickup and drop stops are required.')),
    );
    return;
  }

  try {
    final updated =
        await ref.read(transferStudentTransportProvider.notifier).execute(
              TransferStudentTransportRequest(
                allocationId: allocation.id,
                targetRouteId: selectedRouteId,
                pickupStop: pickup,
                dropStop: drop,
              ),
            );
    if (!context.mounted || updated == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.transportTransferSuccessSnackbar,
        content: Text('${updated.studentName} transferred to ${updated.routeName}'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
  }
}

Future<void> removeStudentFromRoute(
  BuildContext context,
  WidgetRef ref,
  StudentTransportAllocation allocation,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove from route'),
      content: Text(
        'Remove ${allocation.studentName} from ${allocation.routeName}?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.transportRemoveDialogSubmitButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final updated =
        await ref.read(removeStudentTransportProvider.notifier).execute(
              RemoveStudentTransportRequest(allocationId: allocation.id),
            );
    if (!context.mounted || updated == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.transportRemoveSuccessSnackbar,
        content: Text('${updated.studentName} removed from route'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
  }
}
