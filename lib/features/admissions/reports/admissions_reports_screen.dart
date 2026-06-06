import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../theme/spacing.dart';
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
    final isLoading = ref.watch(admissionsReportsLoadingProvider);
    final isError = ref.watch(admissionsReportsErrorProvider);
    final isEmpty = ref.watch(admissionsReportsEmptyProvider);
    final data = ref.watch(admissionsReportsProvider);
    final tab = ref.watch(admissionsReportsTabProvider);

    return AdmissionsModuleScaffold(
      screen: AdmissionsScreen.reports,
      filters: _tabs,
      selectedFilterIndex: AdmissionsReportTab.values.indexOf(tab),
      onFilterSelected: (index) => ref
          .read(admissionsReportsTabProvider.notifier)
          .state = AdmissionsReportTab.values[index],
      filterTrailing: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.download_outlined, size: 18),
        label: const Text('Export'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
              child: AksharaLoadingState(semanticLabel: 'Loading reports'),
            )
          else if (isError)
            const AksharaErrorState(message: 'Unable to load reports.')
          else if (isEmpty || data == null)
            const AksharaEmptyState(
              message: 'No report data for the selected period.',
              icon: Icons.analytics_outlined,
            )
          else
            _buildTabContent(data, tab),
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
