import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'teacher_today_provider.dart';

/// A teacher's classes for today, including any cover assigned to them.
class TeacherTodayScreen extends ConsumerWidget {
  const TeacherTodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periods = ref.watch(teacherTodayScheduleProvider);
    final colors = context.colors;
    final text = context.aksharaText;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLow,
      appBar: AppBar(title: const Text("Today's classes")),
      body: periods.isEmpty
          ? const AksharaEmptyState(
              icon: Icons.event_available_outlined,
              message: 'No classes scheduled for you today.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AksharaSpacing.s4),
              itemCount: periods.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AksharaSpacing.s3),
              itemBuilder: (context, i) {
                final p = periods[i];
                return Material(
                  color: colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: AksharaRadius.card,
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  child: InkWell(
                    // TCH-1 — tapping a period jumps to attendance marking with
                    // this class pre-selected.
                    borderRadius: AksharaRadius.card,
                    onTap: () => context.go(
                      '${RouteNames.teacherAttendance}'
                      '?class=${Uri.encodeQueryComponent(p.classLabel)}',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AksharaSpacing.s3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${p.periodLabel} · ${p.classLabel}',
                                    style: text.titleSmall),
                                const SizedBox(height: 2),
                                Text(p.subject,
                                    style: text.bodySmall.copyWith(
                                        color: colors.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          if (p.isSubstitute)
                            AksharaStatusChip(
                              label: 'Covering ${p.originalTeacherName}',
                              tone: KpiAccent.warning,
                            ),
                          const SizedBox(width: AksharaSpacing.s2),
                          Icon(Icons.chevron_right,
                              color: colors.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
