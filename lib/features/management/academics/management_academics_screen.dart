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

/// MG-05 — Academic Health.
class ManagementAcademicsScreen extends ConsumerWidget {
  const ManagementAcademicsScreen({super.key});

  static const List<String> filterLabels = [
    'Current term',
    'All classes',
    'All subjects',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(managementAcademicsLoadingProvider);
    final isError = ref.watch(managementAcademicsErrorProvider);
    final isEmpty = ref.watch(managementAcademicsEmptyProvider);
    final data = ref.watch(managementAcademicHealthProvider);
    final filterIndex = ref.watch(managementAcademicsFilterProvider);

    return ManagementModuleScaffold(
      screen: ManagementScreen.academics,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(managementAcademicsFilterProvider.notifier).state = index,
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
    required ManagementAcademicHealthData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading academic health',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load academic health.',
      );
    }

    if (isEmpty || data == null) {
      return const AksharaEmptyState(
        message: 'No academic data for the selected filters.',
        icon: Icons.school_outlined,
      );
    }

    final isMobile = AdminLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ManagementKpiRow(kpis: data.kpis),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Academic metrics'),
        const SizedBox(height: AksharaSpacing.s3),
        _AcademicMetricsGrid(metrics: data.metrics),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Subject performance'),
        const SizedBox(height: AksharaSpacing.s3),
        _SubjectPerformanceSection(rows: data.subjectPerformance),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'At-risk students'),
        const SizedBox(height: AksharaSpacing.s3),
        _AtRiskList(students: data.atRiskStudents, compact: isMobile),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.aiInsight,
          actionLabel: 'Review at-risk list',
          icon: Icons.auto_awesome_outlined,
          semanticLabelPrefix: 'AI academic insight',
          onAction: () {},
        ),
      ],
    );
  }
}

class _AcademicMetricsGrid extends StatelessWidget {
  const _AcademicMetricsGrid({required this.metrics});

  final List<ManagementAcademicMetric> metrics;

  KpiAccent _accent(String name) => switch (name) {
        'primary' => KpiAccent.primary,
        'success' => KpiAccent.success,
        'warning' => KpiAccent.warning,
        'error' => KpiAccent.error,
        _ => KpiAccent.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final isMobile = AdminLayout.isMobile(context);
    final columns = isMobile ? 1 : 3;

    return Semantics(
      container: true,
      label: 'Academic metrics, ${metrics.length} items',
      child: GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AksharaSpacing.s4,
        crossAxisSpacing: AksharaSpacing.s4,
        childAspectRatio: isMobile ? 3.5 : 2.8,
        children: [
          for (final metric in metrics)
            _MetricCard(metric: metric, accent: _accent(metric.accentName)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric, required this.accent});

  final ManagementAcademicMetric metric;
  final KpiAccent accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final accentColors = accent.resolve(context);

    return Semantics(
      label: '${metric.label}: ${metric.value}, trend ${metric.trend}',
      child: Card(
        elevation: 0,
        color: accentColors.container,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(metric.label, style: text.bodyMedium),
              const SizedBox(height: AksharaSpacing.s1),
              Row(
                children: [
                  Text(metric.value, style: text.titleLarge),
                  const SizedBox(width: AksharaSpacing.s2),
                  Text(
                    metric.trend,
                    style: text.labelMedium.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectPerformanceSection extends StatelessWidget {
  const _SubjectPerformanceSection({required this.rows});

  final List<ManagementSubjectPerformance> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const AksharaEmptyState(
        message: 'No subject performance data.',
        icon: Icons.menu_book_outlined,
      );
    }

    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final row in rows) ...[
            _SubjectCard(row: row),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Subject performance table, ${rows.length} subjects',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 64,
            columns: const [
              DataColumn(label: Text('Subject')),
              DataColumn(label: Text('Pass %')),
              DataColumn(label: Text('Avg score')),
              DataColumn(label: Text('At-risk')),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    DataCell(Text(row.subject)),
                    DataCell(Text(row.passPercent)),
                    DataCell(Text(row.avgScore)),
                    DataCell(Text('${row.atRiskCount}')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.row});

  final ManagementSubjectPerformance row;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label:
          '${row.subject}: ${row.passPercent} pass rate, ${row.atRiskCount} at risk',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.subject, style: text.titleSmall),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                '${row.passPercent} pass · ${row.avgScore} avg · ${row.atRiskCount} at-risk',
                style: text.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AtRiskList extends StatelessWidget {
  const _AtRiskList({required this.students, this.compact = false});

  final List<String> students;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return const AksharaEmptyState(
        message: 'No at-risk students flagged.',
        icon: Icons.check_circle_outline,
      );
    }

    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'At-risk students, ${students.length} items',
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.error.withValues(alpha: 0.4)),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: students.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final student = students[index];
            return Semantics(
              label: 'At-risk student: $student',
              child: ListTile(
                dense: compact,
                leading: Icon(
                  Icons.warning_amber_outlined,
                  color: colors.error,
                  size: compact ? 20 : 24,
                ),
                title: Text(student, style: text.bodyMedium),
              ),
            );
          },
        ),
      ),
    );
  }
}
