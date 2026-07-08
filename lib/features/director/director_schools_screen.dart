import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/reports/akshara_report_export_service.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../shared/async/erp_async_state.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../admin/admin_layout.dart';
import '../copilot/copilot_context_provider.dart';
import 'director_models.dart';
import 'director_navigation.dart';
import 'director_providers.dart';
import 'reports/director_report_exporters.dart';
import 'widgets/director_module_scaffold.dart';
import 'widgets/director_shared_widgets.dart';

/// DIR-1 — the metric a director can rank the league table by. Every option is
/// already present on [DirectorSchoolRow] (no backend call needed to sort).
enum DirectorSchoolSort {
  feePercent,
  students,
  attendanceHealth,
  outstanding,
  revenue,
  admissions;

  String get label => switch (this) {
        DirectorSchoolSort.feePercent => 'Fee collection %',
        DirectorSchoolSort.students => 'Students',
        DirectorSchoolSort.attendanceHealth => 'Health score',
        DirectorSchoolSort.outstanding => 'Outstanding fees',
        DirectorSchoolSort.revenue => 'Revenue',
        DirectorSchoolSort.admissions => 'Admissions QTD',
      };
}

/// Returns [schools] ranked (descending) by [sort]. Ties keep the incoming
/// (name) order. Descending across the board so rank 1 is always "best/most".
List<DirectorSchoolRow> rankDirectorSchools(
  List<DirectorSchoolRow> schools,
  DirectorSchoolSort sort,
) {
  final sorted = [...schools];
  int cmp(DirectorSchoolRow a, DirectorSchoolRow b) => switch (sort) {
        DirectorSchoolSort.feePercent =>
          b.feeCollectionPercent.compareTo(a.feeCollectionPercent),
        DirectorSchoolSort.students => b.students.compareTo(a.students),
        DirectorSchoolSort.attendanceHealth =>
          b.healthScore.compareTo(a.healthScore),
        DirectorSchoolSort.outstanding =>
          b.outstandingInr.compareTo(a.outstandingInr),
        DirectorSchoolSort.revenue => b.revenueCr.compareTo(a.revenueCr),
        DirectorSchoolSort.admissions =>
          b.admissionsQtd.compareTo(a.admissionsQtd),
      };
  sorted.sort(cmp);
  return sorted;
}

class DirectorSchoolsScreen extends ConsumerStatefulWidget {
  const DirectorSchoolsScreen({super.key});

  @override
  ConsumerState<DirectorSchoolsScreen> createState() =>
      _DirectorSchoolsScreenState();
}

class _DirectorSchoolsScreenState extends ConsumerState<DirectorSchoolsScreen> {
  DirectorSchoolSort _sort = DirectorSchoolSort.feePercent;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(directorSchoolsProvider);
    return CopilotContextScope(
      module: 'director',
      screen: 'Director Multi-School Overview',
      child: DirectorModuleScaffold(
        screen: DirectorScreen.schools,
        // The dead ['Region','Performance Tier','Compare Schools'] filter bar is
        // replaced by a real sort-by selector + export actions (built into the
        // body), so the scaffold filter bar is hidden.
        showFilterBar: false,
        body: ErpAsyncBody<List<DirectorSchoolRow>>(
          state: resolveErpAsync(
            state,
            isDataEmpty: (schools) => schools.isEmpty,
          ),
          loadingLabel: 'Loading',
          emptyMessage: 'No schools available in this portfolio.',
          onRetry: () => ref.invalidate(directorSchoolsProvider),
          builder: (schools) {
            final ranked = rankDirectorSchools(schools, _sort);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SchoolsToolbar(
                  sort: _sort,
                  onSortChanged: (value) => setState(() => _sort = value),
                  ranked: ranked,
                ),
                const SizedBox(height: AksharaSpacing.s4),
                _SchoolsTable(
                  schools: ranked,
                  onOpenSchool: _openSnapshot,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openSnapshot(DirectorSchoolRow school) {
    context.go(RouteNames.directorSchoolSnapshot(school.schoolId));
  }
}

/// The DIR-1 sort selector + DIR-3 export actions row.
class _SchoolsToolbar extends ConsumerWidget {
  const _SchoolsToolbar({
    required this.sort,
    required this.onSortChanged,
    required this.ranked,
  });

  final DirectorSchoolSort sort;
  final ValueChanged<DirectorSchoolSort> onSortChanged;
  final List<DirectorSchoolRow> ranked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On phones the fixed-width selector + labelled buttons overflow the narrow
    // content column, so the selector stretches full-width in a column above the
    // action buttons; tablet/desktop keep the inline wrapped row.
    final isCompact = AdminLayout.useCardLayout(context);
    final selector = DropdownButtonFormField<DirectorSchoolSort>(
      key: QaTestKeys.directorSchoolsSortSelector,
      initialValue: sort,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Rank by',
        prefixIcon: Icon(Icons.sort, size: 18),
        isDense: true,
      ),
      items: [
        for (final option in DirectorSchoolSort.values)
          DropdownMenuItem(value: option, child: Text(option.label)),
      ],
      onChanged: (value) {
        if (value != null) onSortChanged(value);
      },
    );
    final actions = [
      OutlinedButton.icon(
        key: QaTestKeys.directorSchoolsExportCsvButton,
        onPressed: () => _export(context, ref, pdf: false),
        icon: const Icon(Icons.table_chart_outlined, size: 18),
        label: const Text('Export CSV'),
      ),
      OutlinedButton.icon(
        key: QaTestKeys.directorSchoolsExportPdfButton,
        onPressed: () => _export(context, ref, pdf: true),
        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
        label: const Text('Export PDF'),
      ),
      const DirectorAiAssistantLink(
        screenLabel: 'Director Multi-School Overview',
      ),
    ];

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          selector,
          const SizedBox(height: AksharaSpacing.s3),
          Wrap(
            spacing: AksharaSpacing.s3,
            runSpacing: AksharaSpacing.s3,
            children: actions,
          ),
        ],
      );
    }

    return Wrap(
      spacing: AksharaSpacing.s3,
      runSpacing: AksharaSpacing.s3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(width: 260, child: selector),
        ...actions,
      ],
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref, {
    required bool pdf,
  }) async {
    final exporters =
        DirectorReportExporters(ref.read(aksharaReportExportServiceProvider));
    try {
      if (pdf) {
        await exporters.shareSchoolComparisonPdf(ranked);
      } else {
        await exporters.shareSchoolComparisonCsv(ranked);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.directorExportSnackbar,
          content: Text(
            'School comparison exported (${pdf ? 'PDF' : 'CSV'})',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export comparison: $error')),
      );
    }
  }
}

class _SchoolsTable extends StatelessWidget {
  const _SchoolsTable({required this.schools, required this.onOpenSchool});

