import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../features/auth/auth_token_models.dart';
import '../../auth/jwt_decoder.dart';
import '../../auth/jwt_validator.dart';
import '../../auth/token_revocation_service.dart';

/// Attaches JWT bearer tokens and supports refresh hooks.
///
/// When [allowAnonymous] is true, requests proceed without Authorization if no
/// token is available.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.tokenAccessor,
    this.refreshCallback,
    this.allowAnonymous = true,
    this.onTokensRefreshed,
    this.onSessionExpired,
    this.jwtValidator,
    this.revocationService,
    this.expectedTenantId,
  });

  final AuthTokens? Function() tokenAccessor;
  final TokenRefreshCallback? refreshCallback;
  final bool allowAnonymous;
  final void Function(AuthTokens tokens)? onTokensRefreshed;
  final void Function()? onSessionExpired;
  final JwtValidator? jwtValidator;
  final TokenRevocationService? revocationService;
  final String? expectedTenantId;

  bool _isRefreshing = false;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    var tokens = tokenAccessor();

    if (tokens != null) {
      final blocked = await _rejectIfInsecure(tokens, options, handler);
      if (blocked) return;
    }

    if (tokens != null && tokens.isExpired && refreshCallback != null) {
      tokens = await _refreshTokens(tokens.refreshToken);
      if (tokens != null) {
        final blocked = await _rejectIfInsecure(tokens, options, handler);
        if (blocked) return;
      }
    }

    if (tokens != null && tokens.accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    } else if (!allowAnonymous) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          message: 'Authentication required',
        ),
      );
      return;
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    if (status == 401 && refreshCallback != null) {
      final existing = tokenAccessor();
      if (existing != null && !_isRefreshing) {
        final refreshed = await _refreshTokens(existing.refreshToken);
        if (refreshed != null) {
          // RT-29: only auto-replay the failed request when it is safe to do so.
          // Idempotent verbs are always safe; a non-idempotent write is only
          // replayed when it carries an Idempotency-Key the server dedupes
          // (RT-07 backend support). A bare write is NOT retried — replaying it
          // verbatim could create a duplicate. The refreshed session lets the
          // user's own resubmit succeed.
          if (isSafeToAutoReplay(err.requestOptions)) {
            try {
              final response = await _retry(err.requestOptions, refreshed);
              handler.resolve(response);
              return;
            } on DioException catch (retryError) {
              handler.next(retryError);
              return;
            }
          }
          handler.next(err);
          return;
        }
      }
      onSessionExpired?.call();
    }
    handler.next(err);
  }

  /// Whether a request may be transparently re-sent after a 401 token refresh
  /// without risking a duplicate side effect (RT-29).
  @visibleForTesting
  static bool isSafeToAutoReplay(RequestOptions options) {
    const idempotentVerbs = {'GET', 'HEAD', 'OPTIONS'};
    if (idempotentVerbs.contains(options.method.toUpperCase())) return true;
    return options.headers.keys
        .any((k) => k.toLowerCase() == 'idempotency-key');
  }

  Future<bool> _rejectIfInsecure(
    AuthTokens tokens,
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (revocationService != null) {
      await revocationService!.ensureLoaded();
      if (revocationService!.isSessionRevokedSync(tokens.sessionId)) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            message: 'Session revoked',
          ),
        );
        return true;
      }
    }

    final validator = jwtValidator;
    if (validator != null &&
        tokens.accessToken.isNotEmpty &&
        jwtDecoder.isJwtFormat(tokens.accessToken)) {
      final result = validator.validate(
        tokens.accessToken,
        expectedTenantId: expectedTenantId,
      );
      if (!result.isValid) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            message: 'Invalid access token: ${result.failureReason}',
          ),
        );
        return true;
      }
    }

    return false;
  }

  Future<AuthTokens?> _refreshTokens(String refreshToken) async {
    if (_isRefreshing || refreshCallback == null) return null;
    _isRefreshing = true;
    try {
      final refreshed = await refreshCallback!(refreshToken);
      if (refreshed != null) {
        onTokensRefreshed?.call(refreshed);
      }
      return refreshed;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Response<dynamic>> _retry(
    RequestOptions options,
    AuthTokens tokens,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: options.baseUrl));
    final headers = Map<String, dynamic>.from(options.headers);
    headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    return dio.fetch<dynamic>(
      options.copyWith(headers: headers),
    );
  }
}
