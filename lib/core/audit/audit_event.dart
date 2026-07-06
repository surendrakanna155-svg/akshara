import 'package:flutter/foundation.dart';

import '../network/api_config.dart';
import 'audit_security_categorizer.dart';

/// Compliance grouping for audit events.
enum AuditEventCategory {
  security,
  auth,
  workflow,
  system,
}

/// Categories of security-relevant client events.
enum AuditEventType {
  login,
  logout,
  tokenRefresh,
  accessDenied,
  roleChange,
  tenantChange,
  sessionRevoked,
  logoutAllSessions,
  permissionSync,
  permissionDenied,
  auditUploadFailed,
  leadCreated,
  leadUpdated,
  leadAssigned,
  leadStageChanged,
  followupAdded,
  applicationSubmitted,
  enrollmentSubmitted,
  documentUploaded,
  documentApproved,
  documentRejected,
  admissionApproved,
  admissionRejected,
  financeHandoffSent,
  vendorCreated,
  purchaseOrderCreated,
  procurementFinancePosted,
  goodsReceived,
  onboardingImportPreviewed,
  onboardingImportCommitted,
  onboardingImportRolledBack,
  onboardingInviteSent,
  paymentInitiated,
  paymentCaptured,
  studentUpdated,
  refundApproved,
  refundRejected,
  collectionCreated,
  collectionCancelled,
  invoiceIssued,
  invoiceCancelled,
  feeStructureCreated,
  feeStructureUpdated,
  feeStructureArchived,
  feeAssignmentCreated,
  feeAssignmentCancelled,
  sisEnrollmentCreated,
  sisEnrollmentUpdated,
  admissionsConversionCompleted,
  academicYearCreated,
  academicYearUpdated,
  academicClassCreated,
  academicClassUpdated,
  academicSectionCreated,
  academicSectionUpdated,
  academicTeacherAssignmentCreated,
  academicTeacherAssignmentUpdated,
  aiCopilotSessionCreated,
  aiCopilotQuery,
  aiCopilotResponse,

  // Academic timetable (v7.5)
  academicTimetableGenerated,
  academicTimetablePublished,

  employeeCreated,
  employeeUpdated,
  employeeStatusChanged,
  leaveRequestApproved,
  leaveRequestRejected,
  receiptPdfExported,
  // FIN-R7: instrument (cheque/DD/PDC) dishonoured — tracking-only, no money.
  offlinePaymentBounced,

  // Phase A M-A5 — Exam results governance
  examMarkUpdated,
  examResultsSubmittedForVerification,
  examResultsCoordinatorVerified,
  examResultsSubmittedForApproval,
  examResultsPublished,

  transportStudentAssigned,
  transportStudentTransferred,
  transportStudentRemoved,
  transportAttendanceRecorded,
  transportDelayNotified,

  // O5 — staff biometric self check-in/out.
  staffCheckInRecorded,
  staffCheckOutRecorded,

  errorReported,
}

/// Immutable audit record stored locally until server ingestion is available.
@immutable
class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    this.userId,
    this.tenantId,
    this.schoolId,
    this.correlationId,
    this.category,
    this.metadata = const {},
  });

  final String id;
  final AuditEventType type;
  final DateTime timestamp;
  final String? userId;
  final String? tenantId;
  final String? schoolId;
  final String? correlationId;
  final AuditEventCategory? category;
  final Map<String, String> metadata;

  /// Reads correlation ID from metadata using the same header name as
  /// [CorrelationIdInterceptor] (`X-Correlation-Id`).
  static String? correlationIdFromMetadata(Map<String, String> metadata) {
    return metadata['correlationId'] ??
        metadata[ApiConfig.correlationIdHeader];
  }

  AuditEventCategory get resolvedCategory =>
      category ?? AuditSecurityCategorizer.categorize(type);

  factory AuditEvent.fromJson(Map<String, dynamic> json) {
    return AuditEvent(
      id: json['id'] as String? ?? '',
      type: AuditEventType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => AuditEventType.login,
      ),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      userId: json['userId'] as String?,
      tenantId: json['tenantId'] as String?,
      schoolId: json['schoolId'] as String?,
      correlationId: json['correlationId'] as String?,
      category: _categoryFromJson(json['category'] as String?),
      metadata: {
        for (final entry
            in (json['metadata'] as Map<String, dynamic>? ?? const {}).entries)
          entry.key: '${entry.value}',
      },
    );
  }

  static AuditEventCategory? _categoryFromJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return AuditEventCategory.values.firstWhere(
      (c) => c.name == raw,
      orElse: () => AuditEventCategory.system,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        if (userId != null) 'userId': userId,
        if (tenantId != null) 'tenantId': tenantId,
        if (schoolId != null) 'schoolId': schoolId,
        if (correlationId != null) 'correlationId': correlationId,
        if (category != null) 'category': category!.name,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  AuditEvent copyWith({
    String? id,
    AuditEventType? type,
    DateTime? timestamp,
    String? userId,
    String? tenantId,
    String? schoolId,
    String? correlationId,
    AuditEventCategory? category,
    Map<String, String>? metadata,
  }) {
    return AuditEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      tenantId: tenantId ?? this.tenantId,
      schoolId: schoolId ?? this.schoolId,
      correlationId: correlationId ?? this.correlationId,
      category: category ?? this.category,
      metadata: metadata ?? this.metadata,
    );
  }
}
