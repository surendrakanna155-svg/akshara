import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../finance_workflow_actions.dart';
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
        // NOT-YET-APPLIED caveat (mirrors FIN-D4 fee concessions): scholarships
        // and discount rules are recorded here, but no invoice/fee-structure
        // path reduces a student's payable from them yet — surface this
        // up-front so "Active" is never mistaken for "already applied".
        const AksharaWarningBanner(
          message:
              'Scholarships and discount rules are recorded here but do not '
              'yet reduce a student\'s fee — applying them to live invoices '
              'is a tracked follow-up.',
          compactMessage: true,
          semanticLabel:
              'Scholarships and discount rules do not yet reduce student fees',
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
                label: const Text('Assign concession'),
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
                  label: const Text('Assign concession'),
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
