import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_inference_providers.dart';
import '../../network/dio_provider.dart';
import '../../reliability/reliability_providers.dart';
import '../academic/api/academic_remote_data_source.dart';
import '../academic/api/api_academic_repository.dart';
import 'academic_operations/api_academic_operations_repository.dart';
import 'academic_operations/remote/academic_operations_remote_datasource.dart';
import 'continuity/api_continuity_repository.dart';
import 'continuity/remote/continuity_remote_datasource.dart';
import 'workflow/api_workflow_repository.dart';
import 'workflow/remote/workflow_remote_datasource.dart';
import 'admissions/api_admissions_repository.dart';
import 'admissions/remote/admissions_remote_datasource.dart';
import 'finance/api_finance_repository.dart';
import 'finance/remote/finance_remote_datasource.dart';
import 'management/api_management_repository.dart';
import 'management/remote/management_remote_datasource.dart';
import 'sis/api_sis_repository.dart';
import 'sis/remote/sis_remote_datasource.dart';
import 'alumni/api_alumni_repository.dart';
import 'alumni/remote/alumni_remote_datasource.dart';
import 'hostel/api_hostel_repository.dart';
import 'hostel/remote/hostel_remote_datasource.dart';
import 'hr/api_hr_repository.dart';
import 'hr/remote/hr_remote_datasource.dart';
import 'transport/api_transport_repository.dart';
import 'transport/remote/transport_remote_datasource.dart';
import 'inventory/api_inventory_repository.dart';
import 'inventory/remote/inventory_remote_datasource.dart';
import 'inventory_finance/api_inventory_finance_repository.dart';
import 'inventory_finance/remote/inventory_finance_remote_datasource.dart';
import 'library/api_library_repository.dart';
import 'library/remote/library_remote_datasource.dart';
import 'control_center/api_control_center_repository.dart';
import 'control_center/remote/control_center_remote_datasource.dart';
import 'platform_intelligence/api_platform_intelligence_repository.dart';
import 'platform_intelligence/remote/platform_intelligence_remote_datasource.dart';
import 'parent/api_parent_repository.dart';
import 'parent/api_parent_meetings_repository.dart';
import 'parent/remote/parent_remote_datasource.dart';
import 'teacher/api_teacher_repository.dart';
import 'teacher/remote/teacher_remote_datasource.dart';
import 'student/api_student_repository.dart';
import 'student/remote/student_remote_datasource.dart';
import 'copilot/api_copilot_repository.dart';
import 'copilot/remote/copilot_remote_datasource.dart';
import 'timetable/api_timetable_repository.dart';
import 'timetable/remote/timetable_remote_datasource.dart';
import 'approval/api_approval_repository.dart';
import 'approval/remote/approval_remote_datasource.dart';
import 'analytics/api_analytics_intelligence_repository.dart';
import 'analytics/remote/analytics_intelligence_remote_datasource.dart';
import 'communication/api_communication_repository.dart';
import 'communication/remote/communication_api_paths.dart';
import 'communication/remote/communication_remote_datasource.dart';
import '../../security/erp_role.dart';
import '../../security/rbac_service.dart';
import 'onboarding/api_onboarding_repository.dart';
import 'onboarding/remote/onboarding_remote_datasource.dart';
import 'startup_onboarding/api_startup_onboarding_repository.dart';
import 'startup_onboarding/hybrid_startup_onboarding_repository.dart';
import 'startup_onboarding/remote/startup_onboarding_remote_datasource.dart';
import 'attendance/api_attendance_correction_repository.dart';
import 'attendance/remote/attendance_correction_remote_datasource.dart';
import 'exam_administration/api_exam_administration_repository.dart';
import 'exam_administration/remote/exam_remote_datasource.dart';
import 'education/api_education_repository.dart';
import 'education/remote/education_remote_datasource.dart';
import 'intelligence/api_intelligence_repository.dart';
import 'intelligence/remote/intelligence_remote_datasource.dart';
import 'phase4/api_phase4_repositories.dart';
import 'phase4/phase4_remote_datasource.dart';
import 'phase5/api_phase5_repositories.dart';
import 'phase5/phase5_remote_datasource.dart';
import 'evolution/api_evolution_repository.dart';
import 'evolution/remote/evolution_remote_datasource.dart';
import 'school_completion/api_school_completion_repository.dart';
import 'school_completion/remote/school_completion_remote_datasource.dart';
import 'multi_school/api_multi_school_operations_repository.dart';
import 'multi_school/remote/multi_school_operations_remote_datasource.dart';
import 'director/api_director_repository.dart';
import 'director/remote/director_remote_datasource.dart';
import 'predictions/api_predictions_repository.dart';
import 'predictions/remote/predictions_remote_datasource.dart';
import 'organization_builder/api_organization_builder_repository.dart';
import 'organization_builder/remote/organization_builder_remote_datasource.dart';
import 'platform_operations/api_platform_operations_repository.dart';
import 'platform_operations/remote/platform_operations_remote_datasource.dart';
import 'healthcare/api_healthcare_repository.dart';
import 'healthcare/remote/healthcare_remote_datasource.dart';
import 'salon/api_salon_repository.dart';
import 'salon/remote/salon_remote_datasource.dart';
import 'restaurant/api_restaurant_repository.dart';
import 'restaurant/remote/restaurant_remote_datasource.dart';
import 'accommodation/api_accommodation_repository.dart';
import 'accommodation/remote/accommodation_remote_datasource.dart';
import 'white_label/api_white_label_platform_repository.dart';
import 'white_label/remote/white_label_remote_datasource.dart';

