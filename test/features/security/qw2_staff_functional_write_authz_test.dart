import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/mutation_permission_registry.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW2 Batch 1 — Staff (functional manager) module-write authorization.
///
/// QA-J-022/026/027/028/029/030 share one gap: the per-module write/persistence
/// e2e suites (hr_payroll, library_issue_return, transport_route, hostel_*,
/// inventory_po, admissions) all run as **superAdmin**. QW2 asks: prove the
/// *scoped functional role* — not a god-login — is authorized for its own
/// module's writes, is denied OTHER modules' writes, and (J-029) cannot escalate
/// a create verb into an approve verb. This is the deterministic authorization
/// proof against the SAME `MutationPermissionRegistry` gate the real mutations
/// use; the persistence chain itself is already proven by the existing e2e suites.
UserPermissions _role(ErpRole r) => UserPermissions.forRole(r);

/// The permission the registry requires for [module]/[mutationId].
Permission _gate(String module, String mutationId) =>
    MutationPermissionRegistry.forModule(module)
        .firstWhere((e) => e.mutationId == mutationId)
        .permission;

void main() {
  group('QW2 · staff functional write authorization', () {
    test('QA-J-026 · Librarian is authorized to issue/return books, denied '
        'finance + HR', () {
      final lib = _role(ErpRole.librarian);
      expect(lib.has(_gate('library', 'issueLibraryBook')), isTrue);
      expect(lib.has(_gate('library', 'returnLibraryBook')), isTrue);
      expect(lib.has(Permission.manageFinance), isFalse);
      expect(lib.has(Permission.manageHr), isFalse);
      expect(lib.has(Permission.manageTransport), isFalse);
    });

    test('QA-J-027 · Transport manager is authorized for route/allocation/'
        'boarding-attendance writes, denied hostel + finance', () {
      final tm = _role(ErpRole.transportManager);
      expect(tm.has(_gate('transport', 'assignStudentTransport')), isTrue);
      expect(tm.has(_gate('transport', 'recordAttendance')), isTrue);
      expect(tm.has(_gate('transport', 'notifyRouteDelay')), isTrue);
      expect(tm.has(Permission.manageHostel), isFalse);
      expect(tm.has(Permission.manageFinance), isFalse);
    });

    test('QA-J-028 · Hostel manager is authorized for room assign / check-in-out,'
        ' denied transport + finance', () {
      final hm = _role(ErpRole.hostelManager);
      expect(hm.has(_gate('hostel', 'assignHostelRoom')), isTrue);
      expect(hm.has(_gate('hostel', 'admitHostelStudent')), isTrue);
      expect(hm.has(_gate('hostel', 'checkoutHostelStudent')), isTrue);
      expect(hm.has(Permission.manageTransport), isFalse);
      expect(hm.has(Permission.manageFinance), isFalse);
    });

    test('QA-J-029 · Storekeeper can CREATE a PO but is DENIED the APPROVE verb '
        '(no create→approve escalation); inventory manager holds both', () {
      final store = _role(ErpRole.storekeeper);
      final inv = _role(ErpRole.inventoryManager);
      // Create is allowed for the storekeeper...
      expect(store.has(_gate('inventory', 'createProcurementOrder')), isTrue);
      // ...but the approval verb is NOT (the row's anti-escalation point).
      expect(store.has(_gate('inventory', 'approveProcurementHandoff')), isFalse);
      // The full inventory manager holds both verbs.
      expect(inv.has(_gate('inventory', 'createProcurementOrder')), isTrue);
      expect(inv.has(_gate('inventory', 'approveProcurementHandoff')), isTrue);
    });

    test('QA-J-030 · Admissions counselor can MANAGE leads but cannot APPROVE '
        'applications, and is denied finance + HR', () {
      final c = _role(ErpRole.admissionsCounselor);
      // Capture / follow-up / convert leads → manageAdmissions.
      expect(c.has(_gate('admissions', 'createLead')), isTrue);
      expect(c.has(_gate('admissions', 'updateLead')), isTrue);
      // Approving an application is a higher verb the counselor lacks.
      expect(c.has(_gate('admissions', 'approveApplication')), isFalse);
      expect(c.has(Permission.manageFinance), isFalse);
      expect(c.has(Permission.manageHr), isFalse);
    });

    test('QA-J-022 · HR is authorized for employee + payroll/leave writes '
        '(manageHr), denied finance + SIS', () {
      // Payroll has no dedicated mutation — HR module writes gate on manageHr,
      // which the scoped HR persona carries (the same path payroll runs under).
      expect(_gate('hr', 'createEmployee'), Permission.manageHr);
      expect(_gate('hr', 'approveLeaveRequest'), Permission.manageHr);
      // The curated HR persona scope (manageHr) — authorized for HR writes only.
      final hrScoped = UserPermissions.fromClaims(
        roles: const [ErpRole.management],
        explicitPermissions: const [Permission.manageHr, Permission.viewHr],
      );
      expect(hrScoped.has(_gate('hr', 'createEmployee')), isTrue);
      expect(hrScoped.has(_gate('hr', 'approveLeaveRequest')), isTrue);
      expect(hrScoped.has(Permission.manageFinance), isFalse);
      expect(hrScoped.has(Permission.manageSis), isFalse);
    });
  });
}
