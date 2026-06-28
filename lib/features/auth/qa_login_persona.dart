import '../../core/security/erp_role.dart';
import '../../core/security/permissions.dart';
import '../../router/route_names.dart';
import 'auth_models.dart';

/// One-tap personas for QA automation builds only.
enum QaLoginPersona {
  principal,
  teacher,
  parent,
  student,
  finance,
  inventory,
  superAdmin,
  multiHat,
  // QW1 (QA-J-019/024/037/047/058) — the 4 missing RBAC-isolation personas.
  // HR and Director have no dedicated ErpRole, so they carry a curated
  // [customPermissions] subset (see below) rather than a role's full union;
  // School Admin and Staff (librarian) reuse existing narrow roles.
  hr,
  schoolAdmin,
  director,
  staff,
  // QW1 (QA-J-048 positive) — a CHAIN-org director: same director scope plus the
  // chain-only permissions, AND [isChainOrg] = true. Proves the ChainScope gate
  // GRANTS franchise / multi-school / organization-builder when the active org is
  // a real chain (the [director] persona is the single-school negative).
  chainDirector;

  String get buttonLabel => switch (this) {
        QaLoginPersona.principal => 'Principal',
        QaLoginPersona.teacher => 'Teacher',
        QaLoginPersona.parent => 'Parent',
        QaLoginPersona.student => 'Student',
        QaLoginPersona.finance => 'Finance',
        QaLoginPersona.inventory => 'Inventory',
        QaLoginPersona.superAdmin => 'Super Admin',
        QaLoginPersona.multiHat => 'Teacher + Inventory',
        QaLoginPersona.hr => 'HR',
        QaLoginPersona.schoolAdmin => 'School Admin',
        QaLoginPersona.director => 'Director',
        QaLoginPersona.staff => 'Librarian',
        QaLoginPersona.chainDirector => 'Chain Director',
      };

  UserRole get userRole => switch (this) {
        QaLoginPersona.teacher => UserRole.teacher,
        QaLoginPersona.parent => UserRole.parent,
        QaLoginPersona.student => UserRole.student,
        _ => UserRole.staff,
      };

  ErpRole? get erpRole => switch (this) {
        QaLoginPersona.principal => ErpRole.principal,
        QaLoginPersona.finance => ErpRole.financeAdmin,
        QaLoginPersona.inventory => ErpRole.inventoryManager,
        QaLoginPersona.superAdmin => ErpRole.superAdmin,
        QaLoginPersona.teacher => ErpRole.teacher,
        QaLoginPersona.parent => ErpRole.parent,
        QaLoginPersona.student => ErpRole.student,
        // Primary (first) role — staff-shell so the switcher's home is the hub.
        QaLoginPersona.multiHat => ErpRole.inventoryManager,
        QaLoginPersona.schoolAdmin => ErpRole.schoolAdmin,
        QaLoginPersona.staff => ErpRole.librarian,
        // HR + Director have no dedicated role; base role is staff-shell only —
        // their effective permissions come from [customPermissions] (an explicit
        // claims set that overrides the role union in UserPermissions.fromClaims).
        QaLoginPersona.hr => ErpRole.management,
        QaLoginPersona.director => ErpRole.management,
        QaLoginPersona.chainDirector => ErpRole.management,
      };

  /// Whether this persona's active org is a CHAIN (multi-school tenant). Only the
  /// chain-director persona is; flows into [AuthClaims.isChainOrganization] via
  /// the QA login path so [isChainOrgProvider] (and thus the ChainScope gate)
  /// turns on. Every other persona is a single independent school (false).
  bool get isChainOrg => this == QaLoginPersona.chainDirector;

  /// QA-only curated permission subset for personas with no dedicated ErpRole
  /// (HR, Director). Returns null for personas that use their role's default
  /// permission union. Flows through [AuthClaims.demoForRole] →
  /// [UserPermissions.fromClaims] (explicit perms override the role union), so
  /// these personas are scoped exactly to their module — proving RBAC isolation
  /// without changing the production role model.
  List<Permission>? get customPermissions => switch (this) {
        QaLoginPersona.hr => const [
            Permission.viewAdminHub,
            Permission.viewHr,
            Permission.manageHr,
            Permission.viewEmployees,
            Permission.manageEmployees,
            Permission.viewEmployeeIntelligence,
            Permission.submitStaffLeave,
            Permission.approveStaffLeave,
          ],
        QaLoginPersona.director => const [
            Permission.viewAdminHub,
            Permission.viewDirectorPortal,
            Permission.manageDirectorPortal,
            Permission.viewOrganizationIntelligence,
            Permission.viewSchoolHealth,
            Permission.viewAnalytics,
          ],
        // Chain director = the director scope PLUS the chain-only view perms.
        // Holding the perms is necessary but NOT sufficient — the ChainScope gate
        // still hides these routes unless [isChainOrg] is true, which it is for
        // this persona alone. (Still denied control-center: stays scoped.)
        QaLoginPersona.chainDirector => const [
            Permission.viewAdminHub,
            Permission.viewDirectorPortal,
            Permission.manageDirectorPortal,
            Permission.viewOrganizationIntelligence,
            Permission.viewSchoolHealth,
            Permission.viewAnalytics,
            Permission.viewFranchiseOperations,
            Permission.viewBranchOperations,
            Permission.viewMultiSchoolOperations,
            Permission.viewOrganizationBuilder,
          ],
        _ => null,
      };

