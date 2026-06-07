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
      case AuditEventType.documentApproved:
      case AuditEventType.documentRejected:
      case AuditEventType.admissionApproved:
      case AuditEventType.admissionRejected:
      case AuditEventType.financeHandoffSent:
        return AuditEventCategory.workflow;
    }
  }
}
