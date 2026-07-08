import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../shared/async/erp_async_state.dart';
import '../../shared/forms/forms.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/theme_extensions.dart';
import '../admin/admin_layout.dart';
import 'school_completion_models.dart';
import 'school_completion_mutations_provider.dart';
import 'school_completion_providers.dart';
import '../../theme/spacing.dart';

class TeacherReassignmentScreen extends ConsumerStatefulWidget {
  const TeacherReassignmentScreen({super.key});

  @override
  ConsumerState<TeacherReassignmentScreen> createState() =>
      _TeacherReassignmentScreenState();
}

class _TeacherReassignmentScreenState
    extends ConsumerState<TeacherReassignmentScreen> {
  final String _academicYearId = 'year_1';
  String? _sourceTeacherId;
  final Set<String> _selectedSlotIds = <String>{};
  TeacherReassignmentCandidate? _selectedTargetTeacher;
  bool _notifySourceTeacher = true;
  bool _notifyTargetTeacher = true;
  bool _notifyStudents = false;

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(
      teacherReassignmentOptionsProvider(
        (academicYearId: _academicYearId, sourceTeacherId: _sourceTeacherId),
      ),
    );
    final mutationState = ref.watch(reassignTeacherProvider);
    final submitting = mutationState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Reassignment Wizard')),
      body: ErpAsyncBody(
        state: resolveErpAsync(options, isDataEmpty: (_) => false),
        loadingLabel: 'Loading',
        emptyMessage: 'No teacher reassignment options available.',
        onRetry: () => ref.invalidate(
          teacherReassignmentOptionsProvider(
            (academicYearId: _academicYearId, sourceTeacherId: _sourceTeacherId),
          ),
        ),
        builder: (data) {
          if (_sourceTeacherId == null && data.sourceTeacherId.isNotEmpty) {
            _sourceTeacherId = data.sourceTeacherId;
          }
          final groupedTeachers = <String, String>{};
          for (final slot in data.slots) {
            groupedTeachers[slot.sourceTeacherId] = slot.sourceTeacherName;
          }
          if (_sourceTeacherId != null &&
              !groupedTeachers.containsKey(_sourceTeacherId)) {
            _sourceTeacherId = groupedTeachers.keys.isNotEmpty
                ? groupedTeachers.keys.first
                : null;
            _selectedSlotIds.clear();
            _selectedTargetTeacher = null;
          }
          final selectedSlots = data.slots
              .where((slot) => _selectedSlotIds.contains(slot.slotId))
              .toList(growable: false);

          if (_selectedTargetTeacher != null &&
              !data.candidates.any(
                (candidate) =>
                    candidate.teacherId == _selectedTargetTeacher!.teacherId,
              )) {
            _selectedTargetTeacher = null;
          }

          return ListView(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AksharaSpacing.s3),
                  child: DropdownButtonFormField<String>(
                    key: QaTestKeys.teacherReassignmentSourceFilter,
                    initialValue: _sourceTeacherId,
                    decoration: const InputDecoration(
                      labelText: 'Source teacher',
                      border: OutlineInputBorder(),
                    ),
                    items: groupedTeachers.entries
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: groupedTeachers.isEmpty
                        ? null
                        : (teacherId) {
                            setState(() {
                              _sourceTeacherId = teacherId;
                              _selectedSlotIds.clear();
                              _selectedTargetTeacher = null;
                            });
                          },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Step 1: Select periods',
                  style: context.aksharaText.titleMedium),
              const SizedBox(height: 8),
              _ReassignmentSlotsTable(
                slots: data.slots,
                selectedSlotIds: _selectedSlotIds,
                onToggle: (slotId, selected) => setState(() {
                  if (selected) {
                    _selectedSlotIds.add(slotId);
                  } else {
                    _selectedSlotIds.remove(slotId);
                  }
                }),
              ),
              const SizedBox(height: 16),
              Text('Step 2: Select target teacher',
                  style: context.aksharaText.titleMedium),
              const SizedBox(height: 8),
              _TeacherCandidatesPanel(
                candidates: data.candidates,
                selectedTeacher: _selectedTargetTeacher,
                onSelect: (teacher) =>
                    setState(() => _selectedTargetTeacher = teacher),
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
                          'Select periods',
                          'Select target teacher',
                          'Confirm reassignment',
                        ],
                        currentIndex: _selectedSlotIds.isEmpty
                            ? 0
                            : _selectedTargetTeacher == null
                                ? 1
                                : 2,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedSlotIds.isEmpty
                            ? 'Choose one or more timetable periods from source teacher.'
                            : '${_selectedSlotIds.length} periods selected.',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedTargetTeacher == null
                            ? 'Pick the teacher who will take selected periods.'
                            : '${_selectedTargetTeacher!.teacherName} selected as target teacher.',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        selectedSlots.isEmpty
                            ? 'No periods selected yet.'
                            : 'Selected: ${selectedSlots.map((slot) => '${slot.dayOfWeek} ${slot.periodLabel}').join(', ')}',
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: _notifySourceTeacher,
                        onChanged: (value) =>
                            setState(() => _notifySourceTeacher = value),
                        title: const Text('Notify source teacher'),
                      ),
                      SwitchListTile(
                        value: _notifyTargetTeacher,
                        onChanged: (value) =>
                            setState(() => _notifyTargetTeacher = value),
                        title: const Text('Notify target teacher'),
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
                          key: QaTestKeys.teacherReassignmentSubmitButton,
                          onPressed: _sourceTeacherId == null ||
                                  _selectedSlotIds.isEmpty ||
                                  _selectedTargetTeacher == null ||
                                  submitting
                              ? null
                              : () async {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final result = await ref
                                      .read(reassignTeacherProvider.notifier)
                                      .execute(
                                        ReassignTeacherRequest(
                                          academicYearId: _academicYearId,
                                          sourceTeacherId: _sourceTeacherId!,
                                          targetTeacherId:
                                              _selectedTargetTeacher!.teacherId,
                                          slotIds: _selectedSlotIds.toList(
                                              growable: false),
                                          notifySourceTeacher:
                                              _notifySourceTeacher,
                                          notifyTargetTeacher:
                                              _notifyTargetTeacher,
                                          notifyStudents: _notifyStudents,
                                        ),
                                      );
                                  if (!mounted || result == null) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      key: QaTestKeys
                                          .teacherReassignmentSuccessSnackbar,
                                      content: Text(result.message),
                                    ),
                                  );
                                  setState(() {
                                    _selectedSlotIds.clear();
                                    _selectedTargetTeacher = null;
                                  });
                                },
                          icon: submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.compare_arrows_outlined),
                          label: const Text('Reassign teacher'),
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

