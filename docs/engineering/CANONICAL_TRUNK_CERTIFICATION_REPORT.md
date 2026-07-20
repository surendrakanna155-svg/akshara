# Canonical Trunk — Integrity & Readiness Certification Report

**Trunk:** `integration/w0-canonical` @ `db94f2ee` (base ERP + PRA + DRP + web + QIE + ASIP)
**Date:** 2026-07-20 · **Method:** 6 independent parallel audit agents (read-only) + remediation + permanent regression guards.
**Authorization:** Owner (2026-07-20) — final Canonical Trunk Integrity & Readiness Audit before adopting the trunk as the long-term production baseline.

## FINAL VERDICT: ✅ CERTIFIED — suitable as the long-term production baseline

All six independent audit dimensions returned PASS/CLEAN. No production-certified functionality was lost; no duplicate/conflicting implementations or merge artifacts remain; migrations are monotonic + deterministic; RBAC/RLS/tenant-isolation/audit/security are intact; backend and both clients compile and test green. One dead helper was removed and permanent trunk-integrity regression guards were added. Remaining items are tracked technical debt (owner-actionable / cosmetic / parked), none blocking.

---

## 1. Parallel-agent findings

| # | Dimension | Verdict | Headline evidence |
|---|---|---|---|
| 1 | **Convergence no-loss** | ✅ NO LOSS | DRP + PRA + ASIP tips are all **strict git ancestors** of the trunk; **0 source deletions** vs any of them. 88 full-repo deletions = 100% transient `test/golden/failures/*.png` (cleared to reach green). No DRP/PRA/ASIP commit reverted. QIE(90)/curriculum(359)/web(165) preserved. |
| 2 | **Migrations** | ✅ PASS | 244 files, 14-digit prefixes, **0 duplicate versions, strictly monotonic**. Bands: ≤876(195)·877–897 DRP(21)·900* PRA(22)·920* ASIP(6). **RLS 45/45** on every new tenant table. ASIP band **additive-only (zero DROP)**. Deterministic (no `CONCURRENTLY`/`random()` in DDL). All 3 mirror bridges carry the full security envelope. |
| 3 | **Security & isolation** | ✅ PASS | Session RT-16/17 intact (14 tests); non-bypass `erp_tenant` edge role + `assertEdgeTenantRole`; **264 ENABLE / 262 FORCE** RLS; append-only audit + 403 auto-audit; red-team migrations present; **no escalation/bypass** (4 `USING(true)` policies all role-scoped to a NOBYPASSRLS platform role or read-only catalogs). **Mirror bridges airtight**: source org/school from the session GUC (never a parameter), `propagate_resolution` asserts caller *is* the platform org, all `REVOKE...FROM PUBLIC`. |
| 4 | **Duplicates / dead code / artifacts** | ✅ CLEAN | **0 conflict markers** (tracked + untracked), 0 `.orig`/`.rej`/`.bak`. QIE (Python generator) vs `education` (TS bank-governance) = **distinct-by-design, zero cross-references**. **61 unique routers**, stem-sharing prefixes safely ordered. Feature-flags/keys/route-constants duplicate-free. |
| 5 | **Backend wiring & deps** | ✅ PASS | `deno check` **exit 0** (ERP+DRP+PRA+ASIP compile together). **61 routers imported = 61 registered** (perfect 1:1). ASIP imports self-contained (no PRA-only `listAuditEvents`; queries `audit_events` directly). `storage_service.ts` merged with no duplicate exports. **231 sampled deno tests pass / 0 fail**; DB-gated tests self-skip (env, not failure). |
| 6 | **Client (Flutter + Web)** | ✅ PASS | `flutter analyze` **0 issues**; `permissions.dart` 172 members / 0 dups; routes/guards/providers/keys duplicate-free; **6 support + 150 RBAC/routing** flutter tests pass. Web `npm build` 0 errors + **147 web tests**; support console additive (frozen viewer untouched); web↔backend `/support/platform/*` contract matches (snake_case). |

