import 'package:flutter/foundation.dart';

/// Fine-grained permissions for Akshara ERP modules.
enum Permission {
  // Admissions
  viewAdmissions,
  manageAdmissions,
  approveAdmissions,

  // Finance
  viewFinance,
  manageFinance,
  approveRefunds,

  // SIS
  viewSis,
  manageSis,

  // Management
  viewManagement,
  manageManagement,
  manageWorkflowAutomation,

  // Transport
  viewTransport,
  manageTransport,

  // HR
  viewHr,
  manageHr,

  // Hostel
  viewHostel,
  manageHostel,

  // Library
  viewLibrary,
  manageLibrary,

  // Inventory
  viewInventory,
  manageInventory,

  // Alumni
  viewAlumni,
  manageAlumni,

  // Control Center (platform)
  viewControlCenter,
  manageControlCenter,

  // Director Portal
  viewDirectorPortal,
  manageDirectorPortal,
  viewOrganizationIntelligence,
  viewBranchOperations,
  manageBranchOperations,
  viewFranchiseOperations,
  manageFranchiseOperations,

  // Admin hub
  viewAdminHub,

  // Onboarding / data migration
  viewOnboarding,
  manageOnboarding,

  // AI Copilot
  viewAiCopilot,
  runAiCopilot,

  // Academic timetable (v7.5)
  viewAcademicTimetable,
  manageAcademicTimetable,
  publishAcademicTimetable,

  // Analytics Hub (v7.6)
  viewAnalytics,
  viewSchoolHealth,

  // Education Suite (v8.5–v8.8)
  viewEducation,
  manageEducation,
  approveEducation,

  // Intelligence Layer (v8.9–v9.3)
  viewStudentRisk,
  generateIntelligence,

  // Phase 4 (v9.4–v9.7)
  viewHomeworkIntelligence,
  manageHomeworkIntelligence,
  // Wave 5 MJ-M10 — granular teacher homework write gate (create + grade).
  manageHomework,
  viewStudent360,
  viewEmployees,
  manageEmployees,
  viewInventoryDistribution,
  manageInventoryDistribution,

  // Phase 5 (v9.8–v10.3)
  viewParentExperience,
  viewEmployeeIntelligence,
  viewOperationsHub,
  viewSchoolMemories,
  manageSchoolMemories,
  viewAchievementPromotion,
  manageAchievementPromotion,
  approveAchievementPromotion,

  // Evolution v10.5–v11.0
  viewSchoolSetup,
  manageSchoolSetup,
  viewDynamicWidgets,
  manageDynamicWidgets,
  viewTeacherAssistant,
  manageTeacherAssistant,
  viewParentInsights,
  viewPrincipalCommand,
  viewGrowthPlatform,
  manageGrowthPlatform,

  // Phase 8 — School Completion
  viewSubjects,
  manageSubjects,
  viewLessonLogs,
  manageLessonLogs,
  manageTimetableAutomation,
  viewSchoolBranding,
  manageSchoolBranding,
  viewWhatsAppProvider,
  manageWhatsAppProvider,
  managePlatformWhatsApp,

  // Phase 9 — School Platform Completion
  viewSubjectAssignments,
  manageSubjectAssignments,
  viewLessonAnalytics,
  viewTimetableOptimization,
  viewCommunicationDelivery,
  manageCommunication,
  manageCommunicationTemplates,
  viewPilotDashboard,

  // Phase 10 — Final School Platform
  manageSyllabus,
  viewAcademicProgress,
  manageAcademicProgress,
  managePlatformProviders,
  viewPlatformUsage,
  managePlatformVault,
  managePlatformFeatures,
  manageAcademicRooms,
  viewParentAcademicSummary,

  // Phase 11 — Finance Intelligence
  viewFinanceIntelligence,
  viewFinanceExecutiveDashboard,

  // Phase 12 — Inventory Intelligence
  viewInventoryIntelligence,
  manageAssetLifecycle,
  manageProcurementWorkflow,

  // Phase 13–14 — Student Success & Exam Intelligence
  viewStudentSuccessIntelligence,
  viewExamIntelligence,

  // Phase D M-D3 — Exam results governance
  viewExams,
  manageExams,
  manageExamMarks,
  submitExamResults,
  verifyExamResults,
  approveExamResults,
  publishExamResults,
  // EXM-D2 — grace / moderation (coordinator-level; not a plain marks teacher).
  moderateExamMarks,

  // Phase D M-D4 — Attendance & leave governance
  markAttendance,
  viewAttendance,
  submitAttendanceCorrection,
  approveAttendanceCorrection,
  correctAttendance,
  submitStudentLeave,
  approveStudentLeave,
  submitStaffLeave,
  approveStaffLeave,

  // O5 — staff self check-in/out via device biometric (Face ID / fingerprint).
  // Held by every staff persona (not parent/student). Student attendance stays
  // teacher-entered (O4); markAttendance above is the teacher→roster permission.
  markStaffAttendance,

