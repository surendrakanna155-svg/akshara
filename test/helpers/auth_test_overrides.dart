import 'package:akshara_erp/core/auth/auth_security_providers.dart';
import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/auth_provider.dart';
import 'package:akshara_erp/features/auth/auth_token_provider.dart';
import 'package:akshara_erp/features/auth/token_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences-backed secure storage overrides for auth unit tests.
List<Override> authStorageTestOverrides(SharedPreferences prefs) {
  final backend = PreferencesStorageBackend(prefs);
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    secureStorageBackendProvider.overrideWith((ref) => backend),
    tokenStorageProvider.overrideWith((ref) => TokenStorage(backend)),
  ];
}

/// Pins [authProvider] to a fixed [AuthState] for widget/router tests.
class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

/// Staff super-admin session for ERP widget tests (manage/approve actions visible).
AuthState erpWidgetTestStaffAuth() {
  return AuthState(
    status: AuthStatus.authenticated,
    phoneNumber: '9999999999',
    displayName: 'ERP Test Admin',
    role: UserRole.staff,
    claims: AuthClaims.demoForRole(erpRole: ErpRole.superAdmin),
  );
}

/// Override for [authProvider] with a static session snapshot.
Override authStateOverride(AuthState state) {
  return authProvider.overrideWith(() => TestAuthNotifier(state));
}
