import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/features/copilot/dock/copilot_dock_provider.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

/// QW1 money loop (QA-J-001 / QA-J-060) — the parent pay-fee journey completed
/// end to end under the parent persona: Fees → Pay Now → payment summary →
/// Pay now → success, then the generated receipt is RETRIEVED by id on the
/// receipt detail screen. The receipt being loadable by the id the payment
/// returned is the persistence proof (the confirm call created + stored it).
void main() {
  patrolTest(
    'qw1-money: parent completes a fee payment and the receipt persists',
    config: aksharaPatrolConfig(),
    ($) async {
      // Hide the floating AI dock — it sits bottom-right over the pinned
      // "Pay now" CTA and would make it not hit-testable.
      await bootstrapAndLogin(
        $,
        QaLoginPersona.parent,
        extraOverrides: [copilotDockVisibleProvider.overrideWithValue(false)],
      );

      // Fees → Pay Now opens the payment summary (screen title "Pay Fee").
      await tapBottomNav($, 'Fees');
      await scrollTap($, 'Pay Now');
      await assertVisibleText($, 'Pay Fee');

      // Complete the payment (mock gateway → initiate → confirm). The "Pay now"
      // CTA lives in a fixed bottom bar that renders once the summary loads, so
      // a plain tap (waits-for-visible) is used rather than a scroll-to-tap.
      await $('Pay now').tap();
      await assertVisibleText($, 'Payment successful');

      // Persistence: the receipt is retrievable by the id the payment returned
      // (the success view shows "Receipt <number>" and links to its detail).
      await $('View receipt').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey($, QaTestKeys.parentReceiptDownloadButton);
    },
  );
}
