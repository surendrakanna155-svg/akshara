import 'package:flutter/material.dart';

import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../semantic_status.dart';

/// ST-01 schedule period pill (96px card with Now/Next/Later states).
class AksharaPeriodPill extends StatelessWidget {
  const AksharaPeriodPill({
    super.key,
    required this.timeLabel,
    required this.subject,
    required this.teacherName,
    required this.state,
    required this.width,
    this.onTap,
    this.semanticLabel,
  });

  final String timeLabel;
  final String subject;
  final String teacherName;
  final PeriodState state;
  final double width;
  final VoidCallback? onTap;
  final String? semanticLabel;

  static const double pillHeight = 96;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final surface = state.resolveSurface(context);
    final stateLabel = state.label;

    return Semantics(
      button: onTap != null,
      label: semanticLabel ??
          '$timeLabel, $subject with $teacherName, $stateLabel',
      child: Material(
        color: surface.background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(
            color: surface.border,
            width: surface.borderWidth,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AksharaRadius.card,
          child: SizedBox(
            width: width,
            height: pillHeight,
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeLabel,
                    style: text.labelMedium.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AksharaSpacing.s1),
                  Expanded(
                    child: Text(
                      subject,
                      style: text.bodyMedium.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    teacherName,
                    style: text.bodySmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stateLabel,
                    style: text.labelSmall.copyWith(
                      color: state.resolveStateTextColor(context),
                      fontWeight: FontWeight.w600,
                    ),
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
