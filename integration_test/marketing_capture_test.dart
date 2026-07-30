// Marketing screenshot capture — the real app, real fonts, real demo data.
//
// Run via `scripts/marketing/capture_shots.sh` (do not invoke directly — the
// script sets the device size that determines which layout tier renders).
//
// ---------------------------------------------------------------------------
// Why this is an `integration_test` and not a `patrolTest`
// ---------------------------------------------------------------------------
// Patrol has no screenshot API, and this repo's `capturePatrolScreenshot`
// returns early on Android/iOS after writing a `.marker` file — it records
// intent, never an image. Capture requires `IntegrationTestWidgetsFlutterBinding`
// so bytes can cross the driver channel to the host.
//
// `PatrolBinding` and `IntegrationTestWidgetsFlutterBinding` cannot both own the
// binding, so we keep `flutter_test` finders here and add small explicit waits
// rather than importing `patrol_finders`. Nothing about navigation needs Patrol:
// there are no native dialogs on any captured path.
//
// ---------------------------------------------------------------------------
// Honesty rules this file enforces mechanically
// ---------------------------------------------------------------------------
//  * `enableQaLogin: false` — the QA persona switcher paints a
//    "QA visual test — tap to switch persona" banner over every screen
//    (lib/features/auth/qa_visual_switcher.dart:53). A capture containing it
//    would misrepresent the shipping app.
//  * Demo auth only. Never the live pilot: `release/v1.0-playstore` HEAD
//    (commit 8050eda2) records confirmed unauthenticated exposure there.
//  * Every shot asserts an anchor widget is on screen BEFORE capturing, so a
//    failed navigation fails the run instead of silently shipping a wrong or
//    half-built screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:akshara_erp/app/app.dart';
import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:akshara_erp/core/school_config/school_configuration_provider.dart';
import 'package:akshara_erp/core/school_config/school_configuration_storage.dart';
import 'package:akshara_erp/core/security/server_permission_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/auth_provider.dart';
import 'package:akshara_erp/features/auth/auth_token_provider.dart';

/// Demo auth ON (testing-account chips + mock OTP), QA persona switcher OFF.
///
/// `Environment.development` already has `disableDemoAuth: false` and
/// `enableQaLogin: false`; logging is turned off so captures are not taken while
/// the console is busy.
const Environment kMarketingEnvironment = Environment(
  name: EnvironmentName.development,
  apiBaseUrl: 'http://localhost:8080/v1',
  enableApiMode: false,
  enableLogging: false,
);

/// Mock OTP accepted by the demo auth path (`kMockValidOtp`).
const String kDemoOtp = '123456';

/// Full demo capabilities, so module lists are not silently short.
class _MarketingSchoolConfiguration extends SchoolConfigurationNotifier {
  @override
  SchoolConfiguration build() => SchoolConfiguration.demoDefault();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // `convertFlutterSurfaceToImage` must be called once PER TEST. The binding
  // tears the converted surface down between tests, so a process-wide "already
  // converted" flag makes every test after the first fail with
  // "Call convertFlutterSurfaceToImage() before taking a screenshot" — while the
  // first one still succeeds, which is exactly how this hid at first.
  // Calling it twice inside one test also throws, hence the per-test flag.
  var surfaceConverted = false;
  setUp(() => surfaceConverted = false);

  Future<void> capture(WidgetTester tester, String name) async {
    if (!surfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      surfaceConverted = true;
    }
    await settle(tester);
    await binding.takeScreenshot(name);
  }

  /// Boots the app with marketing overrides and a cleared, deterministic store.
  Future<void> bootstrap(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    // A capture run must not inherit the previous run's session or dismissed
    // banners — otherwise shot N depends on whether shot N-1 ran.
    await prefs.clear();
    await prefs.remove(kServerPermissionSnapshotKey);

    // The session does NOT live in SharedPreferences — `AuthSessionStorage`
    // writes it to the platform secure store (Android Keystore), which survives
    // `prefs.clear()`, app restarts and the whole test process. Without this the
    // app silently restores the previous persona and every shot after the first
    // captures the wrong workspace.
    final reset = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        environmentProvider.overrideWithValue(kMarketingEnvironment),
      ],
    );
    await reset.read(authSessionStorageProvider).clear();
    await reset.read(tokenStorageProvider).clear();
    reset.dispose();

    await SchoolConfigurationStorage(prefs).write(
      SchoolConfiguration.demoDefault(),
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        environmentProvider.overrideWithValue(kMarketingEnvironment),
        schoolConfigurationProvider.overrideWith(
          _MarketingSchoolConfiguration.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AksharaApp(),
      ),
    );
    await settle(tester);
  }

  /// Demo login: testing-account chip → Continue → mock OTP → Verify.
  Future<void> signIn(WidgetTester tester, TestingLoginAccount account) async {
    await waitFor(tester, find.byKey(QaTestKeys.loginPhoneField));
    await tapVisible(tester, find.widgetWithText(ChoiceChip, account.label));
    await tapVisible(tester, find.byKey(QaTestKeys.loginContinueButton));

    final otpField = find.byKey(QaTestKeys.otpField);
    await waitFor(tester, otpField);
    await tester.enterText(otpField, kDemoOtp);
    await settle(tester);

    // The OTP screen sometimes submits itself once six digits are entered and
    // sometimes waits for the button, so neither "always tap" nor "tap if
    // present right now" is correct:
    //   · always tap      -> stalls 40s when the screen already advanced
    //   · tap if present  -> races the rebuild after enterText, skips the tap,
    //                        and sits on the OTP screen forever
    // Both failure modes were observed. Poll for whichever happens first.
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      if (find.byKey(QaTestKeys.otpField).evaluate().isEmpty) break; // advanced
      final verify = find.byKey(QaTestKeys.otpVerifyButton);
      if (verify.evaluate().isNotEmpty) {
        await tapVisible(tester, verify);
        break;
      }
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  // -------------------------------------------------------------------------
  // Shots
  //
  // `anchor` is asserted before the capture. It must be text that only appears
  // once the intended screen has actually rendered its content — not a nav label
  // that is present during loading too.
  // -------------------------------------------------------------------------

  for (final shot in kPersonaShots) {
    testWidgets('capture: ${shot.name}', (tester) async {
      await bootstrap(tester);
      await signIn(tester, resolveAccount(shot.account));
      await waitFor(tester, find.text(shot.anchor));
      await capture(tester, shot.name);
    });
  }

  testWidgets('capture: sign-in screen', (tester) async {
    await bootstrap(tester);
    await waitFor(tester, find.byKey(QaTestKeys.loginPhoneField));
    await capture(tester, 'sign-in');
  });
}

