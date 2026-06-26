import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../hostel_models.dart';
import '../hostel_providers.dart';
import '../widgets/hostel_module_scaffold.dart';
import '../widgets/hostel_segment_panel.dart';
import '../widgets/hostel_trend_chart.dart';

/// HO-08 — Reports.
class HostelReportsScreen extends ConsumerWidget {
  const HostelReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(hostelReportsLoadingProvider);
    final isError = ref.watch(hostelReportsErrorProvider);
    final isEmpty = ref.watch(hostelReportsEmptyProvider);
    final data = ref.watch(hostelReportsProvider);

    return HostelModuleScaffold(
      screen: HostelScreen.reports,
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
    required HostelReportsData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading hostel reports'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load hostel reports.',
      );
    }

    if (isEmpty || data == null) {
      return const AksharaEmptyState(
        message: 'No hostel reports available.',
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
          HostelTrendChart(
            title: 'Occupancy trend (%)',
            points: data.occupancyTrend,
            height: chartHeight,
          ),
          const SizedBox(height: AksharaSpacing.s6),
          HostelSegmentPanel(
            title: 'Attendance by block (%)',
            segments: data.attendanceByBlock,
            height: chartHeight,
          ),
          const SizedBox(height: AksharaSpacing.s6),
          HostelTrendChart(
            title: 'Mess cost trend (₹L)',
            points: data.messCostTrend,
            height: chartHeight,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: HostelTrendChart(
                  title: 'Occupancy trend (%)',
                  points: data.occupancyTrend,
                  height: chartHeight,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                flex: 2,
                child: HostelSegmentPanel(
                  title: 'Attendance by block (%)',
                  segments: data.attendanceByBlock,
                  height: chartHeight,
                ),
              ),
            ],
          ),
        if (!isMobile) ...[
          const SizedBox(height: AksharaSpacing.s6),
          HostelTrendChart(
            title: 'Mess cost trend (₹L) — Finance integration',
            points: data.messCostTrend,
            height: chartHeight,
          ),
        ],
      ],
    );
  }
}

class _ReportCatalogList extends StatelessWidget {
  const _ReportCatalogList({required this.items});

  final List<HostelReportCatalogItem> items;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Column(
      children: [
        for (final item in items)
          Semantics(
            label: '${item.title}, last generated ${item.lastGenerated}',
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: AksharaSpacing.s3),
              child: ListTile(
                title: Text(item.title, style: text.titleSmall),
                subtitle: Text(
                  '${item.description} · ${item.lastGenerated}',
                  style: text.bodySmall,
                ),
                // STF-6: only the finance-linked report has a real export
                // destination today; the rest are honestly disabled (greyed)
                // instead of presenting a silent no-op download affordance.
                trailing: item.id == 'rpt_5'
                    ? IconButton(
                        icon: const Icon(Icons.download_outlined),
                        tooltip: 'Open report',
                        onPressed: () => context.go(RouteNames.financeReports),
                      )
                    : const IconButton(
                        icon: Icon(Icons.download_outlined),
                        tooltip: 'Export not available yet',
                        onPressed: null,
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
