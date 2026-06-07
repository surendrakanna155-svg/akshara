import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../management_models.dart';
import '../management_providers.dart';
import '../widgets/management_kpi_row.dart';
import '../widgets/management_module_scaffold.dart';

/// MG-06 — School Performance.
class ManagementPerformanceScreen extends ConsumerWidget {
  const ManagementPerformanceScreen({super.key});

  static const List<String> filterLabels = [
    'Current term',
    'All classes',
    'All metrics',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(managementPerformanceLoadingProvider);
    final isError = ref.watch(managementPerformanceErrorProvider);
    final isEmpty = ref.watch(managementPerformanceEmptyProvider);
    final data = ref.watch(managementSchoolPerformanceProvider);
    final filterIndex = ref.watch(managementPerformanceFilterProvider);

    return ManagementModuleScaffold(
      screen: ManagementScreen.performance,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(managementPerformanceFilterProvider.notifier).state = index,
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
    required ManagementPerformanceData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading school performance',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load school performance.',
      );
    }

    if (isEmpty || data == null) {
      return const AksharaEmptyState(
        message: 'No performance data for the selected filters.',
        icon: Icons.leaderboard_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ManagementKpiRow(kpis: data.kpis),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Class performance'),
        const SizedBox(height: AksharaSpacing.s3),
        _ClassPerformanceSection(rows: data.classPerformance),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'At-risk students'),
        const SizedBox(height: AksharaSpacing.s3),
        _AtRiskCards(students: data.atRiskStudents),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.aiInsight,
          actionLabel: 'Review class 8-B',
          icon: Icons.auto_awesome_outlined,
          semanticLabelPrefix: 'AI performance insight',
          onAction: () {},
        ),
      ],
    );
  }
}

class _ClassPerformanceSection extends StatelessWidget {
  const _ClassPerformanceSection({required this.rows});

  final List<ManagementClassPerformanceRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const AksharaEmptyState(
        message: 'No class performance data.',
        icon: Icons.table_chart_outlined,
      );
    }

    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final row in rows) ...[
            _ClassPerformanceCard(row: row),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Class performance table, ${rows.length} classes',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 64,
            columns: const [
              DataColumn(label: Text('Rank')),
              DataColumn(label: Text('Class')),
              DataColumn(label: Text('Students')),
              DataColumn(label: Text('Pass %')),
              DataColumn(label: Text('Avg marks')),
              DataColumn(label: Text('Attendance')),
              DataColumn(label: Text('Discipline')),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    DataCell(Text('#${row.rank}')),
                    DataCell(Text(row.classLabel)),
                    DataCell(Text('${row.students}')),
                    DataCell(Text(row.passPercent)),
                    DataCell(Text(row.avgMarks)),
                    DataCell(Text(row.attendance)),
                    DataCell(Text(row.disciplineScore)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassPerformanceCard extends StatelessWidget {
  const _ClassPerformanceCard({required this.row});

  final ManagementClassPerformanceRow row;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label:
          'Class ${row.classLabel}, rank ${row.rank}: ${row.passPercent} pass rate',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '#${row.rank} · ${row.classLabel}',
                style: text.titleSmall,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                '${row.students} students · ${row.passPercent} pass · ${row.avgMarks} avg',
                style: text.bodyMedium,
              ),
              Text(
                '${row.attendance} attendance · Discipline ${row.disciplineScore}',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AtRiskCards extends StatelessWidget {
  const _AtRiskCards({required this.students});

  final List<String> students;

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return const AksharaEmptyState(
        message: 'No at-risk students flagged.',
        icon: Icons.check_circle_outline,
      );
    }

    final isMobile = AdminLayout.isMobile(context);
    final columns = isMobile ? 1 : 3;

    return Semantics(
      container: true,
      label: 'At-risk student cards, ${students.length} items',
      child: GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AksharaSpacing.s4,
        crossAxisSpacing: AksharaSpacing.s4,
        childAspectRatio: isMobile ? 3.5 : 2.5,
        children: [
          for (final student in students)
            _AtRiskCard(student: student),
        ],
      ),
    );
  }
}

class _AtRiskCard extends StatelessWidget {
  const _AtRiskCard({required this.student});

  final String student;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      label: 'At-risk student: $student',
      child: Card(
        elevation: 0,
        color: colors.errorContainer.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_outlined,
                color: colors.error,
                size: 20,
              ),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: Text(student, style: text.bodyMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
