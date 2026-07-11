// Audit R1 (P1-2) — the test that would have caught P1-1: in production
// recordCheck ALWAYS takes the ReliableWriter branch (never the direct-Dio
// one), so typed 422 rejections MUST be mapped from the failed
// MutationOutcome, and offline MUST surface as the typed
// StaffAttendanceOffline — never an optimistic "recorded".
//
// Drives the REAL StaffAttendanceRemoteDataSource through a fake
// ReliableWriter returning the real MutationOutcome shapes the gateway
// produces (see mutation_gateway.dart / dio_mutation_executor.dart: a 422
// error envelope becomes a failed outcome carrying error.code/error.message;
// offline on an online-only op becomes a failed outcome with code OFFLINE).

import 'package:akshara_erp/core/errors/api_failure.dart';
import 'package:akshara_erp/core/reliability/model/mutation_outcome.dart';
import 'package:akshara_erp/core/reliability/model/reliability_enums.dart';
import 'package:akshara_erp/core/reliability/reliable_writer.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/staff_attendance/staff_attendance_models.dart';
import 'package:akshara_erp/features/staff_attendance/staff_attendance_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeReliableWriter implements ReliableWriter {
  _FakeReliableWriter(this.outcome);
  final MutationOutcome outcome;
  Map<String, dynamic>? capturedBody;
  String? capturedType;

  @override
  Future<MutationOutcome> runWrite({
    required String type,
    required String method,
    required String path,
    Map<String, dynamic> body = const <String, dynamic>{},
    Map<String, dynamic> scope = const <String, dynamic>{},
    String? entityRef,
    String? idempotencyKey,
  }) async {
    capturedType = type;
    capturedBody = body;
    return outcome;
  }
}

StaffAttendanceRemoteDataSource _datasource(_FakeReliableWriter reliable) =>
    StaffAttendanceRemoteDataSource(
      // Never reached on the reliable path — a bare Dio is fine.
      dio: Dio(BaseOptions(baseUrl: 'https://test.api/v1')),
      query: RepositoryQuery.demo,
      reliable: reliable,
    );

AttendanceLocationFix _fix() => AttendanceLocationFix(
      latitude: 17.45,
      longitude: 78.39,
      accuracyM: 8,
      isMock: false,
      capturedAt: DateTime.utc(2026, 7, 11, 10),
    );

FaceCapture _face() => const FaceCapture(
      embedding: [0.1, 0.2, 0.3],
      livenessPassed: true,
      modelTag: 'mobilefacenet-v1',
    );

Future<StaffCheckRecord> _record(_FakeReliableWriter reliable) =>
    _datasource(reliable).recordCheck(
      event: StaffCheckEvent.checkIn,
      location: _fix(),
      face: _face(),
    );

void main() {
  group('recordCheck via ReliableWriter (the PRODUCTION path)', () {
    test('confirmed outcome → parses the server row', () async {
      final reliable = _FakeReliableWriter(const MutationOutcome(
        status: SyncStatus.confirmed,
        operationId: 'op_1',
        data: {
          'id': 'chk_1',
          'eventType': 'check_in',
          'method': 'face_match',
          'locationVerified': true,
          'faceMatched': true,
          'faceMatchScore': 0.93,
        },
      ));

      final record = await _record(reliable);

      expect(record.id, 'chk_1');
      expect(record.faceMatched, isTrue);
      expect(record.pendingSync, isFalse);
      expect(reliable.capturedType, 'staffAttendance.check');
      expect(
        (reliable.capturedBody?['face'] as Map?)?['modelTag'],
        'mobilefacenet-v1',
        reason: 'modelTag must reach the server on the reliability path too',
      );
    });

    test('422 FACE_NOT_ENROLLED failed outcome → typed StaffAttendanceRejected '
        '(the bug: this used to surface as a generic ApiFailureException)',
        () async {
      final reliable = _FakeReliableWriter(const MutationOutcome(
        status: SyncStatus.failed,
        operationId: 'op_2',
        errorCode: 'STAFF_ATTENDANCE_FACE_NOT_ENROLLED',
        errorMessage:
            'No enrolled reference face — enrol your face before recording attendance',
      ));

      await expectLater(
        () => _record(reliable),
        throwsA(
          isA<StaffAttendanceRejected>()
              .having((e) => e.code, 'code', 'STAFF_ATTENDANCE_FACE_NOT_ENROLLED')
              .having((e) => e.message, 'message', contains('enrol')),
        ),
      );
    });

    test('422 OUTSIDE_GEOFENCE failed outcome → typed rejection with the '
        'location code (drives the location banner)', () async {
      final reliable = _FakeReliableWriter(const MutationOutcome(
        status: SyncStatus.failed,
        operationId: 'op_3',
        errorCode: 'STAFF_ATTENDANCE_OUTSIDE_GEOFENCE',
        errorMessage: 'too far',
      ));

      await expectLater(
        () => _record(reliable),
        throwsA(isA<StaffAttendanceRejected>()
            .having((e) => e.isFaceReason, 'isFaceReason', isFalse)),
      );
    });

    test('OFFLINE failed outcome → typed StaffAttendanceOffline, '
        'NEVER an optimistic record', () async {
      final reliable = _FakeReliableWriter(const MutationOutcome(
        status: SyncStatus.failed,
        operationId: 'op_4',
        errorCode: 'OFFLINE',
        errorMessage: 'No connection. This action needs to be online.',
      ));

      await expectLater(
        () => _record(reliable),
        throwsA(isA<StaffAttendanceOffline>()),
      );
    });

    test('a PENDING (queued/optimistic) outcome is REFUSED — defensive guard '
        'if the op were ever re-registered queueable', () async {
      final reliable = _FakeReliableWriter(const MutationOutcome(
        status: SyncStatus.pending,
        operationId: 'op_5',
      ));

      await expectLater(
        () => _record(reliable),
        throwsA(isA<StaffAttendanceOffline>()),
        reason: 'a queued check-in is guaranteed-stale on drain — an '
            'optimistic success would be a lie',
      );
    });

    test('a non-attendance failure code still surfaces as the standard '
        'ApiFailureException path (unchanged behaviour)', () async {
      final reliable = _FakeReliableWriter(const MutationOutcome(
        status: SyncStatus.failed,
        operationId: 'op_6',
        errorCode: 'FORBIDDEN',
        errorMessage: 'nope',
      ));

      await expectLater(
        () => _record(reliable),
        throwsA(isA<ApiFailureException>()),
      );
    });
  });
}
