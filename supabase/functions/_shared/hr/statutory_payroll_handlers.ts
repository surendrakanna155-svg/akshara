// PRA-P1-35 (Owner decision #9, FINAL) — statutory payroll config handlers (hr-owned).
//
//   POST /hr/payroll/statutory/config    — upsert a component rule (PF/ESI/PT/TDS)
//   POST /hr/payroll/statutory/pt-slabs  — upsert a per-state PT slab
//   GET  /hr/payroll/statutory/config    — read the configured rules + PT slabs
//
// Rates/ceilings/slabs are DATA the admin configures; nothing is hardcoded. The
// parse functions are PURE (unit-tested DB-free); the arithmetic lives entirely in
// statutory_payroll.ts. The deduction ENGINE is wired into payroll generation /
// processing (hr_write_handlers.ts) — these endpoints only manage the config.

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
import {
  boolOr,
  createModuleWriteHandlers,
  numOr,
  str,
  WriteValidationError,
} from "../entity_write/module_write_handlers.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import {
  type PtSlab,
  type RoundingMode,
  type StatutoryComponent,
  type StatutoryComponentConfig,
  type WageBase,
} from "./statutory_payroll.ts";
import {
  listPtSlabs,
  listStatutoryConfigs,
  upsertComponentConfig,
  upsertPtSlab,
} from "./statutory_payroll_repository.ts";

const { runWrite } = createModuleWriteHandlers("manageHr");

const COMPONENTS = new Set<StatutoryComponent>(["pf", "esi", "pt", "tds"]);
const WAGE_BASES = new Set<WageBase>(["gross", "basic"]);
const ROUNDINGS = new Set<RoundingMode>(["none", "nearest", "up"]);

/** Reads an OPTIONAL non-negative number, or null when the key is absent/null. */
function optionalNonNegative(
  body: Record<string, unknown>,
  label: string,
  ...keys: string[]
): number | null {
  for (const key of keys) {
    if (key in body && body[key] != null) {
      const value = numOr(body, NaN, key);
      if (!Number.isFinite(value) || value < 0) {
        throw new WriteValidationError(
          `Statutory config invalid: ${label} must be a non-negative number`,
          422,
          "STATUTORY_CONFIG_INVALID",
        );
      }
      return value;
    }
  }
  return null;
}

/** Reads a REQUIRED non-negative number with a default. */
function requiredNonNegative(
  body: Record<string, unknown>,
  fallback: number,
  label: string,
  ...keys: string[]
): number {
  const value = numOr(body, fallback, ...keys);
  if (!Number.isFinite(value) || value < 0) {
    throw new WriteValidationError(
      `Statutory config invalid: ${label} must be a non-negative number`,
      422,
      "STATUTORY_CONFIG_INVALID",
    );
  }
  return value;
}

/**
 * Pure: parse + validate a component-config payload. NOTHING is defaulted to a
 * compliance number — rates default to 0 (deploy-safe). Throws 422
 * `STATUTORY_CONFIG_INVALID`.
 */
export function parseComponentConfig(body: Record<string, unknown>): StatutoryComponentConfig {
  const component = (str(body, "component") ?? "").toLowerCase() as StatutoryComponent;
  if (!COMPONENTS.has(component)) {
    throw new WriteValidationError(
      "Statutory config invalid: component must be one of pf, esi, pt, tds",
      422,
      "STATUTORY_CONFIG_INVALID",
    );
  }
  const wageBase = (str(body, "wageBase", "wage_base") ?? "gross").toLowerCase() as WageBase;
  if (!WAGE_BASES.has(wageBase)) {
    throw new WriteValidationError(
      "Statutory config invalid: wageBase must be 'gross' or 'basic'",
      422,
      "STATUTORY_CONFIG_INVALID",
    );
  }
  const rounding = (str(body, "rounding") ?? "nearest").toLowerCase() as RoundingMode;
  if (!ROUNDINGS.has(rounding)) {
    throw new WriteValidationError(
      "Statutory config invalid: rounding must be 'none', 'nearest' or 'up'",
      422,
      "STATUTORY_CONFIG_INVALID",
    );
  }
  const employeeRate = requiredNonNegative(body, 0, "employeeRate", "employeeRate", "employee_rate");
  const employerRate = requiredNonNegative(body, 0, "employerRate", "employerRate", "employer_rate");
  if (employeeRate > 1 || employerRate > 1) {
    // Rates are FRACTIONS (0.12 = 12%). A value > 1 is almost certainly a percent
    // entered as a whole number — reject rather than deduct 1200%.
    throw new WriteValidationError(
      "Statutory config invalid: rates are fractions (0.12 = 12%); a value greater than 1 is not allowed",
      422,
      "STATUTORY_CONFIG_INVALID",
    );
  }
  return {
    component,
    state: (str(body, "state", "jurisdiction") ?? "").toUpperCase() === "ALL"
      ? ""
      : (str(body, "state", "jurisdiction") ?? ""),
    employeeRate,
    employerRate,
    wageBase,
    baseCap: optionalNonNegative(body, "baseCap", "baseCap", "base_cap"),
    eligibilityCeiling: optionalNonNegative(
      body,
      "eligibilityCeiling",
      "eligibilityCeiling",
      "eligibility_ceiling",
    ),
    eligibilityFloor: optionalNonNegative(
      body,
      "eligibilityFloor",
      "eligibilityFloor",
      "eligibility_floor",
    ),
    flatEmployee: optionalNonNegative(body, "flatEmployee", "flatEmployee", "flat_employee"),
    flatEmployer: optionalNonNegative(body, "flatEmployer", "flatEmployer", "flat_employer"),
    rounding,
    active: boolOr(body, true, "active"),
  };
}

