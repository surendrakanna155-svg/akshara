import 'package:flutter/material.dart';

import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// AI insight strip shared across parent, teacher, and student dashboards.
class AksharaInsightCard extends StatelessWidget {
  const AksharaInsightCard({
    super.key,
    required this.message,
    required this.actionLabel,
    this.onAction,
    this.accent = KpiAccent.primary,
    this.icon = Icons.psychology_outlined,
    this.semanticLabelPrefix = 'AI insight',
  });

  final String message;
  final String actionLabel;
  final VoidCallback? onAction;
  final KpiAccent accent;
  final IconData icon;
  final String semanticLabelPrefix;

  static const double cardHeight = 88;
  static const double accentWidth = 4;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final accentColors = accent.resolve(context);

    return Semantics(
      container: true,
      label: '$semanticLabelPrefix: $message',
      child: Material(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: SizedBox(
          height: cardHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: accentWidth,
                decoration: BoxDecoration(
                  color: accentColors.foreground,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AksharaRadius.md),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AksharaSpacing.s4,
                    vertical: AksharaSpacing.s3,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 24,
                        color: accentColors.foreground,
                      ),
                      const SizedBox(width: AksharaSpacing.s3),
                      Expanded(
                        child: Text(
                          message,
                          style: text.bodyMedium.copyWith(
                            color: colors.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onAction != null) ...[
                        const SizedBox(width: AksharaSpacing.s2),
                        TextButton(
                          onPressed: onAction,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AksharaSpacing.s2,
                            ),
                            minimumSize: const Size(
                              AksharaSpacing.minTouchTarget,
                              AksharaSpacing.minTouchTarget,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            actionLabel,
                            style: text.labelLarge.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
