import 'package:akshara_erp/core/security/mutation_permission_registry.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Mutation permission coverage', () {
    test('registry includes admissions finance and sis mutations', () {
      for (final module in ['admissions', 'finance', 'sis']) {
        expect(
          MutationPermissionRegistry.forModule(module),
          isNotEmpty,
          reason: module,
        );
      }
    });

    test('approveRefund requires approveRefunds permission', () {
      final entry = MutationPermissionRegistry.entries.firstWhere(
        (e) => e.mutationId == 'approveRefund',
      );
      expect(entry.permission, Permission.approveRefunds);
      expect(entry.kind, 'approve');
    });

    test('all entries use manage or approve permission enums', () {
      for (final entry in MutationPermissionRegistry.entries) {
        expect(
          entry.permission.name.startsWith('manage') ||
              entry.permission.name.startsWith('approve'),
          isTrue,
          reason: entry.mutationId,
        );
      }
    });
  });
}
