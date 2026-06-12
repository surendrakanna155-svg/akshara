import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Context chip shown beside app bar titles (period, class, etc.).
class AksharaContextChip extends StatelessWidget {
  const AksharaContextChip({
    super.key,
    required this.label,
    required this.semanticLabel,
    this.fontWeight = FontWeight.w500,
  });

  final String label;
  final String semanticLabel;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AksharaSpacing.s3,
          vertical: AksharaSpacing.s1,
        ),
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: text.bodySmall.copyWith(
            color: colors.onPrimaryContainer,
            fontWeight: fontWeight,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
