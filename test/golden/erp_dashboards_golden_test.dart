@TestOn('mac-os')
library;

import 'package:akshara_erp/features/finance/dashboard/finance_dashboard_screen.dart';
import 'package:akshara_erp/features/inventory/dashboard/inventory_dashboard_screen.dart';
import 'package:akshara_erp/features/management/dashboard/management_dashboard_screen.dart';
import 'package:akshara_erp/features/management/intelligence/intelligence_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';

void main() {
  group('ERP dashboard golden tests', () {
    final cases = <({String prefix, Widget screen})>[
      (prefix: 'management_dashboard', screen: const ManagementDashboardScreen()),
      (prefix: 'finance_dashboard', screen: const FinanceDashboardScreen()),
      (prefix: 'inventory_dashboard', screen: const InventoryDashboardScreen()),
      (prefix: 'intelligence_dashboard', screen: const IntelligenceHubScreen()),
    ];

    for (final testCase in cases) {
      for (final viewport in GoldenViewports.all) {
        testWidgets(
          '${testCase.prefix} renders at ${viewport.label}',
          (tester) async {
            await pumpGoldenErpScreen(
              tester,
              screen: testCase.screen,
              viewport: viewport.size,
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
    }
  });
}
