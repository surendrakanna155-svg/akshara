import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_view_action.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';
import '../finance_mutations_provider.dart';
import '../finance_workflow_actions.dart';
import '../invoices/finance_invoices_provider.dart';
import '../student_accounts/finance_student_accounts_provider.dart';
import '../widgets/finance_kpi_row.dart';
import '../widgets/finance_module_scaffold.dart';
import 'finance_discounts_provider.dart';

/// FN-09 — Scholarships, discount rules, and assignments.
class FinanceDiscountsScreen extends ConsumerWidget {
  const FinanceDiscountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(financeDiscountsViewStateProvider);

    return FinanceModuleScaffold(
      screen: FinanceScreen.discounts,
      showFilterBar: false,
      body: FinanceAsyncBody<DiscountsDashboardData>(
        state: viewState,
        loadingLabel: 'Loading discounts and scholarships',
        emptyMessage: 'No discount or scholarship data available.',
        emptyIcon: Icons.school_outlined,
        onRetry: () => retryFinanceFuture(ref, financeDiscountsFutureProvider),
        builder: (data) => _buildContent(context, ref: ref, data: data),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required WidgetRef ref,
    required DiscountsDashboardData data,
  }) {
    final isMobile = AdminLayout.isMobile(context);
    final useCards = AdminLayout.useCardLayout(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // STEP-5 — maker-checker on the invoice-scoped fee-reduction engine
        // (finance_fee_reductions_{repository,handlers}.ts): the catalog and
        // rules here are TEMPLATES. Awarding one targets a SPECIFIC INVOICE —
        // it is proposed (maker) and moves NO money; the student's payable
        // drops only once a second, different, authorised person approves it
        // in "Pending awards" below.
        const AksharaWarningBanner(
          message:
              'Scholarships and discount rules here are templates. Awarding one '
              'proposes a reduction against a specific invoice — the student\'s '
              'fee drops only after a second, different, authorised person '
              'approves it below.',
          compactMessage: true,
          height: 72,
          semanticLabel:
              'Awarding a scholarship or discount targets a specific invoice '
              'and reduces the student fee only after a second person '
              'approves it',
        ),
        const SizedBox(height: AksharaSpacing.s4),
        FinanceKpiRow(
          desktopColumns: 4,
          cardHeight: 100,
          kpis: data.kpis,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        Row(
          children: [
            const Expanded(
              child: AksharaSectionHeader(title: 'Scholarship catalog'),
            ),
            AksharaManageAction(
              permission: Permission.manageFinance,
              child: FilledButton.icon(
                onPressed: () => showCreateScholarshipDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add scholarship'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s3),
        if (useCards)
          Column(
            children: [
              for (final scholarship in data.scholarships) ...[
                _ScholarshipMobileCard(scholarship: scholarship),
                const SizedBox(height: AksharaSpacing.s3),
              ],
            ],
          )
        else
          _ScholarshipCatalogTable(scholarships: data.scholarships),
        const SizedBox(height: AksharaSpacing.s6),
        Row(
          children: [
            const Expanded(
              child: AksharaSectionHeader(title: 'Discount rules'),
            ),
            AksharaManageAction(
              permission: Permission.manageFinance,
              child: FilledButton.icon(
                key: QaTestKeys.financeDiscountRuleAddButton,
                onPressed: () => showCreateDiscountRuleDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add rule'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s3),
        if (useCards)
          Column(
            children: [
              for (final rule in data.rules) ...[
                _DiscountRuleMobileCard(
                  rule: rule,
                  onEdit: () => showEditDiscountRuleDialog(
                    context,
                    ref,
                    rule: rule,
                  ),
                ),
                const SizedBox(height: AksharaSpacing.s3),
              ],
            ],
          )
        else
          _DiscountRulesTable(
            rules: data.rules,
            onEditRule: (rule) =>
                showEditDiscountRuleDialog(context, ref, rule: rule),
          ),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          const AksharaSectionHeader(title: 'Student assignments'),
          const SizedBox(height: AksharaSpacing.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: AksharaViewAction(
              permission: Permission.assignScholarship,
              child: FilledButton.icon(
                key: QaTestKeys.financeAssignConcessionButton,
                onPressed: () => showAssignFeeConcessionDialog(context, ref),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Award scholarship / discount'),
              ),
            ),
          ),
        ] else
          Row(
            children: [
              const Expanded(
                child: AksharaSectionHeader(title: 'Student assignments'),
              ),
              AksharaViewAction(
                permission: Permission.assignScholarship,
                child: FilledButton.icon(
                  key: QaTestKeys.financeAssignConcessionButton,
                  onPressed: () => showAssignFeeConcessionDialog(context, ref),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Award scholarship / discount'),
                ),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s3),
        if (useCards)
          Column(
            children: [
              for (final assignment in data.assignments) ...[
                _AssignmentMobileCard(assignment: assignment),
                const SizedBox(height: AksharaSpacing.s3),
              ],
            ],
          )
        else
          _AssignmentsTable(assignments: data.assignments),
        const SizedBox(height: AksharaSpacing.s6),
        // STEP-5 — the CHECKER half of the maker-checker: proposed awards wait
        // here until a second, different, authorised person approves (money
        // moves) or rejects (no money) them; approved ones can be reversed.
        _PendingFeeReductionsSection(data: data),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.impactSummary,
          actionLabel: 'View impact report',
          icon: Icons.savings_outlined,
          semanticLabelPrefix: 'Discount impact summary',
          onAction: () => context.go(RouteNames.financeReports),
        ),
      ],
    );
  }
}

class _ScholarshipCatalogTable extends StatelessWidget {
  const _ScholarshipCatalogTable({required this.scholarships});

  final List<ScholarshipCatalogItem> scholarships;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Scholarship catalog, ${scholarships.length} programs',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 48,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 64,
          columns: const [
            DataColumn(label: Text('Scholarship')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Max discount')),
            DataColumn(label: Text('Eligibility')),
            DataColumn(label: Text('Active')),
          ],
          rows: [
            for (final scholarship in scholarships)
              DataRow(
                cells: [
                  DataCell(Text(scholarship.name)),
                  DataCell(Text(_scholarshipTypeLabel(scholarship.type))),
                  DataCell(Text(scholarship.maxDiscount)),
                  DataCell(Text(scholarship.eligibility)),
                  DataCell(Text('${scholarship.activeAssignments}')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DiscountRulesTable extends StatelessWidget {
  const _DiscountRulesTable({required this.rules, this.onEditRule});

  final List<DiscountRule> rules;
  final void Function(DiscountRule rule)? onEditRule;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Discount rules, ${rules.length} rules',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 48,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 64,
          columns: const [
            DataColumn(label: Text('Rule')),
            DataColumn(label: Text('Discount')),
            DataColumn(label: Text('Applies to')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final rule in rules)
              DataRow(
                cells: [
                  DataCell(Text(rule.name)),
                  DataCell(Text(rule.discountPercent)),
                  DataCell(Text(rule.appliesTo)),
                  DataCell(_DiscountStatusChip(status: rule.status)),
                  DataCell(
                    AksharaManageAction(
                      permission: Permission.manageFinance,
                      child: IconButton(
                        key: QaTestKeys.financeDiscountRuleEditButton(rule.id),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit rule',
                        onPressed: onEditRule == null
                            ? null
                            : () => onEditRule!(rule),
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

class _AssignmentsTable extends StatelessWidget {
  const _AssignmentsTable({required this.assignments});

  final List<StudentDiscountAssignment> assignments;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Student discount assignments, ${assignments.length} students',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 48,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 64,
          columns: const [
            DataColumn(label: Text('Student')),
            DataColumn(label: Text('Admission No.')),
            DataColumn(label: Text('Scholarship')),
            DataColumn(label: Text('Discount')),
            DataColumn(label: Text('Impact')),
            DataColumn(label: Text('Status')),
          ],
          rows: [
            for (final assignment in assignments)
              DataRow(
                cells: [
                  DataCell(Text(assignment.studentName)),
                  DataCell(Text(assignment.admissionNumber)),
                  DataCell(Text(assignment.scholarshipName)),
                  DataCell(Text(assignment.discountAmount)),
                  DataCell(Text(assignment.impactOnFees)),
                  DataCell(_DiscountStatusChip(status: assignment.status)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ScholarshipMobileCard extends StatelessWidget {
  const _ScholarshipMobileCard({required this.scholarship});

  final ScholarshipCatalogItem scholarship;

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
            Text(scholarship.name, style: text.titleSmall),
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              '${_scholarshipTypeLabel(scholarship.type)} · up to ${scholarship.maxDiscount}',
              style: text.bodySmall,
            ),
            Text(scholarship.eligibility, style: text.bodySmall),
            Text(
              '${scholarship.activeAssignments} active assignments',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscountRuleMobileCard extends StatelessWidget {
  const _DiscountRuleMobileCard({required this.rule, this.onEdit});

  final DiscountRule rule;
  final VoidCallback? onEdit;

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
            Row(
              children: [
                Expanded(child: Text(rule.name, style: text.titleSmall)),
                AksharaManageAction(
                  permission: Permission.manageFinance,
                  child: IconButton(
                    key: QaTestKeys.financeDiscountRuleEditButton(rule.id),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit rule',
                    visualDensity: VisualDensity.compact,
                    onPressed: onEdit,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              '${rule.discountPercent} · ${rule.appliesTo}',
              style: text.bodySmall,
            ),
            const SizedBox(height: AksharaSpacing.s2),
            _DiscountStatusChip(status: rule.status),
          ],
        ),
      ),
    );
  }
}

class _AssignmentMobileCard extends StatelessWidget {
  const _AssignmentMobileCard({required this.assignment});

  final StudentDiscountAssignment assignment;

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
            Text(assignment.studentName, style: text.titleSmall),
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              '${assignment.admissionNumber} · ${assignment.scholarshipName}',
              style: text.bodySmall,
            ),
            Text(
              '${assignment.discountAmount} · ${assignment.impactOnFees}',
              style: text.bodySmall,
            ),
            const SizedBox(height: AksharaSpacing.s2),
            _DiscountStatusChip(status: assignment.status),
          ],
        ),
      ),
    );
  }
}

/// STEP-5 — the CHECKER half of the invoice-scoped fee-reduction
/// maker-checker (finance_fee_reductions_{repository,handlers}.ts). Watches
/// its own read providers (independent of the parent's discounts-dashboard
/// future) so Approve/Reject/Reverse — which invalidate
/// `financeFeeReductionsFutureProvider` — refresh this section immediately.
class _PendingFeeReductionsSection extends ConsumerWidget {
  const _PendingFeeReductionsSection({required this.data});

  final DiscountsDashboardData data;

  String _sourceLabel(FeeReduction r) {
    if (r.sourceKind == FeeReductionSourceKind.scholarship) {
      final scholarship =
          data.scholarships.cast<ScholarshipCatalogItem?>().firstWhere(
                (s) => s?.id == r.scholarshipId,
                orElse: () => null,
              );
      return scholarship?.name ?? 'Scholarship';
    }
    final rule = data.rules.cast<DiscountRule?>().firstWhere(
          (rule) => rule?.id == r.discountRuleId,
          orElse: () => null,
        );
    return rule?.name ?? 'Discount rule';
  }

  String _valueLabel(FeeReduction r) {
    return r.reductionKind == FeeReductionKind.percent
        ? '${r.percent}%'
        : '₹${r.fixedAmount}';
  }

  void _showError(BuildContext context, Object error) {
    final failure = error is ApiFailureException
        ? error.failure
        : apiFailureMapper.fromException(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure.message)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(financePendingFeeReductionsProvider);
    final approved = ref.watch(financeApprovedFeeReductionsProvider);
    final invoices = ref.watch(financeInvoicesProvider);
    final studentAccounts = ref.watch(financeStudentAccountsProvider);

    if (pending.isEmpty && approved.isEmpty) {
      return const SizedBox.shrink();
    }

    FinanceInvoice? invoiceFor(String invoiceId) {
      return invoices.cast<FinanceInvoice?>().firstWhere(
            (inv) => inv?.id == invoiceId,
            orElse: () => null,
          );
    }

    String invoiceLabel(String invoiceId) =>
        invoiceFor(invoiceId)?.invoiceNumber ?? invoiceId;

    String studentLabel(FeeReduction r) {
      final invoice = invoiceFor(r.invoiceId);
      if (invoice == null) return r.studentId;
      final account = studentAccounts.cast<StudentFeeAccount?>().firstWhere(
            (a) =>
                a?.feeAssignmentId != null &&
                a!.feeAssignmentId == invoice.feeAssignmentId,
            orElse: () => null,
          );
      return account?.studentName ?? r.studentId;
    }

    Future<void> approve(FeeReduction reduction) async {
      try {
        await ref
            .read(approveFeeReductionProvider.notifier)
            .execute(reductionId: reduction.id);
      } catch (error) {
        if (!context.mounted) return;
        _showError(context, error);
      }
    }

    Future<void> reject(FeeReduction reduction) async {
      try {
        await ref
            .read(rejectFeeReductionProvider.notifier)
            .execute(reductionId: reduction.id);
      } catch (error) {
        if (!context.mounted) return;
        _showError(context, error);
      }
    }

    Future<void> reverse(FeeReduction reduction) async {
      try {
        await ref
            .read(reverseFeeReductionProvider.notifier)
            .execute(reductionId: reduction.id);
      } catch (error) {
        if (!context.mounted) return;
        _showError(context, error);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Pending awards'),
        const SizedBox(height: AksharaSpacing.s3),
        if (pending.isEmpty)
          const Text('No awards awaiting approval.')
        else
          for (final reduction in pending) ...[
            _FeeReductionRow(
              reduction: reduction,
              sourceLabel: _sourceLabel(reduction),
              valueLabel: _valueLabel(reduction),
              invoiceLabel: invoiceLabel(reduction.invoiceId),
              studentLabel: studentLabel(reduction),
              onApprove: () => approve(reduction),
              onReject: () => reject(reduction),
            ),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        if (approved.isNotEmpty) ...[
          const SizedBox(height: AksharaSpacing.s3),
          const AksharaSectionHeader(title: 'Approved awards'),
          const SizedBox(height: AksharaSpacing.s3),
          for (final reduction in approved) ...[
            _FeeReductionRow(
              reduction: reduction,
              sourceLabel: _sourceLabel(reduction),
              valueLabel: _valueLabel(reduction),
              invoiceLabel: invoiceLabel(reduction.invoiceId),
              studentLabel: studentLabel(reduction),
              onReverse: () => reverse(reduction),
            ),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      ],
    );
  }
}

/// A single proposed/approved fee reduction with its checker actions —
/// Approve/Reject gated behind [Permission.approveFeeConcession] (pending) or
/// Reverse (approved). Never crashes on the backend's 403 self-approval —
/// errors surface via the same snackbar path as every other finance mutation.
class _FeeReductionRow extends StatelessWidget {
  const _FeeReductionRow({
    required this.reduction,
    required this.sourceLabel,
    required this.valueLabel,
    required this.invoiceLabel,
    required this.studentLabel,
    this.onApprove,
    this.onReject,
    this.onReverse,
  });

  final FeeReduction reduction;
  final String sourceLabel;
  final String valueLabel;
  final String invoiceLabel;
  final String studentLabel;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onReverse;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final isPending = reduction.status == FeeReductionStatus.pending;

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
                  child: Text(
                    '$studentLabel · $sourceLabel',
                    style: text.titleSmall,
                  ),
                ),
                _FeeReductionStatusChip(status: reduction.status),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              'Invoice $invoiceLabel · $valueLabel · ${reduction.reason}',
              style: text.bodySmall,
            ),
            if (isPending) ...[
              const SizedBox(height: AksharaSpacing.s3),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AksharaApproveAction(
                    permission: Permission.approveFeeConcession,
                    child: OutlinedButton(
                      key: QaTestKeys.financeFeeReductionRejectButton(
                        reduction.id,
                      ),
                      onPressed: onReject,
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s2),
                  AksharaApproveAction(
                    permission: Permission.approveFeeConcession,
                    child: FilledButton(
                      key: QaTestKeys.financeFeeReductionApproveButton(
                        reduction.id,
                      ),
                      onPressed: onApprove,
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ] else if (reduction.status == FeeReductionStatus.approved) ...[
              const SizedBox(height: AksharaSpacing.s3),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AksharaApproveAction(
                    permission: Permission.approveFeeConcession,
                    child: OutlinedButton(
                      key: QaTestKeys.financeFeeReductionReverseButton(
                        reduction.id,
                      ),
                      onPressed: onReverse,
                      child: const Text('Reverse'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeeReductionStatusChip extends StatelessWidget {
  const _FeeReductionStatusChip({required this.status});

  final FeeReductionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      FeeReductionStatus.pending => ('Pending', KpiAccent.warning),
      FeeReductionStatus.approved => ('Approved', KpiAccent.success),
      FeeReductionStatus.rejected => ('Rejected', KpiAccent.error),
      FeeReductionStatus.reversed => ('Reversed', KpiAccent.primary),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}

class _DiscountStatusChip extends StatelessWidget {
  const _DiscountStatusChip({required this.status});

  final DiscountApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      DiscountApprovalStatus.pending => ('Pending', KpiAccent.warning),
      DiscountApprovalStatus.approved => ('Approved', KpiAccent.primary),
      DiscountApprovalStatus.rejected => ('Rejected', KpiAccent.error),
      DiscountApprovalStatus.active => ('Active', KpiAccent.success),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}

String _scholarshipTypeLabel(ScholarshipType type) => switch (type) {
      ScholarshipType.merit => 'Merit',
      ScholarshipType.needBased => 'Need-based',
      ScholarshipType.sibling => 'Sibling',
      ScholarshipType.staffChild => 'Staff child',
      ScholarshipType.sports => 'Sports',
    };
