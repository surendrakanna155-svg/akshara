import 'package:flutter/foundation.dart';

import '../security/rbac_module_registry.dart';
import '../../router/route_guards.dart' show erpRoutePermissionFor;

/// Persona-level pseudo-modules for routes that live outside the admin ERP shell
/// (mobile apps + the support surface itself). Ordered longest-first so
/// `student` never shadows a longer match.
const List<String> _personaModules = <String>[
  'admissions',
  'management',
  'inventory',
  'transport',
  'director',
  'library',
  'finance',
  'student',
  'teacher',
  'parent',
  'support',
  'hostel',
  'alumni',
  'admin',
  'hr',
];

/// Resolves the ERP `moduleKey` for a route location, so an incident reported
/// from a screen carries the module the user was in (ASIP_DESIGN §1: derive via
/// `RbacModuleRegistry` ∩ `kErpRouteViewPermissions`).
///
/// The router's `NavigatorObserver` yields either a path (`/finance/dashboard`)
/// or a GoRoute name (`financeDashboard`), so this is resilient to both:
/// 1. For a real path, map it to its view [Permission] using the router's own
///    longest-prefix matcher ([erpRoutePermissionFor]) — the same source of
///    truth the route guard uses — then reverse that to a module via
///    [RbacModuleRegistry].
/// 2. Otherwise, match the location against known module / persona keys by
///    substring (`financeDashboard` → `finance`).
///
/// Deterministic; no AI. Returns null when nothing matches.
String? deriveIncidentModuleKey(String? location) {
  if (location == null || location.isEmpty) return null;

  // Strip any query string / fragment before matching.
  final path = location.split('?').first.split('#').first;
  if (path.isEmpty || path == '/') return null;

  if (path.startsWith('/')) {
    final permission = erpRoutePermissionFor(path);
    if (permission != null) {
      for (final module in RbacModuleRegistry.modules) {
        if (module.view == permission) return module.moduleId;
      }
    }
  }

  final lower = path.toLowerCase();
  for (final module in RbacModuleRegistry.modules) {
    if (lower.contains(module.moduleId)) return module.moduleId;
  }
  for (final persona in _personaModules) {
    if (lower.contains(persona)) return persona;
  }

  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  return segments.isEmpty ? null : segments.first;
}

/// Best-effort platform label for the incident context (`ios` | `android` |
/// `web` | `macos` | `windows` | `linux` | `fuchsia`).
String resolvePlatformLabel() {
  if (kIsWeb) return 'web';
  return defaultTargetPlatform.name.toLowerCase();
}
