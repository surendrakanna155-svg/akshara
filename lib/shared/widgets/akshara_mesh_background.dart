import 'package:flutter/material.dart';

import '../../theme/mesh_background.dart';
import '../../theme/theme_extensions.dart';

/// Full-bleed mesh gradient atmosphere behind dashboard content (M15.5).
class AksharaMeshBackground extends StatelessWidget {
  const AksharaMeshBackground({
    super.key,
    required this.palette,
    required this.child,
    this.baseColor,
  });

  final AksharaMeshPalette palette;
  final Widget child;
  final Color? baseColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mesh = AksharaMeshTokens.colors(palette, colors);
    final base = baseColor ?? colors.surfaceContainerLowest;

    return DecoratedBox(
      decoration: BoxDecoration(color: base),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.65, -0.85),
                    radius: 1.35,
                    colors: mesh,
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(1.1, 0.9),
                    radius: 0.95,
                    colors: [
                      mesh[1].withValues(alpha: mesh[1].a * 0.75),
                      base.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
