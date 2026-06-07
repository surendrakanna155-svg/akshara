import 'package:akshara_erp/core/auth/jwt_decoder.dart';
import 'package:akshara_erp/core/repositories/interfaces/auth_repository.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/features/auth/auth_token_models.dart';

/// Builds canned auth API envelopes for contract tests.
class AuthFixtureBuilder {
  const AuthFixtureBuilder();

  Map<String, dynamic> envelope(Map<String, dynamic> data) => {'data': data};

  Map<String, dynamic> loginEnvelope({bool success = true, String? message}) {
    return envelope({
      'success': success,
      if (message != null) 'message': message,
      'sessionId': 'session_001',
    });
  }

  Map<String, dynamic> verifyOtpEnvelope({
    String userId = 'staff_api_001',
    ErpRole role = ErpRole.superAdmin,
    List<Permission> permissions = const [Permission.viewAdminHub],
  }) {
    final expiresAt = DateTime.now().add(const Duration(hours: 1));
    final accessToken = JwtDecoder.buildMockToken(
      subject: userId,
      tenantId: 'tenant_demo_001',
      schoolId: 'school_akshara_001',
      organizationId: 'org_akshara_001',
      role: role.name,
      ttl: const Duration(hours: 1),
    );

    return envelope({
      'accessToken': accessToken,
      'refreshToken': 'refresh_${expiresAt.millisecondsSinceEpoch}',
      'expiresAt': expiresAt.toIso8601String(),
      'user': {
        'id': userId,
        'displayName': 'API Staff',
        'role': role.name,
        'tenantId': 'tenant_demo_001',
        'schoolId': 'school_akshara_001',
        'organizationId': 'org_akshara_001',
        'email': 'staff@school.edu',
      },
      'permissions': [
        for (final permission in permissions)
          {'permission': permission.name, 'source': 'server'},
      ],
    });
  }

  Map<String, dynamic> tokensEnvelope({String refreshToken = 'refresh_token'}) {
    final expiresAt = DateTime.now().add(const Duration(hours: 1));
    return envelope({
      'accessToken': JwtDecoder.buildMockToken(
        subject: 'refreshed_user',
        tenantId: 'tenant_demo_001',
        role: ErpRole.superAdmin.name,
        ttl: const Duration(hours: 1),
      ),
      'refreshToken': refreshToken,
      'expiresAt': expiresAt.toIso8601String(),
    });
  }

  Map<String, dynamic> userEnvelope({
    String userId = 'staff_api_001',
    ErpRole role = ErpRole.financeAdmin,
  }) {
    return envelope({
      'id': userId,
      'displayName': 'Finance Staff',
      'role': role.name,
      'tenantId': 'tenant_demo_001',
      'schoolId': 'school_akshara_001',
      'organizationId': 'org_akshara_001',
    });
  }

  Map<String, dynamic> permissionsEnvelope({
    List<Permission> permissions = const [
      Permission.viewFinance,
      Permission.manageFinance,
    ],
  }) {
    return envelope({
      'permissions': [
        for (final permission in permissions)
          {'permission': permission.name, 'source': 'server'},
      ],
    });
  }

  AuthVerificationResult expectedVerification({
    ErpRole role = ErpRole.superAdmin,
  }) {
    final raw = verifyOtpEnvelope(role: role);
    final data = raw['data'] as Map<String, dynamic>;
    final expiresAt =
        DateTime.parse(data['expiresAt'] as String);
    return AuthVerificationResult(
      tokens: AuthTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        expiresAt: expiresAt,
      ),
      user: AuthUser(
        id: 'staff_api_001',
        displayName: 'API Staff',
        erpRole: role,
        tenantId: 'tenant_demo_001',
        schoolId: 'school_akshara_001',
        organizationId: 'org_akshara_001',
        email: 'staff@school.edu',
      ),
      permissions: const [
        ServerPermission(
          permission: Permission.viewAdminHub,
          source: 'server',
        ),
      ],
    );
  }
}
