# EOS Finding — Phase B · Live `/health/tenant-access` 503 (tenant-isolation self-check)

**Date:** 2026-07-01 · **Discovered during:** Track B B2 (edge live verification) · **HEAD:** `681d269` · **Scope:** tenant isolation self-check (relates to B7 / `QA-R-003/004/008`).
**Governing law:** Constitution Part 7B (*Automatic Failure Conditions* — tenant-isolation) + Part 4B (RLS). **Verdict anchor:** evidence over opinion — every classification cites `file:line`.

## Summary verdict

The live `GET /health/tenant-access` returns **503 `degraded`** because its in-edge RLS self-check reports `isolation.pass=false`: **23 of 233 probes fail, deterministically** (identical set across repeated runs). Full per-probe analysis (with RLS migration + probe-source citations) finds:

- **REAL data-exposure defects: 0.** No probe shows any scope reading another family's, school's, or org's rows. **All ~40 cross-tenant probes pass** — the hard tenant boundary is intact.
- **REAL own-data lockouts: 0.**
- **19 = PROBE/DESIGN MISMATCH** — stale probe expectations that contradict RLS grants deliberately shipped + certified in later migrations.
- **4 = SEED/FIXTURE GAP** — branding/config/subscription probes whose own-data fixture rows are inserted by no migration (RLS itself is correct).
- **Highest real severity: P2.** No P0/P1. **Not GA-blocking as a defect** — but the 503 is a false-red that will fail B7 live cert + the B12 regression cron and pollutes production monitoring, so it must be cleared before those waves close.

## Root cause

The probe suite (`tenant_isolation_probes.ts`, long-standing since 2026-06-09) hard-codes `*_denied_*` / `*_sees_own_*` expectations. Three newer, **intentional** RLS changes were never reflected back into those expectations:
- `20260707000000_director_portal.sql` — Director **org-scope rollup reads** (students, leads, invoices, collections, enrollments, conversions).
- `20260704000000_parent_student_finance_read_rls.sql` — parent/student **own-child** money-loop finance reads (per-child predicate `student_id IN (student_guardians…)`).
- `20260703100000_parent_student_exam_read_rls.sql` — parent/student **own-child** exam/enrollment reads.
Plus 4 QW8-era probes (2026-06-30, branding/config/subscription) whose `e1…/e2…/e3…` fixture rows were never seeded.

## Classification (23 failing probes)

