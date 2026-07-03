import 'package:flutter/foundation.dart';

import 'approval_models.dart';
import 'approval_request_type.dart';

/// Payload to create a new approval request.
@immutable
class SubmitApprovalRequest {
  const SubmitApprovalRequest({
    required this.type,
    required this.title,
    required this.summary,
    required this.requesterId,
    required this.requesterName,
    required this.entityType,
    required this.entityId,
    this.payload = const {},
  });

  final ApprovalRequestType type;
  final String title;
  final String summary;
  final String requesterId;
  final String requesterName;
  final String entityType;
  final String entityId;
  final Map<String, Object?> payload;
}

/// Principal / approver decision to approve a pending request.
@immutable
class ApproveApprovalRequest {
  const ApproveApprovalRequest({
    required this.approvalId,
    required this.actorId,
    required this.actorName,
    this.comment,
  });

  final String approvalId;
  final String actorId;
  final String actorName;
  final String? comment;
}

/// Principal / approver decision to reject a pending request.
@immutable
class RejectApprovalRequest {
  const RejectApprovalRequest({
    required this.approvalId,
    required this.actorId,
    required this.actorName,
    required this.comment,
  });

  final String approvalId;
  final String actorId;
  final String actorName;
  final String comment;
}

/// PRI-1 — a principal's batch approve/reject over many pending requests.
/// `reject` requires a non-empty [comment] (whole-batch validation error).
@immutable
class BatchDecideApprovalsRequest {
  const BatchDecideApprovalsRequest({
    required this.ids,
    required this.decision,
    required this.actorId,
    required this.actorName,
    this.comment,
  });

  final List<String> ids;
  final ApprovalBatchDecision decision;
  final String actorId;
  final String actorName;
  final String? comment;
}

/// Requester or system cancellation of a pending approval.
@immutable
class CancelApprovalRequest {
  const CancelApprovalRequest({
    required this.approvalId,
    required this.actorId,
    required this.actorName,
    this.comment,
  });

  final String approvalId;
  final String actorId;
  final String actorName;
  final String? comment;
}
