// ASIP — Phase 2: support-console HTTP handlers. Every handler requires a
// PLATFORM_ORG session holding the platformSupport permission; the mirror RLS
// does the data scoping. Resolutions flow back to the school via the SECURITY
// DEFINER propagate bridge (which itself asserts the caller is PLATFORM_ORG).

import type { AppConfig } from "../config.ts";
import { authenticateRequest } from "../permission_middleware.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { withTenantContext } from "../tenant_db.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import { correlationIdFromRequest, recordServerAuditEvent } from "../audit/audit_repository.ts";
import { propagateResolution } from "./support_mirror.ts";
import {
  assignPlatformIncident,
  escalatePlatformIncident,
  getCluster,
  getPlatformIncident,
  insertPlatformNote,
  listClusterIncidentIds,
  listClusters,
  listPlatformEvidence,
  listPlatformIncidents,
  listPlatformNotes,
  setClusterResolution,
  setPlatformSupportStatus,
  SUPPORT_PLATFORM_ORG,
} from "./support_platform_repository.ts";
import {
  autoCluster,
  buildEngineeringHandoff,
  investigate,
} from "./support_platform_service.ts";

const SUPPORT_STATUS_ORDER = ["queue", "investigating", "awaiting_engineering", "resolved"];

/** PLATFORM_ORG session + platformSupport permission, else 403. */
function requirePlatformSupport(claims: AccessTokenClaims): Response | null {
  if (claims.tenant_id !== SUPPORT_PLATFORM_ORG || !claims.permissions.includes("platformSupport")) {
    return errorEnvelope("FORBIDDEN", "Platform support access required", 403);
  }
  return null;
}

async function auth(req: Request, config: AppConfig): Promise<
  { ok: true; claims: AccessTokenClaims } | { ok: false; response: Response }
> {
  const a = await authenticateRequest(req, config);
  if (!a.ok) return a;
  const denied = requirePlatformSupport(a.claims);
  if (denied) return { ok: false, response: denied };
  return { ok: true, claims: a.claims };
}

export async function handlePlatformQueue(req: Request, config: AppConfig): Promise<Response> {
  const a = await auth(req, config);
  if (!a.ok) return a.response;
  const url = new URL(req.url);
  const result = await withTenantContext(config, a.claims, (db) =>
    listPlatformIncidents(db, {
      supportStatus: url.searchParams.get("support_status") ?? undefined,
      clusterId: url.searchParams.get("cluster_id") ?? undefined,
      page: Number(url.searchParams.get("page") ?? "1") || 1,
      pageSize: Number(url.searchParams.get("pageSize") ?? "20") || 20,
    }));
  return jsonResponse(envelope(result));
}

export async function handlePlatformIncident(
  req: Request,
  config: AppConfig,
  incidentId: string,
): Promise<Response> {
  const a = await auth(req, config);
  if (!a.ok) return a.response;
  const claims = a.claims;
  const loaded = await withTenantContext(config, claims, async (db) => {
    let incident = await getPlatformIncident(db, incidentId);
    if (!incident) return { notFound: true as const };
    const evidence = await listPlatformEvidence(db, incidentId);
    // Lazy "investigate once": cluster the incident on first support view.
    if (!incident.cluster_id) {
      await autoCluster(db, claims, incident, evidence);
      incident = await getPlatformIncident(db, incidentId) ?? incident;
    }
    const notes = await listPlatformNotes(db, incidentId);
    const cluster = incident.cluster_id ? await getCluster(db, incident.cluster_id) : null;
    return { incident, evidence, notes, cluster };
  });
  if ("notFound" in loaded) return errorEnvelope("NOT_FOUND", "Incident not found", 404);
  return jsonResponse(envelope(loaded));
}

export async function handlePlatformAssign(
  req: Request,
  config: AppConfig,
  incidentId: string,
): Promise<Response> {
  const a = await auth(req, config);
  if (!a.ok) return a.response;
  const body = await readJson<{ assignedTo?: string | null }>(req);
  // Omitted assignedTo assigns to self; explicit null unassigns.
  const assignedTo = body && "assignedTo" in body ? body.assignedTo ?? null : a.claims.sub;
  const updated = await withTenantContext(config, a.claims, async (db) => {
    const row = await assignPlatformIncident(db, incidentId, assignedTo);
    if (row) {
      await recordServerAuditEvent(db, a.claims, {
        eventType: "supportPlatformAssigned",
        category: "support",
        entityType: "support_platform_incident",
        entityId: incidentId,
        metadata: { assignedTo },
        correlationId: correlationIdFromRequest(req),
      }, req);
    }
    return row;
  });
  if (!updated) return errorEnvelope("NOT_FOUND", "Incident not found", 404);
  return jsonResponse(envelope(updated));
}

