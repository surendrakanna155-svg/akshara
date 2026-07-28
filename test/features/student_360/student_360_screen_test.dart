import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/student_360/student_360_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

Future<void> _pumpStudent360(WidgetTester tester) async {
  // Tall viewport so a meaningful slice of the single scroll is laid out; the
  // page is deliberately one list, so anything far down is reached by scrolling
  // rather than by tapping a tab.
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
        home: const Student360Screen(studentId: 'SIS-STU-10430'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Student360Screen — single-screen parent-meeting dossier', () {
    testWidgets('opens on identity, care alert and parent contacts without any '
        'navigation', (tester) async {
      await _pumpStudent360(tester);

      // The principal must have the child, the urgent flag and the phone number
      // in front of them the moment the screen opens — no tab, no second page.
      expect(find.byKey(QaTestKeys.student360TabBar), findsOneWidget);
      expect(find.text('Arjun Reddy'), findsOneWidget);
      expect(find.textContaining('Severe peanut allergy'), findsOneWidget);
      expect(find.text('Venkat Reddy'), findsOneWidget);
      expect(find.textContaining('98490 11234'), findsOneWidget);
    });

    testWidgets('identifiers a principal searches by are on the header',
        (tester) async {
      await _pumpStudent360(tester);

      // ERP (admission) number and the unique student ID — the two things a
      // parent quotes on the phone.
      expect(find.textContaining('ADM-2024-001'), findsOneWidget);
      expect(find.textContaining('STU-001'), findsOneWidget);
    });

    testWidgets('headline numbers are readable in the first screenful',
        (tester) async {
      await _pumpStudent360(tester);

      // The headline strip repeats values that also appear in the detail
      // sections below, so these are findsWidgets, not findsOneWidget.
      expect(find.text('84%'), findsWidgets); // attendance
      expect(find.text('₹5000'), findsWidgets); // fees due
      expect(find.text('high'), findsWidgets); // risk
    });

    testWidgets('leave history and transport are present on the same scroll',
        (tester) async {
      await _pumpStudent360(tester);

      await tester.scrollUntilVisible(
        find.text('Leave history'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Leave history'), findsOneWidget);
      expect(find.textContaining('Viral fever'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Transport'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Route 12'), findsOneWidget);
      expect(find.textContaining('TS09 AB 4521'), findsOneWidget);
    });

    testWidgets('NEVER renders clinical health detail — care alerts only',
        (tester) async {
      // Guards the owner decision of 2026-07-15: diagnoses, medication and
      // treatment notes must not reach this broad profile surface. If someone
      // later wires the clinical tables into Student 360, this fails.
      await _pumpStudent360(tester);

      for (final forbidden in [
        'Diagnosis',
        'Medication',
        'Treatment',
        'Prescription',
        'Clinical',
      ]) {
        expect(
          find.textContaining(forbidden),
          findsNothing,
          reason: '"$forbidden" is clinical health detail and must never '
              'appear on Student 360 — care alerts only',
        );
      }
    });
  });
}