final admissionsRemoteDataSourceProvider = Provider<AdmissionsRemoteDataSource>(
  (ref) => AdmissionsRemoteDataSource(ref.watch(dioProvider)),
);

final financeRemoteDataSourceProvider = Provider<FinanceRemoteDataSource>(
  (ref) => FinanceRemoteDataSource(
    ref.watch(dioProvider),
    reliableWriter: ref.watch(reliableWriterProvider),
  ),
);

final sisRemoteDataSourceProvider = Provider<SisRemoteDataSource>(
  (ref) => SisRemoteDataSource(ref.watch(dioProvider)),
);

final academicRemoteDataSourceProvider = Provider<AcademicRemoteDataSource>(
  (ref) => AcademicRemoteDataSource(ref.watch(dioProvider)),
);
final academicOperationsRemoteDataSourceProvider =
    Provider<AcademicOperationsRemoteDataSource>(
  (ref) => AcademicOperationsRemoteDataSource(ref.watch(dioProvider)),
);
final continuityRemoteDataSourceProvider = Provider<ContinuityRemoteDataSource>(
  (ref) => ContinuityRemoteDataSource(ref.watch(dioProvider)),
);
final workflowRemoteDataSourceProvider = Provider<WorkflowRemoteDataSource>(
  (ref) => WorkflowRemoteDataSource(ref.watch(dioProvider)),
);

final managementRemoteDataSourceProvider = Provider<ManagementRemoteDataSource>(
  (ref) => ManagementRemoteDataSource(ref.watch(dioProvider)),
);

final transportRemoteDataSourceProvider = Provider<TransportRemoteDataSource>(
  (ref) => TransportRemoteDataSource(ref.watch(dioProvider)),
);

final hrRemoteDataSourceProvider = Provider<HrRemoteDataSource>(
  (ref) => HrRemoteDataSource(ref.watch(dioProvider)),
);

final hostelRemoteDataSourceProvider = Provider<HostelRemoteDataSource>(
  (ref) => HostelRemoteDataSource(ref.watch(dioProvider)),
);

final alumniRemoteDataSourceProvider = Provider<AlumniRemoteDataSource>(
  (ref) => AlumniRemoteDataSource(ref.watch(dioProvider)),
);

