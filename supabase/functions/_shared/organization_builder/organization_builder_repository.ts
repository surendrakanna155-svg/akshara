// Organization Builder — persistence + deterministic configuration resolution.
//
// B10 (P3). Backs the frozen Flutter contract: vertical-pack catalog, interview
// drafts (client-supplied TEXT id, create-on-demand), a deterministic config
// preview, and REAL provisioning (synchronous, persisted, audited — each step
// reflects work actually done, no simulated timers).
//
// Everything runs on a `withTenantContext` (erp_tenant) connection: the
// org-scope token satisfies the org-scope RLS on these tables, so RLS — not
// application code — is the isolation boundary. Reads/writes additionally filter
// on `organization_id = orgId` as defence-in-depth.

import type { TenantQueryClient } from "../tenant_db.ts";

const MAX_RECOMMENDATIONS = 5;
const INTERVIEW_STEP_COUNT = 7;

// ─── Response shapes (camelCase — match the Flutter datasource exactly) ──────

export interface OrgBuilderPack {
  id: string;
  type: string;
  name: string;
  description: string;
  primaryEntities: string[];
  moduleSeeds: string[];
  dashboardFocus: string;
  brandLabel: string | null;
}

export interface InterviewRecommendation {
  id: string;
  title: string;
  detail: string;
  confidence: number;
}

export interface InterviewDraftView {
  id: string;
  packId: string;
  organizationName: string;
  currentStep: number;
  answers: Record<string, string>;
  recommendations: InterviewRecommendation[];
  status: "in_progress" | "ready_for_preview" | "provisioned";
  createdAt: string;
  updatedAt: string;
}

export interface ConfigModuleItem {
  id: string;
  name: string;
  enabled: boolean;
  isNew: boolean;
}
export interface ConfigRoleItem {
  id: string;
  name: string;
  permissionCount: number;
}
export interface ConfigWidgetItem {
  id: string;
  role: string;
  widgetName: string;
}
export interface ConfigWorkflowItem {
  id: string;
  name: string;
  trigger: string;
}

export interface ConfigPreviewView {
  draftId: string;
  organizationName: string;
  packId: string;
  modules: ConfigModuleItem[];
  roles: ConfigRoleItem[];
  widgets: ConfigWidgetItem[];
  workflows: ConfigWorkflowItem[];
  generatedAt: string;
}

export interface ProvisioningStepView {
  id: string;
  label: string;
  status: "pending" | "running" | "completed" | "failed" | "skipped";
  startedAt?: string;
  completedAt?: string;
  error?: string;
}

export interface ProvisioningJobView {
  id: string;
  draftId: string;
  organizationName: string;
  status: "pending" | "running" | "completed" | "failed";
  steps: ProvisioningStepView[];
  startedAt: string;
  completedAt?: string;
  /** G11 — the tenant the job actually created, so the client can open it. */
  newOrganizationId?: string | null;
  newBranchId?: string | null;
}

const UNIVERSAL_EMPLOYEE_MODULE_ID = "universal_employee";

// ─── Mapping helpers ────────────────────────────────────────────────────────

function iso(value: unknown): string {
  if (value instanceof Date) return value.toISOString();
  return new Date(value as string).toISOString();
}

function asStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.map((v) => String(v)) : [];
}

function asAnswers(value: unknown): Record<string, string> {
  if (!value || typeof value !== "object") return {};
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
    out[k] = v == null ? "" : String(v);
  }
  return out;
}

function asRecommendations(value: unknown): InterviewRecommendation[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((r) => r && typeof r === "object")
    .map((r) => {
      const o = r as Record<string, unknown>;
      return {
        id: String(o.id ?? ""),
        title: String(o.title ?? ""),
        detail: String(o.detail ?? ""),
        confidence: typeof o.confidence === "number" ? o.confidence : Number(o.confidence) || 0,
      };
    });
}

interface PackRow {
  id: string;
  type: string;
  name: string;
  description: string;
  primary_entities: string[];
  module_seeds: string[];
  dashboard_focus: string;
  brand_label: string | null;
}

function mapPack(row: PackRow): OrgBuilderPack {
  return {
    id: row.id,
    type: row.type,
    name: row.name,
    description: row.description,
    primaryEntities: asStringArray(row.primary_entities),
    moduleSeeds: asStringArray(row.module_seeds),
    dashboardFocus: row.dashboard_focus,
    brandLabel: row.brand_label,
  };
}

