import 'package:flutter/material.dart';

import '../../theme/motion.dart';

/// M15 fade + scale entrance for status placeholders and sheet bodies.
class AksharaMotionAppear extends StatefulWidget {
  const AksharaMotionAppear({
    super.key,
    required this.child,
    this.scale = true,
    this.delay = Duration.zero,
  });

  final Widget child;
  final bool scale;
  final Duration delay;

  @override
  State<AksharaMotionAppear> createState() => _AksharaMotionAppearState();
}

class _AksharaMotionAppearState extends State<AksharaMotionAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AksharaMotion.standard,
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: AksharaMotion.enter,
    );
    _opacity = curve;
    _scale = Tween<double>(
      begin: widget.scale ? AksharaMotion.enterScale : 1,
      end: 1,
    ).animate(curve);

    if (!AksharaMotion.animationsEnabledInEnvironment) {
      _controller.value = 1;
      return;
    }

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AksharaMotion.animationsEnabledInEnvironment) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}

/// Shared M15 transition builders for dialogs and overlays.
abstract final class AksharaMotionTransitions {
  static Widget dialog(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return fadeScale(animation, child);
  }

  static Widget fadeScale(Animation<double> animation, Widget child) {
    if (!AksharaMotion.animationsEnabledInEnvironment) {
      return child;
    }

    final curved = CurvedAnimation(
      parent: animation,
      curve: AksharaMotion.enter,
      reverseCurve: AksharaMotion.exit,
    );

    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: AksharaMotion.enterScale,
          end: 1,
        ).animate(curved),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

/// Subtle cross-fade for async content swaps (charts, tabs).
class AksharaAnimatedSwitcher extends StatelessWidget {
  const AksharaAnimatedSwitcher({
    super.key,
    required this.child,
    this.duration = AksharaMotion.standard,
    this.layoutBuilder = AnimatedSwitcher.defaultLayoutBuilder,
  });

  final Widget child;
  final Duration duration;
  final AnimatedSwitcherLayoutBuilder layoutBuilder;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AksharaMotion.animationsEnabledInEnvironment
          ? duration
          : Duration.zero,
      switchInCurve: AksharaMotion.enter,
      switchOutCurve: AksharaMotion.exit,
      transitionBuilder: (child, animation) {
        return AksharaMotionTransitions.fadeScale(animation, child);
      },
      layoutBuilder: layoutBuilder,
      child: child,
    );
  }
}

/// Shows a dialog with M15 fade + scale entrance.
Future<T?> showAksharaDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  if (!AksharaMotion.animationsEnabledInEnvironment) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: AksharaMotion.standard,
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionBuilder: AksharaMotionTransitions.dialog,
  );
}
