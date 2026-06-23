/// Canonical path constants for [GoRouter] configuration.
abstract final class RouteNames {
  static const String root = '/';

  // Auth (P-01 → P-03)
  static const String splash = '/splash';
  static const String login = '/login';
  static const String qaLogin = '/qa-login';
  static const String otpVerification = '/otp';
  static const String staffLogin = '/staff/login';
  static const String staffOtp = '/staff/otp';

  // Parent app (mobile)
  static const String parent = '/parent';
  static const String parentDashboard = '/parent/dashboard';
  static const String parentAttendance = '/parent/attendance';
  static const String parentTimetable = '/parent/timetable';
  static const String parentHomework = '/parent/homework';
  static const String parentExams = '/parent/exams';
  static const String parentNotices = '/parent/notices';
  static const String parentEvents = '/parent/events';
  static const String parentProfile = '/parent/profile';
  static const String parentFees = '/parent/fees';
  static const String parentPayment = '/parent/payment';
  static const String parentReceipts = '/parent/receipts';
  static const String parentLeave = '/parent/leave';
  static const String parentMessages = '/parent/messages';
  static const String parentTransport = '/parent/transport';
  static const String parentPtm = '/parent/ptm';
  static const String parentNotifications = '/parent/notifications';

  static String parentReceiptDetail(String receiptId) =>
      '$parentReceipts/$receiptId';
  static String parentConversation(String threadId) =>
      '$parentMessages/$threadId';
  static String parentCommunicationMessage(String messageId) =>
      '$parentMessages/comm/$messageId';

  // Teacher app (mobile)
  static const String teacher = '/teacher';
  static const String teacherDashboard = '/teacher/dashboard';
  static const String teacherClassTeacherDashboard =
      '/teacher/class-teacher-dashboard';
  static const String teacherAttendance = '/teacher/attendance';
  static const String teacherTimetable = '/teacher/timetable';
  static const String teacherHomework = '/teacher/homework';
  static const String teacherHomeworkCreate = '/teacher/homework/create';
  static const String teacherExams = '/teacher/exams';
  static const String teacherMessages = '/teacher/messages';
  static const String teacherParentCommunication = '/teacher/parent-communication';

  static String teacherStudentRisk(String sisStudentId) =>
      '$teacher/student-risk/$sisStudentId';
  static const String teacherLeave = '/teacher/leave';
  static const String teacherSettings = '/teacher/settings';

  static String teacherConversation(String threadId) =>
      '$teacherMessages/$threadId';

  // Student app (mobile)
  static const String student = '/student';
  static const String studentDashboard = '/student/dashboard';
  static const String studentAttendance = '/student/attendance';
  static const String studentTimetable = '/student/timetable';
  static const String studentHomework = '/student/homework';
  static const String studentExams = '/student/exams';
  static const String studentReportCard = '/student/report-card';
  static const String studentProgress = '/student/progress';
  static const String studentNotices = '/student/notices';
  static const String studentProfile = '/student/profile';

