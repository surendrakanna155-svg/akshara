import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../core/widgets/whatsapp_contact_button.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_kpi_card.dart';
import '../../../shared/widgets/akshara_manage_action.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';
import '../recovery/finance_recovery_actions.dart';
import '../recovery/finance_recovery_provider.dart';
import '../widgets/finance_kpi_row.dart';
import '../widgets/finance_module_scaffold.dart';
import '../widgets/finance_responsive_grid.dart';
import 'finance_defaulters_provider.dart';

/// FN-07 — Defaulters, aging analysis, and fee-recovery CRM (FIN-R1..R5, FIN-8).
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
      filterTrailing: _DefaulterExportActions(defaulters: defaulters),
      body: FinanceAsyncBody<DefaultersDashboardData>(
        state: viewState,
        loadingLabel: 'Loading defaulters',
        emptyMessage: 'No defaulter records for the selected filters.',
        emptyIcon: Icons.warning_amber_outlined,
        onRetry: () => retryFinanceFuture(ref, financeDefaultersFutureProvider),
        builder: (data) =>
            _buildContent(context, data: data, defaulters: defaulters),
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
        // FIN-R1/R5 — recovery dashboard section.
        const _RecoverySection(),
        const SizedBox(height: AksharaSpacing.s6),
        // FIN-R3 — promise-to-pay worklist.
        const _PromiseWorklistSection(),
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

/// FIN-8 — class-wise dues + full defaulter list CSV export. Compact overflow
/// menu on mobile (keeps the filter bar within its fixed height); labeled
/// buttons on tablet/desktop.
class _DefaulterExportActions extends ConsumerWidget {
  const _DefaulterExportActions({required this.defaulters});

  final List<DefaulterRecord> defaulters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AdminLayout.isMobile(context)) {
      return PopupMenuButton<int>(
        icon: const Icon(Icons.download_outlined),
        tooltip: 'Export',
        onSelected: (value) {
          if (value == 0) {
            exportClassWiseDues(context, ref, defaulters: defaulters);
          } else {
            exportDefaulterList(context, ref, defaulters: defaulters);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem<int>(
            key: QaTestKeys.financeExportClassDuesButton,
            value: 0,
            child: Text('Export class-wise dues'),
          ),
          const PopupMenuItem<int>(
            value: 1,
            child: Text('Export list'),
          ),
        ],
      );
    }
    return Wrap(
      spacing: AksharaSpacing.s2,
      children: [
        OutlinedButton.icon(
          key: QaTestKeys.financeExportClassDuesButton,
          onPressed: () =>
              exportClassWiseDues(context, ref, defaulters: defaulters),
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Export class-wise dues'),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              exportDefaulterList(context, ref, defaulters: defaulters),
          icon: const Icon(Icons.list_alt_outlined, size: 18),
          label: const Text('Export list'),
        ),
      ],
    );
  }
}

