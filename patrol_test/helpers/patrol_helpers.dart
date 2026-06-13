import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import 'patrol_app.dart';

/// Default Patrol config for Akshara QA builds (extended timeouts for splash).
PatrolTesterConfig aksharaPatrolConfig() {
  return const PatrolTesterConfig(
    existsTimeout: Duration(seconds: 20),
    visibleTimeout: Duration(seconds: 20),
    settleTimeout: Duration(seconds: 20),
    printLogs: false,
  );
}

/// Records screenshot intent for regression tooling.
/// On-device Patrol tests cannot write to host project paths — no-op on Android/iOS.
Future<void> capturePatrolScreenshot(
  PatrolIntegrationTester $,
  String name, {
  String subdir = 'runtime',
}) async {
  if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
    return;
  }
  try {
    final dir = Directory('qa/patrol/screenshots/$subdir');
    dir.createSync(recursive: true);
    File('${dir.path}/$name.marker').writeAsStringSync(
      DateTime.now().toIso8601String(),
    );
  } catch (_) {
    // Patrol CLI captures failure screenshots on the host.
  }
}

/// Asserts text is visible.
Future<void> assertVisibleText(
  PatrolIntegrationTester $,
  String text, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  await $(text).waitUntilVisible(timeout: timeout);
  expect($(text), findsAtLeast(1));
}

/// Taps navigation item by label and waits for destination anchor.
Future<void> tapNavAndWait(
  PatrolIntegrationTester $,
  String navLabel,
  String destinationAnchor,
) async {
  await $(navLabel).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await $(destinationAnchor).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
}

/// Opens ERP drawer on mobile admin shell.
Future<void> openErpDrawer(PatrolIntegrationTester $) async {
  await $(QaTestKeys.erpMenuButton).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 5));
}

/// QA login → ERP drawer → module (+ optional sub-nav) → workflow anchor.
Future<void> navigateErpWorkflow(
  PatrolIntegrationTester $,
  QaLoginPersona persona,
  String moduleKey, {
  String? subNavLabel,
  required String workflowAnchor,
}) async {
  await bootstrapAndLogin($, persona);
  await openErpDrawer($);
  await $(QaTestKeys.erpNavModule(moduleKey)).scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 15));
  if (subNavLabel != null) {
    await $(QaTestKeys.moduleSubNavTab(moduleKey, subNavLabel))
        .scrollTo()
        .tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  }
  await $(workflowAnchor).scrollTo();
  await assertVisibleText($, workflowAnchor, timeout: const Duration(seconds: 25));
}

/// Taps a horizontal module sub-nav tab by module key + label.
Future<void> tapModuleSubNav(
  PatrolIntegrationTester $,
  String moduleKey,
  String label,
) async {
  await $(QaTestKeys.moduleSubNavTab(moduleKey, label)).scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
}

/// Advances enrollment wizard; scrolls to Continue when off-screen.
Future<void> tapEnrollmentContinue(PatrolIntegrationTester $) async {
  await $(QaTestKeys.enrollmentContinueButton).scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
}

/// Principal overview quick action (stable keys).
Future<void> tapPrincipalQuickAction(PatrolIntegrationTester $, String action) async {
  await $(QaTestKeys.principalQuickAction(action)).scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 15));
}

/// Opens ERP drawer (mobile) and navigates to a module by key.
Future<void> openErpModule(
  PatrolIntegrationTester $,
  QaLoginPersona persona,
  String moduleKey,
) async {
  await bootstrapAndLogin($, persona);
  await openErpDrawer($);
  await $(QaTestKeys.erpNavModule(moduleKey)).scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 15));
}

/// Bottom navigation bar tap (mobile shells).
Future<void> tapBottomNav(PatrolIntegrationTester $, String label) async {
  await $(label).scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
}

/// Scroll until visible, then tap label text.
Future<void> scrollTap(PatrolIntegrationTester $, String label) async {
  await $(label).scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
}