interface DraftRow {
  id: string;
  pack_id: string;
  organization_name: string;
  current_step: number;
  answers: unknown;
  recommendations: unknown;
  status: InterviewDraftView["status"];
  created_at: unknown;
  updated_at: unknown;
}

function mapDraft(row: DraftRow): InterviewDraftView {
  return {
    id: row.id,
    packId: row.pack_id,
    organizationName: row.organization_name,
    currentStep: Number(row.current_step) || 0,
    answers: asAnswers(row.answers),
    recommendations: asRecommendations(row.recommendations),
    status: row.status,
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
  };
}

interface JobRow {
  id: string;
  draft_id: string;
  organization_name: string;
  status: ProvisioningJobView["status"];
  steps: unknown;
  started_at: unknown;
  completed_at: unknown;
  resolved_config?: unknown;
}

function mapJob(row: JobRow): ProvisioningJobView {
  const steps = Array.isArray(row.steps)
    ? (row.steps as ProvisioningStepView[])
    : [];
  const config = (row.resolved_config && typeof row.resolved_config === "object")
    ? row.resolved_config as Record<string, unknown>
    : {};
  return {
    id: row.id,
    draftId: row.draft_id,
    organizationName: row.organization_name,
    status: row.status,
    steps,
    startedAt: iso(row.started_at),
    completedAt: row.completed_at ? iso(row.completed_at) : undefined,
    newOrganizationId: (config.newOrganizationId as string | null) ?? null,
    newBranchId: (config.newBranchId as string | null) ?? null,
  };
}

// ─── Packs (catalog) ────────────────────────────────────────────────────────

export async function listPacks(db: TenantQueryClient): Promise<OrgBuilderPack[]> {
  const rows = await db.queryObject<PackRow>(
    `SELECT id, type, name, description, primary_entities, module_seeds,
            dashboard_focus, brand_label
     FROM org_builder_packs ORDER BY sort_order, name`,
  );
  return rows.map(mapPack);
}

export async function getPack(
  db: TenantQueryClient,
  packId: string,
): Promise<OrgBuilderPack | null> {
  const rows = await db.queryObject<PackRow>(
    `SELECT id, type, name, description, primary_entities, module_seeds,
            dashboard_focus, brand_label
     FROM org_builder_packs WHERE id = $1`,
    [packId],
  );
  return rows.length > 0 ? mapPack(rows[0]) : null;
}

// ─── Interview drafts ───────────────────────────────────────────────────────

const DRAFT_COLUMNS =
  `id, pack_id, organization_name, current_step, answers, recommendations,
   status, created_at, updated_at`;

async function getDraftRow(
  db: TenantQueryClient,
  orgId: string,
  draftId: string,
): Promise<InterviewDraftView | null> {
  const rows = await db.queryObject<DraftRow>(
    `SELECT ${DRAFT_COLUMNS} FROM org_builder_interview_drafts
     WHERE id = $1 AND organization_id = $2`,
    [draftId, orgId],
  );
  return rows.length > 0 ? mapDraft(rows[0]) : null;
}

export async function listDrafts(
  db: TenantQueryClient,
  orgId: string,
): Promise<InterviewDraftView[]> {
  const rows = await db.queryObject<DraftRow>(
    `SELECT ${DRAFT_COLUMNS} FROM org_builder_interview_drafts
     WHERE organization_id = $1 ORDER BY updated_at DESC`,
    [orgId],
  );
  return rows.map(mapDraft);
}

/** Returns the draft, creating an empty (pack_school, step 0) row if missing. */
export async function getOrCreateDraft(
  db: TenantQueryClient,
  orgId: string,
  draftId: string,
): Promise<InterviewDraftView> {
  const existing = await getDraftRow(db, orgId, draftId);
  if (existing) return existing;

  const rows = await db.queryObject<DraftRow>(
    `INSERT INTO org_builder_interview_drafts
       (id, organization_id, pack_id, organization_name, current_step, answers,
        recommendations, status)
     VALUES ($1, $2, 'pack_school', '', 0, '{}'::jsonb, '[]'::jsonb, 'in_progress')
     ON CONFLICT (id) DO NOTHING
     RETURNING ${DRAFT_COLUMNS}`,
    [draftId, orgId],
  );
  if (rows.length > 0) return mapDraft(rows[0]);
  // Lost an insert race (or id owned by this org already) — re-read.
  const reread = await getDraftRow(db, orgId, draftId);
  if (reread) return reread;
  throw new Error("Failed to create interview draft");
}

