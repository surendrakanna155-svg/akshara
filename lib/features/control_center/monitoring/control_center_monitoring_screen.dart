import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../control_center_models.dart';
import '../control_center_providers.dart';
import '../widgets/control_center_module_scaffold.dart';

/// ACC-10 — Platform Monitoring.
class ControlCenterMonitoringScreen extends ConsumerWidget {
  const ControlCenterMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(controlCenterMonitoringLoadingProvider);
    final isError = ref.watch(controlCenterMonitoringErrorProvider);
    final data = ref.watch(controlCenterMonitoringProvider);

    return ControlCenterModuleScaffold(
      screen: ControlCenterScreen.monitoring,
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
    required ControlCenterMonitoringData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading platform monitoring',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load platform monitoring.',
      );
    }

    if (data == null) {
      return const AksharaErrorState(
        message: 'Monitoring data is not available.',
      );
    }

    final text = context.aksharaText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Platform monitoring'),
        Text(
          'Error rate ${data.errorRatePercent}% · ${data.activeDeployments} active deployments',
          style: text.bodyMedium,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        for (final service in data.services) ...[
          _ServiceHealthCard(service: service),
          const SizedBox(height: AksharaSpacing.s3),
        ],
        const SizedBox(height: AksharaSpacing.s4),
        const AksharaSectionHeader(title: 'Feature flags'),
        const SizedBox(height: AksharaSpacing.s3),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Wrap(
              spacing: AksharaSpacing.s2,
              runSpacing: AksharaSpacing.s2,
              children: [
                for (final flag in data.featureFlags)
                  Chip(label: Text(flag, style: text.labelMedium)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ServiceHealthCard extends StatelessWidget {
  const _ServiceHealthCard({required this.service});

  final PlatformServiceHealth service;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    final (label, tone) = switch (service.status) {
      PlatformHealthStatus.healthy => ('Healthy', KpiAccent.success),
      PlatformHealthStatus.degraded => ('Degraded', KpiAccent.warning),
      PlatformHealthStatus.critical => ('Critical', KpiAccent.error),
    };

    return Semantics(
      container: true,
      label: '${service.serviceName}: $label',
      child: Card(
        elevation: 0,
        child: ListTile(
          title: Text(service.serviceName, style: text.titleSmall),
          subtitle: Text(
            'Uptime ${service.uptimePercent} · Last incident: ${service.lastIncident}',
            style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
          ),
          trailing: AksharaStatusChip(
            label: label,
            tone: tone,
            semanticLabel: 'Service status: $label',
          ),
        ),
      ),
    );
  }
}
