import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/testing/qa_test_keys.dart';
import '../../../../core/timetable/timetable_generation_inputs.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../timetable_editor_tab.dart';
import '../timetable_models.dart';
import '../timetable_provider.dart';
import 'daily_substitutions_provider.dart';

/// Coordinator/principal view of a day's cover: server-resolved substitutions
/// and on-leave teachers, with real create/delete against the backend.
class DailySubstitutionsScreen extends ConsumerWidget {
  const DailySubstitutionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleAsync = ref.watch(dailySubstitutionsProvider);
    final canManage = ref.watch(substitutionCanManageProvider);
    final colors = context.colors;
    final date = ref.watch(selectedTimetableDateProvider);
    final teacherDirectory = mockTimetableTeacherDirectory();

    String teacherName(String? id) {
      if (id == null || id.isEmpty) return 'Unassigned';
      return teacherDirectory[id] ?? id;
    }

    return Scaffold(
      backgroundColor: colors.surfaceContainerLow,
      appBar: AppBar(title: const Text('Timetable & cover')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              key: QaTestKeys.dailySubstitutionsAddButton,
              onPressed: () => _openAddCoverSheet(context, ref, teacherDirectory),
              icon: const Icon(Icons.add),
              label: const Text('Add cover'),
            )
          : null,
      body: Column(
        children: [
          _DateStrip(date: date),
          Expanded(
            child: bundleAsync.when(
              loading: () => const AksharaLoadingState(
                semanticLabel: 'Loading cover for the day',
              ),
              error: (_, __) => AksharaErrorState(
                message: 'Unable to load the day\'s cover.',
                onRetry: () => ref.invalidate(dailySubstitutionsProvider),
              ),
              data: (bundle) => _DayBody(
                bundle: bundle,
                canManage: canManage,
                teacherName: teacherName,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddCoverSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> teacherDirectory,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddCoverSheet(teacherDirectory: teacherDirectory),
    );
  }
}

class _DateStrip extends ConsumerWidget {
  const _DateStrip({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AksharaSpacing.s3),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => stepSelectedDate(ref, -1),
          ),
          Expanded(
            child: Text(
              '${date.day}/${date.month}/${date.year}',
              textAlign: TextAlign.center,
              style: text.titleSmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => stepSelectedDate(ref, 1),
          ),
        ],
      ),
    );
  }
}

class _DayBody extends ConsumerWidget {
  const _DayBody({
    required this.bundle,
    required this.canManage,
    required this.teacherName,
  });

  final DailySubstitutionsBundle bundle;
  final bool canManage;
  final String Function(String?) teacherName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.aksharaText;
    final onLeaveNames = [
      for (final t in bundle.onLeave) teacherName(t.teacherId),
    ];

    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        Material(
          color: colors.surfaceContainerHighest,
          borderRadius: AksharaRadius.card,
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s3),
            child: Text(
              onLeaveNames.isEmpty
                  ? 'No teachers on approved leave this day — full timetable runs as scheduled.'
                  : 'On approved leave: ${onLeaveNames.join(', ')}. Assign cover for their classes below.',
              style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ),
        const SizedBox(height: AksharaSpacing.s4),
        const AksharaSectionHeader(title: 'Assigned cover', fixedHeight: false),
        const SizedBox(height: AksharaSpacing.s2),
        if (bundle.substitutions.isEmpty)
          const AksharaEmptyState(
            message: 'No cover assigned for this day yet.',
            icon: Icons.event_available_outlined,
          )
        else
          for (final sub in bundle.substitutions)
            Padding(
              padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
              child: _SubstitutionRow(
                substitution: sub,
                canManage: canManage,
                teacherName: teacherName,
              ),
            ),
      ],
    );
  }
}

class _SubstitutionRow extends ConsumerWidget {
  const _SubstitutionRow({
    required this.substitution,
    required this.canManage,
    required this.teacherName,
  });

  final TimetableSubstitution substitution;
  final bool canManage;
  final String Function(String?) teacherName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.aksharaText;
    final s = substitution;

    final slotParts = <String>[
      if (s.periodNumber != null) 'Period ${s.periodNumber}',
      if (s.subjectLabel != null && s.subjectLabel!.isNotEmpty) s.subjectLabel!,
    ];
    final slotLabel = slotParts.isEmpty ? 'Cover' : slotParts.join(' · ');

