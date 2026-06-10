import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Timetable RBAC', () {
    test('timetable route maps to viewAcademicTimetable', () {
      expect(
        erpRoutePermissionFor(RouteNames.managementTimetable),
        Permission.viewAcademicTimetable,
      );
    });

    test('principal can view and publish timetables', () {
      final rbac = RbacService(UserPermissions.forRole(ErpRole.principal));
      expect(canAccessErpRoute(rbac, RouteNames.managementTimetable), isTrue);
      expect(rbac.hasPermission(Permission.manageAcademicTimetable), isTrue);
      expect(rbac.hasPermission(Permission.publishAcademicTimetable), isTrue);
    });

    test('financeAdmin cannot access timetable route', () {
      final rbac = RbacService(UserPermissions.forRole(ErpRole.financeAdmin));
      expect(canAccessErpRoute(rbac, RouteNames.managementTimetable), isFalse);
    });
  });
}
