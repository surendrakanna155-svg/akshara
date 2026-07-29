import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErpRole', () {
    test('fromName resolves all SUPPORTED roles', () {
      // JOURNEY-002: `values` now includes the fail-closed sentinel, which is
      // deliberately NOT reachable by name — see the next test.
      for (final role in ErpRole.supportedValues) {
        expect(ErpRole.fromName(role.name), role);
      }
    });

    test('fromName returns null for unknown values', () {
      expect(ErpRole.fromName('unknown'), isNull);
      expect(ErpRole.fromName(''), isNull);
      expect(ErpRole.fromName(null), isNull);
    });

    test('the fail-closed sentinel is not selectable by name', () {
      // A server slug must never be able to name the sentinel; and `resolve`
      // must land on it for anything unmapped (never on a privileged role).
      expect(ErpRole.fromName(ErpRole.unsupported.name), isNull);
      expect(ErpRole.resolve('unsupported'), ErpRole.unsupported);
      expect(ErpRole.resolve('organizationOwner'), ErpRole.unsupported);
      expect(ErpRole.resolve(null), ErpRole.unsupported);
      expect(ErpRole.supportedValues.length, ErpRole.values.length - 1);
    });

    test('staffErpRoles excludes mobile-only roles', () {
      expect(ErpRole.staffErpRoles, isNot(contains(ErpRole.parent)));
      expect(ErpRole.staffErpRoles, isNot(contains(ErpRole.student)));
      expect(ErpRole.staffErpRoles, contains(ErpRole.superAdmin));
      expect(ErpRole.staffErpRoles, contains(ErpRole.financeAdmin));
      expect(ErpRole.staffErpRoles, contains(ErpRole.vicePrincipal));
    });

    test('labels are human readable', () {
      expect(ErpRole.superAdmin.label, 'Super Admin');
      expect(ErpRole.admissionsCounselor.label, 'Admissions Counselor');
      expect(ErpRole.transportManager.label, 'Transport Manager');
      expect(ErpRole.vicePrincipal.label, 'Vice Principal');
    });
  });
}
