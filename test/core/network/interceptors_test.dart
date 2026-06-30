import 'dart:async';
import 'dart:math';

import 'package:akshara_erp/core/network/api_config.dart';
import 'package:akshara_erp/core/network/interceptors/auth_interceptor.dart';
import 'package:akshara_erp/core/network/interceptors/correlation_id_interceptor.dart';
import 'package:akshara_erp/core/network/interceptors/tenant_interceptor.dart';
import 'package:akshara_erp/core/tenant/tenant_context.dart';
import 'package:akshara_erp/features/auth/auth_token_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CorrelationIdInterceptor', () {
    test('adds correlation header', () {
      final interceptor = CorrelationIdInterceptor(random: Random(42));
      final options = RequestOptions(path: '/test');
      interceptor.onRequest(options, _CapturingHandler((o) {
        final id = o.headers[ApiConfig.correlationIdHeader] as String?;
        expect(id, isNotNull);
        expect(id!.startsWith('ak-'), isTrue);
      }));
    });
  });

  group('TenantInterceptor', () {
    test('adds tenant, school, organization, and user headers', () {
      final interceptor = TenantInterceptor(
        tenantAccessor: () => TenantContext.demo,
      );
      final options = RequestOptions(path: '/test');
      interceptor.onRequest(options, _CapturingHandler((o) {
        expect(o.headers[ApiConfig.tenantIdHeader], TenantContext.demo.tenantId);
        expect(o.headers[ApiConfig.schoolIdHeader], TenantContext.demo.schoolId);
        expect(
          o.headers[ApiConfig.organizationIdHeader],
          TenantContext.demo.organizationId,
        );
        expect(o.headers[ApiConfig.userIdHeader], TenantContext.demo.userId);
      }));
    });

    test('rejects when tenant is required but missing', () {
      final interceptor = TenantInterceptor(
        tenantAccessor: () => null,
        requireTenant: true,
      );
      final options = RequestOptions(path: '/test');
      var rejected = false;
      interceptor.onRequest(
        options,
        _RejectingHandler(() => rejected = true),
      );
      expect(rejected, isTrue);
    });
  });

  group('AuthInterceptor', () {
    test('attaches bearer token when available', () async {
      final tokens = AuthTokens.demo();
      final interceptor = AuthInterceptor(
        tokenAccessor: () => tokens,
        allowAnonymous: false,
      );
      final options = RequestOptions(path: '/secure');
      final handler = _AsyncCapturingHandler();
      interceptor.onRequest(options, handler);
      await Future<void>.delayed(Duration.zero);
      expect(
        handler.captured?.headers['Authorization'],
        'Bearer ${tokens.accessToken}',
      );
    });

    test('allows anonymous requests when configured', () async {
      final interceptor = AuthInterceptor(
        tokenAccessor: () => null,
        allowAnonymous: true,
      );
      final options = RequestOptions(path: '/public');
      final handler = _AsyncCapturingHandler();
      interceptor.onRequest(options, handler);
      await Future<void>.delayed(Duration.zero);
      expect(handler.captured?.headers.containsKey('Authorization'), isFalse);
    });
  });

  // QW4 · QA-X-007 — 401 onError: refresh the token then *safely* replay the
  // original request. Idempotent reads (and writes carrying an idempotency key)
  // are transparently replayed; a bare non-idempotent write is NOT auto-replayed
  // (replaying it verbatim could create a duplicate side effect). A failed
  // refresh surfaces the 401 and signals session expiry.
  group('AuthInterceptor · 401 refresh + replay (QA-X-007)', () {
    test('isSafeToAutoReplay: idempotent verbs are always replayable', () {
      for (final method in ['GET', 'get', 'HEAD', 'OPTIONS']) {
        expect(
          AuthInterceptor.isSafeToAutoReplay(
            RequestOptions(path: '/r', method: method),
          ),
          isTrue,
          reason: '$method should be auto-replayable',
        );
      }
    });

    test('isSafeToAutoReplay: bare write is NOT replayable', () {
      for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
        expect(
          AuthInterceptor.isSafeToAutoReplay(
            RequestOptions(path: '/w', method: method),
          ),
          isFalse,
          reason: '$method without an idempotency key must not auto-replay',
        );
      }
    });

    test('isSafeToAutoReplay: write WITH idempotency key is replayable', () {
      final options = RequestOptions(
        path: '/w',
        method: 'POST',
        headers: {'Idempotency-Key': 'abc-123'},
      );
      expect(AuthInterceptor.isSafeToAutoReplay(options), isTrue);
    });

    test('401 on a GET refreshes the token and replays the original request',
        () async {
      // Two distinct token sets so we can prove the *refreshed* token is used.
      final stale = AuthTokens.demo();
      final fresh = AuthTokens(
        accessToken: 'fresh_access',
        refreshToken: 'fresh_refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      var refreshCalls = 0;
      AuthTokens? refreshedNotified;

      final interceptor = AuthInterceptor(
        tokenAccessor: () => stale,
        refreshCallback: (rt) async {
          refreshCalls++;
          expect(rt, stale.refreshToken);
          return fresh;
        },
        onTokensRefreshed: (t) => refreshedNotified = t,
      );

      final options = RequestOptions(path: '/secure-read', method: 'GET');
      final err = DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 401),
      );
      final handler = _RecordingErrorHandler();
      interceptor.onError(err, handler);

      // The replay issues a real fetch against an unreachable host, which fails
      // with a transport error — the point under test is that the refresh fired
      // and the request was re-issued, not the network outcome.
      await handler.completed;

      expect(refreshCalls, 1, reason: 'token must be refreshed exactly once');
      expect(refreshedNotified, fresh,
          reason: 'onTokensRefreshed must receive the new tokens');
      expect(handler.resolved, isFalse);
      // The original 401 is NOT what surfaces — it was replaced by the replay's
      // own (network) error, proving the request was actually re-issued.
      expect(handler.nextError?.response?.statusCode, isNot(401));
    });

    test('a bare POST 401 refreshes but does NOT auto-replay; surfaces the 401',
        () async {
      final stale = AuthTokens.demo();
      final fresh = AuthTokens(
        accessToken: 'fresh_access',
        refreshToken: 'fresh_refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      var refreshCalls = 0;

      final interceptor = AuthInterceptor(
        tokenAccessor: () => stale,
        refreshCallback: (rt) async {
          refreshCalls++;
          return fresh;
        },
      );

      final options = RequestOptions(path: '/secure-write', method: 'POST');
      final err = DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 401),
      );
      final handler = _RecordingErrorHandler();
      interceptor.onError(err, handler);
      await handler.completed;

      expect(refreshCalls, 1, reason: 'session is still refreshed');
      // The unsafe write is not replayed: the original 401 is surfaced verbatim
      // so the caller (or the user) can decide to resubmit.
      expect(handler.resolved, isFalse);
      expect(handler.nextError?.response?.statusCode, 401);
    });

    test('a failed refresh surfaces the original 401 and signals expiry',
        () async {
      final stale = AuthTokens.demo();
      var sessionExpired = false;

      final interceptor = AuthInterceptor(
        tokenAccessor: () => stale,
        refreshCallback: (rt) async => null, // refresh fails
        onSessionExpired: () => sessionExpired = true,
      );

      final options = RequestOptions(path: '/secure-read', method: 'GET');
      final err = DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 401),
      );
      final handler = _RecordingErrorHandler();
      interceptor.onError(err, handler);
      await handler.completed;

      expect(sessionExpired, isTrue,
          reason: 'a failed refresh must signal session expiry');
      expect(handler.resolved, isFalse);
      expect(handler.nextError?.response?.statusCode, 401,
          reason: 'the original 401 must surface when refresh fails');
    });

    test('non-401 errors pass through untouched (no refresh attempt)', () async {
      var refreshCalls = 0;
      final interceptor = AuthInterceptor(
        tokenAccessor: AuthTokens.demo,
        refreshCallback: (rt) async {
          refreshCalls++;
          return null;
        },
      );

      final options = RequestOptions(path: '/secure', method: 'GET');
      final err = DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 500),
      );
      final handler = _RecordingErrorHandler();
      interceptor.onError(err, handler);
      await handler.completed;

      expect(refreshCalls, 0, reason: 'only a 401 triggers a refresh');
      expect(handler.nextError?.response?.statusCode, 500);
    });
  });
}

