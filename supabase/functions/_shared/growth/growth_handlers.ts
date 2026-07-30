import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requireAnyPermission,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, growthPlatformAudit } from "../audit/mutation_audit_catalog.ts";
import { createLead } from "../admissions/admissions_repository.ts";
import {
  getCampaignNameById,
  getInquiryForConversion,
  insertGrowthCampaign,
  insertGrowthInquiry,
  listCampaignAttribution,
  listCampaignStatusChannelCounts,
  listFunnelStageCounts,
  listGrowthCampaignHistory,
  listGrowthCampaigns,
  listGrowthInquiries,
  listInquiryStatusSourceCounts,
  listSourceAttribution,
  markGrowthInquiryConverted,
  pauseGrowthCampaign,
  updateGrowthCampaign,
} from "./growth_repository.ts";

export async function handleGrowthDashboard(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnyPermission(auth.claims, ["viewGrowthPlatform", "viewAdmissions"]) ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const data = await withTenantContext(config, auth.claims, async (db) => {
      const campaigns = await listCampaignStatusChannelCounts(db, orgId, schoolId);
      const inquiries = await listInquiryStatusSourceCounts(db, orgId, schoolId);
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
  const denied = requireAnyPermission(auth.claims, ["manageGrowthPlatform", "manageAdmissions"]) ??
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
      const id = await insertGrowthCampaign(db, {
        organizationId: orgId,
        schoolId,
        name: body.name,
        channel: body.channel,
        budgetInr: body.budgetInr ?? null,
        startDate: body.startDate ?? null,
        endDate: body.endDate ?? null,
        audience: body.audience ?? "all",
        scheduledAt: body.scheduledAt ?? null,
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        growthPlatformAudit.campaignCreated(id),
        req,
      );
      return id;
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
  const denied = requireAnyPermission(auth.claims, ["manageGrowthPlatform", "manageAdmissions"]) ??
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
      const id = await insertGrowthInquiry(db, {
        organizationId: orgId,
        schoolId,
        campaignId: body.campaignId ?? null,
        parentName: body.parentName,
        phone: body.phone ?? null,
        gradeInterest: body.gradeInterest ?? null,
        source: body.source,
        notes: body.notes ?? null,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        growthPlatformAudit.inquiryCreated(id),
        req,
      );
      return id;
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
    const items = await withTenantContext(config, auth.claims, async (db) => listGrowthCampaigns(db));
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("GROWTH_ERROR", String(error), 500);
  }
}

export async function handleUpdateGrowthCampaign(
  req: Request,
  config: AppConfig,
  campaignId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnyPermission(auth.claims, ["manageGrowthPlatform", "manageAdmissions"]) ??
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
      const rows = await updateGrowthCampaign(db, sets, params);
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
  const denied = requireAnyPermission(auth.claims, ["manageGrowthPlatform", "manageAdmissions"]) ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const campaign = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await pauseGrowthCampaign(db, campaignId);
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
    const items = await withTenantContext(
      config,
      auth.claims,
      async (db) => listGrowthCampaignHistory(db),
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
  const denied = requireAnyPermission(auth.claims, ["viewGrowthPlatform", "viewAdmissions"]) ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const data = await withTenantContext(config, auth.claims, async (db) => {
      const stages = await listFunnelStageCounts(db, orgId, schoolId);
      const campaignAttribution = await listCampaignAttribution(db, orgId, schoolId);
      const sourceAttribution = await listSourceAttribution(db, orgId, schoolId);
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
  const denied = requireAnyPermission(auth.claims, ["manageGrowthPlatform", "manageAdmissions"]) ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const leadId = await withTenantContext(config, auth.claims, async (db) => {
      const inquiry = await getInquiryForConversion(db, inquiryId);
      if (!inquiry) throw new Error("Inquiry not found");
      if (inquiry.lead_id) return inquiry.lead_id;

      let campaignName: string | null = null;
      if (inquiry.campaign_id) {
        campaignName = await getCampaignNameById(db, inquiry.campaign_id);
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

      await markGrowthInquiryConverted(db, inquiryId, lead.id);
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
    const items = await withTenantContext(config, auth.claims, async (db) => listGrowthInquiries(db));
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("GROWTH_ERROR", String(error), 500);
  }
}
