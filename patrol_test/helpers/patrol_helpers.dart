import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

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

/// Opens ERP drawer (mobile) and navigates to a module by label.
Future<void> openErpModule(
  PatrolIntegrationTester $,
  QaLoginPersona persona,
  String moduleLabel,
) async {
  await bootstrapAndLogin($, persona);
  try {
    await $('Open navigation').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  } catch (_) {
    // Tablet/desktop layout — module rail is already visible.
  }
  await $(moduleLabel).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 15));
}