/**
 * Persists one interview step: merges answers, advances the step, resolves
 * pack/name, and stores the final recommendation list. Returns the saved draft.
 * `recommendations` is the already-resolved list (handler prepends the AI rec).
 */
export async function saveStep(
  db: TenantQueryClient,
  orgId: string,
  draftId: string,
  stepIndex: number,
  answers: Record<string, string>,
  recommendations: InterviewRecommendation[],
): Promise<InterviewDraftView> {
  const existing = await getDraftRow(db, orgId, draftId);
  const mergedAnswers = { ...(existing?.answers ?? {}), ...answers };
  const packId = (answers["pack_id"] || existing?.packId || "pack_school").trim();
  const orgName = (answers["identity_name"] || existing?.organizationName || "New Organization")
    .trim();
  const nextStep = Math.min(Math.max(stepIndex + 1, 0), INTERVIEW_STEP_COUNT);
  const status = nextStep >= INTERVIEW_STEP_COUNT ? "ready_for_preview" : "in_progress";

  const rows = await db.queryObject<DraftRow>(
    `INSERT INTO org_builder_interview_drafts
       (id, organization_id, pack_id, organization_name, current_step, answers,
        recommendations, status)
     VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8)
     ON CONFLICT (id) DO UPDATE SET
        pack_id = EXCLUDED.pack_id,
        organization_name = EXCLUDED.organization_name,
        current_step = EXCLUDED.current_step,
        answers = EXCLUDED.answers,
        recommendations = EXCLUDED.recommendations,
        status = EXCLUDED.status,
        updated_at = now()
     RETURNING ${DRAFT_COLUMNS}`,
    [
      draftId,
      orgId,
      packId,
      orgName,
      nextStep,
      JSON.stringify(mergedAnswers),
      JSON.stringify(recommendations.slice(0, MAX_RECOMMENDATIONS)),
      status,
    ],
  );
  return mapDraft(rows[0]);
}

// ─── Configuration preview (deterministic, pure) ────────────────────────────

/** Builds the configuration preview for a draft + pack. Pure: no DB, no clock-state. */
export function buildPreview(
  draft: InterviewDraftView,
  pack: OrgBuilderPack,
  generatedAtIso: string,
): ConfigPreviewView {
  const modules: ConfigModuleItem[] = [
    ...pack.moduleSeeds.map((seed) => ({
      id: seed.toLowerCase().replace(/\s+/g, "_"),
      name: seed,
      enabled: true,
      isNew: true,
    })),
    {
      id: UNIVERSAL_EMPLOYEE_MODULE_ID,
      name: "Universal Employee (FV-PLAT-01)",
      enabled: true,
      isNew: true,
    },
    { id: "auth", name: "Auth & RBAC", enabled: true, isNew: false },
    { id: "analytics", name: "Analytics", enabled: true, isNew: false },
  ];

  return {
    draftId: draft.id,
    organizationName: draft.organizationName,
    packId: draft.packId,
    modules,
    roles: rolesForPack(pack.type),
    widgets: widgetsForPack(pack.type),
    workflows: workflowsForPack(pack.type),
    generatedAt: generatedAtIso,
  };
}

export function rolesForPack(type: string): ConfigRoleItem[] {
  switch (type) {
    case "salon":
      return [
        { id: "manager", name: "Salon Manager", permissionCount: 36 },
        { id: "stylist", name: "Stylist", permissionCount: 18 },
        { id: "reception", name: "Reception", permissionCount: 14 },
      ];
    case "hospital":
      return [
        { id: "admin", name: "Hospital Admin", permissionCount: 52 },
        { id: "doctor", name: "Doctor", permissionCount: 28 },
        { id: "nurse", name: "Nurse", permissionCount: 20 },
      ];
    case "restaurant":
      return [
        { id: "manager", name: "Restaurant Manager", permissionCount: 34 },
        { id: "chef", name: "Chef", permissionCount: 16 },
        { id: "server", name: "Server", permissionCount: 10 },
      ];
    default:
      return [
        { id: "principal", name: "Principal", permissionCount: 48 },
        { id: "teacher", name: "Teacher", permissionCount: 22 },
        { id: "parent", name: "Parent", permissionCount: 12 },
      ];
  }
}