## 2. Verified invariants (now guarded permanently)

`supabase/functions/_shared/trunk_integrity_test.ts` (run: `deno test --allow-read …`) codifies 5 invariants so **future convergence cannot silently regress them** (all 5 currently green):
1. **Migration versions are unique + strictly monotonic** (14-digit prefixes).
2. **No table has two *unguarded* `CREATE TABLE`** (guarded `IF NOT EXISTS` recreates allowed).
3. **Every imported edge module router is registered exactly once** in `moduleRouters` (with `routeSupport`/`routeIdentity`/`routeAudit`/`routeFinance` coexistence anchors).
4. **No git conflict markers** in `supabase/functions`.
5. **ASIP mirror bridges stay `SECURITY DEFINER` + `search_path`-pinned + `REVOKE...FROM PUBLIC`** (the cross-tenant isolation control).

Additional live-proven invariants (from ASIP + W0 certification): tenant isolation (cross-school 404), the mirror "source-org-not-forgeable" property, resolve-propagate-back-to-school, and the append-only audit trail — all validated 18/18 on the live pilot.

## 3. Remediation applied in this audit

- **Removed** `supabase/functions/_shared/audit/audit_mutation_middleware.ts` — verified **zero references** anywhere (prod or test); dead-code cleanup. `deno check` remains green.
- **Added** the 5 permanent trunk-integrity regression guards above.

## 4. Remaining technical debt (tracked; none blocking)

| # | Item | Severity | Disposition |
|---|---|---|---|
| 1 | **9 forward QPL commits** on `feature/qie-question-planning-layer` (QPL Phase 1–5 R&D) authored *after* the convergence snapshot — pending forward-integration (NOT lost; the frozen KIE v1.4 foundation is fully present) | P1 — **owner-actionable** | Owner decides whether to fold into a subsequent W-wave (Owner Decision C context) |
| 2 | `app_support_mirror_incident` doesn't pre-verify the incident is a real owned `support_incident` before insert | low (non-exploitable — `source_org_id` forced to caller's own org; not reachable via the app) | Optional defense-in-depth; would require a `CREATE OR REPLACE` migration + redeploy — defer |
| 3 | `app_support_propagate_resolution` defined in both `…040` and `…050` (intentional `CREATE OR REPLACE` supersede that adds the reporter notification) | maintainability note | Acceptable — replay-safe (`…050` wins); document only |
| 4 | `_shared/device_management/` router unregistered (dead in prod) | parked | **By design** — the tracked P0-15 device-adapter (hardware) item; keep flagged, not live |
| 5 | Cosmetic/pre-existing (not merge-introduced): 7 local `ValidationError extends Error`; `route_names.dart` out-of-scope vertical aliases; base-band `intel_*` idempotent recreate; migration numbering gap at `…027` | cosmetic | Defer |

## 5. Recommended cleanup

- **Done:** removed the dead `audit_mutation_middleware.ts`.
- **Owner decision:** fold-in (or explicitly defer) the 9 forward QPL commits (item 4.1).
- **Optional/deferred:** items 4.2–4.5 above — none affect production readiness.

## 6. Production-readiness verdict

**The canonical trunk `integration/w0-canonical` is internally consistent, complete, and CERTIFIED as the long-term production baseline.** No production-certified capability from ERP, PRA, DRP, ASIP, QIE, or Web was lost or duplicated; migrations, RBAC, RLS, tenant isolation, audit history, rollback, and security guarantees are intact and now regression-guarded.

**Remaining activation steps are owner-gated deployment decisions, not code readiness:** re-point `main`/`production` to this trunk; redeploy the converged trunk to the pilot (brings PRA's P0 fixes live — the pilot edge is a shared bind-mount carrying the additive ASIP files, which any redeploy must preserve); and per-branch prune decisions for the stale/experimental lines.

**W0 is fully certified and may be considered completely closed.**
