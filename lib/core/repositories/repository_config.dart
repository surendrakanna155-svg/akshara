import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/environment_provider.dart';

/// Per-module API feature flags — enable independently when endpoints are ready.
///
/// F1 Auth + RBAC: `--dart-define=ENABLE_API_MODE=true` (auth defaults on via
/// `AUTH_API_ENABLED`, default true when API mode is enabled).
///
/// Phase 5: set `--dart-define=ENABLE_API_MODE=true` and
/// `--dart-define=PHASE5_API_ENABLED=true` (requires Phase 4 flags for dependencies).
///
/// Onboarding: `--dart-define=ONBOARDING_API_ENABLED=true`
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
final authApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'AUTH_API_ENABLED',
    defaultValue: true,
  );
});
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
final academicOperationsApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'ACADEMIC_OPERATIONS_API_ENABLED',
    defaultValue: false,
  );
});
final continuityApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'CONTINUITY_API_ENABLED',
    defaultValue: false,
  );
});
final workflowApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'WORKFLOW_API_ENABLED',
    defaultValue: false,
  );
});
final approvalApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'APPROVAL_API_ENABLED',
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
  return const bool.fromEnvironment('MANAGEMENT_API_ENABLED',
      defaultValue: false);
});
final transportApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('TRANSPORT_API_ENABLED',
      defaultValue: false);
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
  return const bool.fromEnvironment('INVENTORY_API_ENABLED',
      defaultValue: false);
});
final inventoryFinanceApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'INVENTORY_FINANCE_API_ENABLED',
    defaultValue: false,
  );
});

final educationApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'EDUCATION_API_ENABLED',
    defaultValue: false,
  );
});

/// Exam administration API — set `--dart-define=EXAM_API_ENABLED=true` with API mode.
final examApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'EXAM_API_ENABLED',
    defaultValue: false,
  );
});

final intelligenceApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'INTELLIGENCE_API_ENABLED',
    defaultValue: false,
  );
});

final employeeApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'EMPLOYEE_API_ENABLED',
    defaultValue: false,
  );
});

final inventoryDistributionApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'INVENTORY_DISTRIBUTION_API_ENABLED',
    defaultValue: false,
  );
});

final phase5ApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'PHASE5_API_ENABLED',
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
  return const bool.fromEnvironment('CONTROL_CENTER_API_ENABLED',
      defaultValue: false);
});
final directorApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('DIRECTOR_API_ENABLED',
      defaultValue: false);
});
final platformIntelligenceApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'PLATFORM_INTELLIGENCE_API_ENABLED',
    defaultValue: false,
  );
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

final evolutionApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('EVOLUTION_API_ENABLED',
      defaultValue: false);
});

final schoolCompletionApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment('SCHOOL_COMPLETION_API_ENABLED',
      defaultValue: false);
});

final multiSchoolOperationsApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'MULTI_SCHOOL_OPERATIONS_API_ENABLED',
    defaultValue: false,
  );
});

final organizationBuilderApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'ORGANIZATION_BUILDER_API_ENABLED',
    defaultValue: false,
  );
});

final platformOperationsApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'PLATFORM_OPERATIONS_API_ENABLED',
    defaultValue: false,
  );
});

final healthcareApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'HEALTHCARE_API_ENABLED',
    defaultValue: false,
  );
});

final salonApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'SALON_API_ENABLED',
    defaultValue: false,
  );
});

final restaurantApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'RESTAURANT_API_ENABLED',
    defaultValue: false,
  );
});

final accommodationApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'ACCOMMODATION_API_ENABLED',
    defaultValue: false,
  );
});

final whiteLabelPlatformApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'WHITE_LABEL_PLATFORM_API_ENABLED',
    defaultValue: false,
  );
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
      ref.watch(academicOperationsApiEnabledProvider) ||
      ref.watch(continuityApiEnabledProvider) ||
      ref.watch(workflowApiEnabledProvider) ||
      ref.watch(managementApiEnabledProvider) ||
      ref.watch(transportApiEnabledProvider) ||
      ref.watch(hrApiEnabledProvider) ||
      ref.watch(hostelApiEnabledProvider) ||
      ref.watch(libraryApiEnabledProvider) ||
      ref.watch(inventoryApiEnabledProvider) ||
      ref.watch(inventoryFinanceApiEnabledProvider) ||
      ref.watch(educationApiEnabledProvider) ||
      ref.watch(intelligenceApiEnabledProvider) ||
      ref.watch(employeeApiEnabledProvider) ||
      ref.watch(inventoryDistributionApiEnabledProvider) ||
      ref.watch(phase5ApiEnabledProvider) ||
      ref.watch(aiCopilotApiEnabledProvider) ||
      ref.watch(alumniApiEnabledProvider) ||
      ref.watch(controlCenterApiEnabledProvider) ||
      ref.watch(directorApiEnabledProvider) ||
      ref.watch(platformIntelligenceApiEnabledProvider) ||
      ref.watch(auditApiEnabledProvider) ||
      ref.watch(paymentApiEnabledProvider) ||
      ref.watch(communicationApiEnabledProvider) ||
      ref.watch(onboardingApiEnabledProvider) ||
      ref.watch(parentApiEnabledProvider) ||
      ref.watch(teacherApiEnabledProvider) ||
      ref.watch(studentApiEnabledProvider) ||
      ref.watch(academicTimetableApiEnabledProvider) ||
      ref.watch(analyticsIntelligenceApiEnabledProvider) ||
      ref.watch(evolutionApiEnabledProvider) ||
      ref.watch(schoolCompletionApiEnabledProvider) ||
      ref.watch(multiSchoolOperationsApiEnabledProvider) ||
      ref.watch(organizationBuilderApiEnabledProvider) ||
      ref.watch(platformOperationsApiEnabledProvider) ||
      ref.watch(healthcareApiEnabledProvider) ||
      ref.watch(salonApiEnabledProvider) ||
      ref.watch(restaurantApiEnabledProvider) ||
      ref.watch(accommodationApiEnabledProvider) ||
      ref.watch(whiteLabelPlatformApiEnabledProvider);
});
