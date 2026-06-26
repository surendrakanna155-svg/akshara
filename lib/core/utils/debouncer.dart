import 'dart:async';
import 'package:flutter/foundation.dart';

/// Collapses a burst of calls into a single trailing-edge invocation.
///
/// Used to keep keystroke-driven work (e.g. a search field that fetches from the
/// backend on `onChanged`) from firing a request per character: each [run]
/// restarts the timer, so the action fires only once the input has been idle for
/// [delay]. Hold one instance per field and call [dispose] from `dispose()`.
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 350)});

  final Duration delay;
  Timer? _timer;

  /// Schedule [action] to run after [delay], cancelling any pending run.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancel a pending run without invoking it.
  void cancel() => _timer?.cancel();

  /// True while a run is scheduled but has not yet fired.
  bool get isActive => _timer?.isActive ?? false;

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
