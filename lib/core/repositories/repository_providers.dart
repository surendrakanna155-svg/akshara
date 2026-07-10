import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'academic/academic_repository.dart';
import 'academic/hybrid_academic_repository.dart';
import 'api/api_repository_providers.dart';
import 'api/academic_operations/hybrid_academic_operations_repository.dart';
import 'api/workflow/hybrid_workflow_repository.dart';
import 'api/finance/hybrid_finance_repository.dart';
import 'api/sis/hybrid_sis_repository.dart';
import 'api/continuity/hybrid_continuity_repository.dart';
import 'interfaces/admissions_repository.dart';
import 'interfaces/academic_operations_repository.dart';
import 'interfaces/workflow_repository.dart';
import 'interfaces/approval_repository.dart';
import 'interfaces/finance_repository.dart';
import 'interfaces/hostel_repository.dart';
import 'interfaces/hr_repository.dart';
import 'interfaces/library_repository.dart';
import 'interfaces/management_repository.dart';
import 'interfaces/sis_repository.dart';
import 'interfaces/continuity_repository.dart';
import 'interfaces/alumni_repository.dart';
import 'interfaces/control_center_repository.dart';
import 'interfaces/platform_intelligence_repository.dart';
import 'interfaces/director_repository.dart';
import 'interfaces/predictions_repository.dart';
import 'interfaces/inventory_finance_repository.dart';
import 'interfaces/inventory_repository.dart';
import 'interfaces/onboarding_repository.dart';
import 'interfaces/startup_onboarding_repository.dart';
import 'interfaces/transport_repository.dart';
import 'interfaces/parent_repository.dart';
import 'interfaces/teacher_repository.dart';
import 'interfaces/student_repository.dart';
import 'interfaces/adaptive_ai_repository.dart';
import 'interfaces/copilot_repository.dart';
import 'interfaces/education_repository.dart';
import 'interfaces/intelligence_repository.dart';
import 'interfaces/homework_intelligence_repository.dart';
import 'interfaces/student_360_repository.dart';
import 'interfaces/exam_administration_repository.dart';
import 'interfaces/attendance_correction_repository.dart';
import 'interfaces/attendance_office_repository.dart';
import 'interfaces/employee_repository.dart';
import 'interfaces/inventory_distribution_repository.dart';
import 'interfaces/phase5_repositories.dart';
import 'interfaces/evolution_repository.dart';
import 'api/evolution/hybrid_evolution_repository.dart';
import 'api/school_completion/hybrid_school_completion_repository.dart';
import 'interfaces/school_completion_repository.dart';
import 'interfaces/multi_school_operations_repository.dart';
import 'interfaces/organization_builder_repository.dart';
import 'interfaces/platform_operations_repository.dart';
import 'interfaces/healthcare_repository.dart';
import 'interfaces/salon_repository.dart';
import 'interfaces/restaurant_repository.dart';
import 'interfaces/accommodation_repository.dart';
import 'interfaces/white_label_platform_repository.dart';
import 'mock/mock_evolution_repository.dart';
import 'mock/mock_school_completion_repository.dart';
import 'mock/mock_multi_school_operations_repository.dart';
import 'mock/mock_organization_builder_repository.dart';
import 'mock/mock_platform_operations_repository.dart';
import 'mock/mock_healthcare_repository.dart';
import 'mock/mock_salon_repository.dart';
import 'mock/mock_restaurant_repository.dart';
import 'mock/mock_accommodation_repository.dart';
import 'mock/mock_white_label_platform_repository.dart';
import 'interfaces/communication_repository.dart';
import 'api/adaptive_ai/hybrid_adaptive_ai_repository.dart';
import 'api/copilot/hybrid_copilot_repository.dart';
import '../ai/ai_inference_providers.dart';
import 'mock/mock_adaptive_ai_repository.dart';
import 'mock/mock_copilot_repository.dart';
import 'mock/mock_education_repository.dart';
import 'mock/mock_intelligence_repository.dart';
import 'mock/mock_homework_intelligence_repository.dart';
import 'mock/mock_student_360_repository.dart';
import 'mock/mock_exam_administration_repository.dart';
import 'mock/mock_attendance_correction_repository.dart';
import 'mock/mock_attendance_office_repository.dart';
import 'mock/mock_employee_repository.dart';
import 'mock/mock_inventory_distribution_repository.dart';
import 'mock/mock_phase5_repositories.dart';
import 'api/education/hybrid_education_repository.dart';
import 'api/intelligence/hybrid_intelligence_repository.dart';
import 'interfaces/timetable_repository.dart';
import 'interfaces/analytics_intelligence_repository.dart';
import 'api/timetable/hybrid_timetable_repository.dart';
import 'api/analytics/hybrid_analytics_intelligence_repository.dart';
import 'api/director/hybrid_director_repository.dart';
import 'api/predictions/hybrid_predictions_repository.dart';
import 'api/hostel/hybrid_hostel_repository.dart';
import 'api/hr/hybrid_hr_repository.dart';
import 'mock/mock_timetable_repository.dart';
import 'mock/mock_analytics_intelligence_repository.dart';
import 'mock/mock_communication_repository.dart';
import 'api/communication/hybrid_communication_repository.dart';
import 'mock/mock_academic_repository.dart';
import 'mock/mock_admissions_repository.dart';
import 'mock/mock_alumni_repository.dart';
import 'mock/mock_academic_operations_repository.dart';
import 'mock/mock_continuity_repository.dart';
import 'mock/mock_workflow_repository.dart';
import 'mock/mock_approval_repository.dart';
import '../approvals/approval_center_service.dart';
import 'mock/mock_finance_repository.dart';
import 'mock/mock_hostel_repository.dart';
import 'api/inventory_finance/hybrid_inventory_finance_repository.dart';
import 'api/inventory/hybrid_inventory_repository.dart';
import 'api/library/hybrid_library_repository.dart';
import 'api/transport/hybrid_transport_repository.dart';
import 'mock/mock_inventory_finance_repository.dart';
import 'mock/mock_inventory_repository.dart';
import 'mock/mock_hr_repository.dart';
import 'mock/mock_library_repository.dart';
import 'mock/mock_management_repository.dart';
import 'mock/mock_sis_repository.dart';
import 'mock/mock_control_center_repository.dart';
import 'mock/mock_platform_intelligence_repository.dart';
import 'mock/mock_director_repository.dart';
import 'mock/mock_predictions_repository.dart';
import 'mock/mock_transport_repository.dart';
import 'mock/mock_onboarding_repository.dart';
import 'mock/mock_startup_onboarding_repository.dart';
import 'mock/mock_parent_repository.dart';
import 'mock/mock_parent_meetings_repository.dart';
import 'mock/mock_teacher_repository.dart';
import 'mock/mock_student_repository.dart';
import '../../features/parent_meetings/parent_meetings_repository.dart';
import '../../features/platform/branch/branch_repository.dart';
import '../../features/platform/franchise/franchise_repository.dart';
import 'repository_config.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  if (isModuleApiEnabled(ref, financeApiEnabledProvider)) {
    return HybridFinanceRepository(
      api: ref.read(apiFinanceRepositoryProvider),
    );
  }
  return MockFinanceRepository();
});

