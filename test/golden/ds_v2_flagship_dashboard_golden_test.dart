@TestOn('mac-os')
library;

import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_screen.dart';
import 'package:akshara_erp/theme/persona_accents.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';

/// DS V2 Phase 3 — flagship dashboard goldens. These render each migrated
/// dashboard under its persona theme at a TALL viewport so the *entire* screen
/// (not just the 844px fold) is captured — the standard dashboard goldens only
/// pin the viewport top, which can't verify below-the-fold flagship work
/// (rings, academic cards, activity sections). Light + Dark.
void main() {
  const tall = Size(390, 2600);

  for (final mode in const [
    (label: 'light', dark: false),
    (label: 'dark', dark: true),
  ]) {
    testWidgets('Parent flagship dashboard · ${mode.label}', (tester) async {
      await pumpGoldenDashboard(
        tester,
        screen: const ParentDashboardScreen(),
        viewport: tall,
        personaAccent: AksharaPersonaAccent.parent,
        dark: mode.dark,
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          goldenFileName('ds_v2_flagship_parent_${mode.label}', '390x2600'),
        ),
      );
    });
  }
}
