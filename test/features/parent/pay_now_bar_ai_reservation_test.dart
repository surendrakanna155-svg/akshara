// The Fees screen's sticky "Pay Now" bar must reserve the raised centre AI
// button's band.
//
// Found by looking at the running app while regenerating store screenshots: the
// AI FAB is docked directly above the bottom navigation and was sitting ON TOP
// of the Pay Now button — the one control on this screen that moves money.
//
// The reservation pattern already existed (BottomNavAiScope, and the payment
// screen's own CTA bar uses it); this bar was simply missed. Nothing asserted
// the property, so a screen could be added or changed without it and no test
// would notice. These tests assert the property itself, so the next fixed
// bottom bar that forgets it fails here.

import 'package:akshara_erp/features/copilot/widgets/bottom_nav_ai_scope.dart';
import 'package:akshara_erp/features/parent/fees/pay_now_bottom_bar.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {required double reserved}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AksharaAppTheme.light(),
      home: Scaffold(
        body: BottomNavAiScope(
          reservedHeight: reserved,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: PayNowBottomBar(amountDue: 4200, onPayNow: () {}),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('PayNowBottomBar reserves the AI button band', () {
    testWidgets('grows by exactly the reserved height', (tester) async {
      await _pump(tester, reserved: 0);
      final bare = tester.getSize(find.byType(PayNowBottomBar)).height;

      await _pump(tester, reserved: kBottomNavAiFabDiameter);
      final reserved = tester.getSize(find.byType(PayNowBottomBar)).height;

      expect(
        reserved - bare,
        kBottomNavAiFabDiameter,
        reason: 'the bar must reserve the whole band the FAB occupies',
      );
    });

    testWidgets('the Pay Now button clears the reserved band', (tester) async {
      // The property that actually matters: the FAB occupies the bottom
      // `kBottomNavAiFabDiameter` of this bar, so the CTA must sit entirely
      // above it. Asserting the button's rect (not just the bar's height)
      // means padding added in the wrong place still fails.
      await _pump(tester, reserved: kBottomNavAiFabDiameter);
      final barBottom = tester.getRect(find.byType(PayNowBottomBar)).bottom;
      final buttonBottom = tester.getRect(find.byType(FilledButton)).bottom;

      expect(
        buttonBottom,
        lessThanOrEqualTo(barBottom - kBottomNavAiFabDiameter),
        reason: 'Pay Now overlaps the band the AI button is drawn in',
      );
    });

    testWidgets('costs nothing where no AI button is drawn', (tester) async {
      // Full-screen routes have no bottom nav, so reserving there would just
      // add dead space under the CTA.
      await _pump(tester, reserved: 0);
      expect(
        tester.getSize(find.byType(PayNowBottomBar)).height,
        PayNowBottomBar.height,
      );
    });

    testWidgets('still renders the amount and the CTA', (tester) async {
      await _pump(tester, reserved: kBottomNavAiFabDiameter);
      expect(find.text('Amount due'), findsOneWidget);
      expect(find.text('Pay Now'), findsOneWidget);
    });
  });
}