final admissionsRepositoryProvider = Provider<AdmissionsRepository>((ref) {
  if (isModuleApiEnabled(ref, admissionsApiEnabledProvider)) {
    return ref.read(apiAdmissionsRepositoryProvider);
  }
  return MockAdmissionsRepository();
});

final sisRepositoryProvider = Provider<SisRepository>((ref) {
  if (isModuleApiEnabled(ref, sisApiEnabledProvider)) {
    return HybridSisRepository(
      api: ref.read(apiSisRepositoryProvider),
    );
  }
  return MockSisRepository();
});

final academicRepositoryProvider = Provider<AcademicRepository>((ref) {
  if (isModuleApiEnabled(ref, academicApiEnabledProvider)) {
    return HybridAcademicRepository(
      api: ref.read(apiAcademicRepositoryProvider),
    );
  }
  return MockAcademicRepository();
});

final academicOperationsRepositoryProvider =
    Provider<AcademicOperationsRepository>((ref) {
  if (isModuleApiEnabled(ref, academicOperationsApiEnabledProvider)) {
    return HybridAcademicOperationsRepository(
      api: ref.read(apiAcademicOperationsRepositoryProvider),
    );
  }
  return MockAcademicOperationsRepository(
    sisRepository: (() {
      final sis = ref.read(sisRepositoryProvider);
      return sis is MockSisRepository ? sis : MockSisRepository();
    })(),
  );
});

