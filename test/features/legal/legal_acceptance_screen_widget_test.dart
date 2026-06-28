import 'package:akshara_erp/features/legal/legal_acceptance_screen.dart';
import 'package:akshara_erp/features/legal/legal_gate_provider.dart';
import 'package:akshara_erp/features/legal/legal_models.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW1 · QA-F-026 — LegalAcceptanceScreen render + the accept GATE, loading,
/// review/empty and submitting states. Complements `legal_gate_test.dart`
/// (which proves the redirect logic + a happy-path accept) and QA-J-062
/// (the gate redirect journey). Here we pump the screen with a deterministic
/// stub gate notifier so every visual state is asserted without the network.

const _privacy = LegalPolicy(
  key: 'privacy',
  title: 'Privacy Policy',
  version: '2.0',
  summary: 'How we handle your data.',
  path: '/privacy',
);

/// Fixed-state stand-in for [LegalGateController] — returns [_fixed] from build()
/// and never hits the network (so the screen's initState refresh is a no-op).
class _StubLegalGate extends LegalGateController {
  _StubLegalGate(this._fixed);

  final LegalGateState _fixed;
  bool accepted = false;

  @override
  LegalGateState build() => _fixed;

  @override
  Future<void> refresh() async {}

  @override
  Future<bool> acceptOutstanding() async {
    accepted = true;
    return true;
  }
}

Future<void> _pump(
  WidgetTester tester,
  LegalGateState state, {
  _StubLegalGate? stub,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        legalGateProvider.overrideWith(() => stub ?? _StubLegalGate(state)),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const LegalAcceptanceScreen(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  group('QA-F-026 · LegalAcceptanceScreen', () {
    testWidgets('blocked: renders outstanding policy + Accept gated behind the '
        'agree checkbox (disabled → enabled)', (tester) async {
      const blocked = LegalGateState(
        phase: LegalGatePhase.blocked,
        outstanding: [_privacy],
        policies: [_privacy],
      );
      await _pump(tester, blocked);

      // Enforcement title + the policy card render.
      expect(find.text('Before you continue'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);

      // Accept is DISABLED until the user ticks "I have read and agree".
      final acceptBefore = tester.widget<FilledButton>(
        find.byKey(LegalAcceptanceScreen.acceptButtonKey),
      );
      expect(acceptBefore.onPressed, isNull,
          reason: 'Accept must be disabled before agreeing');

      await tester.tap(find.byKey(LegalAcceptanceScreen.agreeCheckboxKey));
      await tester.pumpAndSettle();

      final acceptAfter = tester.widget<FilledButton>(
        find.byKey(LegalAcceptanceScreen.acceptButtonKey),
      );
      expect(acceptAfter.onPressed, isNotNull,
          reason: 'Accept must enable once the box is ticked');
    });

    testWidgets('blocked: tapping Accept (after agreeing) records acceptance',
        (tester) async {
      final stub = _StubLegalGate(
        const LegalGateState(
          phase: LegalGatePhase.blocked,
          outstanding: [_privacy],
          policies: [_privacy],
        ),
      );
      await _pump(tester, stub._fixed, stub: stub);

      await tester.tap(find.byKey(LegalAcceptanceScreen.agreeCheckboxKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LegalAcceptanceScreen.acceptButtonKey));
      await tester.pumpAndSettle();

      expect(stub.accepted, isTrue);
    });

    testWidgets('submitting: Accept shows a spinner and the checkbox is locked',
        (tester) async {
      const submitting = LegalGateState(
        phase: LegalGatePhase.blocked,
        outstanding: [_privacy],
        policies: [_privacy],
        submitting: true,
      );
      await _pump(tester, submitting, settle: false);

      // Spinner inside the accept button; button + checkbox both disabled.
      expect(
        find.descendant(
          of: find.byKey(LegalAcceptanceScreen.acceptButtonKey),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      final accept = tester.widget<FilledButton>(
        find.byKey(LegalAcceptanceScreen.acceptButtonKey),
      );
      expect(accept.onPressed, isNull);
      final checkbox = tester.widget<CheckboxListTile>(
        find.byKey(LegalAcceptanceScreen.agreeCheckboxKey),
      );
      expect(checkbox.onChanged, isNull);
    });

    testWidgets('loading: shows a progress indicator, no policy cards',
        (tester) async {
      const loading = LegalGateState(phase: LegalGatePhase.loading);
      await _pump(tester, loading, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(LegalAcceptanceScreen.acceptButtonKey), findsNothing);
    });

    testWidgets('review (satisfied): renders policies without the accept gate',
        (tester) async {
      const satisfied = LegalGateState(
        phase: LegalGatePhase.satisfied,
        policies: [_privacy],
      );
      await _pump(tester, satisfied);

      // Review-mode title + the policy; no enforcement checkbox/accept button.
      expect(find.text('Terms & Policies'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.byKey(LegalAcceptanceScreen.acceptButtonKey), findsNothing);
      expect(find.byKey(LegalAcceptanceScreen.agreeCheckboxKey), findsNothing);
    });

    testWidgets('review with nothing outstanding: shows the up-to-date message',
        (tester) async {
      const empty = LegalGateState(phase: LegalGatePhase.satisfied);
      await _pump(tester, empty);

      expect(
        find.textContaining('You are all up to date'),
        findsOneWidget,
      );
    });
  });
}
