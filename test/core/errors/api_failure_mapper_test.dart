import 'package:akshara_erp/core/errors/api_failure.dart';
import 'package:akshara_erp/core/errors/api_failure_mapper.dart';
import 'package:akshara_erp/core/repositories/api/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = ApiFailureMapper();

  group('ApiFailureMapper', () {
    test('maps ApiNotConnectedException to notConnected', () {
      final failure = mapper.fromException(
        ApiNotConnectedException('ApiFinanceRepository', 'getDashboard'),
      );
      expect(failure.type, ApiFailureType.notConnected);
      expect(failure.code, 'API_NOT_CONNECTED');
      expect(failure.isRetryable, isTrue);
    });

    test('maps 401 to unauthorized', () {
      final failure = mapper.fromException(
        DioException(
          requestOptions: RequestOptions(path: '/finance'),
          response: Response(
            requestOptions: RequestOptions(path: '/finance'),
            statusCode: 401,
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(failure.type, ApiFailureType.unauthorized);
      expect(failure.code, 'UNAUTHORIZED');
    });

    test('maps 403 to forbidden', () {
      final failure = mapper.fromException(
        DioException(
          requestOptions: RequestOptions(path: '/admin'),
          response: Response(
            requestOptions: RequestOptions(path: '/admin'),
            statusCode: 403,
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(failure.type, ApiFailureType.forbidden);
    });

    test('maps timeout to timeout failure', () {
      final failure = mapper.fromException(
        DioException(
          requestOptions: RequestOptions(path: '/sis'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      expect(failure.type, ApiFailureType.timeout);
      expect(failure.isRetryable, isTrue);
    });
  });
}
