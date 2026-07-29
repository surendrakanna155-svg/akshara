/// ERP staff roles mapped to permission grants (JWT claim `role`).
///
/// ## JOURNEY-002 / JOURNEY-003 — the fallback fails CLOSED
///
/// The server issues one role slug per session out of a **29-slug** vocabulary
/// ([kServerRoleSlugs]); this enum names the subset the app can actually render.
/// Before this change the two resolution paths disagreed and both were unsafe:
/// the login path fell back to `ErpRole.superAdmin` — the *highest* privilege in
/// the product — and the session-restore path fell back to `ErpRole.parent`, so
/// the same user was a super admin on a fresh login and a parent after an app
/// relaunch.
///
/// There is now exactly ONE resolver, [ErpRole.resolve], and its failure mode is
/// [ErpRole.unsupported]: a role that grants **no workspace, no permission and no
/// role-keyed gate**. Every call site that turns a server slug into an [ErpRole]
/// must use it — `fromName` stays nullable for callers that genuinely want to
/// know "is this a slug I know?", and a `?? ErpRole.<something>` on top of it is
/// the exact bug this file exists to prevent.
///
/// The sentinel is deliberately **not** called `unknown`: `fromName` matches on
/// `role.name`, so a value named `unknown` would make the literal server slug
/// `"unknown"` resolve to it. `unsupported` cannot collide with any of the 29.
enum ErpRole {
  superAdmin,
  schoolAdmin,
  principal,
  vicePrincipal,
  management,
  financeAdmin,
  admissionsCounselor,
  teacher,
  parent,
  student,
  transportManager,
  hostelManager,
  librarian,
  inventoryManager,
  storekeeper,
  // ─── JOURNEY-002: the five school roles the server already seeds ──────────
  // Added in the SAME change as the fail-closed default, never after it — a
  // fail-closed default shipped alone locks these people out of the product.
  // Each has a `RolePermissionMatrix` entry mirroring the server grants and a
  // `kRoleWorkspaces` entry.
  hrManager,
  officeStaff,
  healthStaff,
  classTeacher,
  coordinator,
  // ─── The fail-closed sentinel. Always last; grants nothing. ───────────────
  unsupported;

  String get label => switch (this) {
        ErpRole.superAdmin => 'Super Admin',
        ErpRole.schoolAdmin => 'School Admin',
        ErpRole.principal => 'Principal',
        ErpRole.vicePrincipal => 'Vice Principal',
        ErpRole.management => 'Management',
        ErpRole.financeAdmin => 'Finance Admin',
        ErpRole.admissionsCounselor => 'Admissions Counselor',
        ErpRole.teacher => 'Teacher',
        ErpRole.parent => 'Parent',
        ErpRole.student => 'Student',
        ErpRole.transportManager => 'Transport Manager',
        ErpRole.hostelManager => 'Hostel Manager',
        ErpRole.librarian => 'Librarian',
        ErpRole.inventoryManager => 'Inventory Manager',
        ErpRole.storekeeper => 'Storekeeper',
        ErpRole.hrManager => 'HR Manager',
        ErpRole.officeStaff => 'Office Staff',
        ErpRole.healthStaff => 'Health / Infirmary Staff',
        ErpRole.classTeacher => 'Class Teacher',
        ErpRole.coordinator => 'Coordinator',
        ErpRole.unsupported => 'Unsupported role',
      };

  /// Whether this app version can render a workspace for the role at all.
  bool get isSupported => this != ErpRole.unsupported;

  /// Strict lookup: the [ErpRole] named [value], or `null` when this app version
  /// has no mapping for it.
  ///
  /// Never returns [ErpRole.unsupported] — the sentinel is not a server slug, so
  /// it must not be reachable by name. Prefer [resolve] at every boundary where a
  /// server-supplied slug becomes a role; use `fromName` only when `null` is
  /// genuinely the answer you want (e.g. a picker that lists known roles).
  static ErpRole? fromName(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value == ErpRole.unsupported.name) return null;
    for (final role in ErpRole.values) {
      if (role.name == value) return role;
    }
    return null;
  }

  /// **The** server-slug → role resolver. Fails CLOSED.
  ///
  /// An absent, empty or unmapped slug resolves to [ErpRole.unsupported], which
  /// holds no permissions and opens no workspace. Login and session-restore both
  /// call this, so a given slug resolves identically on both paths (JOURNEY-003).
  static ErpRole resolve(String? value) => fromName(value) ?? ErpRole.unsupported;

  /// Staff ERP roles selectable in demo mode.
  static const List<ErpRole> staffErpRoles = [
    ErpRole.superAdmin,
    ErpRole.schoolAdmin,
    ErpRole.principal,
    ErpRole.vicePrincipal,
    ErpRole.management,
    ErpRole.financeAdmin,
    ErpRole.admissionsCounselor,
    ErpRole.transportManager,
    ErpRole.hostelManager,
    ErpRole.librarian,
    ErpRole.inventoryManager,
    ErpRole.storekeeper,
    ErpRole.hrManager,
    ErpRole.officeStaff,
    ErpRole.healthStaff,
    ErpRole.classTeacher,
    ErpRole.coordinator,
  ];

  /// Every role the app can actually render (the enum minus the sentinel).
  static List<ErpRole> get supportedValues =>
      ErpRole.values.where((r) => r.isSupported).toList(growable: false);
}