final continuityRepositoryProvider = Provider<ContinuityRepository>((ref) {
  if (isModuleApiEnabled(ref, continuityApiEnabledProvider)) {
    return HybridContinuityRepository(
      api: ref.read(apiContinuityRepositoryProvider),
    );
  }
  return MockContinuityRepository(
    teacherRepository: ref.read(teacherRepositoryProvider),
    communicationRepository: ref.read(communicationRepositoryProvider),
    timetableRepository: ref.read(timetableRepositoryProvider),
    parentRepository: ref.read(parentRepositoryProvider),
  );
});

final workflowRepositoryProvider = Provider<WorkflowRepository>((ref) {
  if (isModuleApiEnabled(ref, workflowApiEnabledProvider)) {
    return HybridWorkflowRepository(
      api: ref.read(apiWorkflowRepositoryProvider),
    );
  }
  return MockWorkflowRepository();
});

final approvalRepositoryProvider = Provider<ApprovalRepository>((ref) {
  if (isModuleApiEnabled(ref, approvalApiEnabledProvider)) {
    return ref.read(apiApprovalRepositoryProvider);
  }
  return MockApprovalRepository();
});

final examAdministrationRepositoryProvider =
    Provider<ExamAdministrationRepository>((ref) {
  if (isModuleApiEnabled(ref, examApiEnabledProvider)) {
    return ref.read(apiExamAdministrationRepositoryProvider);
  }
  return MockExamAdministrationRepository();
});

final attendanceCorrectionRepositoryProvider =
    Provider<AttendanceCorrectionRepository>((ref) {
  if (isModuleApiEnabled(ref, attendanceApiEnabledProvider)) {
    return ref.read(apiAttendanceCorrectionRepositoryProvider);
  }
  return MockAttendanceCorrectionRepository();
});

/// OFFICE / ADMIN attendance reads (ATT-1, ATT-2, ATT-4, ATT-D1, ATT-D2).
final attendanceOfficeRepositoryProvider =
    Provider<AttendanceOfficeRepository>((ref) {
  if (isModuleApiEnabled(ref, attendanceApiEnabledProvider)) {
    return ref.read(apiAttendanceOfficeRepositoryProvider);
  }
  return const MockAttendanceOfficeRepository();
});

final approvalCenterServiceProvider = Provider<ApprovalCenterService>((ref) {
  return ApprovalCenterService(ref.read(approvalRepositoryProvider));
});

final managementRepositoryProvider = Provider<ManagementRepository>((ref) {
  if (isModuleApiEnabled(ref, managementApiEnabledProvider)) {
    return ref.read(apiManagementRepositoryProvider);
  }
  return MockManagementRepository();
});

final transportRepositoryProvider = Provider<TransportRepository>((ref) {
  if (isModuleApiEnabled(ref, transportApiEnabledProvider)) {
    return HybridTransportRepository(
      api: ref.read(apiTransportRepositoryProvider),
      mock: MockTransportRepository(),
    );
  }
  return MockTransportRepository();
});

final hrRepositoryProvider = Provider<HrRepository>((ref) {
  if (isModuleApiEnabled(ref, hrApiEnabledProvider)) {
    return HybridHrRepository(
      api: ref.read(apiHrRepositoryProvider),
      mock: MockHrRepository(),
    );
  }
  return MockHrRepository();
});

final hostelRepositoryProvider = Provider<HostelRepository>((ref) {
  if (isModuleApiEnabled(ref, hostelApiEnabledProvider)) {
    return HybridHostelRepository(
      api: ref.read(apiHostelRepositoryProvider),
      mock: MockHostelRepository(),
    );
  }
  return MockHostelRepository();
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  if (isModuleApiEnabled(ref, inventoryApiEnabledProvider)) {
    return HybridInventoryRepository(
      api: ref.read(apiInventoryRepositoryProvider),
      mock: MockInventoryRepository(),
    );
  }
  return MockInventoryRepository();
});

final inventoryFinanceRepositoryProvider =
    Provider<InventoryFinanceRepository>((ref) {
  if (isModuleApiEnabled(ref, inventoryFinanceApiEnabledProvider)) {
    return HybridInventoryFinanceRepository(
      api: ref.read(apiInventoryFinanceRepositoryProvider),
    );
  }
  return MockInventoryFinanceRepository();
});

