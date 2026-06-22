import 'package:flutter/material.dart';

import '../../../theme/motion.dart';

/// Subtle entrance animation — a short fade + upward slide when the widget first
/// mounts. Used to give the premium dashboards a polished, app-like feel without
/// pulling in an animation package. Honours reduced-motion (disableAnimations).
class AksharaMountFade extends StatefulWidget {
  const AksharaMountFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 14,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<AksharaMountFade> createState() => _AksharaMountFadeState();
}

class _AksharaMountFadeState extends State<AksharaMountFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: AksharaMotion.enter,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
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
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        return Opacity(
          opacity: _curve.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - _curve.value) * widget.offset),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
