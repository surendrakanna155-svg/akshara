import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { createModuleReadHandlers } from "../entity_read/module_read_handlers.ts";
import {
  type AlumniLiveRows,
  alumniDetailToApi,
  alumniStore,
  computeAlumniDashboard,
  computeAlumniReports,
} from "./alumni_read_repository.ts";

const { handleList, handleSnapshot } = createModuleReadHandlers(
  "viewAlumni",
  alumniStore,
);

const VIEW_ALUMNI = "viewAlumni";

/** Default report catalog (report template definitions, not seeded data). */
const REPORTS_CATALOG: Array<Record<string, unknown>> = [
  {
    id: "rpt_eng",
    title: "Engagement Report",
    description: "Alumni activity summary",
    lastGenerated: "",
  },
];

const PAGE_SIZE = 100;

function requireRead(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, VIEW_ALUMNI) ??
    requireSchoolOperationalScope(claims);
}

/** Page through every row of an entity type so aggregates are exact at any scale. */
async function listAll(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  entityType: string,
): Promise<Array<Record<string, unknown>>> {
  const items: Array<Record<string, unknown>> = [];
  let page = 1;
  while (true) {
    const result = await alumniStore.listEntities(db, orgId, schoolId, entityType, {
      page,
      pageSize: PAGE_SIZE,
    });
    items.push(...result.items);
    if (!result.hasMore) break;
    page += 1;
  }
  return items;
}

async function loadLiveRows(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<AlumniLiveRows> {
  const [alumni, events, campaigns, donations, mentorship] = await Promise.all([
    listAll(db, orgId, schoolId, "alumni"),
    listAll(db, orgId, schoolId, "event"),
    listAll(db, orgId, schoolId, "campaign"),
    listAll(db, orgId, schoolId, "donation"),
    listAll(db, orgId, schoolId, "mentorship"),
  ]);
  return { alumni, events, campaigns, donations, mentorship };
}

async function withReadContext<T>(
  req: Request,
  config: AppConfig,
  errorMessage: string,
  compute: (db: TenantQueryClient, orgId: string, schoolId: string) => Promise<T>,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) =>
      await compute(db, orgId, schoolId)
    );
    return jsonResponse(envelope(result as Record<string, unknown>));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error(`${errorMessage}:`, error);
    return errorEnvelope("INTERNAL_ERROR", errorMessage, 500);
  }
}

export async function handleDashboard(req: Request, config: AppConfig): Promise<Response> {
  return await withReadContext(
    req,
    config,
    "Failed to load alumni dashboard",
    async (db, orgId, schoolId) => {
      const rows = await loadLiveRows(db, orgId, schoolId);
      return computeAlumniDashboard(rows);
    },
  );
}

export async function handleRegistry(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "alumni", "Failed to load alumni registry");
}

export async function handleAlumniDetail(
  req: Request,
  config: AppConfig,
  alumniId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const notFoundMessage = `Alumni not found: ${alumniId}`;

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const alumni = await alumniStore.getEntity(db, orgId, schoolId, "alumni", alumniId);
      const donations = await listAll(db, orgId, schoolId, "donation");
      return alumniDetailToApi(alumni, donations);
    });
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof alumniStore.EntityNotFoundError) {
      return errorEnvelope("NOT_FOUND", notFoundMessage, 404);
    }
    console.error(`handleAlumniDetail(${alumniId}) error:`, error);
    return errorEnvelope("INTERNAL_ERROR", notFoundMessage, 500);
  }
}

export async function handleEvents(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "event", "Failed to load alumni events");
}

export async function handleDonations(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "donation", "Failed to load alumni donations");
}

export async function handleCampaigns(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "campaign", "Failed to load alumni campaigns");
}

export async function handleMentorship(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "mentorship", "Failed to load mentorship pairs");
}

export async function handleReports(req: Request, config: AppConfig): Promise<Response> {
  return await withReadContext(
    req,
    config,
    "Failed to load alumni reports",
    async (db, orgId, schoolId) => {
      // #5: alumni rows are needed too, for the engagementByBatch aggregation.
      const [alumni, donations, events] = await Promise.all([
        listAll(db, orgId, schoolId, "alumni"),
        listAll(db, orgId, schoolId, "donation"),
        listAll(db, orgId, schoolId, "event"),
      ]);
      return computeAlumniReports({ alumni, donations, events }, REPORTS_CATALOG);
    },
  );
}

export async function handleSettings(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_settings", "Failed to load alumni settings");
}
