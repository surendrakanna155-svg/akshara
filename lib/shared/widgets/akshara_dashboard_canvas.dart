import 'package:flutter/material.dart';

import '../../theme/mesh_background.dart';
import 'akshara_dashboard_watermark.dart';
import 'akshara_mesh_background.dart';

/// M15.5 dashboard atmosphere — mesh gradient + optional watermark.
class AksharaDashboardCanvas extends StatelessWidget {
  const AksharaDashboardCanvas({
    super.key,
    required this.palette,
    required this.child,
    this.watermark,
    this.watermarkOpacity = 0.05,
    this.baseColor,
  });

  final AksharaMeshPalette palette;
  final Widget child;
  final AksharaWatermarkMotif? watermark;
  final double watermarkOpacity;
  final Color? baseColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight = constraints.hasBoundedHeight &&
            constraints.maxHeight.isFinite;

        Widget content = child;
        if (boundedHeight) {
          content = SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: child,
          );
        }

        return AksharaMeshBackground(
          palette: palette,
          baseColor: baseColor,
          child: Stack(
            fit: boundedHeight ? StackFit.expand : StackFit.passthrough,
            children: [
              if (watermark != null)
                AksharaDashboardWatermark(
                  motif: watermark!,
                  opacity: watermarkOpacity,
                ),
              content,
            ],
          ),
        );
      },
    );
  }
}
