import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../shared/async/erp_async_state.dart';
import '../../shared/forms/forms.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/theme_extensions.dart';
import '../admin/admin_layout.dart';
import 'school_completion_models.dart';
import 'school_completion_mutations_provider.dart';
import 'school_completion_providers.dart';
import '../../theme/spacing.dart';

class SubstituteManagerScreen extends ConsumerStatefulWidget {
  const SubstituteManagerScreen({super.key});

  @override
  ConsumerState<SubstituteManagerScreen> createState() =>
      _SubstituteManagerScreenState();
}

class _SubstituteManagerScreenState
    extends ConsumerState<SubstituteManagerScreen> {
  final String _academicYearId = 'year_1';
  String? _dayFilter;
  String _classFilter = '';
  SubstituteOpenSlot? _selectedSlot;
  SubstituteTeacherCandidate? _selectedTeacher;
  bool _notifySubstituteTeacher = true;
  bool _notifyClassIncharge = true;
  bool _notifyStudents = false;

  List<SubstituteOpenSlot> _filteredSlots(List<SubstituteOpenSlot> slots) {
    final normalized = _classFilter.trim().toLowerCase();
    return slots.where((slot) {
      if (normalized.isEmpty) return true;
      return slot.className.toLowerCase().contains(normalized) ||
          slot.sectionName.toLowerCase().contains(normalized) ||
          slot.subjectName.toLowerCase().contains(normalized);
    }).toList(growable: false);
  }

  List<SubstituteTeacherCandidate> _rankedTeachers(
    List<SubstituteTeacherCandidate> candidates,
    SubstituteOpenSlot? slot,
  ) {
    if (slot == null) return candidates;
    final scored = [...candidates];
    scored.sort((a, b) {
      final aMatch =
          a.subjects.any((subject) => subject == slot.subjectName) ? 1 : 0;
      final bMatch =
          b.subjects.any((subject) => subject == slot.subjectName) ? 1 : 0;
      if (aMatch != bMatch) return bMatch.compareTo(aMatch);
      if (a.freePeriods != b.freePeriods) {
        return b.freePeriods.compareTo(a.freePeriods);
      }
      return a.dailyLoad.compareTo(b.dailyLoad);
    });
    return scored;
  }

  @override
  Widget build(BuildContext context) {
    final coverage = ref.watch(
      substituteCoverageProvider(
          (academicYearId: _academicYearId, dayOfWeek: _dayFilter)),
    );
    final assignmentState = ref.watch(assignSubstituteProvider);
    final assigning = assignmentState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Substitute Teacher Wizard')),
      body: ErpAsyncBody(
        state: resolveErpAsync(coverage, isDataEmpty: (_) => false),
        loadingLabel: 'Loading',
        emptyMessage: 'No substitute coverage data available.',
        onRetry: () => ref.invalidate(
          substituteCoverageProvider(
              (academicYearId: _academicYearId, dayOfWeek: _dayFilter)),
        ),
        builder: (data) {
          final slots = _filteredSlots(data.openSlots);
          final teachers = _rankedTeachers(data.candidates, _selectedSlot);
          if (_selectedSlot != null &&
              !slots.any((slot) => slot.slotId == _selectedSlot!.slotId)) {
            _selectedSlot = null;
            _selectedTeacher = null;
          }
          if (_selectedTeacher != null &&
              !teachers.any((teacher) =>
                  teacher.teacherId == _selectedTeacher!.teacherId)) {
            _selectedTeacher = null;
          }
          return ListView(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            children: [
              _FilterBar(
                dayFilter: _dayFilter,
                classFilter: _classFilter,
                onDayChanged: (value) => setState(() => _dayFilter = value),
                onClassChanged: (value) => setState(() => _classFilter = value),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(RouteNames.teacherReassignment),
                  icon: const Icon(Icons.compare_arrows_outlined),
                  label: const Text('Open Teacher Reassignment Wizard'),
                ),
              ),
              const SizedBox(height: 16),
              Text('Open slots',
                  style: context.aksharaText.titleMedium),
              const SizedBox(height: 8),
              _OpenSlotsTable(
                slots: slots,
                selectedSlot: _selectedSlot,
                onSelect: (slot) => setState(() {
                  _selectedSlot = slot;
                  _selectedTeacher = null;
                }),
              ),
              const SizedBox(height: 16),
              Text('Available teachers',
                  style: context.aksharaText.titleMedium),
              const SizedBox(height: 8),
              _AvailableTeachersPanel(
                slot: _selectedSlot,
                teachers: teachers,
                selectedTeacher: _selectedTeacher,
                onSelect: (teacher) =>
                    setState(() => _selectedTeacher = teacher),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AksharaSpacing.s3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AksharaStepIndicator(
                        stepLabels: const [
                          'Select slot',
                          'Select teacher',
                          'Confirm and notify',
                        ],
                        currentIndex: _selectedSlot == null
                            ? 0
                            : _selectedTeacher == null
                                ? 1
                                : 2,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedSlot == null
                            ? 'Choose one open timetable slot from the table.'
                            : '${_selectedSlot!.className} ${_selectedSlot!.sectionName} • ${_selectedSlot!.subjectName} • ${_selectedSlot!.dayOfWeek} ${_selectedSlot!.periodLabel}',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedTeacher == null
                            ? 'Pick an available teacher with matching subject and free period.'
                            : '${_selectedTeacher!.teacherName} selected (${_selectedTeacher!.freePeriods} free periods).',
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: _notifySubstituteTeacher,
                        onChanged: (value) =>
                            setState(() => _notifySubstituteTeacher = value),
                        title: const Text('Notify substitute teacher'),
                      ),
                      SwitchListTile(
                        value: _notifyClassIncharge,
                        onChanged: (value) =>
                            setState(() => _notifyClassIncharge = value),
                        title: const Text('Notify class incharge'),
                      ),
                      SwitchListTile(
                        value: _notifyStudents,
                        onChanged: (value) =>
                            setState(() => _notifyStudents = value),
                        title: const Text('Notify students'),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          key: QaTestKeys.substituteAssignButton,
                          onPressed: _selectedSlot == null ||
                                  _selectedTeacher == null ||
                                  assigning
                              ? null
                              : () async {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final result = await ref
                                      .read(assignSubstituteProvider.notifier)
                                      .execute(
                                        AssignSubstituteRequest(
                                          slotId: _selectedSlot!.slotId,
                                          substituteTeacherId:
                                              _selectedTeacher!.teacherId,
                                          notifySubstituteTeacher:
                                              _notifySubstituteTeacher,
                                          notifyClassIncharge:
                                              _notifyClassIncharge,
                                          notifyStudents: _notifyStudents,
                                        ),
                                      );
                                  if (!mounted || result == null) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      key: QaTestKeys
                                          .substituteAssignSuccessSnackbar,
                                      content: Text(result.message),
                                    ),
                                  );
                                  setState(() {
                                    _selectedSlot = null;
                                    _selectedTeacher = null;
                                  });
                                },
                          icon: assigning
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: const Text('Assign substitute'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.dayFilter,
    required this.classFilter,
    required this.onDayChanged,
    required this.onClassChanged,
  });

  final String? dayFilter;
  final String classFilter;
  final ValueChanged<String?> onDayChanged;
  final ValueChanged<String> onClassChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String?>(
            key: QaTestKeys.substituteDayFilter,
            initialValue: dayFilter,
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('All days')),
              DropdownMenuItem<String?>(value: 'Monday', child: Text('Monday')),
              DropdownMenuItem<String?>(
                  value: 'Tuesday', child: Text('Tuesday')),
              DropdownMenuItem<String?>(
                  value: 'Wednesday', child: Text('Wednesday')),
              DropdownMenuItem<String?>(
                  value: 'Thursday', child: Text('Thursday')),
              DropdownMenuItem<String?>(value: 'Friday', child: Text('Friday')),
            ],
            onChanged: onDayChanged,
            decoration: const InputDecoration(
              labelText: 'Day filter',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: 240,
          child: TextFormField(
            key: QaTestKeys.substituteClassFilter,
            initialValue: classFilter,
            onChanged: onClassChanged,
            decoration: const InputDecoration(
              labelText: 'Search class/section/subject',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

class _OpenSlotsTable extends StatelessWidget {
  const _OpenSlotsTable({
    required this.slots,
    required this.selectedSlot,
    required this.onSelect,
  });

  final List<SubstituteOpenSlot> slots;
  final SubstituteOpenSlot? selectedSlot;
  final ValueChanged<SubstituteOpenSlot> onSelect;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AksharaSpacing.s4),
          child: Text('No open timetable slots for the selected filter.'),
        ),
      );
    }

    if (AdminLayout.useCardLayout(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final slot in slots) ...[
            AksharaKeyValueCard(
              title: '${slot.className} · ${slot.sectionName}',
              trailing: OutlinedButton(
                key: ValueKey('substitute_slot_${slot.slotId}'),
                onPressed: () => onSelect(slot),
                child: Text(
                  selectedSlot?.slotId == slot.slotId ? 'Selected' : 'Select',
                ),
              ),
              entries: [
                ('Subject', slot.subjectName),
                ('Day', slot.dayOfWeek),
                ('Period', slot.periodLabel),
                ('Original teacher', slot.originalTeacherName),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Class')),
            DataColumn(label: Text('Section')),
            DataColumn(label: Text('Subject')),
            DataColumn(label: Text('Day')),
            DataColumn(label: Text('Period')),
            DataColumn(label: Text('Original teacher')),
            DataColumn(label: Text('Action')),
          ],
          rows: slots.map((slot) {
            final selected = selectedSlot?.slotId == slot.slotId;
            return DataRow(
              selected: selected,
              cells: [
                DataCell(Text(slot.className)),
                DataCell(Text(slot.sectionName)),
                DataCell(Text(slot.subjectName)),
                DataCell(Text(slot.dayOfWeek)),
                DataCell(Text(slot.periodLabel)),
                DataCell(Text(slot.originalTeacherName)),
                DataCell(
                  OutlinedButton(
                    key: ValueKey('substitute_slot_${slot.slotId}'),
                    onPressed: () => onSelect(slot),
                    child: Text(selected ? 'Selected' : 'Select'),
                  ),
                ),
              ],
            );
          }).toList(growable: false),
        ),
      ),
    );
  }
}

class _AvailableTeachersPanel extends StatelessWidget {
  const _AvailableTeachersPanel({
    required this.slot,
    required this.teachers,
    required this.selectedTeacher,
    required this.onSelect,
  });

  final SubstituteOpenSlot? slot;
  final List<SubstituteTeacherCandidate> teachers;
  final SubstituteTeacherCandidate? selectedTeacher;
  final ValueChanged<SubstituteTeacherCandidate> onSelect;

  @override
  Widget build(BuildContext context) {
    if (slot == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AksharaSpacing.s4),
          child: Text('Select a slot to load ranked substitute teachers.'),
        ),
      );
    }
    return Card(
      child: Column(
        children: teachers.map((teacher) {
          final selected = selectedTeacher?.teacherId == teacher.teacherId;
          final subjectMatch =
              teacher.subjects.any((subject) => subject == slot!.subjectName);
          return ListTile(
            key: ValueKey('substitute_teacher_${teacher.teacherId}'),
            selected: selected,
            title: Text(teacher.teacherName),
            subtitle: Text(
              'Subjects: ${teacher.subjects.join(', ')} • Free: ${teacher.freePeriods} • Daily load: ${teacher.dailyLoad}',
            ),
            trailing: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                if (subjectMatch) const Chip(label: Text('Subject match')),
                if (!teacher.canNotify)
                  const Chip(label: Text('No direct notify')),
                OutlinedButton(
                  key: ValueKey(
                      'substitute_teacher_select_${teacher.teacherId}'),
                  onPressed: () => onSelect(teacher),
                  child: Text(selected ? 'Selected' : 'Select'),
                ),
              ],
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}
