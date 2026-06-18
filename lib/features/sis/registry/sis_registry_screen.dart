import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../router/student360_navigation.dart';
import '../../../core/reports/akshara_report_export_service.dart';
import '../../../shared/widgets/akshara_view_action.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../sis_async_state.dart';
import '../sis_models.dart';
import '../widgets/sis_module_scaffold.dart';
import 'sis_registry_provider.dart';

/// SIS-02 — Student Registry.
class SisRegistryScreen extends ConsumerStatefulWidget {
  const SisRegistryScreen({super.key});

  @override
  ConsumerState<SisRegistryScreen> createState() => _SisRegistryScreenState();
}

class _SisRegistryScreenState extends ConsumerState<SisRegistryScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(sisRegistryViewStateProvider);
    final pageResult = ref.watch(sisStudentsPageResultProvider);
    final students = ref.watch(sisFilteredStudentsProvider);
    final filterIndex = ref.watch(sisRegistryEffectiveFilterIndexProvider);
    final filterLabels = ref.watch(sisRegistryFilterLabelsProvider);

    return SisModuleScaffold(
      screen: SisScreen.registry,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(sisRegistryFilterProvider.notifier).state = index,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: QaTestKeys.sisRegistryExportButton,
              onPressed: students.isEmpty
                  ? null
                  : () async {
                      final service =
                          ref.read(aksharaReportExportServiceProvider);
                      final rows = [
                        for (final student in students)
                          MapEntry(
                            student.admissionNumber,
                            '${student.studentName} · ${student.classLabel}-${student.section} · ${student.status.name}',
                          ),
                      ];
                      await service.shareTabularCsv(
                        filename: 'sis_registry.csv',
                        reportTitle: 'SIS Student Registry',
                        rows: rows,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          key: QaTestKeys.sisRegistryExportSuccessSnackbar,
                          content: Text(
                            'SIS registry CSV ready (${students.length} students)',
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export'),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          Semantics(
            label: 'Student search',
            child: Material(
              child: TextField(
                key: QaTestKeys.sisRegistrySearchField,
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search student or admission number',
                  prefixIcon: Icon(Icons.search),
                  hintText: 'e.g. ADM-2026-0138',
                ),
                onChanged: (value) =>
                    ref.read(sisRegistrySearchProvider.notifier).state = value,
              ),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          SisAsyncBody<PaginatedResult<SisStudent>>(
            state: viewState,
            loadingLabel: 'Loading student registry',
            emptyMessage: 'No students match your search or filters.',
            emptyIcon: Icons.people_outline,
            onRetry: () => retrySisFuture(ref, sisStudentsFutureProvider),
            builder: (result) {
              if (students.isEmpty) {
                return const AksharaEmptyState(
                  message: 'No students match your search or filters.',
                  icon: Icons.people_outline,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (AdminLayout.isMobile(context))
                    Column(
                      children: [
                        for (final student in students) ...[
                          _StudentMobileCard(
                            student: student,
                            onTap: () => context.go(
                              RouteNames.sisStudentDetail(student.id),
                            ),
                          ),
                          const SizedBox(height: AksharaSpacing.s3),
                        ],
                      ],
                    )
                  else
                    _StudentRegistryTable(students: students),
                  if (pageResult != null)
                    AksharaPaginationBar<SisStudent>(
                      result: pageResult,
                      onPageChanged: (page) =>
                          ref.read(sisRegistryPageProvider.notifier).state =
                              page,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StudentRegistryTable extends StatelessWidget {
  const _StudentRegistryTable({required this.students});

  final List<SisStudent> students;

  static const _columns = [
    DataColumn(label: Text('Student')),
    DataColumn(label: Text('Admission No.')),
    DataColumn(label: Text('Class')),
    DataColumn(label: Text('Section')),
    DataColumn(label: Text('Status')),
    DataColumn(label: Text('Actions')),
  ];

  @override
  Widget build(BuildContext context) {
    return AksharaVirtualizedDataTable(
      columns: _columns,
      rowCount: students.length,
      semanticLabel: 'Student registry, ${students.length} students',
      rowBuilder: (index) {
        final student = students[index];
        return DataRow(
          key: QaTestKeys.sisRegistryStudentRow(student.studentName),
          cells: [
            DataCell(Text(student.studentName)),
            DataCell(Text(student.admissionNumber)),
            DataCell(Text(student.classLabel)),
            DataCell(Text(student.section)),
            DataCell(_StudentStatusChip(status: student.status)),
            DataCell(
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'profile':
                      context.go(RouteNames.sisStudentDetail(student.id));
                    case 'student360':
                      openStudent360(context, student.id);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Text('View profile'),
                  ),
                  const PopupMenuItem(
                    value: 'student360',
                    child: Text('Student 360'),
                  ),
                ],
                child: const Text('Actions'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StudentStatusChip extends StatelessWidget {
  const _StudentStatusChip({required this.status});

  final SisStudentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      SisStudentStatus.active => ('Active', KpiAccent.success),
      SisStudentStatus.prospect => ('Prospect', KpiAccent.warning),
      SisStudentStatus.transferred => ('Transferred', KpiAccent.primary),
      SisStudentStatus.exited => ('Exited', KpiAccent.neutral),
      SisStudentStatus.alumni => ('Alumni', KpiAccent.neutral),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}

class _StudentMobileCard extends StatelessWidget {
  const _StudentMobileCard({required this.student, required this.onTap});

  final SisStudent student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: true,
      label: '${student.studentName}, ${student.admissionNumber}',
      child: Card(
        key: QaTestKeys.sisRegistryStudentRow(student.studentName),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.studentName, style: text.titleSmall),
                Text(
                  '${student.admissionNumber} · Class ${student.classLabel}-${student.section}',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AksharaSpacing.s2),
                _StudentStatusChip(status: student.status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