export async function handlePlatformSupportStatus(
  req: Request,
  config: AppConfig,
  incidentId: string,
): Promise<Response> {
  const a = await auth(req, config);
  if (!a.ok) return a.response;
  const body = await readJson<{ status?: string }>(req);
  if (!body || !SUPPORT_STATUS_ORDER.includes(body.status ?? "")) {
    return errorEnvelope("VALIDATION", "a valid support status is required", 422);
  }
  const result = await withTenantContext(config, a.claims, async (db) => {
    const incident = await getPlatformIncident(db, incidentId);
    if (!incident) return { notFound: true as const };
    const updated = await setPlatformSupportStatus(db, incidentId, incident.support_status, body.status!);
    if (!updated) return { conflict: true as const };
    await recordServerAuditEvent(db, a.claims, {
      eventType: "supportPlatformStatusChanged",
      category: "support",
      entityType: "support_platform_incident",
      entityId: incidentId,
      metadata: { from: incident.support_status, to: body.status },
      correlationId: correlationIdFromRequest(req),
    }, req);
    return { updated };
  });
  if ("notFound" in result) return errorEnvelope("NOT_FOUND", "Incident not found", 404);
  if ("conflict" in result) return errorEnvelope("CONFLICT", "Status changed concurrently", 409);
  return jsonResponse(envelope(result.updated));
}

export async function handlePlatformEscalate(
  req: Request,
  config: AppConfig,
  incidentId: string,
): Promise<Response> {
  const a = await auth(req, config);
  if (!a.ok) return a.response;
  const updated = await withTenantContext(config, a.claims, async (db) => {
    const row = await escalatePlatformIncident(db, incidentId);
    if (row) {
      await recordServerAuditEvent(db, a.claims, {
        eventType: "supportPlatformEscalated",
        category: "support",
        entityType: "support_platform_incident",
        entityId: incidentId,
        correlationId: correlationIdFromRequest(req),
      }, req);
    }
    return row;
  });
  if (!updated) return errorEnvelope("NOT_FOUND", "Incident not found", 404);
  return jsonResponse(envelope(updated));
}

export async function handlePlatformNote(
  req: Request,
  config: AppConfig,
  incidentId: string,
): Promise<Response> {
  const a = await auth(req, config);
  if (!a.ok) return a.response;
  const body = await readJson<{ body?: string }>(req);
  if (!body || typeof body.body !== "string" || body.body.trim().length === 0) {
    return errorEnvelope("VALIDATION", "body is required", 422);
  }
  const note = await withTenantContext(config, a.claims, async (db) => {
    const incident = await getPlatformIncident(db, incidentId);
    if (!incident) return null;
    return await insertPlatformNote(db, a.claims, incidentId, body.body!.trim().slice(0, 8000));
  });
  if (!note) return errorEnvelope("NOT_FOUND", "Incident not found", 404);
  return jsonResponse(envelope(note), { status: 201 });
}

export async function handlePlatformInvestigate(
  req: Request,
  config: AppConfig,
  incidentId: string,
): Promise<Response> {
  const a = await auth(req, config);
  if (!a.ok) return a.response;
  const loaded = await withTenantContext(config, a.claims, async (db) => {
    const incident = await getPlatformIncident(db, incidentId);
    if (!incident) return { notFound: true as const };
    const evidence = await listPlatformEvidence(db, incidentId);
    const clusterSize = incident.cluster_id
      ? (await listClusterIncidentIds(db, incident.cluster_id)).length
      : 1;
    return { incident, evidence, clusterSize };
  });
  if ("notFound" in loaded) return errorEnvelope("NOT_FOUND", "Incident not found", 404);
  // The model call runs in its own transaction (inside investigate).
  const investigation = await investigate(
    config,
    a.claims,
    loaded.incident,
    loaded.evidence,
    loaded.clusterSize,
  );
  return jsonResponse(envelope(investigation));
}

