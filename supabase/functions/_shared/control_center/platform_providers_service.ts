import type { TenantQueryClient } from "../tenant_db.ts";

export async function recordUsageEvent(
  db: TenantQueryClient,
  input: {
    organizationId?: string;
    schoolId?: string;
    providerCategory: string;
    providerName: string;
    eventType: string;
    units?: number;
    costInr?: number;
  },
): Promise<void> {
  await db.queryObject(
    `INSERT INTO platform_usage_events (
       organization_id, school_id, provider_category, provider_name,
       event_type, units, cost_inr
     ) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
    [
      input.organizationId ?? null,
      input.schoolId ?? null,
      input.providerCategory,
      input.providerName,
      input.eventType,
      input.units ?? 1,
      input.costInr ?? 0,
    ],
  );
}

export async function getUsageAnalytics(
  db: TenantQueryClient,
  organizationId?: string,
): Promise<{
  totalEvents: number;
  totalCostInr: number;
  byCategory: Record<string, { events: number; costInr: number }>;
  byProvider: Record<string, { events: number; costInr: number }>;
}> {
  const conditions = organizationId ? ["organization_id = $1"] : ["1=1"];
  const params = organizationId ? [organizationId] : [];

  const rows = await db.queryObject<{
    provider_category: string;
    provider_name: string;
    events: string;
    cost: string;
  }>(
    `SELECT provider_category, provider_name,
            count(*)::text AS events,
            coalesce(sum(cost_inr), 0)::text AS cost
     FROM platform_usage_events
     WHERE ${conditions.join(" AND ")}
     GROUP BY provider_category, provider_name`,
    params,
  );

  let totalEvents = 0;
  let totalCostInr = 0;
  const byCategory: Record<string, { events: number; costInr: number }> = {};
  const byProvider: Record<string, { events: number; costInr: number }> = {};

  for (const row of rows) {
    const events = Number(row.events);
    const costInr = Number(row.cost);
    totalEvents += events;
    totalCostInr += costInr;

    const cat = byCategory[row.provider_category] ?? { events: 0, costInr: 0 };
    cat.events += events;
    cat.costInr += costInr;
    byCategory[row.provider_category] = cat;

    const key = `${row.provider_category}:${row.provider_name}`;
    byProvider[key] = { events, costInr };
  }

  return { totalEvents, totalCostInr, byCategory, byProvider };
}

export async function listFeatureEnablements(
  db: TenantQueryClient,
  orgId: string,
  schoolId?: string,
): Promise<Array<{ schoolId: string; featureKey: string; enabled: boolean }>> {
  if (schoolId) {
    return await db.queryObject(
      `SELECT school_id AS "schoolId", feature_key AS "featureKey", enabled
       FROM platform_feature_enablements
       WHERE organization_id = $1 AND school_id = $2`,
      [orgId, schoolId],
    );
  }
  return await db.queryObject(
    `SELECT school_id AS "schoolId", feature_key AS "featureKey", enabled
     FROM platform_feature_enablements WHERE organization_id = $1`,
    [orgId],
  );
}

export async function setFeatureEnablement(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  featureKey: string,
  enabled: boolean,
  updatedBy: string,
): Promise<void> {
  await db.queryObject(
    `INSERT INTO platform_feature_enablements (organization_id, school_id, feature_key, enabled, updated_by)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (organization_id, school_id, feature_key)
     DO UPDATE SET enabled = EXCLUDED.enabled, updated_by = EXCLUDED.updated_by, updated_at = now()`,
    [orgId, schoolId, featureKey, enabled, updatedBy],
  );
}

export function usageAnalyticsToApi(data: Awaited<ReturnType<typeof getUsageAnalytics>>) {
  return {
    totalEvents: data.totalEvents,
    totalCostInr: data.totalCostInr,
    byCategory: data.byCategory,
    byProvider: data.byProvider,
  };
}
