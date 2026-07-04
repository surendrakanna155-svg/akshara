import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../hr_models.dart';
import '../hr_providers.dart';
import '../hr_workflow_actions.dart';
import '../hr_report_models.dart';
import '../reports/hr_export_providers.dart';
import '../reports/hr_report_exporters.dart';
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
      // A fresh school still needs the engine entry points: define salary
      // structures → generate the first draft run (MOD-2).
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PayrollManageActions(data: null),
          SizedBox(height: AksharaSpacing.s4),
          AksharaEmptyState(
            message: 'No payroll runs for the selected period.',
            icon: Icons.payments_outlined,
          ),
        ],
      );
    }

    final isMobile = AdminLayout.isMobile(context);
    final chartHeight = isMobile ? 240.0 : 280.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PayrollManageActions(data: data),
        const SizedBox(height: AksharaSpacing.s4),
        _PayrollExportBar(runs: data.runs),
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

/// MOD-2 — the payroll engine's manage actions: define salary structures,
/// generate a draft run from them, then process the draft. All three are
/// manageHr-gated; [data] is null on the empty state (no runs yet), where
/// Process payroll is disabled because there is no draft to process.
class _PayrollManageActions extends ConsumerWidget {
  const _PayrollManageActions({required this.data});

  final HrPayrollData? data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = (data?.runs ?? const <HrPayrollRun>[])
        .where((r) => r.status == HrPayrollStatus.draft)
        .toList();

    return AksharaManageAction(
      permission: Permission.manageHr,
      child: Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          spacing: AksharaSpacing.s3,
          runSpacing: AksharaSpacing.s3,
          children: [
            OutlinedButton.icon(
              key: QaTestKeys.hrSalaryStructureButton,
              onPressed: () => showUpsertSalaryStructureDialog(context, ref),
              icon: const Icon(Icons.request_quote_outlined, size: 18),
              label: const Text('Salary structure'),
            ),
            OutlinedButton.icon(
              key: QaTestKeys.hrGeneratePayrollRunButton,
              onPressed: () => showGeneratePayrollRunDialog(context, ref),
              icon: const Icon(Icons.auto_mode, size: 18),
              label: const Text('Generate run'),
            ),
            FilledButton.icon(
              key: QaTestKeys.hrProcessPayrollButton,
              onPressed: drafts.isEmpty
                  ? null
                  : () => showProcessPayrollRunDialog(
                        context,
                        ref,
                        run: drafts.first,
                      ),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Process payroll'),
            ),
          ],
        ),
      ),
    );
  }
}

/// HR-1 salary register + HR-2 payslip exports (replaces the old stub snackbar).
/// Both derive from the selected payroll run and ride the shared XCT-1 grid
/// export service (CSV + PDF). Visible on the already viewHr-gated HR payroll
/// screen; a fresh school with no runs shows nothing to export.
class _PayrollExportBar extends ConsumerWidget {
  const _PayrollExportBar({required this.runs});

  final List<HrPayrollRun> runs;

  /// Prefers a processed/paid run (real salary lines), else the first run.
  HrPayrollRun? get _exportRun {
    if (runs.isEmpty) return null;
    final processed = runs.where((r) =>
        r.status == HrPayrollStatus.processed ||
        r.status == HrPayrollStatus.paid);
    return processed.isNotEmpty ? processed.first : runs.first;
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(HrReportExporters exporters) action,
    String successLabel,
  ) async {
    final run = _exportRun;
    if (run == null) return;
    final exporters =
        HrReportExporters(ref.read(aksharaReportExportServiceProvider));
    try {
      await action(exporters);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.hrReportExportSuccessSnackbar,
          content: Text(successLabel),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to build the export.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = _exportRun;
    if (run == null) return const SizedBox.shrink();
    return Semantics(
      label: 'Payroll report export actions',
      child: Wrap(
        spacing: AksharaSpacing.s3,
        runSpacing: AksharaSpacing.s3,
        children: [
          OutlinedButton.icon(
            key: QaTestKeys.hrSalaryRegisterExportButton,
            onPressed: () => _run(
              context,
              ref,
              (e) async {
                final register = await ref.read(
                  hrSalaryRegisterProvider(run.id).future,
                );
                await e.shareSalaryRegisterPdf(register);
              },
              'Salary register (${run.period}) PDF ready',
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Salary register PDF'),
          ),
          OutlinedButton.icon(
            onPressed: () => _run(
              context,
              ref,
              (e) async {
                final register = await ref.read(
                  hrSalaryRegisterProvider(run.id).future,
                );
                await e.shareSalaryRegisterCsv(register);
              },
              'Salary register (${run.period}) Excel CSV ready',
            ),
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Salary register Excel'),
          ),
          OutlinedButton.icon(
            key: QaTestKeys.hrPayslipsExportButton,
            onPressed: () => _run(
              context,
              ref,
              (e) async {
                final bundle =
                    await ref.read(hrPayslipsProvider(run.id).future);
                await e.sharePayslipsBundlePdf(bundle);
              },
              'Payslip bundle (${run.period}) PDF ready',
            ),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Payslips PDF'),
          ),
          OutlinedButton.icon(
            onPressed: () => _run(
              context,
              ref,
              (e) async {
                final bundle =
                    await ref.read(hrPayslipsProvider(run.id).future);
                await e.sharePayslipsCsv(bundle);
              },
              'Payslips (${run.period}) Excel CSV ready',
            ),
            icon: const Icon(Icons.table_view_outlined),
            label: const Text('Payslips Excel'),
          ),
          // HR-2 — individual per-employee payslip PDFs (distinct from the
          // all-employees bundle): pick an employee, download their own slip.
          OutlinedButton.icon(
            key: QaTestKeys.hrIndividualPayslipsButton,
            onPressed: () => _showIndividualPayslips(context, ref, run),
            icon: const Icon(Icons.badge_outlined),
            label: const Text('Individual payslips'),
          ),
        ],
      ),
    );
  }

  Future<void> _showIndividualPayslips(
    BuildContext context,
    WidgetRef ref,
    HrPayrollRun run,
  ) async {
    HrPayslipBundle bundle;
    try {
      bundle = await ref.read(hrPayslipsProvider(run.id).future);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load payslips.')),
      );
      return;
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _IndividualPayslipSheet(bundle: bundle),
    );
  }
}

/// HR-2 — a picker of the run's employees; each downloads its own payslip PDF.
class _IndividualPayslipSheet extends ConsumerWidget {
  const _IndividualPayslipSheet({required this.bundle});

  final HrPayslipBundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            Text('Individual payslips · ${bundle.period}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AksharaSpacing.s3),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: bundle.payslips.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final p = bundle.payslips[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${p.name} · ${p.code}'),
                    subtitle: Text(
                      '${p.dept} · Net ${p.netPay.toStringAsFixed(0)}',
                    ),
                    trailing: IconButton(
                      key: QaTestKeys.hrIndividualPayslipDownload(p.code),
                      tooltip: 'Download payslip',
                      icon: const Icon(Icons.download_outlined),
                      onPressed: () => _download(context, ref, p),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    HrPayslip payslip,
  ) async {
    final exporters =
        HrReportExporters(ref.read(aksharaReportExportServiceProvider));
    try {
      await exporters.sharePayslipPdf(payslip, period: bundle.period);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.hrReportExportSuccessSnackbar,
          content: Text('Payslip for ${payslip.name} ready'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to build the payslip.')),
      );
    }
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
