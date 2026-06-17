import 'package:flutter/foundation.dart';

import 'approval_request_type.dart';
import 'approval_status.dart';

/// Domain model for a unified cross-module approval request.
@immutable
class ApprovalRequest {
  const ApprovalRequest({
    required this.id,
    required this.type,
    required this.status,
    required this.title,
    required this.summary,
    required this.requesterId,
    required this.requesterName,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    this.payload = const {},
    this.decidedAt,
    this.decidedById,
    this.decidedByName,
    this.decisionComment,
    this.tenantId,
    this.schoolId,
  });

  final String id;
  final ApprovalRequestType type;
  final ApprovalStatus status;
  final String title;
  final String summary;
  final String requesterId;
  final String requesterName;
  final String entityType;
  final String entityId;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final String? decidedById;
  final String? decidedByName;
  final String? decisionComment;
  final String? tenantId;
  final String? schoolId;

  bool get isPending => status == ApprovalStatus.pending;

  ApprovalRequest copyWith({
    ApprovalStatus? status,
    DateTime? decidedAt,
    String? decidedById,
    String? decidedByName,
    String? decisionComment,
  }) {
    return ApprovalRequest(
      id: id,
      type: type,
      status: status ?? this.status,
      title: title,
      summary: summary,
      requesterId: requesterId,
      requesterName: requesterName,
      entityType: entityType,
      entityId: entityId,
      payload: payload,
      createdAt: createdAt,
      decidedAt: decidedAt ?? this.decidedAt,
      decidedById: decidedById ?? this.decidedById,
      decidedByName: decidedByName ?? this.decidedByName,
      decisionComment: decisionComment ?? this.decisionComment,
      tenantId: tenantId,
      schoolId: schoolId,
    );
  }
}

/// Filter for listing approval requests.
@immutable
class ApprovalListFilter {
  const ApprovalListFilter({
    this.status,
    this.type,
    this.requesterId,
    this.entityType,
    this.entityId,
  });

  final ApprovalStatus? status;
  final ApprovalRequestType? type;
  final String? requesterId;
  final String? entityType;
  final String? entityId;
}
