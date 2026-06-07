import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../management_models.dart';
import '../management_providers.dart';
import '../widgets/management_kpi_row.dart';
import '../widgets/management_module_scaffold.dart';
import '../widgets/management_segment_panel.dart';

/// MG-03 — Admissions Funnel.
class ManagementAdmissionsScreen extends ConsumerWidget {
  const ManagementAdmissionsScreen({super.key});

  static const List<String> filterLabels = [
    'This month',
    'All sources',
    'All counselors',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(managementAdmissionsLoadingProvider);
    final isError = ref.watch(managementAdmissionsErrorProvider);
    final isEmpty = ref.watch(managementAdmissionsEmptyProvider);
    final data = ref.watch(managementAdmissionsFunnelProvider);
    final filterIndex = ref.watch(managementAdmissionsFilterProvider);

    return ManagementModuleScaffold(
      screen: ManagementScreen.admissions,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(managementAdmissionsFilterProvider.notifier).state = index,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        data: data,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required ManagementAdmissionsFunnelData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading admissions funnel',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load admissions funnel.',
      );
    }

    if (isEmpty || data == null) {
      return const AksharaEmptyState(
        message: 'No admissions data for the selected filters.',
        icon: Icons.person_add_outlined,
      );
    }

    final isMobile = AdminLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ManagementKpiRow(kpis: data.kpis),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Funnel stages'),
        const SizedBox(height: AksharaSpacing.s3),
        _FunnelStagesList(stages: data.funnelStages),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile)
          ManagementSegmentPanel(
            title: 'Source performance',
            segments: data.sourcePerformance,
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ManagementSegmentPanel(
                  title: 'Source performance',
                  segments: data.sourcePerformance,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AksharaSectionHeader(title: 'Recent conversions'),
                    const SizedBox(height: AksharaSpacing.s3),
                    _RecentConversionsSection(
                      conversions: data.recentConversions,
                    ),
                  ],
                ),
              ),
            ],
          ),
        if (isMobile) ...[
          const SizedBox(height: AksharaSpacing.s6),
          const AksharaSectionHeader(title: 'Recent conversions'),
          const SizedBox(height: AksharaSpacing.s3),
          _RecentConversionsSection(conversions: data.recentConversions),
        ],
        const SizedBox(height: AksharaSpacing.s6),
        OutlinedButton.icon(
          onPressed: () => context.go(data.admissionsReportsRoute),
          icon: const Icon(Icons.assessment_outlined),
          label: const Text('View admissions reports'),
        ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.aiInsight,
          actionLabel: 'Open reports',
          icon: Icons.auto_awesome_outlined,
          semanticLabelPrefix: 'AI admissions insight',
          onAction: () => context.go(data.admissionsReportsRoute),
        ),
      ],
    );
  }
}

class _FunnelStagesList extends StatelessWidget {
  const _FunnelStagesList({required this.stages});

  final List<ManagementFunnelStage> stages;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Admissions funnel, ${stages.length} stages',
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            children: [
              for (final stage in stages) ...[
                Semantics(
                  label:
                      '${stage.label}: ${stage.count} leads, ${stage.percent.toStringAsFixed(1)} percent',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(stage.label, style: text.bodyMedium),
                          ),
                          Text('${stage.count}', style: text.titleSmall),
                          const SizedBox(width: AksharaSpacing.s3),
                          Text(
                            '${stage.percent.toStringAsFixed(1)}%',
                            style: text.bodySmall.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AksharaSpacing.s1),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: stage.percent / 100,
                          minHeight: 8,
                          backgroundColor: colors.surfaceContainerHighest,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: AksharaSpacing.s3),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentConversionsSection extends StatelessWidget {
  const _RecentConversionsSection({required this.conversions});

  final List<ManagementRecentConversion> conversions;

  @override
  Widget build(BuildContext context) {
    if (conversions.isEmpty) {
      return const AksharaEmptyState(
        message: 'No recent conversions.',
        icon: Icons.swap_horiz_outlined,
      );
    }

    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final conversion in conversions) ...[
            _ConversionCard(conversion: conversion),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Recent conversions, ${conversions.length} items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 64,
            columns: const [
              DataColumn(label: Text('Lead')),
              DataColumn(label: Text('Class')),
              DataColumn(label: Text('Source')),
              DataColumn(label: Text('Counselor')),
              DataColumn(label: Text('Stage')),
              DataColumn(label: Text('Days')),
            ],
            rows: [
              for (final conversion in conversions)
                DataRow(
                  cells: [
                    DataCell(Text(conversion.leadName)),
                    DataCell(Text(conversion.classLabel)),
                    DataCell(Text(conversion.source)),
                    DataCell(Text(conversion.counselor)),
                    DataCell(Text(conversion.stage)),
                    DataCell(Text('${conversion.daysInPipeline}')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversionCard extends StatelessWidget {
  const _ConversionCard({required this.conversion});

  final ManagementRecentConversion conversion;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label:
          'Conversion: ${conversion.leadName}, class ${conversion.classLabel}, stage ${conversion.stage}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(conversion.leadName, style: text.titleSmall),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                'Class ${conversion.classLabel} · ${conversion.source}',
                style: text.bodyMedium,
              ),
              Text(
                '${conversion.counselor} · ${conversion.stage} · ${conversion.daysInPipeline}d',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
