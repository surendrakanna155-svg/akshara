import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_kpi_card.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';
import '../widgets/finance_kpi_row.dart';
import '../widgets/finance_module_scaffold.dart';
import '../widgets/finance_responsive_grid.dart';
import 'finance_defaulters_provider.dart';

/// FN-07 — Defaulters and aging analysis.
class FinanceDefaultersScreen extends ConsumerWidget {
  const FinanceDefaultersScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    '1–30d',
    '31–60d',
    '90+d',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(financeDefaultersViewStateProvider);
    final defaulters = ref.watch(financeFilteredDefaultersProvider);
    final filterIndex = ref.watch(financeDefaultersFilterProvider);

    return FinanceModuleScaffold(
      screen: FinanceScreen.defaulters,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(financeDefaultersFilterProvider.notifier).state = index,
      body: FinanceAsyncBody<DefaultersDashboardData>(
        state: viewState,
        loadingLabel: 'Loading defaulters',
        emptyMessage: 'No defaulter records for the selected filters.',
        emptyIcon: Icons.warning_amber_outlined,
        onRetry: () => retryFinanceFuture(ref, financeDefaultersFutureProvider),
        builder: (data) => _buildContent(context, data: data, defaulters: defaulters),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required DefaultersDashboardData data,
    required List<DefaulterRecord> defaulters,
  }) {
    final useCards = AdminLayout.useCardLayout(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinanceKpiRow(
          desktopColumns: 4,
          cardHeight: 100,
          kpis: data.kpis,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Aging buckets'),
        const SizedBox(height: AksharaSpacing.s3),
        Semantics(
          container: true,
          label: 'Aging bucket summary, ${data.agingBuckets.length} buckets',
          child: FinanceResponsiveGrid(
            desktopColumns: 5,
            tabletColumns: 3,
            mobileColumns: 2,
            children: [
              for (final bucket in data.agingBuckets)
                AksharaKpiCard(
                  value: bucket.totalAmount,
                  subtitle: bucket.label,
                  detail: '${bucket.studentCount} students',
                  icon: Icons.hourglass_bottom_outlined,
                  accent: _agingAccent(bucket.bucket),
                  style: AksharaKpiCardStyle.filled,
                  semanticLabel:
                      '${bucket.label}: ${bucket.totalAmount}, ${bucket.studentCount} students',
                ),
            ],
          ),
        ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Defaulters list'),
        const SizedBox(height: AksharaSpacing.s3),
        if (defaulters.isEmpty)
          const AksharaEmptyState(
            message: 'No defaulters match the selected aging filter.',
            icon: Icons.people_outline,
          )
        else if (useCards)
          Column(
            children: [
              for (final record in defaulters) ...[
                _DefaulterMobileCard(record: record),
                const SizedBox(height: AksharaSpacing.s3),
              ],
            ],
          )
        else
          _DefaultersTable(defaulters: defaulters),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.aiInsight,
          actionLabel: data.aiActionLabel,
          icon: Icons.auto_awesome_outlined,
          semanticLabelPrefix: 'AI defaulter risk insight',
          onAction: () => context.go(RouteNames.financeStudentAccounts),
        ),
      ],
    );
  }

  static KpiAccent _agingAccent(DefaulterAgingBucket bucket) => switch (bucket) {
        DefaulterAgingBucket.current => KpiAccent.neutral,
        DefaulterAgingBucket.days1to30 => KpiAccent.warning,
        DefaulterAgingBucket.days31to60 => KpiAccent.warning,
        DefaulterAgingBucket.days61to90 => KpiAccent.error,
        DefaulterAgingBucket.over90 => KpiAccent.error,
      };
}

class _DefaultersTable extends StatelessWidget {
  const _DefaultersTable({required this.defaulters});

  final List<DefaulterRecord> defaulters;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Defaulters list, ${defaulters.length} students',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 48,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 64,
          columns: const [
            DataColumn(label: Text('Student')),
            DataColumn(label: Text('Admission No.')),
            DataColumn(label: Text('Class')),
            DataColumn(label: Text('Overdue')),
            DataColumn(label: Text('Days')),
            DataColumn(label: Text('Bucket')),
            DataColumn(label: Text('Last contact')),
            DataColumn(label: Text('Collection %')),
          ],
          rows: [
            for (final record in defaulters)
              DataRow(
                cells: [
                  DataCell(Text(record.studentName)),
                  DataCell(Text(record.admissionNumber)),
                  DataCell(Text(record.classLabel)),
                  DataCell(Text(record.overdueAmount)),
                  DataCell(Text('${record.daysOverdue}')),
                  DataCell(_AgingBucketChip(bucket: record.bucket)),
                  DataCell(Text(record.lastContact)),
                  DataCell(Text('${record.collectionProbability}%')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DefaulterMobileCard extends StatelessWidget {
  const _DefaulterMobileCard({required this.record});

  final DefaulterRecord record;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(record.studentName, style: text.titleSmall),
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              '${record.admissionNumber} · Class ${record.classLabel}',
              style: text.bodySmall,
            ),
            Text(
              '${record.overdueAmount} · ${record.daysOverdue} days overdue',
              style: text.bodySmall,
            ),
            Text(
              'Last contact: ${record.lastContact}',
              style: text.bodySmall,
            ),
            const SizedBox(height: AksharaSpacing.s2),
            Row(
              children: [
                _AgingBucketChip(bucket: record.bucket),
                const SizedBox(width: AksharaSpacing.s2),
                AksharaStatusChip(
                  label: '${record.collectionProbability}% likely',
                  tone: record.collectionProbability >= 60
                      ? KpiAccent.success
                      : KpiAccent.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AgingBucketChip extends StatelessWidget {
  const _AgingBucketChip({required this.bucket});

  final DefaulterAgingBucket bucket;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (bucket) {
      DefaulterAgingBucket.current => ('Current', KpiAccent.neutral),
      DefaulterAgingBucket.days1to30 => ('1–30d', KpiAccent.warning),
      DefaulterAgingBucket.days31to60 => ('31–60d', KpiAccent.warning),
      DefaulterAgingBucket.days61to90 => ('61–90d', KpiAccent.error),
      DefaulterAgingBucket.over90 => ('90+d', KpiAccent.error),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}
