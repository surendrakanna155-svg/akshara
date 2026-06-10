import 'package:flutter/foundation.dart';

/// Fine-grained permissions for Akshara ERP modules.
enum Permission {
  // Admissions
  viewAdmissions,
  manageAdmissions,
  approveAdmissions,

  // Finance
  viewFinance,
  manageFinance,
  approveRefunds,

  // SIS
  viewSis,
  manageSis,

  // Management
  viewManagement,
  manageManagement,

  // Transport
  viewTransport,
  manageTransport,

  // HR
  viewHr,
  manageHr,

  // Hostel
  viewHostel,
  manageHostel,

  // Library
  viewLibrary,
  manageLibrary,

  // Inventory
  viewInventory,
  manageInventory,

  // Alumni
  viewAlumni,
  manageAlumni,

  // Control Center (platform)
  viewControlCenter,
  manageControlCenter,

  // Admin hub
  viewAdminHub,

  // Onboarding / data migration
  viewOnboarding,
  manageOnboarding,

  // AI Copilot
  viewAiCopilot,
  runAiCopilot,

  // Academic timetable (v7.5)
  viewAcademicTimetable,
  manageAcademicTimetable,
  publishAcademicTimetable,

  // Analytics & Intelligence (v7.6)
  viewAnalytics,
  viewSchoolHealth,
}

/// Immutable set of [Permission] values for a session.
@immutable
class PermissionSet {
  const PermissionSet(this._permissions);

  factory PermissionSet.from(Iterable<Permission> permissions) {
    return PermissionSet(Set<Permission>.unmodifiable(permissions));
  }

  factory PermissionSet.all() {
    return PermissionSet(Set<Permission>.unmodifiable(Permission.values));
  }

  final Set<Permission> _permissions;

  bool contains(Permission permission) => _permissions.contains(permission);

  bool containsAny(Iterable<Permission> permissions) {
    for (final p in permissions) {
      if (_permissions.contains(p)) return true;
    }
    return false;
  }

  bool containsAll(Iterable<Permission> permissions) {
    for (final p in permissions) {
      if (!_permissions.contains(p)) return false;
    }
    return true;
  }

  Set<Permission> get values => Set<Permission>.unmodifiable(_permissions);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PermissionSet &&
        other._permissions.length == _permissions.length &&
        other._permissions.containsAll(_permissions);
  }

  @override
  int get hashCode => Object.hashAllUnordered(_permissions);
}
