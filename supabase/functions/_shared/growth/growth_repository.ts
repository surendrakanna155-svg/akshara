import type { TenantQueryClient } from "../tenant_db.ts";

export interface GrowthCampaignStatusChannelCount {
  status: string;
  channel: string;
  count: string;
}

export async function listCampaignStatusChannelCounts(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string | null,
): Promise<GrowthCampaignStatusChannelCount[]> {
  return await db.queryObject<GrowthCampaignStatusChannelCount>(
    `SELECT status, channel, count(*)::text AS count
     FROM growth_campaigns
     WHERE organization_id = $1 AND school_id = $2
     GROUP BY status, channel`,
    [organizationId, schoolId],
  );
}

export interface GrowthInquiryStatusSourceCount {
  status: string;
  source: string;
  count: string;
}

export async function listInquiryStatusSourceCounts(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string | null,
): Promise<GrowthInquiryStatusSourceCount[]> {
  return await db.queryObject<GrowthInquiryStatusSourceCount>(
    `SELECT status, source, count(*)::text AS count
     FROM growth_inquiries
     WHERE organization_id = $1 AND school_id = $2
     GROUP BY status, source`,
    [organizationId, schoolId],
  );
}

export async function insertGrowthCampaign(
  db: TenantQueryClient,
  params: {
    organizationId: string;
    schoolId: string | null;
    name: string;
    channel: string;
    budgetInr: number | null;
    startDate: string | null;
    endDate: string | null;
    audience: string;
    scheduledAt: string | null;
    createdBy: string;
  },
): Promise<string> {
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO growth_campaigns (
       organization_id, school_id, name, channel, budget_inr, start_date, end_date,
       audience, scheduled_at, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING id`,
    [
      params.organizationId,
      params.schoolId,
      params.name,
      params.channel,
      params.budgetInr,
      params.startDate,
      params.endDate,
      params.audience,
      params.scheduledAt,
      params.createdBy,
    ],
  );
  return rows[0]!.id;
}

export async function insertGrowthInquiry(
  db: TenantQueryClient,
  params: {
    organizationId: string;
    schoolId: string | null;
    campaignId: string | null;
    parentName: string;
    phone: string | null;
    gradeInterest: string | null;
    source: string;
    notes: string | null;
  },
): Promise<string> {
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO growth_inquiries (
       organization_id, school_id, campaign_id, parent_name, phone,
       grade_interest, source, notes
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING id`,
    [
      params.organizationId,
      params.schoolId,
      params.campaignId,
      params.parentName,
      params.phone,
      params.gradeInterest,
      params.source,
      params.notes,
    ],
  );
  return rows[0]!.id;
}

export async function listGrowthCampaigns(
  db: TenantQueryClient,
): Promise<Record<string, unknown>[]> {
  return await db.queryObject<Record<string, unknown>>(
    `SELECT id, name, channel, status, budget_inr AS "budgetInr",
            start_date AS "startDate", end_date AS "endDate",
            audience, scheduled_at AS "scheduledAt", created_at AS "createdAt"
     FROM growth_campaigns
     ORDER BY created_at DESC
     LIMIT 50`,
  );
}

// Columns returned for a single campaign — keys match the Flutter
// `toGrowthCampaign` mapper so update/pause responses hydrate the model directly.
export const CAMPAIGN_RETURNING =
  `id, name, channel, status, budget_inr AS "budgetInr",
   audience, scheduled_at AS "scheduledAt", created_at AS "createdAt", updated_at`;

export async function updateGrowthCampaign(
  db: TenantQueryClient,
  sets: string[],
  params: unknown[],
): Promise<Record<string, unknown>[]> {
  return await db.queryObject<Record<string, unknown>>(
    `UPDATE growth_campaigns SET ${sets.join(", ")}
     WHERE id = $1
     RETURNING ${CAMPAIGN_RETURNING}`,
    params,
  );
}

export async function pauseGrowthCampaign(
  db: TenantQueryClient,
  campaignId: string,
): Promise<Record<string, unknown>[]> {
  return await db.queryObject<Record<string, unknown>>(
    `UPDATE growth_campaigns SET status = 'paused'
     WHERE id = $1
     RETURNING ${CAMPAIGN_RETURNING}`,
    [campaignId],
  );
}

