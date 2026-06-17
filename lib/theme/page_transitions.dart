import 'package:flutter/material.dart';

import 'motion.dart';

/// Desktop page transition — fade only, no vertical slide.
class AksharaFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const AksharaFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!AksharaMotion.animationsEnabledInEnvironment) {
      return child;
    }

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: AksharaMotion.enter,
        reverseCurve: AksharaMotion.exit,
      ),
      child: child,
    );
  }
}