final apiAdmissionsRepositoryProvider = Provider<ApiAdmissionsRepository>(
  (ref) => ApiAdmissionsRepository(
    remote: ref.watch(admissionsRemoteDataSourceProvider),
  ),
);

final apiFinanceRepositoryProvider = Provider<ApiFinanceRepository>(
  (ref) => ApiFinanceRepository(
    remote: ref.watch(financeRemoteDataSourceProvider),
  ),
);

final apiSisRepositoryProvider = Provider<ApiSisRepository>(
  (ref) => ApiSisRepository(remote: ref.watch(sisRemoteDataSourceProvider)),
);

final apiAcademicRepositoryProvider = Provider<ApiAcademicRepository>(
  (ref) => ApiAcademicRepository(
    remote: ref.watch(academicRemoteDataSourceProvider),
  ),
);
final apiAcademicOperationsRepositoryProvider =
    Provider<ApiAcademicOperationsRepository>(
  (ref) => ApiAcademicOperationsRepository(
    remote: ref.watch(academicOperationsRemoteDataSourceProvider),
  ),
);
final apiContinuityRepositoryProvider = Provider<ApiContinuityRepository>(
  (ref) => ApiContinuityRepository(
    remote: ref.watch(continuityRemoteDataSourceProvider),
  ),
);
final apiWorkflowRepositoryProvider = Provider<ApiWorkflowRepository>(
  (ref) => ApiWorkflowRepository(
    remote: ref.watch(workflowRemoteDataSourceProvider),
  ),
);

final apiManagementRepositoryProvider = Provider<ApiManagementRepository>(
  (ref) => ApiManagementRepository(
    remote: ref.watch(managementRemoteDataSourceProvider),
  ),
);

final apiTransportRepositoryProvider = Provider<ApiTransportRepository>(
  (ref) => ApiTransportRepository(
    remote: ref.watch(transportRemoteDataSourceProvider),
  ),
);

final apiHrRepositoryProvider = Provider<ApiHrRepository>(
  (ref) => ApiHrRepository(
    remote: ref.watch(hrRemoteDataSourceProvider),
  ),
);

final apiHostelRepositoryProvider = Provider<ApiHostelRepository>(
  (ref) => ApiHostelRepository(
    remote: ref.watch(hostelRemoteDataSourceProvider),
  ),
);

final apiAlumniRepositoryProvider = Provider<ApiAlumniRepository>(
  (ref) => ApiAlumniRepository(
    remote: ref.watch(alumniRemoteDataSourceProvider),
  ),
);

final inventoryRemoteDataSourceProvider = Provider<InventoryRemoteDataSource>(
  (ref) => InventoryRemoteDataSource(ref.watch(dioProvider)),
);

final apiInventoryRepositoryProvider = Provider<ApiInventoryRepository>(
  (ref) => ApiInventoryRepository(
    remote: ref.watch(inventoryRemoteDataSourceProvider),
  ),
);

final inventoryFinanceRemoteDataSourceProvider =
    Provider<InventoryFinanceRemoteDataSource>(
  (ref) => InventoryFinanceRemoteDataSource(ref.watch(dioProvider)),
);

final apiInventoryFinanceRepositoryProvider =
    Provider<ApiInventoryFinanceRepository>(
  (ref) => ApiInventoryFinanceRepository(
    remote: ref.watch(inventoryFinanceRemoteDataSourceProvider),
  ),
);

final copilotRemoteDataSourceProvider = Provider<CopilotRemoteDataSource>(
  (ref) => CopilotRemoteDataSource(ref.watch(dioProvider)),
);

final apiCopilotRepositoryProvider = Provider<ApiCopilotRepository>(
  (ref) => ApiCopilotRepository(
    remote: ref.watch(copilotRemoteDataSourceProvider),
  ),
);

final timetableRemoteDataSourceProvider = Provider<TimetableRemoteDataSource>(
  (ref) => TimetableRemoteDataSource(ref.watch(dioProvider)),
);

