import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../control_center_models.dart';
import '../control_center_providers.dart';
import '../widgets/control_center_module_scaffold.dart';

/// ACC-02 — Schools Registry.
class ControlCenterSchoolsScreen extends ConsumerWidget {
  const ControlCenterSchoolsScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Active',
    'Trial',
    'Churn risk',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(controlCenterSchoolsLoadingProvider);
    final isError = ref.watch(controlCenterSchoolsErrorProvider);
    final isEmpty = ref.watch(controlCenterSchoolsEmptyProvider);
    final schools = ref.watch(controlCenterFilteredSchoolsProvider);
    final filterIndex = ref.watch(controlCenterSchoolsFilterProvider);

    return ControlCenterModuleScaffold(
      screen: ControlCenterScreen.schools,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(controlCenterSchoolsFilterProvider.notifier).state = index,
      filterTrailing: FilledButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Create school'),
      ),
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        schools: schools,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<PlatformSchool> schools,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading schools registry'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load schools registry.',
      );
    }

    if (isEmpty || schools.isEmpty) {
      return const AksharaEmptyState(
        message: 'No schools match the selected filters.',
        icon: Icons.apartment_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Schools registry'),
        const SizedBox(height: AksharaSpacing.s3),
        if (AdminLayout.isMobile(context))
          Column(
            children: [
              for (final school in schools) ...[
                _SchoolCard(school: school),
                const SizedBox(height: AksharaSpacing.s3),
              ],
            ],
          )
        else
          _SchoolsTable(schools: schools),
      ],
    );
  }
}

class _SchoolsTable extends StatelessWidget {
  const _SchoolsTable({required this.schools});

  final List<PlatformSchool> schools;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Schools table, ${schools.length} schools',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            columns: const [
              DataColumn(label: Text('School ID')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Plan')),
              DataColumn(label: Text('Students')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('MRR')),
              DataColumn(label: Text('Health')),
            ],
            rows: [
              for (final school in schools)
                DataRow(
                  onSelectChanged: (_) =>
                      context.go(RouteNames.managementDashboard),
                  cells: [
                    DataCell(Text(school.id)),
                    DataCell(Text(school.name)),
                    DataCell(Text(school.plan.name)),
                    DataCell(Text('${school.studentCount}')),
                    DataCell(_SchoolStatusChip(status: school.status)),
                    DataCell(Text('₹${school.mrrLakhs}L')),
                    DataCell(Text('${school.healthScore}')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({required this.school});

  final PlatformSchool school;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: '${school.name}, ${school.studentCount} students',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${school.id} — ${school.name}', style: text.titleSmall),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                '${school.plan.name} · ${school.studentCount} students · ₹${school.mrrLakhs}L MRR',
                style: text.bodyMedium,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              _SchoolStatusChip(status: school.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchoolStatusChip extends StatelessWidget {
  const _SchoolStatusChip({required this.status});

  final PlatformSchoolStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      PlatformSchoolStatus.active => ('Active', KpiAccent.success),
      PlatformSchoolStatus.trial => ('Trial', KpiAccent.primary),
      PlatformSchoolStatus.suspended => ('Suspended', KpiAccent.error),
      PlatformSchoolStatus.churnRisk => ('Churn risk', KpiAccent.warning),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'School status: $label',
    );
  }
}
