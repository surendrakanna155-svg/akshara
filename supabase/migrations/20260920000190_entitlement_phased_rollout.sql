-- ICA-G2 (P1, Commercial) — Entitlement enforcement: phased, per-org rollout.
--
-- ── THE FINDING ──────────────────────────────────────────────────────────────
-- Backend entitlement enforcement (module 402 plan-gates + suspended-subscription
-- block + slab/SMS limits) was governed by a SINGLE global boolean env
-- (`ENTITLEMENT_ENFORCEMENT`, default OFF — entitlement_enforcement.ts). Every
-- 402 gate was therefore INERT until an operator flipped one global switch, and
-- flipping it turned enforcement on for ALL orgs at once — an all-or-nothing risk
-- with no way to validate one org, enable it, and watch, before the next.
--
-- ── THE FIX (owner decision G2: production-ready, config/flag-controlled, gradual) ─
-- A master MODE (env, default "off" — a kill-switch) PLUS this per-org flag:
--   * off        → enforce nowhere (default; exactly today's safe behavior).
--   * allowlist  → enforce ONLY for orgs whose `entitlement_enforcement_enabled`
--                  flag is true — the gradual, org-by-org rollout dial.
--   * all        → enforce everywhere (the eventual end state).
-- The edge resolves this via a single `isEntitlementEnforcedForOrg(orgId, db)`
-- (entitlement_enforcement.ts). An operator validates an org, flips its flag here,
-- and enforcement begins for that org alone — no redeploy, no restart.
--
-- DEFAULT = SAFE: the column defaults to FALSE and the master mode defaults to
-- "off", so on the certified trunk — with nothing configured — enforcement runs
-- NOWHERE, identical to pre-G2. Zero risk to the live pilot.
--
-- ── PRE-FLIP AUDIT (detect_orgs_missing_entitlement_plan) ─────────────────────
-- Before an operator enables enforcement for an org, they MUST confirm the org
-- actually has a real plan/subscription assigned — otherwise enforcement would
-- resolve it to the Trial fallback and 402 its paid modules. This detector returns
-- every ACTIVE org that has NO organization_subscriptions row, so the pre-flip
-- checklist is data-driven, not eyeballed.
--
-- POSTURE (mirrors the ICA-E2 / F5 detectors 20260920000160 / …180 and the D3
-- reaper …130): organizations is FORCE ROW LEVEL SECURITY, so a cross-tenant
-- sweep MUST run under the RLS-bypassing privileged owner role and MUST NOT be
-- reachable from the client `erp_tenant` edge role: SECURITY DEFINER + pinned
-- search_path + REVOKE ALL FROM PUBLIC. LANGUAGE sql, pure read-only SELECT — it
-- detects, it never mutates. (The per-org FLAG itself is read by the edge via the
-- existing `SELECT ON organizations` grant + the org's own RLS row; only this
-- cross-org AUDIT is privileged-ops-only.)
--
-- OPS INVOCATION (same ops-cron lane as the E2/F5 detectors — no pg_cron here):
--     docker exec <akshara-postgres> psql -U <admin> -d <db> \
--       -c "SELECT * FROM detect_orgs_missing_entitlement_plan();"
-- Any returned row = an org that must be assigned a plan (Step-4.5 admin screen)
-- BEFORE its entitlement_enforcement_enabled flag is set true.
--
-- Additive + idempotent (ADD COLUMN IF NOT EXISTS, CREATE OR REPLACE FUNCTION).
-- Safe to re-run.

-- ── Per-org rollout flag ──────────────────────────────────────────────────────
-- NOT NULL DEFAULT false: existing rows backfill to false (enforced nowhere) and
-- new orgs are created disabled — an org is only ever enforced after an operator
-- explicitly opts it in. The edge's existing `GRANT SELECT ON organizations TO
-- erp_tenant` covers this new column, and organizations_tenant_access RLS lets a
-- tenant read only its OWN org row, so the allowlist lookup is self-scoped.
ALTER TABLE organizations
  ADD COLUMN IF NOT EXISTS entitlement_enforcement_enabled BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN organizations.entitlement_enforcement_enabled IS
  'ICA-G2 phased-rollout per-org switch. When the master mode '
  '(ENTITLEMENT_ENFORCEMENT_MODE) is "allowlist", backend entitlement enforcement '
  '(402 plan-gate + suspended-subscription block + slab/SMS limits) applies to this '
  'org ONLY when this flag is true. Default false = not enforced. Flip true only '
  'AFTER confirming the org has a real plan (detect_orgs_missing_entitlement_plan()).';

-- ── Pre-flip audit: active orgs with NO plan/subscription assigned ────────────
CREATE OR REPLACE FUNCTION detect_orgs_missing_entitlement_plan()
  RETURNS TABLE (
    organization_id   uuid,
    organization_name text,
    organization_slug text,
    enforcement_enabled boolean
  )
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
  -- Active (non-deleted) orgs that have NO organization_subscriptions row. Such an
  -- org would resolve to the Trial fallback under enforcement and 402 its paid
  -- modules, so it must be assigned a real plan before its flag is flipped true.
  -- enforcement_enabled is surfaced so an operator can immediately see the danger
  -- case: a missing plan on an org whose flag is ALREADY true.
  SELECT o.id, o.name, o.slug, o.entitlement_enforcement_enabled
    FROM organizations o
    LEFT JOIN organization_subscriptions os ON os.organization_id = o.id
   WHERE o.deleted_at IS NULL
     AND os.organization_id IS NULL
   ORDER BY o.name;
$fn$;

-- Cross-tenant integrity/audit sweep: privileged ops role only, never the tenant edge.
REVOKE ALL ON FUNCTION detect_orgs_missing_entitlement_plan() FROM PUBLIC;

COMMENT ON FUNCTION detect_orgs_missing_entitlement_plan() IS
  'ICA-G2 pre-flip audit. Returns every active organization (deleted_at IS NULL) '
  'with NO organization_subscriptions row — i.e. no real plan assigned — plus its '
  'current entitlement_enforcement_enabled flag. Run BEFORE enabling per-org '
  'entitlement enforcement: any returned row must first be assigned a plan (Step-4.5 '
  'assign screen), otherwise enforcement would 402 its paid modules via the Trial '
  'fallback. SECURITY DEFINER so it sweeps across tenants past FORCE RLS; '
  'PUBLIC-revoked so only the privileged ops role runs it. Zero rows = every active '
  'org has a plan and is safe to enable. OPS: run on the ops-cron lane under the '
  'privileged DB role, e.g. `docker exec <akshara-postgres> psql -U <admin> -d <db> '
  '-c "SELECT * FROM detect_orgs_missing_entitlement_plan();"`.';
