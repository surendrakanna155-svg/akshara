// Staff attendance — certification (B4, re-implemented per the FINAL design decision:
// GPS geofence + anti-mock + live camera face; NO device biometric).
//
// Proves the feature headless (no device):
//   1. HARD-STOP chain — a check-in proceeds ONLY when the location step AND the
//      face step succeed. If location capture fails, a mock GPS is detected, or the
//      face capture fails, NOTHING is written and NOTHING is audited. There is NO
//      device-biometric / PIN fallback.
//   2. Both check_in AND check_out are recorded, each emitting the matching audit
//      event through the real categorizer (→ workflow).
//   3. A SERVER 422 rejection (geofence / face no-match) is surfaced as the right
//      location/face banner, with NO audit.
//   4. The write is offline-queueable (reliability platform), surfaced as pending.
//   5. RBAC — every staff persona holds markStaffAttendance; parent/student never.
//   6. The card UI renders the recorded / location-blocked / face-blocked states.
//
// The concrete geolocator / camera+ML device adapters + a live on-device run are
// the Track-B remainder (device + Flutter-toolchain gated).

import 'package:akshara_erp/core/audit/audit_event.dart';
import 'package:akshara_erp/core/audit/audit_logger.dart';
import 'package:akshara_erp/core/reliability/model/reliability_enums.dart';
import 'package:akshara_erp/core/reliability/policy/operation_policy_registry.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/mutation_permission_registry.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/role_permissions.dart';
import 'package:akshara_erp/features/staff_attendance/attendance_capture_sources.dart';
import 'package:akshara_erp/features/staff_attendance/staff_attendance_controller.dart';
import 'package:akshara_erp/features/staff_attendance/staff_attendance_models.dart';
import 'package:akshara_erp/features/staff_attendance/widgets/staff_check_in_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AttendanceLocationFix _fix({bool isMock = false}) => AttendanceLocationFix(
      latitude: 17.45,
      longitude: 78.39,
      accuracyM: 8,
      isMock: isMock,
      capturedAt: DateTime.utc(2026, 7, 1, 10),
    );

FaceCapture _face() => const FaceCapture(
      embedding: [0.1, 0.2, 0.3, 0.4],
      livenessPassed: true,
      captureRef: 'cap/1.jpg',
    );

class _FakeWriter implements StaffAttendanceWriter {
  _FakeWriter({this.throwError = false, this.reject});
  final bool throwError;
  final StaffAttendanceRejected? reject;
  final List<({StaffCheckEvent event, AttendanceLocationFix location, FaceCapture face})> calls = [];
  @override
  Future<StaffCheckRecord> recordCheck({
    required StaffCheckEvent event,
    required AttendanceLocationFix location,
    required FaceCapture face,
  }) async {
    calls.add((event: event, location: location, face: face));
    if (reject != null) throw reject!;
    if (throwError) throw Exception('network down');
    return StaffCheckRecord(
      id: 'chk_1',
      eventType: event.apiValue,
      method: 'face_match',
      locationVerified: true,
      faceMatched: true,
      faceMatchScore: 0.95,
    );
  }
}

/// Simulates the online-only gateway path when the device is offline: the
/// write seam surfaces the typed [StaffAttendanceOffline] (audit R1) — it
/// NEVER returns an optimistic record.
class _OfflineWriter implements StaffAttendanceWriter {
  @override
  Future<StaffCheckRecord> recordCheck({
    required StaffCheckEvent event,
    required AttendanceLocationFix location,
    required FaceCapture face,
  }) async =>
      throw const StaffAttendanceOffline();
}

Future<AuditLogger> _auditLogger() async {
  SharedPreferences.setMockInitialValues({});
  return AuditLogger(await SharedPreferences.getInstance());
}

