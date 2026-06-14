import 'package:akshara_erp/features/sis/academic_operations/sis_promotion_screen.dart';
import 'package:akshara_erp/features/sis/academic_operations/sis_reshuffle_screen.dart';
import 'package:akshara_erp/features/sis/academic_operations/sis_section_balance_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

void main() {
  Future<void> pumpSisWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: erpWidgetTestOverrides(),
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: child,
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('Promotion screen renders wizard and mappings', (tester) async {
    await pumpSisWidget(tester, const SisPromotionScreen());
    expect(find.text('Promotion wizard'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsWidgets);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('Reshuffle screen renders strategy and execute action', (tester) async {
    await pumpSisWidget(tester, const SisReshuffleScreen());
    expect(find.text('Student reshuffle'), findsOneWidget);
    expect(find.text('Execute reshuffle'), findsOneWidget);
  });

  testWidgets('Section balance screen renders tabs', (tester) async {
    await pumpSisWidget(tester, const SisSectionBalanceScreen());
    expect(find.text('Section Balance'), findsWidgets);
    expect(find.text('Quarterly'), findsOneWidget);
    expect(find.text('Performance'), findsOneWidget);
  });
}
