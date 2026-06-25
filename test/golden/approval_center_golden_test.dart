@TestOn('mac-os')
library;

import 'package:akshara_erp/features/management/approval/principal_approval_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/auth_test_overrides.dart';
import 'golden_test_helpers.dart';

void main() {
  group('Approval center golden tests', () {
    for (final viewport in GoldenViewports.all) {
      testWidgets(
        'principal_approval_center ${viewport.label}',
        (tester) async {
          await pumpGoldenErpScreen(
            tester,
            screen: const PrincipalApprovalCenterScreen(),
            viewport: viewport.size,
            extraOverrides: [
              authStateOverride(erpWidgetTestStaffAuth()),
            ],
          );

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              goldenFileName('approval_center', viewport.label),
            ),
          );
        },
      );
    }
  });
}
