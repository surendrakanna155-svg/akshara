import 'permissions.dart';

/// Describes a guarded mutation and its required permission.
class MutationPermissionEntry {
  const MutationPermissionEntry({
    required this.moduleId,
    required this.mutationId,
    required this.permission,
    required this.kind,
  });

  final String moduleId;
  final String mutationId;
  final Permission permission;

  /// `manage` or `approve`.
  final String kind;
}

/// Inventory of provider-level mutations and required RBAC permissions.
class MutationPermissionRegistry {
  const MutationPermissionRegistry._();

  static const entries = <MutationPermissionEntry>[
    // Admissions
    MutationPermissionEntry(
      moduleId: 'admissions',
      mutationId: 'createLead',
      permission: Permission.manageAdmissions,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'admissions',
      mutationId: 'updateLead',
      permission: Permission.manageAdmissions,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'admissions',
      mutationId: 'approveApplication',
      permission: Permission.approveAdmissions,
      kind: 'approve',
    ),
    MutationPermissionEntry(
      moduleId: 'admissions',
      mutationId: 'rejectApplication',
      permission: Permission.approveAdmissions,
      kind: 'approve',
    ),
    // Finance
    MutationPermissionEntry(
      moduleId: 'finance',
      mutationId: 'createFeeStructure',
      permission: Permission.manageFinance,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'finance',
      mutationId: 'approveRefund',
      permission: Permission.approveRefunds,
      kind: 'approve',
    ),
    MutationPermissionEntry(
      moduleId: 'finance',
      mutationId: 'createScholarship',
      permission: Permission.manageFinance,
      kind: 'manage',
    ),
    // SIS
    MutationPermissionEntry(
      moduleId: 'sis',
      mutationId: 'registerStudent',
      permission: Permission.manageSis,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'sis',
      mutationId: 'assignAcademic',
      permission: Permission.manageSis,
      kind: 'manage',
    ),
  ];

  static List<MutationPermissionEntry> forModule(String moduleId) {
    return entries.where((e) => e.moduleId == moduleId).toList(growable: false);
  }
}
