import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../finance_models.dart';
import '../widgets/finance_kpi_row.dart';
import '../widgets/finance_module_scaffold.dart';
import 'finance_discounts_provider.dart';

/// FN-09 — Scholarships, discount rules, and assignments.
class FinanceDiscountsScreen extends ConsumerWidget {
  const FinanceDiscountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(financeDiscountsLoadingProvider);
    final isError = ref.watch(financeDiscountsErrorProvider);
    final isEmpty = ref.watch(financeDiscountsEmptyProvider);
    final data = ref.watch(financeDiscountsProvider);

    return FinanceModuleScaffold(
      screen: FinanceScreen.discounts,
      showFilterBar: false,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        data: data,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required DiscountsDashboardData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading discounts and scholarships',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load discounts and scholarships.',
      );
    }

    if (isEmpty || data == null) {
      return const AksharaEmptyState(
        message: 'No discount or scholarship data available.',
        icon: Icons.school_outlined,
      );
    }

    final isMobile = AdminLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinanceKpiRow(
          desktopColumns: 4,
          cardHeight: 100,
          kpis: data.kpis,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Scholarship catalog'),
        const SizedBox(height: AksharaSpacing.s3),
        if (isMobile)
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
        const AksharaSectionHeader(title: 'Discount rules'),
        const SizedBox(height: AksharaSpacing.s3),
        if (isMobile)
          Column(
            children: [
              for (final rule in data.rules) ...[
                _DiscountRuleMobileCard(rule: rule),
                const SizedBox(height: AksharaSpacing.s3),
              ],
            ],
          )
        else
          _DiscountRulesTable(rules: data.rules),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Student assignments'),
        const SizedBox(height: AksharaSpacing.s3),
        if (isMobile)
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
          onAction: () {},
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
  const _DiscountRulesTable({required this.rules});

  final List<DiscountRule> rules;

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
          ],
          rows: [
            for (final rule in rules)
              DataRow(
                cells: [
                  DataCell(Text(rule.name)),
                  DataCell(Text(rule.discountPercent)),
                  DataCell(Text(rule.appliesTo)),
                  DataCell(_DiscountStatusChip(status: rule.status)),
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
  const _DiscountRuleMobileCard({required this.rule});

  final DiscountRule rule;

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
            Text(rule.name, style: text.titleSmall),
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
