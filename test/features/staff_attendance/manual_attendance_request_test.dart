// PRA-P0-15 — audited manual-attendance fallback (client).
//
// Proves headless (no device, no live backend):
//   1. Request screen — reason validation blocks a <3-char submit (no network
//      call) and a valid reason submits + shows the success banner; a server
//      rejection surfaces the error banner.
//   2. Approver queue — pending requests render; Approve calls the decide
//      endpoint with approve:true and refreshes; Reject calls it with
//      approve:false.
//   3. Check-in card — the "Request manual attendance" fallback is always
//      reachable; the "Approve manual requests" entry is gated on the approver
//      permission provider.

import 'package:akshara_erp/features/staff_attendance/manual_attendance_approver_screen.dart';
import 'package:akshara_erp/features/staff_attendance/manual_attendance_request_datasource.dart';
import 'package:akshara_erp/features/staff_attendance/manual_attendance_request_models.dart';
import 'package:akshara_erp/features/staff_attendance/manual_attendance_request_providers.dart';
import 'package:akshara_erp/features/staff_attendance/manual_attendance_request_screen.dart';
import 'package:akshara_erp/features/staff_attendance/staff_attendance_models.dart';
import 'package:akshara_erp/features/staff_attendance/widgets/staff_check_in_card.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDataSource implements ManualAttendanceRequestDataSource {
  _FakeDataSource({
    List<ManualAttendanceRequest>? pending,
    this.submitError,
  }) : _pending = [...?pending];

  final List<ManualAttendanceRequest> _pending;
  final Object? submitError;

  final List<({StaffCheckEvent event, String reason})> submitCalls = [];
  final List<({String requestId, bool approve})> decideCalls = [];

  @override
  Future<ManualRequestSubmitResult> submit({
    required StaffCheckEvent event,
    required String reason,
    String? staffName,
  }) async {
    submitCalls.add((event: event, reason: reason));
    final error = submitError;
    if (error != null) throw error;
    return ManualRequestSubmitResult(
      id: 'req_1',
      status: ManualRequestStatus.pending,
      eventType: event,
    );
  }

  @override
  Future<List<ManualAttendanceRequest>> listPending() async =>
      List.of(_pending);

  @override
  Future<ManualRequestDecision> decide({
    required String requestId,
    required bool approve,
  }) async {
    decideCalls.add((requestId: requestId, approve: approve));
    _pending.removeWhere((r) => r.id == requestId);
    return ManualRequestDecision(
      id: requestId,
      status: approve
          ? ManualRequestStatus.approved
          : ManualRequestStatus.rejected,
      checkInId: approve ? 'chk_9' : null,
    );
  }
}

ManualAttendanceRequest _req(String id, {String name = 'Asha'}) =>
    ManualAttendanceRequest(
      id: id,
      status: ManualRequestStatus.pending,
      eventType: StaffCheckEvent.checkIn,
      reason: 'Camera not working',
      staffName: name,
    );

Widget _wrap(Widget child, _FakeDataSource fake, {bool canApprove = false}) {
  return ProviderScope(
    overrides: [
      manualAttendanceRequestDataSourceProvider.overrideWithValue(fake),
      canApproveManualAttendanceProvider.overrideWithValue(canApprove),
    ],
    child: MaterialApp(theme: AksharaAppTheme.light(), home: child),
  );
}

