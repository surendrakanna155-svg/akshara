// The WIRING between StaffCheckInCard and GeofenceSettingsDialog.
//
// WHY THIS EXISTS. GeofenceSettingsDialog and SchoolGeofenceDataSource were
// built and thoroughly tested, and their entry point — the "Set school
// geofence" button on the check-in card, plus the two providers behind it —
// was silently reverted. Every test still passed, because they all drive the
// dialog and the datasource DIRECTLY. Nothing asserted that a real user could
// ever reach them, so a fully-built feature was reachable by nobody and the
// suite reported green.
//
// That is the "built, tested, never wired" pattern this project already has
// several instances of on the defect register. These tests close it for the
// geofence: they assert the affordance EXISTS on the card, is permission-gated,
// and actually opens the dialog.

import 'package:akshara_erp/features/staff_attendance/manual_attendance_request_providers.dart';
import 'package:akshara_erp/features/staff_attendance/staff_attendance_models.dart';
import 'package:akshara_erp/features/staff_attendance/staff_attendance_providers.dart';
import 'package:akshara_erp/features/staff_attendance/widgets/staff_check_in_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';

final _geofenceButton = find.byKey(const Key('staff-configure-geofence-button'));

// The card is never tapped for a check-in here; these tests are about the
// geofence affordance only.
Future<StaffCheckOutcome> _idle(StaffCheckEvent event) async =>
    StaffCheckOutcome.failed('not exercised');

Future<void> _pumpCard(
  WidgetTester tester, {
  required bool canConfigureGeofence,
  VoidCallback? onConfigureGeofence,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        canApproveManualAttendanceProvider.overrideWithValue(false),
        canConfigureSchoolGeofenceProvider
            .overrideWithValue(canConfigureGeofence),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: StaffCheckInCard(
            onRecord: _idle,
            onConfigureGeofence: onConfigureGeofence,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('geofence configuration is REACHABLE from the check-in card', () {
    testWidgets('a permitted supervisor sees the entry point', (tester) async {
      // The assertion the wipe would have failed. Without it, the dialog and
      // its datasource can be deleted from the UI entirely and every other
      // geofence test still passes.
      await _pumpCard(tester, canConfigureGeofence: true);
      expect(_geofenceButton, findsOneWidget);
      expect(find.text('Set school geofence'), findsOneWidget);
    });

    testWidgets('a staff member without the permission does NOT',
        (tester) async {
      await _pumpCard(tester, canConfigureGeofence: false);
      expect(_geofenceButton, findsNothing);
    });

    testWidgets('tapping it opens the configuration surface', (tester) async {
      // Uses the injection seam rather than the real dialog: the dialog itself
      // performs a network read on open, which is covered by its own test. What
      // is unproven elsewhere — and what broke — is that the TAP is connected.
      var opened = 0;
      await _pumpCard(
        tester,
        canConfigureGeofence: true,
        onConfigureGeofence: () => opened++,
      );
      await tester.tap(_geofenceButton);
      await tester.pump();
      expect(opened, 1);
    });
  });

  group('the gate is the one the server enforces', () {
    test('the provider exists and is overridable', () {
      // Pins the provider's identity. If it is renamed or deleted, this fails
      // at compile time rather than silently un-gating (or hiding) the button.
      final container = ProviderContainer(
        overrides: [
          canConfigureSchoolGeofenceProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(canConfigureSchoolGeofenceProvider), isTrue);
    });

    test('the datasource provider is wired and resolvable', () async {
      // The other half of the wiring: the card reads this on tap. A card that
      // renders a button which then throws on resolve is not "wired".
      // SharedPreferences is provided because the tenant/query graph behind the
      // datasource needs it — main() overrides it the same way.
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider
              .overrideWithValue(await SharedPreferences.getInstance()),
        ],
      );
      addTearDown(container.dispose);
      expect(
        () => container.read(schoolGeofenceDataSourceProvider),
        returnsNormally,
      );
    });
  });
}
