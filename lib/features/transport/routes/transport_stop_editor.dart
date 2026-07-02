import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../transport_models.dart';
import '../transport_mutations_provider.dart';
import '../transport_providers.dart';
import '../transport_requests.dart';
import '../reports/transport_report_exporters.dart';

/// TRN-4 — opens the stop editor for a route (add / reorder / edit / remove).
Future<void> showTransportStopEditor(
  BuildContext context,
  WidgetRef ref, {
  required TransportRoute route,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(AksharaSpacing.s6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: _StopEditor(routeId: route.id, routeName: route.name),
      ),
    ),
  );
}

class _StopEditor extends ConsumerWidget {
  const _StopEditor({required this.routeId, required this.routeName});

  final String routeId;
  final String routeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read the current stops from the freshly-loaded routes list.
    final routes = ref.watch(transportRoutesProvider);
    final route = routes.where((r) => r.id == routeId).firstOrNull;
    final stops = route?.stops ?? const <TransportStop>[];
    final text = context.aksharaText;

    return Padding(
      padding: const EdgeInsets.all(AksharaSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Stops · $routeName', style: text.titleMedium),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s3),
          Wrap(
            spacing: AksharaSpacing.s2,
            runSpacing: AksharaSpacing.s2,
            children: [
              FilledButton.icon(
                key: QaTestKeys.transportAddStopButton,
                onPressed: () => _addStop(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add stop'),
              ),
              OutlinedButton.icon(
                onPressed: () => _exportRoster(context, ref, pdf: true),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Roster PDF'),
              ),
              OutlinedButton.icon(
                onPressed: () => _exportRoster(context, ref, pdf: false),
                icon: const Icon(Icons.table_view_outlined, size: 18),
                label: const Text('Roster CSV'),
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s3),
          Flexible(
            child: stops.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AksharaSpacing.s6),
                    child: Text('No stops yet. Add the first stop.',
                        style: text.bodySmall),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: stops.length,
                    itemBuilder: (context, index) {
                      final stop = stops[index];
                      return Card(
                        elevation: 0,
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${stop.sequence}')),
                          title: Text(stop.name),
                          subtitle: stop.scheduledTime.isEmpty
                              ? null
                              : Text('Pickup ${stop.scheduledTime}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                key: QaTestKeys.transportStopMoveUpButton(stop.id),
                                icon: const Icon(Icons.arrow_upward, size: 18),
                                tooltip: 'Move up',
                                onPressed: index == 0
                                    ? null
                                    : () => _reorder(context, ref, stops,
                                        index, index - 1),
                              ),
                              IconButton(
                                key: QaTestKeys.transportStopMoveDownButton(stop.id),
                                icon: const Icon(Icons.arrow_downward, size: 18),
                                tooltip: 'Move down',
                                onPressed: index == stops.length - 1
                                    ? null
                                    : () => _reorder(context, ref, stops,
                                        index, index + 1),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Edit stop',
                                onPressed: () => _editStop(context, ref, stop),
                              ),
                              IconButton(
                                key: QaTestKeys.transportRemoveStopButton(stop.id),
                                icon: const Icon(Icons.delete_outline, size: 18),
                                tooltip: 'Remove stop',
                                onPressed: () => _removeStop(context, ref, stop),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addStop(BuildContext context, WidgetRef ref) async {
    final result = await _stopFormDialog(context);
    if (result == null || !context.mounted) return;
    await _run(context, ref, () async {
      await ref.read(stopEditorProvider.notifier).add(
            AddTransportStopRequest(
              routeId: routeId,
              name: result.name,
              pickupTime: result.pickupTime,
              dropTime: result.dropTime,
            ),
          );
    });
  }

  Future<void> _editStop(
    BuildContext context,
    WidgetRef ref,
    TransportStop stop,
  ) async {
    final result = await _stopFormDialog(context, stop: stop);
    if (result == null || !context.mounted) return;
    await _run(context, ref, () async {
      await ref.read(stopEditorProvider.notifier).editStop(
            UpdateTransportStopRequest(
              routeId: routeId,
              stopId: stop.id,
              name: result.name,
              pickupTime: result.pickupTime,
              dropTime: result.dropTime,
            ),
          );
    });
  }

  Future<void> _removeStop(
    BuildContext context,
    WidgetRef ref,
    TransportStop stop,
  ) async {
    await _run(context, ref, () async {
      await ref.read(stopEditorProvider.notifier).remove(
            RemoveTransportStopRequest(routeId: routeId, stopId: stop.id),
          );
    });
  }

  Future<void> _reorder(
    BuildContext context,
    WidgetRef ref,
    List<TransportStop> stops,
    int from,
    int to,
  ) async {
    final ids = [for (final s in stops) s.id];
    final moved = ids.removeAt(from);
    ids.insert(to, moved);
    await _run(context, ref, () async {
      await ref.read(stopEditorProvider.notifier).reorder(
            ReorderTransportStopsRequest(routeId: routeId, stopOrder: ids),
          );
    });
  }

  Future<void> _exportRoster(
    BuildContext context,
    WidgetRef ref, {
    required bool pdf,
  }) async {
    try {
      final roster =
          await ref.read(transportRouteRosterProvider(routeId).future);
      final exporters =
          TransportReportExporters(ref.read(aksharaReportExportServiceProvider));
      if (pdf) {
        await exporters.shareRosterPdf(roster);
      } else {
        await exporters.shareRosterCsv(roster);
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
    }
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      final state = ref.read(stopEditorProvider);
      if (!context.mounted) return;
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(aksharaErrorMessage(state.error!))),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: QaTestKeys.transportStopSavedSnackbar,
          content: Text('Stops updated'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
    }
  }
}

class _StopFormResult {
  const _StopFormResult(this.name, this.pickupTime, this.dropTime);
  final String name;
  final String pickupTime;
  final String dropTime;
}

Future<_StopFormResult?> _stopFormDialog(
  BuildContext context, {
  TransportStop? stop,
}) async {
  final name = TextEditingController(text: stop?.name ?? '');
  final pickup = TextEditingController(text: stop?.scheduledTime ?? '');
  final drop = TextEditingController();

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(stop == null ? 'Add stop' : 'Edit stop'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: QaTestKeys.transportStopNameField,
            controller: name,
            decoration: const InputDecoration(labelText: 'Stop name'),
          ),
          TextField(
            controller: pickup,
            decoration: const InputDecoration(
              labelText: 'Pickup time (optional)',
              hintText: 'e.g. 7:05 AM',
            ),
          ),
          TextField(
            controller: drop,
            decoration: const InputDecoration(
              labelText: 'Drop time (optional)',
              hintText: 'e.g. 3:40 PM',
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
          key: QaTestKeys.transportStopDialogSubmitButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (saved != true) return null;
  if (name.text.trim().isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stop name is required.')),
      );
    }
    return null;
  }
  return _StopFormResult(
    name.text.trim(),
    pickup.text.trim(),
    drop.text.trim(),
  );
}
