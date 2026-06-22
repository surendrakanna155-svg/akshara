import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../hr_models.dart';
import '../hr_providers.dart';
import '../hr_workflow_actions.dart';
import '../widgets/hr_module_scaffold.dart';
import '../widgets/hr_trend_chart.dart';

/// HR-06 — Payroll.
class HrPayrollScreen extends ConsumerWidget {
  const HrPayrollScreen({super.key});

  static const List<String> filterLabels = [
    'Current month',
    'Last month',
    'All runs',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(hrPayrollLoadingProvider);
    final isError = ref.watch(hrPayrollErrorProvider);
    final isEmpty = ref.watch(hrPayrollEmptyProvider);
    final data = ref.watch(hrPayrollProvider);
    final filterIndex = ref.watch(hrPayrollFilterProvider);

    return HrModuleScaffold(
      screen: HrScreen.payroll,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(hrPayrollFilterProvider.notifier).state = index,
      body: _buildBody(
        context,
        ref,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        data: data,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required HrPayrollData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading payroll'),
      );
    }

    if (isError) {
      return const AksharaErrorState(message: 'Unable to load payroll data.');
    }

    if (isEmpty || data == null) {
      return const AksharaEmptyState(
        message: 'No payroll runs for the selected period.',
        icon: Icons.payments_outlined,
      );
    }

    final isMobile = AdminLayout.isMobile(context);
    final chartHeight = isMobile ? 240.0 : 280.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: AksharaManageAction(
            permission: Permission.manageHr,
            child: FilledButton.icon(
              key: QaTestKeys.hrProcessPayrollButton,
              onPressed: () {
                final drafts = data.runs
                    .where((r) => r.status == HrPayrollStatus.draft);
                if (drafts.isEmpty) return;
                showProcessPayrollRunDialog(context, ref, run: drafts.first);
              },
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Process payroll'),
            ),
          ),
        ),
        const SizedBox(height: AksharaSpacing.s4),
        Wrap(
          spacing: AksharaSpacing.s3,
          runSpacing: AksharaSpacing.s3,
          children: [
            OutlinedButton.icon(
              key: QaTestKeys.hrPayrollExportPdfButton,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    key: QaTestKeys.hrPayrollExportSuccessSnackbar,
                    content: Text(
                      'Payroll summary export queued (${data.runs.length} runs)',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Export payroll summary PDF'),
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s4),
        const AksharaSectionHeader(title: 'Payroll runs'),
        const SizedBox(height: AksharaSpacing.s3),
        _PayrollRunsList(runs: data.runs),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Employee payroll entries'),
        const SizedBox(height: AksharaSpacing.s3),
        _PayrollEntriesTable(entries: data.entries),
        const SizedBox(height: AksharaSpacing.s6),
        HrTrendChart(
          title: 'Salary disbursement (₹ Cr)',
          points: data.salaryTrend,
          height: chartHeight,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.financeIntegrationNote,
          actionLabel: 'Open Finance',
          icon: Icons.account_balance_outlined,
          semanticLabelPrefix: 'Finance payroll integration',
          onAction: () => context.go(data.financeRoute),
        ),
      ],
    );
  }
}

class _PayrollRunsList extends StatelessWidget {
  const _PayrollRunsList({required this.runs});

  final List<HrPayrollRun> runs;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Payroll runs, ${runs.length} periods',
      child: Card(
        elevation: 0,
        child: Column(
          children: [
            for (var i = 0; i < runs.length; i++) ...[
              ListTile(
                title: Text(runs[i].period, style: text.titleSmall),
                subtitle: Text(
                  '${runs[i].employeeCount} employees · Net ${runs[i].netAmount}',
                  style: text.bodySmall,
                ),
                trailing: _PayrollStatusChip(status: runs[i].status),
              ),
              if (i < runs.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _PayrollEntriesTable extends StatelessWidget {
  const _PayrollEntriesTable({required this.entries});

  final List<HrPayrollEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final entry in entries) ...[
            _PayrollEntryCard(entry: entry),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Payroll entries table, ${entries.length} employees',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Employee')),
              DataColumn(label: Text('Department')),
              DataColumn(label: Text('Basic')),
              DataColumn(label: Text('Allowances')),
              DataColumn(label: Text('Deductions')),
              DataColumn(label: Text('Net pay')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final entry in entries)
                DataRow(
                  cells: [
                    DataCell(Text(entry.employeeName)),
                    DataCell(Text(entry.department.name)),
                    DataCell(Text(entry.basicPay)),
                    DataCell(Text(entry.allowances)),
                    DataCell(Text(entry.deductions)),
                    DataCell(Text(entry.netPay)),
                    DataCell(_PayrollStatusChip(status: entry.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayrollEntryCard extends StatelessWidget {
  const _PayrollEntryCard({required this.entry});

  final HrPayrollEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Payroll ${entry.employeeName}, net ${entry.netPay}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.employeeName, style: text.titleSmall),
              Text('Net ${entry.netPay}', style: text.bodySmall),
              const SizedBox(height: AksharaSpacing.s2),
              _PayrollStatusChip(status: entry.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayrollStatusChip extends StatelessWidget {
  const _PayrollStatusChip({required this.status});

  final HrPayrollStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      HrPayrollStatus.draft => ('Draft', KpiAccent.neutral),
      HrPayrollStatus.processed => ('Processed', KpiAccent.primary),
      HrPayrollStatus.paid => ('Paid', KpiAccent.success),
      HrPayrollStatus.onHold => ('On hold', KpiAccent.warning),
    };

    return AksharaStatusChip(label: label, tone: tone);
  }
}
