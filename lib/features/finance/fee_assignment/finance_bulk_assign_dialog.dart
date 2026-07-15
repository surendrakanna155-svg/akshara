import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/repositories/academic/academic_catalog_provider.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/forms/akshara_form_field.dart';
import '../../../shared/forms/akshara_searchable_dropdown.dart';
import '../../../shared/widgets/akshara_dialog.dart';
import '../../../shared/widgets/akshara_motion.dart';
import '../fee_structures/finance_fee_structures_provider.dart';
import '../finance_models.dart';
import '../finance_mutations_provider.dart';
import '../finance_requests.dart';
import 'finance_bulk_assign_provider.dart';

/// PRC-A gap fix — every fee-structure assignment used to be one student at a
/// time via the admissions-handoff queue. This dialog lets a finance manager
/// pick a fee structure + academic year, pick a class, and assign the
/// structure to every (or a chosen subset of) student in that class in a
/// single call, then shows the assigned/skipped report.
Future<void> showFinanceBulkAssignDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  // The screen this dialog is launched from doesn't otherwise fetch the full
  // student roster — await it here (mirrors showAssignFeeConcessionDialog's
  // "await reads before building the dialog" idiom) so the class/student
  // pickers below never see a transient empty list from an unloaded provider.
  await ref.read(financeFeeStructuresFutureProvider.future);
  await ref.read(financeBulkAssignStudentsFutureProvider.future);
  if (!context.mounted) return;

  final structures = ref.read(financeFeeStructuresProvider);
  if (structures.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create a fee structure before bulk-assigning one.'),
      ),
    );
    return;
  }

  // Cap 67 — the default fee structure (first in the list) may itself be
  // class/section-bound; when it is, resolve the roster FROM that binding
  // instead of defaulting to "the first class in the school". Falls back to
  // the pre-cap-67 default (first real class) when the structure is unbound.
  final defaultStructure = structures.first;
  final classes = ref.read(classOptionsProvider);
  ref.read(financeBulkAssignClassFilterProvider.notifier).state =
      defaultStructure.isClassBound
          ? defaultStructure.className
          : (classes.isNotEmpty ? classes.first : null);
  ref.read(financeBulkAssignSectionFilterProvider.notifier).state =
      defaultStructure.isClassBound ? defaultStructure.sectionName : null;

  var selectedStructureId = structures.first.id;
  var selectedYear = structures.first.academicYear;
  var selectedStudentIds = <String>{};

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (dialogContext) => AksharaAlertDialog(
      title: 'Bulk assign fee structure',
      icon: Icons.groups_outlined,
      scrollable: true,
      content: _BulkAssignForm(
        structures: structures,
        onChanged: ({
          required String structureId,
          required String academicYear,
          required Set<String> studentIds,
        }) {
          selectedStructureId = structureId;
          selectedYear = academicYear;
          selectedStudentIds = studentIds;
        },
      ),
      actions: [
        AksharaDialogActions(
          confirmLabel: 'Assign',
          confirmKey: QaTestKeys.financeBulkAssignSubmitButton,
          onCancel: () => Navigator.of(dialogContext).pop(false),
          onConfirm: () {
            if (selectedStructureId.isEmpty) return;
            if (selectedYear.trim().isEmpty) return;
            if (selectedStudentIds.isEmpty) return;
            Navigator.of(dialogContext).pop(true);
          },
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final result =
        await ref.read(bulkAssignFeeStructureProvider.notifier).execute(
              BulkAssignFeePlanRequest(
                feeStructureId: selectedStructureId,
                academicYear: selectedYear.trim(),
                studentIds: selectedStudentIds.toList(),
              ),
            );
    if (!context.mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bulk assignment could not be completed'),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.financeBulkAssignSuccessSnackbar,
        content: Text(
          result.skipped.isEmpty
              ? 'Assigned ${result.assigned.length} of ${result.total} '
                  'students'
              : 'Assigned ${result.assigned.length} of ${result.total} '
                  'students (${result.skipped.length} already had this '
                  'structure)',
        ),
      ),
    );
    await _showBulkAssignReport(context, result);
  } catch (error) {
    if (!context.mounted) return;
    final failure = error is ApiFailureException
        ? error.failure
        : apiFailureMapper.fromException(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure.message)),
    );
  }
}

