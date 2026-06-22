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
import '../hr_models.dart';
import '../hr_providers.dart';
import '../widgets/hr_module_scaffold.dart';
import '../widgets/hr_segment_panel.dart';
import '../widgets/hr_trend_chart.dart';

/// HR-08 — Performance Reviews.
class HrPerformanceScreen extends ConsumerWidget {
  const HrPerformanceScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'In progress',
    'Completed',
    'Overdue',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(hrPerformanceLoadingProvider);
    final isError = ref.watch(hrPerformanceErrorProvider);
    final isEmpty = ref.watch(hrPerformanceEmptyProvider);
    final data = ref.watch(hrPerformanceProvider);
    final reviews = ref.watch(hrFilteredReviewsProvider);
    final filterIndex = ref.watch(hrPerformanceFilterProvider);

    return HrModuleScaffold(
      screen: HrScreen.performance,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(hrPerformanceFilterProvider.notifier).state = index,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        data: data,
        reviews: reviews,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required HrPerformanceData? data,
    required List<HrPerformanceReview> reviews,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading performance reviews'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load performance reviews.',
      );
    }

    if (isEmpty || data == null || reviews.isEmpty) {
      return const AksharaEmptyState(
        message: 'No performance reviews match the selected filters.',
        icon: Icons.star_outline,
      );
    }

    final isMobile = AdminLayout.isMobile(context);
    final chartHeight = isMobile ? 240.0 : 280.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Performance reviews'),
        const SizedBox(height: AksharaSpacing.s3),
        _ReviewsTable(reviews: reviews),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          HrSegmentPanel(
            title: 'Rating distribution',
            segments: data.ratingDistribution,
            height: chartHeight,
          ),
          const SizedBox(height: AksharaSpacing.s4),
          HrTrendChart(
            title: 'Review completion %',
            points: data.completionTrend,
            height: chartHeight,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: HrSegmentPanel(
                  title: 'Rating distribution',
                  segments: data.ratingDistribution,
                  height: chartHeight,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                child: HrTrendChart(
                  title: 'Review completion %',
                  points: data.completionTrend,
                  height: chartHeight,
                ),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.managementInsight,
          actionLabel: 'View Management',
          icon: Icons.leaderboard_outlined,
          semanticLabelPrefix: 'Management performance link',
          onAction: null,
        ),
      ],
    );
  }
}

class _ReviewsTable extends StatelessWidget {
  const _ReviewsTable({required this.reviews});

  final List<HrPerformanceReview> reviews;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final review in reviews) ...[
            _ReviewCard(review: review),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Performance reviews table, ${reviews.length} items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Employee')),
              DataColumn(label: Text('Department')),
              DataColumn(label: Text('Cycle')),
              DataColumn(label: Text('Rating')),
              DataColumn(label: Text('Reviewer')),
              DataColumn(label: Text('Due')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final review in reviews)
                DataRow(
                  cells: [
                    DataCell(Text(review.employeeName)),
                    DataCell(Text(review.department.name)),
                    DataCell(Text(review.cycle.name.toUpperCase())),
                    DataCell(Text(review.rating)),
                    DataCell(Text(review.reviewer)),
                    DataCell(Text(review.dueDate)),
                    DataCell(_ReviewStatusChip(status: review.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final HrPerformanceReview review;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Review ${review.employeeName}, ${review.rating}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(review.employeeName, style: text.titleSmall),
              Text('Rating ${review.rating}', style: text.bodySmall),
              const SizedBox(height: AksharaSpacing.s2),
              _ReviewStatusChip(status: review.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewStatusChip extends StatelessWidget {
  const _ReviewStatusChip({required this.status});

  final HrReviewStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      HrReviewStatus.notStarted => ('Not started', KpiAccent.neutral),
      HrReviewStatus.inProgress => ('In progress', KpiAccent.primary),
      HrReviewStatus.completed => ('Completed', KpiAccent.success),
      HrReviewStatus.overdue => ('Overdue', KpiAccent.error),
    };

    return AksharaStatusChip(label: label, tone: tone);
  }
}
