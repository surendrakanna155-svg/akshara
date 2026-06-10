import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/environment_provider.dart';

/// Per-module API feature flags — enable independently when endpoints are ready.
///
/// Finance: set `--dart-define=ENABLE_API_MODE=true` and
/// `--dart-define=FINANCE_API_ENABLED=true` for staging API mode.
///
/// SIS: set `--dart-define=ENABLE_API_MODE=true` and
/// `--dart-define=SIS_API_ENABLED=true` for staging API mode.
///
/// Transport: set `--dart-define=ENABLE_API_MODE=true` and
/// `--dart-define=TRANSPORT_API_ENABLED=true` for staging API mode.
///
/// HR: set `--dart-define=ENABLE_API_MODE=true` and
/// `--dart-define=HR_API_ENABLED=true` for staging API mode.
final authApiEnabledProvider = Provider<bool>((ref) => false);
final admissionsApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'ADMISSIONS_API_ENABLED',
    defaultValue: false,
  );
});

final financeApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('FINANCE_API_ENABLED', defaultValue: false);
});
final sisApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('SIS_API_ENABLED', defaultValue: false);
});
final academicApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'ACADEMIC_API_ENABLED',
    defaultValue: false,
  );
});
final academicTimetableApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'ACADEMIC_TIMETABLE_API_ENABLED',
    defaultValue: false,
  );
});
final analyticsIntelligenceApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'ANALYTICS_INTELLIGENCE_API_ENABLED',
    defaultValue: false,
  );
});
final managementApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('MANAGEMENT_API_ENABLED', defaultValue: false);
});
final transportApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('TRANSPORT_API_ENABLED', defaultValue: false);
});
final hrApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('HR_API_ENABLED', defaultValue: false);
});
final hostelApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('HOSTEL_API_ENABLED', defaultValue: false);
});
final libraryApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('LIBRARY_API_ENABLED', defaultValue: false);
});
final inventoryApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('INVENTORY_API_ENABLED', defaultValue: false);
});
final inventoryFinanceApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'INVENTORY_FINANCE_API_ENABLED',
    defaultValue: false,
  );
});

final aiCopilotApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'AI_COPILOT_ENABLED',
    defaultValue: false,
  );
});

final alumniApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('ALUMNI_API_ENABLED', defaultValue: false);
});
final controlCenterApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('CONTROL_CENTER_API_ENABLED', defaultValue: false);
});
final auditApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('AUDIT_API_ENABLED', defaultValue: false);
});
final paymentApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('PAYMENT_API_ENABLED', defaultValue: false);
});
final communicationApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'COMMUNICATION_API_ENABLED',
    defaultValue: false,
  );
});
final onboardingApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'ONBOARDING_API_ENABLED',
    defaultValue: false,
  );
});
final parentApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('PARENT_API_ENABLED', defaultValue: false);
});
final teacherApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('TEACHER_API_ENABLED', defaultValue: false);
});
final studentApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('STUDENT_API_ENABLED', defaultValue: false);
});

/// Returns true when the global API mode and module flag are both enabled.
bool isModuleApiEnabled(Ref ref, Provider<bool> moduleFlagProvider) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return ref.watch(moduleFlagProvider);
}

/// @deprecated Use per-module `*ApiEnabledProvider` flags instead.
final useApiRepositoriesProvider = Provider<bool>((ref) {
  return ref.watch(authApiEnabledProvider) ||
      ref.watch(admissionsApiEnabledProvider) ||
      ref.watch(financeApiEnabledProvider) ||
      ref.watch(sisApiEnabledProvider) ||
      ref.watch(academicApiEnabledProvider) ||
      ref.watch(managementApiEnabledProvider) ||
      ref.watch(transportApiEnabledProvider) ||
      ref.watch(hrApiEnabledProvider) ||
      ref.watch(hostelApiEnabledProvider) ||
      ref.watch(libraryApiEnabledProvider) ||
      ref.watch(inventoryApiEnabledProvider) ||
      ref.watch(inventoryFinanceApiEnabledProvider) ||
      ref.watch(aiCopilotApiEnabledProvider) ||
      ref.watch(alumniApiEnabledProvider) ||
      ref.watch(controlCenterApiEnabledProvider) ||
      ref.watch(auditApiEnabledProvider) ||
      ref.watch(paymentApiEnabledProvider) ||
      ref.watch(communicationApiEnabledProvider) ||
      ref.watch(onboardingApiEnabledProvider) ||
      ref.watch(parentApiEnabledProvider) ||
      ref.watch(teacherApiEnabledProvider) ||
      ref.watch(studentApiEnabledProvider) ||
      ref.watch(academicTimetableApiEnabledProvider) ||
      ref.watch(analyticsIntelligenceApiEnabledProvider);
});
