import 'package:flutter/foundation.dart';

/// Immutable audit action for approval lifecycle events.
enum ApprovalAuditAction {
  submitted,
  approved,
  rejected,
  cancelled,
}

/// Audit record for a single approval decision or submission.
@immutable
class ApprovalAuditEntry {
  const ApprovalAuditEntry({
    required this.id,
    required this.approvalRequestId,
    required this.action,
    required this.actorId,
    required this.actorName,
    required this.occurredAt,
    this.comment,
    this.tenantId,
    this.schoolId,
    this.metadata = const {},
  });

  final String id;
  final String approvalRequestId;
  final ApprovalAuditAction action;
  final String actorId;
  final String actorName;
  final DateTime occurredAt;
  final String? comment;
  final String? tenantId;
  final String? schoolId;
  final Map<String, String> metadata;
}