export async function handlePlatformHandoff(
  req: Request,
  config: AppConfig,
  incidentId: string,
): Promise<Response> {
  const a = await auth(req, config);
  if (!a.ok) return a.response;
  const result = await withTenantContext(config, a.claims, async (db) => {
    const incident = await getPlatformIncident(db, incidentId);
    if (!incident) return { notFound: true as const };
    const evidence = await listPlatformEvidence(db, incidentId);
    const notes = await listPlatformNotes(db, incidentId);
    const clusterSize = incident.cluster_id
      ? (await listClusterIncidentIds(db, incident.cluster_id)).length
      : 1;
    return { handoff: buildEngineeringHandoff(incident, evidence, notes, clusterSize) };
  });
  if ("notFound" in result) return errorEnvelope("NOT_FOUND", "Incident not found", 404);
  return jsonResponse(envelope(result.handoff));
}

/** Resolve an incident (and, optionally, its whole cluster) — propagating the
 * resolution back to every affected school. "Resolve many." */
export async function handlePlatformResolve(
  req: Request,
  config: AppConfig,
  incidentId: string,
): Promise<Response> {
  const a = await auth(req, config);
  if (!a.ok) return a.response;
  const body = await readJson<{ resolution?: string; resolveCluster?: boolean }>(req);
  const resolution = (body?.resolution ?? "").trim().slice(0, 2000);
  if (!resolution) return errorEnvelope("VALIDATION", "resolution is required", 422);

  const result = await withTenantContext(config, a.claims, async (db) => {
    const incident = await getPlatformIncident(db, incidentId);
    if (!incident) return { notFound: true as const };

    const targets = body?.resolveCluster && incident.cluster_id
      ? await listClusterIncidentIds(db, incident.cluster_id)
      : [incidentId];

    for (const id of targets) {
      // Write resolution back to the school incident + mark the mirror resolved.
      await propagateResolution(db, id, "resolved", resolution);
      await setPlatformSupportStatus(db, id, "queue", "resolved");
      await setPlatformSupportStatus(db, id, "investigating", "resolved");
      await setPlatformSupportStatus(db, id, "awaiting_engineering", "resolved");
    }
    if (body?.resolveCluster && incident.cluster_id) {
      await setClusterResolution(db, incident.cluster_id, "resolved", "", resolution);
    }
    await recordServerAuditEvent(db, a.claims, {
      eventType: "supportPlatformResolved",
      category: "support",
      entityType: "support_platform_incident",
      entityId: incidentId,
      metadata: { resolvedCount: targets.length, cluster: body?.resolveCluster === true },
      correlationId: correlationIdFromRequest(req),
    }, req);
    return { resolvedCount: targets.length };
  });
  if ("notFound" in result) return errorEnvelope("NOT_FOUND", "Incident not found", 404);
  return jsonResponse(envelope({ resolved: true, count: result.resolvedCount }));
}

export async function handlePlatformClusters(req: Request, config: AppConfig): Promise<Response> {
  const a = await auth(req, config);
  if (!a.ok) return a.response;
  const url = new URL(req.url);
  const result = await withTenantContext(config, a.claims, (db) =>
    listClusters(db, {
      status: url.searchParams.get("status") ?? undefined,
      page: Number(url.searchParams.get("page") ?? "1") || 1,
      pageSize: Number(url.searchParams.get("pageSize") ?? "20") || 20,
    }));
  return jsonResponse(envelope(result));
}

export async function handlePlatformCluster(
  req: Request,
  config: AppConfig,
  clusterId: string,
): Promise<Response> {
  const a = await auth(req, config);
  if (!a.ok) return a.response;
  const result = await withTenantContext(config, a.claims, async (db) => {
    const cluster = await getCluster(db, clusterId);
    if (!cluster) return { notFound: true as const };
    const incidents = await listPlatformIncidents(db, { clusterId, page: 1, pageSize: 100 });
    return { cluster, incidents: incidents.items };
  });
  if ("notFound" in result) return errorEnvelope("NOT_FOUND", "Cluster not found", 404);
  return jsonResponse(envelope(result));
}
