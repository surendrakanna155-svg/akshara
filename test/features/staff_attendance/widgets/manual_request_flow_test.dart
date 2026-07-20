// Slice 4 — the Manual Attendance Request fallback is DISCOVERABLE and safe:
//   1. Card CTA matrix: "Request manual attendance" appears exactly when the
//      chain could NOT complete (location/face/failed) — never on success.
//   2. Dialog: duplicate-pending guard, reason validation (server mirror),
//      submit → pending-approval confirmation.

import 'package:akshara_erp/features/staff_attendance/manual_request_datasource.dart';
import 'package:akshara_erp/features/staff_attendance/staff_attendance_models.dart';
import 'package:akshara_erp/features/staff_attendance/widgets/manual_request_dialog.dart';
import 'package:akshara_erp/features/staff_attendance/widgets/staff_check_in_card.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake datasource — implements the concrete class; only the members the
/// dialog touches are live, the rest throw if reached.
class _FakeManualRequestDataSource implements ManualAttendanceRequestDataSource {
  _FakeManualRequestDataSource({
    this.existing = const <ManualAttendanceRequest>[],
    this.failCreate = false,
  });

  final List<ManualAttendanceRequest> existing;
  final bool failCreate;
  final List<({String event, String reason})> created = [];

  @override
  Future<List<ManualAttendanceRequest>> myRequests() async => existing;

  @override
  Future<ManualAttendanceRequest> create({
    required StaffCheckEvent event,
    required String reason,
  }) async {
    if (failCreate) {
      throw const StaffAttendanceRejected(
        'STAFF_ATTENDANCE_REASON_REQUIRED',
        'A reason is required for a manual request',
      );
    }
    created.add((event: event.apiValue, reason: reason));
    return const ManualAttendanceRequest(
      id: 'att_req_1',
      eventType: 'check_in',
      status: 'pending',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required StaffCheckOutcome outcome,
  void Function(StaffCheckEvent? attempted)? onManualRequest,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StaffCheckInCard(
          onRecord: (_) async => outcome,
          onManualRequest: onManualRequest ?? (_) {},
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('staff-check-in-button')));
  await tester.pumpAndSettle();
}

Future<void> _pumpDialog(
  WidgetTester tester,
  _FakeManualRequestDataSource datasource, {
  StaffCheckEvent? attempted,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AksharaAppTheme.light(),
      home: Scaffold(
        body: ManualRequestDialog(
          datasource: datasource,
          attempted: attempted,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('StaffCheckInCard — manual-request CTA matrix', () {
    testWidgets('locationBlocked shows the CTA and passes the attempted event',
        (tester) async {
      StaffCheckEvent? attempted;
      await _pumpCard(
        tester,
        outcome: StaffCheckOutcome.locationBlocked('too far'),
        onManualRequest: (event) => attempted = event,
      );
      final cta = find.byKey(const Key('manual-request-cta'));
      expect(cta, findsOneWidget);
      await tester.tap(cta);
      expect(attempted, StaffCheckEvent.checkIn);
    });

    testWidgets('faceBlocked shows the CTA', (tester) async {
      await _pumpCard(
        tester,
        outcome: StaffCheckOutcome.faceBlocked('no match'),
      );
      expect(find.byKey(const Key('manual-request-cta')), findsOneWidget);
    });

    testWidgets('failed (e.g. offline) shows the CTA', (tester) async {
      await _pumpCard(
        tester,
        outcome: StaffCheckOutcome.failed(StaffAttendanceOffline.userMessage),
      );
      expect(find.byKey(const Key('manual-request-cta')), findsOneWidget);
    });

    testWidgets('a recorded success NEVER shows the CTA', (tester) async {
      await _pumpCard(
        tester,
        outcome: StaffCheckOutcome.recorded(
          const StaffCheckRecord(
            id: 'chk_1',
            eventType: 'check_in',
            method: 'face_match',
          ),
        ),
      );
      expect(find.byKey(const Key('manual-request-cta')), findsNothing);
    });

    testWidgets('no callback wired → no CTA even when blocked', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffCheckInCard(
              onRecord: (_) async => StaffCheckOutcome.locationBlocked('far'),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('staff-check-in-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('manual-request-cta')), findsNothing);
    });
  });

  group('ManualRequestDialog', () {
    testWidgets('an already-pending request blocks a duplicate', (tester) async {
      final ds = _FakeManualRequestDataSource(existing: const [
        ManualAttendanceRequest(
          id: 'r1',
          eventType: 'check_in',
          status: 'pending',
        ),
      ]);
      await _pumpDialog(tester, ds);
      expect(
        find.byKey(const Key('manual-request-already-pending')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('manual-request-submit')), findsNothing);
    });

    testWidgets('a too-short reason is blocked client-side (server mirror)',
        (tester) async {
      final ds = _FakeManualRequestDataSource();
      await _pumpDialog(tester, ds);
      await tester.enterText(
        find.byKey(const Key('manual-request-reason')),
        'ab',
      );
      await tester.tap(find.byKey(const Key('manual-request-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('at least 3 characters'), findsOneWidget);
      expect(ds.created, isEmpty);
    });

    testWidgets(
        'submit sends the prefilled attempted event + reason and confirms '
        'pending approval', (tester) async {
      final ds = _FakeManualRequestDataSource();
      await _pumpDialog(tester, ds, attempted: StaffCheckEvent.checkOut);
      await tester.enterText(
        find.byKey(const Key('manual-request-reason')),
        'camera not working',
      );
      await tester.tap(find.byKey(const Key('manual-request-submit')));
      await tester.pumpAndSettle();

      expect(ds.created.single.event, 'check_out');
      expect(ds.created.single.reason, 'camera not working');
      expect(
        find.byKey(const Key('manual-request-submitted')),
        findsOneWidget,
      );
    });

    testWidgets('a server rejection surfaces on the form, not a crash',
        (tester) async {
      final ds = _FakeManualRequestDataSource(failCreate: true);
      await _pumpDialog(tester, ds);
      await tester.enterText(
        find.byKey(const Key('manual-request-reason')),
        'valid reason',
      );
      await tester.tap(find.byKey(const Key('manual-request-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('reason is required'), findsOneWidget);
      expect(find.byKey(const Key('manual-request-submit')), findsOneWidget);
    });
  });
}
