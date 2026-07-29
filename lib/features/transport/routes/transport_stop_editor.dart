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
                          // BUS-006/BUS-007: surface BOTH persisted times. Drop
                          // time was stored by the backend but had no display,
                          // which is why its silent erasure went unnoticed.
                          subtitle: Text(_stopTimesLabel(stop)),
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

/// BUS-006/BUS-007 — human-readable summary of a stop's persisted times.
String _stopTimesLabel(TransportStop stop) {
  if (stop.hasNoTimes) return 'Time not set';
  final pickup = stop.pickupTime.trim();
  final drop = stop.dropTime.trim();
  return [
    if (pickup.isNotEmpty) 'Pickup $pickup',
    if (drop.isNotEmpty) 'Drop $drop',
  ].join(' · ');
}

class _StopFormResult {
  const _StopFormResult(this.name, this.pickupTime, this.dropTime);
  final String name;
  final String pickupTime;
  final String dropTime;
}

/// BUS-007 — stop add/edit form.
///
/// A `StatefulWidget` so its three [TextEditingController]s are disposed; the
/// previous dialog created them in a bare function and leaked one set per open.
///
/// The defect this fixes: in EDIT mode the drop-time controller was constructed
/// empty (`TextEditingController()`) regardless of the stop's persisted value,
/// and the result was submitted unconditionally — so editing only a stop's NAME
/// silently wiped its drop time, with no signal to the admin and no way back.
/// Both fields now prefill from the persisted stop (BUS-006 made drop time
/// readable in the first place).
class _StopFormDialog extends StatefulWidget {
  const _StopFormDialog({this.stop});

  final TransportStop? stop;

  @override
  State<_StopFormDialog> createState() => _StopFormDialogState();
}

class _StopFormDialogState extends State<_StopFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _pickup;
  late final TextEditingController _drop;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final stop = widget.stop;
    _name = TextEditingController(text: stop?.name ?? '');
    // BUS-007: prefill BOTH times from the persisted stop — never blank on edit.
    _pickup = TextEditingController(text: stop?.pickupTime ?? '');
    _drop = TextEditingController(text: stop?.dropTime ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _pickup.dispose();
    _drop.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = 'Stop name is required.');
      return;
    }
    Navigator.of(context).pop(
      _StopFormResult(
        _name.text.trim(),
        _pickup.text.trim(),
        _drop.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.stop == null ? 'Add stop' : 'Edit stop'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: QaTestKeys.transportStopNameField,
            controller: _name,
            decoration: InputDecoration(
              labelText: 'Stop name',
              errorText: _nameError,
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          TextField(
            key: QaTestKeys.transportStopPickupTimeField,
            controller: _pickup,
            decoration: const InputDecoration(
              labelText: 'Pickup time (optional)',
              hintText: 'e.g. 7:05 AM',
            ),
          ),
          TextField(
            key: QaTestKeys.transportStopDropTimeField,
            controller: _drop,
            decoration: const InputDecoration(
              labelText: 'Drop time (optional)',
              hintText: 'e.g. 3:40 PM',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.transportStopDialogSubmitButton,
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Future<_StopFormResult?> _stopFormDialog(
  BuildContext context, {
  TransportStop? stop,
}) {
  return showDialog<_StopFormResult>(
    context: context,
    builder: (context) => _StopFormDialog(stop: stop),
  );
}
