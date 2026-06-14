import 'package:akshara_erp/features/continuity/continuity_migration_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

void main() {
  testWidgets('continuity migration screen renders actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: erpWidgetTestOverrides(),
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const ContinuityMigrationScreen(),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
    expect(find.text('Continuity migration wizard'), findsOneWidget);
    expect(find.text('Preview continuity'), findsOneWidget);
    expect(find.text('Execute continuity'), findsOneWidget);
  });
}
