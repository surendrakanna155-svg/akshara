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
import '../management_insight_navigation.dart';
import '../management_models.dart';
import '../management_providers.dart';
import '../widgets/management_kpi_row.dart';
import '../widgets/management_module_scaffold.dart';
import '../widgets/management_segment_panel.dart';
import '../widgets/management_trend_chart.dart';

/// MG-02 — School Analytics.
class ManagementAnalyticsScreen extends ConsumerWidget {
  const ManagementAnalyticsScreen({super.key});

  static const List<String> filterLabels = [
    'This year',
    'All classes',
    'All sections',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(managementAnalyticsLoadingProvider);
    final isError = ref.watch(managementAnalyticsErrorProvider);
    final isEmpty = ref.watch(managementAnalyticsEmptyProvider);
    final data = ref.watch(managementAnalyticsProvider);
    final filterIndex = ref.watch(managementAnalyticsFilterProvider);

    return ManagementModuleScaffold(
      screen: ManagementScreen.analytics,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(managementAnalyticsFilterProvider.notifier).state = index,
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
    required ManagementAnalyticsData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading school analytics',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load school analytics.',
      );
    }

    if (isEmpty || data == null) {
      return const AksharaEmptyState(
        message: 'No analytics data for the selected filters.',
        icon: Icons.insights_outlined,
      );
    }

    final isMobile = AdminLayout.isMobile(context);
    final chartHeight = isMobile ? 240.0 : 300.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ManagementKpiRow(kpis: data.kpis),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          ManagementTrendChart(
            title: 'Enrollment trend',
            points: data.enrollmentTrend,
            height: chartHeight,
          ),
          const SizedBox(height: AksharaSpacing.s6),
          ManagementSegmentPanel(
            title: 'Attendance by segment',
            segments: data.attendanceByClass,
            height: chartHeight,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: ManagementTrendChart(
                  title: 'Enrollment trend',
                  points: data.enrollmentTrend,
                  height: chartHeight,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                flex: 2,
                child: ManagementSegmentPanel(
                  title: 'Attendance by segment',
                  segments: data.attendanceByClass,
                  height: chartHeight,
                ),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Class summary'),
        const SizedBox(height: AksharaSpacing.s3),
        _ClassSummarySection(rows: data.classSummary),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.aiInsight,
          actionLabel: 'Review class 8-B',
          icon: Icons.auto_awesome_outlined,
          semanticLabelPrefix: 'AI analytics insight',
          onAction: () => navigateManagementInsightAction(
            context,
            ManagementScreen.analytics,
          ),
        ),
      ],
    );
  }
}

class _ClassSummarySection extends StatelessWidget {
  const _ClassSummarySection({required this.rows});

  final List<ManagementClassSummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const AksharaEmptyState(
        message: 'No class summary data available.',
        icon: Icons.table_chart_outlined,
      );
    }

    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final row in rows) ...[
            _ClassSummaryCard(row: row),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Class summary table, ${rows.length} classes',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 64,
            columns: const [
              DataColumn(label: Text('Class')),
              DataColumn(label: Text('Students')),
              DataColumn(label: Text('Attendance')),
              DataColumn(label: Text('Avg marks')),
              DataColumn(label: Text('Fee collection')),
              DataColumn(label: Text('Teachers')),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    DataCell(Text(row.classLabel)),
                    DataCell(Text('${row.students}')),
                    DataCell(Text(row.attendancePercent)),
                    DataCell(Text(row.avgMarks)),
                    DataCell(Text(row.feeCollectionPercent)),
                    DataCell(Text('${row.teachers}')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassSummaryCard extends StatelessWidget {
  const _ClassSummaryCard({required this.row});

  final ManagementClassSummaryRow row;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label:
          'Class ${row.classLabel}: ${row.students} students, ${row.attendancePercent} attendance',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.classLabel, style: text.titleSmall),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                '${row.students} students · ${row.attendancePercent} attendance',
                style: text.bodyMedium,
              ),
              Text(
                '${row.avgMarks} avg marks · ${row.feeCollectionPercent} fees · ${row.teachers} teachers',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
