import 'package:flutter/services.dart';

/// P2-UX-1 — the app's haptic vocabulary. One small, consistent set of taps so
/// the same gesture always feels the same across the app:
///
/// - [tick]    — a light tick for a toggle / selection.
/// - [success] — a distinct notch for a completed submit / collect / save
///   (fired by the shared success ceremony, [AksharaSuccessView]).
/// - [warning] — a heavier buzz before a destructive / irreversible action.
///
/// Thin wrapper over [HapticFeedback] so call sites depend on the vocabulary,
/// not the raw platform API. No-op on platforms without haptics (and in tests).
abstract final class AksharaHaptics {
  /// Light tick — toggles, selection changes, chip taps.
  static void tick() => HapticFeedback.selectionClick();

  /// Success notch — a submit / collect / save completed (the "trust" beat).
  static void success() => HapticFeedback.mediumImpact();

  /// Warning buzz — precedes a destructive / irreversible action.
  static void warning() => HapticFeedback.heavyImpact();
}
