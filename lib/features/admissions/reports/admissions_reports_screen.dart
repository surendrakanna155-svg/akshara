import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';
import '../admissions_navigation.dart';
import '../widgets/admissions_chart_panel.dart';
import '../widgets/admissions_module_scaffold.dart';
import 'admissions_reports_provider.dart';
import 'widgets/admissions_reports_tables.dart';

/// AD-09 — Admissions analytics and reports.
class AdmissionsReportsScreen extends ConsumerWidget {
  const AdmissionsReportsScreen({super.key});

  static const List<String> _tabs = [
    'Funnel',
    'Sources',
    'Counselors',
    'Applications',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(admissionsReportsViewStateProvider);
    final tab = ref.watch(admissionsReportsTabProvider);

    return AdmissionsModuleScaffold(
      screen: AdmissionsScreen.reports,
      filters: _tabs,
      selectedFilterIndex: AdmissionsReportTab.values.indexOf(tab),
      onFilterSelected: (index) => ref
          .read(admissionsReportsTabProvider.notifier)
          .state = AdmissionsReportTab.values[index],
      filterTrailing: OutlinedButton.icon(
        onPressed: () => showAksharaExportQueuedSnackBar(context),
        icon: const Icon(Icons.download_outlined, size: 18),
        label: const Text('Export'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdmissionsAsyncBody<AdmissionsReportsData>(
            state: viewState,
            loadingLabel: 'Loading reports',
            emptyMessage: 'No report data for the selected period.',
            emptyIcon: Icons.analytics_outlined,
            onRetry: () =>
                retryAdmissionsFuture(ref, admissionsReportsFutureProvider),
            builder: (data) => _buildTabContent(data, tab),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(AdmissionsReportsData data, AdmissionsReportTab tab) {
    return switch (tab) {
      AdmissionsReportTab.funnel => AdmissionsChartPanel(
          title: 'Conversion funnel',
          segments: data.funnelSegments,
          height: 320,
        ),
      AdmissionsReportTab.sources => AdmissionsSourceReportTable(
          rows: data.sourceAnalysis,
        ),
      AdmissionsReportTab.counselors => AdmissionsCounselorReportTable(
          rows: data.counselorPerformance,
        ),
      AdmissionsReportTab.applications => AdmissionsApplicationReportTable(
          rows: data.applicationStatus,
        ),
    };
  }
}
