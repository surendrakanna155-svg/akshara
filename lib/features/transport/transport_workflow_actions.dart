import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import 'transport_models.dart';
import 'transport_mutations_provider.dart';
import 'transport_requests.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
  }
}

Future<void> showAssignStudentTransportDialog(
  BuildContext context,
  WidgetRef ref, {
  required StudentTransportAllocation allocation,
}) async {
  final routeController = TextEditingController(text: 'route_12');
  final pickupController = TextEditingController(text: 'Lake View Colony');
  final dropController = TextEditingController(text: 'Akshara Main Gate');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Assign ${allocation.studentName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: routeController,
            decoration: const InputDecoration(labelText: 'Route ID'),
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
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final updated =
        await ref.read(assignStudentTransportProvider.notifier).execute(
              AssignStudentTransportRequest(
                allocationId: allocation.id,
                routeId: routeController.text.trim(),
                pickupStop: pickupController.text.trim(),
                dropStop: dropController.text.trim(),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
  }
}

Future<void> showTransferStudentTransportDialog(
  BuildContext context,
  WidgetRef ref, {
  required StudentTransportAllocation allocation,
}) async {
  final routeController = TextEditingController(text: 'route_08');
  final pickupController = TextEditingController(text: 'Hitech City');
  final dropController = TextEditingController(text: 'Akshara Main Gate');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Transfer ${allocation.studentName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: routeController,
            decoration: const InputDecoration(labelText: 'Target route ID'),
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
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final updated =
        await ref.read(transferStudentTransportProvider.notifier).execute(
              TransferStudentTransportRequest(
                allocationId: allocation.id,
                targetRouteId: routeController.text.trim(),
                pickupStop: pickupController.text.trim(),
                dropStop: dropController.text.trim(),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
  }
}
