// ASIP — data access for the platform-support module. Runs on the non-bypass
// erp_tenant client (RLS-enforced); every write sets org+school from the claims,
// never the client. INSERT ... RETURNING is safe here because the school-scope
// RLS lets the school user read back their own inserted rows (unlike the
// persona-scoped audit path).

import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type {
  AnalysisRow,
  AttachmentRow,
  EventRow,
  EvidenceRow,
  IncidentRow,
  MessageRow,
} from "./support_types.ts";

const INCIDENT_COLUMNS = `
  id, organization_id, school_id, public_ref, reporter_user_id, reporter_role,
  title, description, category, status, severity, module_key, screen_route,
  app_version, platform, device_model, os_version, session_id, correlation_id,
  resolved_by, resolved_at, resolution_summary, first_seen_at, created_at, updated_at
`;

export interface NewIncidentInput {
  title: string;
  description: string;
  category: string;
  severity: string;
  moduleKey: string | null;
  screenRoute: string | null;
  appVersion: string | null;
  platform: string | null;
  deviceModel: string | null;
  osVersion: string | null;
  sessionId: string | null;
  correlationId: string | null;
}

export async function insertIncident(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  input: NewIncidentInput,
): Promise<IncidentRow> {
  const rows = await db.queryObject<IncidentRow>(
    `INSERT INTO support_incident (
       organization_id, school_id, reporter_user_id, reporter_role,
       title, description, category, severity,
       module_key, screen_route, app_version, platform, device_model,
       os_version, session_id, correlation_id
     ) VALUES (
       $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16
     )
     RETURNING ${INCIDENT_COLUMNS}`,
    [
      claims.tenant_id,
      claims.school_id,
      claims.sub,
      claims.primary_role ?? claims.role ?? "",
      input.title,
      input.description,
      input.category,
      input.severity,
      input.moduleKey,
      input.screenRoute,
      input.appVersion,
      input.platform,
      input.deviceModel,
      input.osVersion,
      input.sessionId,
      input.correlationId,
    ],
  );
  return rows[0];
}

export interface ListIncidentsFilter {
  reporterOnly: boolean;
  reporterUserId: string;
  status?: string;
  page: number;
  pageSize: number;
}

