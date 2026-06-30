@TestOn('mac-os')
library;

import 'package:akshara_erp/features/admissions/enrollment/admissions_enrollment_provider.dart';
import 'package:akshara_erp/features/admissions/enrollment/admissions_enrollment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';

/// QW6 · QA-X-028 — Golden baseline for the admissions ENROLLMENT wizard
/// (AD-05), a multi-step `ConsumerStatefulWidget` driven by
/// `EnrollmentFormNotifier`. The admissions dashboard golden already exists
/// (see qw3_key_dashboards_golden_test.dart); this pins the multi-step
/// enrollment form's first step (Student profile) as it renders on fresh load.
///
/// The form is prefilled from `admissionsEnrollmentPrefillFutureProvider`, which
/// resolves against the demo repository (`repositoryQueryProvider == demo` wired
/// by `pumpGoldenErpScreen`). Forcing the prefill view-state to a non-loading /
/// non-error success state keeps the wizard's initial step deterministic.
void main() {
  group('QA-X-028 · admissions enrollment wizard goldens', () {
    const prefix = 'qa_x_028_admissions_enrollment';

    // Keep the prefill async view-state stable (success, non-loading) so the
    // wizard lands on its first step deterministically.
    final stableOverrides = <Override>[
      admissionsEnrollmentLoadingProvider.overrideWith((ref) => false),
      admissionsEnrollmentErrorProvider.overrideWith((ref) => false),
    ];

    // Light mode across all three canonical viewports.
    for (final viewport in GoldenViewports.all) {
      testWidgets(
        'QA-X-028 $prefix renders at ${viewport.label}',
        (tester) async {
          await pumpGoldenErpScreen(
            tester,
            screen: const AdmissionsEnrollmentScreen(),
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
      'QA-X-028 $prefix renders in dark mode',
      (tester) async {
        await pumpGoldenErpScreen(
          tester,
          screen: const AdmissionsEnrollmentScreen(),
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
