import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/timetable/timetable_generation_inputs.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import 'timetable_models.dart';
import 'timetable_provider.dart';

final timetableEditorDetailProvider = FutureProvider.family<TimetableDetail, String>((ref, id) {
  return ref.read(timetableRepositoryProvider).getTimetable(
        query: ref.watch(timetableQueryProvider),
        timetableId: id,
      );
});

/// v15.3 — Drag-and-drop timetable period editor with teacher reassignment.
class TimetableEditorTab extends ConsumerStatefulWidget {
  const TimetableEditorTab({super.key});

  @override
  ConsumerState<TimetableEditorTab> createState() => _TimetableEditorTabState();
}

class _TimetableEditorTabState extends ConsumerState<TimetableEditorTab> {
  List<TimetablePeriod>? _periods;
  final Map<String, String> _teacherDirectory = mockTimetableTeacherDirectory();

  String _teacherName(String? id) {
    if (id == null || id.isEmpty) return 'Unassigned';
    return _teacherDirectory[id] ?? id;
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(timetableSelectedIdProvider) ?? 'tt_mock_2';
    final detailAsync = ref.watch(timetableEditorDetailProvider(selectedId));
    final canManage = ref.watch(timetableCanManageProvider);

    return detailAsync.when(
      loading: () => const AksharaLoadingState(semanticLabel: 'Loading timetable editor'),
      error: (_, __) => AksharaErrorState(
        message: 'Unable to load timetable for editing.',
        onRetry: () => ref.invalidate(timetableEditorDetailProvider(selectedId)),
      ),
      data: (detail) {
        _periods ??= List<TimetablePeriod>.from(detail.periods);
        final periods = _periods!;
        final periodsPerDay = detail.timetable.periodsPerDay;
        if (periods.isEmpty) {
          return const AksharaEmptyState(message: 'No periods to edit.');
        }
        return ReorderableListView.builder(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          itemCount: periods.length,
          // ignore: deprecated_member_use
          onReorder: canManage
              ? (oldIndex, newIndex) async {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = periods.removeAt(oldIndex);
                    periods.insert(newIndex, item);
                  });
                  final moved = periods[newIndex.clamp(0, periods.length - 1)];
                  final targetPeriod = (newIndex % periodsPerDay) + 1;
                  final targetDay = (newIndex ~/ periodsPerDay) + 1;
                  await ref.read(timetableRepositoryProvider).movePeriod(
                        query: ref.read(timetableQueryProvider),
                        request: MoveTimetablePeriodRequest(
                          periodId: moved.id,
                          targetDayOfWeek: targetDay,
                          targetPeriodNumber: targetPeriod,
                        ),
                      );
                  ref.invalidate(timetableConflictsProvider);
                }
              : (_, __) {},
          itemBuilder: (context, index) {
            final period = periods[index];
            return ListTile(
              key: ValueKey(period.id),
              leading: const Icon(Icons.drag_handle),
              title: Text('${period.subjectLabel} · Day ${period.dayOfWeek} P${period.periodNumber}'),
              subtitle: Text('${_teacherName(period.teacherId)} · Room ${period.roomLabel}'),
              trailing: canManage
                  ? PopupMenuButton<String>(
                      tooltip: 'Change teacher',
                      icon: const Icon(Icons.person_outline),
                      onSelected: (teacherId) =>
                          _reassign(period, teacherId, index),
                      itemBuilder: (_) => [
                        for (final entry in _teacherDirectory.entries)
                          PopupMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                    )
                  : (period.roomLabel.toLowerCase().contains('lab')
                      ? const Chip(label: Text('Lab'))
                      : null),
            );
          },
        );
      },
    );
  }

  Future<void> _reassign(
      TimetablePeriod period, String teacherId, int index) async {
    final updated = await ref
        .read(timetableRepositoryProvider)
        .reassignPeriodTeacher(
          query: ref.read(timetableQueryProvider),
          request: ReassignPeriodTeacherRequest(
            periodId: period.id,
            teacherId: teacherId,
          ),
        );
    if (!mounted) return;
    setState(() => _periods![index] = updated);
    ref.invalidate(timetableConflictsProvider);
  }
}
