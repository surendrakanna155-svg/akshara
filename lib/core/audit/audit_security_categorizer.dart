import 'audit_event.dart';

/// Maps [AuditEventType] values to compliance categories.
abstract final class AuditSecurityCategorizer {
  static AuditEventCategory categorize(AuditEventType type) {
    switch (type) {
      case AuditEventType.login:
      case AuditEventType.logout:
      case AuditEventType.tokenRefresh:
        return AuditEventCategory.auth;

      case AuditEventType.accessDenied:
      case AuditEventType.roleChange:
      case AuditEventType.tenantChange:
      case AuditEventType.sessionRevoked:
      case AuditEventType.logoutAllSessions:
      case AuditEventType.permissionSync:
      case AuditEventType.permissionDenied:
      case AuditEventType.auditUploadFailed:
        return AuditEventCategory.security;

      case AuditEventType.leadCreated:
      case AuditEventType.leadUpdated:
      case AuditEventType.leadAssigned:
      case AuditEventType.leadStageChanged:
      case AuditEventType.followupAdded:
      case AuditEventType.applicationSubmitted:
      case AuditEventType.enrollmentSubmitted:
      case AuditEventType.documentUploaded:
      case AuditEventType.documentApproved:
      case AuditEventType.documentRejected:
      case AuditEventType.admissionApproved:
      case AuditEventType.admissionRejected:
      case AuditEventType.financeHandoffSent:
      case AuditEventType.vendorCreated:
      case AuditEventType.purchaseOrderCreated:
      case AuditEventType.procurementFinancePosted:
      case AuditEventType.goodsReceived:
      case AuditEventType.onboardingImportPreviewed:
      case AuditEventType.onboardingImportCommitted:
      case AuditEventType.onboardingImportRolledBack:
      case AuditEventType.onboardingInviteSent:
      case AuditEventType.paymentInitiated:
      case AuditEventType.paymentCaptured:
      case AuditEventType.studentUpdated:
      case AuditEventType.refundApproved:
      case AuditEventType.refundRejected:
      case AuditEventType.collectionCreated:
      case AuditEventType.collectionCancelled:
      case AuditEventType.invoiceIssued:
      case AuditEventType.invoiceCancelled:
      case AuditEventType.feeStructureCreated:
      case AuditEventType.feeStructureUpdated:
      case AuditEventType.feeStructureArchived:
      case AuditEventType.feeAssignmentCreated:
      case AuditEventType.feeAssignmentCancelled:
      case AuditEventType.sisEnrollmentCreated:
      case AuditEventType.sisEnrollmentUpdated:
      case AuditEventType.admissionsConversionCompleted:
      case AuditEventType.academicYearCreated:
      case AuditEventType.academicYearUpdated:
      case AuditEventType.academicClassCreated:
      case AuditEventType.academicClassUpdated:
      case AuditEventType.academicSectionCreated:
      case AuditEventType.academicSectionUpdated:
      case AuditEventType.academicTeacherAssignmentCreated:
      case AuditEventType.academicTeacherAssignmentUpdated:
      case AuditEventType.aiCopilotSessionCreated:
      case AuditEventType.aiCopilotQuery:
      case AuditEventType.aiCopilotResponse:
      case AuditEventType.academicTimetableGenerated:
      case AuditEventType.academicTimetablePublished:
      case AuditEventType.employeeCreated:
      case AuditEventType.employeeUpdated:
      case AuditEventType.employeeStatusChanged:
      case AuditEventType.leaveRequestApproved:
      case AuditEventType.leaveRequestRejected:
      case AuditEventType.receiptPdfExported:
      case AuditEventType.examMarkUpdated:
      case AuditEventType.examResultsSubmittedForVerification:
      case AuditEventType.examResultsCoordinatorVerified:
      case AuditEventType.examResultsSubmittedForApproval:
      case AuditEventType.examResultsPublished:
      case AuditEventType.transportStudentAssigned:
      case AuditEventType.transportStudentTransferred:
      case AuditEventType.transportStudentRemoved:
      case AuditEventType.transportAttendanceRecorded:
      case AuditEventType.transportDelayNotified:
        return AuditEventCategory.workflow;

      case AuditEventType.errorReported:
        return AuditEventCategory.system;
    }
  }
}
