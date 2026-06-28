// Mocks the url_launcher platform interface (a transitive plugin package) so
// the policy "View full policy" launch can be asserted offline. These imports
// are intentionally on transitive plugin-interface packages.
// ignore_for_file: depend_on_referenced_packages
import 'package:akshara_erp/core/legal/legal_links.dart';
import 'package:akshara_erp/features/legal/legal_acceptance_screen.dart';
import 'package:akshara_erp/features/legal/legal_gate_provider.dart';
import 'package:akshara_erp/features/legal/legal_models.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// QW3 · QA-F-027 — Legal: review/download a policy document + Continue gating.
/// The QW1 test (`legal_acceptance_screen_widget_test.dart`) covers the accept
/// gate. This adds: tapping "View full policy" opens the hosted policy document
/// (via `LegalLinks.openPolicyPath` → url_launcher) and confirms the Accept
/// ("Continue") button stays gated behind the agree checkbox.

const _privacy = LegalPolicy(
  key: 'privacy',
  title: 'Privacy Policy',
  version: '2.0',
  summary: 'How we handle your data.',
  path: '/privacy',
);

/// Records url_launcher calls so we can assert the policy document was opened.
class _FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final List<String> launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

/// Fixed-state stand-in for the gate controller (no network).
class _StubLegalGate extends LegalGateController {
  _StubLegalGate(this._fixed);

  final LegalGateState _fixed;

  @override
  LegalGateState build() => _fixed;

  @override
  Future<void> refresh() async {}
}

Future<void> _pump(WidgetTester tester, LegalGateState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        legalGateProvider.overrideWith(() => _StubLegalGate(state)),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const LegalAcceptanceScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late UrlLauncherPlatform original;
  late _FakeUrlLauncher fake;

  setUp(() {
    original = UrlLauncherPlatform.instance;
    fake = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = fake;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = original;
  });

  group('QA-F-027 · Legal review/download policy document', () {
    testWidgets('tapping View full policy opens the hosted policy document',
        (tester) async {
      const review = LegalGateState(
        phase: LegalGatePhase.satisfied,
        policies: [_privacy],
      );
      await _pump(tester, review);

      // Review mode renders the policy card with the "View full policy" CTA.
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('View full policy'), findsOneWidget);

      await tester.tap(find.text('View full policy'));
      await tester.pumpAndSettle();

      // The hosted document URL for the policy path was launched.
      expect(fake.launched, isNotEmpty);
      expect(fake.launched.single, LegalLinks.urlForPath(_privacy.path));
      // No "available online soon" fallback snackbar (the open succeeded).
      expect(find.textContaining('available online soon'), findsNothing);
    });

    testWidgets('blocked: Continue (Accept) stays gated behind the agree box, '
        'and the policy is still reviewable', (tester) async {
      const blocked = LegalGateState(
        phase: LegalGatePhase.blocked,
        outstanding: [_privacy],
        policies: [_privacy],
      );
      await _pump(tester, blocked);

      // The document is reviewable in enforcement mode too.
      await tester.tap(find.text('View full policy'));
      await tester.pumpAndSettle();
      expect(fake.launched, isNotEmpty);

      // Continue/accept is DISABLED until the agree checkbox is ticked.
      final before = tester.widget<FilledButton>(
        find.byKey(LegalAcceptanceScreen.acceptButtonKey),
      );
      expect(before.onPressed, isNull,
          reason: 'Accept must be gated before agreeing');

      await tester.tap(find.byKey(LegalAcceptanceScreen.agreeCheckboxKey));
      await tester.pumpAndSettle();

      final after = tester.widget<FilledButton>(
        find.byKey(LegalAcceptanceScreen.acceptButtonKey),
      );
      expect(after.onPressed, isNotNull,
          reason: 'Accept enables once the agree box is ticked');
    });
  });
}
