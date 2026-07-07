import 'package:flutter/material.dart';

import '../../theme/motion.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// A single shimmering skeleton placeholder block.
///
/// Renders a rounded rectangle in the surface's neutral tone. When entrance
/// animations are enabled (i.e. NOT inside a widget/golden test) a soft
/// highlight sweeps across it; in tests it renders a static block so
/// `pumpAndSettle` completes and goldens stay deterministic.
class AksharaSkeletonBox extends StatefulWidget {
  const AksharaSkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<AksharaSkeletonBox> createState() => _AksharaSkeletonBoxState();
}

class _AksharaSkeletonBoxState extends State<AksharaSkeletonBox>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    // No repeating animation in tests: a forever-repeating controller would
    // hang `pumpAndSettle` and make golden capture non-deterministic.
    if (AksharaMotion.animationsEnabledInEnvironment) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base = colors.surfaceContainerHighest;
    final highlight = Color.alphaBlend(
      colors.surface.withValues(alpha: 0.6),
      base,
    );
    final radius = widget.borderRadius ?? BorderRadius.circular(AksharaRadius.sm);
    final controller = _controller;

    if (controller == null) {
      // Reduced-motion / test: static, deterministic block.
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: base, borderRadius: radius),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final c = -0.3 + controller.value * 1.6;
        final stops = <double>[
          (c - 0.3).clamp(0.0, 1.0),
          c.clamp(0.0, 1.0),
          (c + 0.3).clamp(0.0, 1.0),
        ];
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              colors: [base, highlight, base],
              stops: stops,
            ),
          ),
        );
      },
    );
  }
}

/// Composable skeleton placeholders for the app's loading surfaces.
///
/// Pass the appropriate preset to [AksharaLoadingState.skeleton] (directly, or
/// via the `skeleton:` slot on `ErpAsyncBody` / `MobileAsyncBody`) so a screen's
/// wait state echoes the silhouette of the content that is about to arrive,
/// instead of a bare spinner.
abstract final class AksharaSkeleton {
  /// A single text-line placeholder.
  static Widget line({double? width, double height = 14}) =>
      AksharaSkeletonBox(width: width, height: height);

  /// A circular placeholder (avatar / icon).
  static Widget circle(double size) => AksharaSkeletonBox(
        width: size,
        height: size,
        borderRadius: BorderRadius.circular(size / 2),
      );

  /// A card-shaped block (KPI tile / summary card).
  static Widget card({double height = 96, BorderRadius? radius}) =>
      AksharaSkeletonBox(
        height: height,
        borderRadius: radius ?? AksharaRadius.card,
      );

  /// A row placeholder — leading avatar + two stacked lines.
  static Widget row({double height = 56}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            circle(height * 0.7),
            const SizedBox(width: AksharaSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  line(height: 12),
                  const SizedBox(height: AksharaSpacing.s2),
                  line(width: 140, height: 10),
                ],
              ),
            ),
          ],
        ),
      );

  /// A vertical stack of [rows] row placeholders — for list / table screens.
  ///
  /// Scrolls internally so it can never overflow its host on short viewports.
  static Widget list({
    int rows = 6,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: AksharaSpacing.s4, vertical: AksharaSpacing.s3),
  }) =>
      SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (var i = 0; i < rows; i++) row()],
        ),
      );

  /// A dashboard placeholder — hero banner, a KPI tile row, then list rows.
  ///
  /// Scrolls internally (no overflow) and matches the common mobile dashboard
  /// silhouette (hero → KPI grid → recent list).
  static Widget dashboard({
    EdgeInsetsGeometry padding = const EdgeInsets.all(AksharaSpacing.s4),
    int kpis = 2,
    int rows = 3,
  }) =>
      SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            card(height: 116, radius: AksharaRadius.kpiCard),
            const SizedBox(height: AksharaSpacing.s4),
            Row(
              children: [
                for (var i = 0; i < kpis; i++) ...[
                  if (i > 0) const SizedBox(width: AksharaSpacing.s3),
                  Expanded(child: card(height: 88)),
                ],
              ],
            ),
            const SizedBox(height: AksharaSpacing.s4),
            for (var i = 0; i < rows; i++) row(),
          ],
        ),
      );
}
