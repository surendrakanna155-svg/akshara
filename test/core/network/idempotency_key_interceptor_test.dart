import 'package:akshara_erp/core/network/interceptors/idempotency_key_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures the RequestOptions the interceptor forwards.
class _CaptureHandler extends RequestInterceptorHandler {
  RequestOptions? forwarded;
  @override
  void next(RequestOptions requestOptions) {
    forwarded = requestOptions;
    super.next(requestOptions);
  }
}

String? _key(RequestOptions o) {
  for (final e in o.headers.entries) {
    if (e.key.toLowerCase() == 'idempotency-key') return e.value as String?;
  }
  return null;
}

void main() {
  final interceptor = IdempotencyKeyInterceptor();

  RequestOptions run(String method, {Map<String, dynamic>? headers}) {
    final handler = _CaptureHandler();
    interceptor.onRequest(
      RequestOptions(path: '/x', method: method, headers: headers ?? {}),
      handler,
    );
    return handler.forwarded!;
  }

  test('REL-1: mints an Idempotency-Key for mutating verbs', () {
    for (final m in ['POST', 'PUT', 'PATCH', 'DELETE', 'post', 'patch']) {
      final o = run(m);
      expect(_key(o), isNotNull, reason: '$m should carry a key');
      expect(_key(o), isNotEmpty);
    }
  });

  test('REL-1: does NOT add a key to safe verbs', () {
    for (final m in ['GET', 'HEAD', 'get']) {
      expect(_key(run(m)), isNull, reason: '$m must not carry a key');
    }
  });

  test('REL-1: preserves an existing key (ReliableWriter stable key)', () {
    final o = run('POST', headers: {'Idempotency-Key': 'stable-123'});
    expect(_key(o), 'stable-123');
  });

  test('REL-1: preserves an existing key regardless of header casing', () {
    final o = run('POST', headers: {'idempotency-key': 'lower-123'});
    expect(_key(o), 'lower-123');
  });

  test('REL-1: distinct requests get distinct keys', () {
    expect(_key(run('POST')), isNot(_key(run('POST'))));
  });
}
