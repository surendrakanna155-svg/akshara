import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/api_failure.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../finance/fee_structures/finance_fee_structures_provider.dart';
import '../finance/finance_models.dart';
import 'transport_models.dart';
import 'transport_mutations_provider.dart';
import 'transport_providers.dart';
import 'transport_requests.dart';
import '../../core/errors/error_text.dart';

Future<void> showCreateTransportRouteDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final nameController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('New transport route'),
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(
          labelText: 'Route name',
          hintText: 'e.g. Route 12 — East Loop',
        ),
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

  await _assignWithCapacityGuard(
    context,
    ref,
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
}

/// TRN-7 — runs the assign mutation; if the backend returns 409
/// CAPACITY_EXCEEDED, shows a confirm dialog and retries with
/// `allowOverCapacity: true`.
Future<void> _assignWithCapacityGuard(
  BuildContext context,
  WidgetRef ref,
  AssignStudentTransportRequest request,
) async {
  final updated =
      await ref.read(assignStudentTransportProvider.notifier).execute(request);
  if (!context.mounted) return;

  final state = ref.read(assignStudentTransportProvider);
  if (state.hasError) {
    final error = state.error;
    if (!request.allowOverCapacity &&
        error is ApiFailureException &&
        error.failure.code == 'CAPACITY_EXCEEDED') {
      final override = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Route over capacity'),
          content: const Text(
            'This route is over its vehicle capacity. Assign anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: QaTestKeys.transportCapacityOverrideConfirmButton,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Assign anyway'),
            ),
          ],
        ),
      );
      if (override == true && context.mounted) {
        await _assignWithCapacityGuard(
          context,
          ref,
          request.copyWith(allowOverCapacity: true),
        );
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(aksharaErrorMessage(error ?? 'Assign failed.'))),
    );
    return;
  }

  if (updated == null) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      key: QaTestKeys.transportAssignSuccessSnackbar,
      content: Text('${updated.studentName} assigned to ${updated.routeName}'),
    ),
  );
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

// ─── TRN-9: raise a Finance transport-fee demand ──────────────────────────────