  // Web ERP admin shell (desktop / tablet / mobile drawer)
  static const String admin = '/admin';
  static const String copilot = '/copilot';
  static const String aiAssistant = '/ai-assistant';
  static const String aiAssistantSettings = '/settings/ai-assistant';
  static const String appearanceSettings = '/settings/appearance';
  static const String education = '/education';
  static const String intelligence = '/intelligence';
  static const String studentSuccessIntelligence =
      '/intelligence/student-success';
  static const String examIntelligence = '/intelligence/exam';
  static const String homeworkIntelligence = '/homework-intelligence';
  static const String student360 = '/student-360';
  static const String employees = '/employees';
  static const String inventoryDistribution = '/inventory/distribution';
  static const String inventoryReplacements = '/inventory/replacements';
  static const String parentExperience = '/parent/experience';
  static const String parentAcademicReport = '/parent/academic-report';
  static const String employee360 = '/employees/360';
  static const String operationsHub = '/operations/hub';
  static const String resourceOptimization = '/resource-optimization';
  static const String aiContent = '/ai-content';
  static const String organizationIntelligence = '/organization/intelligence';
  static const String branches = '/branches';
  static const String franchise = '/franchise';
  static const String schoolMemories = '/memories';
  static const String achievementPromotion = '/promotions';
  static const String setupWizard = '/setup-wizard';
  static const String dynamicDashboard = '/dashboard/dynamic';
  static const String dynamicWidgets = '/dynamic-widgets';
  static const String dynamicWidgetLayout = '/dynamic-widgets/layout';
  static const String dynamicWidgetRuntime = '/dynamic-widgets/runtime';
  static const String teacherAssistant = '/teacher-assistant';
  static const String parentInsights = '/parent/insights';
  static const String principalCommand = '/principal-command';
  static const String growthPlatform = '/growth';
  static const String schoolCompletionHub = '/school/completion';
  static const String subjectsManagement = '/school/subjects';
  static const String examAdministration = '/school/exam-administration';
  static String examAdministrationMarksPath(String examId) =>
      '$examAdministration/$examId/marks';
  static const String lessonLogs = '/school/lesson-logs';
  static const String timetableAutomation = '/school/timetables/automate';
  static const String schoolBranding = '/school/branding';
  static const String whatsAppProvider = '/school/whatsapp-provider';
  static const String subjectAssignments = '/school/subject-assignments';
  static const String lessonAnalytics = '/school/lesson-analytics';
  static const String timetableOptimization = '/school/timetables/optimize';
  static const String substituteManager = '/school/timetables/substitute';
  static const String teacherReassignment = '/school/timetables/reassign';
  static const String classTeacherAssignments =
      '/school/timetables/class-teachers';
  static const String communicationDelivery = '/school/communications/delivery';
  static const String communicationBroadcastAdmin =
      '/school/communications/broadcast-admin';
  static const String communicationAnalytics =
      '/school/communications/analytics';
  static const String teacherEffectiveness =
      '/intelligence/teacher-effectiveness';
  static const String pilotDashboard = '/school/pilot';
  static const String parentActivationDashboard = '/school/parent-activation';
  static const String roomAllocation = '/school/rooms-allocation';
  static const String syllabusAutomation = '/school/syllabus/automation';
  static const String academicProgress = '/school/academic/progress';
  static const String timetableIntelligence = '/school/timetables/intelligence';
  static const String parentMeetings = '/parent-meetings';
  static const String multiSchoolPortfolio = '/multi-school/portfolio';
  static const String multiSchoolOnboarding = '/multi-school/onboarding';
  static const String organizationBuilder = '/organization-builder';
  static const String organizationBuilderInterview =
      '/organization-builder/interview';
  static const String organizationBuilderPreview =
      '/organization-builder/preview';
  static const String organizationBuilderProvisioning =
      '/organization-builder/provisioning';
  static const String schoolDiscovery = '/school-config/discovery';
  static const String platformOperations = '/platform-operations';
  static const String platformOperationsAlerts = '/platform-operations/alerts';
  static const String platformOperationsSecurity =
      '/platform-operations/security';
  static const String platformOperationsTenantIsolation =
      '/platform-operations/tenant-isolation';
  static const String platformOperationsReadiness =
      '/platform-operations/readiness';

  // FV-32 — Multi-Industry Framework
  static const String industry = '/industry';
  static const String industryFramework = '/industry/framework';

  // FV-33 — Healthcare
  static const String healthcare = '/healthcare';
  static const String healthcareDashboard = '/healthcare';
  static const String healthcarePatients = '/healthcare/patients';
  static const String healthcareAppointments = '/healthcare/appointments';
  static const String healthcarePractitioners = '/healthcare/practitioners';
  static const String healthcareIntelligence = '/healthcare/intelligence';

  // FV-34 — Salon
  static const String salon = '/salon';
  static const String salonDashboard = '/salon';
  static const String salonCustomers = '/salon/customers';
  static const String salonAppointments = '/salon/appointments';
  static const String salonServices = '/salon/services';
  static const String salonIntelligence = '/salon/intelligence';

