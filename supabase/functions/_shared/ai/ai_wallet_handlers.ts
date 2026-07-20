// PRC-A Batch 3 (caps 37–43) — AI credit wallet HTTP handlers (owner decision #3).
//
//   GET  /ai-wallet          balance + health + recent ledger        (viewAiWallet)
//   POST /ai-wallet/grant    top_up | adjustment | expiry            (manageAiCredits)
//
// The wallet owns NO state of its own. Balance is the projection defined in
// ai_wallet_repository.ts over rows that already exist:
//   available = SUM(ai_credit_entries.units)
//             - SUM(ai_call_log.credits_debited)
//             - SUM(pending ai_call_reservations.credits_reserved)
// These handlers are the thin HTTP surface over that repository; all admission
// correctness lives in the atomic admit clause in
// ai_call_reservations_repository.ts, never here.
//
// SCOPE MODEL. `ai_credit_entries` is a TENANT table: RLS
// `WITH CHECK organization_id = app_current_tenant_id()`, granted to
// `erp_tenant` (SELECT+INSERT, no UPDATE/DELETE). So every read/write here runs
// through `withTenantContext` — which sets `app_current_tenant_id()` from
// `claims.tenant_id` — and writes `organization_id = organizationIdFromClaims`
// (== `claims.tenant_id`). The RLS check is therefore satisfied by construction,
// and a credit row can only ever land under the caller's own org. A platform
// superAdmin crediting an ARBITRARY other org would need an act-as-org tenant
// context, which this codebase does not have — that is deliberately out of scope
// (see the Batch 3 handoff residue), NOT smuggled in by overriding tenant_id.

import type { AccessTokenClaims } from "../jwt.ts";
import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import type { AiTenantScope } from "./ai_call_log_repository.ts";
import {
  type AiCreditEntryRow,
  type AiWalletBalance,
  grantCredits,
  InvalidCreditGrantError,
  listCreditEntries,
  readWalletBalance,
  walletHealth,
} from "./ai_wallet_repository.ts";

const ENTRY_TYPES = ["top_up", "adjustment", "expiry"] as const;
type EntryType = (typeof ENTRY_TYPES)[number];

function scopeFromClaims(claims: AccessTokenClaims): AiTenantScope {
  // organizationIdFromClaims === claims.tenant_id === app_current_tenant_id().
  // schoolId is carried for parity with the ai_* scope shape but is NOT used by
  // the wallet: credits are an ORG fact (org-scoped surfaces call with school_id
  // NULL), so the balance/ledger are read by organization_id alone.
  return { organizationId: organizationIdFromClaims(claims), schoolId: claims.school_id };
}

function tenantError(error: unknown): Response {
  if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
  return errorEnvelope("INTERNAL_ERROR", String(error), 500);
}

function toNum(v: number | string): number {
  return typeof v === "number" ? v : Number.parseInt(String(v), 10);
}

function balanceToApi(b: AiWalletBalance) {
  return {
    grantedUnits: b.grantedUnits,
    debitedUnits: b.debitedUnits,
    reservedUnits: b.reservedUnits,
    availableUnits: b.availableUnits,
    lastTopUpUnits: b.lastTopUpUnits,
    // The panel and the alert dispatcher must read ONE health verdict; expose the
    // same pure function both use so they can never drift.
    health: walletHealth(b),
  };
}

function entryToApi(row: AiCreditEntryRow) {
  return {
    id: row.id,
    entryType: row.entry_type,
    units: toNum(row.units),
    reason: row.reason,
    actorId: row.actor_id,
    externalRef: row.external_ref,
    createdAt: row.created_at,
  };
}

/** GET /ai-wallet — the org's balance, health verdict and recent ledger. */
export async function handleGetAiWallet(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewAiWallet");
  if (denied) return denied;

  const parsed = Number.parseInt(new URL(req.url).searchParams.get("limit") ?? "50", 10);
  const limit = Number.isFinite(parsed) ? parsed : 50;

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const scope = scopeFromClaims(auth.claims);
      const balance = await readWalletBalance(db, scope);
      const entries = await listCreditEntries(db, scope, limit);
      return { balance, entries };
    });
    return jsonResponse(envelope({
      balance: balanceToApi(result.balance),
      entries: result.entries.map(entryToApi),
    }));
  } catch (error) {
    return tenantError(error);
  }
}

/**
 * POST /ai-wallet/grant — write ONE signed credit-ledger row.
 *
 * Platform-only: `manageAiCredits` is seeded to `superAdmin` ONLY (migration
 * 20260888). A tenant topping up its own wallet at will is the same as having no
 * wallet, so organizationOwner/Admin deliberately do NOT hold it. `viewAiWallet`
 * (org-level) is the tenant's read-only counterpart.
 *
 * There is no UPDATE path by design — reversing a mistake means a compensating
 * row (a negative `adjustment`), so the audit trail always survives.
 */
export async function handleGrantAiCredits(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageAiCredits");
  if (denied) return denied;

  let body: Record<string, unknown>;
  try {
    body = (await readJson<Record<string, unknown>>(req)) ?? {};
  } catch {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const entryType = body.entryType;
  if (typeof entryType !== "string" || !ENTRY_TYPES.includes(entryType as EntryType)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `entryType must be one of: ${ENTRY_TYPES.join(", ")}`,
      422,
    );
  }
  const rawUnits = body.units;
  if (typeof rawUnits !== "number" || !Number.isFinite(rawUnits) || Math.trunc(rawUnits) === 0) {
    return errorEnvelope("VALIDATION_ERROR", "units must be a non-zero number", 422);
  }
  // cap 43: a credit grant/adjustment is auditable or it is not a control — and
  // an unjustified adjustment is unauditable in practice. Require a reason.
  const reason = typeof body.reason === "string" ? body.reason.trim() : "";
  if (!reason) {
    return errorEnvelope("VALIDATION_ERROR", "reason is required", 422);
  }
  const externalRef = typeof body.externalRef === "string" && body.externalRef.trim()
    ? body.externalRef.trim()
    : null;

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const scope = scopeFromClaims(auth.claims);
      // grantCredits also enforces the sign rules (a clear 422 below); the DB
      // CHECK constraint `ai_credit_entries_units_sign_check` is the real
      // guarantee and binds anything that bypasses this function.
      const granted = await grantCredits(db, scope, {
        entryType: entryType as EntryType,
        units: Math.trunc(rawUnits),
        reason,
        actorId: auth.claims.sub,
        externalRef,
      });
      // Audit rides the SAME tenant transaction as the insert, so a granted
      // credit can never exist without its audit row (nor vice-versa).
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("aiWallet.credit_granted", "ai_credit_entry", granted.id, {
          entryType,
          units: granted.units,
          reason,
          externalRef,
        }),
        req,
      );
      // Echo the resulting balance from the SAME transaction (the just-inserted
      // row is visible), so the caller sees the true post-grant state.
      const balance = await readWalletBalance(db, scope);
      return { granted, balance };
    });
    return jsonResponse(envelope({
      entry: { id: result.granted.id, entryType, units: result.granted.units },
      balance: balanceToApi(result.balance),
    }));
  } catch (error) {
    if (error instanceof InvalidCreditGrantError) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    return tenantError(error);
  }
}
