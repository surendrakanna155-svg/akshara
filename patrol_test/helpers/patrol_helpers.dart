import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/providers/router_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// Asserts text is visible without re-scrolling the horizontal sub-nav.
Future<void> assertVisibleText(
  PatrolIntegrationTester $,
  String text, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  await $.pump(const Duration(milliseconds: 500));
  final finder = find.text(text);
  if ($.tester.any(finder)) {
    try {
      await $.tester.ensureVisible(finder);
      await $.pump(const Duration(milliseconds: 500));
    } catch (_) {
      // Below the fold — waitUntilVisible may still succeed after body scroll.
    }
  }
  await $(text).waitUntilVisible(timeout: timeout);
  expect(find.text(text), findsWidgets);
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

/// Resolves [GoRouter] from the Patrol app's Riverpod container.
GoRouter _patrolGoRouter(PatrolIntegrationTester $) {
  final scope = find.byType(UncontrolledProviderScope);
  expect(scope, findsOneWidget);
  final container = $.tester.widget<UncontrolledProviderScope>(scope).container;
  return container.read(goRouterProvider);
}

/// Navigates directly to an ERP route via GoRouter (bypasses horizontal sub-nav).
Future<void> goToErpRoute(PatrolIntegrationTester $, String route) async {
  _patrolGoRouter($).go(route);
  for (var i = 0; i < 20; i++) {
    await $.pump(const Duration(milliseconds: 500));
    if (_patrolGoRouter($).state.uri.path == route) break;
  }
}

/// Asserts a QA widget key is present after navigation.
Future<void> assertVisibleKey(
  PatrolIntegrationTester $,
  Key key, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  await $.pump(const Duration(milliseconds: 500));
  final finder = find.byKey(key);
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (_safeAny($, finder)) {
      expect(finder, findsOneWidget);
      return;
    }
    await $.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsOneWidget);
}

/// QA login → direct ERP route → screen key + workflow anchor.
Future<void> navigateErpModuleRoute(
  PatrolIntegrationTester $,
  QaLoginPersona persona,
  String route, {
  required Key screenKey,
  required String workflowAnchor,
}) async {
  await bootstrapAndLogin($, persona);
  await goToErpRoute($, route);
  await assertVisibleKey($, screenKey);
  await assertVisibleText($, workflowAnchor);
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
    await _tapHorizontalSubNav($, moduleKey, subNavLabel);
  }
  await assertVisibleText($, workflowAnchor,
      timeout: const Duration(seconds: 25));
}

/// Taps a horizontal module sub-nav tab — never drags the page body.
Future<void> tapModuleSubNav(
  PatrolIntegrationTester $,
  String moduleKey,
  String label,
) async {
  await _tapHorizontalSubNav($, moduleKey, label);
}

String _moduleNavSemantics(String moduleKey) => switch (moduleKey) {
      'finance' => 'Finance module navigation',
      'management' => 'Management module navigation',
      'sis' => 'Student SIS module navigation',
      'admissions' => 'Admissions module navigation',
      'inventory' => 'Inventory module navigation',
      'hr' => 'HR module navigation',
      'transport' => 'Transport module navigation',
      'library' => 'Library module navigation',
      'hostel' => 'Hostel module navigation',
      'alumni' => 'Alumni module navigation',
      'controlCenter' => 'Control Center module navigation',
      'director' => 'Director module navigation',
      _ => '$moduleKey module navigation',
    };

Finder _moduleNavScrollView(String navSemantics) {
  return find.descendant(
    of: find.bySemanticsLabel(navSemantics),
    matching: find.byType(SingleChildScrollView),
  );
}

bool _safeAny(PatrolIntegrationTester $, Finder finder) {
  try {
    return $.tester.any(finder);
  } catch (_) {
    return false;
  }
}

Future<void> _scrollNavHorizontally(
  PatrolIntegrationTester $,
  Finder scrollView, {
  required double dx,
  int times = 1,
}) async {
  if (!_safeAny($, scrollView)) return;
  for (var i = 0; i < times; i++) {
    try {
      await $.tester.drag(scrollView.first, Offset(dx, 0));
      await $.pumpAndSettle(timeout: const Duration(seconds: 1));
    } catch (_) {
      await $.pumpAndSettle(timeout: const Duration(seconds: 2));
    }
  }
}

