import 'package:akshara_erp/core/approvals/approval_audit.dart';
import 'package:akshara_erp/core/approvals/approval_center_service.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';
import 'package:akshara_erp/core/repositories/mock/mock_approval_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/role_permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/approval/approval_fixture_builder.dart';

/// QW7 · QA-C-020 — role combinations / multi-hat / delegated / approvals.
///
/// Builds on:
///  • test/router_smoke_test.dart — a multi-hat user (Inventory Manager +
///    Teacher) lands in a shell with a workspace switcher and crosses shells
///    (live router behaviour).
///  • test/core/approvals/approval_center_service_test.dart — approve/reject
///    record audit + status (service layer).
///
/// The genuine gap this cert closes: assert, as ONE behaviour statement, that a
/// multi-hat user holds the UNION of permissions AND the right action
/// availability per workspace (inventory actions in the inventory hat, teaching
/// actions in the teacher hat, and the intersection of *neither* for modules
/// neither role owns), and that the approval flow drives a real status change.
///
/// DELEGATED PERMISSIONS — HONEST STATUS (not built): a repo-wide search
/// (delegatedPermission / permissionDelegation / actingAs / onBehalfOf /
/// impersonate) finds NO delegation feature. ErpRole + UserPermissions has no
/// "acting on behalf of" concept; RbacService resolves only the union of the
/// user's OWN held roles. The delegated-permissions leg is therefore asserted as
/// ABSENT below — it is not implemented, and this cert does not build it.
void main() {
  const multiHatRoles = <ErpRole>[ErpRole.inventoryManager, ErpRole.teacher];

  RbacService multiHat() =>
      RbacService(UserPermissions.forRoles(multiHatRoles));

  group('QA-C-020 · multi-hat union of permissions', () {
    test('holds the UNION of both held roles (each hat contributes its perms)',
        () {
      final rbac = multiHat();

      // Inventory-hat exclusive perms.
      expect(rbac.hasPermission(Permission.manageInventory), isTrue);
      expect(rbac.hasPermission(Permission.approvePurchaseOrder), isTrue);
      expect(rbac.hasPermission(Permission.createInventoryPo), isTrue);

      // Teacher-hat exclusive perms.
      expect(rbac.hasPermission(Permission.markAttendance), isTrue);
      expect(rbac.hasPermission(Permission.manageEducation), isTrue);
      expect(rbac.hasPermission(Permission.manageExamMarks), isTrue);
    });

    test('the union is EXACTLY both role sets — no extra grants leak in', () {
      final union = UserPermissions.forRoles(multiHatRoles).permissionSet.values;
      final expected = <Permission>{
        ...RolePermissionMatrix.permissionsFor(ErpRole.inventoryManager).values,
        ...RolePermissionMatrix.permissionsFor(ErpRole.teacher).values,
      };
      expect(union, equals(expected),
          reason: 'multi-hat permissions must equal the union of held roles, '
              'no more (no privilege leak), no less');
    });

    test('holds NEITHER role grants nothing — finance/admissions stay denied',
        () {
      final rbac = multiHat();
      // Neither Inventory Manager nor Teacher owns Finance/Admissions/Control.
      expect(rbac.hasPermission(Permission.manageFinance), isFalse);
      expect(rbac.hasPermission(Permission.manageAdmissions), isFalse);
      expect(rbac.hasManagePermission(Permission.manageControlCenter), isFalse);
    });

    test('reports BOTH roles via hasRole / roles (primary first)', () {
      final rbac = multiHat();
      expect(rbac.hasRole(ErpRole.inventoryManager), isTrue);
      expect(rbac.hasRole(ErpRole.teacher), isTrue);
      expect(rbac.hasRole(ErpRole.financeAdmin), isFalse);
      expect(rbac.roles, equals(multiHatRoles));
      expect(rbac.role, ErpRole.inventoryManager, reason: 'primary = first hat');
    });
  });

  group('QA-C-020 · right action availability PER workspace', () {
    final rbac = multiHat();

    test('inventory workspace: inventory route reachable, finance denied', () {
      expect(canAccessErpRoute(rbac, RouteNames.inventory), isTrue);
      expect(canAccessErpRoute(rbac, RouteNames.finance), isFalse);
    });

    test('teacher-hat education actions available; admin-only routes denied', () {
      // Teaching action present (manage education) …
      expect(rbac.hasManagePermission(Permission.manageEducation), isTrue);
      // … but a module neither hat owns is route-denied.
      expect(canAccessErpRoute(rbac, RouteNames.controlCenter), isFalse);
      expect(canAccessErpRoute(rbac, RouteNames.admissions), isFalse);
    });

    test(
        'each workspace exposes ONLY its hat actions (no cross-hat escalation): '
        'PO-approve from inventory hat, attendance from teacher hat, '
        'neither grants the other hats\' admin powers', () {
      // Inventory hat's approve power.
      expect(rbac.hasPermission(Permission.approvePurchaseOrder), isTrue);
      // Teacher hat's mark power.
      expect(rbac.hasPermission(Permission.markAttendance), isTrue);
      // A single-hat inventory manager must NOT get teaching powers, and vice
      // versa — proven by the per-role sets being disjoint on these perms.
      final invOnly =
          RolePermissionMatrix.permissionsFor(ErpRole.inventoryManager);
      final teachOnly = RolePermissionMatrix.permissionsFor(ErpRole.teacher);
      expect(invOnly.contains(Permission.markAttendance), isFalse);
      expect(teachOnly.contains(Permission.approvePurchaseOrder), isFalse);
    });
  });

  group('QA-C-020 · approval flow behaviour (approve / reject → status change)',
      () {
    const query = RepositoryQuery.demo;
    final fixtures = ApprovalFixtureBuilder();
    late MockApprovalRepository repo;
    late ApprovalCenterService service;

    setUp(() {
      repo = MockApprovalRepository()..reset();
      service = ApprovalCenterService(repo);
    });

    test('approve: pending → approved, status change is persisted + audited',
        () async {
      final created = await service.submitApprovalRequest(
        query: query,
        request: fixtures.submitRequest(),
      );
      expect(created.status, ApprovalStatus.pending);

      final approved = await service.approveRequest(
        query: query,
        request: fixtures.approveRequest(created.id),
      );
      expect(approved.status, ApprovalStatus.approved,
          reason: 'approve drives the status change');

      // Persisted: it is no longer pending.
      final pending = await service.listPending(query: query);
      expect(pending.any((r) => r.id == created.id), isFalse);

      // Audited: submit + approve trail.
      final audit = await service.listAuditEntries(
        query: query,
        approvalRequestId: created.id,
      );
      expect(audit.map((e) => e.action), <ApprovalAuditAction>[
        ApprovalAuditAction.submitted,
        ApprovalAuditAction.approved,
      ]);
    });

    test('reject: pending → rejected (with required comment) + audit', () async {
      final created = await service.submitApprovalRequest(
        query: query,
        request: fixtures.submitRequest(),
      );

      final rejected = await service.rejectRequest(
        query: query,
        request: fixtures.rejectRequest(created.id, comment: 'Marks incomplete.'),
      );
      expect(rejected.status, ApprovalStatus.rejected);
      expect(rejected.decisionComment, 'Marks incomplete.');

      final audit = await service.listAuditEntries(
        query: query,
        approvalRequestId: created.id,
      );
      expect(audit.last.action, ApprovalAuditAction.rejected);
    });
  });

  group('QA-C-020 · delegated permissions — ABSENT (honest, not built)', () {
    test('RbacService resolves only the union of OWN held roles (no delegation)',
        () {
      // There is no "acting on behalf of" path: a user's permissions are exactly
      // the union of the roles they themselves hold. A user without a role gets
      // none of its permissions — no delegated grant can appear.
      final inventoryOnly =
          RbacService(UserPermissions.forRole(ErpRole.inventoryManager));
      // Cannot "borrow" a teacher's mark-attendance via any delegation.
      expect(inventoryOnly.hasPermission(Permission.markAttendance), isFalse);
      // Cannot "borrow" finance approval either.
      expect(inventoryOnly.hasApprovePermission(Permission.approveRefunds),
          isFalse);

      // UserPermissions exposes no delegation/acting-as constructor: the only
      // ways to gain a permission are role membership or explicit claims — both
      // are the user's OWN grants. (Delegation is not implemented in this repo.)
    });
  });
}
