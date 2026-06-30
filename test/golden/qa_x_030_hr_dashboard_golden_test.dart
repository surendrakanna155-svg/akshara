@TestOn('mac-os')
library;

import 'package:akshara_erp/features/hr/dashboard/hr_dashboard_screen.dart';
import 'package:akshara_erp/features/hr/hr_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';

/// QW6 · QA-X-030 — Golden baseline for the HR dashboard (HR-01). The
/// management and intelligence dashboard goldens already exist (see
/// erp_dashboards_golden_test.dart); this pins the distinct HR surface
/// (headcount/attendance trend charts, pending-leave queue, recruitment
/// snapshot, management KPI note).
///
/// Dashboard data is loaded via `hrDashboardFutureProvider` against the demo
/// repository (`repositoryQueryProvider == demo` wired by
/// `pumpGoldenErpScreen`). The AI HR insight is baked into the dashboard data
/// model (no live AI provider / timer). Forcing the loading / error / empty
/// flags to a success state keeps the capture deterministic.
void main() {
  group('QA-X-030 · HR dashboard goldens', () {
    const prefix = 'qa_x_030_hr_dashboard';

    final stableOverrides = <Override>[
      hrDashboardLoadingProvider.overrideWith((ref) => false),
      hrDashboardErrorProvider.overrideWith((ref) => false),
      hrDashboardEmptyProvider.overrideWith((ref) => false),
    ];

    // Light mode across all three canonical viewports.
    for (final viewport in GoldenViewports.all) {
      testWidgets(
        'QA-X-030 $prefix renders at ${viewport.label}',
        (tester) async {
          await pumpGoldenErpScreen(
            tester,
            screen: const HrDashboardScreen(),
            viewport: viewport.size,
            extraOverrides: stableOverrides,
          );

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              goldenFileName(prefix, viewport.label),
            ),
          );
        },
      );
    }

    // Dark mode at the primary mobile viewport.
    testWidgets(
      'QA-X-030 $prefix renders in dark mode',
      (tester) async {
        await pumpGoldenErpScreen(
          tester,
          screen: const HrDashboardScreen(),
          viewport: GoldenViewports.mobile390,
          extraOverrides: stableOverrides,
          dark: true,
        );

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            goldenFileName('dark_$prefix', '390x844'),
          ),
        );
      },
    );
  });
}
