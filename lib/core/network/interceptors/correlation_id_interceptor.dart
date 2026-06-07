import 'dart:math';

import 'package:dio/dio.dart';

import '../../network/api_config.dart';

/// Injects a unique correlation ID on every outbound request for tracing.
class CorrelationIdInterceptor extends Interceptor {
  CorrelationIdInterceptor({Random? random}) : _random = random ?? Random();

  final Random _random;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final id = _generateId();
    options.headers[ApiConfig.correlationIdHeader] = id;
    options.extra['correlationId'] = id;
    handler.next(options);
  }

  String _generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final suffix = _random.nextInt(999999).toString().padLeft(6, '0');
    return 'ak-$ts-$suffix';
  }
}