| # | Probe (live detail) | Class | Sev | Evidence |
|---|---|---|:--:|---|
| 1 | org_scope_denied_raw_students (=5) | MISMATCH | none | `students_director_org_read` intended org read — `20260707000000_director_portal.sql:162` vs probe `tenant_isolation_probes.ts:421` |
| 2 | org_scope_denied_raw_admissions_leads (=5) | MISMATCH | none | `admissions_leads_director_org_read` — `20260707000000:186` |
| 3 | organization_denied_finance_invoices (=2) | MISMATCH | none | `finance_invoices_director_org_read` — `20260707000000:174` |
| 4 | parent_denied_finance_invoices (=1) | MISMATCH | none | own-child read `20260704000000_...rls.sql:15` (count=1 = own child) |
| 5 | student_denied_finance_invoices (=1) | MISMATCH | none | `20260704000000_...rls.sql:29` (`student_id=app_current_student_id()`) |
| 6 | organization_denied_collections (=8) | MISMATCH | none | `finance_collections_director_org_read` — `20260707000000:180` |
| 7 | parent_denied_collections (=7) | MISMATCH | none | per-child `20260704000000_...rls.sql:38` (all own child's) |
| 8 | student_denied_collections (=7) | MISMATCH | none | `20260704000000_...rls.sql:52` |
| 9 | parent_denied_daily_summary (=1) | MISMATCH | none | counts own-child invoice — `20260704000000_...rls.sql:15` |
| 10 | student_denied_daily_summary (=1) | MISMATCH | none | own invoice — `20260704000000_...rls.sql:29` |
| 11 | student_denied_finance_dashboard (=1) | MISMATCH | none | own invoice — `20260704000000_...rls.sql:29` |
| 12 | approved_refund_updates_balances (44500 vs 47000) | MISMATCH (live-data drift) | **P2** | seed 47000 `20260612600000_finance_slice5_refunds.sql:92`; live −2500 real payment on invoice `b9000000…01`; probe asserts static seed on a mutating table `tenant_isolation_probes.ts:956` — **verify the payment is legitimate** |
| 13 | organization_denied_sis_enrollments (=3) | MISMATCH | none | `sis_student_enrollments_director_org_read` — `20260707000000:168` |
| 14 | parent_denied_sis_enrollments (=1) | MISMATCH | none | own-child `20260703100000_...rls.sql:22` |
| 15 | student_denied_sis_enrollments (=1) | MISMATCH | none | `20260703100000_...rls.sql:36` |
| 16 | organization_denied_sis_enrollments_api (=3) | MISMATCH | none | JOIN both org-readable — `20260707000000:162,168` |
| 17 | parent_denied_sis_enrollments_api (=1) | MISMATCH | none | own-child JOIN — `20260703100000_...rls.sql:22` + `20260609100000_phase2_rls_scope.sql:256` |
| 18 | student_denied_sis_enrollments_api (=1) | MISMATCH | none | own — `20260703100000_...rls.sql:36` + `20260609100000:266` |
| 19 | organization_denied_admissions_conversion (=1) | MISMATCH | none | org-read students+enrollments — `20260707000000:162,198` |
| 20 | school_a_sees_own_branding (=0) | SEED GAP | **P2** | RLS OK `20260624000000_school_completion_foundation.sql:102`; fixture `e1000000…01` seeded by no migration; probe `tenant_isolation_probes.ts:2105` |
| 21 | school_a_sees_own_configuration (=0) | SEED GAP | **P2** | RLS OK `20260714000000_school_configuration.sql:47`; fixture `e2…01` unseeded; probe `:2123` |
| 22 | org_a_sees_own_subscription (=0) | SEED GAP | **P2** | RLS OK `20260717100000_organization_subscriptions.sql:109`; fixture `e3…a1` unseeded; probe `:2144` |
| 23 | school_a_sees_own_org_subscription (=0) | SEED GAP | **P2** | same table/policy `20260717100000:109`; fixture absent; probe `:2152` |

## Recommended remediation (test/health-harness, not RLS)

1. **19 MISMATCH probes** — update the expected counts (or retire as superseded by the passing `*_cannot_see_*` cross-tenant probes) to match the **certified** director-org + parent/student own-child read policies. ⚠ This is a **security-posture ratification** of already-shipped RLS — recommend owner sign-off before editing the isolation cert suite.
2. **4 SEED-GAP probes** — add the missing `e1/e2/e3…` fixture rows (or have the probe insert them in its rolled-back txn, as sibling probes do). Pure test hygiene; strengthens the suite.
3. **Probe 12** — confirm the live −2500 payment on invoice `b9000000…01` is a legitimate transaction, then make the probe tolerant of live mutation.
4. Re-run `/health/tenant-access` → expect **200** (`isolation.pass=true`), unblocking B7 live cert + the B12 regression cron.

## Gate impact

`QA-R-012` GA gate: **unchanged (still BLOCKED on infra)**. This finding adds **no P0/P1**; it is P2 harness/health-hygiene that must clear before **B7** and **B12** report green. No product behaviour or RLS policy is changed by the recommended fix.

---

## RESOLUTION — 2026-07-01 (commit `20ae776`, owner-approved)

**Fixed and verified live. `/health/tenant-access` → 200, `isolation.pass=true`, 233/233 probes pass** (0 failures; re-checked after deploy).

- **18 scope over-read probes** — rewrote each stale "denied ALL rows" assertion to "denied OTHERS' rows" (`WHERE organization_id <> ORG` / `WHERE student_id <> STUDENT_A`, still `=== 0`). This is a **stronger** invariant: it proves each scope sees *nothing outside its own boundary* (with ~5 students + multiple schools seeded, a real leak is caught) — matching the certified director-org-rollup + parent/student own-child RLS.
- **Probe 12** (`approved_refund_updates_balances`) — asserts the invoice↔student-account balance-coupling invariant (`0 ≤ outstanding ≤ total`, coupled) instead of a hardcoded ₹47,000; survives live pilot activity, still catches a broken refund.
- **4 own-data probes** (branding/config/subscription) — assert by **natural key** (`school_id`/`organization_id`), not a synthetic fixture id. Live check showed config + subscription rows already exist for the probe SCHOOL_A/ORG; only the **branding** row was missing, seeded by `supabase/migrations/20260819000000_isolation_probe_branding_config_subscription_seed.sql` (idempotent `NOT EXISTS`, brand-new row). **The agent's original re-key-of-live-PKs migration was rejected** in favour of this non-mutating approach.

**Deploy:** probe file → `/opt/akshara/functions/_shared/`, `build_info.json` refreshed to HEAD, `docker restart akshara-edge`. `deno check` clean. No RLS policy or product behaviour changed. **B7 live-isolation health signal + B12 cron are no longer blocked by this.**