final copilotRepositoryProvider = Provider<CopilotRepository>((ref) {
  if (isModuleApiEnabled(ref, aiCopilotApiEnabledProvider)) {
    return HybridCopilotRepository(
      api: ref.read(apiCopilotRepositoryProvider),
    );
  }
  return MockCopilotRepository(
    pipeline: ref.watch(aiInferencePipelineProvider),
  );
});

/// Adaptive AI (W2) — backend Priority/Recommendation feed, Quick Actions and
/// Universal Search. Hybrid when the flag is on (fail-soft to empty), else Mock.
final adaptiveAiRepositoryProvider = Provider<AdaptiveAiRepository>((ref) {
  if (isModuleApiEnabled(ref, adaptiveAiApiEnabledProvider)) {
    return HybridAdaptiveAiRepository(
      api: ref.read(apiAdaptiveAiRepositoryProvider),
    );
  }
  return MockAdaptiveAiRepository();
});

final timetableRepositoryProvider = Provider<TimetableRepository>((ref) {
  if (isModuleApiEnabled(ref, academicTimetableApiEnabledProvider)) {
    return HybridTimetableRepository(
      api: ref.read(apiTimetableRepositoryProvider),
    );
  }
  return MockTimetableRepository();
});

final analyticsIntelligenceRepositoryProvider =
    Provider<AnalyticsIntelligenceRepository>((ref) {
  if (isModuleApiEnabled(ref, analyticsIntelligenceApiEnabledProvider)) {
    return HybridAnalyticsIntelligenceRepository(
      api: ref.read(apiAnalyticsIntelligenceRepositoryProvider),
    );
  }
  return MockAnalyticsIntelligenceRepository();
});

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  if (isModuleApiEnabled(ref, libraryApiEnabledProvider)) {
    return HybridLibraryRepository(
      api: ref.read(apiLibraryRepositoryProvider),
      mock: MockLibraryRepository(),
    );
  }
  return MockLibraryRepository();
});

final alumniRepositoryProvider = Provider<AlumniRepository>((ref) {
  if (isModuleApiEnabled(ref, alumniApiEnabledProvider)) {
    return ref.read(apiAlumniRepositoryProvider);
  }
  return MockAlumniRepository();
});

final controlCenterRepositoryProvider =
    Provider<ControlCenterRepository>((ref) {
  if (isModuleApiEnabled(ref, controlCenterApiEnabledProvider)) {
    return ref.read(apiControlCenterRepositoryProvider);
  }
  return MockControlCenterRepository();
});

final platformIntelligenceRepositoryProvider =
    Provider<PlatformIntelligenceRepository>((ref) {
  if (isModuleApiEnabled(ref, platformIntelligenceApiEnabledProvider)) {
    return ref.read(apiPlatformIntelligenceRepositoryProvider);
  }
  return MockPlatformIntelligenceRepository(
    pipeline: ref.watch(aiInferencePipelineProvider),
  );
});

final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  return MockBranchRepository();
});

final franchiseRepositoryProvider = Provider<FranchiseRepository>((ref) {
  return MockFranchiseRepository();
});

final directorRepositoryProvider = Provider<DirectorRepository>((ref) {
  if (isModuleApiEnabled(ref, directorApiEnabledProvider)) {
    return HybridDirectorRepository(
      api: ref.read(apiDirectorRepositoryProvider),
      mock: MockDirectorRepository(
        pipeline: ref.watch(aiInferencePipelineProvider),
      ),
    );
  }
  return MockDirectorRepository(
      pipeline: ref.watch(aiInferencePipelineProvider));
});

final predictionsRepositoryProvider = Provider<PredictionsRepository>((ref) {
  if (isModuleApiEnabled(ref, predictionsApiEnabledProvider)) {
    return HybridPredictionsRepository(
      api: ref.read(apiPredictionsRepositoryProvider),
      mock: MockPredictionsRepository(),
    );
  }
  return MockPredictionsRepository();
});

final parentRepositoryProvider = Provider<ParentRepository>((ref) {
  if (isModuleApiEnabled(ref, parentApiEnabledProvider)) {
    return ref.read(apiParentRepositoryProvider);
  }
  return MockParentRepository();
});

