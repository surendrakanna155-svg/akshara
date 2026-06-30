import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW5 · QA-J-045 — School Admin · auto-allocate rooms/labs + syllabus automation.
///
/// Both are REAL backend writes in `school_completion`:
/// `phase10_handlers.ts` → `handleAllocateRooms` (gated `manageAcademicRooms`,
/// line 218) and `handleGenerateSyllabus` (gated `manageSyllabus`, line 45),
/// each persisting + emitting a mutation audit. Their route contracts are already
/// asserted by `qw4_school_completion_route_contract_test.ts`. These mutations are
/// server-enforced (not in the client `MutationPermissionRegistry`), so this
/// proves the persona authorization: the School Admin who runs the academic
/// build holds both verbs, while teaching/finance/parent personas do not.
UserPermissions _role(ErpRole r) => UserPermissions.forRole(r);

void main() {
  group('QW5 · QA-J-045 schoolAdmin room/syllabus automation authz', () {
    test('School Admin is authorized to auto-allocate rooms and auto-generate '
        'syllabus', () {
      final admin = _role(ErpRole.schoolAdmin);
      expect(admin.has(Permission.manageAcademicRooms), isTrue);
      expect(admin.has(Permission.manageSyllabus), isTrue);
    });

    test('Non-academic-build personas are DENIED room allocation + syllabus '
        'generation', () {
      // Teaching staff and functional managers cannot run the school-wide
      // academic-build automation; parents certainly cannot.
      expect(_role(ErpRole.teacher).has(Permission.manageAcademicRooms),
          isFalse);
      expect(_role(ErpRole.teacher).has(Permission.manageSyllabus), isFalse);
      expect(_role(ErpRole.financeAdmin).has(Permission.manageAcademicRooms),
          isFalse);
      expect(_role(ErpRole.financeAdmin).has(Permission.manageSyllabus),
          isFalse);
      expect(_role(ErpRole.parent).has(Permission.manageAcademicRooms), isFalse);
      expect(_role(ErpRole.parent).has(Permission.manageSyllabus), isFalse);
    });
  });
}
