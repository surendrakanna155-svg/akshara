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

  // BUS-013 — transport field + self-service permissions.
  //
  // The old model had exactly two transport permissions, both staff-scoped, so
  // there was no way to express "a driver may see their own trip" or "a parent
  // may see their own child's bus". That gap is why the parent surface 403'd in
  // the live build and why no driver could ever log in.
  //
  // Scopes are defined in docs/engineering/TRANSPORT_DOMAIN_CONTRACT.md §5.

  /// Driver/attendant: read ONLY today's assigned trip (route, stops, manifest).
  viewOwnTransportTrip,

  /// Driver: start/end a trip. Attendants deliberately do NOT hold this.
  operateTransportTrip,

  /// Driver/attendant: record boarding + alighting for today's trip.
  recordTransportBoarding,

  /// Driver/attendant: raise an SOS.
  raiseTransportSos,

  /// Parent: read THEIR OWN child's allocation + active trip. Never a list.
  viewChildTransport,

  /// Student: read their own route/stop/times. Never a manifest.
  viewOwnTransport,

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
