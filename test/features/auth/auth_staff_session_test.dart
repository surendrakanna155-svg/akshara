import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/auth_provider.dart';
import 'package:akshara_erp/features/auth/auth_session_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/auth_test_overrides.dart';


void main() {
  group('staff ERP sessions', () {
    test('signInStaff persists claims and ERP role preference', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: authStorageTestOverrides(prefs),
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signInStaff(
            phoneNumber: '9876543210',
            displayName: 'Finance Lead',
            erpRole: ErpRole.financeAdmin,
          );

      final auth = container.read(authProvider);
      expect(auth.role, UserRole.staff);
      expect(auth.claims?.erpRole, ErpRole.financeAdmin);
      expect(container.read(canViewFinanceProvider), isTrue);
      expect(container.read(canViewControlCenterProvider), isFalse);

      // SEC-3: the PII session snapshot is now written to the (encrypted in
      // production) secure backend under its dedicated key, not the legacy
      // plaintext key. The test's secure backend is preferences-backed.
      expect(prefs.getString(kAuthSessionStorageKey), isNull);
      final raw = prefs.getString(kAuthSessionSecureKey);
      expect(raw, isNotNull);
      expect(raw, contains('financeAdmin'));
    });

    test('setStaffErpRole updates active staff claims', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: authStorageTestOverrides(prefs),
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signInStaff(
            phoneNumber: '9876543210',
            displayName: 'Ops',
            erpRole: ErpRole.superAdmin,
          );
      await container
          .read(authProvider.notifier)
          .setStaffErpRole(ErpRole.admissionsCounselor);

      expect(container.read(authProvider).claims?.erpRole,
          ErpRole.admissionsCounselor);
      expect(container.read(canManageAdmissionsProvider), isTrue);
      expect(container.read(canViewFinanceProvider), isFalse);
    });
  });
}
