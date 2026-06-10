import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_manage_action.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../../../core/repositories/academic/academic_catalog_provider.dart';
import '../registry/sis_registry_provider.dart';
import '../sis_async_state.dart';
import '../sis_mutations_provider.dart';
import '../sis_models.dart';
import '../sis_requests.dart';
import '../widgets/sis_module_scaffold.dart';
import 'sis_academic_assignment_provider.dart';

/// SIS-04 — Academic Assignment.
class SisAcademicAssignmentScreen extends ConsumerStatefulWidget {
  const SisAcademicAssignmentScreen({super.key});

  @override
  ConsumerState<SisAcademicAssignmentScreen> createState() =>
      _SisAcademicAssignmentScreenState();
}

class _SisAcademicAssignmentScreenState
    extends ConsumerState<SisAcademicAssignmentScreen> {
  late String _classLabel;
  late String _section;
  late String _academicYear;

  @override
  void initState() {
    super.initState();
    _classLabel = '5';
    _section = 'A';
    _academicYear = '2026–27';
  }

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(sisAcademicAssignmentScreenViewStateProvider);
    final students = ref.watch(sisStudentsProvider);
    final selected = ref.watch(sisSelectedAssignmentStudentProvider);
    final classes = ref.watch(sisClassOptionsProvider);
    final sections = ref.watch(sectionOptionsForClassProvider(_classLabel));
    final years = ref.watch(sisAcademicYearOptionsProvider);
    final isMobile = AdminLayout.isMobile(context);

    if (selected != null) {
      _classLabel = selected.classLabel;
      _section = selected.section;
      _academicYear = selected.academicYear;
    }

    return SisModuleScaffold(
      screen: SisScreen.academicAssignment,
      showFilterBar: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AksharaSectionHeader(title: 'Academic assignment'),
          Text(
            'Assign class, section, and academic year. Promote or transfer workflows are placeholders.',
            style: context.aksharaText.bodyMedium,
          ),
          const SizedBox(height: AksharaSpacing.s4),
          SisAsyncBody<PaginatedResult<SisStudent>>(
            state: viewState,
            loadingLabel: 'Loading academic assignment',
            emptyMessage: 'No students available for assignment.',
            emptyIcon: Icons.class_outlined,
            onRetry: () {
              retrySisFuture(ref, sisStudentsFutureProvider);
              retryAcademicCatalog(ref);
            },
            builder: (_) {
              if (selected != null) {
                _classLabel = selected.classLabel;
                _section = selected.section;
                _academicYear = selected.academicYear;
              }
              if (isMobile) {
                return Column(
                  children: [
                    _StudentPicker(
                      students: students,
                      selectedId: selected?.id,
                      onSelect: (id) => ref
                          .read(sisSelectedAssignmentStudentIdProvider.notifier)
                          .state = id,
                    ),
                    if (selected != null) ...[
                      const SizedBox(height: AksharaSpacing.s4),
                      _AssignmentForm(
                        student: selected,
                        classes: classes,
                        sections: sections,
                        years: years,
                        classLabel: _classLabel,
                        section: _section,
                        academicYear: _academicYear,
                        onClassChanged: (v) => setState(() {
                          _classLabel = v;
                          final filtered =
                              ref.read(sectionOptionsForClassProvider(v));
                          if (filtered.isNotEmpty &&
                              !filtered.contains(_section)) {
                            _section = filtered.first;
                          }
                        }),
                        onSectionChanged: (v) => setState(() => _section = v),
                        onYearChanged: (v) => setState(() => _academicYear = v),
                        onSaveAssignment: () => _saveAssignment(selected),
                        onPromote: () => _updateStatus(
                          selected,
                          SisStudentStatus.active,
                          'Promoted',
                        ),
                        onTransfer: () => _updateStatus(
                          selected,
                          SisStudentStatus.transferred,
                          'Marked for transfer',
                        ),
                      ),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _StudentPicker(
                      students: students,
                      selectedId: selected?.id,
                      onSelect: (id) => ref
                          .read(sisSelectedAssignmentStudentIdProvider.notifier)
                          .state = id,
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s6),
                  Expanded(
                    flex: 3,
                    child: selected == null
                        ? const AksharaEmptyState(
                            message: 'Select a student to assign.',
                            icon: Icons.person_search_outlined,
                          )
                        : _AssignmentForm(
                            student: selected,
                            classes: classes,
                            sections: sections,
                            years: years,
                            classLabel: _classLabel,
                            section: _section,
                            academicYear: _academicYear,
                            onClassChanged: (v) => setState(() {
                              _classLabel = v;
                              final filtered =
                                  ref.read(sectionOptionsForClassProvider(v));
                              if (filtered.isNotEmpty &&
                                  !filtered.contains(_section)) {
                                _section = filtered.first;
                              }
                            }),
                            onSectionChanged: (v) =>
                                setState(() => _section = v),
                            onYearChanged: (v) =>
                                setState(() => _academicYear = v),
                            onSaveAssignment: () => _saveAssignment(selected),
                            onPromote: () => _updateStatus(
                              selected,
                              SisStudentStatus.active,
                              'Promoted',
                            ),
                            onTransfer: () => _updateStatus(
                              selected,
                              SisStudentStatus.transferred,
                              'Marked for transfer',
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveAssignment(SisStudent student) async {
    final updated = await ref
        .read(assignAcademicAssignmentProvider.notifier)
        .execute(
          AcademicAssignmentRequest(
            studentId: student.id,
            classLabel: _classLabel,
            section: _section,
            academicYear: _academicYear,
          ),
        );
    if (!mounted || updated == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Assigned ${updated.studentName} to Class ${updated.classLabel}-${updated.section}',
        ),
      ),
    );
  }

  Future<void> _updateStatus(
    SisStudent student,
    SisStudentStatus status,
    String label,
  ) async {
    final updated = await ref
        .read(updateStudentStatusProvider.notifier)
        .execute(
          studentId: student.id,
          request: UpdateStudentStatusRequest(status: status),
        );
    if (!mounted || updated == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label ${updated.studentName}')),
    );
  }
}

class _StudentPicker extends StatelessWidget {
  const _StudentPicker({
    required this.students,
    required this.selectedId,
    required this.onSelect,
  });

  final List<SisStudent> students;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Students for academic assignment',
      child: Material(
        child: Column(
          children: [
            for (final student in students)
              ListTile(
                selected: student.id == selectedId,
                title: Text(student.studentName),
                subtitle: Text(
                  '${student.admissionNumber} · Class ${student.classLabel}-${student.section}',
                ),
                onTap: () => onSelect(student.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentForm extends ConsumerWidget {
  const _AssignmentForm({
    required this.student,
    required this.classes,
    required this.sections,
    required this.years,
    required this.classLabel,
    required this.section,
    required this.academicYear,
    required this.onClassChanged,
    required this.onSectionChanged,
    required this.onYearChanged,
    required this.onSaveAssignment,
    required this.onPromote,
    required this.onTransfer,
  });

  final SisStudent student;
  final List<String> classes;
  final List<String> sections;
  final List<String> years;
  final String classLabel;
  final String section;
  final String academicYear;
  final ValueChanged<String> onClassChanged;
  final ValueChanged<String> onSectionChanged;
  final ValueChanged<String> onYearChanged;
  final VoidCallback onSaveAssignment;
  final VoidCallback onPromote;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(student.studentName, style: context.aksharaText.titleMedium),
            const SizedBox(height: AksharaSpacing.s6),
            Material(
              child: DropdownMenu<String>(
                key: ValueKey(classLabel),
                initialSelection: classLabel,
                label: const Text('Class'),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: [
                  for (final c in classes)
                    DropdownMenuEntry(value: c, label: c),
                ],
                onSelected: (v) {
                  if (v != null) onClassChanged(v);
                },
              ),
            ),
            const SizedBox(height: AksharaSpacing.s4),
            Material(
              child: DropdownMenu<String>(
                key: ValueKey(section),
                initialSelection: section,
                label: const Text('Section'),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: [
                  for (final s in sections)
                    DropdownMenuEntry(value: s, label: s),
                ],
                onSelected: (v) {
                  if (v != null) onSectionChanged(v);
                },
              ),
            ),
            const SizedBox(height: AksharaSpacing.s4),
            Material(
              child: DropdownMenu<String>(
                key: ValueKey(academicYear),
                initialSelection: academicYear,
                label: const Text('Academic year'),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: [
                  for (final y in years)
                    DropdownMenuEntry(value: y, label: y),
                ],
                onSelected: (v) {
                  if (v != null) onYearChanged(v);
                },
              ),
            ),
            const SizedBox(height: AksharaSpacing.s6),
            Wrap(
              spacing: AksharaSpacing.s3,
              runSpacing: AksharaSpacing.s3,
              children: [
                OutlinedButton(
                  onPressed: onPromote,
                  child: const Text('Promote'),
                ),
                OutlinedButton(
                  onPressed: onTransfer,
                  child: const Text('Transfer'),
                ),
                AksharaManageAction(
                  permission: Permission.manageSis,
                  child: FilledButton(
                    onPressed: onSaveAssignment,
                    child: const Text('Save assignment'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s4),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Bulk assignment (placeholder)'),
            ),
          ],
        ),
      ),
    );
  }
}
