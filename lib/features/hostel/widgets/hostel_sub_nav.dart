import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../hostel_navigation.dart';
import '../hostel_models.dart';

class HostelSubNav extends StatelessWidget {
  const HostelSubNav({super.key, required this.current});

  final HostelScreen current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Hostel module navigation',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final screen in kHostelNavScreens) ...[
              _HostelSubNavTab(
                label: screen.label,
                selected: screen == current,
                onTap: () {
                  if (screen != current) {
                    context.go(screen.route);
                  }
                },
              ),
              if (screen != kHostelNavScreens.last)
                const SizedBox(width: AksharaSpacing.s2),
            ],
          ],
        ),
      ),
    );
  }
}

class _HostelSubNavTab extends StatelessWidget {
  const _HostelSubNavTab({
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
