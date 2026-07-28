import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/adaptive_ai/adaptive_ai_providers.dart';
import 'package:akshara_erp/features/hr/hr_models.dart';
import 'package:akshara_erp/features/hr/staff_360/staff_360_screen.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/router/staff360_navigation.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: providerTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const Staff360Screen(employeeId: 'HR-EMP-101'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Staff360Screen — one-screen employee dossier', () {
    testWidgets('renders as a single scroll, not a tabbed record', (tester) async {
      await _pump(tester);
      expect(find.byKey(QaTestKeys.staff360Body), findsOneWidget);
      expect(find.byType(TabBar), findsNothing,
          reason: 'Staff 360 is one scroll — the same contract as Student 360');
    });

    testWidgets('shows the sections a principal opens it for', (tester) async {
      await _pump(tester);
      for (final section in ['Contact', 'Employment']) {
        expect(find.text(section), findsOneWidget, reason: section);
      }
    });

    testWidgets('empty sections say so rather than vanish', (tester) async {
      // Honest-state doctrine: a principal must be able to tell "nothing
      // recorded" apart from "this school does not track that".
      await _pump(tester);
      await tester.scrollUntilVisible(
        find.text('Documents'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Documents'), findsOneWidget);
    });
  });

  group('staff search routing', () {
    test('a staff result opens Staff 360 for roles holding viewHr', () {
      expect(
        adaptiveSearchRoute('staff', 'emp_1',
            hasPermission: (p) => p == Permission.viewHr),
        staff360Path('emp_1'),
      );
    });

    test('without viewHr it falls back to the HR record, never Access Denied',
        () {
      expect(
        adaptiveSearchRoute('staff', 'emp_1',
            hasPermission: (p) => p != Permission.viewHr),
        RouteNames.hrEmployeeDetail('emp_1'),
      );
      expect(
        adaptiveSearchRoute('staff', 'emp_1'),
        RouteNames.hrEmployeeDetail('emp_1'),
      );
    });
  });

  group('HR enum labels', () {
    test('never render raw camelCase to a user', () {
      // These used to reach the screen as `.name` — "onLeave", "halfDay".
      expect(HrEmployeeStatus.onLeave.label, 'On leave');
      expect(HrAttendanceStatus.halfDay.label, 'Half day');
      expect(HrDepartment.hr.label, 'HR');
      expect(HrEmployeeRole.admin.label, 'Administrator');
      expect(HrLeaveType.earned.label, 'Earned');

      for (final s in HrEmployeeStatus.values) {
        expect(s.label, isNot(contains(RegExp(r'[a-z][A-Z]'))), reason: s.name);
      }
      for (final s in HrAttendanceStatus.values) {
        expect(s.label, isNot(contains(RegExp(r'[a-z][A-Z]'))), reason: s.name);
      }
    });
  });
}
