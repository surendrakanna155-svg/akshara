import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:akshara_erp/app/app.dart';
import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/errors/error_observer.dart';
import 'package:akshara_erp/core/errors/error_reporting_service.dart';
import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:akshara_erp/core/school_config/school_configuration_provider.dart';
import 'package:akshara_erp/core/school_config/school_configuration_storage.dart';
import 'package:akshara_erp/core/security/server_permission_provider.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/features/copilot/settings/ai_access_preferences.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/copilot/settings/ai_access_preferences_storage.dart';
import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_provider.dart';

/// QA automation environment — mirrors [scripts/qa/build_qa_apk.sh] dart-defines.
const Environment kPatrolQaEnvironment = Environment(
  name: EnvironmentName.development,
  apiBaseUrl: 'http://localhost:8080/v1',
  enableApiMode: false,
  enableLogging: false,
  disableDemoAuth: false,
  enableQaLogin: true,
);

/// Seeds floating AI dock for all QA personas (mobile Patrol runs).
Future<void> seedPatrolAiDockPreferences(SharedPreferences prefs) async {
  const aiPrefs = AiAccessPreferences(floatingBubbleEnabled: true);
  final storage = AiAccessPreferencesStorage(prefs);
  for (final persona in QaLoginPersona.values) {
    await storage.write('qa_${persona.name}', aiPrefs);
  }
}

/// Forces full demo capabilities (transport notices visible) for Patrol journeys.
class PatrolSchoolConfigurationNotifier extends SchoolConfigurationNotifier {
  @override
  SchoolConfiguration build() => SchoolConfiguration.demoDefault();
}

/// Puts [noticeId] first in the parent dashboard carousel for Patrol deep-link taps.
Override parentPatrolNoticeFirstOverride(String noticeId) {
  return parentDashboardFutureProvider.overrideWith((ref) async {
    final base = await ref.read(parentRepositoryProvider).getDashboard(
          query: ref.watch(repositoryQueryProvider),
        );
    final target = base.notices.where((n) => n.id == noticeId).firstOrNull;
    if (target == null) return base;
    final others = base.notices.where((n) => n.id != noticeId).toList();
    return ParentDashboardData(
      childName: base.childName,
      childClass: base.childClass,
      greetingEyebrow: base.greetingEyebrow,
      greetingHeadline: base.greetingHeadline,
      schoolName: base.schoolName,
      statusChips: base.statusChips,
      quickActions: base.quickActions,
      todaySummary: base.todaySummary,
      notices: [target, ...others],
      events: base.events,
      aiInsight: base.aiInsight,
      unreadNotifications: base.unreadNotifications,
    );
  });
}

/// Builds a Riverpod container with QA login enabled for Patrol tests.
Future<ProviderContainer> createPatrolContainer({
  SharedPreferences? prefs,
  List<Override> extraOverrides = const [],
}) async {
  final sharedPrefs = prefs ?? await SharedPreferences.getInstance();
  await sharedPrefs.remove(kServerPermissionSnapshotKey);
  await SchoolConfigurationStorage(sharedPrefs).write(
    SchoolConfiguration.demoDefault(),
  );
  await seedPatrolAiDockPreferences(sharedPrefs);
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
      schoolConfigurationProvider.overrideWith(
        PatrolSchoolConfigurationNotifier.new,
      ),
      ...extraOverrides,
    ],
    observers: [AksharaErrorObserver(errorReporting)],
  );
}

/// Pumps [AksharaApp] with QA environment overrides.
Future<ProviderContainer> pumpAksharaApp(
  dynamic $, {
  SharedPreferences? prefs,
  List<Override> extraOverrides = const [],
}) async {
  final container = await createPatrolContainer(
    prefs: prefs,
    extraOverrides: extraOverrides,
  );
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
Future<void> bootstrapAndLogin(
  dynamic $,
  QaLoginPersona persona, {
  List<Override> extraOverrides = const [],
}) async {
  await pumpAksharaApp($, extraOverrides: extraOverrides);
  await waitForQaLogin($);
  await loginAsQaPersona($, persona);
}

/// All QA personas for parameterized tests.
const kAllQaPersonas = QaLoginPersona.values;
