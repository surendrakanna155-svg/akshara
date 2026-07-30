import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/support/domain/support_delivery_failure.dart';
import 'package:akshara_erp/features/support/support_incident_detail_screen.dart';
import 'package:akshara_erp/features/support/support_ui.dart';
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
    expect(find.text('NIKSHA Support'), findsOneWidget);
    expect(find.byKey(QaTestKeys.supportReplyField), findsOneWidget);
    expect(find.byKey(QaTestKeys.supportReplySendButton), findsOneWidget);
  });

  testWidgets(
      'a reply that did not reach support is not shown as sent — it says so '
      'and keeps the text', (tester) async {
    _usePhoneViewport(tester);
    final repo = FakeSupportRepository(
      detail: sampleDetail(),
      postMessageFailure: const SupportDeliveryFailure.notDelivered(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: erpWidgetTestOverrides([
          supportRepositoryProvider.overrideWithValue(repo),
        ]),
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const SupportIncidentDetailScreen(incidentId: 'i1'),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(QaTestKeys.supportReplyField),
      'Any update on this?',
    );
    await tester.pump();
    await tester.tap(find.byKey(QaTestKeys.supportReplySendButton));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repo.postMessageAttempts, 1);
    expect(find.byKey(kSupportReplyDeliveryFailureKey), findsOneWidget);
    expect(
      find.text(
        supportReplyFailureMessage(SupportDeliveryFailureReason.notDelivered),
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    // The composer still holds what they wrote…
    expect(find.text('Any update on this?'), findsOneWidget);
    // …and it was NOT rendered into the conversation as a delivered message.
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('Any update on this?'),
      ),
      findsNothing,
    );
  });

  testWidgets('a successful reply clears the composer and shows no error',
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

    await tester.enterText(
      find.byKey(QaTestKeys.supportReplyField),
      'Any update on this?',
    );
    await tester.pump();
    await tester.tap(find.byKey(QaTestKeys.supportReplySendButton));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(kSupportReplyDeliveryFailureKey), findsNothing);
    expect(find.text('Any update on this?'), findsNothing);
  });
}