/// Opens the raise-transport-demand flow. Transport DEFINES the fee and RAISES a
/// Finance demand here — it NEVER collects payment (Finance owns collection).
Future<void> showRaiseTransportDemandDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final assigned = (ref.read(transportAllocationsProvider) ?? const [])
      .where((a) => a.isAssigned)
      .toList();
  if (assigned.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Assign a student to a route before raising a demand.'),
      ),
    );
    return;
  }

  final transportStructures = ref
      .read(financeFeeStructuresProvider)
      .where(
        (structure) => structure.categories
            .any((line) => line.category == FeeStructureCategory.transport),
      )
      .toList();
  if (transportStructures.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No transport fee structure found in Finance. Create one in Finance first.',
        ),
      ),
    );
    return;
  }

  var selectedStudentId = assigned.first.sisStudentId;
  var selectedStructureId = transportStructures.first.id;
  final yearController =
      TextEditingController(text: transportStructures.first.academicYear);
  final termController = TextEditingController(text: 'annual');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Raise transport fee demand'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transport defines the fee and raises a demand. '
                        'Finance collects payment — no payment is taken here.',
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop(false);
                            context.go(RouteNames.financeFeeStructures);
                          },
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open Finance'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedStudentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Student'),
                items: [
                  for (final allocation in assigned)
                    DropdownMenuItem<String>(
                      value: allocation.sisStudentId,
                      child: Text(
                        '${allocation.studentName} · ${allocation.routeName}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => selectedStudentId = value ?? selectedStudentId),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedStructureId,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Transport fee structure'),
                items: [
                  for (final structure in transportStructures)
                    DropdownMenuItem<String>(
                      value: structure.id,
                      child: Text(
                        structure.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(
                    () => selectedStructureId = value ?? selectedStructureId),
              ),
              TextField(
                controller: yearController,
                decoration: const InputDecoration(labelText: 'Academic year'),
              ),
              TextField(
                controller: termController,
                decoration: const InputDecoration(labelText: 'Term'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.transportRaiseDemandSubmitButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Raise demand'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final academicYear = yearController.text.trim();
  final term = termController.text.trim();
  if (academicYear.isEmpty || term.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Academic year and term are required.')),
    );
    return;
  }

  final allocation =
      assigned.firstWhere((a) => a.sisStudentId == selectedStudentId);

  try {
    final result = await ref.read(raiseTransportDemandProvider.notifier).execute(
          RaiseTransportDemandRequest(
            sisStudentId: allocation.sisStudentId,
            routeId: allocation.routeId,
            feeStructureId: selectedStructureId,
            academicYear: academicYear,
            term: term,
            allocationId: allocation.id,
          ),
        );
    if (!context.mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.transportRaiseDemandSuccessSnackbar,
        content: Text(
          result.idempotent
              ? 'Demand already raised (no new charge) — invoice ${result.invoiceId}'
              : 'Transport fee demand raised — invoice ${result.invoiceId}',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
  }
}

/// PRA-P0-20 — raise a Finance transport-fee demand for EVERY assigned student
/// who is not yet billed, in one action. Reuses [raiseTransportDemandProvider]
/// per allocation (demand only — Finance still collects) and is idempotent, so
/// re-running bills nobody twice. Surfaced from the allocation screen next to
/// the per-row billed status.
Future<void> showRaiseDemandForUnbilledDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final unbilled = (ref.read(transportAllocationsProvider) ?? const [])
      .where((a) => a.isAssigned && !a.demandRaised)
      .toList();
  if (unbilled.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All assigned students already have a transport demand.'),
      ),
    );
    return;
  }

  final transportStructures = ref
      .read(financeFeeStructuresProvider)
      .where(
        (structure) => structure.categories
            .any((line) => line.category == FeeStructureCategory.transport),
      )
      .toList();
  if (transportStructures.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No transport fee structure found in Finance. Create one in Finance first.',
        ),
      ),
    );
    return;
  }

  var selectedStructureId = transportStructures.first.id;
  final yearController =
      TextEditingController(text: transportStructures.first.academicYear);
  final termController = TextEditingController(text: 'annual');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Raise demand for unbilled'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${unbilled.length} assigned student(s) have no transport demand. '
                'Transport defines the fee and raises a demand — Finance collects; '
                'no payment is taken here.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedStructureId,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Transport fee structure'),
                items: [
                  for (final structure in transportStructures)
                    DropdownMenuItem<String>(
                      value: structure.id,
                      child: Text(
                        structure.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(
                    () => selectedStructureId = value ?? selectedStructureId),
              ),
              TextField(
                controller: yearController,
                decoration: const InputDecoration(labelText: 'Academic year'),
              ),
              TextField(
                controller: termController,
                decoration: const InputDecoration(labelText: 'Term'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.transportRaiseDemandSubmitButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Raise demands'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final academicYear = yearController.text.trim();
  final term = termController.text.trim();
  if (academicYear.isEmpty || term.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Academic year and term are required.')),
    );
    return;
  }

  var raised = 0;
  var alreadyBilled = 0;
  var failed = 0;
  for (final allocation in unbilled) {
    try {
      final result =
          await ref.read(raiseTransportDemandProvider.notifier).execute(
                RaiseTransportDemandRequest(
                  sisStudentId: allocation.sisStudentId,
                  routeId: allocation.routeId,
                  feeStructureId: selectedStructureId,
                  academicYear: academicYear,
                  term: term,
                  allocationId: allocation.id,
                ),
              );
      if (result == null) {
        failed++;
      } else if (result.idempotent) {
        alreadyBilled++;
      } else {
        raised++;
      }
    } catch (_) {
      failed++;
    }
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      key: QaTestKeys.transportRaiseDemandSuccessSnackbar,
      content: Text(
        'Transport demands: $raised raised'
        '${alreadyBilled > 0 ? ', $alreadyBilled already billed' : ''}'
        '${failed > 0 ? ', $failed failed' : ''}',
      ),
    ),
  );
}