  // FV-35 — Restaurant
  static const String restaurant = '/restaurant';
  static const String restaurantDashboard = '/restaurant';
  static const String restaurantTables = '/restaurant/tables';
  static const String restaurantOrders = '/restaurant/orders';
  static const String restaurantKitchen = '/restaurant/kitchen';
  static const String restaurantIntelligence = '/restaurant/intelligence';

  // FV-36 — Accommodation
  static const String accommodation = '/accommodation';
  static const String accommodationDashboard = '/accommodation';
  static const String accommodationResidents = '/accommodation/residents';
  static const String accommodationOccupancy = '/accommodation/occupancy';
  static const String accommodationAllocations = '/accommodation/allocations';
  static const String accommodationIntelligence = '/accommodation/intelligence';

  // FV-PLAT-11 — White Label Platform
  static const String whiteLabel = '/white-label';
  static const String whiteLabelHub = '/white-label';
  static const String whiteLabelBranding = '/white-label/branding';
  static const String whiteLabelTheme = '/white-label/theme';
  static const String whiteLabelLogo = '/white-label/logo';
  static const String whiteLabelDeployment = '/white-label/deployment';

  static const String admissions = '/admissions';
  static const String admissionsDashboard = '/admissions/dashboard';
  static const String admissionsLeads = '/admissions/leads';
  static const String admissionsApplications = '/admissions/applications';
  static const String admissionsEnrollment = '/admissions/enrollment';
  static const String admissionsDocuments = '/admissions/documents';

  static String admissionsLeadDetail(String leadId) =>
      '$admissionsLeads/$leadId';
  static const String admissionsApproval = '/admissions/approval';
  static const String admissionsFeeHandoff = '/admissions/fee-handoff';
  static const String admissionsReports = '/admissions/reports';
  static const String admissionsSettings = '/admissions/settings';

  /// All admissions module routes (AD-01 → AD-10).
  static const List<String> admissionsRoutes = [
    admissionsDashboard,
    admissionsLeads,
    admissionsApplications,
    admissionsEnrollment,
    admissionsDocuments,
    admissionsApproval,
    admissionsFeeHandoff,
    admissionsReports,
    admissionsSettings,
  ];
  static const String finance = '/finance';
  static const String financeDashboard = '/finance/dashboard';
  static const String financeFeeStructures = '/finance/fee-structures';
  static const String financeStudentAccounts = '/finance/student-accounts';
  static const String financeFeeAssignment = '/finance/fee-assignment';
  static const String financeCollections = '/finance/collections';
  static const String financeQrPayment = '/finance/payments/qr';
  static const String financeOfflinePayments = '/finance/payments/offline';
  static const String financeDefaulters = '/finance/defaulters';
  static const String financeRefunds = '/finance/refunds';
  static const String financeDiscounts = '/finance/discounts';
  static const String financeReports = '/finance/reports';
  static const String financeReconciliation = '/finance/reconciliation';
  static const String financeSettings = '/finance/settings';
  static const String financeIntelligence = '/finance/intelligence';
  static const String financeExecutiveDashboard = '/finance/executive';

  static String financeCollectionDetail(String collectionId) =>
      '$financeCollections/$collectionId';

  /// All finance module routes (FN-01 → FN-11).
  static const List<String> financeRoutes = [
    financeDashboard,
    financeFeeStructures,
    financeStudentAccounts,
    financeFeeAssignment,
    financeCollections,
    financeQrPayment,
    financeOfflinePayments,
    financeDefaulters,
    financeRefunds,
    financeDiscounts,
    financeReports,
    financeReconciliation,
    financeSettings,
    financeIntelligence,
    financeExecutiveDashboard,
  ];
  static const String sis = '/sis';
  static const String sisDashboard = '/sis/dashboard';
  static const String sisStudents = '/sis/students';
  static const String sisAcademicAssignment = '/sis/academic-assignment';
  static const String sisAdmissionsConversion = '/sis/admissions-conversion';
  static const String sisPromotion = '/sis/promotion';
  static const String sisReshuffle = '/sis/reshuffle';
  static const String sisSectionBalance = '/sis/section-balance';
  static const String sisContinuity = '/sis/continuity';
  static const String onboardingHub = '/sis/onboarding';
  static const String unifiedOnboarding = '/admin/onboarding/unified';
  static const String backupRestore = '/admin/backup-restore';

