// ICA-B3 regression guard (P1, Security) — in-DB guardrails on the onboarding /
// subscription SECURITY DEFINER functions.
//
// These three functions bypass RLS (SECURITY DEFINER, granted to erp_tenant), so
// their in-DB scope guards are load-bearing. This is a PERMANENT static invariant:
// it locates the LATEST migration that (re)defines each function and asserts the
// guard predicates are still present — so a future migration that recreates one
// of them WITHOUT the guard (drift) fails CI here rather than silently in prod.
//
// Pure file scan (no DB, no network). Run with:
//   deno test --allow-read supabase/functions/_shared/onboarding_secdef_guard_test.ts

import { assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

const HERE = new URL(".", import.meta.url); // supabase/functions/_shared/
const MIGRATIONS = new URL("../../migrations/", HERE); // supabase/migrations/

function migrationFiles(): string[] {
  const names: string[] = [];
  for (const e of Deno.readDirSync(MIGRATIONS)) {
    if (e.isFile && e.name.endsWith(".sql")) names.push(e.name);
  }
  // Ascending version order (14-digit numeric prefix); the LAST match wins.
  return names.sort();
}

/**
 * Returns the body of the LATEST `CREATE OR REPLACE FUNCTION <fnName>(...)` across
 * all migrations — from the CREATE keyword through the closing `$$;` of the
 * plpgsql body. Files are scanned in version order so a later redefinition
 * supersedes an earlier one (exactly how Postgres applies them).
 */
function latestDefinition(fnName: string): { file: string; body: string } {
  let latest: { file: string; body: string } | null = null;
  const marker = `CREATE OR REPLACE FUNCTION ${fnName}(`;
  for (const f of migrationFiles()) {
    const sql = Deno.readTextFileSync(new URL(f, MIGRATIONS));
    const start = sql.indexOf(marker);
    if (start < 0) continue;
    const end = sql.indexOf("$$;", start);
    assert(end > start, `${f}: could not find the $$; body terminator for ${fnName}`);
    latest = { file: f, body: sql.slice(start, end + 3) };
  }
  assert(latest, `no CREATE OR REPLACE FUNCTION found for ${fnName}`);
  return latest;
}

function countRaises(body: string): number {
  return (body.match(/RAISE\s+EXCEPTION/gi) ?? []).length;
}

// Every guarded definition must keep the SECURITY DEFINER + pinned search_path
// posture and fail closed with RAISE EXCEPTION.
function assertSecurityPosture(fnName: string, body: string) {
  assert(/SECURITY DEFINER/.test(body), `${fnName}: lost SECURITY DEFINER`);
  assert(/SET search_path\s*=\s*public/.test(body), `${fnName}: lost pinned search_path`);
  assert(countRaises(body) >= 1, `${fnName}: has no RAISE EXCEPTION (must fail closed)`);
}

Deno.test("ICA-B3: onboarding_ensure_school_membership has tenant/school scope guard + role allowlist", () => {
  const { fnName, body } = {
    fnName: "onboarding_ensure_school_membership",
    ...latestDefinition("onboarding_ensure_school_membership"),
  };
  assertSecurityPosture(fnName, body);

  // Tenant boundary re-derived from the session GUC + verified against schools.
  assert(/app_current_tenant_id\(\)/.test(body), `${fnName}: missing app_current_tenant_id() guard`);
  assert(/FROM\s+schools/i.test(body), `${fnName}: missing schools-table tenant-ownership check`);
  assert(/organization_id\s*=\s*v_tenant/.test(body), `${fnName}: school not checked against caller tenant`);
  // Session-school match (school GUC is proven set in the onboarding path).
  assert(/app_current_school_id\(\)/.test(body), `${fnName}: missing app_current_school_id() session-school guard`);

  // Explicit role allowlist that blocks privilege-escalation slugs. Isolate the
  // `v_role NOT IN ( ... )` tuple so the check inspects the allowlist itself, not
  // the surrounding explanatory comment.
  const allow = body.match(/v_role\s+NOT\s+IN\s*\(([\s\S]*?)\)/i);
  assert(allow, `${fnName}: missing explicit role allowlist (v_role NOT IN ...)`);
  const allowlist = allow[1];
  for (const role of ["'teacher'", "'principal'", "'schoolAdmin'"]) {
    assert(allowlist.includes(role), `${fnName}: allowlist must include the importer role ${role}`);
  }
  // Escalation roles must NOT be assignable through onboarding.
  for (const bad of ["superAdmin", "organizationOwner", "organizationAdmin", "schoolGroupDirector"]) {
    assert(!allowlist.includes(`'${bad}'`), `${fnName}: escalation role '${bad}' must not be in the allowlist`);
  }
  // A dedicated tenant/scope RAISE and a role RAISE (>=2 fail-closed branches).
  assert(countRaises(body) >= 2, `${fnName}: expected >=2 RAISE branches (scope + role), found ${countRaises(body)}`);
});

Deno.test("ICA-B3: onboarding_upsert_user_by_phone requires an authenticated tenant session", () => {
  const fnName = "onboarding_upsert_user_by_phone";
  const { body } = latestDefinition(fnName);
  assertSecurityPosture(fnName, body);

  // Global-identity table → the safe guardrail is a session-context check that
  // fails closed. It must appear BEFORE the users mutation.
  assert(/app_current_tenant_id\(\)\s+IS\s+NULL/i.test(body), `${fnName}: missing 'app_current_tenant_id() IS NULL' fail-closed guard`);
  const guardIdx = body.search(/app_current_tenant_id\(\)\s+IS\s+NULL/i);
  const updateIdx = body.search(/UPDATE\s+users/i);
  const insertIdx = body.search(/INSERT\s+INTO\s+users/i);
  assert(guardIdx >= 0 && guardIdx < updateIdx, `${fnName}: session guard must precede the UPDATE users`);
  assert(guardIdx >= 0 && guardIdx < insertIdx, `${fnName}: session guard must precede the INSERT INTO users`);
});

Deno.test("ICA-B3: assign_organization_subscription binds actor to session + validates target org", () => {
  const fnName = "assign_organization_subscription";
  const { body } = latestDefinition(fnName);
  assertSecurityPosture(fnName, body);

  // Authenticated session + actor binding (the cross-org op must never trust a
  // forged p_actor) + real, non-deleted target org.
  assert(/app_current_user_id\(\)/.test(body), `${fnName}: missing app_current_user_id() session guard`);
  assert(/p_actor\s+IS\s+DISTINCT\s+FROM/i.test(body), `${fnName}: missing p_actor↔session actor binding`);
  assert(/FROM\s+organizations/i.test(body), `${fnName}: missing target-organization existence check`);
  // Must NOT tie the target org to the caller's tenant (cross-org is by design).
  assert(
    !/p_organization_id\s*=\s*app_current_tenant_id\(\)/.test(body),
    `${fnName}: p_organization_id must NOT be pinned to app_current_tenant_id() (cross-org assignment is legitimate)`,
  );
  assert(countRaises(body) >= 3, `${fnName}: expected >=3 RAISE branches (session + actor + org), found ${countRaises(body)}`);
});
