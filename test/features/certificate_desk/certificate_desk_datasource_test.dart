// PRC-A client — CertificateDeskDataSource: request/response parsing, tenant
// scope, and the 422/403/409/404 -> typed CertificateRequestRejected mapping.

import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/certificate_desk/certificate_desk_datasource.dart';
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

CertificateDeskDataSource _ds(Dio dio) =>
    CertificateDeskDataSource(dio: dio, query: RepositoryQuery.demo);

Map<String, dynamic> _row({String status = 'pending', String issueNote = ''}) => {
      'id': 'cr-1',
      'studentId': 'stu-1',
      'certificateType': 'bonafide',
      'purpose': 'scholarship',
      'status': status,
      'requestedBy': 'user-1',
      'requestedByRole': 'staff',
      'approvalRequestId': 'appr-1',
      'issuedCertificateId': null,
      'issueNote': issueNote,
      'decidedAt': null,
      'createdAt': '2026-07-01T00:00:00Z',
      'updatedAt': '2026-07-01T00:00:00Z',
    };

void main() {
  group('raise', () {
    test('posts studentId/certificateType/purpose and parses the response', () async {
      Map<String, dynamic>? body;
      Map<String, dynamic>? query;
      final dio = createFakeDio((options) {
        body = options.data as Map<String, dynamic>?;
        query = options.queryParameters;
        return {'data': _row()};
      });

      final result = await _ds(dio).raise(
        studentId: 'stu-1',
        certificateType: 'bonafide',
        purpose: 'scholarship',
      );

      expect(result.id, 'cr-1');
      expect(result.certificateType, 'bonafide');
      expect(result.status, 'pending');
      expect(body?['studentId'], 'stu-1');
      expect(body?['certificateType'], 'bonafide');
      expect(body?['purpose'], 'scholarship');
      expect(query?['tenantId'], isNotNull);
    });

    test('omits purpose when blank', () async {
      Map<String, dynamic>? body;
      final dio = createFakeDio((options) {
        body = options.data as Map<String, dynamic>?;
        return {'data': _row()};
      });
      await _ds(dio).raise(studentId: 'stu-1', certificateType: 'bonafide', purpose: '   ');
      expect(body?.containsKey('purpose'), isFalse);
    });

    test('422 VALIDATION_ERROR -> typed CertificateRequestRejected', () async {
      final dio = _rejectingDio(422, {
        'error': {'code': 'VALIDATION_ERROR', 'message': 'certificateType is required'},
      });
      await expectLater(
        () => _ds(dio).raise(studentId: 'stu-1', certificateType: 'bonafide'),
        throwsA(isA<CertificateRequestRejected>()
            .having((e) => e.code, 'code', 'VALIDATION_ERROR')
            .having((e) => e.message, 'message', 'certificateType is required')),
      );
    });

    test('404 NOT_FOUND (student not found) -> typed rejection', () async {
      final dio = _rejectingDio(404, {
        'error': {'code': 'NOT_FOUND', 'message': 'Student not found'},
      });
      await expectLater(
        () => _ds(dio).raise(studentId: 'nope', certificateType: 'bonafide'),
        throwsA(isA<CertificateRequestRejected>()
            .having((e) => e.code, 'code', 'NOT_FOUND')),
      );
    });

    test('409 CONFLICT (duplicate open request) -> typed rejection', () async {
      final dio = _rejectingDio(409, {
        'error': {'code': 'CONFLICT', 'message': 'An open bonafide request already exists'},
      });
      await expectLater(
        () => _ds(dio).raise(studentId: 'stu-1', certificateType: 'bonafide'),
        throwsA(isA<CertificateRequestRejected>()),
      );
    });

    test('a 500 with no error code is rethrown as a raw DioException', () async {
      final dio = _rejectingDio(500, {'error': 'boom'});
      await expectLater(
        () => _ds(dio).raise(studentId: 'stu-1', certificateType: 'bonafide'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('list', () {
    test('sends the status filter and parses items', () async {
      Map<String, dynamic>? query;
      final dio = createFakeDio((options) {
        query = options.queryParameters;
        return {
          'data': {
            'items': [_row(), _row(status: 'issued')],
            'count': 2,
          },
        };
      });

      final items = await _ds(dio).list(status: 'pending');
      expect(items, hasLength(2));
      expect(items.first.isPending, isTrue);
      expect(query?['status'], 'pending');
    });

    test('omits the status param when null', () async {
      Map<String, dynamic>? query;
      final dio = createFakeDio((options) {
        query = options.queryParameters;
        return {
          'data': {'items': <dynamic>[], 'count': 0},
        };
      });
      await _ds(dio).list();
      expect(query?.containsKey('status'), isFalse);
    });
  });

  group('byId', () {
    test('parses a single request', () async {
      final dio = createFakeDio((_) => {'data': _row()});
      final result = await _ds(dio).byId('cr-1');
      expect(result.id, 'cr-1');
    });
  });

  group('blocked_dues', () {
    test('carries the honest issueNote — not issued, not a generic failure', () async {
      final dio = createFakeDio(
        (_) => {
          'data': _row(status: 'blocked_dues', issueNote: '₹500 outstanding dues'),
        },
      );
      final result = await _ds(dio).byId('cr-1');
      expect(result.status, 'blocked_dues');
      expect(result.isBlockedDues, isTrue);
      expect(result.isIssued, isFalse);
      expect(result.issueNote, '₹500 outstanding dues');
    });
  });

  group('cancel', () {
    test('posts and parses the cancelled request', () async {
      final dio = createFakeDio((_) => {'data': _row(status: 'cancelled')});
      final result = await _ds(dio).cancel('cr-1');
      expect(result.status, 'cancelled');
    });

    test('403 FORBIDDEN (not the requester, no approve perm) -> typed rejection', () async {
      final dio = _rejectingDio(403, {
        'error': {'code': 'FORBIDDEN', 'message': 'Cannot cancel this request'},
      });
      await expectLater(
        () => _ds(dio).cancel('cr-1'),
        throwsA(isA<CertificateRequestRejected>()
            .having((e) => e.code, 'code', 'FORBIDDEN')),
      );
    });
  });
}
