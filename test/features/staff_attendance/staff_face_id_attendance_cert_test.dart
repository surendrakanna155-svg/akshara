// Staff Face ID attendance — certification (O5, Must-Before-GA, parallel to QW8).
//
// Proves the staff biometric self check-in/out feature headless (no device):
//   1. HARD-BLOCK — a check-in proceeds ONLY on a real biometric. If the
//      biometric is unavailable (no enrolment) or fails, NOTHING is written and
//      NOTHING is audited. There is NO device-credential (PIN) fallback.
//   2. Both check_in AND check_out are recorded (owner decision), each emitting
//      the matching audit event through the real categorizer (→ workflow).
//   3. The write is offline-queueable (reliability platform), surfaced as pending.
//   4. RBAC — every staff persona holds markStaffAttendance; parent/student never.
//   5. The card UI renders the recorded / biometric-blocked states.
//
// Live deploy + a real on-device biometric run are the Track-B remainder.

import 'package:akshara_erp/core/audit/audit_event.dart';
import 'package:akshara_erp/core/audit/audit_logger.dart';
import 'package:akshara_erp/core/biometric/biometric_authenticator.dart';
import 'package:akshara_erp/core/reliability/model/reliability_enums.dart';
import 'package:akshara_erp/core/reliability/policy/operation_policy_registry.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/mutation_permission_registry.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/role_permissions.dart';
import 'package:akshara_erp/features/staff_attendance/staff_attendance_controller.dart';
import 'package:akshara_erp/features/staff_attendance/staff_attendance_models.dart';
import 'package:akshara_erp/features/staff_attendance/widgets/staff_check_in_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBiometric implements BiometricAuthenticator {
  _FakeBiometric(this._result);
  final BiometricResult _result;
  int calls = 0;
  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    calls++;
    return _result;
  }
}

class _FakeWriter implements StaffAttendanceWriter {
  _FakeWriter({this.pendingSync = false, this.throwError = false});
  final bool pendingSync;
  final bool throwError;
  final List<({StaffCheckEvent event, String method})> calls = [];
  @override
  Future<StaffCheckRecord> recordCheck({
    required StaffCheckEvent event,
    required String method,
  }) async {
    calls.add((event: event, method: method));
    if (throwError) throw Exception('network down');
    return StaffCheckRecord(
      id: 'chk_1',
      eventType: event.apiValue,
      method: method,
      biometricVerified: true,
      pendingSync: pendingSync,
    );
  }
}