/// FIN-R1/R5 — recovery KPIs and collector performance table.
class _RecoverySection extends ConsumerWidget {
  const _RecoverySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeRecoveryDashboardViewStateProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Recovery'),
        const SizedBox(height: AksharaSpacing.s3),
        FinanceAsyncBody<RecoveryDashboardData>(
          state: state,
          loadingLabel: 'Loading recovery dashboard',
          emptyMessage: 'No recovery activity yet.',
          emptyIcon: Icons.trending_up,
          onRetry: () =>
              retryFinanceFuture(ref, financeRecoveryDashboardFutureProvider),
          builder: (data) => _buildRecovery(context, data),
        ),
      ],
    );
  }

  Widget _buildRecovery(BuildContext context, RecoveryDashboardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinanceResponsiveGrid(
          desktopColumns: 5,
          tabletColumns: 3,
          mobileColumns: 2,
          children: [
            AksharaKpiCard(
              value: '${data.ptpPending}',
              subtitle: 'PTP pending',
              icon: Icons.pending_actions_outlined,
              accent: KpiAccent.warning,
              style: AksharaKpiCardStyle.filled,
            ),
            AksharaKpiCard(
              value: '${data.ptpDueToday}',
              subtitle: 'PTP due today',
              icon: Icons.today_outlined,
              accent: KpiAccent.primary,
              style: AksharaKpiCardStyle.filled,
            ),
            AksharaKpiCard(
              value: '${data.ptpOverdue}',
              subtitle: 'PTP overdue',
              icon: Icons.warning_amber_outlined,
              accent: KpiAccent.error,
              style: AksharaKpiCardStyle.filled,
            ),
            AksharaKpiCard(
              value: '${data.contactsThisMonth}',
              subtitle: 'Contacts this month',
              icon: Icons.phone_in_talk_outlined,
              accent: KpiAccent.neutral,
              style: AksharaKpiCardStyle.filled,
            ),
            AksharaKpiCard(
              value: '₹${data.recoveredThisMonth}',
              subtitle: 'Recovered this month',
              icon: Icons.savings_outlined,
              accent: KpiAccent.success,
              style: AksharaKpiCardStyle.filled,
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s4),
        AksharaSectionHeader(
          title: 'Collector performance · ${data.period}',
        ),
        const SizedBox(height: AksharaSpacing.s2),
        if (data.collectorPerformance.isEmpty)
          const AksharaEmptyState(
            message: 'No collector activity for this period.',
            icon: Icons.groups_outlined,
          )
        else
          Semantics(
            container: true,
            label:
                'Collector performance, ${data.collectorPerformance.length} collectors',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 44,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(label: Text('Collector')),
                  DataColumn(label: Text('Contacts')),
                  DataColumn(label: Text('Promises')),
                  DataColumn(label: Text('Collections')),
                  DataColumn(label: Text('Recovered')),
                ],
                rows: [
                  for (final c in data.collectorPerformance)
                    DataRow(cells: [
                      DataCell(Text(c.collectorName)),
                      DataCell(Text('${c.contactsMade}')),
                      DataCell(Text('${c.promisesObtained}')),
                      DataCell(Text('${c.collectionsCount}')),
                      DataCell(Text('₹${c.amountRecovered}')),
                    ]),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// FIN-R3 — promise-to-pay worklist with kept/broken/cancel actions.
class _PromiseWorklistSection extends ConsumerWidget {
  const _PromiseWorklistSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financePromisesViewStateProvider);
    final filter = ref.watch(financePromiseStatusFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Promises to pay'),
        const SizedBox(height: AksharaSpacing.s2),
        Wrap(
          spacing: AksharaSpacing.s2,
          children: [
            _PromiseFilterChip(
              label: 'Pending',
              value: PromiseToPayStatus.pending,
              selected: filter == PromiseToPayStatus.pending,
            ),
            _PromiseFilterChip(
              label: 'Kept',
              value: PromiseToPayStatus.kept,
              selected: filter == PromiseToPayStatus.kept,
            ),
            _PromiseFilterChip(
              label: 'Broken',
              value: PromiseToPayStatus.broken,
              selected: filter == PromiseToPayStatus.broken,
            ),
            _PromiseFilterChip(
              label: 'All',
              value: null,
              selected: filter == null,
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s3),
        FinanceAsyncBody<List<PromiseToPay>>(
          state: state,
          loadingLabel: 'Loading promises',
          emptyMessage: 'No promises to pay for this filter.',
          emptyIcon: Icons.event_available_outlined,
          onRetry: () => retryFinanceFuture(ref, financePromisesFutureProvider),
          builder: (promises) => Column(
            children: [
              for (final promise in promises) ...[
                _PromiseTile(promise: promise),
                const SizedBox(height: AksharaSpacing.s2),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PromiseFilterChip extends ConsumerWidget {
  const _PromiseFilterChip({
    required this.label,
    required this.value,
    required this.selected,
  });

  final String label;
  final PromiseToPayStatus? value;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => ref
          .read(financePromiseStatusFilterProvider.notifier)
          .state = value,
    );
  }
}

class _PromiseTile extends ConsumerWidget {
  const _PromiseTile({required this.promise});

  final PromiseToPay promise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.aksharaText;
    final isPending = promise.status == PromiseToPayStatus.pending;

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
            Row(
              children: [
                Expanded(
                  child: Text(promise.studentName, style: text.titleSmall),
                ),
                _PromiseStatusChip(status: promise.status),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              '${promise.amount} · by ${promise.promiseDate}',
              style: text.bodySmall,
            ),
            if (promise.notes.isNotEmpty)
              Text(promise.notes, style: text.bodySmall),
            if (isPending) ...[
              const SizedBox(height: AksharaSpacing.s2),
              AksharaManageAction(
                permission: Permission.manageFinance,
                child: Wrap(
                  spacing: AksharaSpacing.s2,
                  children: [
                    FilledButton.tonal(
                      key: QaTestKeys.financeResolvePromiseButton(promise.id),
                      onPressed: () => resolvePromise(
                        context,
                        ref,
                        promise: promise,
                        status: PromiseToPayStatus.kept,
                      ),
                      child: const Text('Kept'),
                    ),
                    OutlinedButton(
                      onPressed: () => resolvePromise(
                        context,
                        ref,
                        promise: promise,
                        status: PromiseToPayStatus.broken,
                      ),
                      child: const Text('Broken'),
                    ),
                    TextButton(
                      onPressed: () => resolvePromise(
                        context,
                        ref,
                        promise: promise,
                        status: PromiseToPayStatus.cancelled,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PromiseStatusChip extends StatelessWidget {
  const _PromiseStatusChip({required this.status});

  final PromiseToPayStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      PromiseToPayStatus.pending => ('Pending', KpiAccent.warning),
      PromiseToPayStatus.kept => ('Kept', KpiAccent.success),
      PromiseToPayStatus.broken => ('Broken', KpiAccent.error),
      PromiseToPayStatus.cancelled => ('Cancelled', KpiAccent.neutral),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}

class _DefaultersTable extends ConsumerWidget {
  const _DefaultersTable({required this.defaulters});

  final List<DefaulterRecord> defaulters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            DataColumn(label: Text('Actions')),
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
                  DataCell(_DefaulterRowActions(record: record)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Per-row recovery actions: WhatsApp, log contact, promise to pay, history.
class _DefaulterRowActions extends ConsumerWidget {
  const _DefaulterRowActions({required this.record});

  final DefaulterRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WhatsAppContactButton(
          phone: record.guardianPhone,
          style: WhatsAppButtonStyle.icon,
          label: 'WhatsApp ${record.studentName}\'s guardian',
          message: _defaulterMessage(record),
          unavailableMessage: 'No guardian number on file.',
        ),
        AksharaManageAction(
          permission: Permission.manageFinance,
          child: IconButton(
            key: QaTestKeys.financeLogContactButton(record.id),
            tooltip: 'Log contact',
            icon: const Icon(Icons.phone_in_talk_outlined),
            onPressed: () =>
                showLogRecoveryContactDialog(context, ref, record: record),
          ),
        ),
        AksharaManageAction(
          permission: Permission.manageFinance,
          child: IconButton(
            key: QaTestKeys.financePromiseToPayButton(record.id),
            tooltip: 'Promise to pay',
            icon: const Icon(Icons.event_available_outlined),
            onPressed: () =>
                showCreatePromiseToPayDialog(context, ref, record: record),
          ),
        ),
        IconButton(
          tooltip: 'Contact history',
          icon: const Icon(Icons.history_outlined),
          onPressed: () => showContactHistorySheet(context, record: record),
        ),
      ],
    );
  }
}

class _DefaulterMobileCard extends ConsumerWidget {
  const _DefaulterMobileCard({required this.record});

  final DefaulterRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            const SizedBox(height: AksharaSpacing.s2),
            _DefaulterRowActions(record: record),
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

/// FIN-R4 — shows the defaulter's already-populated contact history in a sheet.
void showContactHistorySheet(
  BuildContext context, {
  required DefaulterRecord record,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final text = context.aksharaText;
      final colors = context.colors;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AksharaSpacing.s5,
            AksharaSpacing.s2,
            AksharaSpacing.s5,
            AksharaSpacing.s5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Contact history — ${record.studentName}',
                  style: text.titleMedium),
              const SizedBox(height: AksharaSpacing.s1),
              Text('Last contact: ${record.lastContact}', style: text.bodySmall),
              const SizedBox(height: AksharaSpacing.s3),
              if (record.contactHistory.isEmpty)
                const AksharaEmptyState(
                  message: 'No contact attempts logged yet.',
                  icon: Icons.history_outlined,
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: record.contactHistory.length,
                    separatorBuilder: (_, __) => Divider(
                      color: colors.outlineVariant,
                      height: AksharaSpacing.s4,
                    ),
                    itemBuilder: (context, index) {
                      final entry = record.contactHistory[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${entry.channel} · ${entry.outcome}',
                              style: text.titleSmall),
                          Text(entry.timestamp, style: text.bodySmall),
                          if (entry.notes.isNotEmpty)
                            Text(entry.notes, style: text.bodySmall),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

String _defaulterMessage(DefaulterRecord record) =>
    'Hello, this is a gentle fee reminder from the school regarding '
    '${record.studentName} (${record.admissionNumber}). The pending amount is '
    '${record.overdueAmount}. ';
