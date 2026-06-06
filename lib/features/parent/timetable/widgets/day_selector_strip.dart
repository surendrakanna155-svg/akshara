import 'package:flutter/material.dart';

import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../timetable_models.dart';

/// Horizontal weekday selector for timetable.
class DaySelectorStrip extends StatelessWidget {
  const DaySelectorStrip({
    super.key,
    required this.days,
    required this.onDayTap,
  });

  final List<TimetableDay> days;
  final ValueChanged<String> onDayTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: AksharaSpacing.s2),
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = day.isSelected;

          return Semantics(
            button: true,
            selected: selected,
            label: '${day.fullLabel}, ${day.date.day}',
            child: Material(
              color: selected ? colors.primaryContainer : colors.surface,
              borderRadius: AksharaRadius.chip,
              child: InkWell(
                onTap: () => onDayTap(day.id),
                borderRadius: AksharaRadius.chip,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AksharaSpacing.s3,
                    vertical: AksharaSpacing.s2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: AksharaRadius.chip,
                    border: Border.all(
                      color: selected ? colors.primary : colors.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        day.shortLabel,
                        style: context.aksharaText.labelLarge.copyWith(
                          color: selected ? colors.primary : colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (day.isToday) ...[
                        const SizedBox(width: AksharaSpacing.s1),
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: selected
                              ? colors.primary
                              : context.akshara.success,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
