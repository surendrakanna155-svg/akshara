import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/permissions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../admin/admin_layout.dart';
import '../control_center_models.dart';
import '../control_center_providers.dart';
import '../widgets/control_center_module_scaffold.dart';
import '../widgets/control_center_segment_panel.dart';
import '../widgets/control_center_trend_chart.dart';

/// ACC-09 — Usage Analytics.
class ControlCenterAnalyticsScreen extends ConsumerWidget {
  const ControlCenterAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(controlCenterAnalyticsLoadingProvider);
    final isError = ref.watch(controlCenterAnalyticsErrorProvider);
    final data = ref.watch(controlCenterAnalyticsProvider);

    return ControlCenterModuleScaffold(
      screen: ControlCenterScreen.analytics,
      showFilterBar: false,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageControlCenter,
        child: OutlinedButton.icon(
          onPressed: () => showAksharaReportExportPreviewSnackBar(context, reportName: 'Control Center analytics'),
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Export'),
        ),
      ),
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        data: data,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required ControlCenterAnalyticsData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading platform analytics',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load platform analytics.',
      );
    }

    if (data == null) {
      return const AksharaErrorState(
        message: 'Analytics data is not available.',
      );
    }

    final isMobile = AdminLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Platform analytics'),
        const SizedBox(height: AksharaSpacing.s4),
        if (isMobile) ...[
          ControlCenterTrendChart(
            title: 'School growth',
            points: data.schoolGrowthTrend,
          ),
          const SizedBox(height: AksharaSpacing.s4),
          ControlCenterTrendChart(
            title: 'Student growth (counts)',
            points: data.studentGrowthTrend,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ControlCenterTrendChart(
                  title: 'School growth',
                  points: data.schoolGrowthTrend,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                child: ControlCenterTrendChart(
                  title: 'Student growth (counts)',
                  points: data.studentGrowthTrend,
                ),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          ControlCenterSegmentPanel(
            title: 'ERP module usage',
            segments: data.moduleUsage,
            height: 240,
          ),
          const SizedBox(height: AksharaSpacing.s4),
          ControlCenterSegmentPanel(
            title: 'Marketing attribution',
            segments: data.marketingAttribution,
            height: 240,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ControlCenterSegmentPanel(
                  title: 'ERP module usage',
                  segments: data.moduleUsage,
                  height: 280,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                child: ControlCenterSegmentPanel(
                  title: 'Marketing attribution',
                  segments: data.marketingAttribution,
                  height: 280,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