export interface IncidentPage {
  items: IncidentRow[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

export async function listIncidents(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  filter: ListIncidentsFilter,
): Promise<IncidentPage> {
  const limit = Math.min(Math.max(filter.pageSize, 1), 100);
  const offset = (Math.max(filter.page, 1) - 1) * limit;

  const where: string[] = ["organization_id = $1", "school_id = $2"];
  const args: unknown[] = [claims.tenant_id, claims.school_id];

  if (filter.reporterOnly) {
    args.push(filter.reporterUserId);
    where.push(`reporter_user_id = $${args.length}::uuid`);
  }
  if (filter.status) {
    args.push(filter.status);
    where.push(`status = $${args.length}`);
  }
  const whereSql = where.join(" AND ");

  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM support_incident WHERE ${whereSql}`,
    args,
  );
  const items = await db.queryObject<IncidentRow>(
    `SELECT ${INCIDENT_COLUMNS}
       FROM support_incident
      WHERE ${whereSql}
      ORDER BY created_at DESC, id DESC
      LIMIT $${args.length + 1} OFFSET $${args.length + 2}`,
    [...args, limit, offset],
  );
  return {
    items,
    total,
    page: Math.max(filter.page, 1),
    pageSize: limit,
    hasMore: offset + items.length < total,
  };
}

export async function getIncident(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incidentId: string,
): Promise<IncidentRow | null> {
  const rows = await db.queryObject<IncidentRow>(
    `SELECT ${INCIDENT_COLUMNS}
       FROM support_incident
      WHERE organization_id = $1 AND school_id = $2 AND id = $3::uuid`,
    [claims.tenant_id, claims.school_id, incidentId],
  );
  return rows[0] ?? null;
}

export interface NewEventInput {
  eventType: string;
  actorUserId: string | null;
  fromValue?: string | null;
  toValue?: string | null;
  metadata?: Record<string, unknown>;
}

export async function insertEvent(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incidentId: string,
  input: NewEventInput,
): Promise<void> {
  await db.queryObject(
    `INSERT INTO support_incident_event (
       organization_id, school_id, incident_id, event_type, actor_user_id,
       from_value, to_value, metadata
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)`,
    [
      claims.tenant_id,
      claims.school_id,
      incidentId,
      input.eventType,
      input.actorUserId,
      input.fromValue ?? null,
      input.toValue ?? null,
      JSON.stringify(input.metadata ?? {}),
    ],
  );
}

export async function listEvents(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incidentId: string,
): Promise<EventRow[]> {
  return await db.queryObject<EventRow>(
    `SELECT id, incident_id, event_type, actor_user_id, from_value, to_value,
            metadata, created_at
       FROM support_incident_event
      WHERE organization_id = $1 AND school_id = $2 AND incident_id = $3::uuid
      ORDER BY created_at ASC, id ASC`,
    [claims.tenant_id, claims.school_id, incidentId],
  );
}

export interface NewMessageInput {
  senderUserId: string | null;
  senderKind: string;
  visibility: string;
  body: string;
}

export async function insertMessage(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incidentId: string,
  input: NewMessageInput,
): Promise<MessageRow> {
  const rows = await db.queryObject<MessageRow>(
    `INSERT INTO support_incident_message (
       organization_id, school_id, incident_id, sender_user_id, sender_kind,
       visibility, body
     ) VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING id, incident_id, sender_user_id, sender_kind, visibility, body, created_at`,
    [
      claims.tenant_id,
      claims.school_id,
      incidentId,
      input.senderUserId,
      input.senderKind,
      input.visibility,
      input.body,
    ],
  );
  return rows[0];
}

export async function listMessages(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incidentId: string,
  includeInternal: boolean,
): Promise<MessageRow[]> {
  const where = includeInternal ? "" : " AND visibility = 'school_visible'";
  return await db.queryObject<MessageRow>(
    `SELECT id, incident_id, sender_user_id, sender_kind, visibility, body, created_at
       FROM support_incident_message
      WHERE organization_id = $1 AND school_id = $2 AND incident_id = $3::uuid${where}
      ORDER BY created_at ASC, id ASC`,
    [claims.tenant_id, claims.school_id, incidentId],
  );
}

export interface NewEvidenceInput {
  kind: string;
  payload: Record<string, unknown>;
  redacted: boolean;
}

export async function insertEvidence(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incidentId: string,
  input: NewEvidenceInput,
): Promise<void> {
  await db.queryObject(
    `INSERT INTO support_incident_evidence (
       organization_id, school_id, incident_id, kind, payload, redacted
     ) VALUES ($1, $2, $3, $4, $5::jsonb, $6)`,
    [
      claims.tenant_id,
      claims.school_id,
      incidentId,
      input.kind,
      JSON.stringify(input.payload),
      input.redacted,
    ],
  );
}

/** Latest evidence row per kind (a re-collection supersedes an older snapshot). */
export async function listLatestEvidence(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incidentId: string,
): Promise<EvidenceRow[]> {
  return await db.queryObject<EvidenceRow>(
    `SELECT DISTINCT ON (kind)
            id, incident_id, kind, payload, redacted, collected_at
       FROM support_incident_evidence
      WHERE organization_id = $1 AND school_id = $2 AND incident_id = $3::uuid
      ORDER BY kind, collected_at DESC, id DESC`,
    [claims.tenant_id, claims.school_id, incidentId],
  );
}

export interface NewAttachmentInput {
  kind: string;
  storagePath: string;
  fileName: string;
  contentType: string;
  sizeBytes: number;
  uploadedBy: string;
}

export async function insertAttachment(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incidentId: string,
  input: NewAttachmentInput,
): Promise<AttachmentRow> {
  const rows = await db.queryObject<AttachmentRow>(
    `INSERT INTO support_incident_attachment (
       organization_id, school_id, incident_id, kind, storage_path, file_name,
       content_type, size_bytes, uploaded_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     RETURNING id, incident_id, kind, storage_path, file_name, content_type,
               size_bytes, uploaded_by, created_at`,
    [
      claims.tenant_id,
      claims.school_id,
      incidentId,
      input.kind,
      input.storagePath,
      input.fileName,
      input.contentType,
      input.sizeBytes,
      input.uploadedBy,
    ],
  );
  return rows[0];
}

export async function listAttachments(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incidentId: string,
): Promise<AttachmentRow[]> {
  return await db.queryObject<AttachmentRow>(
    `SELECT id, incident_id, kind, storage_path, file_name, content_type,
            size_bytes, uploaded_by, created_at
       FROM support_incident_attachment
      WHERE organization_id = $1 AND school_id = $2 AND incident_id = $3::uuid
      ORDER BY created_at ASC, id ASC`,
    [claims.tenant_id, claims.school_id, incidentId],
  );
}

export interface NewAnalysisInput {
  categorization: Record<string, unknown>;
  severitySuggestion: string | null;
  summary: string;
  likelyRootCause: string;
  suggestedNextSteps: unknown[];
  confidence: number;
  method: string;
  model: string;
  evidenceDigest: string;
}

export async function nextAnalysisVersion(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incidentId: string,
): Promise<number> {
  const rows = await db.queryObject<{ next: string }>(
    `SELECT (COALESCE(MAX(version), 0) + 1)::text AS next
       FROM support_incident_ai_analysis
      WHERE organization_id = $1 AND school_id = $2 AND incident_id = $3::uuid`,
    [claims.tenant_id, claims.school_id, incidentId],
  );
  return Number(rows[0]?.next ?? "1");
}

export async function insertAnalysis(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incidentId: string,
  version: number,
  input: NewAnalysisInput,
): Promise<AnalysisRow> {
  const rows = await db.queryObject<AnalysisRow>(
    `INSERT INTO support_incident_ai_analysis (
       organization_id, school_id, incident_id, version, categorization,
       severity_suggestion, summary, likely_root_cause, suggested_next_steps,
       confidence, method, model, evidence_digest
     ) VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7, $8, $9::jsonb, $10, $11, $12, $13)
     RETURNING id, incident_id, version, categorization, severity_suggestion,
               summary, likely_root_cause, suggested_next_steps, confidence,
               method, model, evidence_digest, approved_by, approved_at, generated_at`,
    [
      claims.tenant_id,
      claims.school_id,
      incidentId,
      version,
      JSON.stringify(input.categorization),
      input.severitySuggestion,
      input.summary,
      input.likelyRootCause,
      JSON.stringify(input.suggestedNextSteps),
      input.confidence,
      input.method,
      input.model,
      input.evidenceDigest,
    ],
  );
  return rows[0];
}

export async function getLatestAnalysis(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incidentId: string,
): Promise<AnalysisRow | null> {
  const rows = await db.queryObject<AnalysisRow>(
    `SELECT id, incident_id, version, categorization, severity_suggestion,
            summary, likely_root_cause, suggested_next_steps, confidence,
            method, model, evidence_digest, approved_by, approved_at, generated_at
       FROM support_incident_ai_analysis
      WHERE organization_id = $1 AND school_id = $2 AND incident_id = $3::uuid
      ORDER BY version DESC
      LIMIT 1`,
    [claims.tenant_id, claims.school_id, incidentId],
  );
  return rows[0] ?? null;
}

/** Human-approval stamp: transitions approved_by/at from NULL → set for exactly
 * one (incident, version). Returns the number of rows updated (0 = already
 * approved or not found). Never un-approves and never edits content. */
export async function approveAnalysis(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incidentId: string,
  version: number,
  approvedBy: string,
): Promise<number> {
  const rows = await db.queryObject<{ id: string }>(
    `UPDATE support_incident_ai_analysis
        SET approved_by = $4::uuid, approved_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2 AND incident_id = $3::uuid
        AND version = $5 AND approved_by IS NULL
      RETURNING id`,
    [claims.tenant_id, claims.school_id, incidentId, approvedBy, version],
  );
  return rows.length;
}

export interface StatusUpdateInput {
  status: string;
  resolvedBy?: string | null;
  resolutionSummary?: string | null;
}

/** Guarded status transition: writes only when the CURRENT status is `fromStatus`
 * (optimistic guard against a concurrent double-transition). Returns the updated
 * row, or null when the guard failed (status already moved). */
export async function updateIncidentStatus(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incidentId: string,
  fromStatus: string,
  input: StatusUpdateInput,
): Promise<IncidentRow | null> {
  const setResolved = input.status === "resolved";
  const rows = await db.queryObject<IncidentRow>(
    `UPDATE support_incident
        SET status = $4,
            resolved_by = CASE WHEN $5 THEN $6::uuid ELSE resolved_by END,
            resolved_at = CASE WHEN $5 THEN timezone('utc', now()) ELSE resolved_at END,
            resolution_summary = COALESCE($7, resolution_summary)
      WHERE organization_id = $1 AND school_id = $2 AND id = $3::uuid
        AND status = $8
      RETURNING ${INCIDENT_COLUMNS}`,
    [
      claims.tenant_id,
      claims.school_id,
      incidentId,
      input.status,
      setResolved,
      input.resolvedBy ?? null,
      input.resolutionSummary ?? null,
      fromStatus,
    ],
  );
  return rows[0] ?? null;
}

/**
 * RC-5 (audit P1-E): incidents in the caller's org that the mirror reconcile
 * sweep should re-mirror.
 *
 * A bounded, most-recent-first window rather than "everything": the sweep exists
 * to repair mirrors lost to a transient failure at create time, and those are
 * recent by definition. Re-mirroring is an upsert, so covering already-mirrored
 * incidents is a harmless no-op — which is what lets this run without reading
 * across the RLS wall into the platform-support domain (a school session cannot
 * see the mirror, so it cannot ask which rows are missing).
 */
export async function listIncidentsForMirrorReconcile(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  opts: { sinceDays: number; limit: number },
): Promise<IncidentRow[]> {
  const sinceDays = Math.min(Math.max(opts.sinceDays, 1), 90);
  const limit = Math.min(Math.max(opts.limit, 1), 500);
  return await db.queryObject<IncidentRow>(
    `SELECT * FROM support_incident
      WHERE organization_id = $1
        AND created_at >= timezone('utc', now()) - ($2 || ' days')::interval
      ORDER BY created_at DESC
      LIMIT $3`,
    [claims.tenant_id, String(sinceDays), limit],
  );
}