/// A screen worth publishing, and the text that proves it rendered.
class MarketingShot {
  const MarketingShot({
    required this.name,
    required this.account,
    required this.anchor,
  });

  /// Output filename stem. Kept stable — the website references these.
  final String name;

  /// Which demo persona to sign in as — the `label` of an entry in the app's own
  /// [kTestingLoginAccounts]. Resolved at runtime rather than duplicated here,
  /// so if the app's demo accounts change the harness follows instead of
  /// silently drifting.
  final String account;

  /// Text that must be visible before the shutter fires.
  final String anchor;
}

/// Looks up a demo account by its chip label, failing loudly if it is gone.
TestingLoginAccount resolveAccount(String label) {
  return kTestingLoginAccounts.firstWhere(
    (a) => a.label == label,
    orElse: () => throw StateError(
      'No demo account labelled "$label". kTestingLoginAccounts now offers: '
      '${kTestingLoginAccounts.map((a) => a.label).join(", ")}.',
    ),
  );
}

/// Landing screen per persona. Deeper journeys are added once these are proven
/// green at every layout tier — a shot list is only useful if it is repeatable.
const List<MarketingShot> kPersonaShots = [
  // The principal does NOT land on a "Dashboard" — the staff/principal entry
  // point is the Admin Hub workspace (students / staff / attendance summary and
  // the authorised-module list). Discovered from the harness's own timeout dump.
  MarketingShot(
    name: 'principal-admin-hub',
    account: 'Principal',
    anchor: 'Admin Hub',
  ),
  MarketingShot(
    name: 'teacher-dashboard',
    account: 'Teacher',
    anchor: 'Dashboard',
  ),
  MarketingShot(
    name: 'parent-dashboard',
    account: 'Parent',
    anchor: 'Home',
  ),
  MarketingShot(
    name: 'student-dashboard',
    account: 'Student',
    anchor: 'Home',
  ),
];

// ---------------------------------------------------------------------------
// Waiting
//
// `pumpAndSettle` cannot be used unguarded: the app runs continuous animations
// (the docked AI affordance, progress rings, skeleton shimmer), so settling
// never completes and the call throws on timeout. These helpers pump for a
// bounded time and treat "still animating" as normal rather than as failure.
// ---------------------------------------------------------------------------

/// Pumps frames for up to [timeout], stopping early once the tree is quiet.
Future<void> settle(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 120));
    if (!tester.binding.hasScheduledFrame) return;
  }
}

/// Waits for [finder], scrolls it into view if it is inside a scrollable, then
/// taps it.
///
/// A plain `tester.tap` is not safe across layout tiers: the same widget that
/// sits mid-screen on a phone can fall below the fold on a tablet, where it is
/// present in the tree but not hit-testable — the tap silently lands on nothing
/// and the run stalls on a screen that looks correct. This is what broke the
/// first tablet capture on the OTP screen.
Future<void> tapVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  await waitFor(tester, finder, timeout: timeout);
  try {
    await tester.ensureVisible(finder);
    await settle(tester);
  } catch (_) {
    // Not inside a Scrollable — already as visible as it will get.
  }
  await tester.tap(finder);
  await settle(tester);
}

/// Pumps until [finder] matches, or fails the test with a useful message.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (finder.evaluate().isNotEmpty) {
      // Let the arriving screen finish its entrance before the shutter fires —
      // a mid-transition frame is unusable and must never reach the website.
      await tester.pump(const Duration(milliseconds: 600));
      return;
    }
    await tester.pump(const Duration(milliseconds: 120));
  }
  fail('Timed out waiting for $finder — navigation changed, or the screen '
      'no longer renders this anchor. Fix the shot, never the assertion.\n'
      'Visible text at timeout: ${visibleText(tester)}');
}

/// Every `Text` string currently in the tree — the first thing you want when a
/// shot times out, because it says which screen you actually landed on.
String visibleText(WidgetTester tester) {
  final seen = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final data = (element.widget as Text).data;
    if (data != null && data.trim().isNotEmpty) seen.add(data.trim());
  }
  return seen.isEmpty ? '(no Text widgets in tree)' : seen.join(' · ');
}
