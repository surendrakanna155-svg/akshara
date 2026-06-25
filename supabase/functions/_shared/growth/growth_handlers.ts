import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, growthPlatformAudit } from "../audit/mutation_audit_catalog.ts";
import { createLead } from "../admissions/admissions_repository.ts";

export async function handleGrowthDashboard(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewGrowthPlatform") ??
    requirePermission(auth.claims, "viewAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const data = await withTenantContext(config, auth.claims, async (db) => {
      const campaigns = await db.queryObject<{ status: string; channel: string; count: string }>(
        `SELECT status, channel, count(*)::text AS count
         FROM growth_campaigns
         WHERE organization_id = $1 AND school_id = $2
         GROUP BY status, channel`,
        [orgId, schoolId],
      );
      const inquiries = await db.queryObject<{ status: string; source: string; count: string }>(
        `SELECT status, source, count(*)::text AS count
         FROM growth_inquiries
         WHERE organization_id = $1 AND school_id = $2
         GROUP BY status, source`,
        [orgId, schoolId],
      );
      const converted = inquiries
        .filter((i) => i.status === "converted")
        .reduce((sum, i) => sum + Number(i.count), 0);
      const total = inquiries.reduce((sum, i) => sum + Number(i.count), 0);
      return {
        campaigns: campaigns.map((c) => ({
          status: c.status,
          channel: c.channel,
          count: Number(c.count),
        })),
        inquiries: inquiries.map((i) => ({
          status: i.status,
          source: i.source,
          count: Number(i.count),
        })),
        conversionRate: total > 0 ? Math.round((converted / total) * 100) : 0,
        totalInquiries: total,
        activeCampaigns: campaigns
          .filter((c) => c.status === "active")
          .reduce((sum, c) => sum + Number(c.count), 0),
      };
    });
    return jsonResponse(envelope(data));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("GROWTH_ERROR", String(error), 500);
  }
}

export async function handleCreateGrowthCampaign(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageGrowthPlatform") ??
    requirePermission(auth.claims, "manageAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    name: string;
    channel: string;
    budgetInr?: number;
    startDate?: string;
    endDate?: string;
    audience?: string;
    scheduledAt?: string;
  }>(req);
  if (!body?.name || !body.channel) {
    return errorEnvelope("VALIDATION_ERROR", "name and channel required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const id = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await db.queryObject<{ id: string }>(
        `INSERT INTO growth_campaigns (
           organization_id, school_id, name, channel, budget_inr, start_date, end_date,
           audience, scheduled_at, created_by
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         RETURNING id`,
        [
          orgId,
          schoolId,
          body.name,
          body.channel,
          body.budgetInr ?? null,
          body.startDate ?? null,
          body.endDate ?? null,
          body.audience ?? "all",
          body.scheduledAt ?? null,
          auth.claims.sub,
        ],
      );
      await emitMutationAudit(
        db,
        auth.claims,
        growthPlatformAudit.campaignCreated(rows[0]!.id),
        req,
      );
      return rows[0]!.id;
    });
    return jsonResponse(envelope({ id }), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("GROWTH_ERROR", String(error), 500);
  }
}

export async function handleCreateGrowthInquiry(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageGrowthPlatform") ??
    requirePermission(auth.claims, "manageAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    parentName: string;
    phone?: string;
    gradeInterest?: string;
    source: string;
    campaignId?: string;
    notes?: string;
  }>(req);
  if (!body?.parentName || !body.source) {
    return errorEnvelope("VALIDATION_ERROR", "parentName and source required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const id = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await db.queryObject<{ id: string }>(
        `INSERT INTO growth_inquiries (
           organization_id, school_id, campaign_id, parent_name, phone,
           grade_interest, source, notes
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING id`,
        [
          orgId,
          schoolId,
          body.campaignId ?? null,
          body.parentName,
          body.phone ?? null,
          body.gradeInterest ?? null,
          body.source,
          body.notes ?? null,
        ],
      );
      await emitMutationAudit(
        db,
        auth.claims,
        growthPlatformAudit.inquiryCreated(rows[0]!.id),
        req,
      );
      return rows[0]!.id;
    });
    return jsonResponse(envelope({ id }), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("GROWTH_ERROR", String(error), 500);
  }
}

