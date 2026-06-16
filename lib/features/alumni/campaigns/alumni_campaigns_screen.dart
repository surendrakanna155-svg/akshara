import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../alumni_models.dart';
import '../alumni_providers.dart';
import '../widgets/alumni_module_scaffold.dart';

/// AL-06 — Campaigns.
class AlumniCampaignsScreen extends ConsumerWidget {
  const AlumniCampaignsScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Active',
    'Draft',
    'Completed',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(alumniCampaignsLoadingProvider);
    final isError = ref.watch(alumniCampaignsErrorProvider);
    final isEmpty = ref.watch(alumniCampaignsEmptyProvider);
    final campaigns = ref.watch(alumniFilteredCampaignsProvider);
    final filterIndex = ref.watch(alumniCampaignsFilterProvider);
    final pageResult = ref.watch(alumniCampaignsPageResultProvider);

    return AlumniModuleScaffold(
      screen: AlumniScreen.campaigns,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(alumniCampaignsFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageAlumni,
        child: FilledButton.icon(
          onPressed: () => showAksharaOperationalPreviewSnackBar(context, action: 'Create campaign'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New campaign'),
        ),
      ),
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        campaigns: campaigns,
        pageResult: pageResult,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<AlumniCampaign> campaigns,
    required PaginatedResult<AlumniCampaign>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading alumni campaigns'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load alumni campaigns.',
      );
    }

    if (isEmpty || campaigns.isEmpty) {
      return const AksharaEmptyState(
        message: 'No campaigns match the selected filters.',
        icon: Icons.campaign_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Fundraising campaigns'),
        const SizedBox(height: AksharaSpacing.s3),
        _CampaignsTable(campaigns: campaigns),
        AksharaPaginatedListFooter<AlumniCampaign>(
          result: pageResult,
          pageProvider: alumniCampaignsPageProvider,
        ),
      ],
    );
  }
}

class _CampaignsTable extends StatelessWidget {
  const _CampaignsTable({required this.campaigns});

  final List<AlumniCampaign> campaigns;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final campaign in campaigns) ...[
            _CampaignCard(campaign: campaign),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Campaigns table, ${campaigns.length} campaigns',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Campaign')),
              DataColumn(label: Text('Goal')),
              DataColumn(label: Text('Raised')),
              DataColumn(label: Text('Donors')),
              DataColumn(label: Text('Deadline')),
              DataColumn(label: Text('GL Code')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final campaign in campaigns)
                DataRow(
                  cells: [
                    DataCell(Text(campaign.name)),
                    DataCell(Text(campaign.goalAmount)),
                    DataCell(Text(campaign.raisedAmount)),
                    DataCell(Text('${campaign.donorCount}')),
                    DataCell(Text(campaign.deadline)),
                    DataCell(Text(campaign.financeAccountCode)),
                    DataCell(_CampaignStatusChip(status: campaign.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign});

  final AlumniCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return Semantics(
      label: 'Campaign ${campaign.name}, raised ${campaign.raisedAmount}',
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
                    child: Text(campaign.name, style: text.titleSmall),
                  ),
                  _CampaignStatusChip(status: campaign.status),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                '${campaign.raisedAmount} / ${campaign.goalAmount} · ${campaign.donorCount} donors',
                style: text.bodyMedium,
              ),
              Text(
                'Deadline ${campaign.deadline} · ${campaign.financeAccountCode}',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampaignStatusChip extends StatelessWidget {
  const _CampaignStatusChip({required this.status});

  final AlumniCampaignStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      AlumniCampaignStatus.active => ('Active', KpiAccent.success),
      AlumniCampaignStatus.draft => ('Draft', KpiAccent.warning),
      AlumniCampaignStatus.completed => ('Completed', KpiAccent.neutral),
      AlumniCampaignStatus.paused => ('Paused', KpiAccent.error),
    };

    return AksharaStatusChip(label: label, tone: tone);
  }
}
