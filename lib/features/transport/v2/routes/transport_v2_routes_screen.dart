import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/repositories/api/transport/v2/transport_v2_datasource.dart';
import '../../../../core/repositories/api/transport/v2/transport_v2_repository.dart';
import '../../../../core/security/permissions.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../transport_models.dart' show TransportScreen;
import '../../widgets/transport_module_scaffold.dart';
import '../transport_v2_models.dart';
import '../transport_v2_providers.dart';
import '../assignment/transport_v2_assignment_sheet.dart';
import 'transport_v2_route_form.dart';

/// TR-02 v2 — Routes management on the relational API.
///
/// WHAT CHANGES FOR THE ADMIN, versus the screen this replaces:
///   * a route can be EDITED (BUS-033). Previously name, code, shift, direction
///     and both departure times were write-once — a typo was permanent.
///   * a route can be RETIRED or DELETED (BUS-034). Previously only `activate`
///     existed, so a discontinued route stayed live forever, kept counting in
///     KPIs and remained selectable for allocation.
///   * activation is GATED and the blockers are shown as a checklist (BUS-042).
///     Previously activate ran with zero validation, so an admin could publish a
///     route with no located stops, no bus and no driver — and nothing on screen
///     said so.
///   * the assigned bus and driver come from the DATED assignment for the
///     selected service date, and a substitute is labelled as such (BUS-051).
class TransportV2RoutesScreen extends ConsumerWidget {
  const TransportV2RoutesScreen({super.key});

  static const List<String> filterLabels = ['All', 'Active', 'Draft', 'Inactive'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(transportV2EnabledProvider);
    final routesAsync = ref.watch(transportV2RoutesProvider);
    final filterIndex = ref.watch(_filterProvider);

    return TransportModuleScaffold(
      screen: TransportScreen.routes,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (i) => ref.read(_filterProvider.notifier).state = i,
      body: !enabled
          // BUS-015: the relational store is per-school gated. Say so rather
          // than issuing a request that cannot succeed.
          ? const _NotEnabledState()
          : routesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
                child: AksharaLoadingState(semanticLabel: 'Loading routes'),
              ),
              error: (error, _) => AksharaErrorState(
                message: 'Unable to load transport routes.',
                onRetry: () => ref.invalidate(transportV2RoutesProvider),
              ),
              data: (result) => _RoutesBody(
                result: result,
                filterIndex: filterIndex,
              ),
            ),
    );
  }
}

final _filterProvider = StateProvider<int>((ref) => 0);

class _NotEnabledState extends StatelessWidget {
  const _NotEnabledState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AksharaSpacing.s4),
      child: AksharaEmptyState(
        key: QaTestKeys.transportV2NotEnabledState,
        title: 'Transport v2 is not enabled for this school',
        message:
            'This school has not been migrated to the new transport module yet. '
            'Its existing routes remain available on the current screens.',
        icon: Icons.alt_route_outlined,
      ),
    );
  }
}

class _RoutesBody extends ConsumerWidget {
  const _RoutesBody({required this.result, required this.filterIndex});

