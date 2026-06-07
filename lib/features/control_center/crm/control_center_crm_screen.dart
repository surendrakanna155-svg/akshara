import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/permissions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../control_center_models.dart';
import '../control_center_providers.dart';
import '../widgets/control_center_module_scaffold.dart';
import '../widgets/control_center_segment_panel.dart';

/// ACC-05 — Sales CRM (school-as-customer pipeline).
class ControlCenterCrmScreen extends ConsumerWidget {
  const ControlCenterCrmScreen({super.key});

  static const List<String> filterLabels = [
    'All stages',
    'Demo',
    'Proposal',
    'Won',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(controlCenterCrmLoadingProvider);
    final isError = ref.watch(controlCenterCrmErrorProvider);
    final data = ref.watch(controlCenterCrmProvider);
    final filterIndex = ref.watch(controlCenterCrmFilterProvider);

    return ControlCenterModuleScaffold(
      screen: ControlCenterScreen.crm,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(controlCenterCrmFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageControlCenter,
        child: FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New lead'),
        ),
      ),
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
    required ControlCenterCrmData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading CRM pipeline'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load sales CRM pipeline.',
      );
    }

    if (data == null) {
      return const AksharaErrorState(
        message: 'CRM pipeline data is not available.',
      );
    }

    final text = context.aksharaText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Sales pipeline'),
        Text(
          'Pipeline ₹${data.pipelineValueLakhs}L · Win rate ${data.winRatePercent}%',
          style: text.bodyMedium,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        ControlCenterSegmentPanel(
          title: 'Stage distribution',
          segments: data.stageDistribution,
          height: 220,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Active deals'),
        const SizedBox(height: AksharaSpacing.s3),
        if (AdminLayout.isMobile(context))
          Column(
            children: [
              for (final deal in data.deals) ...[
                _DealCard(deal: deal),
                const SizedBox(height: AksharaSpacing.s3),
              ],
            ],
          )
        else
          _DealsTable(deals: data.deals),
      ],
    );
  }
}

class _DealsTable extends StatelessWidget {
  const _DealsTable({required this.deals});

  final List<CrmDeal> deals;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'CRM deals table, ${deals.length} deals',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Deal')),
              DataColumn(label: Text('School')),
              DataColumn(label: Text('Contact')),
              DataColumn(label: Text('Stage')),
              DataColumn(label: Text('Est. MRR')),
              DataColumn(label: Text('Owner')),
            ],
            rows: [
              for (final deal in deals)
                DataRow(
                  cells: [
                    DataCell(Text(deal.id)),
                    DataCell(Text(deal.schoolName)),
                    DataCell(Text(deal.contactName)),
                    DataCell(_CrmStageChip(stage: deal.stage)),
                    DataCell(Text('₹${deal.estimatedMrrLakhs}L')),
                    DataCell(Text(deal.owner)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({required this.deal});

  final CrmDeal deal;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(deal.schoolName, style: text.titleSmall),
            Text('${deal.contactName} · ${deal.owner}', style: text.bodyMedium),
            const SizedBox(height: AksharaSpacing.s2),
            _CrmStageChip(stage: deal.stage),
          ],
        ),
      ),
    );
  }
}

class _CrmStageChip extends StatelessWidget {
  const _CrmStageChip({required this.stage});

  final CrmPipelineStage stage;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (stage) {
      CrmPipelineStage.lead => ('Lead', KpiAccent.neutral),
      CrmPipelineStage.contacted => ('Contacted', KpiAccent.primary),
      CrmPipelineStage.demo => ('Demo', KpiAccent.primary),
      CrmPipelineStage.proposal => ('Proposal', KpiAccent.warning),
      CrmPipelineStage.negotiation => ('Negotiation', KpiAccent.warning),
      CrmPipelineStage.won => ('Won', KpiAccent.success),
      CrmPipelineStage.lost => ('Lost', KpiAccent.error),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'CRM stage: $label',
    );
  }
}
