import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:akshara_erp/app/app.dart';
import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/errors/error_observer.dart';
import 'package:akshara_erp/core/errors/error_reporting_service.dart';
import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';

/// QA automation environment — mirrors [scripts/qa/build_qa_apk.sh] dart-defines.
const Environment kPatrolQaEnvironment = Environment(
  name: EnvironmentName.development,
  apiBaseUrl: 'http://localhost:8080/v1',
  enableApiMode: false,
  enableLogging: false,
  disableDemoAuth: false,
  enableQaLogin: true,
);

/// Builds a Riverpod container with QA login enabled for Patrol tests.
Future<ProviderContainer> createPatrolContainer({
  SharedPreferences? prefs,
}) async {
  final sharedPrefs = prefs ?? await SharedPreferences.getInstance();
  final bootstrap = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      environmentProvider.overrideWithValue(kPatrolQaEnvironment),
    ],
  );
  final errorReporting = bootstrap.read(errorReportingServiceProvider);
  bootstrap.dispose();

  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      environmentProvider.overrideWithValue(kPatrolQaEnvironment),
    ],
    observers: [AksharaErrorObserver(errorReporting)],
  );
}

/// Pumps [AksharaApp] with QA environment overrides.
Future<ProviderContainer> pumpAksharaApp(
  dynamic $, {
  SharedPreferences? prefs,
}) async {
  final container = await createPatrolContainer(prefs: prefs);
  await $.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const AksharaApp(),
    ),
  );
  return container;
}

/// Waits for splash → QA login screen (cold start).
Future<void> waitForQaLogin(dynamic $) async {
  await $.pumpAndSettle(timeout: const Duration(seconds: 15));
  await $(QaLoginPersona.principal.buttonLabel).waitUntilVisible(
    timeout: const Duration(seconds: 20),
  );
}

/// One-tap QA persona login from the QA login screen.
Future<void> loginAsQaPersona(dynamic $, QaLoginPersona persona) async {
  await $(persona.buttonLabel).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 15));
  await $(persona.dashboardAnchor).waitUntilVisible(
    timeout: const Duration(seconds: 25),
  );
}

/// Full cold-start login flow for a QA persona.
Future<void> bootstrapAndLogin(dynamic $, QaLoginPersona persona) async {
  await pumpAksharaApp($);
  await waitForQaLogin($);
  await loginAsQaPersona($, persona);
}

/// All QA personas for parameterized tests.
const kAllQaPersonas = QaLoginPersona.values;