  /// All roles the persona holds — multi-hat personas return several.
  List<ErpRole> get erpRoles => switch (this) {
        QaLoginPersona.multiHat => const [
            ErpRole.inventoryManager,
            ErpRole.teacher,
          ],
        _ => [erpRole ?? ErpRole.parent],
      };

  String get demoPhone => switch (this) {
        QaLoginPersona.principal => '9876543210',
        QaLoginPersona.teacher => '9000000001',
        QaLoginPersona.parent => '9000100001',
        QaLoginPersona.student => '9876543212',
        QaLoginPersona.finance => '9999999991',
        QaLoginPersona.inventory => '9999999992',
        QaLoginPersona.superAdmin => '9999999999',
        QaLoginPersona.multiHat => '9000000050',
        QaLoginPersona.hr => '9000000060',
        QaLoginPersona.schoolAdmin => '9000000061',
        QaLoginPersona.director => '9000000062',
        QaLoginPersona.staff => '9000000063',
        QaLoginPersona.chainDirector => '9000000064',
      };

  String get displayName => switch (this) {
        QaLoginPersona.principal => 'QA Principal',
        QaLoginPersona.teacher => 'QA Teacher',
        QaLoginPersona.parent => 'QA Parent',
        QaLoginPersona.student => 'QA Student',
        QaLoginPersona.finance => 'QA Finance',
        QaLoginPersona.inventory => 'QA Inventory',
        QaLoginPersona.superAdmin => 'QA Super Admin',
        QaLoginPersona.multiHat => 'QA Surendra',
        QaLoginPersona.hr => 'QA HR',
        QaLoginPersona.schoolAdmin => 'QA School Admin',
        QaLoginPersona.director => 'QA Director',
        QaLoginPersona.staff => 'QA Librarian',
        QaLoginPersona.chainDirector => 'QA Chain Director',
      };

  /// Dashboard anchor text Maestro can wait for after login.
  String get dashboardAnchor => switch (this) {
        QaLoginPersona.principal => 'Principal overview',
        QaLoginPersona.teacher => 'Good morning, Priya',
        QaLoginPersona.parent => 'Fees',
        QaLoginPersona.student => 'Home',
        QaLoginPersona.finance => 'Fee Collected (MTD)',
        QaLoginPersona.inventory => 'Total Assets',
        QaLoginPersona.superAdmin => 'Admin Hub',
        QaLoginPersona.multiHat => 'Your workspaces',
        // All four QW1 personas land on the Admin Hub (they hold viewAdminHub);
        // their module-specific reach/denial is asserted by the RBAC-isolation
        // journeys, not the landing screen.
        QaLoginPersona.hr => 'Admin Hub',
        QaLoginPersona.schoolAdmin => 'Admin Hub',
        QaLoginPersona.director => 'Admin Hub',
        QaLoginPersona.staff => 'Admin Hub',
        QaLoginPersona.chainDirector => 'Admin Hub',
      };
}

/// Post-login route for a QA persona (staff ERP roles land on module dashboards).
String homeRouteForQaPersona(QaLoginPersona persona) {
  return switch (persona) {
    QaLoginPersona.teacher => RouteNames.teacherDashboard,
    QaLoginPersona.parent => RouteNames.parentDashboard,
    QaLoginPersona.student => RouteNames.studentDashboard,
    QaLoginPersona.principal => RouteNames.managementDashboard,
    QaLoginPersona.finance => RouteNames.financeDashboard,
    QaLoginPersona.inventory => RouteNames.inventoryDashboard,
    QaLoginPersona.superAdmin => RouteNames.admin,
    // Multi-hat lands on the Admin Hub where the workspace switcher lives.
    QaLoginPersona.multiHat => RouteNames.admin,
    // QW1 personas land on the Admin Hub; isolation journeys deep-link from here.
    QaLoginPersona.hr => RouteNames.admin,
    QaLoginPersona.schoolAdmin => RouteNames.admin,
    QaLoginPersona.director => RouteNames.admin,
    QaLoginPersona.staff => RouteNames.admin,
    QaLoginPersona.chainDirector => RouteNames.admin,
  };
}

/// Post-login route when staff session carries an ERP role claim.
String homeRouteForStaffErp(ErpRole erpRole) {
  return switch (erpRole) {
    ErpRole.financeAdmin => RouteNames.financeDashboard,
    ErpRole.inventoryManager => RouteNames.inventoryDashboard,
    ErpRole.principal => RouteNames.managementDashboard,
    ErpRole.vicePrincipal => RouteNames.managementDashboard,
    ErpRole.superAdmin => RouteNames.admin,
    _ => RouteNames.admin,
  };
}
