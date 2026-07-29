import '../../core/security/erp_role.dart';
import '../../features/auth/auth_claims.dart';
import '../../features/auth/auth_token_models.dart';
import 'jwt_decoder.dart';
import 'jwt_validator.dart';
import 'refresh_token_rotation_tracker.dart';
import 'session_expiration_policy.dart';
import 'session_metadata.dart';
import 'token_refresh_service.dart';
import 'token_revocation_service.dart';

/// Session lifecycle events emitted to listeners.
enum AuthSessionEvent {
  restored,
  refreshed,
  expired,
  cleared,
  reuseDetected,
}

/// Coordinates JWT validation, refresh scheduling, and session expiry.
class AuthSessionManager {
  AuthSessionManager({
    JwtDecoder decoder = jwtDecoder,
    JwtValidator? validator,
    TokenRefreshService? refreshService,
    RefreshTokenRotationTracker? rotationTracker,
    SessionExpirationPolicy? expirationPolicy,
    TokenRevocationService? revocationService,
  })  : _decoder = decoder,
        _validator = validator ?? jwtValidator,
        _refreshService = refreshService ?? TokenRefreshService(decoder: decoder),
        _rotationTracker = rotationTracker ?? RefreshTokenRotationTracker(),
        _expirationPolicy = expirationPolicy ?? sessionExpirationPolicy,
        _revocationService = revocationService;

  final JwtDecoder _decoder;
  final JwtValidator _validator;
  final TokenRefreshService _refreshService;
  final RefreshTokenRotationTracker _rotationTracker;
  final SessionExpirationPolicy _expirationPolicy;
  final TokenRevocationService? _revocationService;

  RefreshTokenRotationTracker get rotationTracker => _rotationTracker;

  /// Validates stored tokens and optionally refreshes before session restore.
  Future<AuthSessionRestoreResult> restoreSession({
    required AuthTokens? tokens,
    required AuthClaims? claims,
    DeviceSessionMetadata? sessionMetadata,
    TokenRefreshCallback? refreshCallback,
    void Function(AuthTokens tokens)? onTokensRefreshed,
    void Function(AuthSessionEvent event)? onEvent,
  }) async {
    if (tokens == null) {
      return AuthSessionRestoreResult(
        claims: claims,
        tokens: null,
        isValid: claims != null && !(claims.isTokenExpired),
      );
    }

    final revocation = _revocationService;
    if (revocation != null) {
      await revocation.ensureLoaded();
      if (revocation.isSessionRevokedSync(tokens.sessionId)) {
        onEvent?.call(AuthSessionEvent.expired);
        return const AuthSessionRestoreResult(
          isValid: false,
          wasExpired: true,
          wasRevoked: true,
        );
      }
    }

    if (sessionMetadata != null &&
        _expirationPolicy.isSessionExpired(sessionMetadata)) {
      onEvent?.call(AuthSessionEvent.expired);
      return const AuthSessionRestoreResult(
        isValid: false,
        wasExpired: true,
        wasPolicyExpired: true,
      );
    }

    final validation = _decoder.isJwtFormat(tokens.accessToken)
        ? _validator.validate(tokens.accessToken)
        : const JwtValidationResult.valid();
    if (!validation.isValid && !tokens.isExpired) {
      onEvent?.call(AuthSessionEvent.expired);
      return AuthSessionRestoreResult(
        isValid: false,
        wasExpired: true,
        validationFailure: validation.failureReason,
      );
    }

    if (_rotationTracker.detectReuse(tokens)) {
      onEvent?.call(AuthSessionEvent.reuseDetected);
      return const AuthSessionRestoreResult(
        isValid: false,
        wasReuseDetected: true,
      );
    }

    if (tokens.isExpired && refreshCallback != null) {
      final outcome = await _refreshService.refreshIfNeeded(
        tokens: tokens,
        refreshCallback: refreshCallback,
        onRefreshed: (refreshed) {
          _recordRotation(tokens, refreshed);
          onTokensRefreshed?.call(refreshed);
        },
      );

      if (outcome.status == TokenRefreshStatus.refreshed &&
          outcome.tokens != null) {
        onEvent?.call(AuthSessionEvent.refreshed);
        return AuthSessionRestoreResult(
          claims: _syncClaimsExpiry(claims, outcome.tokens!),
          tokens: outcome.tokens,
          isValid: true,
          wasRefreshed: true,
        );
      }

      if (outcome.status == TokenRefreshStatus.expired) {
        onEvent?.call(AuthSessionEvent.expired);
        return const AuthSessionRestoreResult(isValid: false, wasExpired: true);
      }
    }

    if (tokens.isExpired || _decoder.isExpired(tokens.accessToken)) {
      onEvent?.call(AuthSessionEvent.expired);
      return const AuthSessionRestoreResult(isValid: false, wasExpired: true);
    }

    _rotationTracker.seed(tokens);
    onEvent?.call(AuthSessionEvent.restored);
    return AuthSessionRestoreResult(
      claims: _syncClaimsExpiry(claims, tokens),
      tokens: tokens,
      isValid: true,
    );
  }