export async function listGrowthCampaignHistory(
  db: TenantQueryClient,
): Promise<Record<string, unknown>[]> {
  return await db.queryObject<Record<string, unknown>>(
    `SELECT ${CAMPAIGN_RETURNING}
     FROM growth_campaigns
     WHERE status IN ('paused', 'completed')
     ORDER BY updated_at DESC
     LIMIT 100`,
  );
}

export interface GrowthFunnelStageCount {
  status: string;
  count: string;
}

export async function listFunnelStageCounts(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string | null,
): Promise<GrowthFunnelStageCount[]> {
  return await db.queryObject<GrowthFunnelStageCount>(
    `SELECT status, count(*)::text AS count
     FROM growth_inquiries
     WHERE organization_id = $1 AND school_id = $2
     GROUP BY status`,
    [organizationId, schoolId],
  );
}

export interface GrowthCampaignAttribution {
  campaign_name: string;
  inquiries: string;
  converted: string;
}

export async function listCampaignAttribution(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string | null,
): Promise<GrowthCampaignAttribution[]> {
  return await db.queryObject<GrowthCampaignAttribution>(
    `SELECT coalesce(c.name, 'Unattributed') AS campaign_name,
            count(i.id)::text AS inquiries,
            count(i.id) FILTER (WHERE i.status = 'converted')::text AS converted
     FROM growth_inquiries i
     LEFT JOIN growth_campaigns c ON c.id = i.campaign_id
     WHERE i.organization_id = $1 AND i.school_id = $2
     GROUP BY c.name`,
    [organizationId, schoolId],
  );
}

export interface GrowthSourceAttribution {
  source: string;
  inquiries: string;
  converted: string;
}

export async function listSourceAttribution(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string | null,
): Promise<GrowthSourceAttribution[]> {
  return await db.queryObject<GrowthSourceAttribution>(
    `SELECT source,
            count(*)::text AS inquiries,
            count(*) FILTER (WHERE status = 'converted')::text AS converted
     FROM growth_inquiries
     WHERE organization_id = $1 AND school_id = $2
     GROUP BY source`,
    [organizationId, schoolId],
  );
}

export interface GrowthInquiryForConversion {
  parent_name: string;
  phone: string | null;
  grade_interest: string | null;
  source: string;
  campaign_id: string | null;
  lead_id: string | null;
}

export async function getInquiryForConversion(
  db: TenantQueryClient,
  inquiryId: string,
): Promise<GrowthInquiryForConversion | null> {
  const rows = await db.queryObject<GrowthInquiryForConversion>(
    `SELECT parent_name, phone, grade_interest, source, campaign_id, lead_id
     FROM growth_inquiries WHERE id = $1`,
    [inquiryId],
  );
  return rows[0] ?? null;
}

export async function getCampaignNameById(
  db: TenantQueryClient,
  campaignId: string,
): Promise<string | null> {
  const rows = await db.queryObject<{ name: string }>(
    `SELECT name FROM growth_campaigns WHERE id = $1`,
    [campaignId],
  );
  return rows[0]?.name ?? null;
}

export async function markGrowthInquiryConverted(
  db: TenantQueryClient,
  inquiryId: string,
  leadId: string,
): Promise<void> {
  await db.queryObject(
    `UPDATE growth_inquiries
     SET status = 'converted', lead_id = $2, updated_at = timezone('utc', now())
     WHERE id = $1`,
    [inquiryId, leadId],
  );
}

export async function listGrowthInquiries(
  db: TenantQueryClient,
): Promise<Record<string, unknown>[]> {
  return await db.queryObject<Record<string, unknown>>(
    `SELECT id, parent_name AS "parentName", phone, grade_interest AS "gradeInterest",
            source, status, follow_up_at AS "followUpAt", campaign_id AS "campaignId",
            lead_id AS "leadId"
     FROM growth_inquiries
     ORDER BY created_at DESC
     LIMIT 100`,
  );
}
