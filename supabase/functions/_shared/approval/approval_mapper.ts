import type { ApprovalAuditRow, ApprovalRequestRow } from "./approval_types.ts";

export function approvalRequestToApi(row: ApprovalRequestRow): Record<string, unknown> {
  return {
    id: row.id,
    type: row.type,
    status: row.status,
    title: row.title,
    summary: row.summary,
    requesterId: row.requester_id,
    requesterName: row.requester_name,
    entityType: row.entity_type,
    entityId: row.entity_id,
    payload: row.payload ?? {},
    createdAt: row.created_at,
    decidedAt: row.decided_at,
    decidedById: row.decided_by_id,
    decidedByName: row.decided_by_name,
    decisionComment: row.decision_comment,
    tenantId: row.organization_id,
    schoolId: row.school_id,
  };
}

export function approvalAuditToApi(row: ApprovalAuditRow): Record<string, unknown> {
  const metadata = row.metadata ?? {};
  const stringMetadata: Record<string, string> = {};
  for (const [key, value] of Object.entries(metadata)) {
    if (value != null) stringMetadata[key] = String(value);
  }

  return {
    id: row.id,
    approvalRequestId: row.approval_request_id,
    action: row.action,
    actorId: row.actor_id,
    actorName: row.actor_name,
    occurredAt: row.occurred_at,
    comment: row.comment,
    tenantId: row.organization_id,
    schoolId: row.school_id,
    metadata: stringMetadata,
  };
}

export function listEnvelope(items: Record<string, unknown>[]) {
  return { items };
}
