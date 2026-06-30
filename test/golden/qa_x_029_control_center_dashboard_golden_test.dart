@TestOn('mac-os')
library;

import 'package:akshara_erp/features/platform/control_center/control_center_providers.dart';
import 'package:akshara_erp/features/platform/control_center/dashboard/control_center_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';

/// QW6 · QA-X-029 — Golden baseline for the CONTROL CENTER dashboard (ACC-01),
/// the platform-level multi-school overview. The director dashboard golden
/// already exists (see qw3_key_dashboards_golden_test.dart); this pins the
/// distinct control-center dashboard surface (platform KPIs, growth/MRR trend
/// charts, plan distribution, ERP module adoption).
///
/// Dashboard data is loaded via `controlCenterDashboardFutureProvider` against
/// the demo repository (`repositoryQueryProvider == demo` wired by
/// `pumpGoldenErpScreen`). The AI platform insight is baked into the dashboard
/// data model (no live AI provider / timer). Forcing the loading / error / empty
/// flags to a success state keeps the capture deterministic.
void main() {
  group('QA-X-029 · control center dashboard goldens', () {
    const prefix = 'qa_x_029_control_center_dashboard';

    final stableOverrides = <Override>[
      controlCenterDashboardLoadingProvider.overrideWith((ref) => false),
      controlCenterDashboardErrorProvider.overrideWith((ref) => false),
      controlCenterDashboardEmptyProvider.overrideWith((ref) => false),
    ];

    // Light mode across all three canonical viewports.
    for (final viewport in GoldenViewports.all) {
      testWidgets(
        'QA-X-029 $prefix renders at ${viewport.label}',
        (tester) async {
          await pumpGoldenErpScreen(
            tester,
            screen: const ControlCenterDashboardScreen(),
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
      'QA-X-029 $prefix renders in dark mode',
      (tester) async {
        await pumpGoldenErpScreen(
          tester,
          screen: const ControlCenterDashboardScreen(),
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