  final List<DirectorSchoolRow> schools;
  final ValueChanged<DirectorSchoolRow> onOpenSchool;

  @override
  Widget build(BuildContext context) {
    // Phones + portrait tablets collapse the ranked table into stacked cards
    // (B.4e card-fallback target); landscape/desktop keep the data table. The
    // card-fallback keeps the same ranked order.
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (var i = 0; i < schools.length; i++) ...[
            _SchoolCard(
              rank: i + 1,
              school: schools[i],
              onTap: () => onOpenSchool(schools[i]),
            ),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return AksharaVirtualizedDataTable(
      columns: const [
        DataColumn(label: Text('#')),
        DataColumn(label: Text('School')),
        DataColumn(label: Text('Location')),
        DataColumn(label: Text('Students')),
        DataColumn(label: Text('Revenue')),
        DataColumn(label: Text('Admissions QTD')),
        DataColumn(label: Text('Fee %')),
        DataColumn(label: Text('Outstanding')),
        DataColumn(label: Text('Health')),
        DataColumn(label: Text('Status')),
      ],
      rowCount: schools.length,
      rowBuilder: (index) {
        final school = schools[index];
        return DataRow(
          key: QaTestKeys.directorSchoolRow(school.schoolId),
          // Row tap → DIR-D1 read-only drill-down (onSelectChanged is wired to
          // InkWell.onTap by AksharaVirtualizedDataTable).
          onSelectChanged: (_) => onOpenSchool(school),
          cells: [
            DataCell(Text('${index + 1}')),
            DataCell(Text(school.schoolName)),
            DataCell(Text(school.location)),
            DataCell(Text('${school.students}')),
            DataCell(Text('${school.revenueCr.toStringAsFixed(1)} Cr')),
            DataCell(Text('${school.admissionsQtd}')),
            DataCell(Text('${school.feeCollectionPercent}%')),
            DataCell(Text('₹${school.outstandingInr}')),
            DataCell(Text('${school.healthScore}')),
            DataCell(DirectorSchoolStatusChip(status: school.status)),
          ],
        );
      },
    );
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({
    required this.rank,
    required this.school,
    required this.onTap,
  });

  final int rank;
  final DirectorSchoolRow school;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Semantics(
      label: 'School ${school.schoolName}, ${school.location}, rank $rank',
      button: true,
      child: Card(
        key: QaTestKeys.directorSchoolRow(school.schoolId),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      child: Text('$rank', style: text.labelMedium),
                    ),
                    const SizedBox(width: AksharaSpacing.s2),
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
                  'Outstanding ₹${school.outstandingInr} · '
                  'Health ${school.healthScore}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
