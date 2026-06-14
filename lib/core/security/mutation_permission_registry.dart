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
