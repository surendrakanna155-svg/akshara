import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_inference_providers.dart';
import '../../network/dio_provider.dart';
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
import 'parent/remote/parent_remote_datasource.dart';
import 'teacher/api_teacher_repository.dart';
import 'teacher/remote/teacher_remote_datasource.dart';
import 'student/api_student_repository.dart';
import 'student/remote/student_remote_datasource.dart';
import 'copilot/api_copilot_repository.dart';
import 'copilot/remote/copilot_remote_datasource.dart';
import 'timetable/api_timetable_repository.dart';
import 'timetable/remote/timetable_remote_datasource.dart';
import 'analytics/api_analytics_intelligence_repository.dart';
import 'analytics/remote/analytics_intelligence_remote_datasource.dart';
import 'communication/api_communication_repository.dart';
import 'communication/remote/communication_remote_datasource.dart';
import 'onboarding/api_onboarding_repository.dart';
import 'onboarding/remote/onboarding_remote_datasource.dart';
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
import 'organization_builder/api_organization_builder_repository.dart';
import 'organization_builder/remote/organization_builder_remote_datasource.dart';
import 'platform_operations/api_platform_operations_repository.dart';
import 'platform_operations/remote/platform_operations_remote_datasource.dart';

final admissionsRemoteDataSourceProvider = Provider<AdmissionsRemoteDataSource>(
  (ref) => AdmissionsRemoteDataSource(ref.watch(dioProvider)),
);

final financeRemoteDataSourceProvider = Provider<FinanceRemoteDataSource>(
  (ref) => FinanceRemoteDataSource(ref.watch(dioProvider)),
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
  (ref) => ParentRemoteDataSource(ref.watch(dioProvider)),
);

final teacherRemoteDataSourceProvider = Provider<TeacherRemoteDataSource>(
  (ref) => TeacherRemoteDataSource(ref.watch(dioProvider)),
);

final studentRemoteDataSourceProvider = Provider<StudentRemoteDataSource>(
  (ref) => StudentRemoteDataSource(ref.watch(dioProvider)),
);

final apiParentRepositoryProvider = Provider<ApiParentRepository>(
  (ref) => ApiParentRepository(
    remote: ref.watch(parentRemoteDataSourceProvider),
  ),
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

final apiCommunicationRepositoryProvider = Provider<ApiCommunicationRepository>(
  (ref) => ApiCommunicationRepository(
    remote: ref.watch(communicationRemoteDataSourceProvider),
  ),
);

final onboardingRemoteDataSourceProvider = Provider<OnboardingRemoteDataSource>(
  (ref) => OnboardingRemoteDataSource(ref.watch(dioProvider)),
);

final apiOnboardingRepositoryProvider = Provider<ApiOnboardingRepository>(
  (ref) => ApiOnboardingRepository(
    remote: ref.watch(onboardingRemoteDataSourceProvider),
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
