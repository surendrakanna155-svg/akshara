import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW2 Batch 6 (closeable) — HR bulk-import + finance→parent receipt scoping.
///
/// QA-J-021 (HR bulk-imports employees via Excel) and QA-J-025 (a finance
/// collection's receipt reaches the parent). The import/commit + collect/receipt
/// persistence is covered by the existing HR + finance e2e suites and the QW1
/// money loop; the QW2 gap is proving the right roles own each side — HR owns
/// the employee import, finance owns the collection write, and the parent (a
/// different shell) is the read-side recipient — not a single god-login.
UserPermissions _persona(QaLoginPersona p) => UserPermissions.fromClaims(
      roles: p.erpRoles,
      explicitPermissions: p.customPermissions,
    );

void main() {
  group('QW2 · HR import + finance→parent receipt scoping', () {
    test('QA-J-021 · HR is authorized to bulk-import employees '
        '(manageEmployees/manageHr); non-HR roles are not', () {
      final hr = _persona(QaLoginPersona.hr);
      expect(hr.has(Permission.manageEmployees), isTrue);
      expect(hr.has(Permission.manageHr), isTrue);
      // A scoped non-HR role cannot import employees.
      for (final r in [ErpRole.financeAdmin, ErpRole.librarian, ErpRole.teacher]) {
        expect(UserPermissions.forRole(r).has(Permission.manageEmployees), isFalse,
            reason: '$r must not import employees');
      }
    });

    test('QA-J-025 · Finance owns the collection write (manageFinance); the '
        'parent is the read-side receipt recipient (viewParentExperience) — '
        'and neither role holds the other\'s', () {
      final finance = UserPermissions.forRole(ErpRole.financeAdmin);
      final parent = UserPermissions.forRole(ErpRole.parent);
      // Finance writes the collection / receipt...
      expect(finance.has(Permission.manageFinance), isTrue);
      expect(parent.has(Permission.manageFinance), isFalse);
      // ...the parent reads it in their own shell, but cannot collect.
      expect(parent.has(Permission.viewParentExperience), isTrue);
      expect(finance.has(Permission.viewParentExperience), isFalse);
    });
  });
}
