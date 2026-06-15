import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import '../copilot/copilot_context_provider.dart';
import 'director_navigation.dart';
import 'director_providers.dart';
import 'widgets/director_module_scaffold.dart';
import 'widgets/director_shared_widgets.dart';

class DirectorRevenueScreen extends ConsumerWidget {
  const DirectorRevenueScreen({super.key});

  static const _filters = ['All Schools', 'Current FY', 'Revenue Mix'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(directorRevenueProvider);
    return CopilotContextScope(
      module: 'director',
      screen: 'Director Revenue Overview',
      child: DirectorModuleScaffold(
        screen: DirectorScreen.revenue,
        filters: _filters,
        filterTrailing: const DirectorAiAssistantLink(
          screenLabel: 'Director Revenue Overview',
        ),
        body: state.when(
          loading: () => const AksharaLoadingState(),
          error: (error, _) => AksharaErrorState(message: '$error'),
          data: (revenue) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AksharaSpacing.s3,
                runSpacing: AksharaSpacing.s3,
                children: [
                  DirectorMetricTile(
                    label: 'Chain Revenue',
                    value: '${revenue.chainRevenueCr.toStringAsFixed(1)} Cr',
                  ),
                  DirectorMetricTile(
                    label: 'Expenses',
                    value: '${revenue.expensesCr.toStringAsFixed(1)} Cr',
                  ),
                  DirectorMetricTile(
                    label: 'Net',
                    value: '${revenue.netCr.toStringAsFixed(1)} Cr',
                  ),
                  DirectorMetricTile(
                    label: 'Margin',
                    value: '${revenue.marginPercent}%',
                  ),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s4),
              const AksharaSectionHeader(title: 'School Revenue Table'),
              const SizedBox(height: AksharaSpacing.s3),
              AksharaVirtualizedDataTable(
                columns: const [
                  DataColumn(label: Text('School')),
                  DataColumn(label: Text('Revenue')),
                  DataColumn(label: Text('Students')),
                  DataColumn(label: Text('Fee Collection %')),
                  DataColumn(label: Text('Health')),
                ],
                rowCount: revenue.revenueBySchool.length,
                rowBuilder: (index) {
                  final school = revenue.revenueBySchool[index];
                  return DataRow(
                    cells: [
                      DataCell(Text(school.schoolName)),
                      DataCell(
                          Text('${school.revenueCr.toStringAsFixed(1)} Cr')),
                      DataCell(Text('${school.students}')),
                      DataCell(Text('${school.feeCollectionPercent}%')),
                      DataCell(Text('${school.healthScore}')),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
