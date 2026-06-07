import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../transport_models.dart';
import '../transport_providers.dart';
import '../widgets/transport_module_scaffold.dart';
import '../widgets/transport_segment_panel.dart';
import '../widgets/transport_trend_chart.dart';

/// TR-08 — Reports.
class TransportReportsScreen extends ConsumerWidget {
  const TransportReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(transportReportsLoadingProvider);
    final isError = ref.watch(transportReportsErrorProvider);
    final isEmpty = ref.watch(transportReportsEmptyProvider);
    final data = ref.watch(transportReportsProvider);

    return TransportModuleScaffold(
      screen: TransportScreen.reports,
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
    required TransportReportsData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading transport reports'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load transport reports.',
      );
    }

    if (isEmpty || data == null) {
      return const AksharaEmptyState(
        message: 'No transport reports available.',
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
          TransportTrendChart(
            title: 'On-time performance (%)',
            points: data.onTimeTrend,
            height: chartHeight,
          ),
          const SizedBox(height: AksharaSpacing.s6),
          TransportSegmentPanel(
            title: 'Avg delay by route (min)',
            segments: data.delayByRoute,
            height: chartHeight,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TransportTrendChart(
                  title: 'On-time performance (%)',
                  points: data.onTimeTrend,
                  height: chartHeight,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                flex: 2,
                child: TransportSegmentPanel(
                  title: 'Avg delay by route (min)',
                  segments: data.delayByRoute,
                  height: chartHeight,
                ),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        TransportTrendChart(
          title: 'Fuel cost trend (₹L) — Finance placeholder',
          points: data.fuelTrend,
          height: chartHeight,
        ),
      ],
    );
  }
}

class _ReportCatalogList extends StatelessWidget {
  const _ReportCatalogList({required this.items});

  final List<TransportReportCatalogItem> items;

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
                  onPressed: () {},
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
