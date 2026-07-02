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

    test('surfaces the server message + code for a 409 conflict', () {
      final failure = mapper.fromException(
        DioException(
          requestOptions: RequestOptions(path: '/hr/payroll/run'),
          response: Response(
            requestOptions: RequestOptions(path: '/hr/payroll/run'),
            statusCode: 409,
            data: {
              'data': null,
              'error': {
                'code': 'PAYROLL_RUN_ALREADY_PROCESSED',
                'message':
                    'Payroll run pay_1 is already processed; re-processing is not allowed',
              },
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(failure.statusCode, 409);
      expect(failure.code, 'PAYROLL_RUN_ALREADY_PROCESSED');
      expect(
        failure.message,
        'Payroll run pay_1 is already processed; re-processing is not allowed',
      );
    });

    test('surfaces the server message + code for a 422 validation error', () {
      final failure = mapper.fromException(
        DioException(
          requestOptions: RequestOptions(path: '/hr/payroll/run'),
          response: Response(
            requestOptions: RequestOptions(path: '/hr/payroll/run'),
            statusCode: 422,
            data: {
              'data': null,
              'error': {
                'code': 'PAYROLL_ENTRY_INVALID',
                'message': 'Payroll entry invalid for employee EMP-1',
              },
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(failure.statusCode, 422);
      expect(failure.code, 'PAYROLL_ENTRY_INVALID');
      expect(failure.message, 'Payroll entry invalid for employee EMP-1');
    });

    test('falls back to a generic message when the 4xx body has no envelope', () {
      final failure = mapper.fromException(
        DioException(
          requestOptions: RequestOptions(path: '/hr/leave/lv_1/approve'),
          response: Response(
            requestOptions: RequestOptions(path: '/hr/leave/lv_1/approve'),
            statusCode: 409,
            data: 'plain text',
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(failure.statusCode, 409);
      expect(failure.message, 'Something went wrong. Please try again.');
      expect(failure.code, 'HTTP_409');
    });
  });
}