  final RoutesResult result;
  final int filterIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = _applyFilter(result.routes, filterIndex);
    final unstaffed = ref.watch(transportV2UnstaffedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Staleness is DISCLOSED, never hidden. Showing cached routes as live is
        // how an admin ends up configuring against data that no longer exists.
        if (result.isStale) _StaleBanner(cachedAt: result.cachedAt),

        // BUS-050 — routes with no crew for the selected date. This is the signal
        // that lets an admin arrange a substitute before 6 a.m. rather than
        // discovering the gap when a bus fails to arrive.
        unstaffed.maybeWhen(
          data: (rows) =>
              rows.isEmpty ? const SizedBox.shrink() : _UnstaffedBanner(rows: rows),
          orElse: () => const SizedBox.shrink(),
        ),

        Align(
          alignment: Alignment.centerRight,
          child: AksharaManageAction(
            permission: Permission.manageTransport,
            child: FilledButton.icon(
              key: QaTestKeys.transportV2CreateRouteButton,
              onPressed: () => showTransportV2RouteForm(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New route'),
            ),
          ),
        ),
        const SizedBox(height: AksharaSpacing.s4),

        if (routes.isEmpty)
          const AksharaEmptyState(
            message: 'No routes match the selected filter.',
            icon: Icons.alt_route_outlined,
          )
        else
          for (final route in routes) ...[
            _RouteCard(route: route),
            const SizedBox(height: AksharaSpacing.s3),
          ],
      ],
    );
  }

  static List<TransportRouteV2> _applyFilter(
    List<TransportRouteV2> routes,
    int index,
  ) {
    return switch (index) {
      1 => routes.where((r) => r.status == RouteV2Status.active).toList(),
      2 => routes.where((r) => r.status == RouteV2Status.draft).toList(),
      3 => routes.where((r) => r.status == RouteV2Status.inactive).toList(),
      _ => routes,
    };
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.cachedAt});

  final DateTime? cachedAt;

  @override
  Widget build(BuildContext context) {
    final at = cachedAt;
    final when = at == null
        ? ''
        : ' from ${at.hour.toString().padLeft(2, '0')}:'
            '${at.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s3),
      child: AksharaSurfaceCard(
        key: QaTestKeys.transportV2StaleBanner,
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, color: context.colors.error, size: 20),
            const SizedBox(width: AksharaSpacing.s3),
            Expanded(
              child: Text(
                'Showing saved data$when — could not reach the server. '
                'Changes are disabled until the connection returns.',
                style: context.aksharaText.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnstaffedBanner extends StatelessWidget {
  const _UnstaffedBanner({required this.rows});

  final List<UnstaffedRouteV2> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s3),
      child: AksharaSurfaceCard(
        key: QaTestKeys.transportV2UnstaffedBanner,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_outlined,
                    color: context.colors.error, size: 20),
                const SizedBox(width: AksharaSpacing.s3),
                Text(
                  '${rows.length} route${rows.length == 1 ? '' : 's'} '
                  'need attention today',
                  style: context.aksharaText.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s2),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(top: AksharaSpacing.s1),
                child: Text('${row.routeName} — ${row.reasonLabel}',
                    style: context.aksharaText.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteCard extends ConsumerWidget {
  const _RouteCard({required this.route});

  final TransportRouteV2 route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;
    final assignment = route.assignment;

    return AksharaSurfaceCard(
      key: QaTestKeys.transportV2RouteCard(route.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  route.code.isEmpty ? route.name : '${route.code} · ${route.name}',
                  style: text.titleMedium,
                ),
              ),
              _StatusChip(status: route.status),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s2),
          Text(
            '${route.shift.name.toUpperCase()} · '
            '${route.direction.name} · '
            '${route.stopCount} stop${route.stopCount == 1 ? '' : 's'} · '
            '${route.studentCount} student${route.studentCount == 1 ? '' : 's'} · '
            '${route.distanceLabel}',
            style: text.bodySmall,
          ),
          const SizedBox(height: AksharaSpacing.s2),

          // The bus and driver in force for the SELECTED DATE, resolved from the
          // dated assignment. Pre-v2 this read from a scalar no endpoint wrote,
          // so it was always blank.
          if (assignment == null)
            Text('Not assigned yet — no bus or driver',
                style: text.bodySmall
                    .copyWith(color: context.colors.onSurfaceVariant))
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${assignment.vehicleRegistration ?? "No bus"} · '
                    '${assignment.driverName ?? "No driver"}',
                    style: text.bodySmall,
                  ),
                ),
                // A covering driver must be visibly a substitute — otherwise the
                // admin cannot tell today's arrangement from the permanent one.
                if (assignment.isSubstitute)
                  AksharaStatusChip(
                    key: QaTestKeys.transportV2SubstituteChip(route.id),
                    label: 'Substitute',
                    tone: KpiAccent.warning,
                  ),
              ],
            ),

          if (route.stopsMissingLocation.isNotEmpty) ...[
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              '${route.stopsMissingLocation.length} stop(s) have no location — '
              'place them on the map before activating',
              style: text.bodySmall.copyWith(color: context.colors.error),
            ),
          ],
          if (route.hasNonMonotonicTimes) ...[
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              'Stop times do not run in order — check the schedule',
              style: text.bodySmall.copyWith(color: context.colors.error),
            ),
          ],

          const SizedBox(height: AksharaSpacing.s3),
          _RouteActions(route: route),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final RouteV2Status status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      RouteV2Status.active => ('Active', KpiAccent.success),
      RouteV2Status.draft => ('Draft', KpiAccent.warning),
      RouteV2Status.inactive => ('Inactive', KpiAccent.neutral),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}

class _RouteActions extends ConsumerWidget {
  const _RouteActions({required this.route});