final parentMeetingsRepositoryProvider =
    Provider<ParentMeetingsRepository>((ref) {
  // MJ-C4 — live parent PTM view reads real ptm_meeting entities; falls back to
  // the mock when the parent module is not in live API mode.
  if (isModuleApiEnabled(ref, parentApiEnabledProvider)) {
    return ref.read(apiParentMeetingsRepositoryProvider);
  }
  return MockParentMeetingsRepository();
});

final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  if (isModuleApiEnabled(ref, teacherApiEnabledProvider)) {
    return ref.read(apiTeacherRepositoryProvider);
  }
  return MockTeacherRepository();
});

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  if (isModuleApiEnabled(ref, studentApiEnabledProvider)) {
    return ref.read(apiStudentRepositoryProvider);
  }
  return MockStudentRepository();
});

final communicationRepositoryProvider =
    Provider<CommunicationRepository>((ref) {
  if (isModuleApiEnabled(ref, communicationApiEnabledProvider)) {
    return HybridCommunicationRepository(
      api: ref.read(apiCommunicationRepositoryProvider),
      mock: MockCommunicationRepository(),
      useApi: true,
    );
  }
  return MockCommunicationRepository();
});

final educationRepositoryProvider = Provider<EducationRepository>((ref) {
  if (isModuleApiEnabled(ref, educationApiEnabledProvider)) {
    return HybridEducationRepository(
      api: ref.read(apiEducationRepositoryProvider),
    );
  }
  return MockEducationRepository();
});

final intelligenceRepositoryProvider = Provider<IntelligenceRepository>((ref) {
  if (isModuleApiEnabled(ref, intelligenceApiEnabledProvider)) {
    return HybridIntelligenceRepository(
      api: ref.read(apiIntelligenceRepositoryProvider),
    );
  }
  return MockIntelligenceRepository();
});

final homeworkIntelligenceRepositoryProvider =
    Provider<HomeworkIntelligenceRepository>((ref) {
  if (isModuleApiEnabled(ref, intelligenceApiEnabledProvider)) {
    return ref.read(apiHomeworkIntelligenceRepositoryProvider);
  }
  return MockHomeworkIntelligenceRepository();
});

final student360RepositoryProvider = Provider<Student360Repository>((ref) {
  if (isModuleApiEnabled(ref, sisApiEnabledProvider)) {
    return ref.read(apiStudent360RepositoryProvider);
  }
  return MockStudent360Repository();
});

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  if (isModuleApiEnabled(ref, employeeApiEnabledProvider)) {
    return ref.read(apiEmployeeRepositoryProvider);
  }
  return MockEmployeeRepository();
});

final inventoryDistributionRepositoryProvider =
    Provider<InventoryDistributionRepository>((ref) {
  if (isModuleApiEnabled(ref, inventoryDistributionApiEnabledProvider)) {
    return ref.read(apiInventoryDistributionRepositoryProvider);
  }
  return MockInventoryDistributionRepository();
});

final parentExperienceRepositoryProvider =
    Provider<ParentExperienceRepository>((ref) {
  if (isModuleApiEnabled(ref, phase5ApiEnabledProvider)) {
    return ref.read(apiParentExperienceRepositoryProvider);
  }
  return MockParentExperienceRepository();
});

final employeeIntelligenceRepositoryProvider =
    Provider<EmployeeIntelligenceRepository>((ref) {
  if (isModuleApiEnabled(ref, phase5ApiEnabledProvider)) {
    return ref.read(apiEmployeeIntelligenceRepositoryProvider);
  }
  return MockEmployeeIntelligenceRepository();
});

final operationsHubRepositoryProvider =
    Provider<OperationsHubRepository>((ref) {
  if (isModuleApiEnabled(ref, phase5ApiEnabledProvider)) {
    return ref.read(apiOperationsHubRepositoryProvider);
  }
  return MockOperationsHubRepository();
});

final schoolMemoriesRepositoryProvider =
    Provider<SchoolMemoriesRepository>((ref) {
  if (isModuleApiEnabled(ref, phase5ApiEnabledProvider)) {
    return ref.read(apiSchoolMemoriesRepositoryProvider);
  }
  return MockSchoolMemoriesRepository();
});

