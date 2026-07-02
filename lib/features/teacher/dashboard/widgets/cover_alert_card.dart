import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../timetable/teacher_today_provider.dart';

/// TCH-4 — a home alert surfaced when the teacher has been assigned to COVER one
/// or more classes today (from the daily-substitution overlay). Hidden when the
/// teacher has no cover duty. Tapping opens the timetable.
class CoverAlertCard extends ConsumerWidget {
  const CoverAlertCard({super.key, this.onOpenTimetable});

  final VoidCallback? onOpenTimetable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(teacherTodayScheduleProvider);
    final covering = today.where((p) => p.isSubstitute).toList();
    if (covering.isEmpty) return const SizedBox.shrink();

    final classes = covering.map((p) => p.classLabel).toSet().join(', ');
    final message = covering.length == 1
        ? 'You are covering ${covering.first.classLabel} '
            '(${covering.first.subject}) today.'
        : 'You are covering ${covering.length} classes today: $classes.';

    return AksharaWarningBanner(
      message: message,
      actionLabel: 'View timetable',
      onAction: onOpenTimetable,
      compactMessage: true,
    );
  }
}
