import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/auth_provider.dart';
import 'package:akshara_erp/features/auth/auth_role_mapping.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/auth_test_overrides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('auth hardening', () {
    test('demo mode rejects random OTP', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: authStorageTestOverrides(prefs),
      );
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      await notifier.sendOtp('9876543210', UserRole.student);
      final ok = await notifier.verifyOtp('999999');

      expect(ok, isFalse);
      expect(container.read(authProvider).isAuthenticated, isFalse);
    });

    test('staging build rejects mock OTP without API override', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          ...authStorageTestOverrides(prefs),
          environmentProvider.overrideWith(
            (ref) => Environment.staging.copyWith(
              enableApiMode: false,
              disableDemoAuth: true,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      final sent = await notifier.sendOtp('9999999999', UserRole.student);
      expect(sent, isFalse);

      final verify = await notifier.verifyOtp(kMockValidOtp);
      expect(verify, isFalse);
    });

    test('userRoleFromErpRole maps student correctly', () {
      expect(
        userRoleFromErpRole(ErpRole.student),
        UserRole.student,
      );
    });
  });
}