  // P1-PROD-22 slice 4 — approve/reject manual staff attendance requests (the
  // audited fallback when the geofence+face chain cannot complete). Seeded
  // server-side in 20260820000000 for the supervisory roles.
  approveStaffAttendance,

  // SCE-1 slice 4 — approve/reject a student clearance dues-waiver (maker-checker,
  // the sanctioned override to issue a TC despite a small remaining due). Seeded
  // server-side in 20260878000000 for the supervisory roles.
  approveClearanceWaiver,

  // Phase D M-D5 — Finance approval governance
  assignScholarship,
  approveFeeConcession,
  approveFeeStructure,
  submitFeeStructureForApproval,

  // Phase D M-D6 — Inventory PO governance
  createInventoryPo,
  approvePurchaseOrder,

  // Phase 15 — Communication Analytics
  viewCommunicationAnalytics,

  // Phase 16 — Teacher Effectiveness
  viewTeacherEffectiveness,

  // FV-PLAT-02 — Multi-School SaaS Operations
  viewMultiSchoolOperations,
  manageMultiSchoolOperations,

  // FV-30 — Universal Organization Builder
  viewOrganizationBuilder,
  manageOrganizationBuilder,

  // FV-PLAT-06/08/09/12 — Platform Operations
  viewPlatformOperations,
  managePlatformOperations,

  // FV-32 — Multi-Industry Framework
  viewIndustryFramework,
  manageIndustryFramework,

  // FV-33 — Healthcare Pack
  viewHealthcare,
  manageHealthcare,

  // FV-34 — Salon Pack
  viewSalonBusiness,
  manageSalonBusiness,

  // FV-35 — Restaurant Pack
  viewRestaurantHospitality,
  manageRestaurantHospitality,

  // FV-36 — Accommodation Pack
  viewAccommodation,
  manageAccommodation,

  // FV-PLAT-11 — White Label Platform
  viewWhiteLabelPlatform,
  manageWhiteLabelPlatform,

  // PRC-A Batch 2 — Certificate Request Desk (caps 136–148)
  requestStudentCertificate,
  approveCertificateRequest,

  // PRC-A Batch 2 — Gate Pass / early pickup (caps 109–118)
  requestGatePass,
  approveGatePass,
  verifyGatePass,

  // PRC-A Batch 2 — Complaints / internal issues (caps 101–108)
  raiseComplaint,
  manageComplaints,
  viewComplaintsPrincipal,

  // PRC-A Batch 2 — Student Health / Infirmary (caps 119–127).
  // Owner decision #1: strict need-to-know. `viewStudentHealthRecord` is health
  // staff + explicitly authorised leadership ONLY; teaching roles get
  // `viewStudentCareAlert`, which carries no clinical detail and is further
  // narrowed server-side to students that caller actually teaches. Never widen
  // these on the client to "make the UI simpler" — the server is the authority,
  // but a client that requests the wrong one leaks intent.
  manageStudentHealth,
  viewStudentHealthRecord,
  viewStudentCareAlert,
  administerStudentMedication,

  // PRC-A Batch 3 — AI credit wallet (caps 37–43). Seeded server-side in
  // 20260888000000_ai_credit_wallet.sql: viewAiWallet -> superAdmin,
  // organizationOwner, organizationAdmin, management; manageAiCredits ->
  // superAdmin ONLY (granting credit is a platform act, not a tenant one).
  viewAiWallet,
  manageAiCredits,

  // PRC-A Batch 4 — storage quota (caps 31–36). Seeded server-side in
  // 20260889000000_storage_quota.sql: viewStorageQuota -> superAdmin,
  // organizationOwner, organizationAdmin, management. Deliberately no manage
  // permission — the limit is set by the PLAN, not granted ad hoc.
  viewStorageQuota,
}

/// Immutable set of [Permission] values for a session.
@immutable
class PermissionSet {
  const PermissionSet(this._permissions);

  factory PermissionSet.from(Iterable<Permission> permissions) {
    return PermissionSet(Set<Permission>.unmodifiable(permissions));
  }

  factory PermissionSet.all() {
    return PermissionSet(Set<Permission>.unmodifiable(Permission.values));
  }

  final Set<Permission> _permissions;

  bool contains(Permission permission) => _permissions.contains(permission);

  bool containsAny(Iterable<Permission> permissions) {
    for (final p in permissions) {
      if (_permissions.contains(p)) return true;
    }
    return false;
  }

  bool containsAll(Iterable<Permission> permissions) {
    for (final p in permissions) {
      if (!_permissions.contains(p)) return false;
    }
    return true;
  }

  Set<Permission> get values => Set<Permission>.unmodifiable(_permissions);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PermissionSet &&
        other._permissions.length == _permissions.length &&
        other._permissions.containsAll(_permissions);
  }

  @override
  int get hashCode => Object.hashAllUnordered(_permissions);
}
