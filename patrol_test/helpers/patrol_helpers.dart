import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/providers/router_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/auth_provider.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'patrol_app.dart';

/// Default Patrol config for Akshara QA builds (extended timeouts for splash).
PatrolTesterConfig aksharaPatrolConfig() {
  return const PatrolTesterConfig(
    existsTimeout: Duration(seconds: 30),
    visibleTimeout: Duration(seconds: 30),
    settleTimeout: Duration(seconds: 30),
    printLogs: false,
  );
}

/// Clears the active session and signs in as another QA persona (mid-test).
Future<void> switchQaPersona(
  PatrolIntegrationTester $,
  QaLoginPersona persona,
) async {
  final scope = find.byType(UncontrolledProviderScope);
  expect(scope, findsOneWidget);
  final container =
      $.tester.widget<UncontrolledProviderScope>(scope).container;
  await container.read(authProvider.notifier).logout();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  _patrolGoRouter($).go(RouteNames.qaLogin);
  await $.pumpAndSettle(timeout: const Duration(seconds: 15));
  await waitForQaLogin($);
  await loginAsQaPersona($, persona);
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
  Duration timeout = const Duration(seconds: 30),
}) async {
  await $.pump(const Duration(milliseconds: 500));
  final finder = find.text(text);
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (_safeAny($, finder)) {
      expect(finder, findsWidgets);
      return;
    }
    await $.pump(const Duration(milliseconds: 200));
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
  for (var i = 0; i < 60; i++) {
    await $.pump(const Duration(milliseconds: 250));
    final path = _patrolGoRouter($).state.uri.path;
    if (path == route || path.startsWith('$route/')) break;
  }
  await $.pumpAndSettle(timeout: const Duration(seconds: 20));
}

/// Waits for a widget key, scrolling the primary body when needed.
Future<void> tapByKey(
  PatrolIntegrationTester $,
  Key key, {
  bool scrollFirst = true,
}) async {
  final finder = find.byKey(key);
  if (scrollFirst) {
    try {
      await $(key).scrollTo();
    } catch (_) {
      // App bar / fixed overlays are not in a scrollable.
    }
  }
  await assertVisibleKey($, key, timeout: const Duration(seconds: 30));
  await $.tester.tap(finder);
  await $.pump(const Duration(seconds: 1));
}

/// Taps the Nth tab in a scrollable AppBar [TabBar] (0-based).
Future<void> tapAppBarTabByIndex(
  PatrolIntegrationTester $,
  int index,
) async {
  final tabBar = find.byType(TabBar);
  final tabs = find.descendant(of: tabBar, matching: find.byType(Tab));
  final scrollable = find.descendant(
    of: tabBar,
    matching: find.byType(Scrollable),
  );

  for (var i = 0; i < 80; i++) {
    if (_safeAny($, tabs) && $.tester.widgetList(tabs).length > index) {
      final tabFinder = tabs.at(index);
      if (await _tryTapFinder($, tabFinder)) {
        await $.pumpAndSettle(timeout: const Duration(seconds: 10));
        return;
      }
    }
    if (_safeAny($, scrollable)) {
      await $.tester.drag(scrollable.first, const Offset(-260, 0));
      await $.pump(const Duration(milliseconds: 300));
    }
  }
  expect(tabs, findsWidgets);
  await $.tester.tap(tabs.at(index));
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
}