Future<bool> _tryTapFinder(
  PatrolIntegrationTester $,
  Finder finder, {
  bool ensureVisibleFirst = true,
}) async {
  try {
    if (!_safeAny($, finder)) return false;
    if (ensureVisibleFirst) {
      try {
        await $.tester.ensureVisible(finder);
      } catch (_) {
        // Far-right sub-nav tabs can throw during ensureVisible — tap anyway.
      }
    }
    await $.tester.tap(finder, warnIfMissed: false);
    await $.pump(const Duration(seconds: 2));
    return true;
  } catch (_) {
    await $.pump(const Duration(milliseconds: 500));
    return false;
  }
}

/// Scrolls module page body vertically using a visible anchor (not sub-nav).
Future<void> scrollModuleBody(
  PatrolIntegrationTester $,
  String anchorText, {
  int times = 2,
}) async {
  final anchor = find.text(anchorText);
  for (var i = 0; i < times; i++) {
    if ($.tester.any(anchor)) {
      await $.tester.drag(anchor.first, const Offset(0, -350));
      await $.pumpAndSettle(timeout: const Duration(seconds: 2));
    }
  }
}

/// Scrolls the ERP dashboard page down (vertical) — never the horizontal sub-nav.
Future<void> scrollDashboardDown(
  PatrolIntegrationTester $, {
  int times = 4,
}) async {
  final anchor = find.text('Principal overview');
  for (var i = 0; i < times; i++) {
    if ($.tester.any(anchor)) {
      await $.tester.drag(anchor, const Offset(0, -400));
      await $.pumpAndSettle(timeout: const Duration(seconds: 2));
    }
  }
}

Future<void> _tapHorizontalSubNav(
  PatrolIntegrationTester $,
  String moduleKey,
  String label,
) async {
  final tabKey = QaTestKeys.moduleSubNavTab(moduleKey, label);
  final keyFinder = find.byKey(tabKey);
  final semanticsFinder = find.bySemanticsLabel('$label tab');
  final navSemantics = _moduleNavSemantics(moduleKey);
  final scrollView = _moduleNavScrollView(navSemantics);

  if (await _tryTapFinder($, keyFinder)) return;
  if (await _tryTapFinder($, semanticsFinder)) return;

  // Drag the horizontal ScrollView (not the Semantics wrapper — drags there no-op).
  if (_safeAny($, scrollView)) {
    await _scrollNavHorizontally($, scrollView, dx: 280, times: 4);
    for (var i = 0; i < 30; i++) {
      if (await _tryTapFinder($, keyFinder)) return;
      if (await _tryTapFinder($, semanticsFinder)) return;
      if (i < 19) {
        await _scrollNavHorizontally($, scrollView, dx: -280);
      }
    }
  }

  expect(
    false,
    isTrue,
    reason: 'Sub-nav tab "$label" not reachable for module $moduleKey',
  );
}

/// Advances enrollment wizard; scrolls to Continue when off-screen.
Future<void> tapEnrollmentContinue(PatrolIntegrationTester $) async {
  await $(QaTestKeys.enrollmentContinueButton).scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
}

/// Principal overview quick action — scrolls page body down, never the sub-nav.
Future<void> tapPrincipalQuickAction(
    PatrolIntegrationTester $, String action) async {
  await $('Principal overview')
      .waitUntilVisible(timeout: const Duration(seconds: 20));
  final keyFinder = find.byKey(QaTestKeys.principalQuickAction(action));
  final overview = find.text('Principal overview');
  for (var i = 0; i < 5; i++) {
    if ($.tester.any(keyFinder)) {
      if (await _tryTapFinder($, keyFinder)) return;
    }
    if ($.tester.any(overview)) {
      await $.tester.drag(overview, const Offset(0, -400));
      await $.pumpAndSettle(timeout: const Duration(seconds: 2));
    }
  }
  await $(QaTestKeys.principalQuickAction(action)).tap();
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
