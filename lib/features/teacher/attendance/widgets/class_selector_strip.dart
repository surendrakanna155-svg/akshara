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

  /// Fixed chrome inside a card: `EdgeInsets.all(s3)` top + bottom.
  static const double _cardVerticalPadding = AksharaSpacing.s3 * 2;

  /// Height of the two-line text block at the default 1.0× font scale.
  /// `_cardVerticalPadding + _textBlockHeight` == the original hard 72.
  static const double _textBlockHeight = 48;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    // A11y-P1: the strip used a hard `SizedBox(height: 72)` around a Column
    // whose natural height is 56dp. Past roughly 1.5× system font scale the
    // Column no longer fitted and the teacher attendance screen threw a
    // RenderFlex overflow — the yellow/black overflow banner, in production.
    //
    // A horizontal ListView needs a BOUNDED cross-axis extent, so a plain
    // minHeight constraint is not available here (it would leave the viewport
    // unbounded). Instead the height is composed: fixed card padding plus a
    // text block that scales with the system font setting. At 1.0× this is
    // exactly 72 — pixel-identical to before — and it grows only as the text
    // does.
    final stripHeight = _cardVerticalPadding +
        MediaQuery.textScalerOf(context).scale(_textBlockHeight);

    return Semantics(
      container: true,
      label: 'Class selector',
      child: SizedBox(
        height: stripHeight,
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
