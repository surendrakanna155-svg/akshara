import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audit/audit_event.dart';
import '../repositories/api/auth/mapper/auth_mapper.dart';
import '../../features/auth/auth_token_models.dart';
import '../security/erp_role.dart';
import 'auth_repository_providers.dart';
import 'auth_security_providers.dart';
import 'auth_session_manager.dart';
import 'jwt_decoder.dart';
import 'token_refresh_service.dart';

export 'auth_repository_providers.dart'
    show authRepositoryProvider, isAuthApiEnabled, syncAuthPermissions, loadCachedServerPermissions;
export '../repositories/repository_config.dart' show authApiEnabledProvider;

final jwtDecoderProvider = Provider<JwtDecoder>((ref) => jwtDecoder);

final tokenRefreshServiceProvider = Provider<TokenRefreshService>((ref) {
  final service = TokenRefreshService();
  ref.onDispose(service.dispose);
  return service;
});

final authSessionManagerProvider = Provider<AuthSessionManager>((ref) {
  final manager = AuthSessionManager(
    refreshService: ref.watch(tokenRefreshServiceProvider),
    validator: ref.watch(jwtValidatorProvider),
    rotationTracker: ref.watch(refreshTokenRotationTrackerProvider),
    expirationPolicy: ref.watch(sessionExpirationPolicyProvider),
    revocationService: ref.watch(tokenRevocationServiceProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

/// Production refresh hook — uses auth remote when API mode is enabled.
final tokenRefreshCallbackProvider = Provider<TokenRefreshCallback?>((ref) {
  if (isAuthApiEnabled(ref)) {
    final remote = ref.read(authRemoteDataSourceProvider);
    const mapper = AuthMapper();
    final onAudit = ref.read(authRepositoryAuditHookProvider);
    return (refreshToken) async {
      try {
        final dto =
            await remote.refreshToken(refreshToken: refreshToken);
        final tokens = mapper.toTokens(dto);
        if (tokens.accessToken.isEmpty) return null;
        onAudit(AuditEventType.tokenRefresh);
        return tokens;
      } on Object {
        return null;
      }
    };
  }

  return (refreshToken) async {
    if (refreshToken.isEmpty) return null;
    final now = DateTime.now();
    return AuthTokens(
      accessToken: JwtDecoder.buildMockToken(
        subject: 'refreshed_user',
        tenantId: 'tenant_demo_001',
        role: ErpRole.superAdmin.name,
        ttl: const Duration(hours: 1),
      ),
      refreshToken: refreshToken,
      expiresAt: now.add(const Duration(hours: 1)),
    );
  };
});
