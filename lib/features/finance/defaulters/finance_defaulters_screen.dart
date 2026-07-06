import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_text.dart';
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
import '../finance_requests.dart';
import '../recovery/finance_recovery_actions.dart';
import '../recovery/finance_recovery_provider.dart';
import '../widgets/finance_kpi_row.dart';
import '../widgets/finance_module_scaffold.dart';
import '../widgets/finance_responsive_grid.dart';
import 'finance_defaulters_provider.dart';
import 'finance_head_wise_dues_provider.dart';

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
        // FIN-R2 — telecaller call queue (who to call next).
        const _CallQueueSection(),
        const SizedBox(height: AksharaSpacing.s6),
        // FIN-R3 — promise-to-pay worklist.
        const _PromiseWorklistSection(),
        const SizedBox(height: AksharaSpacing.s6),
        // FIN-9 — head-wise outstanding dues.
        const _HeadWiseDuesSection(),
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
/// FIN-9 — per-fee-head outstanding dues across open invoices. Async-loaded via
/// [financeHeadWiseDuesFutureProvider]; hides itself while loading / on error /
/// when there are no dues.
class _HeadWiseDuesSection extends ConsumerWidget {
  const _HeadWiseDuesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(financeHeadWiseDuesFutureProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (dues) {
        if (dues.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AksharaSectionHeader(title: 'Head-wise dues'),
            const SizedBox(height: AksharaSpacing.s3),
            Semantics(
              container: true,
              label: 'Head-wise dues, ${dues.length} fee heads',
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 44,
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 56,
                  columns: const [
                    DataColumn(label: Text('Fee head')),
                    DataColumn(label: Text('Outstanding')),
                  ],
                  rows: [
                    for (final due in dues)
                      DataRow(cells: [
                        DataCell(Text(due.label.isNotEmpty
                            ? due.label
                            : due.category)),
                        DataCell(Text('₹${due.dues}')),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

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
          _CollectorPerformanceTable(data: data),
      ],
    );
  }
}

/// FIN-R5/R6 — per-collector performance with monthly collection targets +
/// attainment. A principal (manageFinance) can set each collector's target;
/// every viewer sees the target and how close each collector is to it.
class _CollectorPerformanceTable extends ConsumerWidget {
  const _CollectorPerformanceTable({required this.data});

  final RecoveryDashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
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
            DataColumn(label: Text('Target')),
            DataColumn(label: Text('Attainment')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final c in data.collectorPerformance)
              DataRow(cells: [
                DataCell(Text(c.collectorName)),
                DataCell(Text('${c.contactsMade}')),
                DataCell(Text('${c.promisesObtained}')),
                DataCell(Text('${c.collectionsCount}')),
                DataCell(Text('₹${c.amountRecovered}')),
                DataCell(Text(c.target != null ? '₹${c.target}' : '—')),
                DataCell(_AttainmentChip(pct: c.attainmentPct)),
                DataCell(
                  AksharaManageAction(
                    permission: Permission.manageFinance,
                    child: TextButton(
                      key: QaTestKeys.financeSetCollectionTargetButton(
                        c.collectorId,
                      ),
                      onPressed: () => _setTarget(context, ref, c),
                      child: Text(c.target != null ? 'Edit target' : 'Set target'),
                    ),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  Future<void> _setTarget(
    BuildContext context,
    WidgetRef ref,
    CollectorPerformance collector,
  ) async {
    final amount = await _showSetTargetDialog(context, collector);
    if (amount == null || !context.mounted) return;
    final result =
        await ref.read(setCollectionTargetProvider.notifier).execute(
              SetCollectionTargetRequest(
                collectorUserId: collector.collectorId,
                periodMonth: data.period,
                target: amount,
              ),
            );
    if (!context.mounted) return;
    if (result == null) {
      final failure = ref.read(setCollectionTargetProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failure != null
                ? aksharaErrorMessage(failure)
                : 'Could not set the target. Please try again.',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: QaTestKeys.financeSetCollectionTargetSuccessSnackbar,
        content: Text('Collection target saved.'),
      ),
    );
  }
}

/// Attainment% as a tone-coded chip: ≥100 success, ≥60 warning, else error;
/// '—' when no target is set.
class _AttainmentChip extends StatelessWidget {
  const _AttainmentChip({required this.pct});

  final int? pct;

  @override
  Widget build(BuildContext context) {
    if (pct == null) return const Text('—');
    final tone = pct! >= 100
        ? KpiAccent.success
        : (pct! >= 60 ? KpiAccent.warning : KpiAccent.error);
    return AksharaStatusChip(label: '$pct%', tone: tone);
  }
}

Future<String?> _showSetTargetDialog(
  BuildContext context,
  CollectorPerformance collector,
) {
  final controller = TextEditingController(text: collector.target ?? '');
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Target · ${collector.collectorName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Monthly collection target. Recovered so far: '
              '₹${collector.amountRecovered}.',
            ),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              key: QaTestKeys.financeCollectionTargetField,
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target amount (₹)',
                hintText: 'e.g. 100000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.financeCollectionTargetSaveButton,
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.of(context).pop(value);
            },
            child: const Text('Save target'),
          ),
        ],
      );
    },
  );
}

/// FIN-R2 — the telecaller call queue: defaulters in server-ranked call order,
/// each showing WHY it's prioritised, with one-tap WhatsApp / log-contact /
/// promise-to-pay. Rides the same recovery dialogs + repos as the list below;
/// logging a contact or a promise re-ranks the queue live.
class _CallQueueSection extends ConsumerWidget {
  const _CallQueueSection();

  static const int _maxVisible = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeCallQueueViewStateProvider);
    return Column(
      key: QaTestKeys.financeCallQueueSection,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Call queue'),
        const SizedBox(height: AksharaSpacing.s3),
        FinanceAsyncBody<List<CallQueueEntry>>(
          state: state,
          loadingLabel: 'Loading call queue',
          emptyMessage: 'No one to call — collections are current.',
          emptyIcon: Icons.phone_disabled_outlined,
          onRetry: () => retryFinanceFuture(ref, financeCallQueueFutureProvider),
          builder: (entries) {
            final visible = entries.take(_maxVisible).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in visible) _CallQueueTile(entry: entry),
                if (entries.length > visible.length)
                  Padding(
                    padding: const EdgeInsets.only(top: AksharaSpacing.s2),
                    child: Text(
                      '+${entries.length - visible.length} more in the queue',
                      style: context.aksharaText.bodySmall.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

DefaulterAgingBucket _bucketForDays(int days) {
  if (days <= 0) return DefaulterAgingBucket.current;
  if (days <= 30) return DefaulterAgingBucket.days1to30;
  if (days <= 60) return DefaulterAgingBucket.days31to60;
  if (days <= 90) return DefaulterAgingBucket.days61to90;
  return DefaulterAgingBucket.over90;
}

KpiAccent _reasonTone(int priority) => switch (priority) {
      0 => KpiAccent.error, // promise broken
      1 => KpiAccent.warning, // promise due
      2 => KpiAccent.warning, // not yet contacted
      3 => KpiAccent.primary, // stale contact
      _ => KpiAccent.neutral,
    };

class _CallQueueTile extends ConsumerWidget {
  const _CallQueueTile({required this.entry});

  final CallQueueEntry entry;

  /// Adapts the queue entry to the [DefaulterRecord] the shared recovery
  /// dialogs prefill from (student, fee account, outstanding amount).
  DefaulterRecord get _asRecord => DefaulterRecord(
        id: entry.studentId,
        studentName: entry.studentName,
        admissionNumber: entry.admissionNumber,
        classLabel: entry.classLabel,
        overdueAmount: entry.outstanding,
        daysOverdue: entry.daysOverdue,
        bucket: _bucketForDays(entry.daysOverdue),
        lastContact: entry.lastContact,
        collectionProbability: 0,
        contactHistory: const [],
        feeAccountId: entry.feeAccountId,
        guardianPhone: entry.guardianPhone,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.aksharaText;
    final record = _asRecord;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AksharaSpacing.s2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${entry.studentName} · ${entry.classLabel}',
              style: text.titleSmall,
            ),
            const SizedBox(height: AksharaSpacing.s1),
            Align(
              alignment: Alignment.centerLeft,
              child: AksharaStatusChip(
                label: entry.reason,
                tone: _reasonTone(entry.priority),
              ),
            ),
            const SizedBox(height: AksharaSpacing.s1),
            Text(
              '₹${entry.outstanding} · ${entry.daysOverdue} days overdue',
              style: text.bodySmall,
            ),
            Text(
              entry.guardianPhone.isEmpty
                  ? 'No guardian number on file'
                  : 'Guardian: ${entry.guardianPhone}',
              style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: AksharaSpacing.s2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                WhatsAppContactButton(
                  phone: entry.guardianPhone,
                  style: WhatsAppButtonStyle.icon,
                  label: 'WhatsApp ${entry.studentName}\'s guardian',
                  message: _defaulterMessage(record),
                  unavailableMessage: 'No guardian number on file.',
                ),
                AksharaManageAction(
                  permission: Permission.manageFinance,
                  child: IconButton(
                    key: QaTestKeys.financeCallQueueLogButton(entry.studentId),
                    tooltip: 'Log contact',
                    icon: const Icon(Icons.phone_in_talk_outlined),
                    onPressed: () => showLogRecoveryContactDialog(
                      context,
                      ref,
                      record: record,
                    ),
                  ),
                ),
                AksharaManageAction(
                  permission: Permission.manageFinance,
                  child: IconButton(
                    key:
                        QaTestKeys.financeCallQueuePromiseButton(entry.studentId),
                    tooltip: 'Promise to pay',
                    icon: const Icon(Icons.event_available_outlined),
                    onPressed: () => showCreatePromiseToPayDialog(
                      context,
                      ref,
                      record: record,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

/// FIN-R4 — shows the defaulter's contact history in a sheet. Reads the LIVE
/// per-student contact log (`financeStudentContactsFutureProvider`) so a contact
/// logged this session appears immediately; falls back to the record's embedded
/// history while the live list loads or on error.
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
          child: Consumer(
            builder: (context, ref, _) {
              final live =
                  ref.watch(financeStudentContactsFutureProvider(record.id));
              // Prefer the live log when it has rows; otherwise keep the
              // embedded history (loading / error / genuinely empty live list).
              final entries = live.maybeWhen(
                data: (contacts) => contacts.isEmpty
                    ? record.contactHistory
                    : [
                        for (final c in contacts)
                          ContactHistoryEntry(
                            id: c.id,
                            timestamp: c.timestamp,
                            channel: c.channel,
                            outcome: c.outcome,
                            notes: c.notes,
                          ),
                      ],
                orElse: () => record.contactHistory,
              );
              final lastContact = entries.isNotEmpty
                  ? entries.first.timestamp
                  : record.lastContact;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contact history — ${record.studentName}',
                      style: text.titleMedium),
                  const SizedBox(height: AksharaSpacing.s1),
                  Text('Last contact: $lastContact', style: text.bodySmall),
                  const SizedBox(height: AksharaSpacing.s3),
                  if (entries.isEmpty)
                    const AksharaEmptyState(
                      message: 'No contact attempts logged yet.',
                      icon: Icons.history_outlined,
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => Divider(
                          color: colors.outlineVariant,
                          height: AksharaSpacing.s4,
                        ),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
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
              );
            },
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
