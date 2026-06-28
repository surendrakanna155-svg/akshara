@TestOn('mac-os')
library;

import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';

/// QW3 · QA-F-017 — parent dashboard golden across phone + tablet viewports in
/// DARK mode. The existing `parent_dashboard_golden_test.dart` only captured
/// the light theme; this adds the dark-mode dimension across the canonical
/// 390/428/834 viewports so a dark-theme regression is caught.
void main() {
  group('Parent Dashboard dark-mode golden tests', () {
    for (final viewport in GoldenViewports.all) {
      testWidgets('renders dark at ${viewport.label}', (tester) async {
        await pumpGoldenDashboard(
          tester,
          screen: const ParentDashboardScreen(),
          viewport: viewport.size,
          dark: true,
        );

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            goldenFileName('parent_dashboard_dark', viewport.label),
          ),
        );
      });
    }
  });
}
