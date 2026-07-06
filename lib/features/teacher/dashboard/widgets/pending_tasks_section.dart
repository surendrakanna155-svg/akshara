import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../teacher_dashboard_provider.dart';
import '../../../../theme/breakpoints.dart';

/// TA-01 pending tasks grid — 2 tiles per row on mobile.
class PendingTasksSection extends StatelessWidget {
  const PendingTasksSection({
    super.key,
    required this.tasks,
    this.onTaskTap,
    this.largeMobileBreakpoint = AksharaBreakpoints.largeMobileMinWidth,
    this.tabletBreakpoint = AksharaBreakpoints.tabletMinWidth,
  });

  final List<PendingTask> tasks;
  final void Function(PendingTask task)? onTaskTap;
  final double largeMobileBreakpoint;
  final double tabletBreakpoint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Pending tasks, ${tasks.length} items',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AksharaSectionHeader(
            title: 'Tasks',
            fixedHeight: false,
            spacingBelow: AksharaSpacing.s3,
          ),
          if (tasks.isEmpty)
            const AksharaSectionEmpty(
              message: 'All caught up — no pending tasks.',
              icon: Icons.task_alt_outlined,
            )
          else
            LayoutBuilder(
            builder: (context, constraints) {
              final isLargeMobile =
                  constraints.maxWidth >= largeMobileBreakpoint;
              final tileWidth = isLargeMobile ? 190.0 : 173.0;

              return Wrap(
                spacing: AksharaSpacing.s3,
                runSpacing: AksharaSpacing.s3,
                children: [
                  for (final task in tasks)
                    SizedBox(
                      width: constraints.maxWidth >= tabletBreakpoint
                          ? (constraints.maxWidth - AksharaSpacing.s3) / 2
                          : tileWidth,
                      child: _TaskTile(
                        task: task,
                        onTap: onTaskTap == null
                            ? null
                            : () => onTaskTap!(task),
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
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    this.onTap,
  });

  final PendingTask task;
  final VoidCallback? onTap;

  static const double tileHeight = 80;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    // TCH-2 — an overdue task (past its deadline) is drawn in the error tone.
    final accent = task.overdue ? colors.error : colors.primary;

    return Semantics(
      button: onTap != null,
      label: '${task.count} ${task.label}',
      child: Material(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AksharaRadius.card,
          child: SizedBox(
            height: tileHeight,
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(
                        task.icon,
                        size: 24,
                        color: accent,
                      ),
                      const Spacer(),
                      Text(
                        '${task.count}',
                        style: text.headlineSmall.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AksharaSpacing.s1),
                  Text(
                    task.label,
                    style: text.bodySmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