final apiTimetableRepositoryProvider = Provider<ApiTimetableRepository>(
  (ref) => ApiTimetableRepository(
    remote: ref.watch(timetableRemoteDataSourceProvider),
  ),
);

final analyticsIntelligenceRemoteDataSourceProvider =
    Provider<AnalyticsIntelligenceRemoteDataSource>(
  (ref) => AnalyticsIntelligenceRemoteDataSource(ref.watch(dioProvider)),
);

final apiAnalyticsIntelligenceRepositoryProvider =
    Provider<ApiAnalyticsIntelligenceRepository>(
  (ref) => ApiAnalyticsIntelligenceRepository(
    remote: ref.watch(analyticsIntelligenceRemoteDataSourceProvider),
  ),
);

final libraryRemoteDataSourceProvider = Provider<LibraryRemoteDataSource>(
  (ref) => LibraryRemoteDataSource(ref.watch(dioProvider)),
);

final apiLibraryRepositoryProvider = Provider<ApiLibraryRepository>(
  (ref) => ApiLibraryRepository(
    remote: ref.watch(libraryRemoteDataSourceProvider),
  ),
);

final controlCenterRemoteDataSourceProvider =
    Provider<ControlCenterRemoteDataSource>(
  (ref) => ControlCenterRemoteDataSource(ref.watch(dioProvider)),
);

final apiControlCenterRepositoryProvider = Provider<ApiControlCenterRepository>(
  (ref) => ApiControlCenterRepository(
    remote: ref.watch(controlCenterRemoteDataSourceProvider),
  ),
);

final platformIntelligenceRemoteDataSourceProvider =
    Provider<PlatformIntelligenceRemoteDataSource>(
  (ref) => PlatformIntelligenceRemoteDataSource(ref.watch(dioProvider)),
);

final apiPlatformIntelligenceRepositoryProvider =
    Provider<ApiPlatformIntelligenceRepository>(
  (ref) => ApiPlatformIntelligenceRepository(
    remote: ref.watch(platformIntelligenceRemoteDataSourceProvider),
    pipeline: ref.watch(aiInferencePipelineProvider),
  ),
);

final parentRemoteDataSourceProvider = Provider<ParentRemoteDataSource>(
  (ref) => ParentRemoteDataSource(
    ref.watch(dioProvider),
    reliableWriter: ref.watch(reliableWriterProvider),
  ),
);

final teacherRemoteDataSourceProvider = Provider<TeacherRemoteDataSource>(
  (ref) => TeacherRemoteDataSource(
    ref.watch(dioProvider),
    reliableWriter: ref.watch(reliableWriterProvider),
  ),
);

final studentRemoteDataSourceProvider = Provider<StudentRemoteDataSource>(
  (ref) => StudentRemoteDataSource(ref.watch(dioProvider)),
);

final apiParentRepositoryProvider = Provider<ApiParentRepository>(
  (ref) => ApiParentRepository(
    remote: ref.watch(parentRemoteDataSourceProvider),
  ),
);

final apiParentMeetingsRepositoryProvider =
    Provider<ApiParentMeetingsRepository>(
  (ref) => ApiParentMeetingsRepository(ref.watch(dioProvider)),
);

final apiTeacherRepositoryProvider = Provider<ApiTeacherRepository>(
  (ref) => ApiTeacherRepository(
    remote: ref.watch(teacherRemoteDataSourceProvider),
  ),
);

final apiStudentRepositoryProvider = Provider<ApiStudentRepository>(
  (ref) => ApiStudentRepository(
    remote: ref.watch(studentRemoteDataSourceProvider),
  ),
);

final communicationRemoteDataSourceProvider =
    Provider<CommunicationRemoteDataSource>(
  (ref) => CommunicationRemoteDataSource(ref.watch(dioProvider)),
);

