import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/mutation_permission_registry.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW5 · QA-J-031 — Staff (finance) · refund approve, verb-negative.
///
/// The refund collect/approve persistence chain is already proven by
/// `finance_full_journey_e2e`. The remaining P2 gap is the NEGATIVE verb guard:
/// refund APPROVAL is a separate, higher verb (`approveRefunds`, kind `approve`)
/// than general finance management (`manageFinance`). This proves — against the
/// real `MutationPermissionRegistry` and `RolePermissionMatrix` — that only the
/// finance approval scope holds it, and that broad-but-unrelated roles
/// (a principal, a teacher, other functional managers) cannot approve a refund
/// even though some manage other money/operational surfaces.
UserPermissions _role(ErpRole r) => UserPermissions.forRole(r);

Permission _gate(String module, String mutationId) =>
    MutationPermissionRegistry.forModule(module)
        .firstWhere((e) => e.mutationId == mutationId)
        .permission;

void main() {
  group('QW5 · QA-J-031 finance refund approve verb-negative', () {
    test('refund approve is gated by the dedicated approveRefunds verb '
        '(not manageFinance)', () {
      final gate = _gate('finance', 'approveRefund');
      expect(gate, Permission.approveRefunds);
      expect(gate, isNot(Permission.manageFinance));
    });

    test('the finance approval scope holds the verb', () {
      expect(_role(ErpRole.financeAdmin).has(Permission.approveRefunds), isTrue);
      expect(_role(ErpRole.schoolAdmin).has(Permission.approveRefunds), isTrue);
      expect(_role(ErpRole.superAdmin).has(Permission.approveRefunds), isTrue);
    });

    test('non-finance staff are DENIED the refund-approve verb (the guard)', () {
      // A principal manages many surfaces but does NOT carry approveRefunds
      // (separation of duties — no parent-perm escalation into refunds).
      expect(_role(ErpRole.principal).has(Permission.approveRefunds), isFalse);
      expect(_role(ErpRole.vicePrincipal).has(Permission.approveRefunds),
          isFalse);
      expect(_role(ErpRole.management).has(Permission.approveRefunds), isFalse);
      expect(_role(ErpRole.teacher).has(Permission.approveRefunds), isFalse);
      expect(_role(ErpRole.librarian).has(Permission.approveRefunds), isFalse);
      expect(_role(ErpRole.transportManager).has(Permission.approveRefunds),
          isFalse);
      expect(_role(ErpRole.storekeeper).has(Permission.approveRefunds), isFalse);
      expect(_role(ErpRole.parent).has(Permission.approveRefunds), isFalse);
      expect(_role(ErpRole.student).has(Permission.approveRefunds), isFalse);
    });
  });
}