export async function handleListGrowthCampaigns(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewGrowthPlatform") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      db.queryObject<Record<string, unknown>>(
        `SELECT id, name, channel, status, budget_inr AS "budgetInr",
                start_date AS "startDate", end_date AS "endDate",
                audience, scheduled_at AS "scheduledAt", created_at AS "createdAt"
         FROM growth_campaigns
         ORDER BY created_at DESC
         LIMIT 50`,
      )
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("GROWTH_ERROR", String(error), 500);
  }
}

// Columns returned for a single campaign — keys match the Flutter
// `toGrowthCampaign` mapper so update/pause responses hydrate the model directly.
const CAMPAIGN_RETURNING =
  `id, name, channel, status, budget_inr AS "budgetInr",
   audience, scheduled_at AS "scheduledAt", created_at AS "createdAt", updated_at`;

export async function handleUpdateGrowthCampaign(
  req: Request,
  config: AppConfig,
  campaignId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageGrowthPlatform") ??
    requirePermission(auth.claims, "manageAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    name?: string;
    channel?: string;
    status?: string;
    budgetInr?: number;
    audience?: string;
    scheduledAt?: string;
  }>(req);

  // Build a partial update from only the provided fields. RLS scopes the row to
  // the caller's org+school, so a cross-tenant id silently affects zero rows.
  const updatable: Array<[string, unknown]> = [
    ["name", body?.name],
    ["channel", body?.channel],
    ["status", body?.status],
    ["budget_inr", body?.budgetInr],
    ["audience", body?.audience],
    ["scheduled_at", body?.scheduledAt],
  ];
  const sets: string[] = [];
  const params: unknown[] = [campaignId];
  for (const [col, val] of updatable) {
    if (val !== undefined) {
      params.push(val);
      sets.push(`${col} = $${params.length}`);
    }
  }
  if (sets.length === 0) {
    return errorEnvelope("VALIDATION_ERROR", "no updatable fields provided", 422);
  }

  try {
    const campaign = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await db.queryObject<Record<string, unknown>>(
        `UPDATE growth_campaigns SET ${sets.join(", ")}
         WHERE id = $1
         RETURNING ${CAMPAIGN_RETURNING}`,
        params,
      );
      if (rows.length === 0) throw new Error("Campaign not found");
      await emitMutationAudit(
        db,
        auth.claims,
        growthPlatformAudit.campaignUpdated(campaignId, String(rows[0]!.updated_at)),
        req,
      );
      return rows[0]!;
    });
    return jsonResponse(envelope(campaign));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("GROWTH_ERROR", String(error), 500);
  }
}

export async function handlePauseGrowthCampaign(
  req: Request,
  config: AppConfig,
  campaignId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageGrowthPlatform") ??
    requirePermission(auth.claims, "manageAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const campaign = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await db.queryObject<Record<string, unknown>>(
        `UPDATE growth_campaigns SET status = 'paused'
         WHERE id = $1
         RETURNING ${CAMPAIGN_RETURNING}`,
        [campaignId],
      );
      if (rows.length === 0) throw new Error("Campaign not found");
      await emitMutationAudit(
        db,
        auth.claims,
        growthPlatformAudit.campaignPaused(campaignId, String(rows[0]!.updated_at)),
        req,
      );
      return rows[0]!;
    });
    return jsonResponse(envelope(campaign));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("GROWTH_ERROR", String(error), 500);
  }
}

export async function handleListGrowthCampaignHistory(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewGrowthPlatform") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  // History = past / inactive campaigns (paused or completed), most recent first.
  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      db.queryObject<Record<string, unknown>>(
        `SELECT ${CAMPAIGN_RETURNING}
         FROM growth_campaigns
         WHERE status IN ('paused', 'completed')
         ORDER BY updated_at DESC
         LIMIT 100`,
      )
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("GROWTH_ERROR", String(error), 500);
  }
}

