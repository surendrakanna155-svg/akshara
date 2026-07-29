// ASIP — Phase 2: the school-side half of the mirror (Owner Decision A1). Thin
// wrappers over the SECURITY DEFINER bridges. The bridges themselves take the
// source org/school from the session GUC (never a parameter), so these can only
// ever mirror the CALLER's own incident. Mirroring runs BEST-EFFORT in its own
// transaction so a mirror hiccup never blocks (or rolls back) a school's report.

import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { withTenantContext } from "../tenant_db.ts";
import type { EvidenceParts } from "./support_service.ts";
import type { IncidentRow } from "./support_types.ts";

export async function mirrorIncident(db: TenantQueryClient, incident: IncidentRow): Promise<void> {
  await db.queryObject(
    `SELECT app_support_mirror_incident(
       $1::uuid, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12::timestamptz)`,
    [
      incident.id,
      incident.public_ref,
      incident.title,
      incident.description,
      incident.category,
      incident.severity,
      incident.status,
      incident.module_key,
      incident.screen_route,
      incident.app_version,
      incident.platform,
      incident.first_seen_at,
    ],
  );
}

export async function mirrorEvidence(
  db: TenantQueryClient,
  incidentId: string,
  kind: string,
  payload: Record<string, unknown>,
): Promise<void> {
  await db.queryObject(
    `SELECT app_support_mirror_evidence($1::uuid, $2, $3::jsonb)`,
    [incidentId, kind, JSON.stringify(payload)],
  );
}

export async function propagateResolution(
  db: TenantQueryClient,
  incidentId: string,
  sourceStatus: string,
  resolution: string,
): Promise<void> {
  await db.queryObject(
    `SELECT app_support_propagate_resolution($1::uuid, $2, $3)`,
    [incidentId, sourceStatus, resolution],
  );
}

/** Best-effort full mirror of an incident + its PII-minimized evidence, in its
 * own transaction. Never throws. */
export async function mirrorIncidentBestEffort(
  config: AppConfig,
  claims: AccessTokenClaims,
  incident: IncidentRow,
  parts: EvidenceParts,
): Promise<void> {
  try {
    await withTenantContext(config, claims, async (db) => {
      await mirrorIncident(db, incident);
      await mirrorEvidence(db, incident.id, "client_context", parts.clientContextEv.value);
      await mirrorEvidence(db, incident.id, "breadcrumbs", parts.breadcrumbEv.value);
      await mirrorEvidence(db, incident.id, "api_calls", parts.apiCallsEv.value);
      await mirrorEvidence(db, incident.id, "audit_events", parts.auditEv.value);
      await mirrorEvidence(db, incident.id, "diagnostics", {
        failingCorrelationId: parts.diagnostics.failingCorrelationId,
        apiErrorCount: parts.diagnostics.apiErrorCount,
        topErrorStatus: parts.diagnostics.topErrorStatus,
        topErrorPath: parts.diagnostics.topErrorPath,
        signals: parts.diagnostics.signals,
      });
    });
  } catch (_err) {
    // Best-effort: the school report already succeeded, so a mirror failure is
    // never surfaced to the reporter. Recovery is reconcileMirrorBestEffort(),
    // invoked from collect-evidence and from a status change.
    //
    // This comment previously claimed a retry "can re-run via collect-evidence".
    // That was false — collect-evidence did not re-mirror, and no reconcile path
    // existed, so a transient failure here left the incident permanently
    // invisible in the support console.
  }
}

/**
 * RC-5 (audit P1-E): repair a mirror that was never created.
 *
 * `mirrorIncidentBestEffort` runs once, at incident creation. If it failed —
 * a transient DB error, say — the school's report still succeeded (201) but no
 * mirror row existed, and nothing ever retried. If the school never changed the
 * incident's status it stayed permanently invisible to support, with no recovery
 * path. (Not data loss: the school-side incident is intact; only the support
 * copy is missing.)
 *
 * Re-running the full mirror is safe because `mirrorIncident` and
 * `mirrorEvidence` are upserts, so reconciling an already-mirrored incident is a
 * no-op. Never throws.
 */
export async function reconcileMirrorBestEffort(
  config: AppConfig,
  claims: AccessTokenClaims,
  incident: IncidentRow,
  parts: EvidenceParts,
): Promise<void> {
  await mirrorIncidentBestEffort(config, claims, incident, parts);
}

/** Best-effort mirror of just the incident header (e.g. after a status change). */
export async function mirrorIncidentHeaderBestEffort(
  config: AppConfig,
  claims: AccessTokenClaims,
  incident: IncidentRow,
): Promise<void> {
  try {
    await withTenantContext(config, claims, (db) => mirrorIncident(db, incident));
  } catch (_err) {
    // Best-effort.
  }
}
