import 'package:flutter/widgets.dart';

import 'incident_module_resolver.dart';
import 'incident_telemetry.dart';

/// A [NavigatorObserver] that feeds the incident evidence snapshot: every screen
/// the user visits becomes a navigation breadcrumb, and the most recent
/// non-support screen is remembered as the incident's `screenRoute` + `moduleKey`.
///
/// Support's own screens are deliberately skipped so that when a user opens
/// "Report an issue", the captured route still points at the screen they were
/// actually on — not the report form itself.
class IncidentRouteObserver extends NavigatorObserver {
  IncidentRouteObserver(this._buffer);

  final IncidentTelemetryBuffer _buffer;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _record(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Returning to the underlying screen — treat it as a fresh navigation so the
    // current route reflects where the user actually is again.
    _record(previousRoute);
    super.didPop(route, previousRoute);
  }

  void _record(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null || name.isEmpty) return;
    // Never let the support flow overwrite the reporter's real context.
    if (_isSupportRoute(name)) return;
    _buffer.recordNavigation(name, module: deriveIncidentModuleKey(name));
  }

  bool _isSupportRoute(String name) {
    final lower = name.toLowerCase();
    return lower.startsWith('/support') || lower.startsWith('support');
  }
}
