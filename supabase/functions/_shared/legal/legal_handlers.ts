import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import { authenticateRequest } from "../permission_middleware.ts";
import {
  TenantDbNotConfiguredError,
  TenantQueryClient,
  withTenantContext,
} from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, legalAudit } from "../audit/mutation_audit_catalog.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  computeOutstanding,
  LEGAL_POLICIES,
  requiredPolicyKeysForClaims,
  toPolicyView,
} from "./legal_catalog.ts";
import {
  acceptedVersionsByKey,
  insertAcceptance,
  listAcceptances,
} from "./legal_repository.ts";

function clientIp(req: Request): string | null {
  return req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? null;
}

function userAgent(req: Request): string | null {
  return req.headers.get("user-agent");
}

/** The status payload: what this user must accept, has accepted, and still owes. */
async function buildStatus(db: TenantQueryClient, claims: AccessTokenClaims) {
  const requiredKeys = requiredPolicyKeysForClaims(claims);
  const rows = await listAcceptances(db, claims.sub);
  const outstanding = computeOutstanding(
    requiredKeys,
    acceptedVersionsByKey(rows),
  );
  return {
    policies: requiredKeys
      .map((key) => LEGAL_POLICIES[key])
      .filter((def): def is NonNullable<typeof def> => Boolean(def))
      .map(toPolicyView),
    accepted: rows.map((r) => ({
      key: r.policy_key,
      version: r.policy_version,
      acceptedAt: r.accepted_at,
    })),
    outstanding,
    satisfied: outstanding.length === 0,
  };
}

/**
 * GET /legal/status — every authenticated principal may read their own status.
 * No special permission is required (acceptance is a per-user obligation, not an
 * RBAC-gated action).
 */
export async function handleGetLegalStatus(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  try {
    const status = await withTenantContext(
      config,
      auth.claims,
      (db) => buildStatus(db, auth.claims),
    );
    return jsonResponse(envelope(status));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

interface AcceptItem {
  key: string;
  version: string;
}

/**
 * POST /legal/accept — records the user's acceptance of one or more policies at the
 * CURRENT version. Body: { acceptances: [{ key, version }], device_id?: string }.
 * Records the user, role, scope, tenant, policy key/version, timestamp and IP/device,
 * and emits an audit + domain event per acceptance.
 */
export async function handleAcceptPolicies(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const rawItems = body["acceptances"];
  if (!Array.isArray(rawItems) || rawItems.length === 0) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "acceptances must be a non-empty array",
      422,
    );
  }

  const deviceId = typeof body["device_id"] === "string"
    ? (body["device_id"] as string)
    : null;

  const items: AcceptItem[] = [];
  for (const raw of rawItems) {
    if (typeof raw !== "object" || raw === null) {
      return errorEnvelope("VALIDATION_ERROR", "Invalid acceptance item", 422);
    }
    const key = (raw as Record<string, unknown>)["key"];
    const version = (raw as Record<string, unknown>)["version"];
    if (typeof key !== "string" || typeof version !== "string") {
      return errorEnvelope(
        "VALIDATION_ERROR",
        "Each acceptance needs a string key and version",
        422,
      );
    }
    const def = LEGAL_POLICIES[key];
    if (!def) {
      return errorEnvelope("VALIDATION_ERROR", `Unknown policy: ${key}`, 422);
    }
    if (def.version !== version) {
      // The client is on a stale catalog — ask it to refresh and re-accept.
      return errorEnvelope(
        "POLICY_VERSION_MISMATCH",
        `Policy ${key} current version is ${def.version}, not ${version}. Please refresh and accept again.`,
        409,
      );
    }
    items.push({ key, version });
  }

  const claims = auth.claims;
  const ip = clientIp(req);
  const ua = userAgent(req);

  try {
    const status = await withTenantContext(config, claims, async (db) => {
      for (const item of items) {
        await insertAcceptance(db, {
          organizationId: claims.tenant_id,
          schoolId: claims.school_id,
          userId: claims.sub,
          userRole: claims.primary_role,
          scope: claims.scope,
          policyKey: item.key,
          policyVersion: item.version,
          ipAddress: ip,
          userAgent: ua,
          deviceId,
        });
        await emitMutationAudit(
          db,
          claims,
          legalAudit.policyAccepted(claims.sub, item.key, item.version),
          req,
        );
      }
      return buildStatus(db, claims);
    });
    return jsonResponse(envelope(status), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}
