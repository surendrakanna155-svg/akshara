import 'package:flutter/material.dart';

import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../attendance_models.dart';

/// Horizontal class selector for TA-02.
class ClassSelectorStrip extends StatelessWidget {
  const ClassSelectorStrip({
    super.key,
    required this.classes,
    required this.selectedClassId,
    required this.onClassSelected,
  });

  final List<TeacherAttendanceClass> classes;
  final String selectedClassId;
  final ValueChanged<String> onClassSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Class selector',
      child: SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: classes.length,
          separatorBuilder: (_, __) => const SizedBox(width: AksharaSpacing.s2),
          itemBuilder: (context, index) {
            final item = classes[index];
            final selected = item.id == selectedClassId;

            return Semantics(
              button: true,
              selected: selected,
              label: '${item.label} ${item.periodLabel}',
              child: Material(
                color: selected ? colors.primaryContainer : colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: AksharaRadius.card,
                  side: BorderSide(
                    color: selected ? colors.primary : colors.outlineVariant,
                  ),
                ),
                child: InkWell(
                  onTap: () => onClassSelected(item.id),
                  borderRadius: AksharaRadius.card,
                  child: SizedBox(
                    width: 132,
                    child: Padding(
                      padding: const EdgeInsets.all(AksharaSpacing.s3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.label} · ${item.subject}',
                            style: text.labelMedium.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            item.periodLabel,
                            style: text.bodySmall.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
