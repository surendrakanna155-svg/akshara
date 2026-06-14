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