  static String sisStudentDetail(String studentId) => '$sisStudents/$studentId';

  /// All SIS module routes (SIS-01 → SIS-05).
  static const List<String> sisRoutes = [
    sisDashboard,
    sisStudents,
    sisAcademicAssignment,
    sisAdmissionsConversion,
    sisPromotion,
    sisReshuffle,
    sisSectionBalance,
    sisContinuity,
    onboardingHub,
  ];

  static const String hr = '/hr';
  static const String hrDashboard = '/hr/dashboard';
  static const String hrEmployees = '/hr/employees';
  static const String hrAttendance = '/hr/attendance';
  static const String hrLeave = '/hr/leave';
  static const String hrPayroll = '/hr/payroll';
  static const String hrRecruitment = '/hr/recruitment';
  static const String hrPerformance = '/hr/performance';
  static const String hrReports = '/hr/reports';
  static const String hrSettings = '/hr/settings';

  static String hrEmployeeDetail(String employeeId) =>
      '$hrEmployees/$employeeId';

  /// All HR module routes (HR-01 → HR-09).
  static const List<String> hrModuleRoutes = [
    hrDashboard,
    hrEmployees,
    hrAttendance,
    hrLeave,
    hrPayroll,
    hrRecruitment,
    hrPerformance,
    hrReports,
    hrSettings,
  ];
  static const String management = '/management';
  static const String managementDashboard = '/management/dashboard';
  static const String managementAnalytics = '/management/analytics';
  static const String managementAdmissions = '/management/admissions';
  static const String managementFinance = '/management/finance';
  static const String managementAcademics = '/management/academics';
  static const String managementTimetable = '/management/timetable';
  static const String managementIntelligence = '/management/intelligence';
  static const String managementPerformance = '/management/performance';
  static const String managementTasks = '/management/tasks';
  static const String managementApprovals = '/management/approvals';
  static const String managementAttendanceCorrections =
      '/management/attendance-corrections';
  static const String managementWorkflowAutomation =
      '/management/workflow-automation';
  static const String managementSettings = '/management/settings';

  /// All management module routes (MG-01 → MG-08).
  static const List<String> managementRoutes = [
    managementDashboard,
    managementAnalytics,
    managementAdmissions,
    managementFinance,
    managementAcademics,
    managementTimetable,
    managementIntelligence,
    managementPerformance,
    managementTasks,
    managementApprovals,
    managementAttendanceCorrections,
    managementWorkflowAutomation,
    managementSettings,
  ];
  static const String transport = '/transport';
  static const String transportDashboard = '/transport/dashboard';
  static const String transportRoutes = '/transport/routes';
  static const String transportVehicles = '/transport/vehicles';
  static const String transportDrivers = '/transport/drivers';
  static const String transportAllocation = '/transport/allocation';
  static const String transportAttendance = '/transport/attendance';
  static const String transportTracking = '/transport/tracking';
  static const String transportReports = '/transport/reports';
  static const String transportSettings = '/transport/settings';

  /// All transport module routes (TR-01 → TR-09).
  static const List<String> transportModuleRoutes = [
    transportDashboard,
    transportRoutes,
    transportVehicles,
    transportDrivers,
    transportAllocation,
    transportAttendance,
    transportTracking,
    transportReports,
    transportSettings,
  ];
  static const String hostel = '/hostel';
  static const String hostelDashboard = '/hostel/dashboard';
  static const String hostelStudents = '/hostel/students';
  static const String hostelRooms = '/hostel/rooms';
  static const String hostelAttendance = '/hostel/attendance';
  static const String hostelLeave = '/hostel/leave';
  static const String hostelMess = '/hostel/mess';
  static const String hostelVisitors = '/hostel/visitors';
  static const String hostelReports = '/hostel/reports';

