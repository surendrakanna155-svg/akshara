import 'package:flutter/material.dart';

import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'akshara_motion.dart';

/// Full-area centered loading indicator for screen bodies.
///
/// Supply [skeleton] to render a content-shaped placeholder (see
/// [AksharaSkeleton]) instead of the centered spinner — the widget stays the
/// canonical "loading" surface (same type + `Loading` semantics) either way.
class AksharaLoadingState extends StatelessWidget {
  const AksharaLoadingState({
    super.key,
    this.semanticLabel = 'Loading',
    this.skeleton,
  });

  final String semanticLabel;

  /// Optional skeleton placeholder rendered instead of the centered spinner.
  final Widget? skeleton;

  @override
  Widget build(BuildContext context) {
    final skeleton = this.skeleton;
    if (skeleton != null) {
      return AksharaMotionAppear(
        scale: false,
        child: Semantics(
          label: semanticLabel,
          container: true,
          child: ExcludeSemantics(child: skeleton),
        ),
      );
    }

    final colors = context.colors;
    final showCaption = semanticLabel.trim().isNotEmpty &&
        semanticLabel.toLowerCase() != 'loading';

    return AksharaMotionAppear(
      scale: false,
      child: Semantics(
      label: semanticLabel,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: AksharaRadius.chip,
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              alignment: Alignment.center,
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colors.primary,
                ),
              ),
            ),
            if (showCaption) ...[
              const SizedBox(height: AksharaSpacing.s3),
              Text(
                semanticLabel,
                style: context.text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
