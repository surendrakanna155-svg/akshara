// PRC-A Batch 2 — ComplaintsDataSource: request shape + response parsing +
// the COMPLAINT_*/VALIDATION_ERROR -> typed ComplaintActionRejected mapping.

import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/complaints/complaints_datasource.dart';
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

ComplaintsDataSource _ds(Dio dio) =>
    ComplaintsDataSource(dio: dio, query: RepositoryQuery.demo);

Map<String, dynamic> _complaintJson({
  String status = 'open',
  String slaState = 'onTrack',
  String? assignedTo,
}) =>
    {
      'id': 'c1',
      'category': 'facilities',
      'title': 'Broken fan in 6B',
      'description': 'Ceiling fan not working',
      'severity': 'medium',
      'status': status,
      'raisedBy': 'user-1',
      'raisedByRole': 'teacher',
      'relatedStudentId': null,
      'assignedTo': assignedTo,
      'assignedAt': null,
      'assignedBy': null,
      'slaDueAt': '2026-07-16T10:00:00Z',
      'slaState': slaState,
      'firstResponseAt': null,
      'resolvedAt': null,
      'resolvedBy': null,
      'resolutionNote': null,
      'reopenedCount': 0,
      'vendorId': null,
      'repairCost': null,
      'photoPath': null,
      'createdAt': '2026-07-15T10:00:00Z',
      'updatedAt': '2026-07-15T10:00:00Z',
    };