/// MJ-M2: the active persona decides which notification routes the repository
/// hits. A student persona must read /student/notifications (and the matching
/// mark-read / device-token routes — derived inside the repository from this
/// path); a parent persona keeps /parent/*. Driven off the same RBAC role state
/// the rest of the app reads (rbacServiceProvider), so a student no longer hits
/// the parent-only route (403 -> demo fallback) and never invokes its own.
final apiCommunicationRepositoryProvider = Provider<ApiCommunicationRepository>(
  (ref) {
    final rbac = ref.watch(rbacServiceProvider);
    // Branch to student only when the active persona is a student and is NOT a
    // parent (a parent persona keeps the parent routes); mirrors how other
    // persona-scoped repositories resolve their role.
    final isStudentPersona =
        rbac.hasRole(ErpRole.student) && !rbac.hasRole(ErpRole.parent);
    return ApiCommunicationRepository(
      remote: ref.watch(communicationRemoteDataSourceProvider),
      notificationsPath: isStudentPersona
          ? CommunicationApiPaths.studentNotifications
          : CommunicationApiPaths.parentNotifications,
    );
  },
);

final onboardingRemoteDataSourceProvider = Provider<OnboardingRemoteDataSource>(
  (ref) => OnboardingRemoteDataSource(ref.watch(dioProvider)),
);

final apiOnboardingRepositoryProvider = Provider<ApiOnboardingRepository>(
  (ref) => ApiOnboardingRepository(
    remote: ref.watch(onboardingRemoteDataSourceProvider),
  ),
);

final startupOnboardingRemoteDataSourceProvider =
    Provider<StartupOnboardingRemoteDataSource>(
  (ref) => StartupOnboardingRemoteDataSource(ref.watch(dioProvider)),
);

final apiStartupOnboardingRepositoryProvider =
    Provider<ApiStartupOnboardingRepository>(
  (ref) => ApiStartupOnboardingRepository(
    remote: ref.watch(startupOnboardingRemoteDataSourceProvider),
  ),
);

final hybridStartupOnboardingRepositoryProvider =
    Provider<HybridStartupOnboardingRepository>(
  (ref) => HybridStartupOnboardingRepository(
    api: ref.watch(apiStartupOnboardingRepositoryProvider),
  ),
);

final educationRemoteDataSourceProvider = Provider<EducationRemoteDataSource>(
  (ref) => EducationRemoteDataSource(ref.watch(dioProvider)),
);

final apiEducationRepositoryProvider = Provider<ApiEducationRepository>(
  (ref) => ApiEducationRepository(
    remote: ref.watch(educationRemoteDataSourceProvider),
  ),
);

final intelligenceRemoteDataSourceProvider =
    Provider<IntelligenceRemoteDataSource>(
  (ref) => IntelligenceRemoteDataSource(ref.watch(dioProvider)),
);

final apiIntelligenceRepositoryProvider = Provider<ApiIntelligenceRepository>(
  (ref) => ApiIntelligenceRepository(
    remote: ref.watch(intelligenceRemoteDataSourceProvider),
  ),
);

final phase4RemoteDataSourceProvider = Provider<Phase4RemoteDataSource>(
  (ref) => Phase4RemoteDataSource(ref.watch(dioProvider)),
);

final apiHomeworkIntelligenceRepositoryProvider =
    Provider<ApiHomeworkIntelligenceRepository>(
  (ref) => ApiHomeworkIntelligenceRepository(
      remote: ref.watch(phase4RemoteDataSourceProvider)),
);

final apiStudent360RepositoryProvider = Provider<ApiStudent360Repository>(
  (ref) => ApiStudent360Repository(
      remote: ref.watch(phase4RemoteDataSourceProvider)),
);

final apiEmployeeRepositoryProvider = Provider<ApiEmployeeRepository>(
  (ref) =>
      ApiEmployeeRepository(remote: ref.watch(phase4RemoteDataSourceProvider)),
);

final apiInventoryDistributionRepositoryProvider =
    Provider<ApiInventoryDistributionRepository>(
  (ref) => ApiInventoryDistributionRepository(
      remote: ref.watch(phase4RemoteDataSourceProvider)),
);

