import 'package:dio/dio.dart';

/// Resolves Dio requests with canned JSON without a network call.
class FakeDioInterceptor extends Interceptor {
  FakeDioInterceptor(this._responses);

  final Map<String, dynamic> Function(RequestOptions options) _responses;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final data = _responses(options);
    handler.resolve(
      Response(
        requestOptions: options,
        data: data,
        statusCode: 200,
      ),
    );
  }
}

Dio createFakeDio(Map<String, dynamic> Function(RequestOptions) responses) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.api/v1'));
  dio.interceptors.add(FakeDioInterceptor(responses));
  return dio;
}
