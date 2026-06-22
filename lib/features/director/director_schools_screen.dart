import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../admin/admin_layout.dart';
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
    // Phones + portrait tablets collapse the 8-column table into stacked cards
    // (B.4e card-fallback target); landscape/desktop keep the data table.
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final school in schools) ...[
            _SchoolCard(school: school),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

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

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({required this.school});

  final DirectorSchoolRow school;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Semantics(
      label: 'School ${school.schoolName}, ${school.location}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(school.schoolName, style: text.titleSmall),
                  ),
                  DirectorSchoolStatusChip(status: school.status),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s1),
              Text(
                '${school.location} · ${school.students} students',
                style: text.bodySmall,
              ),
              Text(
                'Revenue ${school.revenueCr.toStringAsFixed(1)} Cr · '
                'Admissions QTD ${school.admissionsQtd}',
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
