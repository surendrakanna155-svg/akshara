import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/widgets.dart';
import '../copilot/copilot_context_provider.dart';
import 'director_models.dart';
import 'director_navigation.dart';
import 'director_providers.dart';
import 'widgets/director_module_scaffold.dart';
import 'widgets/director_shared_widgets.dart';

class DirectorSchoolsScreen extends ConsumerWidget {
  const DirectorSchoolsScreen({super.key});

  static const _filters = ['Region', 'Performance Tier', 'Compare Schools'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(directorSchoolsProvider);
    return CopilotContextScope(
      module: 'director',
      screen: 'Director Multi-School Overview',
      child: DirectorModuleScaffold(
        screen: DirectorScreen.schools,
        filters: _filters,
        filterTrailing: const DirectorAiAssistantLink(
          screenLabel: 'Director Multi-School Overview',
        ),
        body: state.when(
          loading: () => const AksharaLoadingState(),
          error: (error, _) => AksharaErrorState(message: '$error'),
          data: (schools) {
            if (schools.isEmpty) {
              return const AksharaEmptyState(
                message: 'No schools available in this portfolio.',
              );
            }
            return _SchoolsTable(schools: schools);
          },
        ),
      ),
    );
  }
}

class _SchoolsTable extends StatelessWidget {
  const _SchoolsTable({required this.schools});

  final List<DirectorSchoolRow> schools;

  @override
  Widget build(BuildContext context) {
    return AksharaVirtualizedDataTable(
      columns: const [
        DataColumn(label: Text('School')),
        DataColumn(label: Text('Location')),
        DataColumn(label: Text('Students')),
        DataColumn(label: Text('Revenue')),
        DataColumn(label: Text('Admissions QTD')),
        DataColumn(label: Text('Fee %')),
        DataColumn(label: Text('Health')),
        DataColumn(label: Text('Status')),
      ],
      rowCount: schools.length,
      rowBuilder: (index) {
        final school = schools[index];
        return DataRow(
          cells: [
            DataCell(Text(school.schoolName)),
            DataCell(Text(school.location)),
            DataCell(Text('${school.students}')),
            DataCell(Text('${school.revenueCr.toStringAsFixed(1)} Cr')),
            DataCell(Text('${school.admissionsQtd}')),
            DataCell(Text('${school.feeCollectionPercent}%')),
            DataCell(Text('${school.healthScore}')),
            DataCell(DirectorSchoolStatusChip(status: school.status)),
          ],
        );
      },
    );
  }
}