export async function handleGrowthFunnel(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewGrowthPlatform") ??
    requirePermission(auth.claims, "viewAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const data = await withTenantContext(config, auth.claims, async (db) => {
      const stages = await db.queryObject<{ status: string; count: string }>(
        `SELECT status, count(*)::text AS count
         FROM growth_inquiries
         WHERE organization_id = $1 AND school_id = $2
         GROUP BY status`,
        [orgId, schoolId],
      );
      const campaignAttribution = await db.queryObject<{
        campaign_name: string;
        inquiries: string;
        converted: string;
      }>(
        `SELECT coalesce(c.name, 'Unattributed') AS campaign_name,
                count(i.id)::text AS inquiries,
                count(i.id) FILTER (WHERE i.status = 'converted')::text AS converted
         FROM growth_inquiries i
         LEFT JOIN growth_campaigns c ON c.id = i.campaign_id
         WHERE i.organization_id = $1 AND i.school_id = $2
         GROUP BY c.name`,
        [orgId, schoolId],
      );
      const sourceAttribution = await db.queryObject<{
        source: string;
        inquiries: string;
        converted: string;
      }>(
        `SELECT source,
                count(*)::text AS inquiries,
                count(*) FILTER (WHERE status = 'converted')::text AS converted
         FROM growth_inquiries
         WHERE organization_id = $1 AND school_id = $2
         GROUP BY source`,
        [orgId, schoolId],
      );
      const total = stages.reduce((sum, s) => sum + Number(s.count), 0);
      const converted = stages
        .filter((s) => s.status === "converted")
        .reduce((sum, s) => sum + Number(s.count), 0);

      return {
        stages: stages.map((s) => ({ stage: s.status, count: Number(s.count) })),
        campaignAttribution: campaignAttribution.map((c) => ({
          campaign: c.campaign_name,
          inquiries: Number(c.inquiries),
          converted: Number(c.converted),
        })),
        sourceAttribution: sourceAttribution.map((s) => ({
          source: s.source,
          inquiries: Number(s.inquiries),
          converted: Number(s.converted),
        })),
        convertedCount: converted,
        totalInquiries: total,
      };
    });
    return jsonResponse(envelope(data));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("GROWTH_ERROR", String(error), 500);
  }
}

export async function handleConvertGrowthInquiry(
  req: Request,
  config: AppConfig,
  inquiryId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageGrowthPlatform") ??
    requirePermission(auth.claims, "manageAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const leadId = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await db.queryObject<{
        parent_name: string;
        phone: string | null;
        grade_interest: string | null;
        source: string;
        campaign_id: string | null;
        lead_id: string | null;
      }>(
        `SELECT parent_name, phone, grade_interest, source, campaign_id, lead_id
         FROM growth_inquiries WHERE id = $1`,
        [inquiryId],
      );
      const inquiry = rows[0];
      if (!inquiry) throw new Error("Inquiry not found");
      if (inquiry.lead_id) return inquiry.lead_id;

      let campaignName: string | null = null;
      if (inquiry.campaign_id) {
        const camp = await db.queryObject<{ name: string }>(
          `SELECT name FROM growth_campaigns WHERE id = $1`,
          [inquiry.campaign_id],
        );
        campaignName = camp[0]?.name ?? null;
      }

      const lead = await createLead(db, orgId, schoolId, {
        parentName: inquiry.parent_name,
        studentName: inquiry.parent_name,
        classLabel: inquiry.grade_interest ?? "Not specified",
        phone: inquiry.phone ?? "",
        source: inquiry.source,
        campaign: campaignName ?? inquiry.source,
        // Handoff to Admissions CRM leaves the lead UNASSIGNED. `counselor` is a
        // display name in B1 (e.g. "Meera N."), and B4's intelligence treats
        // `counselor = ''` as the "assign an owner" signal. Writing the converting
        // user's UUID here showed a raw UUID as the owner and hid the lead from the
        // AI's assign next-best-action. Provenance is kept in `notes` + the audit log.
        counselor: "",
        email: "",
        address: "",
        notes: `Converted from growth inquiry ${inquiryId} by ${auth.claims.sub}`,
      });

      await db.queryObject(
        `UPDATE growth_inquiries
         SET status = 'converted', lead_id = $2, updated_at = timezone('utc', now())
         WHERE id = $1`,
        [inquiryId, lead.id],
      );
      await emitMutationAudit(
        db,
        auth.claims,
        growthPlatformAudit.inquiryConverted(inquiryId, lead.id),
        req,
      );
      return lead.id;
    });
    return jsonResponse(envelope({ leadId, inquiryId }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("GROWTH_ERROR", String(error), 500);
  }
}

export async function handleListGrowthInquiries(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewGrowthPlatform") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      db.queryObject<Record<string, unknown>>(
        `SELECT id, parent_name AS "parentName", phone, grade_interest AS "gradeInterest",
                source, status, follow_up_at AS "followUpAt", campaign_id AS "campaignId",
                lead_id AS "leadId"
         FROM growth_inquiries
         ORDER BY created_at DESC
         LIMIT 100`,
      )
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("GROWTH_ERROR", String(error), 500);
  }
}
