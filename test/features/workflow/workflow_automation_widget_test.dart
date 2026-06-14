import 'package:akshara_erp/features/workflow/workflow_automation_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

void main() {
  testWidgets('workflow automation screen renders required tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: erpWidgetTestOverrides(),
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const WorkflowAutomationScreen(),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();

    expect(find.text('Workflow Automation Platform'), findsOneWidget);
    expect(find.text('Rules'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Escalations'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
  });
}
