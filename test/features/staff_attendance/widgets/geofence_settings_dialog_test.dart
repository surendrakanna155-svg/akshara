// P0 remediation — GeofenceSettingsDialog: the configuration surface for the
// FIRST gate of the attendance chain. Covers:
//   1. the unconfigured state says so honestly (staff check-in IS blocked);
//   2. an existing config is loaded into the form (never silently discarded);
//   3. "Use my current location" fills the centre from a real fix, and REFUSES
//      a mock fix (a spoofed centre would poison the whole school's geofence);
//   4. save posts the composed config and confirms;
//   5. a server rejection lands on the form, not a crash.

import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/staff_attendance/attendance_capture_sources.dart';
import 'package:akshara_erp/features/staff_attendance/geofence_datasource.dart';
import 'package:akshara_erp/features/staff_attendance/staff_attendance_models.dart';
import 'package:akshara_erp/features/staff_attendance/widgets/geofence_settings_dialog.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_dio_interceptor.dart';

class _RecordingDataSource extends SchoolGeofenceDataSource {
  _RecordingDataSource({
    this.existing,
    this.readThrows = false,
    this.rejectWith,
  }) : super(
          dio: createFakeDio((_) => const {'data': <String, dynamic>{}}),
          query: RepositoryQuery.demo,
        );

  final SchoolGeofence? existing;
  final bool readThrows;
  final SchoolGeofenceRejected? rejectWith;
  SchoolGeofence? saved;

  @override
  Future<SchoolGeofence?> fetch() async {
    if (readThrows) throw DioException(requestOptions: RequestOptions());
    return existing;
  }

