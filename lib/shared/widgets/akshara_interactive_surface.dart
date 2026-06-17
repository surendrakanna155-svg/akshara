import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/elevation.dart';
import '../../theme/motion.dart';
import '../../theme/radius.dart';
import '../../theme/theme_extensions.dart';

/// M15 interactive surface — soft shadow lift, hover, focus ring, touch feedback.
///
/// Use for tappable cards and tiles. Non-interactive surfaces should use plain
/// [DecoratedBox] or [Material] without this wrapper.
class AksharaInteractiveSurface extends StatefulWidget {
  const AksharaInteractiveSurface({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderRadius = AksharaRadius.cardBorder,
    this.border,
    this.restingShadowLevel = AksharaMotion.restingShadow,
    this.hoverShadowLevel = AksharaMotion.hoverShadow,
    this.pressedShadowLevel = AksharaMotion.pressedShadow,
    this.enableHoverLift = true,
    this.semanticLabel,
    this.enabled = true,
    this.clipBehavior = Clip.antiAlias,
    this.drillKey,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final BorderRadius borderRadius;
  final BoxBorder? border;
  final int restingShadowLevel;
  final int hoverShadowLevel;
  final int pressedShadowLevel;
  final bool enableHoverLift;
  final String? semanticLabel;
  final bool enabled;
  final Clip clipBehavior;
  final Key? drillKey;

  bool get _interactive =>
      enabled && (onTap != null || onLongPress != null);

  @override
  State<AksharaInteractiveSurface> createState() =>
      _AksharaInteractiveSurfaceState();
}

class _AksharaInteractiveSurfaceState extends State<AksharaInteractiveSurface> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  int get _shadowLevel {
    if (!widget._interactive) {
      return widget.restingShadowLevel;
    }
    if (_pressed) {
      return widget.pressedShadowLevel;
    }
    if (_hovered && widget.enableHoverLift) {
      return widget.hoverShadowLevel;
    }
    return widget.restingShadowLevel;
  }

  double get _liftY {
    if (!widget._interactive) {
      return 0;
    }
    if (_pressed) {
      return -AksharaMotion.pressLift;
    }
    if (_hovered && widget.enableHoverLift) {
      return -AksharaMotion.hoverLift;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final akshara = context.akshara;
    final background = widget.color ?? colors.surface;
    final shadows = AksharaElevation.boxShadow(context, _shadowLevel);
    final focusBorder = _focused && widget._interactive
        ? Border.all(
            color: colors.primary.withValues(alpha: 0.55),
            width: akshara.focusRingWidth,
            strokeAlign: BorderSide.strokeAlignOutside,
          )
        : null;
    final resolvedBorder = focusBorder ?? widget.border;

    final surface = AnimatedContainer(
      duration: AksharaMotion.fast,
      curve: AksharaMotion.emphasis,
      transform: Matrix4.translationValues(0, _liftY, 0),
      decoration: BoxDecoration(
        color: background,
        borderRadius: widget.borderRadius,
        border: resolvedBorder,
        boxShadow: shadows,
      ),
      clipBehavior: widget.clipBehavior,
      child: Material(
        key: widget.drillKey,
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.enabled ? widget.onTap : null,
          onLongPress: widget.enabled ? widget.onLongPress : null,
          onHighlightChanged: widget._interactive
              ? (value) => setState(() => _pressed = value)
              : null,
          onHover: widget._interactive && widget.enableHoverLift
              ? (value) => setState(() => _hovered = value)
              : null,
          borderRadius: widget.borderRadius,
          splashColor: colors.primary.withValues(alpha: 0.06),
          highlightColor: colors.onSurface.withValues(alpha: 0.04),
          hoverColor: colors.primary.withValues(alpha: 0.04),
          focusColor: colors.primary.withValues(alpha: 0.06),
          child: widget.child,
        ),
      ),
    );

    final focused = Focus(
      onFocusChange: (value) => setState(() => _focused = value),
      child: surface,
    );

    return Semantics(
      button: widget._interactive,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: focused,
    );
  }
}

/// Keyboard-activatable wrapper used by quick actions and KPI tiles.
class AksharaInteractiveActivator extends StatelessWidget {
  const AksharaInteractiveActivator({
    super.key,
    required this.onActivate,
    required this.child,
    this.enabled = true,
  });

  final VoidCallback? onActivate;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || onActivate == null) {
      return child;
    }

    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onActivate!();
            return null;
          },
        ),
      },
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        child: child,
      ),
    );
  }
}