/// The server's COMPLETE role vocabulary — the 29 slugs seeded by
/// `supabase/migrations/20260608100000_rbac_foundation.sql` (27),
/// `20260851000000_communication_storekeepers_audience.sql` (`storekeeper`) and
/// `20260887000000_student_health.sql` (`healthStaff`).
///
/// This list is what makes the 29-vs-client gap *observable* instead of silent:
/// the guard test resolves every slug here and asserts each one either maps to a
/// real [ErpRole] or is named in [kDeliberatelyUnsupportedServerRoles]. A role
/// added server-side and not triaged here fails the build rather than quietly
/// becoming whatever the fallback happened to be.
const List<String> kServerRoleSlugs = <String>[
  'superAdmin',
  'organizationOwner',
  'organizationAdmin',
  'schoolGroupDirector',
  'schoolAdmin',
  'principal',
  'vicePrincipal',
  'financeAdmin',
  'financeManager',
  'hrManager',
  'inventoryManager',
  'transportManager',
  'marketingManager',
  'teacher',
  'classTeacher',
  'coordinator',
  'counselor',
  'admissionsCounselor',
  'petTeacher',
  'danceTeacher',
  'musicTeacher',
  'librarian',
  'officeStaff',
  'management',
  'parent',
  'student',
  'hostelManager',
  'storekeeper',
  'healthStaff',
];

/// Server roles this app version deliberately does NOT map, each with the reason.
///
/// These resolve to [ErpRole.unsupported] — an explicit, observable denial, not a
/// silent fallback. They are listed rather than ignored so the decision is
/// reviewable and so a *new* server role cannot join them by accident.
///
/// The two families:
///  * **Above the school boundary** (`organizationOwner`, `organizationAdmin`,
///    `schoolGroupDirector`) — org/group-scope roles. Mapping them into a
///    school-scope workspace would be an invention, and mapping them to
///    `superAdmin` is precisely the privilege inversion JOURNEY-002 reports.
///  * **Teaching / staff variants with no distinct client surface**
///    (`financeManager`, `marketingManager`, `counselor`, `petTeacher`,
///    `danceTeacher`, `musicTeacher`) — aliasing them onto `teacher` /
///    `financeAdmin` would GRANT the alias's full client permission set, which is
///    strictly wider than the server grants each of them holds. Fail closed until
///    each gets a real matrix entry.
const Map<String, String> kDeliberatelyUnsupportedServerRoles = <String, String>{
  'organizationOwner':
      'organization-scope role; the app renders school-scope workspaces only',
  'organizationAdmin':
      'organization-scope role; the app renders school-scope workspaces only',
  'schoolGroupDirector':
      'school-group-scope role; the app renders school-scope workspaces only',
  'financeManager':
      'no client matrix yet; aliasing onto financeAdmin would grant a wider set '
          '(approveFeeStructure, assignScholarship) than the server seeds',
  'marketingManager':
      'server seeds viewAdminHub only; no marketing-only client workspace exists',
  'counselor':
      'admissions-adjacent; aliasing onto admissionsCounselor would grant viewSis, '
          'which the server does not seed for counselor',
  'petTeacher':
      'teaching variant; aliasing onto teacher grants the full teacher matrix, '
          'far wider than the four permissions the server seeds',
  'danceTeacher':
      'teaching variant; aliasing onto teacher grants the full teacher matrix, '
          'far wider than the four permissions the server seeds',
  'musicTeacher':
      'teaching variant; aliasing onto teacher grants the full teacher matrix, '
          'far wider than the four permissions the server seeds',
};