final achievementPromotionRepositoryProvider =
    Provider<AchievementPromotionRepository>((ref) {
  if (isModuleApiEnabled(ref, phase5ApiEnabledProvider)) {
    return ref.read(apiAchievementPromotionRepositoryProvider);
  }
  return MockAchievementPromotionRepository();
});

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  if (isModuleApiEnabled(ref, onboardingApiEnabledProvider)) {
    return ref.read(apiOnboardingRepositoryProvider);
  }
  return MockOnboardingRepository();
});

final startupOnboardingRepositoryProvider =
    Provider<StartupOnboardingRepository>((ref) {
  if (isModuleApiEnabled(ref, onboardingApiEnabledProvider)) {
    return ref.read(hybridStartupOnboardingRepositoryProvider);
  }
  return MockStartupOnboardingRepository();
});

final evolutionRepositoryProvider = Provider<EvolutionRepository>((ref) {
  if (isModuleApiEnabled(ref, evolutionApiEnabledProvider)) {
    return HybridEvolutionRepository(
        api: ref.read(apiEvolutionRepositoryProvider));
  }
  return MockEvolutionRepository();
});

final schoolCompletionRepositoryProvider =
    Provider<SchoolCompletionRepository>((ref) {
  if (isModuleApiEnabled(ref, schoolCompletionApiEnabledProvider)) {
    return HybridSchoolCompletionRepository(
      api: ref.read(apiSchoolCompletionRepositoryProvider),
    );
  }
  return MockSchoolCompletionRepository();
});

final multiSchoolOperationsRepositoryProvider =
    Provider<MultiSchoolOperationsRepository>((ref) {
  if (isModuleApiEnabled(ref, multiSchoolOperationsApiEnabledProvider)) {
    return ref.read(apiMultiSchoolOperationsRepositoryProvider);
  }
  return MockMultiSchoolOperationsRepository();
});

final organizationBuilderRepositoryProvider =
    Provider<OrganizationBuilderRepository>((ref) {
  if (isModuleApiEnabled(ref, organizationBuilderApiEnabledProvider)) {
    return ref.read(apiOrganizationBuilderRepositoryProvider);
  }
  return MockOrganizationBuilderRepository(
    pipeline: ref.watch(aiInferencePipelineProvider),
  );
});

final platformOperationsRepositoryProvider =
    Provider<PlatformOperationsRepository>((ref) {
  if (isModuleApiEnabled(ref, platformOperationsApiEnabledProvider)) {
    return ref.read(apiPlatformOperationsRepositoryProvider);
  }
  return MockPlatformOperationsRepository(
    pipeline: ref.watch(aiInferencePipelineProvider),
  );
});

final healthcareRepositoryProvider = Provider<HealthcareRepository>((ref) {
  if (isModuleApiEnabled(ref, healthcareApiEnabledProvider)) {
    return ref.read(apiHealthcareRepositoryProvider);
  }
  return MockHealthcareRepository(
    pipeline: ref.watch(aiInferencePipelineProvider),
  );
});

final salonRepositoryProvider = Provider<SalonRepository>((ref) {
  if (isModuleApiEnabled(ref, salonApiEnabledProvider)) {
    return ref.read(apiSalonRepositoryProvider);
  }
  return MockSalonRepository(
    pipeline: ref.watch(aiInferencePipelineProvider),
  );
});

final restaurantRepositoryProvider = Provider<RestaurantRepository>((ref) {
  if (isModuleApiEnabled(ref, restaurantApiEnabledProvider)) {
    return ref.read(apiRestaurantRepositoryProvider);
  }
  return MockRestaurantRepository(
    pipeline: ref.watch(aiInferencePipelineProvider),
  );
});

final accommodationRepositoryProvider =
    Provider<AccommodationRepository>((ref) {
  if (isModuleApiEnabled(ref, accommodationApiEnabledProvider)) {
    return ref.read(apiAccommodationRepositoryProvider);
  }
  return MockAccommodationRepository(
    pipeline: ref.watch(aiInferencePipelineProvider),
  );
});

final whiteLabelPlatformRepositoryProvider =
    Provider<WhiteLabelPlatformRepository>((ref) {
  if (isModuleApiEnabled(ref, whiteLabelPlatformApiEnabledProvider)) {
    return ref.read(apiWhiteLabelPlatformRepositoryProvider);
  }
  return MockWhiteLabelPlatformRepository();
});
