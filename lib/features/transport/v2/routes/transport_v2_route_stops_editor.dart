import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/repositories/api/transport/v2/transport_v2_datasource.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../transport_v2_models.dart';
import '../transport_v2_providers.dart';

/// BUS-038/039/040 — the route's stop sequence: attach, detach, reorder, retime.
///
/// WHAT THIS REPLACES
///
/// The legacy stop editor operated on a JSON array embedded in the route, using
/// up/down arrow buttons, free-text time fields, and a form that submitted a drop
/// time it had never loaded — silently erasing it on any unrelated edit.
///
/// Here the stops are shared school entities (BUS-040) attached to this route with
/// this route's own sequence and times. Consequences the UI must make visible:
///   * attaching picks from EXISTING stops rather than typing a name, so a stop
///     can never be created by a typo;
///   * a stop with no location cannot be attached at all — it would produce a
///     route that can never be published, with no obvious cause;
///   * detaching is blocked while children are allocated to that stop on this
///     route, and says how many;
///   * reorder is a real drag, and the resulting order is validated server-side
///     as a permutation so no stop can be dropped from the route.
Future<void> showTransportV2RouteStopsEditor(
  BuildContext context,
  WidgetRef ref, {
  required TransportRouteV2 route,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(AksharaSpacing.s6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: _RouteStopsEditor(routeId: route.id, routeName: route.name),
      ),
    ),
  );
}

class _RouteStopsEditor extends ConsumerWidget {
  const _RouteStopsEditor({required this.routeId, required this.routeName});

  final String routeId;
  final String routeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(transportV2RoutesProvider);
    final route = routesAsync.maybeWhen(
      data: (r) => r.routes.where((x) => x.id == routeId).firstOrNull,
      orElse: () => null,
    );
    final stops = route?.stops ?? const <RouteStopV2>[];

    return Padding(
      padding: const EdgeInsets.all(AksharaSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Stops · $routeName',
                    style: context.aksharaText.titleMedium),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s3),

