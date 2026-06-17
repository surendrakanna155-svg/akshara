import 'package:akshara_erp/core/approvals/approval_audit.dart';
import 'package:akshara_erp/core/approvals/approval_models.dart';
import 'package:akshara_erp/core/approvals/approval_request_type.dart';
import 'package:akshara_erp/core/approvals/approval_requests.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';

/// Test fixtures for approval repository contract tests.
class ApprovalFixtureBuilder {
  SubmitApprovalRequest submitRequest({
    ApprovalRequestType type = ApprovalRequestType.examResults,
    String entityId = 'exam_math_8a',
  }) {
    return SubmitApprovalRequest(
      type: type,
      title: 'Publish Class 8-A Mathematics results',
      summary: 'Half-yearly exam — 32 students',
      requesterId: 'teacher_001',
      requesterName: 'Priya Sharma',
      entityType: 'exam_session',
      entityId: entityId,
      payload: const {'classLabel': '8-A', 'subject': 'Mathematics'},
    );
  }

  ApproveApprovalRequest approveRequest(String approvalId) {
    return ApproveApprovalRequest(
      approvalId: approvalId,
      actorId: 'principal_001',
      actorName: 'Dr. Rao',
      comment: 'Verified marks register.',
    );
  }

  RejectApprovalRequest rejectRequest(String approvalId, {String? comment}) {
    return RejectApprovalRequest(
      approvalId: approvalId,
      actorId: 'principal_001',
      actorName: 'Dr. Rao',
      comment: comment ?? 'Incomplete marks entry.',
    );
  }

  CancelApprovalRequest cancelRequest(String approvalId) {
    return CancelApprovalRequest(
      approvalId: approvalId,
      actorId: 'teacher_001',
      actorName: 'Priya Sharma',
      comment: 'Submitted wrong exam.',
    );
  }

  ApprovalListFilter pendingExamFilter() {
    return const ApprovalListFilter(
      status: ApprovalStatus.pending,
      type: ApprovalRequestType.examResults,
    );
  }

  ApprovalAuditEntry auditEntry({
    required String approvalRequestId,
    required ApprovalAuditAction action,
  }) {
    return ApprovalAuditEntry(
      id: '',
      approvalRequestId: approvalRequestId,
      action: action,
      actorId: 'actor_001',
      actorName: 'Test Actor',
      occurredAt: DateTime.utc(2026, 6, 17),
    );
  }
}
