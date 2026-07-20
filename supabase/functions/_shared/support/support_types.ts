// ASIP — shared types for the platform-support module (`/support`).
//
// These are the wire contract between the Flutter client and the edge. Kept in
// one place so handlers, repository, collector, package assembler and tests
// share exactly one definition (Constitution LAW 9 — no duplicate contracts).

export const SUPPORT_STATUSES = [
  "new",
  "triaging",
  "in_progress",
  "awaiting_customer",
  "resolved",
  "closed",
] as const;
export type SupportStatus = (typeof SUPPORT_STATUSES)[number];

export const SUPPORT_SEVERITIES = ["sev1", "sev2", "sev3", "sev4"] as const;
export type SupportSeverity = (typeof SUPPORT_SEVERITIES)[number];

/** Soft category set (free text within a known set — a new category never needs
 * a migration). Deterministic categorizer maps to these; a human/AI can refine. */
export const SUPPORT_CATEGORIES = [
  "crash",
  "login_auth",
  "permission_rbac",
  "data_incorrect",
  "missing_feature",
  "ui_display",
  "performance",
  "payment_billing",
  "sync_offline",
  "notification",
  "unknown",
] as const;
export type SupportCategory = (typeof SUPPORT_CATEGORIES)[number];

export const ATTACHMENT_KINDS = ["screenshot", "screen_recording", "log_export"] as const;
export type AttachmentKind = (typeof ATTACHMENT_KINDS)[number];

export const EVIDENCE_KINDS = [
  "client_context",
  "breadcrumbs",
  "audit_events",
  "api_calls",
  "workflow_state",
  "diagnostics",
] as const;
export type EvidenceKind = (typeof EVIDENCE_KINDS)[number];

/** The auto-collected technical context the CLIENT posts on create. The user
 * never types any of this — the client fills it from device/session/route/
 * breadcrumb capture. Every field is optional; a missing field never blocks a
 * report. Structural only (no free-text PII). */
export interface ClientContext {
  appVersion?: string;
  platform?: string; // ios | android | web
  deviceModel?: string;
  osVersion?: string;
  sessionId?: string;
  screenRoute?: string;
  moduleKey?: string;
  correlationIds?: string[];
  breadcrumbs?: Breadcrumb[];
  recentApiCalls?: RecentApiCall[];
}

export interface Breadcrumb {
  /** navigation | api | error | action */
  type?: string;
  route?: string;
  message?: string;
  at?: string; // ISO 8601
}

export interface RecentApiCall {
  method?: string;
  path?: string;
  statusCode?: number;
  correlationId?: string;
  at?: string; // ISO 8601
}

export interface CreateIncidentRequest {
  title: string;
  description?: string;
  context?: ClientContext;
}

export interface PostMessageRequest {
  body: string;
  /** support callers only; reporters always post a school_visible message */
  internalNote?: boolean;
}

export interface PresignAttachmentRequest {
  kind: AttachmentKind;
  fileName: string;
  contentType?: string;
  sizeBytes?: number;
}

export interface ConfirmAttachmentRequest {
  kind: AttachmentKind;
  storagePath: string;
  fileName: string;
  contentType?: string;
  sizeBytes?: number;
}

export interface StatusTransitionRequest {
  status: SupportStatus;
  resolutionSummary?: string;
}

export interface ApproveAnalysisRequest {
  version: number;
}

// ── Row shapes (DB) ──────────────────────────────────────────────────────────

export interface IncidentRow {
  id: string;
  organization_id: string;
  school_id: string;
  public_ref: string;
  reporter_user_id: string;
  reporter_role: string;
  title: string;
  description: string;
  category: string;
  status: string;
  severity: string;
  module_key: string | null;
  screen_route: string | null;
  app_version: string | null;
  platform: string | null;
  device_model: string | null;
  os_version: string | null;
  session_id: string | null;
  correlation_id: string | null;
  resolved_by: string | null;
  resolved_at: string | null;
  resolution_summary: string | null;
  first_seen_at: string;
  created_at: string;
  updated_at: string;
}

export interface EventRow {
  id: string;
  incident_id: string;
  event_type: string;
  actor_user_id: string | null;
  from_value: string | null;
  to_value: string | null;
  metadata: Record<string, unknown>;
  created_at: string;
}

export interface MessageRow {
  id: string;
  incident_id: string;
  sender_user_id: string | null;
  sender_kind: string;
  visibility: string;
  body: string;
  created_at: string;
}

export interface EvidenceRow {
  id: string;
  incident_id: string;
  kind: string;
  payload: Record<string, unknown>;
  redacted: boolean;
  collected_at: string;
}

export interface AttachmentRow {
  id: string;
  incident_id: string;
  kind: string;
  storage_path: string;
  file_name: string;
  content_type: string;
  size_bytes: number;
  uploaded_by: string;
  created_at: string;
}

export interface AnalysisRow {
  id: string;
  incident_id: string;
  version: number;
  categorization: Record<string, unknown>;
  severity_suggestion: string | null;
  summary: string;
  likely_root_cause: string;
  suggested_next_steps: unknown[];
  confidence: number;
  method: string;
  model: string;
  evidence_digest: string;
  approved_by: string | null;
  approved_at: string | null;
  generated_at: string;
}
