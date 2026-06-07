import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../management_navigation.dart';
import '../management_models.dart';

class ManagementSubNav extends StatelessWidget {
  const ManagementSubNav({super.key, required this.current});

  final ManagementScreen current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Management module navigation',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final screen in kManagementNavScreens) ...[
              _ManagementSubNavTab(
                label: screen.label,
                selected: screen == current,
                onTap: () {
                  if (screen != current) {
                    context.go(screen.route);
                  }
                },
              ),
              if (screen != kManagementNavScreens.last)
                const SizedBox(width: AksharaSpacing.s2),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManagementSubNavTab extends StatelessWidget {
  const _ManagementSubNavTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label tab',
      child: Material(
        color: selected ? colors.primaryContainer : colors.surface,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AksharaSpacing.s4,
              vertical: AksharaSpacing.s2,
            ),
            child: Text(
              label,
              style: text.labelLarge.copyWith(
                color: selected ? colors.primary : colors.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
