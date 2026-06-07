import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/permissions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../library_models.dart';
import '../library_providers.dart';
import '../widgets/library_module_scaffold.dart';

/// LB-07 — Digital Resources.
class LibraryResourcesScreen extends ConsumerWidget {
  const LibraryResourcesScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Student app',
    'Teacher app',
    'Staff only',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(libraryResourcesLoadingProvider);
    final isError = ref.watch(libraryResourcesErrorProvider);
    final isEmpty = ref.watch(libraryResourcesEmptyProvider);
    final data = ref.watch(libraryResourcesProvider);
    final filterIndex = ref.watch(libraryResourcesFilterProvider);

    final resources = _filterResources(data?.resources ?? const [], filterIndex);

    return LibraryModuleScaffold(
      screen: LibraryScreen.resources,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(libraryResourcesFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageLibrary,
        child: FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.upload_outlined, size: 18),
          label: const Text('Upload'),
        ),
      ),
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        data: data,
        resources: resources,
      ),
    );
  }

  List<LibraryDigitalResource> _filterResources(
    List<LibraryDigitalResource> resources,
    int filterIndex,
  ) {
    return switch (filterIndex) {
      1 => resources.where((r) => r.studentAppVisible).toList(),
      2 => resources.where((r) => r.teacherAppVisible).toList(),
      3 => resources
          .where((r) => !r.studentAppVisible && r.teacherAppVisible)
          .toList(),
      _ => resources,
    };
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required LibraryDigitalResourcesData? data,
    required List<LibraryDigitalResource> resources,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading digital resources',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load digital resources.',
      );
    }

    if (isEmpty || data == null || resources.isEmpty) {
      return const AksharaEmptyState(
        message: 'No digital resources match the selected filters.',
        icon: Icons.cloud_download_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Digital resources'),
        const SizedBox(height: AksharaSpacing.s3),
        _ResourcesTable(resources: resources),
        const SizedBox(height: AksharaSpacing.s6),
        if (AdminLayout.isMobile(context))
          AksharaInsightCard(
            message: data.integrationNote,
            actionLabel: 'Student app',
            icon: Icons.school_outlined,
            semanticLabelPrefix: 'Student app integration',
            onAction: () => context.go(data.studentAppRoute),
          )
        else
          Row(
            children: [
              Expanded(
                child: AksharaInsightCard(
                  message: data.integrationNote,
                  actionLabel: 'Student app',
                  icon: Icons.school_outlined,
                  semanticLabelPrefix: 'Student app integration',
                  onAction: () => context.go(data.studentAppRoute),
                ),
              ),
              const SizedBox(width: AksharaSpacing.s4),
              Expanded(
                child: AksharaInsightCard(
                  message:
                      'Teachers access the resource shelf from Teacher App dashboard.',
                  actionLabel: 'Teacher app',
                  icon: Icons.co_present_outlined,
                  semanticLabelPrefix: 'Teacher app integration',
                  onAction: () => context.go(data.teacherAppRoute),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ResourcesTable extends StatelessWidget {
  const _ResourcesTable({required this.resources});

  final List<LibraryDigitalResource> resources;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final resource in resources) ...[
            _ResourceCard(resource: resource),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Digital resources table, ${resources.length} items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Title')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Class access')),
              DataColumn(label: Text('Downloads')),
              DataColumn(label: Text('Student app')),
              DataColumn(label: Text('Teacher app')),
            ],
            rows: [
              for (final resource in resources)
                DataRow(
                  cells: [
                    DataCell(Text(resource.title)),
                    DataCell(_ResourceTypeChip(type: resource.type)),
                    DataCell(Text(resource.classAccess)),
                    DataCell(Text('${resource.downloads}')),
                    DataCell(Text(resource.studentAppVisible ? 'Yes' : '—')),
                    DataCell(Text(resource.teacherAppVisible ? 'Yes' : '—')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.resource});

  final LibraryDigitalResource resource;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: '${resource.title}, ${resource.classAccess}, ${resource.downloads} downloads',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(resource.title, style: text.titleSmall),
              Text(resource.classAccess, style: text.bodyMedium),
              Text(
                '${resource.downloads} downloads',
                style: text.bodySmall,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              _ResourceTypeChip(type: resource.type),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceTypeChip extends StatelessWidget {
  const _ResourceTypeChip({required this.type});

  final LibraryResourceType type;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (type) {
      LibraryResourceType.ebook => ('E-book', KpiAccent.primary),
      LibraryResourceType.pdf => ('PDF', KpiAccent.success),
      LibraryResourceType.link => ('Link', KpiAccent.neutral),
      LibraryResourceType.video => ('Video', KpiAccent.warning),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'Resource type: $label',
    );
  }
}