final phase5RemoteDataSourceProvider = Provider<Phase5RemoteDataSource>(
  (ref) => Phase5RemoteDataSource(ref.watch(dioProvider)),
);

final apiParentExperienceRepositoryProvider =
    Provider<ApiParentExperienceRepository>(
  (ref) => ApiParentExperienceRepository(
      remote: ref.watch(phase5RemoteDataSourceProvider)),
);

final apiEmployeeIntelligenceRepositoryProvider =
    Provider<ApiEmployeeIntelligenceRepository>(
  (ref) => ApiEmployeeIntelligenceRepository(
      remote: ref.watch(phase5RemoteDataSourceProvider)),
);

final apiOperationsHubRepositoryProvider = Provider<ApiOperationsHubRepository>(
  (ref) => ApiOperationsHubRepository(
      remote: ref.watch(phase5RemoteDataSourceProvider)),
);

final apiSchoolMemoriesRepositoryProvider =
    Provider<ApiSchoolMemoriesRepository>(
  (ref) => ApiSchoolMemoriesRepository(
      remote: ref.watch(phase5RemoteDataSourceProvider)),
);

final apiAchievementPromotionRepositoryProvider =
    Provider<ApiAchievementPromotionRepository>(
  (ref) => ApiAchievementPromotionRepository(
      remote: ref.watch(phase5RemoteDataSourceProvider)),
);

final evolutionRemoteDataSourceProvider = Provider<EvolutionRemoteDataSource>(
  (ref) => EvolutionRemoteDataSource(ref.watch(dioProvider)),
);

final apiEvolutionRepositoryProvider = Provider<ApiEvolutionRepository>(
  (ref) => ApiEvolutionRepository(
      remote: ref.watch(evolutionRemoteDataSourceProvider)),
);

final schoolCompletionRemoteDataSourceProvider =
    Provider<SchoolCompletionRemoteDataSource>(
  (ref) => SchoolCompletionRemoteDataSource(ref.watch(dioProvider)),
);

final apiSchoolCompletionRepositoryProvider =
    Provider<ApiSchoolCompletionRepository>(
  (ref) => ApiSchoolCompletionRepository(
    remote: ref.watch(schoolCompletionRemoteDataSourceProvider),
  ),
);

final multiSchoolOperationsRemoteDataSourceProvider =
    Provider<MultiSchoolOperationsRemoteDataSource>(
  (ref) => MultiSchoolOperationsRemoteDataSource(ref.watch(dioProvider)),
);

final apiMultiSchoolOperationsRepositoryProvider =
    Provider<ApiMultiSchoolOperationsRepository>(
  (ref) => ApiMultiSchoolOperationsRepository(
    remote: ref.watch(multiSchoolOperationsRemoteDataSourceProvider),
  ),
);

final directorRemoteDataSourceProvider = Provider<DirectorRemoteDataSource>(
  (ref) => DirectorRemoteDataSource(ref.watch(dioProvider)),
);

final apiDirectorRepositoryProvider = Provider<ApiDirectorRepository>(
  (ref) => ApiDirectorRepository(
    remote: ref.watch(directorRemoteDataSourceProvider),
  ),
);

final predictionsRemoteDataSourceProvider =
    Provider<PredictionsRemoteDataSource>(
  (ref) => PredictionsRemoteDataSource(ref.watch(dioProvider)),
);

final apiPredictionsRepositoryProvider = Provider<ApiPredictionsRepository>(
  (ref) => ApiPredictionsRepository(
    remote: ref.watch(predictionsRemoteDataSourceProvider),
  ),
);

final organizationBuilderRemoteDataSourceProvider =
    Provider<OrganizationBuilderRemoteDataSource>(
  (ref) => OrganizationBuilderRemoteDataSource(ref.watch(dioProvider)),
);

final apiOrganizationBuilderRepositoryProvider =
    Provider<ApiOrganizationBuilderRepository>(
  (ref) => ApiOrganizationBuilderRepository(
    remote: ref.watch(organizationBuilderRemoteDataSourceProvider),
  ),
);

