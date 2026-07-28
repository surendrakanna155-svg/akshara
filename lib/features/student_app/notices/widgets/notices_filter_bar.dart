import 'package:flutter/material.dart';

import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../notices_models.dart';

/// Scope filter chips for ST-06 notices.
class NoticesFilterBar extends StatelessWidget {
  const NoticesFilterBar({
    super.key,
    required this.selectedScope,
    required this.onScopeChanged,
  });

  final StudentNoticeScope selectedScope;
  final ValueChanged<StudentNoticeScope> onScopeChanged;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return Semantics(
      container: true,
      label: 'Notice scope filters',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final scope in StudentNoticeScope.values) ...[
              FilterChip(
                label: Text(scope.label),
                selected: selectedScope == scope,
                onSelected: (_) => onScopeChanged(scope),
                showCheckmark: false,
                labelStyle: text.labelMedium.copyWith(
                  color: selectedScope == scope
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                selectedColor: colors.primaryContainer,
                backgroundColor: colors.surface,
                side: BorderSide(color: colors.outlineVariant),
                // A11y-P1 tap target: the local
                // `MaterialTapTargetSize.shrinkWrap` cancelled the theme's 48dp
                // floor, leaving Flutter's bare 32dp `_kChipHeight`. Removed —
                // `padded` wraps the chip in a >=48dp redirecting hit target
                // while the painted pill stays the same size.
              ),
              if (scope != StudentNoticeScope.values.last)
                const SizedBox(width: AksharaSpacing.s2),
            ],
          ],
        ),
      ),
    );
  }
}
