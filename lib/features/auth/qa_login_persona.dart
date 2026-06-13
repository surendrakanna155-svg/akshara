import '../../core/security/erp_role.dart';
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
  superAdmin;

  String get buttonLabel => switch (this) {
        QaLoginPersona.principal => 'Principal',
        QaLoginPersona.teacher => 'Teacher',
        QaLoginPersona.parent => 'Parent',
        QaLoginPersona.student => 'Student',
        QaLoginPersona.finance => 'Finance',
        QaLoginPersona.inventory => 'Inventory',
        QaLoginPersona.superAdmin => 'Super Admin',
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
      };

  String get demoPhone => switch (this) {
        QaLoginPersona.principal => '9876543210',
        QaLoginPersona.teacher => '9000000001',
        QaLoginPersona.parent => '9000100001',
        QaLoginPersona.student => '9876543212',
        QaLoginPersona.finance => '9999999991',
        QaLoginPersona.inventory => '9999999992',
        QaLoginPersona.superAdmin => '9999999999',
      };

  String get displayName => switch (this) {
        QaLoginPersona.principal => 'QA Principal',
        QaLoginPersona.teacher => 'QA Teacher',
        QaLoginPersona.parent => 'QA Parent',
        QaLoginPersona.student => 'QA Student',
        QaLoginPersona.finance => 'QA Finance',
        QaLoginPersona.inventory => 'QA Inventory',
        QaLoginPersona.superAdmin => 'QA Super Admin',
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
  };
}

/// Post-login route when staff session carries an ERP role claim.
String homeRouteForStaffErp(ErpRole erpRole) {
  return switch (erpRole) {
    ErpRole.financeAdmin => RouteNames.financeDashboard,
    ErpRole.inventoryManager => RouteNames.inventoryDashboard,
    ErpRole.principal => RouteNames.managementDashboard,
    ErpRole.superAdmin => RouteNames.admin,
    _ => RouteNames.admin,
  };
}
