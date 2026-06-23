import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../alumni_models.dart';
import '../alumni_providers.dart';
import '../alumni_workflow_actions.dart';
import '../widgets/alumni_module_scaffold.dart';

/// AL-02 — Alumni Registry.
class AlumniRegistryScreen extends ConsumerWidget {
  const AlumniRegistryScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Active',
    'Inactive',
    'Pending',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(alumniRegistryLoadingProvider);
    final isError = ref.watch(alumniRegistryErrorProvider);
    final isEmpty = ref.watch(alumniRegistryEmptyProvider);
    final alumni = ref.watch(alumniFilteredRegistryProvider);
    final filterIndex = ref.watch(alumniRegistryFilterProvider);
    final pageResult = ref.watch(alumniRegistryPageResultProvider);

    return AlumniModuleScaffold(
      screen: AlumniScreen.registry,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(alumniRegistryFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageAlumni,
        child: FilledButton.icon(
          key: QaTestKeys.alumniAddButton,
          onPressed: () => showAddAlumniDialog(context, ref),
          icon: const Icon(Icons.person_add_outlined, size: 18),
          label: const Text('Add alumni'),
        ),
      ),
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        alumni: alumni,
        pageResult: pageResult,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<AlumniRecord> alumni,
    required PaginatedResult<AlumniRecord>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading alumni registry'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load alumni registry.',
      );
    }

    if (isEmpty || alumni.isEmpty) {
      return const AksharaEmptyState(
        message: 'No alumni match the selected filters.',
        icon: Icons.people_outline,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Alumni registry'),
        const SizedBox(height: AksharaSpacing.s3),
        _RegistryTable(alumni: alumni),
        AksharaPaginatedListFooter<AlumniRecord>(
          result: pageResult,
          pageProvider: alumniRegistryPageProvider,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message:
              'Alumni records link to SIS graduate profiles. Auto-onboard Class 12 exits with status = Alumni.',
          actionLabel: 'View SIS students',
          icon: Icons.link_outlined,
          semanticLabelPrefix: 'SIS graduates integration',
          onAction: () => context.go(RouteNames.sisStudents),
        ),
      ],
    );
  }
}

class _RegistryTable extends StatelessWidget {
  const _RegistryTable({required this.alumni});

  final List<AlumniRecord> alumni;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final record in alumni) ...[
            _RegistryCard(record: record),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return AksharaVirtualizedDataTable(
      columns: const [
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Batch')),
        DataColumn(label: Text('Program')),
        DataColumn(label: Text('City')),
        DataColumn(label: Text('SIS ID')),
        DataColumn(label: Text('Donated')),
        DataColumn(label: Text('Status')),
      ],
      rowCount: alumni.length,
      dataRowMinHeight: 56,
      semanticLabel: 'Alumni registry table, ${alumni.length} records',
      rowBuilder: (index) {
        final record = alumni[index];
        return DataRow(
          onSelectChanged: (_) => context.go(
            RouteNames.alumniProfileDetail(record.id),
          ),
          cells: [
            DataCell(Text(record.name)),
            DataCell(Text(record.batchYear)),
            DataCell(Text(record.program)),
            DataCell(Text(record.city)),
            DataCell(Text(record.sisStudentId)),
            DataCell(Text(record.totalDonated)),
            DataCell(_EngagementChip(status: record.engagementStatus)),
          ],
        );
      },
    );
  }
}

class _RegistryCard extends StatelessWidget {
  const _RegistryCard({required this.record});

  final AlumniRecord record;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Alumni ${record.name}, batch ${record.batchYear}',
      child: Card(
        elevation: 0,
        child: InkWell(
          onTap: () => context.go(RouteNames.alumniProfileDetail(record.id)),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(record.name, style: text.titleSmall),
                    ),
                    _EngagementChip(status: record.engagementStatus),
                  ],
                ),
                const SizedBox(height: AksharaSpacing.s2),
                Text(
                  'Batch ${record.batchYear} · ${record.sisStudentId}',
                  style: text.bodySmall,
                ),
                Text(record.currentRole, style: text.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EngagementChip extends StatelessWidget {
  const _EngagementChip({required this.status});

  final AlumniEngagementStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      AlumniEngagementStatus.active => ('Active', KpiAccent.success),
      AlumniEngagementStatus.inactive => ('Inactive', KpiAccent.neutral),
      AlumniEngagementStatus.pending => ('Pending', KpiAccent.warning),
    };

    return AksharaStatusChip(label: label, tone: tone);
  }
}
