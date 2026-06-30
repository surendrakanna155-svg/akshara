@TestOn('mac-os')
library;

import 'package:akshara_erp/features/finance/collection_detail/finance_collection_detail_provider.dart';
import 'package:akshara_erp/features/finance/collection_detail/finance_collection_detail_screen.dart';
import 'package:akshara_erp/features/finance/collections/finance_collections_provider.dart';
import 'package:akshara_erp/features/finance/collections/finance_collections_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';

/// QW6 · QA-X-027 — Golden baselines for the finance COLLECTIONS list (FN-05)
/// and the COLLECTION DETAIL / receipt view (FN-06) across the three canonical
/// viewports plus a dark-mode capture. The finance dashboard golden already
/// exists (see erp_dashboards_golden_test.dart / qw3_key_dashboards_golden_test
/// .dart); this extends coverage to the two collections surfaces that had no
/// baseline.
///
/// Both screens render demo data via `repositoryQueryProvider == demo` (wired by
/// `pumpGoldenErpScreen`). The collection detail loads a deterministic demo
/// record by id (`col_1`, seeded in the mock finance repository). AI insight
/// copy on these screens is baked into the data models (no live AI provider /
/// timer), so renders settle deterministically.
void main() {
  group('QA-X-027 · finance collections goldens', () {
    // Pin the async view-state of both collections surfaces to a populated
    // success state (no loading / error / empty) for deterministic captures.
    final stableOverrides = <Override>[
      financeCollectionsLoadingProvider.overrideWith((ref) => false),
      financeCollectionsErrorProvider.overrideWith((ref) => false),
      financeCollectionsEmptyProvider.overrideWith((ref) => false),
      financeCollectionDetailLoadingProvider.overrideWith((ref) => false),
      financeCollectionDetailErrorProvider.overrideWith((ref) => false),
    ];

    const detailCollectionId = 'col_1';

    final cases = <({String prefix, Widget screen})>[
      (
        prefix: 'qa_x_027_finance_collections',
        screen: const FinanceCollectionsScreen(),
      ),
      (
        prefix: 'qa_x_027_finance_collection_detail',
        screen: const FinanceCollectionDetailScreen(
          collectionId: detailCollectionId,
        ),
      ),
    ];

    for (final testCase in cases) {
      // Light mode across all three canonical viewports.
      for (final viewport in GoldenViewports.all) {
        testWidgets(
          'QA-X-027 ${testCase.prefix} renders at ${viewport.label}',
          (tester) async {
            await pumpGoldenErpScreen(
              tester,
              screen: testCase.screen,
              viewport: viewport.size,
              extraOverrides: stableOverrides,
            );

            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                goldenFileName(testCase.prefix, viewport.label),
              ),
            );
          },
        );
      }

      // Dark mode at the primary mobile viewport.
      testWidgets(
        'QA-X-027 ${testCase.prefix} renders in dark mode',
        (tester) async {
          await pumpGoldenErpScreen(
            tester,
            screen: testCase.screen,
            viewport: GoldenViewports.mobile390,
            extraOverrides: stableOverrides,
            dark: true,
          );

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              goldenFileName('dark_${testCase.prefix}', '390x844'),
            ),
          );
        },
      );
    }
  });
}