/// Taps a scrollable AppBar [Tab] by label or QA key.
Future<void> tapAppBarTab(
  PatrolIntegrationTester $, {
  String? label,
  Key? tabKey,
}) async {
  assert(label != null || tabKey != null);
  final tabFinder =
      tabKey != null ? find.byKey(tabKey) : find.text(label!);
  final scrollable = find.descendant(
    of: find.byType(TabBar),
    matching: find.byType(Scrollable),
  );

  for (var i = 0; i < 60; i++) {
    if (await _tryTapFinder($, tabFinder)) {
      await $.pumpAndSettle(timeout: const Duration(seconds: 8));
      return;
    }
    if (_safeAny($, scrollable)) {
      await $.tester.drag(scrollable.first, const Offset(-220, 0));
      await $.pump(const Duration(milliseconds: 300));
    }
  }
  if (label != null) {
    await $(label).waitUntilVisible(timeout: const Duration(seconds: 30));
    await $(label).tap();
  } else {
    await $(tabKey!).waitUntilVisible(timeout: const Duration(seconds: 30));
    await $(tabKey).tap();
  }
  await $.pumpAndSettle(timeout: const Duration(seconds: 8));
}

/// Enters text into a [TextField] located by its decoration label.
Future<void> enterLabeledField(
  PatrolIntegrationTester $,
  String label,
  String value,
) async {
  final field = find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.labelText == label,
  );
  await $.tester.ensureVisible(field);
  await $.pump(const Duration(milliseconds: 200));
  await $.tester.enterText(field, value);
  await $.pump(const Duration(milliseconds: 200));
}

