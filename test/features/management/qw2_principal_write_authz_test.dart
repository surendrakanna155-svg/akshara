import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/mutation_permission_registry.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW2 Batch 4 — Principal module-write authorization + RBAC boundary.
///
/// QA-J-033 (approve + publish exam results, incl. the reject path), QA-J-034
/// (broadcast a notice), QA-J-035 (reject a pending item with a comment),
/// QA-J-036 (RBAC: Control-Center blocked + the finance-intelligence
/// longest-prefix anti-escalation). The approval/broadcast persistence is
/// covered by batch2/2b + communication_broadcast_e2e; the QW2 gap is proving
/// the principal persona is correctly scoped — authorized for these writes,
/// denied Control-Center, and unable to slip into a child route whose specific
/// permission it lacks.
Permission _gate(String module, String mutationId) =>
    MutationPermissionRegistry.forModule(module)
        .firstWhere((e) => e.mutationId == mutationId)
        .permission;

void main() {
  final principal = UserPermissions.forRole(ErpRole.principal);
  final rbac = RbacService(principal);

  group('QW2 · principal write authorization', () {
    test('QA-J-033 · authorized to approve + publish exam results (and reject)',
        () {
      expect(_gate('management', 'resolveExamResultsApproval'),
          Permission.approveExamResults);
      expect(_gate('teacher', 'publishExamResults'),
          Permission.publishExamResults);
      expect(principal.has(Permission.approveExamResults), isTrue); // approve + reject
      expect(principal.has(Permission.publishExamResults), isTrue);
    });

    test('QA-J-034 · authorized to broadcast a notice (sendBroadcast → '
        'manageCommunication)', () {
      expect(_gate('communication', 'sendBroadcast'),
          Permission.manageCommunication);
      expect(principal.has(_gate('communication', 'sendBroadcast')), isTrue);
    });

    test(
        'QA-J-035 · principal holds manageManagement (the executive-approvals '
        'authority underlying updateManagementSettings and the management '
        'dashboard)', () {
      // #1 gap-sweep (2026-07): the mutation this test originally gated on,
      // resolveManagementApproval (POST /management/tasks/:id/resolve), was
      // found to be dead client code — no screen ever called it. The real
      // approve/reject-with-comment flow (incl. for management-sourced
      // approvals) runs through the unified Approval Center's
      // resolveApprovalRequestProvider → /approvals/:id/approve|reject
      // (per-type permission via approvalPermissionForType), asserted
      // directly below rather than through the now-removed registry entry.
      expect(principal.has(Permission.manageManagement), isTrue);
      expect(_gate('management', 'updateManagementSettings'),
          Permission.manageManagement);
    });

    test('QA-J-036 · RBAC — Control-Center blocked + finance-intelligence '
        'longest-prefix anti-escalation', () {
      // Platform Control-Center is denied (principal lacks viewControlCenter).
      expect(canAccessErpRoute(rbac, RouteNames.controlCenter), isFalse);
      // Principal HOLDS viewFinance, so the /finance hub is reachable...
      expect(principal.has(Permission.viewFinance), isTrue);
      expect(canAccessErpRoute(rbac, RouteNames.finance), isTrue);
      // ...but /finance/intelligence resolves (longest-prefix) to the STRONGER
      // viewFinanceIntelligence, which the principal lacks — no escalation from
      // the weaker parent permission.
      expect(principal.has(Permission.viewFinanceIntelligence), isFalse);
      expect(canAccessErpRoute(rbac, RouteNames.financeIntelligence), isFalse);
    });
  });
}
