// Slice 3 — StaffCheckInCard's enrolment affordances:
//   1. a settings-style entry point (staff-attendance-manage-face-button),
//      always shown when a host wires onOpenEnrollment;
//   2. a targeted "Enrol my face" call-to-action
//      (staff-check-in-enrol-now-button) that appears ONLY after the server
//      rejects check-in specifically with FACE_NOT_ENROLLED
//      (StaffCheckOutcome.isNotEnrolled) — not for any other face-blocked
//      reason.
//
// Drives StaffCheckInCard directly via its onRecord callback (no controller/
// reliability stack needed) — mirrors staff_face_id_attendance_cert_test.dart's
// card-UI group, minus the parts that are already covered there.

import 'package:akshara_erp/features/staff_attendance/manual_attendance_request_providers.dart';
import 'package:akshara_erp/features/staff_attendance/staff_attendance_models.dart';
import 'package:akshara_erp/features/staff_attendance/widgets/staff_check_in_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpCard(
  WidgetTester tester, {
  required Future<StaffCheckOutcome> Function(StaffCheckEvent) onRecord,
  VoidCallback? onOpenEnrollment,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      canApproveManualAttendanceProvider.overrideWithValue(false),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: StaffCheckInCard(
          onRecord: onRecord,
          onOpenEnrollment: onOpenEnrollment,
        ),
      ),
    ),
  ));
}

void main() {
  group('StaffCheckInCard — face enrolment affordances', () {
    testWidgets(
        'the settings entry point is shown only when onOpenEnrollment is wired',
        (tester) async {
      Future<StaffCheckOutcome> record(StaffCheckEvent event) async =>
          StaffCheckOutcome.recorded(const StaffCheckRecord(
            id: 'chk_1',
            eventType: 'check_in',
            method: 'face_match',
          ));

      await _pumpCard(tester, onRecord: record);
      expect(
        find.byKey(const Key('staff-attendance-manage-face-button')),
        findsNothing,
      );

      var opened = false;
      await _pumpCard(tester, onRecord: record, onOpenEnrollment: () => opened = true);
      expect(
        find.byKey(const Key('staff-attendance-manage-face-button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('staff-attendance-manage-face-button')));
      expect(opened, isTrue);
    });

    testWidgets(
        'FACE_NOT_ENROLLED rejection shows the "Enrol my face" CTA, which opens enrolment',
        (tester) async {
      var opened = false;
      Future<StaffCheckOutcome> record(StaffCheckEvent event) async =>
          StaffCheckOutcome.faceBlocked(
            'No enrolled reference face — enrol your face before recording attendance',
            code: 'STAFF_ATTENDANCE_FACE_NOT_ENROLLED',
          );

      await _pumpCard(tester, onRecord: record, onOpenEnrollment: () => opened = true);

      expect(
        find.byKey(const Key('staff-check-in-enrol-now-button')),
        findsNothing,
        reason: 'no outcome yet',
      );

      await tester.tap(find.byKey(const Key('staff-check-in-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('staff-check-in-enrol-now-button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('staff-check-in-enrol-now-button')));
      expect(opened, isTrue);
    });

    testWidgets(
        'a different face-blocked reason (no-match) does NOT show the enrol CTA',
        (tester) async {
      Future<StaffCheckOutcome> record(StaffCheckEvent event) async =>
          StaffCheckOutcome.faceBlocked(
            'Face not verified',
            code: 'STAFF_ATTENDANCE_FACE_NO_MATCH',
          );

      await _pumpCard(tester, onRecord: record, onOpenEnrollment: () {});

      await tester.tap(find.byKey(const Key('staff-check-in-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff-check-status')), findsOneWidget);
      expect(
        find.byKey(const Key('staff-check-in-enrol-now-button')),
        findsNothing,
      );
    });

    testWidgets(
        'a location-blocked outcome does NOT show the enrol CTA',
        (tester) async {
      Future<StaffCheckOutcome> record(StaffCheckEvent event) async =>
          StaffCheckOutcome.locationBlocked('too far');

      await _pumpCard(tester, onRecord: record, onOpenEnrollment: () {});

      await tester.tap(find.byKey(const Key('staff-check-in-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('staff-check-in-enrol-now-button')),
        findsNothing,
      );
    });
  });
}
