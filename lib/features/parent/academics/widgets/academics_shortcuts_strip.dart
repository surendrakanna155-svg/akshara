import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';

/// Quick links from Academics area to timetable, homework, and exams.
class AcademicsShortcutsStrip extends StatelessWidget {
  const AcademicsShortcutsStrip({
    super.key,
    this.onTimetableTap,
    this.onHomeworkTap,
    this.onExamsTap,
  });

  final VoidCallback? onTimetableTap;
  final VoidCallback? onHomeworkTap;
  final VoidCallback? onExamsTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Academic shortcuts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AksharaSectionHeader(
            title: 'Academics',
            fixedHeight: false,
            spacingBelow: AksharaSpacing.s3,
          ),
          Row(
            children: [
              Expanded(
                child: _ShortcutTile(
                  icon: Icons.calendar_view_week_outlined,
                  label: 'Timetable',
                  onTap: onTimetableTap,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: _ShortcutTile(
                  icon: Icons.assignment_outlined,
                  label: 'Homework',
                  onTap: onHomeworkTap,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: _ShortcutTile(
                  icon: Icons.grading_outlined,
                  label: 'Exams',
                  onTap: onExamsTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s1),
          Text(
            'View schedule, assignments, and exam updates for your child.',
            style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: onTap != null,
      label: label,
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
            height: 88,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AksharaSpacing.s2,
                vertical: AksharaSpacing.s2,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22, color: colors.primary),
                  const SizedBox(height: AksharaSpacing.s1),
                  Text(
                    label,
                    style: text.labelMedium.copyWith(color: colors.onSurface),
                    textAlign: TextAlign.center,
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