export function widgetsForPack(type: string): ConfigWidgetItem[] {
  switch (type) {
    case "salon":
      return [
        { id: "chair_utilization", role: "Salon Manager", widgetName: "Chair utilization" },
        { id: "appointment_pipeline", role: "Salon Manager", widgetName: "Revenue by stylist" },
      ];
    case "hospital":
      return [
        { id: "bed_occupancy", role: "Hospital Admin", widgetName: "Bed occupancy" },
        { id: "opd_queue", role: "Hospital Admin", widgetName: "OPD queue" },
      ];
    case "restaurant":
      return [
        { id: "active_covers", role: "Restaurant Manager", widgetName: "Covers per hour" },
        { id: "ticket_time", role: "Restaurant Manager", widgetName: "Kitchen ticket time" },
      ];
    default:
      return [
        { id: "school_health", role: "Principal", widgetName: "School Health" },
        { id: "fee_collection", role: "Principal", widgetName: "Fee Collection" },
        { id: "student_risk", role: "Principal", widgetName: "Student Risk" },
        { id: "attendance_risk", role: "Principal", widgetName: "Attendance Risk" },
      ];
  }
}

export function workflowsForPack(type: string): ConfigWorkflowItem[] {
  switch (type) {
    case "salon":
      return [
        { id: "wf1", name: "Appointment confirm", trigger: "24h before slot" },
        { id: "wf2", name: "No-show follow-up", trigger: "Missed appointment" },
      ];
    case "hospital":
      return [
        { id: "wf1", name: "Discharge checklist", trigger: "Discharge order" },
        { id: "wf2", name: "Insurance claim", trigger: "Billing finalized" },
      ];
    case "restaurant":
      return [
        { id: "wf1", name: "Order to kitchen", trigger: "Order placed" },
        { id: "wf2", name: "Table ready alert", trigger: "Order ready" },
      ];
    default:
      return [
        { id: "wf1", name: "Fee reminder", trigger: "Due date - 3 days" },
        { id: "wf2", name: "Promotion approval", trigger: "End of term" },
      ];
  }
}

// ─── Provisioning (real, synchronous, persisted) ────────────────────────────

export interface ProvisionResult {
  job: ProvisioningJobView;
  resolvedConfig: ConfigPreviewView;
}

interface ProvisionRow {
  new_org_id: string | null;
  new_school_id: string | null;
  roles_seeded: number | string;
  permissions_granted: number | string;
  seeds_loaded: number | string;
  reused: boolean;
  failed_step: string | null;
  error_message: string | null;
}

/** Resolves the acting user's id from the request context (for org-admin grant). */
async function currentActorId(db: TenantQueryClient): Promise<string | null> {
  const rows = await db.queryObject<{ user_id: string | null }>(
    `SELECT NULLIF(current_setting('app.user_id', true), '') AS user_id`,
  );
  return rows[0]?.user_id ?? null;
}

/**
 * Provisions the organization from a draft. REAL work, done synchronously and
 * persisted. The privileged `org_builder_provision_tenant` SECURITY DEFINER
 * function creates (or idempotently reuses) the child organization + its primary
 * branch, seeds the vertical pack's roles into the RBAC catalog, grants their
 * permissions, seeds any baseline rows the pack defines, and takes the org live —
 * all in one atomic call that rolls back its own partial writes on failure.
 *
 * The job's six steps record the ACTUAL outcome: completed up to the point the
 * function reached, the failing step marked `failed` (with its error) and the
 * rest `pending`, on failure. The job status mirrors that (`completed` only when
 * every step really ran), and the draft is flipped to `provisioned` ONLY on real
 * success. The persisted job is what the client polls — no in-memory timers.
 */
