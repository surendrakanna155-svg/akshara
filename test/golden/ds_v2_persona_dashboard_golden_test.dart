@TestOn('mac-os')
library;

import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_screen.dart';
import 'package:akshara_erp/features/student_app/dashboard/student_dashboard_screen.dart';
import 'package:akshara_erp/features/teacher/dashboard/teacher_dashboard_screen.dart';
import 'package:akshara_erp/theme/persona_accents.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';

/// DS V2 P2-5 — persona-themed dashboard goldens. The base dashboard goldens
/// render under `AksharaAppTheme.light()`; the real app wraps each dashboard in
/// its persona theme (persona-cohesive hero + accent chrome). These pin that
/// true experience — Parent=blue, Student=emerald, Teacher=indigo — so the
/// cumulative premium result (P2-1..P2-4) is captured on a real screen and a
/// persona-theming regression is caught deliberately.
void main() {
  const viewport = Size(390, 844);

  final personas = <({String name, Widget screen, Color accent})>[
    (
      name: 'parent',
      screen: const ParentDashboardScreen(),
      accent: AksharaPersonaAccent.parent,
    ),
    (
      name: 'student',
      screen: const StudentDashboardScreen(),
      accent: AksharaPersonaAccent.student,
    ),
    (
      name: 'teacher',
      screen: const TeacherDashboardScreen(),
      accent: AksharaPersonaAccent.teacher,
    ),
  ];

  group('DS V2 · persona-themed dashboards', () {
    for (final mode in const [
      (label: 'light', dark: false),
      (label: 'dark', dark: true),
    ]) {
      for (final persona in personas) {
        testWidgets('${persona.name} dashboard · ${mode.label} (persona theme)',
            (tester) async {
          await pumpGoldenDashboard(
            tester,
            screen: persona.screen,
            viewport: viewport,
            personaAccent: persona.accent,
            dark: mode.dark,
          );

          final suffix = mode.dark ? '_dark' : '';
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              goldenFileName(
                'ds_v2_persona_dashboard_${persona.name}$suffix',
                '390x844',
              ),
            ),
          );
        });
      }
    }
  });
}
