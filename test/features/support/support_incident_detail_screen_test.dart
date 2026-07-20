import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/support/support_incident_detail_screen.dart';
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
  testWidgets('SupportIncidentDetailScreen renders header, conversation and reply box',
      (tester) async {
    _usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: erpWidgetTestOverrides([
          supportRepositoryProvider
              .overrideWithValue(FakeSupportRepository(detail: sampleDetail())),
        ]),
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const SupportIncidentDetailScreen(incidentId: 'i1'),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(QaTestKeys.supportIncidentDetailScreen), findsOneWidget);
    expect(find.text('Cannot open marks'), findsOneWidget);
    // support message body is shown; the reply affordance is present
    expect(find.text('looking into it'), findsOneWidget);
    expect(find.text('Akshara Support'), findsOneWidget);
    expect(find.byKey(QaTestKeys.supportReplyField), findsOneWidget);
    expect(find.byKey(QaTestKeys.supportReplySendButton), findsOneWidget);
  });
}
