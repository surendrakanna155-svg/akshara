import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/timetable/daily_timetable_engine.dart';
import '../../../../core/timetable/mock_daily_timetable_store.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import 'daily_substitutions_provider.dart';

/// Coordinator/principal view of today's auto-substitutions, with override.
class DailySubstitutionsScreen extends ConsumerWidget {
  const DailySubstitutionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = ref.watch(dailySubstitutionGridProvider);
    final onLeave = ref.watch(teachersOnLeaveForSelectedDateProvider);
    final colors = context.colors;
    final text = context.aksharaText;

    // Group periods by period id, in order.
    final periodIds = <String>[];
    for (final p in grid) {
      if (!periodIds.contains(p.periodId)) periodIds.add(p.periodId);
    }

    final date = ref.watch(selectedTimetableDateProvider);
    final onLeaveNames = [
      for (final t in MockDailyTimetableStore.teachers)
        if (onLeave.contains(t.id)) t.name,
    ];

    return Scaffold(
      backgroundColor: colors.surfaceContainerLow,
      appBar: AppBar(title: const Text('Timetable & cover')),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          Row(
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
          const SizedBox(height: AksharaSpacing.s2),
          Material(
            color: colors.surfaceContainerHighest,
            borderRadius: AksharaRadius.card,
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s3),
              child: Text(
                onLeaveNames.isEmpty
                    ? 'No teachers on approved leave this day — full timetable runs as scheduled.'
                    : 'On approved leave: ${onLeaveNames.join(', ')}. Their classes are auto-covered below.',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          for (final pid in periodIds) ...[
            AksharaSectionHeader(
              title: grid.firstWhere((p) => p.periodId == pid).periodLabel,
              fixedHeight: false,
            ),
            const SizedBox(height: AksharaSpacing.s2),
            for (final p in grid.where((p) => p.periodId == pid))
              _PeriodRow(period: p),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      ),
    );
  }
}

class _PeriodRow extends ConsumerWidget {
  const _PeriodRow({required this.period});

  final ScheduledPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.aksharaText;

    final (badgeLabel, badgeTone) = period.isUnfilled
        ? ('Needs cover', KpiAccent.error)
        : period.isSubstitute
            ? ('Substitute', KpiAccent.warning)
            : ('Scheduled', KpiAccent.neutral);

    return Material(
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
                  Text('${period.classLabel} · ${period.subject}',
                      style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    period.isUnfilled
                        ? 'No free teacher (was ${period.originalTeacherName})'
                        : period.isSubstitute
                            ? '${period.teacherName} (covering ${period.originalTeacherName})'
                            : period.teacherName,
                    style: text.bodySmall
                        .copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            AksharaStatusChip(label: badgeLabel, tone: badgeTone),
            if (period.isSubstitute || period.isUnfilled)
              PopupMenuButton<TimetableTeacher>(
                tooltip: 'Reassign',
                icon: const Icon(Icons.edit_outlined),
                onSelected: (t) => overrideSubstitution(
                  ref,
                  periodId: period.periodId,
                  classLabel: period.classLabel,
                  teacher: t,
                ),
                itemBuilder: (_) => [
                  for (final t in MockDailyTimetableStore.teachers)
                    PopupMenuItem(value: t, child: Text(t.name)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
