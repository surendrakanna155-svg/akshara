// PRC-A client — GatePassDataSource: request/response parsing, tenant scope,
// the GATE_PASS_* -> typed GatePassRejected mapping, and the deliberately
// generic verify-failure -> GatePassVerificationRejected mapping (never the
// server's raw reason).

import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/gate_pass/gate_pass_datasource.dart';
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

GatePassDataSource _ds(Dio dio) => GatePassDataSource(dio: dio, query: RepositoryQuery.demo);

Map<String, dynamic> _row({String status = 'pending', bool hasCredential = false}) => {
      'id': 'gp-1',
      'studentId': 'stu-1',
      'passType': 'early_pickup',
      'reason': 'dentist appointment',
      'requestedBy': 'user-1',
      'pickupPersonName': 'Asha Rao',
      'pickupPersonRelation': 'Mother',
      'pickupPersonPhone': '9999999999',
      'scheduledAt': '2026-07-15T10:00:00Z',
      'status': status,
      'rawStatus': status,
      'approvalRequestId': 'appr-1',
      'hasCredential': hasCredential,
      'credentialExpiresAt': null,
      'verifiedBy': null,
      'verifiedAt': null,
      'verificationNote': null,
      'createdAt': '2026-07-14T00:00:00Z',
      'updatedAt': '2026-07-14T00:00:00Z',
    };

void main() {
  group('raise', () {
    test('posts all fields and parses the response', () async {
      Map<String, dynamic>? body;
      Map<String, dynamic>? query;
      final dio = createFakeDio((options) {
        body = options.data as Map<String, dynamic>?;
        query = options.queryParameters;
        return {'data': _row()};
      });

      final result = await _ds(dio).raise(
        studentId: 'stu-1',
        passType: 'early_pickup',
        reason: 'dentist appointment',
        pickupPersonName: 'Asha Rao',
        pickupPersonRelation: 'Mother',
        pickupPersonPhone: '9999999999',
        scheduledAt: DateTime.utc(2026, 7, 15, 10),
      );

      expect(result.id, 'gp-1');
      expect(result.passType, 'early_pickup');
      expect(result.pickupPersonName, 'Asha Rao');
      expect(body?['studentId'], 'stu-1');
      expect(body?['passType'], 'early_pickup');
      expect(body?['pickupPersonPhone'], '9999999999');
      expect(body?['scheduledAt'], '2026-07-15T10:00:00.000Z');
      expect(query?['tenantId'], isNotNull);
    });

    test('422 VALIDATION_ERROR (no GATE_PASS_ prefix) rethrows the raw DioException', () async {
      final dio = _rejectingDio(422, {
        'error': {'code': 'VALIDATION_ERROR', 'message': 'scheduledAt must be a valid timestamp'},
      });
      await expectLater(
        () => _ds(dio).raise(
          studentId: 'stu-1',
          passType: 'early_pickup',
          reason: '',
          pickupPersonName: 'x',
          pickupPersonRelation: 'y',
          pickupPersonPhone: 'z',
          scheduledAt: DateTime.now(),
        ),
        throwsA(isA<DioException>()),
      );
    });

    test('403 GATE_PASS_NOT_YOUR_CHILD -> typed GatePassRejected', () async {
      final dio = _rejectingDio(403, {
        'error': {
          'code': 'GATE_PASS_NOT_YOUR_CHILD',
          'message': 'You may only raise a gate pass for your own child',
        },
      });
      await expectLater(
        () => _ds(dio).raise(
          studentId: 'stu-1',
          passType: 'early_pickup',
          reason: '',
          pickupPersonName: 'x',
          pickupPersonRelation: 'y',
          pickupPersonPhone: 'z',
          scheduledAt: DateTime.now(),
        ),
        throwsA(isA<GatePassRejected>().having((e) => e.code, 'code', 'GATE_PASS_NOT_YOUR_CHILD')),
      );
    });
  });

  group('list', () {
    test('sends the status filter and parses items, including hasCredential', () async {
      Map<String, dynamic>? query;
      final dio = createFakeDio((options) {
        query = options.queryParameters;
        return {
          'data': {
            'items': [_row(status: 'approved', hasCredential: true)],
            'count': 1,
          },
        };
      });

      final items = await _ds(dio).list(status: 'approved');
      expect(items, hasLength(1));
      expect(items.first.isVerifiable, isTrue);
      expect(items.first.hasCredential, isTrue);
      expect(query?['status'], 'approved');
    });
  });

  group('effective status (lazy expiry)', () {
    test('an approved-but-expired pass reports status expired, distinct from rawStatus', () async {
      final dio = createFakeDio((_) => {
            'data': {
              ..._row(status: 'expired'),
              'rawStatus': 'approved',
            },
          });
      final result = await _ds(dio).byId('gp-1');
      expect(result.status, 'expired');
      expect(result.rawStatus, 'approved');
      expect(result.isVerifiable, isFalse);
    });
  });

  group('verify', () {
    test('posts the otp and parses the verified pass (never sends/receives a credential)', () async {
      Map<String, dynamic>? body;
      final dio = createFakeDio((options) {
        body = options.data as Map<String, dynamic>?;
        return {'data': _row(status: 'used')};
      });
      final result = await _ds(dio).verify('gp-1', otp: '123456');
      expect(result.status, 'used');
      expect(body?['otp'], '123456');
    });

    test('GATE_PASS_VERIFICATION_FAILED -> the dedicated generic rejection, never server prose', () async {
      final dio = _rejectingDio(422, {
        'error': {
          'code': 'GATE_PASS_VERIFICATION_FAILED',
          'message': 'some server-side detail that must never reach the UI verbatim',
        },
      });
      await expectLater(
        () => _ds(dio).verify('gp-1', otp: '000000'),
        throwsA(isA<GatePassVerificationRejected>()),
      );
    });

    test('a non-verification GATE_PASS_ code still maps to the general GatePassRejected', () async {
      final dio = _rejectingDio(404, {
        'error': {'code': 'GATE_PASS_NOT_FOUND', 'message': 'Gate pass not found'},
      });
      await expectLater(
        () => _ds(dio).verify('missing', otp: '000000'),
        throwsA(isA<GatePassRejected>()),
      );
    });
  });

  group('cancel', () {
    test('posts and parses the cancelled pass', () async {
      final dio = createFakeDio((_) => {'data': _row(status: 'cancelled')});
      final result = await _ds(dio).cancel('gp-1');
      expect(result.status, 'cancelled');
    });

    test('409 GATE_PASS_CANCEL_FAILED -> typed rejection', () async {
      final dio = _rejectingDio(409, {
        'error': {
          'code': 'GATE_PASS_CANCEL_FAILED',
          'message': 'Gate pass not found, already decided/used, or you may not cancel it',
        },
      });
      await expectLater(
        () => _ds(dio).cancel('gp-1'),
        throwsA(isA<GatePassRejected>()),
      );
    });
  });
}