    return Material(
      key: QaTestKeys.dailySubstitutionRow(s.id),
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AksharaRadius.card,
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s3),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slotLabel, style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    s.originalTeacherId == null || s.originalTeacherId!.isEmpty
                        ? teacherName(s.substituteTeacherId)
                        : '${teacherName(s.substituteTeacherId)} '
                            '(covering ${teacherName(s.originalTeacherId)})',
                    style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const AksharaStatusChip(label: 'Substitute', tone: KpiAccent.warning),
            if (canManage)
              IconButton(
                key: QaTestKeys.dailySubstitutionDeleteButton(s.id),
                tooltip: 'Remove cover',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context, ref),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(substitutionMutationsProvider.notifier).delete(substitution.id);
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        key: QaTestKeys.dailySubstitutionsDeletedSnackbar,
        content: Text('Cover removed.'),
      ),
    );
  }
}

/// Bottom sheet to assign a new cover: pick a period from the school grid and a
/// substitute teacher, then create against the backend.
class _AddCoverSheet extends ConsumerStatefulWidget {
  const _AddCoverSheet({required this.teacherDirectory});

  final Map<String, String> teacherDirectory;

  @override
  ConsumerState<_AddCoverSheet> createState() => _AddCoverSheetState();
}

class _AddCoverSheetState extends ConsumerState<_AddCoverSheet> {
  String? _periodId;
  String? _teacherId;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final selectedTimetableId =
        ref.watch(timetableSelectedIdProvider) ?? 'tt_mock_2';
    final detailAsync =
        ref.watch(timetableEditorDetailProvider(selectedTimetableId));

    return Padding(
      padding: EdgeInsets.only(
        left: AksharaSpacing.s4,
        right: AksharaSpacing.s4,
        top: AksharaSpacing.s4,
        bottom: MediaQuery.of(context).viewInsets.bottom + AksharaSpacing.s4,
      ),
      child: detailAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AksharaSpacing.s4),
          child: AksharaLoadingState(semanticLabel: 'Loading periods'),
        ),
        error: (_, __) => const AksharaErrorState(
          message: 'Unable to load periods to cover.',
        ),
        data: (detail) => _form(context, detail.periods),
      ),
    );
  }

  Widget _form(BuildContext context, List<TimetablePeriod> periods) {
    final text = context.aksharaText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Assign cover', style: text.titleMedium),
        const SizedBox(height: AksharaSpacing.s3),
        DropdownButtonFormField<String>(
          key: QaTestKeys.dailySubstitutionsPeriodPicker,
          initialValue: _periodId,
          decoration: const InputDecoration(labelText: 'Period to cover'),
          items: [
            for (final p in periods)
              DropdownMenuItem(
                value: p.id,
                child: Text(
                  'Day ${p.dayOfWeek} · P${p.periodNumber} · ${p.subjectLabel}',
                ),
              ),
          ],
          onChanged: (v) => setState(() => _periodId = v),
        ),
        const SizedBox(height: AksharaSpacing.s3),
        DropdownButtonFormField<String>(
          key: QaTestKeys.dailySubstitutionsTeacherPicker,
          initialValue: _teacherId,
          decoration: const InputDecoration(labelText: 'Substitute teacher'),
          items: [
            for (final entry in widget.teacherDirectory.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (v) => setState(() => _teacherId = v),
        ),
        const SizedBox(height: AksharaSpacing.s4),
        FilledButton(
          key: QaTestKeys.dailySubstitutionsSaveButton,
          onPressed: _canSubmit ? _submit : null,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Assign cover'),
        ),
      ],
    );
  }

  bool get _canSubmit =>
      !_submitting &&
      _periodId != null &&
      _periodId!.isNotEmpty &&
      _teacherId != null &&
      _teacherId!.isNotEmpty;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(substitutionMutationsProvider.notifier).create(
            periodId: _periodId!,
            substituteTeacherId: _teacherId!,
          );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          key: QaTestKeys.dailySubstitutionsCreatedSnackbar,
          content: Text('Cover assigned.'),
        ),
      );
    } on SubstituteBusyException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(
          key: QaTestKeys.dailySubstitutionsBusyError,
          content: Text(e.message),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not assign cover. Please try again.')),
      );
    }
  }
}
