import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../parent_active_child_provider.dart';
import 'parent_transport_provider.dart';

/// Parent mobile transport — route allocation and telemetry-first ETA (PA-12).
class ParentTransportScreen extends ConsumerWidget {
  const ParentTransportScreen({
    super.key,
    this.onNotificationsTap,
  });

  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(parentActiveChildProvider);
    final allocationAsync = ref.watch(parentTransportAllocationProvider);

    return Scaffold(
      key: QaTestKeys.parentTransportScreen,
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'School Transport',
        subtitle: child?.name ?? 'Your child',
        showAi: false,
        onNotificationsTap: onNotificationsTap,
      ),
      body: allocationAsync.when(
        loading: () => const AksharaLoadingState(),
        error: (error, _) => AksharaErrorState(message: '$error'),
        data: (allocation) {
          if (allocation == null) {
            return const AksharaEmptyState(
              message: 'No transport allocation on file for this student.',
              icon: Icons.directions_bus_outlined,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            children: [
              AksharaSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Route', style: context.aksharaText.titleMedium),
                    const SizedBox(height: AksharaSpacing.s2),
                    Text(allocation.routeName),
                    const SizedBox(height: AksharaSpacing.s3),
                    Text('Bus', style: context.aksharaText.titleMedium),
                    const SizedBox(height: AksharaSpacing.s2),
                    Text(allocation.busNumber),
                  ],
                ),
              ),
              const SizedBox(height: AksharaSpacing.s4),
              AksharaSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pickup & drop', style: context.aksharaText.titleMedium),
                    const SizedBox(height: AksharaSpacing.s2),
                    Text('Pickup: ${allocation.pickupStop}'),
                    const SizedBox(height: AksharaSpacing.s2),
                    Text('Drop: ${allocation.dropStop}'),
                  ],
                ),
              ),
              const SizedBox(height: AksharaSpacing.s4),
              const AksharaInsightCard(
                message:
                    'Bus is approximately 8 minutes away (telemetry preview). '
                    'Live map integration is not enabled in this build.',
                actionLabel: 'Refresh ETA',
                icon: Icons.sensors_outlined,
                semanticLabelPrefix: 'Transport ETA',
              ),
            ],
          );
        },
      ),
    );
  }
}
