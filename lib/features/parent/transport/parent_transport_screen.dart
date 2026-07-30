import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../transport/transport_models.dart';
import '../parent_active_child_provider.dart';
import 'parent_transport_provider.dart';

/// Parent mobile transport — route allocation for the active child (PA-12).
///
/// BUS-001: this screen renders ONLY facts the system holds. It previously
/// displayed a compile-time constant "Bus is approximately 8 minutes away
/// (telemetry preview)" to every parent, for every child, on every load — an
/// invented claim about a child's school bus. There is no ETA engine (BUS-091)
/// and no position source (Phase 9), so no time-based claim may appear here.
/// Live tracking arrives with BUS-096; until then this surface stays factual.
class ParentTransportScreen extends ConsumerWidget {
  const ParentTransportScreen({
    super.key,
    this.onNotificationsTap,
  });

  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(parentActiveChildProvider);
    final viewAsync = ref.watch(parentTransportAllocationProvider);

    return Scaffold(
      key: QaTestKeys.parentTransportScreen,
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'School Transport',
        subtitle: child?.name ?? 'Your child',
        showAi: false,
        onNotificationsTap: onNotificationsTap,
      ),
      // DS V2 P4 — premium persona canvas behind the transport content.
      //
      // The canvas is adopted from DS V2; the DS-V2-era *body* deliberately is
      // not. That body rendered a compile-time "Bus is approximately 8 minutes
      // away (telemetry preview)" card to every parent, for every child, on
      // every load. BUS-001 removed it: there is no position source (Phase 9)
      // and no ETA engine (BUS-091), so no time-based claim about a child's bus
      // may appear here. Visual system in, invented fact stays out.
      body: AksharaPremiumBackground(
        showMotif: false,
        child: ErpAsyncBody(
          state: resolveErpAsync(viewAsync, isDataEmpty: (_) => false),
          loadingLabel: 'Loading',
          emptyMessage: 'No transport allocation on file for this student.',
          emptyIcon: Icons.directions_bus_outlined,
          onRetry: () => ref.invalidate(parentTransportAllocationProvider),
          builder: (view) {
            return switch (view.availability) {
              ParentTransportAvailability.notEnabled => const _NotEnabledState(),
              ParentTransportAvailability.noAllocation =>
                const _NoAllocationState(),
              ParentTransportAvailability.available =>
                _AllocationDetail(allocation: view.allocation!),
            };
          },
        ),
      ),
    );
  }
}

/// BUS-003 — parent transport is not live yet. Say so plainly; do not render a
/// failure screen for a capability the school has simply not switched on.
class _NotEnabledState extends StatelessWidget {
  const _NotEnabledState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AksharaSpacing.s4),
      child: AksharaEmptyState(
        key: QaTestKeys.parentTransportNotEnabledState,
        title: 'Transport not enabled yet',
        message:
            'Bus details will appear here once your school enables transport '
            'in the app.',
        icon: Icons.directions_bus_outlined,
      ),
    );
  }
}

class _NoAllocationState extends StatelessWidget {
  const _NoAllocationState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AksharaSpacing.s4),
      child: AksharaEmptyState(
        title: 'No bus assigned',
        message: 'No transport allocation on file for this student.',
        icon: Icons.directions_bus_outlined,
      ),
    );
  }
}

class _AllocationDetail extends StatelessWidget {
  const _AllocationDetail({required this.allocation});

  final StudentTransportAllocation allocation;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        AksharaSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Route', style: text.titleMedium),
              const SizedBox(height: AksharaSpacing.s2),
              Text(_orNotAssigned(allocation.routeName)),
              const SizedBox(height: AksharaSpacing.s3),
              Text('Bus', style: text.titleMedium),
              const SizedBox(height: AksharaSpacing.s2),
              // BUS-043 note: `assignedBus` has no write path today, so this
              // reads empty for every real allocation. Rendering "Not assigned
              // yet" is the honest form until vehicle assignment ships.
              Text(_orNotAssigned(allocation.busNumber)),
            ],
          ),
        ),
        const SizedBox(height: AksharaSpacing.s4),
        AksharaSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pickup & drop', style: text.titleMedium),
              const SizedBox(height: AksharaSpacing.s2),
              Text('Pickup: ${_orNotAssigned(allocation.pickupStop)}'),
              const SizedBox(height: AksharaSpacing.s2),
              Text('Drop: ${_orNotAssigned(allocation.dropStop)}'),
            ],
          ),
        ),
      ],
    );
  }

  static String _orNotAssigned(String value) =>
      value.trim().isEmpty ? 'Not assigned yet' : value.trim();
}
