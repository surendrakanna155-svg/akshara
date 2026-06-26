import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../admin/admin_layout.dart';
import '../copilot/copilot_context_provider.dart';
import 'director_models.dart';
import 'director_navigation.dart';
import 'director_providers.dart';
import 'widgets/director_metric_input_editor.dart';
import 'widgets/director_module_scaffold.dart';
import 'widgets/director_shared_widgets.dart';
import '../../core/errors/api_failure_mapper.dart';

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
          error: (error, _) => AksharaErrorState.fromFailure(apiFailureMapper.fromException(error)),
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
              if (ref.watch(directorCanManageProvider))
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: QaTestKeys.directorManageInputsButton,
                    onPressed: () => showDirectorMetricInputEditor(context),
                    icon: const Icon(Icons.tune_outlined, size: 18),
                    label: const Text('Enter portfolio inputs'),
                  ),
                ),
              const SizedBox(height: AksharaSpacing.s4),
              const AksharaSectionHeader(title: 'School Revenue Table'),
              const SizedBox(height: AksharaSpacing.s3),
              _RevenueTable(schools: revenue.revenueBySchool),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevenueTable extends StatelessWidget {
  const _RevenueTable({required this.schools});

  final List<DirectorSchoolRow> schools;

  @override
  Widget build(BuildContext context) {
    // Phones + portrait tablets collapse to stacked cards; landscape/desktop
    // keep the data table.
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final school in schools) ...[
            _RevenueCard(school: school),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return AksharaVirtualizedDataTable(
      columns: const [
        DataColumn(label: Text('School')),
        DataColumn(label: Text('Revenue')),
        DataColumn(label: Text('Students')),
        DataColumn(label: Text('Fee Collection %')),
        DataColumn(label: Text('Health')),
      ],
      rowCount: schools.length,
      rowBuilder: (index) {
        final school = schools[index];
        return DataRow(
          cells: [
            DataCell(Text(school.schoolName)),
            DataCell(Text('${school.revenueCr.toStringAsFixed(1)} Cr')),
            DataCell(Text('${school.students}')),
            DataCell(Text('${school.feeCollectionPercent}%')),
            DataCell(Text('${school.healthScore}')),
          ],
        );
      },
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.school});

  final DirectorSchoolRow school;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Semantics(
      label: 'School ${school.schoolName} revenue',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(school.schoolName, style: text.titleSmall),
              const SizedBox(height: AksharaSpacing.s1),
              Text(
                'Revenue ${school.revenueCr.toStringAsFixed(1)} Cr · '
                '${school.students} students',
                style: text.bodySmall,
              ),
              Text(
                'Fee collection ${school.feeCollectionPercent}% · '
                'Health ${school.healthScore}',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