  /// All hostel module routes (HO-01 → HO-08).
  static const List<String> hostelModuleRoutes = [
    hostelDashboard,
    hostelStudents,
    hostelRooms,
    hostelAttendance,
    hostelLeave,
    hostelMess,
    hostelVisitors,
    hostelReports,
  ];
  static const String library = '/library';
  static const String libraryDashboard = '/library/dashboard';
  static const String libraryCatalog = '/library/catalog';
  static const String libraryIssues = '/library/issues';
  static const String libraryReturns = '/library/returns';
  static const String libraryMembers = '/library/members';
  static const String libraryFines = '/library/fines';
  static const String libraryResources = '/library/resources';
  static const String libraryReports = '/library/reports';

  /// All library module routes (LB-01 → LB-08).
  static const List<String> libraryModuleRoutes = [
    libraryDashboard,
    libraryCatalog,
    libraryIssues,
    libraryReturns,
    libraryMembers,
    libraryFines,
    libraryResources,
    libraryReports,
  ];
  static const String inventory = '/inventory';
  static const String inventoryDashboard = '/inventory/dashboard';
  static const String inventoryAssets = '/inventory/assets';
  static const String inventoryCategories = '/inventory/categories';
  static const String inventoryAllocation = '/inventory/allocation';
  static const String inventoryMaintenance = '/inventory/maintenance';
  static const String inventoryProcurement = '/inventory/procurement';
  static const String inventoryVendors = '/inventory/vendors';
  static const String inventoryReports = '/inventory/reports';
  static const String inventoryCopilot = '/inventory/copilot';
  static const String inventoryLifecycle = '/inventory/lifecycle';

  /// All inventory module routes (INV-01 → INV-10).
  static const List<String> inventoryModuleRoutes = [
    inventoryDashboard,
    inventoryAssets,
    inventoryCategories,
    inventoryAllocation,
    inventoryMaintenance,
    inventoryProcurement,
    inventoryVendors,
    inventoryReports,
    inventoryCopilot,
    inventoryLifecycle,
  ];
  static const String alumni = '/alumni';
  static const String alumniDashboard = '/alumni/dashboard';
  static const String alumniRegistry = '/alumni/registry';
  static const String alumniProfile = '/alumni/profile';
  static const String alumniEvents = '/alumni/events';
  static const String alumniDonations = '/alumni/donations';
  static const String alumniCampaigns = '/alumni/campaigns';
  static const String alumniMentorship = '/alumni/mentorship';
  static const String alumniReports = '/alumni/reports';
  static const String alumniSettings = '/alumni/settings';

  static String alumniProfileDetail(String alumniId) =>
      '$alumniProfile/$alumniId';

  /// All alumni module routes (AL-01 → AL-09; AL-03 is a child route).
  static const List<String> alumniModuleRoutes = [
    alumniDashboard,
    alumniRegistry,
    alumniEvents,
    alumniDonations,
    alumniCampaigns,
    alumniMentorship,
    alumniReports,
    alumniSettings,
  ];

  static const String controlCenter = '/control-center';
  static const String controlCenterDashboard = '/control-center/dashboard';
  static const String controlCenterIntelligence =
      '/control-center/intelligence';
  static const String controlCenterSchools = '/control-center/schools';
  static const String controlCenterSubscriptions =
      '/control-center/subscriptions';
  static const String controlCenterBilling = '/control-center/billing';
  static const String controlCenterCrm = '/control-center/crm';
  static const String controlCenterSupport = '/control-center/support';
  static const String controlCenterSuccess = '/control-center/success';
  static const String controlCenterWhiteLabel = '/control-center/white-label';
  static const String controlCenterAnalytics = '/control-center/analytics';
  static const String controlCenterMonitoring = '/control-center/monitoring';
  static const String controlCenterRoles = '/control-center/roles';
  static const String controlCenterSettings = '/control-center/settings';
  static const String controlCenterProviders = '/control-center/providers';
  static const String controlCenterFeatures = '/control-center/features';

