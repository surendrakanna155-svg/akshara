import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../profile_models.dart';

/// Linked child row with active indicator for PA-09.
class ProfileChildRow extends StatelessWidget {
  const ProfileChildRow({
    super.key,
    required this.child,
    this.onTap,
  });

  final ParentChildProfile child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: onTap != null,
      label: child.isActive
          ? 'Active child ${child.name}, class ${child.classLabel}'
          : '${child.name}, class ${child.classLabel}. Tap to switch.',
      selected: child.isActive,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AksharaSpacing.s2),
          side: BorderSide(
            color: child.isActive ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AksharaSpacing.s2),
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AksharaSpacing.s4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colors.primaryContainer,
                    child: Text(
                      child.name.isNotEmpty
                          ? child.name[0].toUpperCase()
                          : '?',
                      style: text.titleSmall.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s3),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child.name,
                          style: text.titleSmall.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                        Text(
                          'Class ${child.classLabel}',
                          style: text.bodySmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (child.isActive)
                    const AksharaStatusChip(
                      label: 'Active',
                      tone: KpiAccent.success,
                      size: AksharaStatusChipSize.compact,
                    )
                  else
                    Icon(
                      Icons.chevron_right,
                      size: 20,
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
