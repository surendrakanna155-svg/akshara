import 'package:flutter/material.dart';
import '../../../shared/widgets/operational_action_feedback.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../alumni_models.dart';
import '../alumni_providers.dart';
import '../widgets/alumni_module_scaffold.dart';
import '../widgets/alumni_segment_panel.dart';
import '../widgets/alumni_trend_chart.dart';

/// AL-08 — Reports.
class AlumniReportsScreen extends ConsumerWidget {
  const AlumniReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(alumniReportsLoadingProvider);
    final isError = ref.watch(alumniReportsErrorProvider);
    final isEmpty = ref.watch(alumniReportsEmptyProvider);
    final data = ref.watch(alumniReportsProvider);

    return AlumniModuleScaffold(
      screen: AlumniScreen.reports,
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
    required AlumniReportsData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading alumni reports'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load alumni reports.',
      );
    }

    if (isEmpty || data == null) {
      return const AksharaEmptyState(
        message: 'No alumni reports available.',
        icon: Icons.assessment_outlined,
      );
    }

    final isMobile = AdminLayout.isMobile(context);
    final chartHeight = isMobile ? 240.0 : 300.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Report catalog'),
        const SizedBox(height: AksharaSpacing.s3),
        _ReportCatalogList(items: data.catalog),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          AlumniTrendChart(
            title: 'Donation trend (₹L) — Finance placeholder',
            points: data.donationTrend,
            height: chartHeight,
          ),
          const SizedBox(height: AksharaSpacing.s6),
          AlumniSegmentPanel(
            title: 'Engagement by batch',
            segments: data.engagementByBatch,
            height: chartHeight,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: AlumniTrendChart(
                  title: 'Donation trend (₹L) — Finance placeholder',
                  points: data.donationTrend,
                  height: chartHeight,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                flex: 2,
                child: AlumniSegmentPanel(
                  title: 'Engagement by batch',
                  segments: data.engagementByBatch,
                  height: chartHeight,
                ),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        AlumniTrendChart(
          title: 'Event attendance rate (%)',
          points: data.eventAttendanceTrend,
          height: chartHeight,
        ),
      ],
    );
  }
}

class _ReportCatalogList extends StatelessWidget {
  const _ReportCatalogList({required this.items});

  final List<AlumniReportCatalogItem> items;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Report catalog, ${items.length} reports',
      child: Column(
        children: [
          for (final item in items) ...[
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(item.title, style: text.titleSmall),
                subtitle: Text(
                  '${item.description} · Last: ${item.lastGenerated}',
                  style: text.bodySmall,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Download report',
                  onPressed: () => showAksharaReportExportPreviewSnackBar(context, reportName: 'Alumni report'),
                ),
              ),
            ),
            const SizedBox(height: AksharaSpacing.s2),
          ],
        ],
      ),
    );
  }
}