/// Asserts a QA widget key is present after navigation.
Future<void> assertVisibleKey(
  PatrolIntegrationTester $,
  Key key, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  await $.pump(const Duration(milliseconds: 500));
  final finder = find.byKey(key);
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (_safeAny($, finder)) {
      await $.pump(const Duration(milliseconds: 200));
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
  await assertVisibleKey($, screenKey, timeout: const Duration(seconds: 45));
  await assertVisibleText($, workflowAnchor,
      timeout: const Duration(seconds: 30));
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

/// Taps label text after scrolling the module body (not Patrol scrollTo).
Future<void> tapBodyText(
  PatrolIntegrationTester $,
  String label, {
  String scrollAnchor = 'Principal overview',
}) async {
  final finder = find.text(label);
  for (var i = 0; i < 8; i++) {
    if (_safeAny($, finder)) {
      try {
        await $.tester.ensureVisible(finder);
        await $.tester.tap(finder, warnIfMissed: false);
        await $.pump(const Duration(seconds: 1));
        return;
      } catch (_) {}
    }
    await scrollModuleBody($, scrollAnchor);
  }
  await $(label).waitUntilVisible(timeout: const Duration(seconds: 30));
  await $.tester.tap(finder);
  await $.pump(const Duration(seconds: 1));
}

/// Waits until a [SnackBar] message containing [text] appears.
Future<void> assertSnackBarText(
  PatrolIntegrationTester $,
  String text, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final finder = find.textContaining(text);
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (_safeAny($, finder)) {
      expect(finder, findsWidgets);
      return;
    }
    await $.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

/// Waits for loading indicators to clear after async provider fetch.
Future<void> waitForLoadingToClear(
  PatrolIntegrationTester $, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final loading = find.byType(CircularProgressIndicator);
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (!_safeAny($, loading)) {
      await $.pump(const Duration(milliseconds: 300));
      return;
    }
    await $.pump(const Duration(milliseconds: 200));
  }
}

/// Current GoRouter path from the Patrol app container.
String currentPatrolRoute(PatrolIntegrationTester $) {
  return _patrolGoRouter($).state.uri.path;
}

/// Waits until [route] is active (exact or prefix match).
Future<void> assertPatrolRoute(
  PatrolIntegrationTester $,
  String route, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final path = currentPatrolRoute($);
    if (path == route || path.startsWith('$route/')) {
      return;
    }
    await $.pump(const Duration(milliseconds: 250));
  }
  expect(currentPatrolRoute($), route);
}

/// Asserts mobile persona cannot remain on a forbidden ERP route (redirect home).
Future<void> assertMobileForbiddenErpRoute(
  PatrolIntegrationTester $,
  String forbiddenRoute, {
  required String expectedHomeRoute,
  required Key expectedHomeScreenKey,
}) async {
  await goToErpRoute($, forbiddenRoute);
  await $.pumpAndSettle(timeout: const Duration(seconds: 15));
  final path = currentPatrolRoute($);
  expect(
    path == forbiddenRoute || path.startsWith('$forbiddenRoute/'),
    isFalse,
    reason: 'Expected redirect away from $forbiddenRoute, still on $path',
  );
  await assertPatrolRoute($, expectedHomeRoute);
  await assertVisibleKey($, expectedHomeScreenKey);
}

/// Taps a parent dashboard quick action by stable QA key.
Future<void> tapParentDashboardQuickAction(
  PatrolIntegrationTester $,
  String actionId,
) async {
  await tapByKey($, QaTestKeys.parentDashboardQuickAction(actionId));
  await $.pumpAndSettle(timeout: const Duration(seconds: 15));
}

/// Taps a student dashboard quick action by stable QA key.
Future<void> tapStudentDashboardQuickAction(
  PatrolIntegrationTester $,
  String actionId,
) async {
  await tapByKey($, QaTestKeys.studentDashboardQuickAction(actionId));
  await $.pumpAndSettle(timeout: const Duration(seconds: 15));
}

/// Returns parent to home dashboard via bottom navigation.
Future<void> tapParentHome(PatrolIntegrationTester $) async {
  await tapBottomNav($, 'Home');
  await assertVisibleKey($, QaTestKeys.parentDashboardScreen);
}

/// Returns student to home dashboard via bottom navigation.
Future<void> tapStudentHome(PatrolIntegrationTester $) async {
  await tapBottomNav($, 'Home');
  await assertVisibleKey($, QaTestKeys.studentDashboardScreen);
}

/// Taps a dashboard notice tile (scrolls vertically + horizontally when needed).
Future<void> tapParentDashboardNotice(
  PatrolIntegrationTester $,
  String noticeId, {
  String? titleFragment,
}) async {
  await assertVisibleText($, 'School Notices');
  await scrollModuleBody($, 'School Notices', times: 4);

  final key = QaTestKeys.parentDashboardNotice(noticeId);
  final keyFinder = find.byKey(key);
  final carouselFinder = find.byKey(QaTestKeys.parentNoticeCarousel);
  final carouselScrollable = find.descendant(
    of: carouselFinder,
    matching: find.byType(Scrollable),
  );

  if (_safeAny($, carouselFinder)) {
    try {
      await $.tester.ensureVisible(carouselFinder);
      await $.pump(const Duration(milliseconds: 300));
    } catch (_) {
      await scrollModuleBody($, 'School Notices', times: 2);
    }
  }

  if (_safeAny($, carouselScrollable)) {
    try {
      await $.tester.scrollUntilVisible(
        keyFinder,
        80,
        scrollable: carouselScrollable,
      );
    } catch (_) {
      for (var i = 0; i < 8; i++) {
        await $.tester.drag(carouselScrollable.first, const Offset(-280, 0));
        await $.pump(const Duration(milliseconds: 250));
      }
    }
  }

  await $.tester.ensureVisible(keyFinder);
  final inkWell = find.descendant(
    of: keyFinder,
    matching: find.byType(InkWell),
  );
  if (_safeAny($, inkWell)) {
    await $.tester.tap(inkWell);
  } else {
    await $.tester.tap(keyFinder);
  }
  await $.pumpAndSettle(timeout: const Duration(seconds: 15));
}

/// Opens full copilot from the floating dock (QA default access mode).
Future<void> openCopilotViaFloatingDock(PatrolIntegrationTester $) async {
  await $(QaTestKeys.copilotFloatingDockFab).waitUntilVisible(
    timeout: const Duration(seconds: 30),
  );
  await $(QaTestKeys.copilotFloatingDockFab).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertVisibleKey($, QaTestKeys.copilotFloatingDockOpenButton);
  await $(QaTestKeys.copilotFloatingDockOpenButton).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 15));
}
