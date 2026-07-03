import '../../../../approvals/approval_audit.dart';
import '../../../../approvals/approval_models.dart';
import '../../../../approvals/approval_request_type.dart';
import '../../../../approvals/approval_status.dart';
import '../dto/approval_audit_entry_dto.dart';
import '../dto/approval_request_dto.dart';
import '../dto/approval_request_payload_dto.dart';

class ApprovalMapper {
  const ApprovalMapper();

  ApprovalRequest toDomain(ApprovalRequestDto dto) {
    return ApprovalRequest(
      id: dto.id,
      type: _typeFromWire(dto.type),
      status: _statusFromWire(dto.status),
      title: dto.title,
      summary: dto.summary,
      requesterId: dto.requesterId,
      requesterName: dto.requesterName,
      entityType: dto.entityType,
      entityId: dto.entityId,
      payload: dto.payload,
      createdAt: DateTime.parse(dto.createdAt).toUtc(),
      decidedAt: dto.decidedAt == null ? null : DateTime.parse(dto.decidedAt!).toUtc(),
      decidedById: dto.decidedById,
      decidedByName: dto.decidedByName,
      decisionComment: dto.decisionComment,
      tenantId: dto.tenantId,
      schoolId: dto.schoolId,
    );
  }

  ApprovalAuditEntry auditToDomain(ApprovalAuditEntryDto dto) {
    return ApprovalAuditEntry(
      id: dto.id,
      approvalRequestId: dto.approvalRequestId,
      action: _auditActionFromWire(dto.action),
      actorId: dto.actorId,
      actorName: dto.actorName,
      occurredAt: DateTime.parse(dto.occurredAt).toUtc(),
      comment: dto.comment,
      tenantId: dto.tenantId,
      schoolId: dto.schoolId,
      metadata: dto.metadata,
    );
  }

  BatchDecisionResult batchToDomain(BatchDecisionResultDto dto) {
    return BatchDecisionResult(
      decided: [
        for (final item in dto.decided)
          ApprovalBatchDecidedItem(
            id: item.id,
            status: _statusFromWire(item.status),
          ),
      ],
      skipped: [
        for (final item in dto.skipped)
          ApprovalBatchSkippedItem(id: item.id, reason: item.reason),
      ],
    );
  }

  ApprovalRequestType _typeFromWire(String raw) {
    return ApprovalRequestType.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => ApprovalRequestType.examResults,
    );
  }

  ApprovalStatus _statusFromWire(String raw) {
    return ApprovalStatus.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => ApprovalStatus.pending,
    );
  }

  ApprovalAuditAction _auditActionFromWire(String raw) {
    return ApprovalAuditAction.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => ApprovalAuditAction.submitted,
    );
  }
}
