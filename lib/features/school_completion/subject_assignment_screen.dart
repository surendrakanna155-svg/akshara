import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/academic/academic_catalog_provider.dart';
import '../../core/repositories/academic/academic_models.dart';
import '../../core/repositories/repository_providers.dart';
import '../../shared/async/erp_async_state.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/theme_extensions.dart';
import 'school_completion_models.dart';
import 'school_completion_providers.dart';
import '../../theme/spacing.dart';

class SubjectAssignmentScreen extends ConsumerStatefulWidget {
  const SubjectAssignmentScreen({super.key});

  @override
  ConsumerState<SubjectAssignmentScreen> createState() => _SubjectAssignmentScreenState();
}

class _SubjectAssignmentScreenState extends ConsumerState<SubjectAssignmentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(academicCatalogFutureProvider);
    final classAssignments = ref.watch(classSubjectAssignmentsProvider);
    final teacherAssignments = ref.watch(teacherSubjectAssignmentsProvider);
    final workload = ref.watch(subjectWorkloadProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subject Assignments'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Class ↔ Subject'),
            Tab(text: 'Teacher Allocation'),
          ],
        ),
      ),
      body: ErpAsyncBody(
        state: resolveErpAsync(catalog, isDataEmpty: (_) => false),
        loadingLabel: 'Loading',
        emptyMessage: 'No academic catalog available.',
        onRetry: () => ref.invalidate(academicCatalogFutureProvider),
        builder: (data) {
          final yearId = data.years.isNotEmpty ? data.years.first.yearId : 'year_1';
          return TabBarView(
            controller: _tabs,
            children: [
              _ClassSubjectTab(
                yearId: yearId,
                classes: data.classes,
                sections: data.sections,
                subjects: ref.watch(subjectsCatalogProvider).valueOrNull ?? const [],
                assignments: classAssignments.valueOrNull ?? const [],
                onAssign: (classId, sectionId, subjectId, elective) async {
                  await ref.read(schoolCompletionRepositoryProvider).createClassSubjectAssignment(
                        query: ref.read(schoolCompletionQueryProvider),
                        academicYearId: yearId,
                        classId: classId,
                        sectionId: sectionId,
                        subjectId: subjectId,
                        isElective: elective,
                      );
                  ref.invalidate(classSubjectAssignmentsProvider);
                },
                onDelete: (id) async {
                  await ref.read(schoolCompletionRepositoryProvider).deleteClassSubjectAssignment(
                        query: ref.read(schoolCompletionQueryProvider),
                        assignmentId: id,
                      );
                  ref.invalidate(classSubjectAssignmentsProvider);
                },
              ),
              _TeacherAllocationTab(
                yearId: yearId,
                subjects: ref.watch(subjectsCatalogProvider).valueOrNull ?? const [],
                teachers: data.teacherAssignments,
                assignments: teacherAssignments.valueOrNull ?? const [],
                workload: workload.valueOrNull ?? const [],
                onAssign: (teacherId, subjectId, periods) async {
                  await ref.read(schoolCompletionRepositoryProvider).createTeacherSubjectAssignment(
                        query: ref.read(schoolCompletionQueryProvider),
                        academicYearId: yearId,
                        teacherUserId: teacherId,
                        subjectId: subjectId,
                        periodsPerWeek: periods,
                        isPrimary: true,
                      );
                  ref.invalidate(teacherSubjectAssignmentsProvider);
                  ref.invalidate(subjectWorkloadProvider);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ClassSubjectTab extends StatelessWidget {
  const _ClassSubjectTab({
    required this.yearId,
    required this.classes,
    required this.sections,
    required this.subjects,
    required this.assignments,
    required this.onAssign,
    required this.onDelete,
  });

  final String yearId;
  final List<AcademicClass> classes;
  final List<AcademicSection> sections;
  final List<AcademicSubject> subjects;
  final List<ClassSubjectAssignment> assignments;
  final Future<void> Function(String classId, String? sectionId, String subjectId, bool elective)
      onAssign;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Assign subject to class'),
          onPressed: subjects.isEmpty
              ? null
              : () => _showAssignDialog(context),
        ),
        const SizedBox(height: 16),
        ...assignments.map(
          (a) => ListTile(
            title: Text('Class ${a.classId} · Subject ${a.subjectId}'),
            subtitle: Text(
              '${a.periodsPerWeek} periods/week${a.isElective ? ' · Elective' : ''}',
            ),
            trailing: IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onDelete(a.id),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAssignDialog(BuildContext context) async {
    String? classId = classes.isNotEmpty ? classes.first.classId : null;
    String? sectionId;
    String? subjectId = subjects.first.id;
    var elective = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Class subject assignment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: classId,
              decoration: const InputDecoration(labelText: 'Class'),
              items: [
                for (final c in classes)
                  DropdownMenuItem(value: c.classId, child: Text(c.className)),
              ],
              onChanged: (v) => classId = v,
            ),
            DropdownButtonFormField<String>(
              initialValue: subjectId,
              decoration: const InputDecoration(labelText: 'Subject'),
              items: [
                for (final s in subjects)
                  DropdownMenuItem(value: s.id, child: Text(s.subjectName)),
              ],
              onChanged: (v) => subjectId = v,
            ),
            SwitchListTile(
              title: const Text('Elective'),
              value: elective,
              onChanged: (v) => elective = v,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: classId == null || subjectId == null
                ? null
                : () async {
                    await onAssign(classId!, sectionId, subjectId!, elective);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }
}

class _TeacherAllocationTab extends StatelessWidget {
  const _TeacherAllocationTab({
    required this.yearId,
    required this.subjects,
    required this.teachers,
    required this.assignments,
    required this.workload,
    required this.onAssign,
  });

  final String yearId;
  final List<AcademicSubject> subjects;
  final List<AcademicTeacherAssignment> teachers;
  final List<TeacherSubjectAssignment> assignments;
  final List<SubjectWorkloadEntry> workload;
  final Future<void> Function(String teacherId, String subjectId, int periods) onAssign;

  /// Teacher UUID → display name. The catalog can carry several assignment rows
  /// per teacher (one per class/section); we keep the first non-empty name.
  Map<String, String> get _teacherNames {
    final map = <String, String>{};
    for (final t in teachers) {
      final name = t.teacherName?.trim();
      if (name != null && name.isNotEmpty) {
        map.putIfAbsent(t.teacherId, () => name);
      }
    }
    return map;
  }

  /// Subject UUID → subject name.
  Map<String, String> get _subjectNames =>
      {for (final s in subjects) s.id: s.subjectName};

  String _teacherLabel(String teacherId) =>
      _teacherNames[teacherId] ?? teacherId;

  String _subjectLabel(String subjectId) =>
      _subjectNames[subjectId] ?? subjectId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        if (workload.any((w) => w.isOverloaded))
          AksharaWarningBanner(
            message: '${workload.where((w) => w.isOverloaded).length} teachers overloaded',
          ),
        FilledButton.icon(
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Allocate teacher'),
          onPressed: subjects.isEmpty || teachers.isEmpty
              ? null
              : () => _showAllocateDialog(context),
        ),
        const SizedBox(height: 16),
        ...assignments.map(
          (a) => ListTile(
            title: Text(
              '${_teacherLabel(a.teacherUserId)} · ${_subjectLabel(a.subjectId)}',
            ),
            subtitle: Text('${a.periodsPerWeek} periods/week'),
          ),
        ),
        const Divider(),
        const Text('Workload', style: TextStyle(fontWeight: FontWeight.bold)),
        ...workload.map(
          (w) => ListTile(
            dense: true,
            title: Text(
              '${_teacherLabel(w.teacherUserId)} / ${_subjectLabel(w.subjectId)}',
            ),
            trailing: Text(
              '${w.totalPeriods}p',
              style: TextStyle(
                color: w.isOverloaded ? context.colors.error : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAllocateDialog(BuildContext context) async {
    String? teacherId = teachers.first.teacherId;
    String? subjectId = subjects.first.id;
    var periods = 5;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Teacher subject allocation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: teacherId,
              decoration: const InputDecoration(labelText: 'Teacher'),
              items: [
                for (final t in teachers)
                  DropdownMenuItem(
                    value: t.teacherId,
                    child: Text(t.teacherName ?? t.teacherId),
                  ),
              ],
              onChanged: (v) => teacherId = v,
            ),
            DropdownButtonFormField<String>(
              initialValue: subjectId,
              decoration: const InputDecoration(labelText: 'Subject'),
              items: [
                for (final s in subjects)
                  DropdownMenuItem(value: s.id, child: Text(s.subjectName)),
              ],
              onChanged: (v) => subjectId = v,
            ),
            TextFormField(
              initialValue: '5',
              decoration: const InputDecoration(labelText: 'Periods per week'),
              keyboardType: TextInputType.number,
              onChanged: (v) => periods = int.tryParse(v) ?? 5,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: teacherId == null || subjectId == null
                ? null
                : () async {
                    await onAssign(teacherId!, subjectId!, periods);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
            child: const Text('Allocate'),
          ),
        ],
      ),
    );
  }
}
