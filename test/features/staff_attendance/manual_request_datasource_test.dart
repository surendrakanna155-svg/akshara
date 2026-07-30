// Slice 4 — ManualAttendanceRequestDataSource: envelope parsing, tenant scope,
// and the 422 STAFF_ATTENDANCE_* rejection mapping (same FakeDio pattern as
// face_enrollment_datasource_test.dart).

import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/staff_attendance/manual_request_datasource.dart';
import 'package:akshara_erp/features/staff_attendance/staff_attendance_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

class _RejectingInterceptor extends Interceptor {
  _RejectingInterceptor({required this.statusCode, required this.body});
  final int statusCode;
  final Map<String, dynamic> body;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.reject(
      DioException(
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: statusCode,
          data: body,
        ),
        type: DioExceptionType.badResponse,
      ),
    );
  }
}

ManualAttendanceRequestDataSource _datasource(Dio dio) =>
    ManualAttendanceRequestDataSource(dio: dio, query: RepositoryQuery.demo);

void main() {
  group('create', () {
    test('posts eventType+reason with tenant scope and parses the envelope',
        () async {
      Map<String, dynamic>? capturedBody;
      Map<String, dynamic>? capturedQuery;
      String? capturedPath;
      final dio = createFakeDio((options) {
        capturedBody = options.data as Map<String, dynamic>?;
        capturedQuery = options.queryParameters;
        capturedPath = options.path;
        return {
          'data': {'id': 'att_req_1', 'status': 'pending', 'eventType': 'check_in'},
        };
      });

      final created = await _datasource(dio).create(
        event: StaffCheckEvent.checkIn,
        reason: 'camera not working',
      );

      expect(created.id, 'att_req_1');
      expect(created.isPending, isTrue);
      expect(capturedPath, '/staff-attendance/manual-request');
      expect(capturedBody?['eventType'], 'check_in');
      expect(capturedBody?['reason'], 'camera not working');
      expect(capturedQuery?['tenantId'], isNotNull,
          reason: 'tenant scope must ride every request');
    });

    test('422 STAFF_ATTENDANCE_REASON_REQUIRED maps to the typed rejection',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.api/v1'))
        ..interceptors.add(_RejectingInterceptor(
          statusCode: 422,
          body: {
            'error': {
              'code': 'STAFF_ATTENDANCE_REASON_REQUIRED',
              'message': 'A reason is required for a manual request',
            },
          },
        ));

      await expectLater(
        () => _datasource(dio).create(event: StaffCheckEvent.checkIn, reason: 'x'),
        throwsA(isA<StaffAttendanceRejected>()
            .having((e) => e.code, 'code', 'STAFF_ATTENDANCE_REASON_REQUIRED')),
      );
    });
  });

  group('myRequests', () {
    test('sends mine=true and parses the items list', () async {
      Map<String, dynamic>? capturedQuery;
      final dio = createFakeDio((options) {
        capturedQuery = options.queryParameters;
        return {
          'data': {
            'items': [
              {
                'id': 'r1',
                'eventType': 'check_in',
                'reason': 'gps off',
                'status': 'pending',
                'createdAt': '2026-07-12T09:00:00Z',
                'decidedAt': null,
              },
              {
                'id': 'r0',
                'eventType': 'check_out',
                'reason': 'old',
                'status': 'approved',
                'createdAt': '2026-07-10T17:00:00Z',
                'decidedAt': '2026-07-10T18:00:00Z',
              },
            ],
          },
        };
      });

      final mine = await _datasource(dio).myRequests();

      expect(capturedQuery?['mine'], 'true');
      expect(mine, hasLength(2));
      expect(mine.first.isPending, isTrue);
      expect(mine.last.status, 'approved');
    });
  });

  group('pendingQueue + decide', () {
    test('parses the approver queue and posts a decision', () async {
      Map<String, dynamic>? decideBody;
      String? lastPath;
      final dio = createFakeDio((options) {
        lastPath = options.path;
        if (options.path.endsWith('/decide')) {
          decideBody = options.data as Map<String, dynamic>?;
          return {
            'data': {'id': 'r1', 'status': 'approved', 'checkInId': 'chk_9'},
          };
        }
        return {
          'data': {
            'items': [
              {
                'id': 'r1',
                'userId': 'u7',
                'staffName': 'Asha',
                'eventType': 'check_in',
                'reason': 'camera broke',
                'createdAt': '2026-07-12T09:00:00Z',
              },
            ],
            'count': 1,
          },
        };
      });

      final ds = _datasource(dio);
      final queue = await ds.pendingQueue();
      expect(queue.single.staffName, 'Asha');
      expect(queue.single.reason, 'camera broke');

      await ds.decide(requestId: 'r1', approve: true);
      expect(lastPath, '/staff-attendance/manual-request/decide');
      expect(decideBody?['requestId'], 'r1');
      expect(decideBody?['approve'], true);
    });
  });
}
