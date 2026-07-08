import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../../school_completion/school_branding_theme_provider.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';
import '../finance_workflow_actions.dart';
import '../policy/finance_policy_provider.dart';
import '../widgets/finance_kpi_row.dart';
import '../widgets/finance_module_scaffold.dart';
import 'finance_student_accounts_provider.dart';

/// FN-03 — Student Fee Accounts.
class FinanceStudentAccountsScreen extends ConsumerStatefulWidget {
  const FinanceStudentAccountsScreen({super.key});

  @override
  ConsumerState<FinanceStudentAccountsScreen> createState() =>
      _FinanceStudentAccountsScreenState();
}

class _FinanceStudentAccountsScreenState
    extends ConsumerState<FinanceStudentAccountsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(financeStudentAccountsViewStateProvider);
    final pageResult = ref.watch(financeStudentAccountsPageResultProvider);
    final accounts = ref.watch(financeFilteredStudentAccountsProvider);
    final selected = ref.watch(financeSelectedStudentAccountProvider);
    final isMobile = AdminLayout.isMobile(context);

    return FinanceModuleScaffold(
      screen: FinanceScreen.studentAccounts,
      showFilterBar: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: 'Student search',
            child: Material(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search student or admission number',
                  prefixIcon: Icon(Icons.search),
                  hintText: 'e.g. ADM-2026-0138',
                ),
                onChanged: (value) => ref
                    .read(financeStudentSearchQueryProvider.notifier)
                    .state = value,
              ),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          FinanceAsyncBody<PaginatedResult<StudentFeeAccount>>(
            state: viewState,
            loadingLabel: 'Loading student fee accounts',
            emptyMessage: 'No student fee accounts match your search.',
            emptyIcon: Icons.account_circle_outlined,
            onRetry: () =>
                retryFinanceFuture(ref, financeStudentAccountsFutureProvider),
            builder: (result) {
              if (accounts.isEmpty) {
                return const AksharaEmptyState(
                  message: 'No student fee accounts match your search.',
                  icon: Icons.account_circle_outlined,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isMobile)
                    Column(
                      children: [
                        for (final account in accounts) ...[
                          _AccountListTile(
                            account: account,
                            selected: account.id == selected?.id,
                            onTap: () => ref
                                .read(financeSelectedAccountIdProvider.notifier)
                                .state = account.id,
                          ),
                          const SizedBox(height: AksharaSpacing.s2),
                        ],
                        if (selected != null) ...[
                          const SizedBox(height: AksharaSpacing.s4),
                          _AccountSummaryPanel(account: selected),
                        ],
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _AccountsList(
                            accounts: accounts,
                            selectedId: selected?.id,
                            onSelect: (id) => ref
                                .read(financeSelectedAccountIdProvider.notifier)
                                .state = id,
                          ),
                        ),
                        const SizedBox(width: AksharaSpacing.s6),
                        Expanded(
                          flex: 3,
                          child: selected == null
                              ? const AksharaEmptyState(
                                  message: 'Select a student fee account.',
                                  icon: Icons.account_balance_outlined,
                                )
                              : _AccountSummaryPanel(account: selected),
                        ),
                      ],
                    ),
                  if (pageResult != null)
                    AksharaPaginationBar<StudentFeeAccount>(
                      result: pageResult,
                      onPageChanged: (page) => ref
                          .read(financeStudentAccountsPageProvider.notifier)
                          .state = page,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AccountsList extends StatelessWidget {
  const _AccountsList({
    required this.accounts,
    required this.selectedId,
    required this.onSelect,
  });

  final List<StudentFeeAccount> accounts;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Student fee accounts list',
      child: Column(
        children: [
          for (final account in accounts)
            _AccountListTile(
              account: account,
              selected: account.id == selectedId,
              onTap: () => onSelect(account.id),
            ),
        ],
      ),
    );
  }
}

class _AccountListTile extends StatelessWidget {
  const _AccountListTile({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  final StudentFeeAccount account;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: true,
      selected: selected,
      label: '${account.studentName}, ${account.admissionNumber}',
      child: Material(
        color: selected ? colors.primaryContainer : colors.surface,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.studentName, style: text.titleSmall),
                      Text(
                        '${account.admissionNumber} · Class ${account.classLabel}',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                _AccountStatusChip(status: account.status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountSummaryPanel extends ConsumerWidget {
  const _AccountSummaryPanel({required this.account});

  final StudentFeeAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AksharaSectionHeader(title: account.studentName),
        Text(
          '${account.admissionNumber} · Class ${account.classLabel}',
          style: context.aksharaText.bodyMedium,
        ),
        const SizedBox(height: AksharaSpacing.s3),
        Wrap(
          spacing: AksharaSpacing.s3,
          runSpacing: AksharaSpacing.s2,
          children: [
            // P2-UX-2 §2.4 — originate a collection straight from the accounts
            // search: the student's real balance seeds the dues amount so the
            // cashier never re-keys it. RBAC-gated to finance managers.
            AksharaManageAction(
              permission: Permission.manageFinance,
              child: FilledButton.icon(
                key: QaTestKeys.financeStudentAccountCollectButton,
                onPressed: () => showRecordCollectionDialog(
                  context,
                  ref,
                  defaultAmount: account.balance,
                  studentLabel:
                      '${account.studentName} · ${account.admissionNumber}',
                  duesLabel: 'Balance ${account.balance} · Class '
                      '${account.classLabel}',
                ),
                icon: const Icon(Icons.add_card_outlined, size: 18),
                label: const Text('Collect fee'),
              ),
            ),
            OutlinedButton.icon(
              key: QaTestKeys.financeExportStatementButton,
              onPressed: () => _exportStatement(context, ref),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Export statement'),
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s4),
        FinanceKpiRow(
          desktopColumns: 4,
          cardHeight: 100,
          kpis: [
            FinanceKpi(
              id: 'total_due',
              value: account.totalDue,
              label: 'Total due',
              icon: Icons.receipt_long_outlined,
              accentName: 'primary',
            ),
            FinanceKpi(
              id: 'paid',
              value: account.totalPaid,
              label: 'Paid',
              icon: Icons.check_circle_outline,
              accentName: 'success',
            ),
            FinanceKpi(
              id: 'balance',
              value: account.balance,
              label: 'Balance',
              icon: Icons.account_balance_wallet_outlined,
              accentName: account.status == FeeAccountStatus.overdue
                  ? 'error'
                  : 'warning',
            ),
            FinanceKpi(
              id: 'status',
              value: _statusLabel(account.status),
              label: 'Account status',
              icon: Icons.info_outline,
              accentName: account.status == FeeAccountStatus.overdue
                  ? 'error'
                  : 'neutral',
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s6),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assigned fee structure',
                  style: context.aksharaText.titleSmall,
                ),
                const SizedBox(height: AksharaSpacing.s2),
                Text(account.feeStructureName),
                const SizedBox(height: AksharaSpacing.s4),
                Text(
                  'Installment plan',
                  style: context.aksharaText.titleSmall,
                ),
                const SizedBox(height: AksharaSpacing.s2),
                Text(account.installmentPlan),
                const SizedBox(height: AksharaSpacing.s4),
                Text(
                  'Last payment',
                  style: context.aksharaText.titleSmall,
                ),
                const SizedBox(height: AksharaSpacing.s2),
                Text(account.lastPaymentDate),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// FIN-2 — builds a printable fee-statement (ledger) PDF for this account and
  /// opens the OS print/preview sheet. The ledger table carries every debit /
  /// credit line with a running balance; a header block carries account totals.
  Future<void> _exportStatement(BuildContext context, WidgetRef ref) async {
    final StudentLedger ledger;
    try {
      ledger = await ref.read(studentLedgerFutureProvider(account.id).future);
    } catch (error) {
      if (!context.mounted) return;
      final failure = error is ApiFailureException
          ? error.failure
          : apiFailureMapper.fromException(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
      return;
    }
    if (!context.mounted) return;

    final acc = ledger.account;
    final schoolName = ref.read(schoolDisplayNameProvider);
    final rows = <List<String>>[
      for (final entry in ledger.ledger)
        [
          entry.date,
          entry.reference,
          entry.description,
          entry.debit,
          entry.credit,
          entry.balance,
        ],
    ];

    final service = ref.read(aksharaReportExportServiceProvider);
    try {
      final bytes = await service.buildGridReportPdf(
        reportTitle: 'Fee Statement — ${acc.studentName}',
        moduleLabel: '${acc.admissionNumber} · Class ${acc.classLabel} · '
            '${acc.academicYear}  |  Due ${acc.totalDue} · '
            'Paid ${acc.totalPaid} · Balance ${acc.balance}'
            '${schoolName.isEmpty ? '' : '  |  $schoolName'}',
        headers: const [
          'Date',
          'Reference',
          'Description',
          'Debit',
          'Credit',
          'Balance',
        ],
        rows: rows,
        rightAlignFrom: 3,
      );
      if (!context.mounted) return;
      await service.previewPdf(
        documentName: 'fee_statement_${acc.admissionNumber}',
        bytes: bytes,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.financeExportStatementSnackbar,
          content: Text('Fee statement ready for ${acc.studentName}'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      final failure = error is ApiFailureException
          ? error.failure
          : apiFailureMapper.fromException(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
    }
  }

  static String _statusLabel(FeeAccountStatus status) => switch (status) {
        FeeAccountStatus.active => 'Active',
        FeeAccountStatus.overdue => 'Overdue',
        FeeAccountStatus.closed => 'Closed',
        FeeAccountStatus.pending => 'Pending',
      };
}

class _AccountStatusChip extends StatelessWidget {
  const _AccountStatusChip({required this.status});

  final FeeAccountStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      FeeAccountStatus.active => ('Active', KpiAccent.success),
      FeeAccountStatus.overdue => ('Overdue', KpiAccent.error),
      FeeAccountStatus.closed => ('Closed', KpiAccent.neutral),
      FeeAccountStatus.pending => ('Pending', KpiAccent.warning),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}