  static const String director = '/director';
  static const String directorDashboard = '/director/dashboard';
  static const String directorSchools = '/director/schools';
  static const String directorPortfolio = '/director/portfolio';
  static const String directorRevenue = '/director/revenue';
  static const String directorGrowth = '/director/growth';
  static const String directorMarketing = '/director/marketing';
  static const String directorAdmissions = '/director/admissions';
  static const String directorCompliance = '/director/compliance';
  static const String directorReports = '/director/reports';

  static const List<String> directorModuleRoutes = [
    directorDashboard,
    directorSchools,
    directorPortfolio,
    directorRevenue,
    directorGrowth,
    directorMarketing,
    directorAdmissions,
    directorCompliance,
    directorReports,
  ];

  /// All control center module routes (ACC-01 → ACC-14).
  static const List<String> controlCenterModuleRoutes = [
    controlCenterDashboard,
    controlCenterIntelligence,
    controlCenterSchools,
    controlCenterSubscriptions,
    controlCenterBilling,
    controlCenterCrm,
    controlCenterSupport,
    controlCenterSuccess,
    controlCenterWhiteLabel,
    controlCenterAnalytics,
    controlCenterMonitoring,
    controlCenterRoles,
    controlCenterSettings,
    controlCenterProviders,
    controlCenterFeatures,
  ];

  /// All module groups wrapped by [AdminShell].
  static const List<String> adminErpRoutes = [
    admin,
    copilot,
    education,
    intelligence,
    studentSuccessIntelligence,
    examIntelligence,
    homeworkIntelligence,
    student360,
    employees,
    inventoryDistribution,
    inventoryReplacements,
    operationsHub,
    resourceOptimization,
    aiContent,
    organizationIntelligence,
    branches,
    franchise,
    schoolMemories,
    achievementPromotion,
    setupWizard,
    dynamicDashboard,
    dynamicWidgets,
    dynamicWidgetLayout,
    dynamicWidgetRuntime,
    teacherAssistant,
    principalCommand,
    growthPlatform,
    schoolCompletionHub,
    subjectsManagement,
    examAdministration,
    lessonLogs,
    timetableAutomation,
    schoolBranding,
    whatsAppProvider,
    subjectAssignments,
    lessonAnalytics,
    timetableOptimization,
    substituteManager,
    teacherReassignment,
    classTeacherAssignments,
    communicationDelivery,
    communicationBroadcastAdmin,
    communicationAnalytics,
    pilotDashboard,
    parentActivationDashboard,
    roomAllocation,
    syllabusAutomation,
    academicProgress,
    timetableIntelligence,
    admissions,
    finance,
    sis,
    hr,
    management,
    transport,
    hostel,
    library,
    inventory,
    alumni,
    controlCenter,
    director,
    parentMeetings,
    multiSchoolPortfolio,
    multiSchoolOnboarding,
    organizationBuilder,
    organizationBuilderInterview,
    organizationBuilderPreview,
    organizationBuilderProvisioning,
    schoolDiscovery,
    platformOperations,
    platformOperationsAlerts,
    platformOperationsSecurity,
    platformOperationsTenantIsolation,
    platformOperationsReadiness,
    industry,
    industryFramework,
    healthcare,
    healthcarePatients,
    healthcareAppointments,
    healthcarePractitioners,
    healthcareIntelligence,
    salon,
    salonCustomers,
    salonAppointments,
    salonServices,
    salonIntelligence,
    restaurant,
    restaurantTables,
    restaurantOrders,
    restaurantKitchen,
    restaurantIntelligence,
    accommodation,
    accommodationResidents,
    accommodationOccupancy,
    accommodationAllocations,
    accommodationIntelligence,
    whiteLabel,
    whiteLabelBranding,
    whiteLabelTheme,
    whiteLabelLogo,
    whiteLabelDeployment,
    dynamicWidgets,
    dynamicWidgetLayout,
    dynamicWidgetRuntime,
  ];
}
