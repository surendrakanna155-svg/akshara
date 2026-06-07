import '../../../../../features/auth/auth_token_models.dart';
import '../../../interfaces/auth_repository.dart';
import '../../../../security/erp_role.dart';
import '../../../../security/permissions.dart';
import '../../../../security/server_permission_models.dart';
import '../dto/auth_login_dto.dart';
import '../dto/auth_permissions_dto.dart';
import '../dto/auth_tokens_dto.dart';
import '../dto/auth_user_dto.dart';
import '../dto/auth_verify_otp_dto.dart';

/// Maps Auth API DTOs to domain models.
class AuthMapper {
  const AuthMapper();

  AuthSession toLoginSession(AuthLoginDto dto) {
    final raw = dto.raw;
    return AuthSession(
      success: raw['success'] as bool? ?? true,
      message: raw['message'] as String?,
      sessionId: raw['sessionId'] as String?,
    );
  }

  AuthVerificationResult toVerificationResult(AuthVerifyOtpDto dto) {
    final raw = dto.raw;
    return AuthVerificationResult(
      tokens: toTokens(AuthTokensDto(raw: _tokenPayload(raw))),
      user: toUser(AuthUserDto(raw: _userPayload(raw))),
      permissions: toServerPermissions(
        AuthPermissionsDto(
          items: _permissionsPayload(raw),
        ),
      ),
    );
  }

  AuthTokens toTokens(AuthTokensDto dto) {
    final raw = dto.raw;
    final expiresRaw = raw['expiresAt'] as String? ??
        raw['accessTokenExpiresAt'] as String? ??
        '';
    final expiresAt = DateTime.tryParse(expiresRaw) ??
        DateTime.now().add(const Duration(hours: 1));
    return AuthTokens(
      accessToken: raw['accessToken'] as String? ?? '',
      refreshToken: raw['refreshToken'] as String? ?? '',
      expiresAt: expiresAt,
      sessionId: raw['sessionId'] as String?,
      refreshTokenId: raw['refreshTokenId'] as String?,
      tokenFamilyId: raw['tokenFamilyId'] as String?,
      deviceId: raw['deviceId'] as String?,
    );
  }

  AuthUser toUser(AuthUserDto dto) {
    final raw = dto.raw;
    return AuthUser(
      id: raw['id'] as String? ?? raw['userId'] as String? ?? '',
      displayName: raw['displayName'] as String? ??
          raw['name'] as String? ??
          'Staff User',
      erpRole: ErpRole.fromName(
            raw['role'] as String? ?? raw['erpRole'] as String?,
          ) ??
          ErpRole.superAdmin,
      tenantId: raw['tenantId'] as String? ?? '',
      email: raw['email'] as String?,
      mobile: raw['mobile'] as String? ?? raw['phone'] as String?,
      schoolId: raw['schoolId'] as String?,
      organizationId: raw['organizationId'] as String?,
    );
  }

  List<ServerPermission> toServerPermissions(AuthPermissionsDto dto) {
    return [
      for (final item in dto.items)
        if (_parsePermission(item) case final permission?)
          ServerPermission(
            permission: permission,
            source: item['source'] as String? ?? 'server',
            expiresAt: DateTime.tryParse(item['expiresAt'] as String? ?? ''),
          ),
    ];
  }

  ServerPermissionPolicy toPermissionPolicy({
    required List<ServerPermission> permissions,
    required String userId,
    String? tenantId,
    int version = 1,
  }) {
    final now = DateTime.now();
    return ServerPermissionPolicy(
      version: version,
      grants: [
        for (final entry in permissions)
          PermissionGrant(
            permission: entry.permission,
            grantedAt: now,
            source: entry.source,
            expiresAt: entry.expiresAt,
          ),
      ],
      revocations: const [],
      syncedAt: now,
      tenantId: tenantId,
      userId: userId,
    );
  }

  Permission? _parsePermission(Map<String, dynamic> item) {
    final name = item['permission'] as String? ??
        item['name'] as String? ??
        item['code'] as String?;
    if (name == null || name.isEmpty) return null;
    for (final permission in Permission.values) {
      if (permission.name == name) return permission;
    }
    return null;
  }

  Map<String, dynamic> _tokenPayload(Map<String, dynamic> raw) {
    if (raw.containsKey('accessToken')) return raw;
    final nested = raw['tokens'];
    if (nested is Map<String, dynamic>) return nested;
    return raw;
  }

  Map<String, dynamic> _userPayload(Map<String, dynamic> raw) {
    if (raw.containsKey('userId') || raw.containsKey('id')) return raw;
    final nested = raw['user'];
    if (nested is Map<String, dynamic>) return nested;
    return raw;
  }

  List<Map<String, dynamic>> _permissionsPayload(Map<String, dynamic> raw) {
    final permissions = raw['permissions'];
    if (permissions is List) {
      return [
        for (final item in permissions)
          if (item is Map<String, dynamic>) item
          else if (item is String) {'permission': item},
      ];
    }
    return const [];
  }
}
