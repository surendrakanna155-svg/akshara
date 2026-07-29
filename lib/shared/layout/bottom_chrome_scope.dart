import 'package:flutter/widgets.dart';

/// Publishes the height of the bottom navigation chrome a shell **actually
/// paints**, so a full-screen overlay that is a *sibling* of that shell (the
/// floating AI dock) can sit clear of it at any width.
///
/// ## Why this exists
///
/// The floating dock is stacked next to the shell, not inside it, so it cannot
/// see the shell's `Scaffold.bottomNavigationBar`. It used to infer the inset
/// from a width tier — `isMobile ? 88 : 24` — i.e. it assumed a bottom nav
/// exists only on phones.
///
/// That assumption is wrong: the persona shells (parent / teacher / student)
/// have **no tablet branch**. They paint the same 80dp [NavigationBar] at every
/// width. So on a tablet the dock collapsed to a 24dp inset and landed *fully
/// inside* the navigation bar, covering a primary destination — the overlap
/// reported at tablet width, alongside the second AI button it appeared to
/// duplicate. The same guess also ignores the gesture/safe-area inset that
/// makes a real device's bar taller than 80dp.
///
/// Guessing chrome from a breakpoint is the defect. The chrome is published by
/// whoever paints it: a bottom nav wraps itself in a [BottomChromeReporter],
/// and any overlay inside the surrounding [BottomChromeScope] reads the real,
/// measured height. A shell that gains, loses, or resizes its bottom nav — at
/// any width, now or later — is handled without the overlay knowing anything
/// about shells or breakpoints.
///
/// Only the **full-width** chrome is reported. A raised affordance that is
/// centred above the bar (the centre AI button) is deliberately excluded: it
/// occupies a narrow centre band, so an overlay pinned to the right edge does
/// not need to clear it. Screens with their own fixed bottom action bar reserve
/// that centre band through `BottomNavAiScope` instead.
class BottomChromeScope extends StatefulWidget {
  const BottomChromeScope({super.key, required this.child});

  final Widget child;

  /// Measured height of the bottom chrome painted under this scope, or `null`
  /// when there is no scope or nothing has reported one.
  ///
  /// `null` means "unknown", not "zero" — callers keep their own fallback so a
  /// shell that does not report is left exactly as it was.
  static double? maybeHeightOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_BottomChromeInherited>()
        ?.notifier
        ?.value;
  }

  @override
  State<BottomChromeScope> createState() => _BottomChromeScopeState();
}

class _BottomChromeScopeState extends State<BottomChromeScope> {
  final ValueNotifier<double?> _height = ValueNotifier<double?>(null);
  bool _disposed = false;
  bool _flushScheduled = false;
  double? _pending;

  /// Records a reported height. The publish is always deferred to after the
  /// current frame: reporters call this from `dispose()` as their nav bar
  /// leaves the tree, and notifying inherited dependents there would
  /// `markNeedsBuild` while the framework is locked.
  void _report(double? height) {
    if (_disposed) return;
    _pending = height;
    if (_flushScheduled) return;
    _flushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      if (_disposed) return;
      if (_height.value == _pending) return;
      _height.value = _pending;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BottomChromeInherited(
      owner: this,
      notifier: _height,
      child: widget.child,
    );
  }
}

class _BottomChromeInherited extends InheritedNotifier<ValueNotifier<double?>> {
  const _BottomChromeInherited({
    required this.owner,
    required ValueNotifier<double?> super.notifier,
    required super.child,
  });

  final _BottomChromeScopeState owner;
}

/// Wraps a bottom navigation bar and reports its laid-out height to the nearest
/// enclosing [BottomChromeScope].
///
/// Measured rather than assumed, so safe-area / gesture insets and any future
/// nav height change are carried automatically. Outside a scope this is an
/// inert pass-through, which keeps every existing widget test that pumps a nav
/// bar on its own working unchanged.
class BottomChromeReporter extends StatefulWidget {
  const BottomChromeReporter({super.key, required this.child});

  final Widget child;

  @override
  State<BottomChromeReporter> createState() => _BottomChromeReporterState();
}

class _BottomChromeReporterState extends State<BottomChromeReporter> {
  _BottomChromeScopeState? _owner;
  double? _reported;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Deliberately a non-dependent lookup: the reporter writes to the scope and
    // must not rebuild when it publishes, or reporting would feed itself.
    final scope =
        context.getInheritedWidgetOfExactType<_BottomChromeInherited>();
    final next = scope?.owner;
    if (!identical(next, _owner)) {
      _owner?._report(null);
      _reported = null;
      _owner = next;
    }
    _scheduleMeasure();
  }

  @override
  void dispose() {
    _owner?._report(null);
    super.dispose();
  }

  void _scheduleMeasure() {
    if (_owner == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measure();
    });
  }

  void _measure() {
    final owner = _owner;
    if (owner == null) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final height = box.size.height;
    if (_reported == height) return;
    _reported = height;
    owner._report(height);
  }

  @override
  Widget build(BuildContext context) {
    // Re-measure after every layout pass, so a height change (safe-area shift,
    // text scale, nav bar swap) republishes without the overlay polling.
    _scheduleMeasure();
    return widget.child;
  }
}