  final TransportRouteV2 route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AksharaManageAction(
      permission: Permission.manageTransport,
      child: Wrap(
        spacing: AksharaSpacing.s2,
        runSpacing: AksharaSpacing.s2,
        children: [
          OutlinedButton.icon(
            key: QaTestKeys.transportV2EditRouteButton(route.id),
            onPressed: () => showTransportV2RouteForm(context, ref, route: route),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
          if (route.status != RouteV2Status.active)
            FilledButton.icon(
              key: QaTestKeys.transportV2ActivateRouteButton(route.id),
              onPressed: () => _activate(context, ref),
              icon: const Icon(Icons.play_arrow_outlined, size: 18),
              label: const Text('Activate'),
            ),
          if (route.status == RouteV2Status.active)
            OutlinedButton.icon(
              key: QaTestKeys.transportV2DeactivateRouteButton(route.id),
              onPressed: () => _deactivate(context, ref),
              icon: const Icon(Icons.pause_outlined, size: 18),
              label: const Text('Deactivate'),
            ),
          // BUS-043/048 — the operation that did not exist pre-v2.
          OutlinedButton.icon(
            key: QaTestKeys.transportV2AssignButton(route.id),
            onPressed: () =>
                showTransportV2AssignmentSheet(context, ref, route: route),
            icon: const Icon(Icons.directions_bus_outlined, size: 18),
            label: Text(route.assignment == null ? 'Assign' : 'Reassign'),
          ),
          // BUS-051 — cover today without touching the permanent arrangement.
          OutlinedButton.icon(
            key: QaTestKeys.transportV2SubstituteButton(route.id),
            onPressed: () => showTransportV2AssignmentSheet(
              context,
              ref,
              route: route,
              substituteMode: true,
            ),
            icon: const Icon(Icons.swap_horiz_outlined, size: 18),
            label: const Text('Substitute'),
          ),
          OutlinedButton.icon(
            key: QaTestKeys.transportV2ReadinessButton(route.id),
            onPressed: () => _showReadiness(context, ref),
            icon: const Icon(Icons.checklist_outlined, size: 18),
            label: const Text('Readiness'),
          ),
          OutlinedButton.icon(
            key: QaTestKeys.transportV2DeleteRouteButton(route.id),
            onPressed: () => _confirmDelete(context, ref),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// BUS-042 — activation is gated. On refusal the blockers are shown as a
  /// checklist rather than a bare error, because the admin needs to know what to
  /// DO. The legacy activate endpoint accepted anything and said nothing.
  Future<void> _activate(BuildContext context, WidgetRef ref) async {
    final mutations = ref.read(transportV2MutationsProvider.notifier);
    await mutations.activateRoute(route.id);
    final state = ref.read(transportV2MutationsProvider);
    if (!context.mounted) return;

    if (state.errorCode == TransportV2ErrorCodes.routeIncomplete) {
      await _showReadiness(context, ref, refused: true);
      return;
    }
    _reportOutcome(context, ref, state);
  }

  Future<void> _deactivate(BuildContext context, WidgetRef ref) async {
    final mutations = ref.read(transportV2MutationsProvider.notifier);
    final stillAllocated = await mutations.deactivateRoute(route.id);
    final state = ref.read(transportV2MutationsProvider);
    if (!context.mounted) return;

    if (!state.hasError && (stillAllocated ?? 0) > 0) {
      // Deactivation does not strip allocations. The admin is told how many
      // children still reference the route so they can re-home them.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.transportV2DeactivateWarningSnackbar,
          content: Text(
            'Route deactivated. $stillAllocated student(s) are still allocated '
            'to it — move them to another route.',
          ),
        ),
      );
      return;
    }
    _reportOutcome(context, ref, state);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${route.name}?'),
        content: const Text(
          'This cannot be undone. A route with students, assignments or trip '
          'history cannot be deleted — deactivate it instead so its history is '
          'preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.transportV2DeleteRouteConfirmButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(transportV2MutationsProvider.notifier).deleteRoute(route.id);
    if (!context.mounted) return;
    _reportOutcome(context, ref, ref.read(transportV2MutationsProvider));
  }

  Future<void> _showReadiness(
    BuildContext context,
    WidgetRef ref, {
    bool refused = false,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final async = ref.watch(transportV2ReadinessProvider(route.id));
          return AlertDialog(
            key: QaTestKeys.transportV2ReadinessDialog,
            title: Text(refused ? 'Cannot activate yet' : 'Route readiness'),
            content: async.when(
              loading: () => const SizedBox(
                height: 80,
                child: AksharaLoadingState(semanticLabel: 'Checking readiness'),
              ),
              error: (_, __) => const Text('Unable to check readiness.'),
              data: (readiness) => readiness.ready
                  ? const Text('This route is ready to activate.')
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final blocker in readiness.blockers)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AksharaSpacing.s2),
                            child: Row(
                              children: [
                                Icon(Icons.radio_button_unchecked,
                                    size: 16, color: context.colors.error),
                                const SizedBox(width: AksharaSpacing.s2),
                                Expanded(child: Text(blocker.label)),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// One outcome reporter so every refusal reads the same way.
  ///
  /// A DOMAIN refusal shows the guidance and no retry — retrying
  /// STOP_HAS_ALLOCATIONS cannot help. A transport fault offers a retry.
  static void _reportOutcome(
    BuildContext context,
    WidgetRef ref,
    TransportV2MutationState state,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    if (state.hasError) {
      final guidance = transportV2Guidance(state.errorCode);
      messenger.showSnackBar(
        SnackBar(
          key: QaTestKeys.transportV2ErrorSnackbar,
          content: Text(
            guidance.isNotEmpty ? guidance : state.failure!.message,
          ),
          action: state.isRetryable
              ? SnackBarAction(
                  label: 'Retry',
                  onPressed: () => ref.invalidate(transportV2RoutesProvider),
                )
              : null,
        ),
      );
      return;
    }
    if (state.successMessage != null) {
      messenger.showSnackBar(
        SnackBar(
          key: QaTestKeys.transportV2SuccessSnackbar,
          content: Text(state.successMessage!),
        ),
      );
    }
  }
}
