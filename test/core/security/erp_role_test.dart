import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErpRole', () {
    test('fromName resolves all roles', () {
      for (final role in ErpRole.values) {
        expect(ErpRole.fromName(role.name), role);
      }
    });

    test('fromName returns null for unknown values', () {
      expect(ErpRole.fromName('unknown'), isNull);
      expect(ErpRole.fromName(''), isNull);
      expect(ErpRole.fromName(null), isNull);
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