Future<AuditLogger> _auditLogger() async {
  SharedPreferences.setMockInitialValues({});
  return AuditLogger(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Staff Face ID — biometric hard-block', () {
    test('no enrolled biometric → blocked, NO write, NO audit (no PIN fallback)',
        () async {
      final biometric = _FakeBiometric(BiometricResult.unavailable());
      final writer = _FakeWriter();
      final audit = await _auditLogger();
      final controller = StaffAttendanceController(
        biometric: biometric,
        writer: writer,
        audit: audit,
      );

      final outcome = await controller.record(StaffCheckEvent.checkIn);

      expect(outcome.status, StaffCheckStatus.biometricRequired);
      expect(writer.calls, isEmpty, reason: 'write must NOT run without biometric');
      expect(await audit.readAll(), isEmpty, reason: 'no audit on a blocked check-in');
    });

    test('biometric cancelled/failed → blocked, NO write, NO audit', () async {
      final writer = _FakeWriter();
      final audit = await _auditLogger();
      final controller = StaffAttendanceController(
        biometric: _FakeBiometric(BiometricResult.failed()),
        writer: writer,
        audit: audit,
      );

      final outcome = await controller.record(StaffCheckEvent.checkIn);

      expect(outcome.status, StaffCheckStatus.biometricRequired);
      expect(writer.calls, isEmpty);
      expect(await audit.readAll(), isEmpty);
    });
  });

  group('Staff Face ID — recorded events', () {
    test('successful biometric check-IN → write + staffCheckInRecorded audit',
        () async {
      final writer = _FakeWriter();
      final audit = await _auditLogger();
      final controller = StaffAttendanceController(
        biometric: _FakeBiometric(BiometricResult.success('face_id')),
        writer: writer,
        audit: audit,
      );

      final outcome = await controller.record(StaffCheckEvent.checkIn);

      expect(outcome.isRecorded, isTrue);
      expect(writer.calls.single.event, StaffCheckEvent.checkIn);
      expect(writer.calls.single.method, 'face_id');

      final events = await audit.readAll();
      expect(events.single.type, AuditEventType.staffCheckInRecorded);
      expect(events.single.metadata['method'], 'face_id');
      expect(events.single.metadata['eventType'], 'check_in');
    });

    test('successful biometric check-OUT → write + staffCheckOutRecorded audit',
        () async {
      final writer = _FakeWriter();
      final audit = await _auditLogger();
      final controller = StaffAttendanceController(
        biometric: _FakeBiometric(BiometricResult.success('fingerprint')),
        writer: writer,
        audit: audit,
      );

      final outcome = await controller.record(StaffCheckEvent.checkOut);

      expect(outcome.isRecorded, isTrue);
      expect(writer.calls.single.event, StaffCheckEvent.checkOut);
      final events = await audit.readAll();
      expect(events.single.type, AuditEventType.staffCheckOutRecorded);
      expect(events.single.metadata['eventType'], 'check_out');
    });

    test('offline → write queued (pendingSync) is still recorded + audited',
        () async {
      final writer = _FakeWriter(pendingSync: true);
      final audit = await _auditLogger();
      final controller = StaffAttendanceController(
        biometric: _FakeBiometric(BiometricResult.success('face_id')),
        writer: writer,
        audit: audit,
      );

      final outcome = await controller.record(StaffCheckEvent.checkIn);

      expect(outcome.isRecorded, isTrue);
      expect(outcome.record!.pendingSync, isTrue);
      expect((await audit.readAll()).single.metadata['pendingSync'], 'true');
    });

    test('write failure after a valid biometric → failed, NO audit', () async {
      final writer = _FakeWriter(throwError: true);
      final audit = await _auditLogger();
      final controller = StaffAttendanceController(
        biometric: _FakeBiometric(BiometricResult.success('face_id')),
        writer: writer,
        audit: audit,
      );

      final outcome = await controller.record(StaffCheckEvent.checkIn);

      expect(outcome.status, StaffCheckStatus.failed);
      expect(await audit.readAll(), isEmpty,
          reason: 'audit is emitted only after a confirmed/queued write');
    });
  });

  group('Staff Face ID — RBAC + reliability policy', () {
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

    test('check-in write is offline-queueable (low-risk) in the policy registry', () {
      final policy = OperationPolicyRegistry.withDefaults()
          .policyFor(OperationTypes.markStaffAttendance);
      expect(policy.kind, OperationKind.queueable);
      expect(policy.conflictCategory, ConflictCategory.lowRisk);
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

  group('Staff Face ID — card UI', () {
    testWidgets('renders check-in/out buttons and a success banner on record',
        (tester) async {
      final audit = await _auditLogger();
      final controller = StaffAttendanceController(
        biometric: _FakeBiometric(BiometricResult.success('face_id')),
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

    testWidgets('shows the biometric-required banner when the gate blocks',
        (tester) async {
      final audit = await _auditLogger();
      final controller = StaffAttendanceController(
        biometric: _FakeBiometric(BiometricResult.unavailable()),
        writer: _FakeWriter(),
        audit: audit,
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StaffCheckInCard(onRecord: controller.record)),
      ));

      await tester.tap(find.byKey(const Key('staff-check-in-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff-check-status')), findsOneWidget);
      expect(find.textContaining('biometric', findRichText: true), findsWidgets);
    });
  });
}