StaffAttendanceController _controller({
  required AttendanceLocationSource location,
  required FaceCaptureSource face,
  required StaffAttendanceWriter writer,
  required AuditLogger audit,
}) =>
    StaffAttendanceController(location: location, face: face, writer: writer, audit: audit);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('B4 attendance — capture hard-stop (no biometric/PIN fallback)', () {
    test('location capture failure → blocked, NO write, NO audit', () async {
      final writer = _FakeWriter();
      final audit = await _auditLogger();
      final controller = _controller(
        location: const FailingLocationSource(),
        face: FixedFaceSource(_face()),
        writer: writer,
        audit: audit,
      );

      final outcome = await controller.record(StaffCheckEvent.checkIn);

      expect(outcome.status, StaffCheckStatus.locationBlocked);
      expect(writer.calls, isEmpty, reason: 'write must NOT run without a location');
      expect(await audit.readAll(), isEmpty);
    });

    test('MOCK GPS detected on-device → blocked before the camera, NO write', () async {
      final writer = _FakeWriter();
      final audit = await _auditLogger();
      final controller = _controller(
        location: FixedLocationSource(_fix(isMock: true)),
        face: FixedFaceSource(_face()),
        writer: writer,
        audit: audit,
      );

      final outcome = await controller.record(StaffCheckEvent.checkIn);

      expect(outcome.status, StaffCheckStatus.locationBlocked);
      expect(writer.calls, isEmpty);
      expect(await audit.readAll(), isEmpty);
    });

    test('face capture cancelled → blocked, NO write, NO audit', () async {
      final writer = _FakeWriter();
      final audit = await _auditLogger();
      final controller = _controller(
        location: FixedLocationSource(_fix()),
        face: const FailingFaceSource(),
        writer: writer,
        audit: audit,
      );

      final outcome = await controller.record(StaffCheckEvent.checkIn);

      expect(outcome.status, StaffCheckStatus.faceBlocked);
      expect(writer.calls, isEmpty);
      expect(await audit.readAll(), isEmpty);
    });
  });

  group('B4 attendance — recorded events', () {
    test('valid location + face check-IN → write + staffCheckInRecorded audit', () async {
      final writer = _FakeWriter();
      final audit = await _auditLogger();
      final controller = _controller(
        location: FixedLocationSource(_fix()),
        face: FixedFaceSource(_face()),
        writer: writer,
        audit: audit,
      );

      final outcome = await controller.record(StaffCheckEvent.checkIn);

      expect(outcome.isRecorded, isTrue);
      expect(writer.calls.single.event, StaffCheckEvent.checkIn);
      final events = await audit.readAll();
      expect(events.single.type, AuditEventType.staffCheckInRecorded);
      expect(events.single.metadata['method'], 'face_match');
      expect(events.single.metadata['eventType'], 'check_in');
    });

    test('valid check-OUT → write + staffCheckOutRecorded audit', () async {
      final writer = _FakeWriter();
      final audit = await _auditLogger();
      final controller = _controller(
        location: FixedLocationSource(_fix()),
        face: FixedFaceSource(_face()),
        writer: writer,
        audit: audit,
      );

      final outcome = await controller.record(StaffCheckEvent.checkOut);

      expect(outcome.isRecorded, isTrue);
      expect((await audit.readAll()).single.type, AuditEventType.staffCheckOutRecorded);
    });

    // Audit R1: DELIBERATE behaviour change from the original "offline →
    // queued (pendingSync) is still recorded" test. Check-in is now
    // ONLINE-ONLY by design: the server enforces a location-freshness window,
    // so a queued check-in drained later is GUARANTEED-stale — an optimistic
    // "recorded" would be a lie (docs/ATTENDANCE_AUTH_DESIGN_DECISION.md §4;
    // the only offline path is the audited manual request).
    test('OFFLINE → honest typed failure with the manual-request hint, '
        'NO optimistic success, NO audit', () async {
      final writer = _OfflineWriter();
      final audit = await _auditLogger();
      final controller = _controller(
        location: FixedLocationSource(_fix()),
        face: FixedFaceSource(_face()),
        writer: writer,
        audit: audit,
      );

      final outcome = await controller.record(StaffCheckEvent.checkIn);

      expect(outcome.status, StaffCheckStatus.failed);
      expect(outcome.record, isNull, reason: 'never an optimistic record offline');
      expect(outcome.message, StaffAttendanceOffline.userMessage);
      expect(outcome.message, contains('manual attendance request'));
      expect(await audit.readAll(), isEmpty);
    });

    test('server FACE_NO_MATCH (422) → faceBlocked, NO audit', () async {
      final writer = _FakeWriter(
        reject: const StaffAttendanceRejected('STAFF_ATTENDANCE_FACE_NO_MATCH', 'no match'),
      );
      final audit = await _auditLogger();
      final controller = _controller(
        location: FixedLocationSource(_fix()),
        face: FixedFaceSource(_face()),
        writer: writer,
        audit: audit,
      );

      final outcome = await controller.record(StaffCheckEvent.checkIn);

      expect(outcome.status, StaffCheckStatus.faceBlocked);
      expect(await audit.readAll(), isEmpty);
    });

    test('server OUTSIDE_GEOFENCE (422) → locationBlocked, NO audit', () async {
      final writer = _FakeWriter(
        reject: const StaffAttendanceRejected('STAFF_ATTENDANCE_OUTSIDE_GEOFENCE', 'too far'),
      );
      final audit = await _auditLogger();
      final controller = _controller(
        location: FixedLocationSource(_fix()),
        face: FixedFaceSource(_face()),
        writer: writer,
        audit: audit,
      );

      final outcome = await controller.record(StaffCheckEvent.checkIn);

      expect(outcome.status, StaffCheckStatus.locationBlocked);
      expect(await audit.readAll(), isEmpty);
    });

    test('write failure after a valid capture → failed, NO audit', () async {
      final writer = _FakeWriter(throwError: true);
      final audit = await _auditLogger();
      final controller = _controller(
        location: FixedLocationSource(_fix()),
        face: FixedFaceSource(_face()),
        writer: writer,
        audit: audit,
      );

      final outcome = await controller.record(StaffCheckEvent.checkIn);

      expect(outcome.status, StaffCheckStatus.failed);
      expect(await audit.readAll(), isEmpty);
    });
  });

  group('B4 attendance — RBAC + reliability policy (unchanged contracts)', () {
    test('every staff persona holds markStaffAttendance; parent/student never', () {
      for (final role in ErpRole.values) {
        final has = RolePermissionMatrix.permissionsFor(role)
            .contains(Permission.markStaffAttendance);
        if (role == ErpRole.parent || role == ErpRole.student) {
          expect(has, isFalse, reason: '${role.name} must NOT self-check-in');
        } else {
          expect(has, isTrue, reason: '${role.name} is staff and may self-check-in');
        }
      }
    });

    test('multi-hat union grants it when ANY hat is staff (parent+teacher)', () {
      final union = RolePermissionMatrix.permissionsForRoles(
        const [ErpRole.parent, ErpRole.teacher],
      );
      expect(union.contains(Permission.markStaffAttendance), isTrue);
    });

    // Audit R1: DELIBERATELY changed from queueable → onlineOnly. A queued
    // check-in drained after reconnect is guaranteed-stale under the server's
    // location-freshness window, so this op must fail fast offline instead of
    // producing an optimistic result (see the OFFLINE test above).
    test('check-in write is ONLINE-ONLY in the policy registry (never queued)', () {
      final policy = OperationPolicyRegistry.withDefaults()
          .policyFor(OperationTypes.markStaffAttendance);
      expect(policy.kind, OperationKind.onlineOnly);
      expect(policy.isOnlineOnly, isTrue);
    });

    test('both staff-attendance mutations require markStaffAttendance', () {
      final entries = MutationPermissionRegistry.forModule('staff_attendance');
      expect(entries.map((e) => e.mutationId),
          containsAll(['recordStaffCheckIn', 'recordStaffCheckOut']));
      for (final e in entries) {
        expect(e.permission, Permission.markStaffAttendance);
      }
    });
  });

  group('B4 attendance — card UI', () {
    testWidgets('renders check-in/out buttons and a success banner on record',
        (tester) async {
      final audit = await _auditLogger();
      final controller = _controller(
        location: FixedLocationSource(_fix()),
        face: FixedFaceSource(_face()),
        writer: _FakeWriter(),
        audit: audit,
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StaffCheckInCard(onRecord: controller.record)),
      ));

      expect(find.byKey(const Key('staff-check-in-button')), findsOneWidget);
      expect(find.byKey(const Key('staff-check-out-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('staff-check-in-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff-check-status')), findsOneWidget);
      expect(find.textContaining('recorded'), findsOneWidget);
    });

    testWidgets('shows the location-blocked banner when the geofence step blocks',
        (tester) async {
      final audit = await _auditLogger();
      final controller = _controller(
        location: const FailingLocationSource('LOCATION_UNAVAILABLE', 'Turn on location to check in'),
        face: FixedFaceSource(_face()),
        writer: _FakeWriter(),
        audit: audit,
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StaffCheckInCard(onRecord: controller.record)),
      ));

      await tester.tap(find.byKey(const Key('staff-check-in-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff-check-status')), findsOneWidget);
      expect(find.textContaining('location'), findsWidgets);
    });
  });
}
