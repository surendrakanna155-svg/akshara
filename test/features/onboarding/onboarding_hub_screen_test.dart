import 'package:akshara_erp/core/widgets/whatsapp_contact_button.dart';
import 'package:akshara_erp/features/onboarding/onboarding_hub_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// #10 gap-remediation — `OnboardingHubScreen`'s invite action must be real
/// (not the old hardcoded-demo-data button) and status must stay honest:
/// creating an invite only ever generates a link ('pending'); it flips to
/// 'sent' ONLY after a confirmed WhatsApp launch (whatsapp_launcher.dart's
/// `onSent` pattern via `WhatsAppContactButton`), never at creation time.
Future<void> _pump(WidgetTester tester) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const OnboardingHubScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('#10 · OnboardingHubScreen real invite action', () {
    testWidgets('starts with no invites and the real invite action visible',
        (tester) async {
      await _pump(tester);

      expect(find.text('Invite parent / teacher / student'), findsOneWidget);
      expect(find.text('No invites yet.'), findsOneWidget);
      // The old hardcoded-demo-data button must be gone.
      expect(find.text('Send demo parent invite'), findsNothing);
    });

    testWidgets('the invite form rejects an empty name and an invalid phone',
        (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Invite parent / teacher / student'));
      await tester.pumpAndSettle();

      expect(find.text('Invite someone'), findsOneWidget);
      await tester.tap(find.text('Generate invite link'));
      await tester.pumpAndSettle();
      expect(find.text('Name is required'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Demo Parent');
      await tester.enterText(find.widgetWithText(TextField, 'Phone number'), '123');
      await tester.tap(find.text('Generate invite link'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a valid phone number (at least 10 digits)'),
        findsOneWidget,
      );
    });

    testWidgets(
        'creating an invite stays honestly "pending" (link generated, not sent)',
        (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Invite parent / teacher / student'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Demo Parent');
      await tester.enterText(
        find.widgetWithText(TextField, 'Phone number'),
        '9876500002',
      );
      await tester.tap(find.text('Generate invite link'));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Invite link generated'),
        findsOneWidget,
      );
      // Honest status: 'pending', never 'sent', until a real launch confirms.
      expect(find.textContaining('· pending'), findsOneWidget);
      expect(find.textContaining('· sent'), findsNothing);
      // A pending invite gets a real send action.
      expect(find.byType(WhatsAppContactButton), findsOneWidget);
    });

    testWidgets(
        'confirming a WhatsApp launch (onSent) flips the invite to sent and removes the send action',
        (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Invite parent / teacher / student'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Demo Parent');
      await tester.enterText(
        find.widgetWithText(TextField, 'Phone number'),
        '9876500002',
      );
      await tester.tap(find.text('Generate invite link'));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      final button = tester.widget<WhatsAppContactButton>(
        find.byType(WhatsAppContactButton),
      );
      // Drive the confirmed-launch callback directly (matches the
      // WhatsAppContactButton contract: onSent fires only once WhatsApp has
      // actually opened) rather than exercising the real url_launcher plugin.
      // (A prior "link generated" SnackBar may still be queued/showing at
      // this point, so the status text + button visibility — not a second
      // SnackBar — are the load-bearing assertions here.)
      await button.onSent!();
      await settleRiverpodFutures(tester);
      await tester.pump();

      expect(find.textContaining('· sent'), findsOneWidget);
      expect(find.textContaining('· pending'), findsNothing);
      expect(find.byType(WhatsAppContactButton), findsNothing);
    });
  });
}