  @override
  Future<SchoolGeofence> save(SchoolGeofence geofence) async {
    final rejection = rejectWith;
    if (rejection != null) throw rejection;
    saved = geofence;
    return geofence;
  }
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required SchoolGeofenceDataSource datasource,
  AttendanceLocationSource? locationSource,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AksharaAppTheme.light(),
    home: Scaffold(
      body: GeofenceSettingsDialog(
        datasource: datasource,
        locationSource: locationSource,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an unconfigured school is told check-in stays blocked',
      (tester) async {
    await _pumpDialog(tester, datasource: _RecordingDataSource());

    expect(find.byKey(const Key('geofence-settings-unconfigured')), findsOneWidget);
    expect(find.byKey(const Key('geofence-settings-existing')), findsNothing);
  });

  testWidgets('an existing geofence is loaded into the form', (tester) async {
    await _pumpDialog(
      tester,
      datasource: _RecordingDataSource(
        existing: const SchoolGeofence(
          centerLatitude: 17.385,
          centerLongitude: 78.4867,
          radiusM: 200,
          maxAccuracyM: 35,
          maxLocationAgeS: 120,
        ),
      ),
    );

    expect(find.byKey(const Key('geofence-settings-existing')), findsOneWidget);
    expect(find.text('17.385'), findsOneWidget);
    expect(find.text('78.4867'), findsOneWidget);
    expect(find.text('35'), findsOneWidget);
  });

  testWidgets('a failed read warns instead of silently replacing the stored '
      'configuration', (tester) async {
    await _pumpDialog(
      tester,
      datasource: _RecordingDataSource(readThrows: true),
    );

    expect(find.byKey(const Key('geofence-settings-error')), findsOneWidget);
    // The form is still usable — a failed read must never dead-end the admin.
    expect(find.byKey(const Key('geofence-settings-save')), findsOneWidget);
  });

  testWidgets('"Use my current location" fills the centre from a real fix',
      (tester) async {
    final datasource = _RecordingDataSource();
    await _pumpDialog(
      tester,
      datasource: datasource,
      locationSource: FixedLocationSource(
        AttendanceLocationFix(
          latitude: 12.9716,
          longitude: 77.5946,
          accuracyM: 8,
          isMock: false,
          capturedAt: DateTime.utc(2026, 7, 28),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('geofence-use-current-location')));
    await tester.pumpAndSettle();

    expect(find.text('12.9716'), findsOneWidget);
    expect(find.text('77.5946'), findsOneWidget);
    expect(find.byKey(const Key('geofence-settings-notice')), findsOneWidget);
  });

  testWidgets('a MOCK fix is REFUSED as the school centre', (tester) async {
    await _pumpDialog(
      tester,
      datasource: _RecordingDataSource(),
      locationSource: FixedLocationSource(
        AttendanceLocationFix(
          latitude: 0.1,
          longitude: 0.1,
          accuracyM: 5,
          isMock: true,
          capturedAt: DateTime.utc(2026, 7, 28),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('geofence-use-current-location')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('geofence-settings-error')), findsOneWidget);
    expect(find.text('0.1'), findsNothing);
  });

  testWidgets('a location-capture failure is reported, manual entry still works',
      (tester) async {
    final datasource = _RecordingDataSource();
    await _pumpDialog(
      tester,
      datasource: datasource,
      locationSource: const DeviceAdapterPendingLocationSource(),
    );

    await tester.tap(find.byKey(const Key('geofence-use-current-location')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('geofence-settings-error')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('geofence-latitude')), '17.4');
    await tester.enterText(find.byKey(const Key('geofence-longitude')), '78.5');
    await tester.tap(find.byKey(const Key('geofence-settings-save')));
    await tester.pumpAndSettle();

    expect(datasource.saved, isNotNull);
    expect(find.byKey(const Key('geofence-settings-saved')), findsOneWidget);
  });

  testWidgets('save posts the composed config and confirms', (tester) async {
    final datasource = _RecordingDataSource();
    await _pumpDialog(tester, datasource: datasource);

    await tester.enterText(find.byKey(const Key('geofence-latitude')), '17.385');
    await tester.enterText(find.byKey(const Key('geofence-longitude')), '78.4867');
    await tester.enterText(find.byKey(const Key('geofence-accuracy')), '40');
    await tester.tap(find.byKey(const Key('geofence-settings-save')));
    await tester.pumpAndSettle();

    expect(datasource.saved, isNotNull);
    expect(datasource.saved!.centerLatitude, 17.385);
    expect(datasource.saved!.centerLongitude, 78.4867);
    expect(datasource.saved!.maxAccuracyM, 40);
    expect(datasource.saved!.radiusM, SchoolGeofence.defaultRadiusM);
    expect(find.byKey(const Key('geofence-settings-saved')), findsOneWidget);
  });

  testWidgets('empty coordinates are blocked before any write', (tester) async {
    final datasource = _RecordingDataSource();
    await _pumpDialog(tester, datasource: datasource);

    await tester.tap(find.byKey(const Key('geofence-settings-save')));
    await tester.pumpAndSettle();

    expect(datasource.saved, isNull);
    expect(find.byKey(const Key('geofence-settings-error')), findsOneWidget);
  });

  testWidgets('an out-of-range accuracy is blocked before any write',
      (tester) async {
    final datasource = _RecordingDataSource();
    await _pumpDialog(tester, datasource: datasource);

    await tester.enterText(find.byKey(const Key('geofence-latitude')), '17.385');
    await tester.enterText(find.byKey(const Key('geofence-longitude')), '78.4867');
    await tester.enterText(find.byKey(const Key('geofence-accuracy')), '900');
    await tester.tap(find.byKey(const Key('geofence-settings-save')));
    await tester.pumpAndSettle();

    expect(datasource.saved, isNull);
    expect(find.byKey(const Key('geofence-settings-error')), findsOneWidget);
  });

  testWidgets('a server rejection lands on the form, not a crash',
      (tester) async {
    await _pumpDialog(
      tester,
      datasource: _RecordingDataSource(
        rejectWith: const SchoolGeofenceRejected(
          'FORBIDDEN',
          'You do not have permission to change the school geofence.',
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('geofence-latitude')), '17.385');
    await tester.enterText(find.byKey(const Key('geofence-longitude')), '78.4867');
    await tester.tap(find.byKey(const Key('geofence-settings-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('geofence-settings-error')), findsOneWidget);
    expect(find.byKey(const Key('geofence-settings-saved')), findsNothing);
    expect(find.byKey(const Key('geofence-settings-save')), findsOneWidget);
  });
}
