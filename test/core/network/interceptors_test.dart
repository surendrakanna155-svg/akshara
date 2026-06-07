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