void main() {
  group('PRA-P0-15 request screen', () {
    testWidgets('reason under 3 chars is rejected — NO network call', (tester) async {
      final fake = _FakeDataSource();
      await tester.pumpWidget(_wrap(const ManualAttendanceRequestScreen(), fake));

      await tester.enterText(
          find.byKey(const Key('manual-request-reason-field')), 'ok');
      await tester.tap(find.byKey(const Key('manual-request-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(fake.submitCalls, isEmpty,
          reason: 'validation must block the submit before any network call');
      expect(find.text('Enter a reason (at least 3 characters).'),
          findsOneWidget);
      expect(find.byKey(const Key('manual-request-success')), findsNothing);
    });

    testWidgets('valid reason submits + shows success banner', (tester) async {
      final fake = _FakeDataSource();
      await tester.pumpWidget(_wrap(const ManualAttendanceRequestScreen(), fake));

      await tester.enterText(
          find.byKey(const Key('manual-request-reason-field')),
          'Phone camera is broken today');
      await tester.tap(find.byKey(const Key('manual-request-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(fake.submitCalls.single.event, StaffCheckEvent.checkIn);
      expect(fake.submitCalls.single.reason, 'Phone camera is broken today');
      expect(find.byKey(const Key('manual-request-success')), findsOneWidget);
    });

    testWidgets('server rejection surfaces the error banner', (tester) async {
      final fake = _FakeDataSource(
        submitError: const ManualAttendanceRequestException(
          'STAFF_ATTENDANCE_REASON_REQUIRED',
          'A reason is required for a manual request',
        ),
      );
      await tester.pumpWidget(_wrap(const ManualAttendanceRequestScreen(), fake));

      await tester.enterText(
          find.byKey(const Key('manual-request-reason-field')), 'valid reason');
      await tester.tap(find.byKey(const Key('manual-request-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('manual-request-error')), findsOneWidget);
      expect(find.textContaining('reason is required'), findsOneWidget);
    });
  });

  group('PRA-P0-15 approver queue', () {
    testWidgets('lists pending + Approve calls decide(approve:true) & refreshes',
        (tester) async {
      final fake = _FakeDataSource(pending: [_req('r1'), _req('r2', name: 'Ravi')]);
      await tester.pumpWidget(
          _wrap(const ManualAttendanceApproverScreen(), fake, canApprove: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Asha · Check in'), findsOneWidget);
      expect(find.text('Ravi · Check in'), findsOneWidget);

      await tester.tap(find.byKey(const Key('manual-approver-approve-r1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(fake.decideCalls.single.requestId, 'r1');
      expect(fake.decideCalls.single.approve, isTrue);
      // Refreshed: r1 removed from the pending queue.
      expect(find.text('Asha · Check in'), findsNothing);
      expect(find.text('Ravi · Check in'), findsOneWidget);
    });

    testWidgets('Reject calls decide(approve:false)', (tester) async {
      final fake = _FakeDataSource(pending: [_req('r9')]);
      await tester.pumpWidget(
          _wrap(const ManualAttendanceApproverScreen(), fake, canApprove: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const Key('manual-approver-reject-r9')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(fake.decideCalls.single.requestId, 'r9');
      expect(fake.decideCalls.single.approve, isFalse);
    });

    testWidgets('empty queue renders the empty state', (tester) async {
      final fake = _FakeDataSource(pending: const []);
      await tester.pumpWidget(
          _wrap(const ManualAttendanceApproverScreen(), fake, canApprove: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('No pending manual attendance requests.'), findsOneWidget);
    });
  });

  group('PRA-P0-15 check-in card fallback', () {
    testWidgets('fallback is reachable; approver entry gated OFF without perm',
        (tester) async {
      final fake = _FakeDataSource();
      var requested = false;
      await tester.pumpWidget(_wrap(
        StaffCheckInCard(
          onRecord: (e) async => StaffCheckOutcome.recorded(
            StaffCheckRecord(id: 'x', eventType: e.apiValue, method: 'manual'),
          ),
          onRequestManual: () => requested = true,
        ),
        fake,
        canApprove: false,
      ));

      expect(find.byKey(const Key('staff-request-manual-button')), findsOneWidget);
      expect(find.byKey(const Key('staff-approve-manual-button')), findsNothing);

      await tester.tap(find.byKey(const Key('staff-request-manual-button')));
      await tester.pump();
      expect(requested, isTrue);
    });

    testWidgets('approver entry shows + is reachable WITH permission',
        (tester) async {
      final fake = _FakeDataSource();
      var opened = false;
      await tester.pumpWidget(_wrap(
        StaffCheckInCard(
          onRecord: (e) async => StaffCheckOutcome.recorded(
            StaffCheckRecord(id: 'x', eventType: e.apiValue, method: 'manual'),
          ),
          onOpenApproverQueue: () => opened = true,
        ),
        fake,
        canApprove: true,
      ));

      expect(find.byKey(const Key('staff-approve-manual-button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('staff-approve-manual-button')));
      await tester.pump();
      expect(opened, isTrue);
    });
  });
}
