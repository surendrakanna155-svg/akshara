import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../router/student360_navigation.dart';
import '../../../core/reports/akshara_report_export_service.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../reports/sis_report_exporters.dart';
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
  // PERF-2: debounce so a search only fetches once typing settles, not once
  // per keystroke (a request storm in live mode).
  final Debouncer _searchDebouncer = Debouncer();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _replacePlaceholder(SisStudent student) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _ReplacePlaceholderDialog(student: student),
    );
    if (result == true && mounted) {
      retrySisFuture(ref, sisStudentsFutureProvider);
    }
  }

  Future<void> _exportRegistry(
    List<SisStudent> students, {
    required bool pdf,
  }) async {
    final exporters = SisReportExporters(
      ref.read(aksharaReportExportServiceProvider),
    );
    if (pdf) {
      await exporters.shareRegistryPdf(students);
    } else {
      await exporters.shareRegistryCsv(students);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.sisRegistryExportSuccessSnackbar,
        content: Text(
          'SIS registry ${pdf ? 'PDF' : 'CSV'} ready '
          '(${students.length} students)',
        ),
      ),
    );
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
          // SIS-2: true multi-column grid export (XCT-1) incl. primary
          // guardian contact — CSV and PDF ride the shared grid primitive.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                key: QaTestKeys.sisRegistryExportButton,
                onPressed: students.isEmpty
                    ? null
                    : () => _exportRegistry(students, pdf: false),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Export CSV'),
              ),
              const SizedBox(width: AksharaSpacing.s2),
              OutlinedButton.icon(
                key: QaTestKeys.sisRegistryExportPdfButton,
                onPressed: students.isEmpty
                    ? null
                    : () => _exportRegistry(students, pdf: true),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
              ),
            ],
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
                onChanged: (value) => _searchDebouncer.run(() {
                  if (!mounted) return;
                  ref.read(sisRegistrySearchProvider.notifier).state = value;
                }),
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
                  if (AdminLayout.useCardLayout(context))
                    Column(
                      children: [
                        for (final student in students) ...[
                          _StudentMobileCard(
                            student: student,
                            onTap: () => context.go(
                              RouteNames.sisStudentDetail(student.id),
                            ),
                            onReplace: () => _replacePlaceholder(student),
                          ),
                          const SizedBox(height: AksharaSpacing.s3),
                        ],
                      ],
                    )
                  else
                    _StudentRegistryTable(
                      students: students,
                      onReplace: _replacePlaceholder,
                    ),
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
  const _StudentRegistryTable({
    required this.students,
    required this.onReplace,
  });

  final List<SisStudent> students;
  final void Function(SisStudent student) onReplace;

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
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(student.studentName)),
                  if (student.isPlaceholder) ...[
                    const SizedBox(width: 6),
                    const _PlaceholderBadge(),
                  ],
                ],
              ),
            ),
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
                    case 'replace':
                      onReplace(student);
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
                  if (student.isPlaceholder)
                    const PopupMenuItem(
                      key: Key('sis_replace_placeholder_btn'),
                      value: 'replace',
                      child: Text('Replace placeholder'),
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

class _PlaceholderBadge extends StatelessWidget {
  const _PlaceholderBadge();

  @override
  Widget build(BuildContext context) {
    return const AksharaStatusChip(
      key: Key('sis_placeholder_badge'),
      label: 'Placeholder',
      tone: KpiAccent.warning,
    );
  }
}

/// Edit/replace flow that flips a placeholder into a real student.
/// On save it commits a single-row import, which creates the parent OTP login.
class _ReplacePlaceholderDialog extends ConsumerStatefulWidget {
  const _ReplacePlaceholderDialog({required this.student});

  final SisStudent student;

  @override
  ConsumerState<_ReplacePlaceholderDialog> createState() =>
      _ReplacePlaceholderDialogState();
}

class _ReplacePlaceholderDialogState
    extends ConsumerState<_ReplacePlaceholderDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _admission;
  late final TextEditingController _parentName;
  late final TextEditingController _parentPhone;
  late final TextEditingController _aadhaar;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _name = TextEditingController(
      text: s.studentName.startsWith('Placeholder') ? '' : s.studentName,
    );
    _admission = TextEditingController(text: s.admissionNumber);
    _parentName = TextEditingController();
    _parentPhone = TextEditingController();
    _aadhaar = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _admission.dispose();
    _parentName.dispose();
    _parentPhone.dispose();
    _aadhaar.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    final s = widget.student;
    final row = <String, dynamic>{
      'studentName': _name.text.trim(),
      'admissionNumber': _admission.text.trim(),
      'classLabel': s.classLabel,
      'sectionLabel': s.section,
      'academicYear': s.academicYear,
      'parentName': _parentName.text.trim(),
      'parentPhone': _parentPhone.text.trim(),
      'replacesStudentId': s.id,
      if (_aadhaar.text.trim().isNotEmpty) 'aadhaar': _aadhaar.text.trim(),
    };
    try {
      final repo = ref.read(onboardingRepositoryProvider);
      final query = ref.read(repositoryQueryProvider);
      final preview = await repo.previewStudentImport(
        query: query,
        fileName: 'replace_placeholder.csv',
        rows: [row],
      );
      if (preview.job.validRows == 0) {
        if (!mounted) return;
        final errs = preview.preview.isNotEmpty
            ? preview.preview.first.errors.join(', ')
            : 'invalid';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not replace: $errs')),
        );
        setState(() => _busy = false);
        return;
      }
      await repo.commitImport(query: query, jobId: preview.job.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Placeholder replaced. Parent can now OTP-login.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not replace: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Replace placeholder student'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                validator: _required,
                decoration: const InputDecoration(labelText: 'Student name *'),
              ),
              TextFormField(
                controller: _admission,
                validator: _required,
                decoration:
                    const InputDecoration(labelText: 'Admission number *'),
              ),
              TextFormField(
                controller: _parentName,
                validator: _required,
                decoration:
                    const InputDecoration(labelText: 'Parent name *'),
              ),
              TextFormField(
                controller: _parentPhone,
                validator: _required,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(labelText: 'Parent phone *'),
              ),
              TextFormField(
                controller: _aadhaar,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Aadhaar (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save & create login'),
        ),
      ],
    );
  }
}

class _StudentMobileCard extends StatelessWidget {
  const _StudentMobileCard({
    required this.student,
    required this.onTap,
    required this.onReplace,
  });

  final SisStudent student;
  final VoidCallback onTap;
  final VoidCallback onReplace;

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
                Row(
                  children: [
                    Flexible(
                      child: Text(student.studentName, style: text.titleSmall),
                    ),
                    if (student.isPlaceholder) ...[
                      const SizedBox(width: 6),
                      const _PlaceholderBadge(),
                    ],
                  ],
                ),
                Text(
                  '${student.admissionNumber} · Class ${student.classLabel}-${student.section}',
                  style: text.bodySmall,
                ),
                // SIS-2: primary guardian contact where available.
                if (student.guardianName.isNotEmpty ||
                    student.phone.isNotEmpty)
                  Text(
                    [
                      if (student.guardianName.isNotEmpty)
                        student.guardianName,
                      if (student.phone.isNotEmpty) student.phone,
                    ].join(' · '),
                    style: text.bodySmall
                        .copyWith(color: colors.onSurfaceVariant),
                  ),
                const SizedBox(height: AksharaSpacing.s2),
                _StudentStatusChip(status: student.status),
                if (student.isPlaceholder) ...[
                  const SizedBox(height: AksharaSpacing.s2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const Key('sis_replace_placeholder_btn'),
                      onPressed: onReplace,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Replace with real data'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
