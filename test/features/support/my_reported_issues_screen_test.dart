import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/support/my_reported_issues_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';
import 'support_test_fakes.dart';

void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('MyReportedIssuesScreen lists the reporter\'s incidents', (tester) async {
    _usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: erpWidgetTestOverrides([
          supportRepositoryProvider
              .overrideWithValue(FakeSupportRepository(incidents: [sampleIncident()])),
        ]),
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const MyReportedIssuesScreen(),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(QaTestKeys.supportMyIssuesScreen), findsOneWidget);
    expect(find.byKey(QaTestKeys.supportReportIssueButton), findsOneWidget);
    expect(find.text('Cannot open marks'), findsOneWidget);
    expect(find.text('SUP-ABCD1234'), findsOneWidget);
  });

  testWidgets('MyReportedIssuesScreen shows an empty state with a call to report',
      (tester) async {
    _usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: erpWidgetTestOverrides([
          supportRepositoryProvider
              .overrideWithValue(FakeSupportRepository(incidents: const [])),
        ]),
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const MyReportedIssuesScreen(),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();

    expect(find.text('No reported issues'), findsOneWidget);
  });
}
