import 'permissions.dart';

/// Describes a guarded mutation and its required permission.
class MutationPermissionEntry {
  const MutationPermissionEntry({
    required this.moduleId,
    required this.mutationId,
    required this.permission,
    required this.kind,
  });

  final String moduleId;
  final String mutationId;
  final Permission permission;

  /// `manage` or `approve`.
  final String kind;
}

/// Inventory of provider-level mutations and required RBAC permissions.
class MutationPermissionRegistry {
  const MutationPermissionRegistry._();

  static const entries = <MutationPermissionEntry>[
    // Admissions
    MutationPermissionEntry(
      moduleId: 'admissions',
      mutationId: 'createLead',
      permission: Permission.manageAdmissions,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'admissions',
      mutationId: 'updateLead',
      permission: Permission.manageAdmissions,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'admissions',
      mutationId: 'updateSettings',
      permission: Permission.manageAdmissions,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'admissions',
      mutationId: 'approveApplication',
      permission: Permission.approveAdmissions,
      kind: 'approve',
    ),
    MutationPermissionEntry(
      moduleId: 'admissions',
      mutationId: 'rejectApplication',
      permission: Permission.approveAdmissions,
      kind: 'approve',
    ),
    // Finance
    MutationPermissionEntry(
      moduleId: 'finance',
      mutationId: 'createFeeStructure',
      permission: Permission.manageFinance,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'finance',
      mutationId: 'approveRefund',
      permission: Permission.approveRefunds,
      kind: 'approve',
    ),
    MutationPermissionEntry(
      moduleId: 'finance',
      mutationId: 'createScholarship',
      permission: Permission.manageFinance,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'finance',
      mutationId: 'issueInvoice',
      permission: Permission.manageFinance,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'finance',
      mutationId: 'cancelInvoice',
      permission: Permission.manageFinance,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'finance',
      mutationId: 'cancelCollection',
      permission: Permission.manageFinance,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'finance',
      mutationId: 'recordOfflinePayment',
      permission: Permission.manageFinance,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'finance',
      mutationId: 'reconcileOfflinePayment',
      permission: Permission.manageFinance,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'finance',
      mutationId: 'createQrPaymentSession',
      permission: Permission.manageFinance,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'finance',
      mutationId: 'confirmQrPaymentSession',
      permission: Permission.manageFinance,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'finance',
      mutationId: 'exportReceiptPdf',
      permission: Permission.manageFinance,
      kind: 'manage',
    ),
    // SIS
    MutationPermissionEntry(
      moduleId: 'sis',
      mutationId: 'registerStudent',
      permission: Permission.manageSis,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'sis',
      mutationId: 'assignAcademic',
      permission: Permission.manageSis,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'sis',
      mutationId: 'updateStudent',
      permission: Permission.manageSis,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'sis',
      mutationId: 'uploadStudentDocument',
      permission: Permission.manageSis,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'sis',
      mutationId: 'previewYearTransition',
      permission: Permission.manageSis,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'sis',
      mutationId: 'executeYearTransition',
      permission: Permission.manageSis,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'sis',
      mutationId: 'executeReshufflePlan',
      permission: Permission.manageSis,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'sis',
      mutationId: 'previewContinuityMigration',
      permission: Permission.manageSis,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'sis',
      mutationId: 'executeContinuityMigration',
      permission: Permission.manageSis,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'sis',
      mutationId: 'transferMessageOwnership',
      permission: Permission.manageCommunication,
      kind: 'manage',
    ),
    // Management
    MutationPermissionEntry(
      moduleId: 'management',
      mutationId: 'resolveManagementApproval',
      permission: Permission.manageManagement,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'management',
      mutationId: 'updateManagementSettings',
      permission: Permission.manageManagement,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'management',
      mutationId: 'exportManagementDashboard',
      permission: Permission.manageManagement,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'management',
      mutationId: 'dismissOperationsHubAlert',
      permission: Permission.manageManagement,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'management',
      mutationId: 'completeOperationsHubAction',
      permission: Permission.manageManagement,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'resource_optimization',
      mutationId: 'applyResourceOptimizationRecommendation',
      permission: Permission.manageManagement,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'resource_optimization',
      mutationId: 'dismissResourceOptimizationRecommendation',
      permission: Permission.manageManagement,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'multi_school',
      mutationId: 'activateSchool',
      permission: Permission.manageMultiSchoolOperations,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'multi_school',
      mutationId: 'deactivateSchool',
      permission: Permission.manageMultiSchoolOperations,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'multi_school',
      mutationId: 'completeOnboarding',
      permission: Permission.manageMultiSchoolOperations,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'multi_school',
      mutationId: 'dismissAlert',
      permission: Permission.manageMultiSchoolOperations,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'multi_school',
      mutationId: 'completeAction',
      permission: Permission.manageMultiSchoolOperations,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'organization_builder',
      mutationId: 'saveInterviewStep',
      permission: Permission.manageOrganizationBuilder,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'organization_builder',
      mutationId: 'generatePreview',
      permission: Permission.manageOrganizationBuilder,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'organization_builder',
      mutationId: 'startProvisioning',
      permission: Permission.manageOrganizationBuilder,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'platform_operations',
      mutationId: 'acknowledgeAlert',
      permission: Permission.managePlatformOperations,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'platform_operations',
      mutationId: 'runTenantVerification',
      permission: Permission.managePlatformOperations,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'platform_operations',
      mutationId: 'completeAccessReview',
      permission: Permission.managePlatformOperations,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'industry_framework',
      mutationId: 'setActiveIndustry',
      permission: Permission.manageIndustryFramework,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'industry_framework',
      mutationId: 'activateIndustryModule',
      permission: Permission.manageIndustryFramework,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'healthcare',
      mutationId: 'bookAppointment',
      permission: Permission.manageHealthcare,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'healthcare',
      mutationId: 'registerPatient',
      permission: Permission.manageHealthcare,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'salon',
      mutationId: 'bookSalonAppointment',
      permission: Permission.manageSalonBusiness,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'salon',
      mutationId: 'registerSalonCustomer',
      permission: Permission.manageSalonBusiness,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'restaurant',
      mutationId: 'createRestaurantOrder',
      permission: Permission.manageRestaurantHospitality,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'restaurant',
      mutationId: 'updateKitchenTicket',
      permission: Permission.manageRestaurantHospitality,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'accommodation',
      mutationId: 'allocateRoom',
      permission: Permission.manageAccommodation,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'accommodation',
      mutationId: 'registerResident',
      permission: Permission.manageAccommodation,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'white_label_platform',
      mutationId: 'saveBrandingProfile',
      permission: Permission.manageWhiteLabelPlatform,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'white_label_platform',
      mutationId: 'applyTheme',
      permission: Permission.manageWhiteLabelPlatform,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'white_label_platform',
      mutationId: 'uploadLogo',
      permission: Permission.manageWhiteLabelPlatform,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'dynamic_widgets',
      mutationId: 'saveRoleDashboardLayout',
      permission: Permission.manageDynamicWidgets,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'dynamic_widgets',
      mutationId: 'resetLayoutToPackDefault',
      permission: Permission.manageDynamicWidgets,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'ai_content',
      mutationId: 'generateAiContent',
      permission: Permission.manageManagement,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'director',
      mutationId: 'acknowledgeCompliance',
      permission: Permission.manageDirectorPortal,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'director',
      mutationId: 'exportReport',
      permission: Permission.manageDirectorPortal,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'branch',
      mutationId: 'assignBranchSchool',
      permission: Permission.manageBranchOperations,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'franchise',
      mutationId: 'improveFranchiseScore',
      permission: Permission.manageFranchiseOperations,
      kind: 'manage',
    ),
    // School Memories
    MutationPermissionEntry(
      moduleId: 'school_memories',
      mutationId: 'createSchoolMemoryEvent',
      permission: Permission.manageSchoolMemories,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'school_memories',
      mutationId: 'publishSchoolMemoryEvent',
      permission: Permission.manageSchoolMemories,
      kind: 'manage',
    ),
    // Communication
    MutationPermissionEntry(
      moduleId: 'communication',
      mutationId: 'sendBroadcast',
      permission: Permission.manageCommunication,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'communication',
      mutationId: 'saveTemplate',
      permission: Permission.manageCommunicationTemplates,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'workflow',
      mutationId: 'executeWorkflowAction',
      permission: Permission.manageWorkflowAutomation,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'school_completion',
      mutationId: 'assignSubstitute',
      permission: Permission.manageAcademicTimetable,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'school_completion',
      mutationId: 'reassignTeacher',
      permission: Permission.manageAcademicTimetable,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'school_completion',
      mutationId: 'applyTimetableOptimization',
      permission: Permission.manageAcademicTimetable,
      kind: 'manage',
    ),

    MutationPermissionEntry(
      moduleId: 'parent_meetings',
      mutationId: 'createMeeting',
      permission: Permission.manageAcademicProgress,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'parent_meetings',
      mutationId: 'saveNotes',
      permission: Permission.manageAcademicProgress,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'parent_meetings',
      mutationId: 'generateSummary',
      permission: Permission.manageAcademicProgress,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'parent_meetings',
      mutationId: 'completeAction',
      permission: Permission.manageAcademicProgress,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'parent_meetings',
      mutationId: 'scheduleFollowUp',
      permission: Permission.manageAcademicProgress,
      kind: 'manage',
    ),
    // Evolution
    MutationPermissionEntry(
      moduleId: 'evolution',
      mutationId: 'createGrowthCampaign',
      permission: Permission.manageGrowthPlatform,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'evolution',
      mutationId: 'createGrowthInquiry',
      permission: Permission.manageGrowthPlatform,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'evolution',
      mutationId: 'convertGrowthInquiry',
      permission: Permission.manageGrowthPlatform,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'evolution',
      mutationId: 'updateGrowthCampaign',
      permission: Permission.manageGrowthPlatform,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'evolution',
      mutationId: 'pauseGrowthCampaign',
      permission: Permission.manageGrowthPlatform,
      kind: 'manage',
    ),
    // Inventory
    MutationPermissionEntry(
      moduleId: 'inventory',
      mutationId: 'createProcurementOrder',
      permission: Permission.manageInventory,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'inventory',
      mutationId: 'approveProcurementHandoff',
      permission: Permission.manageInventory,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'inventory',
      mutationId: 'receiveProcurementHandoff',
      permission: Permission.manageInventory,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'inventory_distribution',
      mutationId: 'createDistribution',
      permission: Permission.manageInventoryDistribution,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'inventory_distribution',
      mutationId: 'markDistributed',
      permission: Permission.manageInventoryDistribution,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'inventory_distribution',
      mutationId: 'requestReplacement',
      permission: Permission.manageInventoryDistribution,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'inventory_distribution',
      mutationId: 'approveReplacement',
      permission: Permission.manageInventoryDistribution,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'inventory_distribution',
      mutationId: 'fulfillReplacement',
      permission: Permission.manageInventoryDistribution,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'inventory_distribution',
      mutationId: 'rejectReplacement',
      permission: Permission.manageInventoryDistribution,
      kind: 'manage',
    ),
    // Library
    MutationPermissionEntry(
      moduleId: 'library',
      mutationId: 'issueLibraryBook',
      permission: Permission.manageLibrary,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'library',
      mutationId: 'returnLibraryBook',
      permission: Permission.manageLibrary,
      kind: 'manage',
    ),
    // Hostel
    MutationPermissionEntry(
      moduleId: 'hostel',
      mutationId: 'admitHostelStudent',
      permission: Permission.manageHostel,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'hostel',
      mutationId: 'assignHostelRoom',
      permission: Permission.manageHostel,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'hostel',
      mutationId: 'checkoutHostelStudent',
      permission: Permission.manageHostel,
      kind: 'manage',
    ),
    // HR
    MutationPermissionEntry(
      moduleId: 'hr',
      mutationId: 'createEmployee',
      permission: Permission.manageHr,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'hr',
      mutationId: 'updateEmployee',
      permission: Permission.manageHr,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'hr',
      mutationId: 'setEmployeeStatus',
      permission: Permission.manageHr,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'hr',
      mutationId: 'approveLeaveRequest',
      permission: Permission.manageHr,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'hr',
      mutationId: 'rejectLeaveRequest',
      permission: Permission.manageHr,
      kind: 'manage',
    ),
    // Transport
    MutationPermissionEntry(
      moduleId: 'transport',
      mutationId: 'assignStudentTransport',
      permission: Permission.manageTransport,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'transport',
      mutationId: 'transferStudentTransport',
      permission: Permission.manageTransport,
      kind: 'manage',
    ),
    MutationPermissionEntry(
      moduleId: 'transport',
      mutationId: 'removeStudentTransport',
      permission: Permission.manageTransport,
      kind: 'manage',
    ),
  ];

  static List<MutationPermissionEntry> forModule(String moduleId) {
    return entries.where((e) => e.moduleId == moduleId).toList(growable: false);
  }
}
