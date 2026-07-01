/** F2 approval request row from PostgreSQL. */
export interface ApprovalRequestRow {
  id: string;
  organization_id: string;
  school_id: string;
  type: string;
  status: string;
  title: string;
  summary: string;
  requester_id: string;
  requester_name: string;
  entity_type: string;
  entity_id: string;
  payload: Record<string, unknown>;
  decided_at: string | null;
  decided_by_id: string | null;
  decided_by_name: string | null;
  decision_comment: string | null;
  created_at: string;
  updated_at: string;
}

export interface ApprovalAuditRow {
  id: string;
  organization_id: string;
  school_id: string;
  approval_request_id: string;
  action: string;
  actor_id: string;
  actor_name: string;
  occurred_at: string;
  comment: string | null;
  metadata: Record<string, unknown>;
}

export type ApprovalStatus = "pending" | "approved" | "rejected" | "cancelled";
export type ApprovalAuditAction = "submitted" | "approved" | "rejected" | "cancelled";

export const F2_APPROVAL_TYPES = [
  "examResults",
  "studentLeave",
  "staffLeave",
  "attendanceCorrection",
  "feeConcession",
  "feeStructure",
  "refund",
  "inventoryPo",
] as const;

export type F2ApprovalType = (typeof F2_APPROVAL_TYPES)[number];

export function isF2ApprovalType(type: string): type is F2ApprovalType {
  return (F2_APPROVAL_TYPES as readonly string[]).includes(type);
}
