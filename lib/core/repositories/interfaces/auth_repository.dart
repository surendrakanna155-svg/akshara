import '../../../features/auth/auth_token_models.dart';
import '../../security/erp_role.dart';
import '../../security/permissions.dart';
import '../../security/server_permission_models.dart';

/// OTP login session started after identifier submission.
class AuthSession {
  const AuthSession({
    required this.success,
    this.message,
    this.sessionId,
  });

  final bool success;
  final String? message;
  final String? sessionId;
}

/// Result of successful OTP verification.
class AuthVerificationResult {
  const AuthVerificationResult({
    required this.tokens,
    required this.user,
    required this.permissions,
  });

  final AuthTokens tokens;
  final AuthUser user;
  final List<ServerPermission> permissions;
}

/// Authenticated user profile from the auth server.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.displayName,
    required this.erpRole,
    required this.tenantId,
    this.email,
    this.mobile,
    this.schoolId,
    this.organizationId,
    this.scope,
    this.childIds = const [],
  });

  final String id;
  final String displayName;
  final ErpRole erpRole;
  final String tenantId;
  final String? email;
  final String? mobile;
  final String? schoolId;
  final String? organizationId;

  /// Auth scope from server (`parent`, `teacher`, `student`, `school`).
  final String? scope;

  /// Linked child ids for parent accounts.
  final List<String> childIds;
}

/// Server-granted permission entry.
class ServerPermission {
  const ServerPermission({
    required this.permission,
    this.source = 'server',
    this.expiresAt,
  });

  final Permission permission;
  final String source;
  final DateTime? expiresAt;
}

/// Contract for authentication data access (mock or API).
abstract class AuthRepository {
  Future<AuthSession> login(
    String identifier, {
    String identifierType = 'email',
  });

  Future<AuthVerificationResult?> verifyOtp(
    String identifier,
    String otp, {
    String identifierType = 'email',
  });

  Future<AuthTokens?> refreshToken(String refreshToken);

  Future<void> logout();

  /// Revokes a single session server-side (admin or self-service).
  Future<void> revokeSession(String sessionId, {String? reason});

  /// Revokes all active sessions for the current user.
  Future<void> logoutAllSessions();

  Future<AuthUser> getCurrentUser();

  Future<List<ServerPermission>> getPermissions();

  /// Fetches server RBAC policy including permissions version metadata.
  Future<ServerPermissionPolicy> fetchPermissionPolicy({
    required String userId,
    String? tenantId,
  });
}