final platformOperationsRemoteDataSourceProvider =
    Provider<PlatformOperationsRemoteDataSource>(
  (ref) => PlatformOperationsRemoteDataSource(ref.watch(dioProvider)),
);

final apiPlatformOperationsRepositoryProvider =
    Provider<ApiPlatformOperationsRepository>(
  (ref) => ApiPlatformOperationsRepository(
    remote: ref.watch(platformOperationsRemoteDataSourceProvider),
  ),
);

final healthcareRemoteDataSourceProvider =
    Provider<HealthcareRemoteDataSource>(
  (ref) => HealthcareRemoteDataSource(ref.watch(dioProvider)),
);

final apiHealthcareRepositoryProvider = Provider<ApiHealthcareRepository>(
  (ref) => ApiHealthcareRepository(
    remote: ref.watch(healthcareRemoteDataSourceProvider),
  ),
);

final salonRemoteDataSourceProvider = Provider<SalonRemoteDataSource>(
  (ref) => SalonRemoteDataSource(ref.watch(dioProvider)),
);

final apiSalonRepositoryProvider = Provider<ApiSalonRepository>(
  (ref) => ApiSalonRepository(
    remote: ref.watch(salonRemoteDataSourceProvider),
  ),
);

final restaurantRemoteDataSourceProvider =
    Provider<RestaurantRemoteDataSource>(
  (ref) => RestaurantRemoteDataSource(ref.watch(dioProvider)),
);

final apiRestaurantRepositoryProvider = Provider<ApiRestaurantRepository>(
  (ref) => ApiRestaurantRepository(
    remote: ref.watch(restaurantRemoteDataSourceProvider),
  ),
);

final accommodationRemoteDataSourceProvider =
    Provider<AccommodationRemoteDataSource>(
  (ref) => AccommodationRemoteDataSource(ref.watch(dioProvider)),
);

final apiAccommodationRepositoryProvider =
    Provider<ApiAccommodationRepository>(
  (ref) => ApiAccommodationRepository(
    remote: ref.watch(accommodationRemoteDataSourceProvider),
  ),
);

final whiteLabelRemoteDataSourceProvider =
    Provider<WhiteLabelRemoteDataSource>(
  (ref) => WhiteLabelRemoteDataSource(ref.watch(dioProvider)),
);

final apiWhiteLabelPlatformRepositoryProvider =
    Provider<ApiWhiteLabelPlatformRepository>(
  (ref) => ApiWhiteLabelPlatformRepository(
    remote: ref.watch(whiteLabelRemoteDataSourceProvider),
  ),
);

final approvalRemoteDataSourceProvider = Provider<ApprovalRemoteDataSource>(
  (ref) => ApprovalRemoteDataSource(ref.watch(dioProvider)),
);

final apiApprovalRepositoryProvider = Provider<ApiApprovalRepository>(
  (ref) => ApiApprovalRepository(
    remote: ref.watch(approvalRemoteDataSourceProvider),
  ),
);

final examRemoteDataSourceProvider = Provider<ExamRemoteDataSource>(
  (ref) => ExamRemoteDataSource(
    ref.watch(dioProvider),
    reliableWriter: ref.watch(reliableWriterProvider),
  ),
);

final apiExamAdministrationRepositoryProvider =
    Provider<ApiExamAdministrationRepository>(
  (ref) => ApiExamAdministrationRepository(
    remote: ref.watch(examRemoteDataSourceProvider),
  ),
);

final attendanceCorrectionRemoteDataSourceProvider =
    Provider<AttendanceCorrectionRemoteDataSource>(
  (ref) => AttendanceCorrectionRemoteDataSource(ref.watch(dioProvider)),
);

final apiAttendanceCorrectionRepositoryProvider =
    Provider<ApiAttendanceCorrectionRepository>(
  (ref) => ApiAttendanceCorrectionRepository(
    remote: ref.watch(attendanceCorrectionRemoteDataSourceProvider),
  ),
);
