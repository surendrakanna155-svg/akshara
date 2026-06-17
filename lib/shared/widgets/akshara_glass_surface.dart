import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/elevation.dart';
import '../../theme/glass.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Frosted / translucent surface — hero cards, app bars, insight strips.
class AksharaGlassSurface extends StatelessWidget {
  const AksharaGlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.margin,
    this.tintColor,
    this.opacity,
    this.borderOpacity,
    this.enableBlur,
    this.blurSigma = AksharaGlass.blurSigma,
    this.showSheen = false,
    this.shadowLevel = 1,
    this.border,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? tintColor;
  final double? opacity;
  final double? borderOpacity;
  final bool? enableBlur;
  final double blurSigma;
  final bool showSheen;
  final int shadowLevel;
  final BoxBorder? border;

  /// Disable live backdrop blur in widget tests for deterministic goldens.
  static bool get blurEnabledInEnvironment {
    if (kIsWeb) return true;
    return !const bool.fromEnvironment('FLUTTER_TEST');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ext = context.akshara;
    final resolvedRadius = borderRadius ?? AksharaRadius.glass;
    final resolvedOpacity = opacity ?? ext.glassOpacity;
    final resolvedBorderOpacity = borderOpacity ?? ext.glassBorderOpacity;
    final useBlur = enableBlur ?? blurEnabledInEnvironment;
    final fill = (tintColor ?? colors.surface).withValues(alpha: resolvedOpacity);
    final resolvedBorder = border ??
        Border.all(
          color: colors.onSurface.withValues(alpha: resolvedBorderOpacity),
        );
    final shadows = AksharaElevation.boxShadow(context, shadowLevel);

    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: resolvedRadius,
        border: resolvedBorder,
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: resolvedRadius,
        child: Stack(
          children: [
            if (useBlur)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ColoredBox(color: fill),
            if (showSheen)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primary.withValues(
                          alpha: AksharaGlass.heroSheenOpacity,
                        ),
                        colors.surface.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            if (padding != null)
              Padding(padding: padding!, child: child)
            else
              child,
          ],
        ),
      ),
    );

    if (margin != null) {
      panel = Padding(padding: margin!, child: panel);
    }

    return panel;
  }
}

/// Glass card shell for dashboard hero and insight zones.
class AksharaGlassCard extends StatelessWidget {
  const AksharaGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AksharaSpacing.s4),
    this.margin,
    this.borderRadius,
    this.showSheen = true,
    this.enableBlur,
    this.tintColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final bool showSheen;
  final bool? enableBlur;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    return AksharaGlassSurface(
      margin: margin,
      padding: padding,
      borderRadius: borderRadius ?? AksharaRadius.glass,
      showSheen: showSheen,
      enableBlur: enableBlur ?? false,
      tintColor: tintColor,
      child: child,
    );
  }
}

/// Full-width glass strip for web admin and mobile app bars.
class AksharaGlassBar extends StatelessWidget {
  const AksharaGlassBar({
    super.key,
    required this.child,
    this.height,
    this.enableBlur = true,
  });

  final Widget child;
  final double? height;
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AksharaGlassSurface(
      borderRadius: BorderRadius.zero,
      enableBlur: enableBlur,
      blurSigma: AksharaGlass.blurSigmaLight,
      opacity: context.akshara.glassOpacity + 0.08,
      border: Border(
        bottom: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      shadowLevel: 0,
      child: height == null ? child : SizedBox(height: height, child: child),
    );
  }
}

/// Soft gradient halo placed behind hero glass cards on dashboards.
class AksharaGlassHeroBackdrop extends StatelessWidget {
  const AksharaGlassHeroBackdrop({
    super.key,
    required this.child,
    this.height = 180,
  });

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -AksharaSpacing.s6,
          right: -AksharaSpacing.s6,
          top: -AksharaSpacing.s4,
          height: height,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.1,
                  colors: [
                    colors.primary.withValues(alpha: 0.10),
                    colors.tertiary.withValues(alpha: 0.04),
                    colors.surface.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
