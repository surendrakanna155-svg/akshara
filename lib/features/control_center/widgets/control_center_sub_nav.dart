import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../control_center_navigation.dart';
import '../control_center_models.dart';

class ControlCenterSubNav extends StatelessWidget {
  const ControlCenterSubNav({super.key, required this.current});

  final ControlCenterScreen current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Control Center module navigation',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final screen in kControlCenterNavScreens) ...[
              _ControlCenterSubNavTab(
                label: screen.label,
                selected: screen == current,
                onTap: () {
                  if (screen != current) {
                    context.go(screen.route);
                  }
                },
              ),
              if (screen != kControlCenterNavScreens.last)
                const SizedBox(width: AksharaSpacing.s2),
            ],
          ],
        ),
      ),
    );
  }
}

class _ControlCenterSubNavTab extends StatelessWidget {
  const _ControlCenterSubNavTab({
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
        key: QaTestKeys.moduleSubNavTab('controlCenter', label),
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
