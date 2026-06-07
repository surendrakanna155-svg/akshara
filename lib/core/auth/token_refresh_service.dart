import 'dart:async';

import '../../features/auth/auth_token_models.dart';
import 'jwt_decoder.dart';

/// Result of a refresh attempt.
enum TokenRefreshStatus {
  notNeeded,
  refreshed,
  failed,
  expired,
}

/// Schedules and executes access-token refresh before expiry.
class TokenRefreshService {
  TokenRefreshService({
    JwtDecoder decoder = jwtDecoder,
  }) : _decoder = decoder;

  final JwtDecoder _decoder;
  Timer? _scheduledTimer;

  /// Returns true when the access token should be refreshed proactively.
  bool shouldRefresh(AuthTokens tokens) {
    if (tokens.isExpired) return true;
    if (tokens.isExpiringSoon) return true;
    return _decoder.decode(tokens.accessToken)?.isExpiringSoon ?? false;
  }

  /// Attempts refresh via [refreshCallback]. Returns null when refresh fails.
  Future<AuthTokenRefreshResult?> refresh({
    required AuthTokens tokens,
    required TokenRefreshCallback refreshCallback,
  }) async {
    if (tokens.refreshToken.isEmpty) {
      return null;
    }

    final refreshed = await refreshCallback(tokens.refreshToken);
    if (refreshed == null || refreshed.accessToken.isEmpty) {
      return null;
    }

    return AuthTokenRefreshResult(
      tokens: refreshed,
      refreshedAt: DateTime.now(),
    );
  }

  /// Executes refresh when needed; returns status and optional refreshed tokens.
  Future<TokenRefreshOutcome> refreshIfNeeded({
    required AuthTokens? tokens,
    required TokenRefreshCallback? refreshCallback,
    void Function(AuthTokens tokens)? onRefreshed,
  }) async {
    if (tokens == null || refreshCallback == null) {
      return const TokenRefreshOutcome(status: TokenRefreshStatus.notNeeded);
    }

    if (tokens.isExpired && tokens.refreshToken.isEmpty) {
      return const TokenRefreshOutcome(status: TokenRefreshStatus.expired);
    }

    if (!shouldRefresh(tokens)) {
      return TokenRefreshOutcome(
        status: TokenRefreshStatus.notNeeded,
        tokens: tokens,
      );
    }

    final result = await refresh(
      tokens: tokens,
      refreshCallback: refreshCallback,
    );

    if (result == null) {
      return TokenRefreshOutcome(
        status:
            tokens.isExpired ? TokenRefreshStatus.expired : TokenRefreshStatus.failed,
      );
    }

    onRefreshed?.call(result.tokens);
    return TokenRefreshOutcome(
      status: TokenRefreshStatus.refreshed,
      tokens: result.tokens,
    );
  }

  /// Schedules a one-shot refresh [leadTime] before token expiry.
  void scheduleRefresh({
    required AuthTokens tokens,
    required Future<void> Function() onRefreshDue,
    Duration leadTime = const Duration(minutes: 5),
  }) {
    cancelScheduledRefresh();

    final expiresAt = tokens.expiresAt;
    final refreshAt = expiresAt.subtract(leadTime);
    final delay = refreshAt.difference(DateTime.now());

    if (delay.isNegative) {
      unawaited(onRefreshDue());
      return;
    }

    _scheduledTimer = Timer(delay, () => unawaited(onRefreshDue()));
  }

  void cancelScheduledRefresh() {
    _scheduledTimer?.cancel();
    _scheduledTimer = null;
  }

  void dispose() => cancelScheduledRefresh();
}

/// Result of [TokenRefreshService.refreshIfNeeded].
class TokenRefreshOutcome {
  const TokenRefreshOutcome({
    required this.status,
    this.tokens,
  });

  final TokenRefreshStatus status;
  final AuthTokens? tokens;
}