void main() {
  group('raise', () {
    test('posts the body and parses the created complaint', () async {
      Map<String, dynamic>? body;
      Map<String, dynamic>? query;
      final dio = createFakeDio((options) {
        body = options.data as Map<String, dynamic>?;
        query = options.queryParameters;
        return {'data': _complaintJson()};
      });

      final c = await _ds(dio).raise(
        category: 'facilities',
        title: 'Broken fan in 6B',
        description: 'Ceiling fan not working',
        severity: 'medium',
      );

      expect(c.id, 'c1');
      expect(c.status, 'open');
      expect(c.slaState, 'onTrack');
      expect(body?['category'], 'facilities');
      expect(body?['title'], 'Broken fan in 6B');
      expect(body?['severity'], 'medium');
      expect(body?.containsKey('relatedStudentId'), isFalse);
      expect(query?['tenantId'], isNotNull);
    });

    test('includes relatedStudentId only when provided', () async {
      Map<String, dynamic>? body;
      final dio = createFakeDio((options) {
        body = options.data as Map<String, dynamic>?;
        return {'data': _complaintJson()};
      });
      await _ds(dio).raise(
        category: 'safety',
        title: 'Loose railing',
        description: 'Near the stairs',
        relatedStudentId: 'stu-9',
      );
      expect(body?['relatedStudentId'], 'stu-9');
    });

    test('422 VALIDATION_ERROR -> typed rejection', () async {
      final dio = _rejectingDio(422, {
        'error': {'code': 'VALIDATION_ERROR', 'message': 'title (>=3 chars) is required'},
      });
      await expectLater(
        () => _ds(dio).raise(category: 'other', title: 'x', description: ''),
        throwsA(isA<ComplaintActionRejected>()
            .having((e) => e.code, 'code', 'VALIDATION_ERROR')),
      );
    });
  });

  group('list', () {
    test('sends filters + tenant scope and parses items', () async {
      Map<String, dynamic>? query;
      final dio = createFakeDio((options) {
        query = options.queryParameters;
        return {
          'data': {
            'items': [_complaintJson(), _complaintJson(status: 'resolved', slaState: 'breached')],
            'count': 2,
          },
        };
      });

      final items = await _ds(dio).list(status: 'open', category: 'facilities', severity: 'medium');
      expect(items, hasLength(2));
      expect(items[1].isBreached, isTrue);
      expect(query?['status'], 'open');
      expect(query?['category'], 'facilities');
      expect(query?['severity'], 'medium');
      expect(query?['tenantId'], isNotNull);
    });

    test('omits filter params when null', () async {
      Map<String, dynamic>? query;
      final dio = createFakeDio((options) {
        query = options.queryParameters;
        return {
          'data': {'items': [], 'count': 0},
        };
      });
      await _ds(dio).list();
      expect(query?.containsKey('status'), isFalse);
      expect(query?.containsKey('category'), isFalse);
      expect(query?.containsKey('severity'), isFalse);
      expect(query?.containsKey('assignedTo'), isFalse);
    });
  });

  group('detail', () {
    test('parses the complaint with its embedded event timeline', () async {
      final dio = createFakeDio((_) => {
            'data': {
              ..._complaintJson(status: 'assigned', assignedTo: 'staff-2'),
              'events': [
                {
                  'id': 'e1',
                  'complaintId': 'c1',
                  'eventType': 'raised',
                  'actorId': 'user-1',
                  'actorName': 'Asha',
                  'note': null,
                  'metadata': {'category': 'facilities'},
                  'occurredAt': '2026-07-15T10:00:00Z',
                },
                {
                  'id': 'e2',
                  'complaintId': 'c1',
                  'eventType': 'assigned',
                  'actorId': 'admin-1',
                  'occurredAt': '2026-07-15T11:00:00Z',
                },
              ],
            },
          });
      final c = await _ds(dio).detail('c1');
      expect(c.events, hasLength(2));
      expect(c.events.first.eventType, 'raised');
      expect(c.events.first.metadata?['category'], 'facilities');
      expect(c.assignedTo, 'staff-2');
    });
  });

  group('assign', () {
    test('posts assignedTo', () async {
      Map<String, dynamic>? body;
      final dio = createFakeDio((options) {
        body = options.data as Map<String, dynamic>?;
        return {'data': _complaintJson(status: 'assigned', assignedTo: 'staff-3')};
      });
      final c = await _ds(dio).assign(id: 'c1', assignedTo: 'staff-3');
      expect(body?['assignedTo'], 'staff-3');
      expect(c.assignedTo, 'staff-3');
    });

    test('422 COMPLAINT_ILLEGAL_ASSIGN -> typed rejection', () async {
      final dio = _rejectingDio(422, {
        'error': {'code': 'COMPLAINT_ILLEGAL_ASSIGN', 'message': "Cannot assign a complaint in status 'resolved'"},
      });
      await expectLater(
        () => _ds(dio).assign(id: 'c1', assignedTo: 'staff-1'),
        throwsA(isA<ComplaintActionRejected>()
            .having((e) => e.code, 'code', 'COMPLAINT_ILLEGAL_ASSIGN')),
      );
    });
  });

  group('updateStatus', () {
    test('posts status + resolutionNote', () async {
      Map<String, dynamic>? body;
      final dio = createFakeDio((options) {
        body = options.data as Map<String, dynamic>?;
        return {'data': _complaintJson(status: 'resolved')};
      });
      await _ds(dio).updateStatus(id: 'c1', status: 'resolved', resolutionNote: 'Fixed the fan');
      expect(body?['status'], 'resolved');
      expect(body?['resolutionNote'], 'Fixed the fan');
    });

    test('422 COMPLAINT_RESOLUTION_NOTE_REQUIRED -> typed rejection', () async {
      final dio = _rejectingDio(422, {
        'error': {
          'code': 'COMPLAINT_RESOLUTION_NOTE_REQUIRED',
          'message': 'A non-empty resolution note is required to resolve a complaint',
        },
      });
      await expectLater(
        () => _ds(dio).updateStatus(id: 'c1', status: 'resolved'),
        throwsA(isA<ComplaintActionRejected>()
            .having((e) => e.code, 'code', 'COMPLAINT_RESOLUTION_NOTE_REQUIRED')),
      );
    });

    test('422 COMPLAINT_ILLEGAL_TRANSITION -> typed rejection (surfaced honestly)', () async {
      final dio = _rejectingDio(422, {
        'error': {
          'code': 'COMPLAINT_ILLEGAL_TRANSITION',
          'message': "Cannot transition a complaint from 'closed' to 'in_progress'",
        },
      });
      await expectLater(
        () => _ds(dio).updateStatus(id: 'c1', status: 'in_progress'),
        throwsA(isA<ComplaintActionRejected>()
            .having((e) => e.code, 'code', 'COMPLAINT_ILLEGAL_TRANSITION')),
      );
    });

    test('a bare 403 FORBIDDEN (non-prefixed) is rethrown, not swallowed', () async {
      final dio = _rejectingDio(403, {
        'error': {'code': 'FORBIDDEN', 'message': 'Complaints require a school-scoped session'},
      });
      await expectLater(
        () => _ds(dio).updateStatus(id: 'c1', status: 'closed'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('comment', () {
    test('posts note and parses the created event', () async {
      Map<String, dynamic>? body;
      final dio = createFakeDio((options) {
        body = options.data as Map<String, dynamic>?;
        return {
          'data': {
            'id': 'e3',
            'complaintId': 'c1',
            'eventType': 'commented',
            'actorId': 'user-1',
            'occurredAt': '2026-07-15T12:00:00Z',
            'note': 'Checked, still broken',
          },
        };
      });
      final event = await _ds(dio).comment(id: 'c1', note: 'Checked, still broken');
      expect(body?['note'], 'Checked, still broken');
      expect(event.eventType, 'commented');
    });
  });

  group('attachVendor', () {
    test('posts vendorId + repairCost', () async {
      Map<String, dynamic>? body;
      final dio = createFakeDio((options) {
        body = options.data as Map<String, dynamic>?;
        return {
          'data': _complaintJson()
            ..addAll({'vendorId': 'v1', 'repairCost': 1500}),
        };
      });
      final c = await _ds(dio).attachVendor(id: 'c1', vendorId: 'v1', repairCost: 1500);
      expect(body?['vendorId'], 'v1');
      expect(body?['repairCost'], 1500);
      expect(c.vendorId, 'v1');
      expect(c.repairCost, 1500);
    });

    test('404 COMPLAINT_VENDOR_NOT_FOUND -> typed rejection', () async {
      final dio = _rejectingDio(404, {
        'error': {'code': 'COMPLAINT_VENDOR_NOT_FOUND', 'message': 'Vendor not found in this school: v9'},
      });
      await expectLater(
        () => _ds(dio).attachVendor(id: 'c1', vendorId: 'v9'),
        throwsA(isA<ComplaintActionRejected>()
            .having((e) => e.code, 'code', 'COMPLAINT_VENDOR_NOT_FOUND')),
      );
    });
  });
}
