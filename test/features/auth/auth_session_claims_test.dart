import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/auth_session_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PersistedAuthSession claims', () {
    test('serializes claims in session JSON', () {
      final state = AuthState(
        status: AuthStatus.authenticated,
        phoneNumber: '9876543210',
        displayName: 'Staff User',
        role: UserRole.staff,
        claims: AuthClaims.demoForRole(erpRole: ErpRole.principal),
      );

      final session = PersistedAuthSession.fromAuthState(state);
      final json = session.toJson();
      expect(json['claims'], isA<Map<String, dynamic>>());
      expect(json['claims']['role'], 'principal');

      final restored = PersistedAuthSession.fromJson(json);
      expect(restored.claims?.erpRole, ErpRole.principal);
    });

    test('v1 sessions without claims remain valid', () {
      final session = PersistedAuthSession.fromJson({
        'isLoggedIn': true,
        'phoneNumber': '9876543210',
        'displayName': 'Teacher',
        'role': 'teacher',
        'selectedChildId': '',
        'selectedChildName': '',
        'selectedChildClass': '',
      });
      expect(session.isValid, isTrue);
      expect(session.claims, isNull);
    });
  });
}
