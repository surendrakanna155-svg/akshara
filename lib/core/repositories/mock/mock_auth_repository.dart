import '../../../features/auth/auth_token_models.dart';
import '../../auth/jwt_decoder.dart';
import '../../security/erp_role.dart';
import '../interfaces/auth_repository.dart';

/// Mock auth repository for development and contract tests.
class MockAuthRepository implements AuthRepository {
  const MockAuthRepository({this.defaultRole = ErpRole.superAdmin});

  static const validOtp = '654321';

  final ErpRole defaultRole;

  @override
  Future<AuthSession> login(
    String identifier, {
    String identifierType = 'email',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!_isValidIdentifier(identifier, identifierType)) {
      return const AuthSession(
        success: false,
        message: 'Enter a valid email or 10-digit mobile number.',
      );
    }
    return const AuthSession(success: true);
  }

  @override
  Future<AuthVerificationResult?> verifyOtp(
    String identifier,
    String otp, {
    String identifierType = 'email',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final code = otp.trim();
    final isValid =
        code == validOtp || (code.length == 6 && int.tryParse(code) != null);
    if (!isValid) return null;

    final userId = 'staff_${_normalize(identifier)}';
    final expiresAt = DateTime.now().add(const Duration(hours: 1));
    final accessToken = JwtDecoder.buildMockToken(
      subject: userId,
      tenantId: 'tenant_demo_001',
      schoolId: 'school_akshara_001',
      organizationId: 'org_akshara_001',
      role: defaultRole.name,
      ttl: const Duration(hours: 1),
    );

    final tokens = AuthTokens(
      accessToken: accessToken,
      refreshToken: 'staff_refresh_${expiresAt.millisecondsSinceEpoch}',
      expiresAt: expiresAt,
    );

    final user = AuthUser(
      id: userId,
      displayName: _displayNameFor(identifier, identifierType),
      erpRole: defaultRole,
      tenantId: 'tenant_demo_001',
      schoolId: 'school_akshara_001',
      organizationId: 'org_akshara_001',
      email: identifierType == 'email' ? identifier : null,
      mobile: identifierType == 'mobile' ? identifier : null,
    );

    return AuthVerificationResult(
      tokens: tokens,
      user: user,
      permissions: const [],
    );
  }

  @override
  Future<AuthTokens?> refreshToken(String refreshToken) async {
    if (refreshToken.isEmpty) return null;
    final now = DateTime.now();
    return AuthTokens(
      accessToken: JwtDecoder.buildMockToken(
        subject: 'refreshed_user',
        tenantId: 'tenant_demo_001',
        role: defaultRole.name,
        ttl: const Duration(hours: 1),
      ),
      refreshToken: refreshToken,
      expiresAt: now.add(const Duration(hours: 1)),
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthUser> getCurrentUser() async {
    return AuthUser(
      id: 'staff_mock_user',
      displayName: 'Staff User',
      erpRole: defaultRole,
      tenantId: 'tenant_demo_001',
      schoolId: 'school_akshara_001',
      organizationId: 'org_akshara_001',
    );
  }

  @override
  Future<List<ServerPermission>> getPermissions() async => const [];

  bool _isValidIdentifier(String raw, String type) {
    final value = raw.trim();
    return switch (type) {
      'mobile' => value.replaceAll(RegExp(r'\D'), '').length == 10,
      _ => RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value),
    };
  }

  String _normalize(String raw) =>
      raw.trim().replaceAll(RegExp(r'\D'), '').toLowerCase();

  String _displayNameFor(String identifier, String type) {
    if (type == 'email') {
      final local = identifier.split('@').first;
      return local.isEmpty ? 'Staff User' : local;
    }
    return 'Staff User';
  }
}
