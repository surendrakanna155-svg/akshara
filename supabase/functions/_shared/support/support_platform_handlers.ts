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
  // Both are needed, and they are NOT interchangeable: cluster SIZE (for
  // investigation confidence and the engineering handoff) counts every member,
  // while resolve targets only rows that have not already transitioned.
  listClusterIncidentIds,
  listClusters,
  listUnresolvedClusterIncidentIds,
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
  isSettableSupportStatus,
} from "./support_platform_service.ts";
import { getKbArticle, listKbArticles } from "./support_kb_repository.ts";
import {
  augmentRecallSemantic,
  embedArticleBestEffort,
  learnFromResolutionBestEffort,
  recallForIncident,
} from "./support_kb_service.ts";


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
    // ASIP-8: proactively surface prior resolutions for this signature
    // (deterministic recall — cheap, no network on the detail path).
    const kbMatches = await recallForIncident(db, incident, evidence);
    return { incident, evidence, notes, cluster, kbMatches };
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
  // RC-3 (audit P1-B): `resolved` is NOT reachable through this endpoint — it
  // writes only the mirror row, while resolving must also propagate to the
  // school, notify the reporter and learn a KB article. See
  // isSettableSupportStatus().
  if (!body || !isSettableSupportStatus(body.status ?? "")) {
    if (body?.status === "resolved") {
      return errorEnvelope(
        "VALIDATION",
        "Use the resolve endpoint to resolve an incident — it also notifies the " +
          "school and records the resolution. Setting 'resolved' here would close " +
          "it only inside the support console.",
        422,
      );
    }
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
    // ASIP-8: deterministic recall of prior resolutions (in-tx, no network).
    const kb = await recallForIncident(db, incident, evidence);
    return { incident, evidence, clusterSize, kb };
  });
  if ("notFound" in loaded) return errorEnvelope("NOT_FOUND", "Incident not found", 404);
  // Optional semantic augmentation runs in its own tx (best-effort, dormant
  // without embeddings/pgvector); then the model call runs in its own tx too.
  const priorResolutions = await augmentRecallSemantic(
    config,
    a.claims,
    loaded.incident,
    loaded.evidence,
    loaded.kb,
  );
  const investigation = await investigate(
    config,
    a.claims,
    loaded.incident,
    loaded.evidence,
    loaded.clusterSize,
    priorResolutions,
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

    // Capture the cluster's root cause BEFORE setClusterResolution overwrites it.
    const priorCluster = incident.cluster_id ? await getCluster(db, incident.cluster_id) : null;

    // RC-4 (audit P1-C): resolve only rows that have not already transitioned.
    // The notify bridge enqueues a push unconditionally on a `resolved` target,
    // so re-resolving an already-resolved incident (directly, or by resolving
    // its cluster afterwards) sent the reporter a second push and inflated the
    // KB counters. Skipping settled rows makes resolve idempotent.
    const targets = body?.resolveCluster && incident.cluster_id
      ? await listUnresolvedClusterIncidentIds(db, incident.cluster_id)
      : incident.support_status === "resolved"
      ? []
      : [incidentId];

    // Nothing left to transition — a no-op re-resolve. No propagation, no
    // notification, and no KB delta.
    if (targets.length === 0) {
      return { resolvedCount: 0, learnInput: null };
    }

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

    // Read the evidence needed for KB learning while the context is open, but do
    // NOT learn here — see below.
    const evidence = await listPlatformEvidence(db, incidentId);

    await recordServerAuditEvent(db, a.claims, {
      eventType: "supportPlatformResolved",
      category: "support",
      entityType: "support_platform_incident",
      entityId: incidentId,
      metadata: {
        resolvedCount: targets.length,
        cluster: body?.resolveCluster === true,
        // KB learning is deferred to its own transaction after this one commits,
        // so its outcome is not knowable here.
        kbLearnDeferred: true,
      },
      correlationId: correlationIdFromRequest(req),
    }, req);
    return {
      resolvedCount: targets.length,
      learnInput: {
        incident,
        evidence,
        resolution,
        clusterRootCause: priorCluster?.root_cause ?? "",
        schoolsSeen: targets.length,
      },
    };
  });
  if ("notFound" in result) return errorEnvelope("NOT_FOUND", "Incident not found", 404);

  // ASIP-8 continuous learning: distil this resolution into a KB article keyed by
  // the incident's signature, so a future incident with the same signature
  // recalls it. Runs in its OWN transaction, AFTER the resolution has committed
  // and the school has been notified — a KB failure must never roll back a
  // school-facing resolution.
  const article = result.learnInput
    ? await learnFromResolutionBestEffort(config, a.claims, result.learnInput)
    : null;

  // Best-effort semantic index of the new article (own tx; dormant without
  // embeddings/pgvector; never affects the response).
  if (article) await embedArticleBestEffort(config, a.claims, article);
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

// ─── ASIP-8: knowledge base (learned resolutions) ──────────────────────────────

/** Browse/search the KB the support team has learned from resolutions. */
export async function handlePlatformKbList(req: Request, config: AppConfig): Promise<Response> {
  const a = await auth(req, config);
  if (!a.ok) return a.response;
  const url = new URL(req.url);
  const result = await withTenantContext(config, a.claims, (db) =>
    listKbArticles(db, {
      q: url.searchParams.get("q") ?? undefined,
      page: Number(url.searchParams.get("page") ?? "1") || 1,
      pageSize: Number(url.searchParams.get("pageSize") ?? "20") || 20,
    }));
  return jsonResponse(envelope(result));
}

export async function handlePlatformKbArticle(
  req: Request,
  config: AppConfig,
  articleId: string,
): Promise<Response> {
  const a = await auth(req, config);
  if (!a.ok) return a.response;
  const article = await withTenantContext(config, a.claims, (db) => getKbArticle(db, articleId));
  if (!article) return errorEnvelope("NOT_FOUND", "Article not found", 404);
  return jsonResponse(envelope(article));
}
