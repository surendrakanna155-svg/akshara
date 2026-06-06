import 'package:flutter/material.dart';

import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../teacher_dashboard_provider.dart';

/// TA-01 class teacher dashboard entry card (conditional).
class ClassTeacherCard extends StatelessWidget {
  const ClassTeacherCard({
    super.key,
    required this.info,
    this.onTap,
  });

  final ClassTeacherInfo info;
  final VoidCallback? onTap;

  static const double cardHeight = 88;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: onTap != null,
      label: info.title,
      child: Material(
        color: colors.primary.withValues(alpha: 0.08),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.primary.withValues(alpha: 0.24)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AksharaRadius.card,
          child: SizedBox(
            height: cardHeight,
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s4),
              child: Row(
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 24,
                    color: colors.primary,
                  ),
                  const SizedBox(width: AksharaSpacing.s3),
                  Expanded(
                    child: Text(
                      info.title,
                      style: text.bodyLarge.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: colors.onSurfaceVariant,
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