export async function provision(
  db: TenantQueryClient,
  orgId: string,
  draftId: string,
  nowIso: string,
): Promise<ProvisionResult> {
  const draft = await getOrCreateDraft(db, orgId, draftId);
  const pack = (await getPack(db, draft.packId)) ?? (await getPack(db, "pack_school"))!;
  const preview = buildPreview(draft, pack, nowIso);

  const actorId = await currentActorId(db);

  // Real, atomic tenant creation. The function never raises: it returns the
  // failing step + message as data so partial work is unwound yet we can still
  // commit a durable job row describing the failure.
  const provRows = await db.queryObject<ProvisionRow>(
    `SELECT new_org_id, new_school_id, roles_seeded, permissions_granted,
            seeds_loaded, reused, failed_step, error_message
     FROM org_builder_provision_tenant($1::uuid, $2, $3, $4, $5::uuid)`,
    [orgId, draftId, pack.id, draft.organizationName, actorId],
  );
  const result = provRows[0];
  const rolesSeeded = Number(result?.roles_seeded ?? 0);
  const permsGranted = Number(result?.permissions_granted ?? 0);
  const seedsLoaded = Number(result?.seeds_loaded ?? 0);
  const failedStep = result?.failed_step ?? null;
  const errorMessage = result?.error_message ?? null;

  // Ordered step plan, with the real labels/counts. Status is filled in below.
  const plan: Array<{ id: string; label: string }> = [
    { id: "step_org", label: "Create organization" },
    { id: "step_branch", label: "Create branch" },
    { id: "step_roles", label: `Seed roles (${rolesSeeded})` },
    { id: "step_permissions", label: `Assign permissions (${permsGranted})` },
    { id: "step_seeds", label: `Load seed data (${seedsLoaded} rows)` },
    { id: "step_golive", label: "Go live" },
  ];

  const failedIdx = failedStep ? plan.findIndex((s) => s.id === failedStep) : -1;
  const steps: ProvisioningStepView[] = plan.map((s, i) => {
    if (failedIdx < 0) {
      // Full success — every step really ran.
      return { ...s, status: "completed", startedAt: nowIso, completedAt: nowIso };
    }
    if (i < failedIdx) {
      // Ran before the failure, but the function rolled everything back; the work
      // did not durably land, so mark it skipped (not falsely completed).
      return { ...s, status: "skipped", startedAt: nowIso, completedAt: nowIso };
    }
    if (i === failedIdx) {
      return {
        ...s,
        status: "failed",
        startedAt: nowIso,
        completedAt: nowIso,
        error: errorMessage ?? "Provisioning step failed",
      };
    }
    return { ...s, status: "pending" };
  });

  const jobStatus: ProvisioningJobView["status"] = failedIdx < 0 ? "completed" : "failed";

  const resolvedConfig = {
    packId: pack.id,
    modules: preview.modules,
    roles: preview.roles,
    widgets: preview.widgets,
    workflows: preview.workflows,
    newOrganizationId: result?.new_org_id ?? null,
    newBranchId: result?.new_school_id ?? null,
    reused: result?.reused ?? false,
  };

  const rows = await db.queryObject<JobRow>(
    `INSERT INTO org_builder_provisioning_jobs
       (organization_id, draft_id, organization_name, status, steps,
        resolved_config, started_at, completed_at)
     VALUES ($1, $2, $3, $4, $5::jsonb, $6::jsonb, $7::timestamptz,
             CASE WHEN $4 IN ('completed', 'failed') THEN $7::timestamptz END)
     RETURNING id, draft_id, organization_name, status, steps, started_at, completed_at, resolved_config`,
    [
      orgId,
      draftId,
      draft.organizationName,
      jobStatus,
      JSON.stringify(steps),
      JSON.stringify(resolvedConfig),
      nowIso,
    ],
  );

  // Flip the draft to provisioned ONLY on a real, complete success.
  if (jobStatus === "completed") {
    await db.queryObject(
      `UPDATE org_builder_interview_drafts
       SET status = 'provisioned', updated_at = now()
       WHERE id = $1 AND organization_id = $2`,
      [draftId, orgId],
    );
  }

  return { job: mapJob(rows[0]), resolvedConfig: preview };
}

export async function getJob(
  db: TenantQueryClient,
  orgId: string,
  jobId: string,
): Promise<ProvisioningJobView | null> {
  const rows = await db.queryObject<JobRow>(
    `SELECT id, draft_id, organization_name, status, steps, started_at, completed_at,
            resolved_config
     FROM org_builder_provisioning_jobs
     WHERE id = $1 AND organization_id = $2`,
    [jobId, orgId],
  );
  return rows.length > 0 ? mapJob(rows[0]) : null;
}