          if (route != null && route.hasNonMonotonicTimes)
            Padding(
              padding: const EdgeInsets.only(bottom: AksharaSpacing.s3),
              child: Text(
                'Pickup times do not increase along the route. Check the order '
                'and the times — a bus cannot reach a later stop earlier.',
                key: QaTestKeys.transportV2StopOrderWarning,
                style: context.aksharaText.bodySmall
                    .copyWith(color: context.colors.error),
              ),
            ),

          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: QaTestKeys.transportV2AttachStopButton,
              onPressed: () => _attach(context, ref),
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('Add stop to route'),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s3),

          Flexible(
            child: stops.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(AksharaSpacing.s6),
                    child: Text(
                      'No stops on this route yet. A route needs at least two '
                      'before it can go live.',
                    ),
                  )
                // A real drag, not up/down arrows: reordering eight stops with
                // arrow taps is 20+ interactions.
                : ReorderableListView.builder(
                    key: QaTestKeys.transportV2StopReorderList,
                    shrinkWrap: true,
                    buildDefaultDragHandles: true,
                    itemCount: stops.length,
                    onReorder: (from, to) =>
                        _reorder(context, ref, stops, from, to),
                    itemBuilder: (context, index) {
                      final rs = stops[index];
                      return _RouteStopTile(
                        key: ValueKey(rs.stop.id),
                        routeId: routeId,
                        routeStop: rs,
                        onEditTimes: () => _editTimes(context, ref, rs),
                        onDetach: () => _detach(context, ref, rs),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Attaches an EXISTING school stop. Nothing here can create a stop, so a
  /// typed name can never become a phantom stop the roster then groups by.
  Future<void> _attach(BuildContext context, WidgetRef ref) async {
    final route = ref.read(transportV2RoutesProvider).maybeWhen(
          data: (r) => r.routes.where((x) => x.id == routeId).firstOrNull,
          orElse: () => null,
        );
    final alreadyOn = {for (final s in route?.stops ?? const []) s.stop.id};

    final picked = await showDialog<TransportStopV2>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final stopsAsync = ref.watch(transportV2StopsProvider);
          return AlertDialog(
            key: QaTestKeys.transportV2AttachStopDialog,
            title: const Text('Add a stop to this route'),
            content: stopsAsync.when(
              loading: () => const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Text('Could not load stops.'),
              data: (result) {
                final available = result.stops
                    .where((s) => !alreadyOn.contains(s.id))
                    .toList(growable: false);
                if (available.isEmpty) {
                  return const Text(
                    'Every school stop is already on this route. Create a new '
                    'stop first.',
                  );
                }
                return SizedBox(
                  width: 420,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final s in available)
                        ListTile(
                          key: QaTestKeys.transportV2AttachStopOption(s.id),
                          title: Text(s.name),
                          subtitle: Text(
                            s.needsLocation
                                // Stated, not hidden: attaching this would build
                                // a route that can never be published.
                                ? 'No location — set it before adding to a route'
                                : [
                                    if (s.addressText.isNotEmpty) s.addressText,
                                    'geofence ${s.geofenceRadiusM} m',
                                  ].join(' · '),
                            style: s.needsLocation
                                ? TextStyle(color: context.colors.error)
                                : null,
                          ),
                          enabled: !s.needsLocation,
                          onTap: s.needsLocation
                              ? null
                              : () => Navigator.of(context).pop(s),
                        ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
    if (picked == null || !context.mounted) return;

    final times = await _timesDialog(context);
    if (times == null || !context.mounted) return;

    await ref.read(transportV2MutationsProvider.notifier).attachStop(
          routeId: routeId,
          stopId: picked.id,
          pickupTime: times.pickup,
          dropTime: times.drop,
        );
    if (!context.mounted) return;
    _report(context, ref);
  }

  Future<void> _editTimes(
    BuildContext context,
    WidgetRef ref,
    RouteStopV2 rs,
  ) async {
    final times = await _timesDialog(
      context,
      pickup: rs.pickupTime,
      drop: rs.dropTime,
    );
    if (times == null || !context.mounted) return;

    await ref.read(transportV2MutationsProvider.notifier).updateRouteStop(
          routeId: routeId,
          stopId: rs.stop.id,
          // Only a value the dialog actually holds is sent. An untouched time is
          // left alone server-side — the structural fix for BUS-007's erasure.
          pickupTime: times.pickup,
          dropTime: times.drop,
        );
    if (!context.mounted) return;
    _report(context, ref);
  }

  Future<void> _detach(
    BuildContext context,
    WidgetRef ref,
    RouteStopV2 rs,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${rs.stop.name} from this route?'),
        content: const Text(
          'The stop itself is kept — it may be used by other routes. Students '
          'allocated to this stop on this route must be moved first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.transportV2DetachStopConfirmButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(transportV2MutationsProvider.notifier).detachStop(
          routeId: routeId,
          stopId: rs.stop.id,
        );
    if (!context.mounted) return;
    _report(context, ref);
  }

  Future<void> _reorder(
    BuildContext context,
    WidgetRef ref,
    List<RouteStopV2> stops,
    int from,
    int to,
  ) async {
    // ReorderableListView reports the target index BEFORE the removal, so a
    // downward move is off by one without this adjustment. Getting it wrong
    // silently reorders to the wrong position.
    final target = to > from ? to - 1 : to;
    final ids = [for (final s in stops) s.stop.id];
    final moved = ids.removeAt(from);
    ids.insert(target, moved);

    await ref
        .read(transportV2MutationsProvider.notifier)
        .reorderStops(routeId: routeId, stopOrder: ids);
    if (!context.mounted) return;
    _report(context, ref);
  }

  static void _report(BuildContext context, WidgetRef ref) {
    final state = ref.read(transportV2MutationsProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (state.hasError) {
      final guidance = transportV2Guidance(state.errorCode);
      messenger.showSnackBar(
        SnackBar(
          key: QaTestKeys.transportV2ErrorSnackbar,
          content: Text(guidance.isNotEmpty ? guidance : state.failure!.message),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        key: QaTestKeys.transportV2SuccessSnackbar,
        content: Text(state.successMessage ?? 'Saved'),
      ),
    );
  }
}

class _RouteStopTile extends StatelessWidget {
  const _RouteStopTile({
    super.key,
    required this.routeId,
    required this.routeStop,
    required this.onEditTimes,
    required this.onDetach,
  });

  final String routeId;
  final RouteStopV2 routeStop;
  final VoidCallback onEditTimes;
  final VoidCallback onDetach;

  @override
  Widget build(BuildContext context) {
    final needsLocation = routeStop.stop.needsLocation;
    return Card(
      elevation: 0,
      child: ListTile(
        key: QaTestKeys.transportV2RouteStopTile(routeStop.stop.id),
        leading: CircleAvatar(child: Text('${routeStop.sequence}')),
        title: Text(routeStop.stop.name),
        subtitle: Text(
          needsLocation
              ? 'No location — this route cannot go live'
              : routeStop.timesLabel,
          style: needsLocation ? TextStyle(color: context.colors.error) : null,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: QaTestKeys.transportV2EditStopTimesButton(routeStop.stop.id),
              icon: const Icon(Icons.schedule_outlined, size: 18),
              tooltip: 'Edit times',
              onPressed: onEditTimes,
            ),
            IconButton(
              key: QaTestKeys.transportV2DetachStopButton(routeStop.stop.id),
              icon: const Icon(Icons.link_off_outlined, size: 18),
              tooltip: 'Remove from route',
              onPressed: onDetach,
            ),
          ],
        ),
      ),
    );
  }
}

class _StopTimes {
  const _StopTimes(this.pickup, this.drop);
  final StopTime? pickup;
  final StopTime? drop;
}

/// Time entry via pickers only. Free text is not offered, so the "7.05"/"morning"
/// class of value the legacy field accepted cannot be produced here at all.
Future<_StopTimes?> _timesDialog(
  BuildContext context, {
  StopTime? pickup,
  StopTime? drop,
}) {
  StopTime? p = pickup;
  StopTime? d = drop;
  return showDialog<_StopTimes>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> pick(bool isPickup) async {
          final current = isPickup ? p : d;
          final result = await showTimePicker(
            context: context,
            initialTime: current == null
                ? TimeOfDay(hour: isPickup ? 7 : 15, minute: 0)
                : TimeOfDay(hour: current.hour, minute: current.minute),
          );
          if (result == null) return;
          setState(() {
            final v = StopTime(result.hour * 60 + result.minute);
            if (isPickup) {
              p = v;
            } else {
              d = v;
            }
          });
        }

        return AlertDialog(
          key: QaTestKeys.transportV2StopTimesDialog,
          title: const Text('Stop times'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                key: QaTestKeys.transportV2StopPickupTimeButton,
                onPressed: () => pick(true),
                // "Not set" is honest and distinct from a fabricated default.
                child: Text('Pickup: ${p?.toDisplay() ?? 'Not set'}'),
              ),
              const SizedBox(height: AksharaSpacing.s2),
              OutlinedButton(
                key: QaTestKeys.transportV2StopDropTimeButton,
                onPressed: () => pick(false),
                child: Text('Drop: ${d?.toDisplay() ?? 'Not set'}'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: QaTestKeys.transportV2StopTimesSubmitButton,
              onPressed: () => Navigator.of(context).pop(_StopTimes(p, d)),
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
}
