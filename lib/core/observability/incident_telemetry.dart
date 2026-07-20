import 'dart:collection';

import 'package:flutter/foundation.dart';

/// ASIP Phase 1 — client-side observability primitives that feed the automatic
/// incident-evidence snapshot.
///
/// The reporter provides only a description and (optionally) a screenshot; every
/// technical signal below is captured passively so the support team never has to
/// ask a school for logs, timestamps or repro steps (ASIP_DESIGN §0). These are
/// deliberately structural + PII-free (route names, HTTP metadata, correlation
/// IDs) — never raw request/response bodies or student data.

/// A single navigation / api / error / action breadcrumb.
@immutable
class IncidentBreadcrumb {
  const IncidentBreadcrumb({
    required this.type,
    required this.at,
    this.route,
    this.message,
  });

  /// `navigation` | `api` | `error` | `action`.
  final String type;
  final String? route;
  final String? message;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'type': type,
        if (route != null) 'route': route,
        if (message != null) 'message': message,
        'at': at.toUtc().toIso8601String(),
      };
}

/// A recent outbound API call (metadata only — no bodies).
@immutable
class IncidentApiCall {
  const IncidentApiCall({
    required this.method,
    required this.path,
    required this.at,
    this.statusCode,
    this.correlationId,
  });

  final String method;
  final String path;
  final int? statusCode;
  final String? correlationId;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'method': method,
        'path': path,
        if (statusCode != null) 'statusCode': statusCode,
        if (correlationId != null) 'correlationId': correlationId,
        'at': at.toUtc().toIso8601String(),
      };
}

/// A bounded, in-memory ring of the most recent breadcrumbs + API calls plus the
/// current screen/module. Single-isolate UI state — no locking required. Bounded
/// so it can never grow without limit or leak PII into an unbounded log.
class IncidentTelemetryBuffer {
  IncidentTelemetryBuffer({
    int maxBreadcrumbs = 40,
    int maxApiCalls = 25,
    DateTime Function()? now,
  })  : _maxBreadcrumbs = maxBreadcrumbs,
        _maxApiCalls = maxApiCalls,
        _now = now ?? DateTime.now;

  final int _maxBreadcrumbs;
  final int _maxApiCalls;
  final DateTime Function() _now;

  final ListQueue<IncidentBreadcrumb> _breadcrumbs = ListQueue();
  final ListQueue<IncidentApiCall> _apiCalls = ListQueue();

  String? _currentRoute;
  String? _currentModule;

  /// The route the user is currently on (last observed navigation).
  String? get currentRoute => _currentRoute;

  /// The ERP module derived from [currentRoute], when resolvable.
  String? get currentModule => _currentModule;

  /// Breadcrumbs oldest → newest.
  List<IncidentBreadcrumb> get breadcrumbs =>
      List<IncidentBreadcrumb>.unmodifiable(_breadcrumbs);

  /// Recent API calls oldest → newest.
  List<IncidentApiCall> get recentApiCalls =>
      List<IncidentApiCall>.unmodifiable(_apiCalls);

  /// Distinct, insertion-ordered correlation IDs seen on recent API calls.
  List<String> get correlationIds {
    final seen = <String>{};
    for (final call in _apiCalls) {
      final id = call.correlationId;
      if (id != null && id.isNotEmpty) seen.add(id);
    }
    return List<String>.unmodifiable(seen);
  }

  /// Records a screen change. [module] is the resolved ERP module (may be null).
  void recordNavigation(String route, {String? module}) {
    _currentRoute = route;
    _currentModule = module;
    _pushBreadcrumb(IncidentBreadcrumb(
      type: 'navigation',
      route: route,
      at: _now(),
    ));
  }

  /// Records an outbound API call. A failing call (>= 400) also drops an `error`
  /// breadcrumb so the timeline shows where things went wrong.
  void recordApiCall({
    required String method,
    required String path,
    int? statusCode,
    String? correlationId,
  }) {
    final at = _now();
    _apiCalls.addLast(IncidentApiCall(
      method: method,
      path: path,
      statusCode: statusCode,
      correlationId: correlationId,
      at: at,
    ));
    while (_apiCalls.length > _maxApiCalls) {
      _apiCalls.removeFirst();
    }
    if (statusCode != null && statusCode >= 400) {
      _pushBreadcrumb(IncidentBreadcrumb(
        type: 'error',
        route: _currentRoute,
        message: '$method $path → $statusCode',
        at: at,
      ));
    }
  }

  /// Records a user action (e.g. a tapped button) for the breadcrumb trail.
  void recordAction(String message, {String? route}) {
    _pushBreadcrumb(IncidentBreadcrumb(
      type: 'action',
      route: route ?? _currentRoute,
      message: message,
      at: _now(),
    ));
  }

  /// Records a client-side error breadcrumb.
  void recordError(String message, {String? route}) {
    _pushBreadcrumb(IncidentBreadcrumb(
      type: 'error',
      route: route ?? _currentRoute,
      message: message,
      at: _now(),
    ));
  }

  /// Clears all captured telemetry (used by tests and on logout).
  void clear() {
    _breadcrumbs.clear();
    _apiCalls.clear();
    _currentRoute = null;
    _currentModule = null;
  }

  void _pushBreadcrumb(IncidentBreadcrumb crumb) {
    _breadcrumbs.addLast(crumb);
    while (_breadcrumbs.length > _maxBreadcrumbs) {
      _breadcrumbs.removeFirst();
    }
  }
}
