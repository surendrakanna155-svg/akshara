import 'package:flutter/animation.dart';

/// M15 motion tokens — subtle enterprise transitions only (fade, scale, elevation).
abstract final class AksharaMotion {
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 240);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasis = Curves.easeOut;

  /// Subtle vertical lift on press (logical pixels).
  static const double pressLift = 1;

  /// Hover lift — half of press.
  static const double hoverLift = 0.5;

  /// Resting card shadow level.
  static const int restingShadow = 1;

  /// Hover shadow level (web/desktop).
  static const int hoverShadow = 2;

  /// Pressed / active shadow level.
  static const int pressedShadow = 3;

  /// Subtle scale when surfaces enter (dialogs, empty states).
  static const double enterScale = 0.98;

  /// Entrance animations — disabled in widget/golden tests for stability.
  static bool get animationsEnabledInEnvironment {
    return !const bool.fromEnvironment('FLUTTER_TEST');
  }
}
