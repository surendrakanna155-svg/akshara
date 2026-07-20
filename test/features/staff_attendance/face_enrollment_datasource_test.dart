// Slice 3 — FaceEnrollmentDataSource: success envelopes (mocked Dio, mirroring
// test/contracts/audit/audit_remote_datasource_test.dart's FakeDioInterceptor
// pattern) and the 422/404 rejection mapping (mirroring
// test/core/errors/api_failure_mapper_test.dart's DioException construction).

import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/staff_attendance/face_enrollment_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

/// Resolves every request with a DioException carrying [statusCode]/[body] —
/// simulates a server-side rejection without a real network call.
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

Dio _rejectingDio({required int statusCode, required Map<String, dynamic> body}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.api/v1'));
  dio.interceptors.add(_RejectingInterceptor(statusCode: statusCode, body: body));
  return dio;
}

void main() {
  group('FaceEnrollmentDataSource.enroll', () {
    test('posts the scoped embedding+modelTag and parses the success envelope',
        () async {
      Map<String, dynamic>? capturedBody;
      Map<String, dynamic>? capturedQuery;

      final dio = createFakeDio((options) {
        capturedBody = options.data as Map<String, dynamic>?;
        capturedQuery = options.queryParameters;
        return {
          'data': {
            'id': 'enr_1',
            'embeddingDim': 192,
            'modelTag': 'mobilefacenet-v1',
            'enrolledAt': '2026-07-11T10:00:00.000Z',
          },
        };
      });

      final ds = FaceEnrollmentDataSource(dio: dio, query: RepositoryQuery.demo);
      final result = await ds.enroll(
        embedding: List.filled(192, 0.01),
        modelTag: 'mobilefacenet-v1',
      );

      expect(result.id, 'enr_1');
      expect(result.modelTag, 'mobilefacenet-v1');
      expect(result.enrolledAt, DateTime.parse('2026-07-11T10:00:00.000Z'));
      expect(capturedBody?['modelTag'], 'mobilefacenet-v1');
      expect((capturedBody?['embedding'] as List).length, 192);
      expect(capturedQuery?['tenantId'], RepositoryQuery.demo.tenantId);
      expect(capturedQuery?['schoolId'], RepositoryQuery.demo.schoolId);
    });

    test('maps a 422 STAFF_ATTENDANCE_EMBEDDING_* error to FaceEnrollmentRejected',
        () async {
      final dio = _rejectingDio(
        statusCode: 422,
        body: {
          'error': {
            'code': 'STAFF_ATTENDANCE_EMBEDDING_DIMS_INVALID',
            'message': 'embedding must have between 64 and 1024 dimensions',
          },
        },
      );
      final ds = FaceEnrollmentDataSource(dio: dio, query: RepositoryQuery.demo);

      await expectLater(
        () => ds.enroll(embedding: const [0.1, 0.2]),
        throwsA(
          isA<FaceEnrollmentRejected>().having(
            (e) => e.code,
            'code',
            'STAFF_ATTENDANCE_EMBEDDING_DIMS_INVALID',
          ),
        ),
      );
    });

    test('rethrows an unmapped (non-422) DioException as-is', () async {
      final dio = _rejectingDio(statusCode: 500, body: const {});
      final ds = FaceEnrollmentDataSource(dio: dio, query: RepositoryQuery.demo);

      await expectLater(
        () => ds.enroll(embedding: const [0.1, 0.2]),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('faceEnrollmentFriendlyMessage', () {
    test('maps STAFF_ATTENDANCE_EMBEDDING_REQUIRED to friendly copy', () {
      const rejected = FaceEnrollmentRejected(
        'STAFF_ATTENDANCE_EMBEDDING_REQUIRED',
        'raw server message',
      );
      expect(
        faceEnrollmentFriendlyMessage(rejected),
        contains('face clearly'),
      );
    });

    test('maps STAFF_ATTENDANCE_EMBEDDING_DIMS_INVALID to friendly copy', () {
      const rejected = FaceEnrollmentRejected(
        'STAFF_ATTENDANCE_EMBEDDING_DIMS_INVALID',
        'raw',
      );
      expect(faceEnrollmentFriendlyMessage(rejected), contains('compatible'));
    });

    test('falls back to the server message for an unmapped code', () {
      const rejected = FaceEnrollmentRejected('SOME_OTHER_CODE', 'server said so');
      expect(faceEnrollmentFriendlyMessage(rejected), 'server said so');
    });
  });

  group('FaceEnrollmentDataSource.status', () {
    test('parses an enrolled status envelope', () async {
      final dio = createFakeDio((_) => {
            'data': {
              'enrolled': true,
              'modelTag': 'mobilefacenet-v1',
              'enrolledAt': '2026-07-11T10:00:00.000Z',
            },
          });
      final ds = FaceEnrollmentDataSource(dio: dio, query: RepositoryQuery.demo);

      final status = await ds.status();

      expect(status.enrolled, isTrue);
      expect(status.modelTag, 'mobilefacenet-v1');
      expect(status.enrolledAt, isNotNull);
    });

    test('parses a not-enrolled status envelope', () async {
      final dio = createFakeDio(
        (_) => {
          'data': {'enrolled': false, 'modelTag': null, 'enrolledAt': null},
        },
      );
      final ds = FaceEnrollmentDataSource(dio: dio, query: RepositoryQuery.demo);

      final status = await ds.status();

      expect(status.enrolled, isFalse);
      expect(status.modelTag, isNull);
      expect(status.enrolledAt, isNull);
    });
  });

  group('FaceEnrollmentDataSource.revoke', () {
    test('returns true when the server confirms a revoke', () async {
      final dio = createFakeDio((_) => {
            'data': {'revoked': true},
          });
      final ds = FaceEnrollmentDataSource(dio: dio, query: RepositoryQuery.demo);

      expect(await ds.revoke(), isTrue);
    });

    test('returns false (not a thrown error) on a 404 — nothing to revoke',
        () async {
      final dio = _rejectingDio(
        statusCode: 404,
        body: {
          'error': {
            'code': 'ATTENDANCE_AUTH_NOT_ENROLLED',
            'message': 'No active face enrollment to revoke',
          },
        },
      );
      final ds = FaceEnrollmentDataSource(dio: dio, query: RepositoryQuery.demo);

      expect(await ds.revoke(), isFalse);
    });
  });
}