/// The assigned/skipped report shown after a bulk assignment completes.
Future<void> _showBulkAssignReport(
  BuildContext context,
  BulkFeeAssignmentResult result,
) {
  return showAksharaDialog<void>(
    context: context,
    builder: (dialogContext) => AksharaAlertDialog(
      title: 'Bulk assignment report',
      icon: Icons.fact_check_outlined,
      scrollable: true,
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assigned (${result.assigned.length})',
              style: Theme.of(dialogContext).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (result.assigned.isEmpty)
              const Text('No students were newly assigned.')
            else
              for (final account in result.assigned)
                Text(
                  '• ${account.studentName.isEmpty ? account.admissionNumber : account.studentName}',
                ),
            if (result.skipped.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Already assigned — skipped (${result.skipped.length})',
                style: Theme.of(dialogContext).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (final skip in result.skipped)
                Text('• Student ${skip.studentId} (${skip.reason})'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: QaTestKeys.financeBulkAssignReportDoneButton,
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

typedef _BulkAssignFormChanged = void Function({
  required String structureId,
  required String academicYear,
  required Set<String> studentIds,
});

class _BulkAssignForm extends ConsumerStatefulWidget {
  const _BulkAssignForm({
    required this.structures,
    required this.onChanged,
  });

  final List<FinanceFeeStructure> structures;
  final _BulkAssignFormChanged onChanged;

  @override
  ConsumerState<_BulkAssignForm> createState() => _BulkAssignFormState();
}

class _BulkAssignFormState extends ConsumerState<_BulkAssignForm> {
  late String _structureId;
  late final TextEditingController _yearController;
  List<String> _lastRosterIds = const [];
  Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _structureId = widget.structures.first.id;
    _yearController =
        TextEditingController(text: widget.structures.first.academicYear)
          ..addListener(_notify);
    // Seed the initial selection from whatever roster is already loaded for
    // the class filter the launcher just set — "default all" per PRC-A spec.
    final roster = ref.read(financeBulkAssignClassRosterProvider);
    _lastRosterIds = [for (final s in roster) s.id];
    _selectedIds = _lastRosterIds.toSet();
  }

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(
      structureId: _structureId,
      academicYear: _yearController.text,
      studentIds: _selectedIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final roster = ref.watch(financeBulkAssignClassRosterProvider);
    final rosterIds = [for (final s in roster) s.id];
    // Default-select-all whenever the roster identity changes (a different
    // class was picked, or the async roster finished loading) — the finance
    // manager can still deselect individual students afterwards.
    if (!listEquals(rosterIds, _lastRosterIds)) {
      _lastRosterIds = rosterIds;
      _selectedIds = rosterIds.toSet();
      _notify();
    }

    final classes = ref.watch(classOptionsProvider);
    final classFilter = ref.watch(financeBulkAssignClassFilterProvider);

    final structureOptions = <String, String>{
      for (final s in widget.structures) s.id: '${s.name} (${s.academicYear})',
    };
    final structureIdByLabel = {
      for (final e in structureOptions.entries) e.value: e.key,
    };
    final allSelected = roster.isNotEmpty && _selectedIds.length == roster.length;
    final selectedStructure =
        widget.structures.firstWhere((s) => s.id == _structureId);

    return AksharaDialogFormBody(
      children: [
        AksharaSearchableDropdown(
          key: QaTestKeys.financeBulkAssignStructureField,
          label: 'Fee structure',
          value: structureOptions[_structureId] ?? structureOptions.values.first,
          options: structureOptions.values.toList(),
          onChanged: (label) {
            final id = structureIdByLabel[label];
            if (id == null) return;
            final structure = widget.structures.firstWhere((s) => s.id == id);
            setState(() {
              _structureId = id;
              _yearController.text = structure.academicYear;
            });
            // Cap 67 — a class/section-bound structure resolves the roster
            // FROM its binding; an unbound structure leaves the filters as
            // the finance manager already had them (no surprise reset).
            if (structure.isClassBound) {
              ref.read(financeBulkAssignClassFilterProvider.notifier).state =
                  structure.className;
              ref.read(financeBulkAssignSectionFilterProvider.notifier).state =
                  structure.sectionName;
            }
            _notify();
          },
        ),
        AksharaFormField(
          key: QaTestKeys.financeBulkAssignYearField,
          label: 'Academic year',
          controller: _yearController,
          required: true,
        ),
        if (selectedStructure.isClassBound)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              selectedStructure.sectionName != null
                  ? 'Bound to Class ${selectedStructure.className} · '
                      'Section ${selectedStructure.sectionName}'
                  : 'Bound to Class ${selectedStructure.className}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
        Material(
          child: DropdownMenu<String?>(
            key: QaTestKeys.financeBulkAssignClassField,
            initialSelection: classFilter,
            label: const Text('Class'),
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: [
              const DropdownMenuEntry(value: null, label: 'All classes'),
              for (final c in classes)
                DropdownMenuEntry(value: c, label: 'Class $c'),
            ],
            onSelected: (value) {
              ref.read(financeBulkAssignClassFilterProvider.notifier).state =
                  value;
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Students (${_selectedIds.length}/${roster.length})'),
            TextButton(
              key: QaTestKeys.financeBulkAssignSelectAllCheckbox,
              onPressed: roster.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _selectedIds =
                            allSelected ? {} : rosterIds.toSet();
                      });
                      _notify();
                    },
              child: Text(allSelected ? 'Deselect all' : 'Select all'),
            ),
          ],
        ),
        if (roster.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No students found for this class.'),
          )
        else
          // A plain Column, not a ListView: the dialog content is already
          // wrapped in a SingleChildScrollView (AksharaAlertDialog's
          // `scrollable: true`), and AlertDialog measures its content's
          // intrinsic width — a nested scrolling viewport (ListView) doesn't
          // support that and crashes ("does not support returning intrinsic
          // dimensions"). The outer scroll view handles overflow instead.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final student in roster)
                CheckboxListTile(
                  key: QaTestKeys.financeBulkAssignStudentCheckbox(
                    student.id,
                  ),
                  dense: true,
                  value: _selectedIds.contains(student.id),
                  title: Text(student.studentName),
                  subtitle: Text(
                    '${student.admissionNumber} · Class '
                    '${student.classLabel}',
                  ),
                  onChanged: (checked) {
                    setState(() {
                      if (checked ?? false) {
                        _selectedIds.add(student.id);
                      } else {
                        _selectedIds.remove(student.id);
                      }
                    });
                    _notify();
                  },
                ),
            ],
          ),
      ],
    );
  }
}