class _CapturingHandler extends RequestInterceptorHandler {
  _CapturingHandler(this.onCapture);

  final void Function(RequestOptions options) onCapture;

  @override
  void next(RequestOptions options) {
    onCapture(options);
  }
}

class _AsyncCapturingHandler extends RequestInterceptorHandler {
  RequestOptions? captured;

  @override
  void next(RequestOptions options) {
    captured = options;
  }
}

class _RejectingHandler extends RequestInterceptorHandler {
  _RejectingHandler(this.onReject);

  final void Function() onReject;

  @override
  void reject(DioException err, [bool callFollowingErrorInterceptor = true]) {
    onReject();
  }
}

/// Captures the outcome of an [AuthInterceptor.onError] call so async refresh +
/// replay paths can be awaited and asserted.
class _RecordingErrorHandler extends ErrorInterceptorHandler {
  final Completer<void> _done = Completer<void>();
  bool resolved = false;
  DioException? nextError;

  /// Completes once the interceptor calls [next] or [resolve].
  Future<void> get completed => _done.future;

  void _finish() {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  void next(DioException err) {
    nextError = err;
    _finish();
  }

  @override
  void resolve(Response<dynamic> response, [bool callFollowingResponseInterceptor = false]) {
    resolved = true;
    _finish();
  }

  @override
  void reject(DioException error, [bool callFollowingErrorInterceptor = false]) {
    nextError = error;
    _finish();
  }
}