  /// Records a token rotation after a successful refresh.
  RefreshRotationResult recordTokenRotation({
    required AuthTokens previous,
    required AuthTokens next,
  }) {
    return _recordRotation(previous, next);
  }

  RefreshRotationResult _recordRotation(AuthTokens previous, AuthTokens next) {
    final result = _rotationTracker.recordRotation(
      previous: previous,
      next: next,
    );
    return result;
  }

  /// Builds [AuthClaims] from a JWT access token when claims are absent.
  AuthClaims? claimsFromAccessToken(String accessToken) {
    final jwt = _decoder.decode(accessToken);
    if (jwt == null || jwt.subject == null || jwt.tenantId == null) {
      return null;
    }

    return AuthClaims(
      userId: jwt.subject!,
      // JOURNEY-002: was `?? ErpRole.superAdmin`. Rebuilding claims from a raw
      // access token is the third resolution path and must agree with the other
      // two — one resolver, failing closed.
      erpRole: ErpRole.resolve(jwt.role),
      tenantId: jwt.tenantId!,
      schoolId: jwt.schoolId,
      organizationId: jwt.organizationId,
      accessTokenExpiresAt: jwt.expiresAt,
      isChainOrganization: jwt.isChainOrganization,
    );
  }

  /// Returns updated metadata after user activity.
  DeviceSessionMetadata touchSession(DeviceSessionMetadata? metadata) {
    final policy = _expirationPolicy;
    if (metadata == null) {
      return policy.startSession();
    }
    return metadata.touch();
  }

  AuthClaims? _syncClaimsExpiry(AuthClaims? claims, AuthTokens tokens) {
    if (claims == null) return null;
    return claims.copyWith(accessTokenExpiresAt: tokens.expiresAt);
  }

  void scheduleTokenRefresh({
    required AuthTokens tokens,
    required Future<void> Function() onRefreshDue,
  }) {
    _refreshService.scheduleRefresh(
      tokens: tokens,
      onRefreshDue: onRefreshDue,
    );
  }

  void clearScheduledRefresh() => _refreshService.cancelScheduledRefresh();

  void resetSecurityState() {
    _rotationTracker.reset();
    clearScheduledRefresh();
  }

  void dispose() => _refreshService.dispose();
}

/// Outcome of a cold-start session restore.
class AuthSessionRestoreResult {
  const AuthSessionRestoreResult({
    this.claims,
    this.tokens,
    this.isValid = false,
    this.wasRefreshed = false,
    this.wasExpired = false,
    this.wasRevoked = false,
    this.wasPolicyExpired = false,
    this.wasReuseDetected = false,
    this.validationFailure,
  });

  final AuthClaims? claims;
  final AuthTokens? tokens;
  final bool isValid;
  final bool wasRefreshed;
  final bool wasExpired;
  final bool wasRevoked;
  final bool wasPolicyExpired;
  final bool wasReuseDetected;
  final String? validationFailure;
}
