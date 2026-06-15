import 'package:flutter/material.dart';

import '../../../core/security/permissions.dart';

/// ERP module route groups surfaced in the admin navigation rail.
enum AdminModule {
  admin,
  admissions,
  finance,
  sis,
  hr,
  management,
  transport,
  hostel,
  library,
  inventory,
  alumni,
  controlCenter,
  director,
  organizationBuilder,
  platformOperations,
  industry,
  healthcare,
  salon,
  restaurant,
  accommodation,
  whiteLabel,
  dynamicWidgets,
}

/// Single breadcrumb segment for [AdminAppBar].
class AdminBreadcrumb {
  const AdminBreadcrumb({
    required this.label,
    this.route,
  });

  final String label;

  /// When null, the segment represents the current page (not tappable).
  final String? route;
}

/// Side-nav destination for an ERP module group.
class AdminNavDestination {
  const AdminNavDestination({
    required this.module,
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.requiredPermission,
  });

  final AdminModule module;
  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Permission requiredPermission;
}

/// Canonical module metadata for placeholders and breadcrumbs.
class AdminModuleInfo {
  const AdminModuleInfo({
    required this.module,
    required this.title,
    required this.description,
    required this.route,
  });

  final AdminModule module;
  final String title;
  final String description;
  final String route;
}
