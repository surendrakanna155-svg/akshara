@TestOn('mac-os')
library;

import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_screen.dart';
import 'package:akshara_erp/features/student_app/dashboard/student_dashboard_screen.dart';
import 'package:akshara_erp/theme/persona_accents.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';

/// DS V2 Phase 3 — flagship dashboard goldens. These render each migrated
/// dashboard under its persona theme at a TALL viewport so the *entire* screen
/// (not just the 844px fold) is captured — the standard dashboard goldens only
/// pin the viewport top, which can't verify below-the-fold flagship work
/// (rings, academic/progress cards, activity sections). Light + Dark.
void main() {
  const tall = Size(390, 2600);

  final dashboards = <({String name, Widget screen, Color accent})>[
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
  ];

  for (final d in dashboards) {
    for (final mode in const [
      (label: 'light', dark: false),
      (label: 'dark', dark: true),
    ]) {
      testWidgets('${d.name} flagship dashboard · ${mode.label}',
          (tester) async {
        await pumpGoldenDashboard(
          tester,
          screen: d.screen,
          viewport: tall,
          personaAccent: d.accent,
          dark: mode.dark,
        );

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            goldenFileName('ds_v2_flagship_${d.name}_${mode.label}', '390x2600'),
          ),
        );
      });
    }
  }
}
