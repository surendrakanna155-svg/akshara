@TestOn('mac-os')
library;

import 'package:akshara_erp/core/attendance/attendance_correction_models.dart';
import 'package:akshara_erp/core/attendance/attendance_correction_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_attendance_correction_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_attendance_office_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_school_calendar_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/evolution/principal_command_screen.dart';
import 'package:akshara_erp/features/management/attendance/attendance_corrections_admin_screen.dart';
import 'package:akshara_erp/features/management/attendance/office_attendance_screen.dart';
import 'package:akshara_erp/features/management/school_calendar/school_calendar_models.dart';
import 'package:akshara_erp/features/management/school_calendar/school_calendar_providers.dart';
import 'package:akshara_erp/features/management/school_calendar/school_calendar_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/persona_accents.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';
import 'golden_test_helpers.dart';

/// DS V2 Phase 4 — flagship goldens for the Principal (school-leadership) MODULE
/// journey (beyond the MG-01 dashboard, done in Phase 3). Each of the four
/// STANDALONE-Scaffold leadership screens is rendered under the Admin/Principal
/// persona theme (indigo) at a leadership-oriented viewport, Light + Dark, so the
/// premium-canvas migration (persona canvas + the principal-command signature
/// ring) is captured while every RBAC gate, export flow, maker-checker/approval
/// path and honest-state banner stays intact.
///
/// The seven scaffold-routed module screens (academics/analytics/finance/
/// performance/admissions/tasks/settings + the approval center) already route
/// through the premium `AksharaDashboardCanvas` via `ManagementModuleScaffold`
/// and needed no change — they are covered by their existing tests + the
/// approval-center golden, so they are intentionally not re-pinned here.
void main() {
  // Wider than a 390px phone so these desktop-oriented leadership screens read
  // faithfully, but still ≤ mobileMax (767) so the clean card layouts render.
  const leadership = Size(600, 1400);

  Future<void> pump(
    WidgetTester tester, {
    required Widget screen,
    required bool dark,
    List<Override> overrides = const [],
  }) async {
    suppressGoldenOverflowErrors();
    useGoldenViewport(tester, leadership);
    await initProviderTestPrefs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: erpWidgetTestOverrides(overrides),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AksharaAppTheme.persona(
            brightness: dark ? Brightness.dark : Brightness.light,
            accent: AksharaPersonaAccent.admin,
          ),
          home: screen,
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  }

  for (final mode in const [
    (label: 'light', dark: false),
    (label: 'dark', dark: true),
  ]) {
    testWidgets('principal command · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const PrincipalCommandScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(PrincipalCommandScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_principal_command_${mode.label}', '600x1400'),
        ),
      );
    });

    testWidgets('office attendance · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const OfficeAttendanceScreen(),
        dark: mode.dark,
        overrides: [
          attendanceOfficeRepositoryProvider
              .overrideWithValue(const MockAttendanceOfficeRepository()),
          repositoryQueryProvider.overrideWith((ref) => RepositoryQuery.demo),
        ],
      );
      await expectLater(
        find.byType(OfficeAttendanceScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_office_attendance_${mode.label}', '600x1400'),
        ),
      );
    });

    testWidgets('attendance corrections · ${mode.label}', (tester) async {
      AttendanceCorrectionStore.instance.reset();
      AttendanceCorrectionStore.instance.create(
        const CreateAttendanceCorrectionRequest(
          sisStudentId: 'SIS-STU-10430',
          studentName: 'Arjun Reddy',
          classLabel: '8',
          section: 'A',
          dateLabel: '12 Jun 2026',
          fromMark: 'Absent',
          toMark: 'Present',
          reason: 'Biometric error',
          requesterId: 'teacher-1',
          requesterName: 'Priya Sharma',
          requesterRole: 'teacher',
        ),
      );
      await pump(
        tester,
        screen: const AttendanceCorrectionsAdminScreen(),
        dark: mode.dark,
        overrides: [
          attendanceCorrectionRepositoryProvider.overrideWithValue(
            MockAttendanceCorrectionRepository(
              store: AttendanceCorrectionStore.instance,
            ),
          ),
          repositoryQueryProvider.overrideWith((ref) => RepositoryQuery.demo),
        ],
      );
      await expectLater(
        find.byType(AttendanceCorrectionsAdminScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_attendance_corrections_${mode.label}',
              '600x1400'),
        ),
      );
    });

    testWidgets('school calendar · ${mode.label}', (tester) async {
      final store = SchoolCalendarMockStore.empty()
        ..create(
          CreateSchoolCalendarEventInput(
            eventDate: DateTime(2026, 1, 26),
            title: 'Republic Day',
            eventType: SchoolCalendarEventType.holiday,
          ),
        )
        ..create(
          CreateSchoolCalendarEventInput(
            eventDate: DateTime(2026, 3, 8),
            title: 'Annual Day',
            eventType: SchoolCalendarEventType.event,
          ),
        );
      await pump(
        tester,
        screen: const SchoolCalendarScreen(),
        dark: mode.dark,
        overrides: [
          schoolCalendarRepositoryProvider.overrideWithValue(
            MockSchoolCalendarRepository(store: store),
          ),
          repositoryQueryProvider.overrideWith((ref) => RepositoryQuery.demo),
          rbacServiceProvider.overrideWithValue(
            RbacService(UserPermissions.forRole(ErpRole.principal)),
          ),
        ],
      );
      await expectLater(
        find.byType(SchoolCalendarScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_school_calendar_${mode.label}', '600x1400'),
        ),
      );
    });
  }
}
