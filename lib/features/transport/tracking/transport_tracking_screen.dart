import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../transport_models.dart';
import '../transport_providers.dart';
import '../widgets/transport_module_scaffold.dart';

/// TR-07 — GPS Tracking (placeholder architecture).
class TransportTrackingScreen extends ConsumerWidget {
  const TransportTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(transportTrackingLoadingProvider);
    final isError = ref.watch(transportTrackingErrorProvider);
    final data = ref.watch(transportTrackingProvider);

    return TransportModuleScaffold(
      screen: TransportScreen.tracking,
      showFilterBar: false,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        data: data,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required TransportTrackingPlaceholderData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading GPS tracking'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load GPS tracking data.',
      );
    }

    if (data == null) {
      return const AksharaErrorState(
        message: 'GPS tracking is not configured.',
      );
    }

    final isMobile = AdminLayout.isMobile(context);
    final mapHeight = isMobile ? 200.0 : 320.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Map placeholder: ${data.mapPlaceholderLabel}',
          child: Card(
            elevation: 0,
            child: SizedBox(
              height: mapHeight,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 48,
                      color: context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: AksharaSpacing.s3),
                    Text(
                      data.mapPlaceholderLabel,
                      style: context.aksharaText.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AksharaSpacing.s2),
                    Text(
                      'Telemetry-first view — map provider wiring is future work',
                      style: context.aksharaText.bodySmall.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Vehicle telemetry'),
        const SizedBox(height: AksharaSpacing.s3),
        _TrackingVehicleList(vehicles: data.vehicles),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.integrationNote,
          actionLabel: 'Parent app',
          icon: Icons.family_restroom_outlined,
          semanticLabelPrefix: 'Parent tracking integration',
          onAction: () => context.go(data.parentAppRoute),
        ),
      ],
    );
  }
}

class _TrackingVehicleList extends StatelessWidget {
  const _TrackingVehicleList({required this.vehicles});

  final List<TrackingVehicleStatus> vehicles;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final vehicle in vehicles) ...[
            _TrackingVehicleCard(vehicle: vehicle),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Vehicle telemetry, ${vehicles.length} buses',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Bus')),
              DataColumn(label: Text('Route')),
              DataColumn(label: Text('Driver')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Speed')),
              DataColumn(label: Text('Last ping')),
              DataColumn(label: Text('Next stop')),
              DataColumn(label: Text('ETA')),
            ],
            rows: [
              for (final vehicle in vehicles)
                DataRow(
                  cells: [
                    DataCell(Text(vehicle.busNumber)),
                    DataCell(Text(vehicle.routeName)),
                    DataCell(Text(vehicle.driverName)),
                    DataCell(_TrackingStatusChip(status: vehicle.status)),
                    DataCell(Text('${vehicle.speedKph} km/h')),
                    DataCell(Text(vehicle.lastPing)),
                    DataCell(Text(vehicle.nextStop)),
                    DataCell(
                      Text(
                        vehicle.etaMinutes > 0
                            ? '${vehicle.etaMinutes} min'
                            : '—',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingVehicleCard extends StatelessWidget {
  const _TrackingVehicleCard({required this.vehicle});

  final TrackingVehicleStatus vehicle;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label:
          'Bus ${vehicle.busNumber}, ${vehicle.status.name}, speed ${vehicle.speedKph}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${vehicle.busNumber} — ${vehicle.routeName}',
                      style: text.titleSmall,
                    ),
                  ),
                  _TrackingStatusChip(status: vehicle.status),
                ],
              ),
              Text(
                '${vehicle.speedKph} km/h · Ping ${vehicle.lastPing}',
                style: text.bodySmall,
              ),
              Text('Next: ${vehicle.nextStop}', style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingStatusChip extends StatelessWidget {
  const _TrackingStatusChip({required this.status});

  final TrackingStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      TrackingStatus.moving => ('Moving', KpiAccent.success),
      TrackingStatus.idle => ('At stop', KpiAccent.primary),
      TrackingStatus.delayed => ('Delayed', KpiAccent.warning),
      TrackingStatus.offline => ('Offline', KpiAccent.error),
    };

    return AksharaStatusChip(label: label, tone: tone);
  }
}
