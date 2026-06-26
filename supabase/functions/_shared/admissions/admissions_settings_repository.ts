import type { TenantQueryClient } from "../tenant_db.ts";

// ─── admissions_entities JSONB store ─────────────────────────────────────────
// Settings live as a single singleton row (entity_type='settings', id='current').
// Approval notes live as one row per note (entity_type='approval_note',
// id=<note uuid>) with the parent application id stored inside the payload.

interface AdmissionsEntityRow {
  id: string;
  payload: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

const SETTINGS_ENTITY_TYPE = "settings";
const SETTINGS_ENTITY_ID = "current";
const APPROVAL_NOTE_ENTITY_TYPE = "approval_note";

/**
 * Sane, clearly-labelled DEFAULT admissions configuration returned when no
 * snapshot has been saved yet. These are honest defaults (the standard pipeline
 * stages / score bands / workflow), NOT fabricated per-school data.
 */
export function defaultAdmissionsSettings(): Record<string, unknown> {
  return {
    leadStages: [
      { stage: "new_enquiry", enabled: true, autoAdvanceDays: null },
      { stage: "contacted", enabled: true, autoAdvanceDays: 3 },
      { stage: "school_visit", enabled: true, autoAdvanceDays: 7 },
      { stage: "demo_class", enabled: true, autoAdvanceDays: 7 },
      { stage: "application", enabled: true, autoAdvanceDays: null },
      { stage: "admission_confirmed", enabled: true, autoAdvanceDays: null },
      { stage: "joined", enabled: true, autoAdvanceDays: null },
    ],
    leadScores: [
      { score: "hot", minEngagement: 8, followUpHours: 4 },
      { score: "warm", minEngagement: 4, followUpHours: 24 },
      { score: "cold", minEngagement: 0, followUpHours: 72 },
    ],
    workflowSteps: [
      { status: "submitted", enabled: true, requiresPrincipalApproval: false },
      { status: "documents_pending", enabled: true, requiresPrincipalApproval: false },
      { status: "under_review", enabled: true, requiresPrincipalApproval: false },
      { status: "approved", enabled: true, requiresPrincipalApproval: true },
      { status: "rejected", enabled: true, requiresPrincipalApproval: true },
    ],
    assignmentRules: [
      {
        id: "rule_round_robin",
        label: "Round-robin across counselors",
        strategy: "round_robin",
        enabled: true,
      },
    ],
    notificationTemplates: [
      {
        id: "tpl_enquiry_ack",
        name: "Enquiry acknowledgement",
        channel: "whatsapp",
        preview: "Thank you for your interest. Our team will reach out shortly.",
        enabled: true,
      },
    ],
    isDefault: true,
  };
}

export async function getAdmissionsSettings(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<{ settings: Record<string, unknown>; isDefault: boolean }> {
  const rows = await db.queryObject<AdmissionsEntityRow>(
    `SELECT id, payload, created_at, updated_at FROM admissions_entities
     WHERE organization_id = $1 AND school_id = $2
       AND entity_type = $3 AND id = $4`,
    [organizationId, schoolId, SETTINGS_ENTITY_TYPE, SETTINGS_ENTITY_ID],
  );
  const saved = rows[0]?.payload;
  if (!saved || Object.keys(saved).length === 0) {
    return { settings: defaultAdmissionsSettings(), isDefault: true };
  }
  return { settings: saved, isDefault: false };
}

/** erp_tenant has no DELETE-on-conflict primitive here; UPDATE-first then INSERT. */
export async function saveAdmissionsSettings(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  settings: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const payload = JSON.stringify(settings);
  const updated = await db.queryObject<AdmissionsEntityRow>(
    `UPDATE admissions_entities SET payload = $5::jsonb
     WHERE organization_id = $1 AND school_id = $2
       AND entity_type = $3 AND id = $4
     RETURNING id, payload, created_at, updated_at`,
    [organizationId, schoolId, SETTINGS_ENTITY_TYPE, SETTINGS_ENTITY_ID, payload],
  );
  if (updated[0]) return updated[0].payload;

  const inserted = await db.queryObject<AdmissionsEntityRow>(
    `INSERT INTO admissions_entities (
       organization_id, school_id, entity_type, id, payload
     ) VALUES ($1, $2, $3, $4, $5::jsonb)
     RETURNING id, payload, created_at, updated_at`,
    [organizationId, schoolId, SETTINGS_ENTITY_TYPE, SETTINGS_ENTITY_ID, payload],
  );
  return inserted[0]!.payload;
}

// ─── Approval notes ──────────────────────────────────────────────────────────

export interface ApprovalNoteRecord {
  id: string;
  applicationId: string;
  author: string;
  content: string;
  createdAt: string;
}

export async function addApprovalNote(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  applicationId: string,
  author: string,
  content: string,
): Promise<ApprovalNoteRecord> {
  const noteId = crypto.randomUUID();
  const payload = JSON.stringify({ applicationId, author, content });
  const rows = await db.queryObject<AdmissionsEntityRow>(
    `INSERT INTO admissions_entities (
       organization_id, school_id, entity_type, id, payload
     ) VALUES ($1, $2, $3, $4, $5::jsonb)
     RETURNING id, payload, created_at, updated_at`,
    [organizationId, schoolId, APPROVAL_NOTE_ENTITY_TYPE, noteId, payload],
  );
  const row = rows[0]!;
  const p = row.payload;
  return {
    id: row.id,
    applicationId: String(p.applicationId ?? applicationId),
    author: String(p.author ?? author),
    content: String(p.content ?? content),
    createdAt: row.created_at,
  };
}

export async function listApprovalNotes(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  applicationId: string,
): Promise<ApprovalNoteRecord[]> {
  const rows = await db.queryObject<AdmissionsEntityRow>(
    `SELECT id, payload, created_at, updated_at FROM admissions_entities
     WHERE organization_id = $1 AND school_id = $2
       AND entity_type = $3
       AND payload->>'applicationId' = $4
     ORDER BY created_at DESC`,
    [organizationId, schoolId, APPROVAL_NOTE_ENTITY_TYPE, applicationId],
  );
  return rows.map((row) => {
    const p = row.payload;
    return {
      id: row.id,
      applicationId: String(p.applicationId ?? applicationId),
      author: String(p.author ?? ""),
      content: String(p.content ?? ""),
      createdAt: row.created_at,
    };
  });
}