class _ReassignmentSlotsTable extends StatelessWidget {
  const _ReassignmentSlotsTable({
    required this.slots,
    required this.selectedSlotIds,
    required this.onToggle,
  });

  final List<TeacherReassignmentSlot> slots;
  final Set<String> selectedSlotIds;
  final void Function(String slotId, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AksharaSpacing.s4),
          child: Text('No periods available for reassignment.'),
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
              trailing: Checkbox(
                key: ValueKey('teacher_reassignment_slot_${slot.slotId}'),
                value: selectedSlotIds.contains(slot.slotId),
                onChanged: (value) => onToggle(slot.slotId, value ?? false),
              ),
              entries: [
                ('Subject', slot.subjectName),
                ('Day', slot.dayOfWeek),
                ('Period', slot.periodLabel),
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
            DataColumn(label: Text('Select')),
            DataColumn(label: Text('Class')),
            DataColumn(label: Text('Section')),
            DataColumn(label: Text('Subject')),
            DataColumn(label: Text('Day')),
            DataColumn(label: Text('Period')),
          ],
          rows: slots.map((slot) {
            final isSelected = selectedSlotIds.contains(slot.slotId);
            return DataRow(
              selected: isSelected,
              cells: [
                DataCell(
                  Checkbox(
                    key: ValueKey('teacher_reassignment_slot_${slot.slotId}'),
                    value: isSelected,
                    onChanged: (value) => onToggle(slot.slotId, value ?? false),
                  ),
                ),
                DataCell(Text(slot.className)),
                DataCell(Text(slot.sectionName)),
                DataCell(Text(slot.subjectName)),
                DataCell(Text(slot.dayOfWeek)),
                DataCell(Text(slot.periodLabel)),
              ],
            );
          }).toList(growable: false),
        ),
      ),
    );
  }
}

class _TeacherCandidatesPanel extends StatelessWidget {
  const _TeacherCandidatesPanel({
    required this.candidates,
    required this.selectedTeacher,
    required this.onSelect,
  });

  final List<TeacherReassignmentCandidate> candidates;
  final TeacherReassignmentCandidate? selectedTeacher;
  final ValueChanged<TeacherReassignmentCandidate> onSelect;

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AksharaSpacing.s4),
          child: Text('No target teachers available for selected periods.'),
        ),
      );
    }
    return Card(
      child: Column(
        children: candidates.map((candidate) {
          final selected = selectedTeacher?.teacherId == candidate.teacherId;
          return ListTile(
            key: ValueKey('teacher_reassignment_target_${candidate.teacherId}'),
            selected: selected,
            title: Text(candidate.teacherName),
            subtitle: Text(
              'Subjects: ${candidate.subjects.join(', ')} • Free: ${candidate.freePeriods} • Daily load: ${candidate.dailyLoad}',
            ),
            trailing: OutlinedButton(
              key: ValueKey(
                  'teacher_reassignment_select_${candidate.teacherId}'),
              onPressed: () => onSelect(candidate),
              child: Text(selected ? 'Selected' : 'Select'),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}