/** Pure: parse + validate a PT-slab payload. Throws 422 `STATUTORY_CONFIG_INVALID`. */
export function parsePtSlab(body: Record<string, unknown>): PtSlab {
  const state = str(body, "state", "jurisdiction") ?? "";
  if (state === "") {
    throw new WriteValidationError(
      "Statutory config invalid: a PT slab requires a state",
      422,
      "STATUTORY_CONFIG_INVALID",
    );
  }
  const lowerBound = requiredNonNegative(body, 0, "lowerBound", "lowerBound", "lower_bound");
  const upperBound = optionalNonNegative(body, "upperBound", "upperBound", "upper_bound");
  if (upperBound != null && upperBound < lowerBound) {
    throw new WriteValidationError(
      "Statutory config invalid: upperBound must be >= lowerBound",
      422,
      "STATUTORY_CONFIG_INVALID",
    );
  }
  const amount = requiredNonNegative(body, 0, "amount", "amount");
  let month: number | null = null;
  if ("month" in body && body.month != null) {
    const m = numOr(body, NaN, "month");
    if (!Number.isInteger(m) || m < 1 || m > 12) {
      throw new WriteValidationError(
        "Statutory config invalid: month must be an integer 1..12",
        422,
        "STATUTORY_CONFIG_INVALID",
      );
    }
    month = m;
  }
  return { state, lowerBound, upperBound, amount, month };
}

/** POST /hr/payroll/statutory/config — upsert a statutory component rule. */
export async function handleUpsertStatutoryConfig(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const cfg = parseComponentConfig(body);
    const { id } = await upsertComponentConfig(db, organizationId, schoolId, cfg);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit(
        "hr.statutory.config.upserted",
        "statutory_component_config",
        `${cfg.component}:${cfg.state || "central"}`,
        {
          component: cfg.component,
          state: cfg.state,
          employeeRate: cfg.employeeRate,
          employerRate: cfg.employerRate,
        },
      ),
      request,
    );
    return { payload: { id, config: cfg }, status: 201 };
  });
}

/** POST /hr/payroll/statutory/pt-slabs — upsert a per-state PT slab. */
export async function handleUpsertPtSlab(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const slab = parsePtSlab(body);
    const { id } = await upsertPtSlab(db, organizationId, schoolId, slab);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit(
        "hr.statutory.pt_slab.upserted",
        "statutory_pt_slab",
        `${slab.state}:${slab.lowerBound}:${slab.month ?? "all"}`,
        { state: slab.state, lowerBound: slab.lowerBound, amount: slab.amount, month: slab.month },
      ),
      request,
    );
    return { payload: { id, slab }, status: 201 };
  });
}

function requireHrRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewHr") ?? requireSchoolOperationalScope(claims);
}

/**
 * GET /hr/payroll/statutory/config?state=<code>
 *
 * Reads the configured component rules (central + the requested state) and that
 * state's PT slabs. This is the source of truth the deduction engine reads at
 * payroll generation.
 */
export async function handleGetStatutoryConfig(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireHrRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const state = (url.searchParams.get("state") ?? url.searchParams.get("jurisdiction") ?? "").trim();

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const configs = await listStatutoryConfigs(db, orgId, schoolId, state);
      const ptSlabs = state === "" ? [] : await listPtSlabs(db, orgId, schoolId, state);
      return { state, configs, ptSlabs };
    });
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("handleGetStatutoryConfig error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load statutory config", 500);
  }
}
