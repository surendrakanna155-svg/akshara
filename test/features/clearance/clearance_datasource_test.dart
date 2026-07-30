// SCE-1 slice 4 — ClearanceDataSource: report parsing + tenant scope, and the
// waiver 422/403/409 → typed ClearanceWaiverRejected mapping.

import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/clearance/clearance_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

class _RejectingInterceptor extends Interceptor {
  _RejectingInterceptor({required this.statusCode, required this.body});
  final int statusCode;
  final Map<String, dynamic> body;
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.reject(DioException(
      requestOptions: options,
      response: Response<dynamic>(requestOptions: options, statusCode: statusCode, data: body),
      type: DioExceptionType.badResponse,
    ));
  }
}

Dio _rejectingDio(int statusCode, Map<String, dynamic> body) =>
    Dio(BaseOptions(baseUrl: 'https://test.api/v1'))
      ..interceptors.add(_RejectingInterceptor(statusCode: statusCode, body: body));

ClearanceDataSource _ds(Dio dio) => ClearanceDataSource(dio: dio, query: RepositoryQuery.demo);

void main() {
  group('report', () {
    test('parses the consolidated report + sends lifecycle + tenant scope', () async {
      Map<String, dynamic>? capturedQuery;
      final dio = createFakeDio((options) {
        capturedQuery = options.queryParameters;
        return {
          'data': {
            'studentId': 'stu-1',
            'lifecycle': 'transfer_certificate',
            'blocked': true,
            'blockingAmount': 500,
            'totalOutstanding': 500,
            'contributions': [
              {'module': 'finance', 'status': 'pending', 'policy': 'blocking', 'amount': 500},
              {'module': 'library', 'status': 'not_tracked', 'policy': 'advisory', 'amount': 0},
            ],
            'notTracked': ['library', 'hostel'],
          },
        };
      });

      final report = await _ds(dio).report(studentId: 'stu-1');
      expect(report.blocked, isTrue);
      expect(report.blockingAmount, 500);
      expect(report.contributions, hasLength(2));
      expect(report.contributions.first.isPending, isTrue);
      expect(report.notTracked, ['library', 'hostel']);
      expect(capturedQuery?['lifecycle'], 'transfer_certificate');
      expect(capturedQuery?['tenantId'], isNotNull);
    });
  });

  group('raiseWaiver', () {
    test('posts the reason and parses the waiver', () async {
      Map<String, dynamic>? body;
      final dio = createFakeDio((options) {
        body = options.data as Map<String, dynamic>?;
        return {
          'data': {'id': 'w1', 'studentId': 'stu-1', 'lifecycle': 'transfer_certificate', 'reason': 'waive', 'amount': 500, 'status': 'pending', 'makerId': 'm1'},
        };
      });
      final w = await _ds(dio).raiseWaiver(studentId: 'stu-1', reason: 'waive');
      expect(w.status, 'pending');
      expect(body?['reason'], 'waive');
    });

    test('422 NO_DUES_TO_WAIVE → typed rejection', () async {
      final dio = _rejectingDio(422, {
        'error': {'code': 'CLEARANCE_WAIVER_NO_DUES_TO_WAIVE', 'message': 'no blocking dues'},
      });
      await expectLater(
        () => _ds(dio).raiseWaiver(studentId: 'stu-1', reason: 'x'),
        throwsA(isA<ClearanceWaiverRejected>()
            .having((e) => e.code, 'code', 'CLEARANCE_WAIVER_NO_DUES_TO_WAIVE')),
      );
    });
  });

  group('decideWaiver', () {
    test('403 SELF_APPROVE_DENIED → typed rejection (SoD surfaced)', () async {
      final dio = _rejectingDio(403, {
        'error': {'code': 'CLEARANCE_WAIVER_SELF_APPROVE_DENIED', 'message': 'you raised it'},
      });
      await expectLater(
        () => _ds(dio).decideWaiver(waiverId: 'w1', approve: true),
        throwsA(isA<ClearanceWaiverRejected>()
            .having((e) => e.code, 'code', 'CLEARANCE_WAIVER_SELF_APPROVE_DENIED')),
      );
    });

    test('409 ALREADY_DECIDED → typed rejection', () async {
      final dio = _rejectingDio(409, {
        'error': {'code': 'CLEARANCE_WAIVER_ALREADY_DECIDED', 'message': 'decided'},
      });
      await expectLater(
        () => _ds(dio).decideWaiver(waiverId: 'w1', approve: false),
        throwsA(isA<ClearanceWaiverRejected>()),
      );
    });

    test('a non-clearance error code is rethrown (not swallowed)', () async {
      final dio = _rejectingDio(403, {'error': {'code': 'FORBIDDEN', 'message': 'nope'}});
      await expectLater(
        () => _ds(dio).decideWaiver(waiverId: 'w1', approve: true),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('pendingWaivers', () {
    test('parses the queue items', () async {
      final dio = createFakeDio((_) => {
            'data': {
              'items': [
                {'id': 'w1', 'studentId': 's1', 'lifecycle': 'transfer_certificate', 'reason': 'r', 'amount': 100, 'status': 'pending', 'makerId': 'm1'},
              ],
              'count': 1,
            },
          });
      final q = await _ds(dio).pendingWaivers();
      expect(q, hasLength(1));
      expect(q.first.amount, 100);
    });
  });
}
