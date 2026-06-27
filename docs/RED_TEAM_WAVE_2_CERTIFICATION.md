# AKSHARA — Red Team Wave 2 Certification

**Status:** ✅ **PRODUCTION CERTIFIED (2026-06-27) — live 25/25** · **Wave 1 regression re-cert: 26/26**
**Wave:** RED_TEAM **Wave 2** — "Tenant & Privacy Isolation (Row-Level Security)."
**Scope source of truth:** [`RED_TEAM_MASTER_TRACKER.md`](./RED_TEAM_MASTER_TRACKER.md) (RT-09..RT-15) + [`RED_TEAM_COMPLETION_ROADMAP.md`](./RED_TEAM_COMPLETION_ROADMAP.md) (Wave 2). No new features, no roadmap expansion, no new audit — this closes the tracker's Wave-2 findings only.
**Branch:** `feature/scope-trim-school-build`
**Migration:** `20260815000000_red_team_wave2_tenant_privacy_rls.sql` (applied + ledgered on the live DB)
**Live cert:** `scripts/qa/live_cert_red_team_wave2.py` → **25/25** against the live VPS pilot, evaluated under the unprivileged **`erp_tenant`** role (the exact role the edge runs as) with the per-request tenant GUCs (`app.scope` / `app.school_id` / `app.parent_user_id` …) set the same way `withTenantContext` sets them, inside rolled-back transactions.

---

## 1. Verdict

**PRODUCTION CERTIFIED.** All **7 Wave-2 findings** (1 Critical, 3 High, 1 Medium, 1 Medium-downgraded, 1 Low) are closed at the database layer and verified on the live DB. These are the *tenant-isolation* gaps: a set of tables whose RLS gated only `organization` + `school` but **not the acting persona**, so under `parent`/`student` scope one family could read or write another family's data, or one school could pollute a sibling school's audit trail within the same org.

This is a **pure RLS-hardening** wave — one migration, no edge-function or Dart changes. Every fix **replaces** an over-broad policy with a stricter one that keeps the legitimate caller working (verified against the live edge handlers) while denying the exact cross-tenant vector each finding reproduced live. The canonical per-child predicate mirrors the already-certified `20260725000000_parent_insights_parent_scope_rls.sql` (Parent Insights / B3) and `20260609100000` (`students_scope_access`): a parent may only touch rows for students linked to them via an **active** `student_guardians` row.

**Why this wave matters now:** the reproduction pass confirmed these leaks are real but *latent* on the single-family pilot. They had to land **before a second family is onboarded** — multi-family onboarding was the hard deadline. That deadline is now met.

## 2. Gate results

| Gate | Result |
|------|--------|
| `flutter analyze` | **0 issues** (no Dart changed; gate re-run for safety) |
| `flutter test` | **2440 passed / 1 skipped / 0 failed** |
| `deno test` (`supabase/functions`) | **860 passed / 0 failed / 2 ignored** |
| Live cert (`live_cert_red_team_wave2.py`) | ✅ **25/25** vs live VPS pilot |
| **Regression — Wave 1 re-cert** (`live_cert_red_team_wave1.py`) | ✅ **26/26** (no RT-01..08 regressed) |

The live cert is the authoritative gate.

## 3. Methodology — how the RLS is actually proven

Unlike Wave 1 (transactional integrity, proven over HTTP), Wave 2's unit-under-test is the **database policy itself**. The cert therefore probes RLS directly under the live `erp_tenant` role (`rolsuper=f`, `rolbypassrls=f` — confirmed live), so policies are genuinely enforced. Each probe runs in a single transaction that (1) optionally seeds a fixture row as the superuser, (2) `SET LOCAL ROLE erp_tenant` + sets the persona GUCs, (3) attempts the read/write, (4) `ROLLBACK`s. Nothing is committed; the script is re-runnable and leaves the live DB untouched. **This is the same rolled-back-probe method that originally reproduced RT-09..14** (see `RED_TEAM_REPRODUCTION_REPORT.md`), so before/after is apples-to-apples.

**Pre-fix baseline captured live (leaks reproduced):**
- RT-09 — a **non-guardian** parent reading child `a4…001`'s academic summary → **1 row** (leak).
- RT-14 — a **school-A** context inserting a `domain_events` row tagged **school-B** → **`INSERT … 1`** (allowed).

After the migration, both return the secure result (0 rows / denied) while the legitimate caller is unaffected.

## 4. Headline live evidence (post-fix, 25/25)

| RT | Finding | Live proof |
|---|---|---|
| **RT-09** (Crit) | Parent academic summaries — cross-family PII | Real guardian reads own child's summary → **1**; **non-guardian** parent reads same child → **0** (leak closed). Policy `parent_academic_summaries_access` carries the `student_guardians` pin in both `USING` and `WITH CHECK`. |
| **RT-11** (High) | Parent meeting summaries — cross-family leak | Parent scope reads meeting summaries → **0**; staff (school scope) still reads → **1**. (No parent-facing surface exists; restricting to school scope fully closes the leak.) |
| **RT-12** (High) | Communication Hub — read/post into any thread | Owning parent reads its own thread message → **1**; **non-participant** parent reads the private thread → **0**; non-participant parent **INSERT** into the thread → **`new row violates row-level security policy`** (injection blocked). Mirrors the correct sibling `comm_threads_participant`. |
| **RT-13** (High) | School Memories — parent/student can write | Parent **SELECT** still works (read intentionally open); parent **INSERT** → **RLS denied**; staff INSERT → **1**. Split into `school_memory_events_read` (school/parent/student) + `school_memory_events_write` (school only), ×3 tables. |
| **RT-10** (Med) | Parent engagement snapshots — cross-parent metric leak | Parent scope reads engagement snapshots → **0**; staff (school scope) reads → **1**. Restricted to school scope (only staff dashboards, gated `viewPilotDashboard`, read it). |
| **RT-14** (Med) | `domain_events` — within-org cross-school pollution | School-A context INSERT tagged **school-B** → **RLS denied**; same-school INSERT → **1**. `domain_events_school_insert`/`_update` now pin `school_id` for per-school scopes; `organization` scope stays org-wide (preserves the `publishPendingDomainEvents` outbox drain). Persona-scope audit (B3) retained, now pinned to the caller's own school. |
| **RT-15** (Low) | Platform secret vault — defense-in-depth | `platform_secret_vault` now `relrowsecurity=t` + `relforcerowsecurity=t` with a `platform_secret_vault_deny_all` (`USING(false) WITH CHECK(false)`) policy; `erp_tenant` read → **`permission denied`** (no grant **and** deny-all). Was a false-positive for current exploitability; closed as belt-and-braces. |

## 5. What was fixed (per finding)

- **RT-09** — `parent_academic_summaries_scope` → `parent_academic_summaries_access`: adds the guardian-pin for `parent` scope (school scope keeps full access) on both `USING` and `WITH CHECK`. The edge already calls `assertParentChildAccess`; this is the DB last line of defence and also gates the generate-on-read UPSERT.
- **RT-10** — `parent_engagement_scope`: restricted to `school` scope; `parent`/`student` denied entirely (no parent-facing reader exists).
- **RT-11** — `parent_meeting_summaries_scope`: restricted to `school` scope. (If a parent surface is ever added, swap to the RT-09 guardian-pin predicate — noted in the migration.)
- **RT-12** — `comm_messages_thread`: a `parent` may only touch messages whose `comm_threads` row they participate in (`parent_user_id = app_current_user_id()`), enforced in `USING` **and** `WITH CHECK`; school scope keeps full access.
- **RT-13** — the three `school_memory_*_school` `FOR ALL` policies (which had no `WITH CHECK`, so the broad `USING` doubled as the write check) are each split into a broad **read** policy (school/parent/student) and a school-only **write** policy.
- **RT-14** — `domain_events_school_insert`/`_update` `WITH CHECK` now pins `school_id = app_current_school_id()` for `school`/`parent`/`student` scope; `organization` scope keeps unrestricted `school_id` for the org-wide outbox drain. No-op for every legitimate emit (`enqueueDomainEvent` always writes `school_id = claims.school_id`), a hard stop for a forged `school_id`.
- **RT-15** — `platform_secret_vault`: `ENABLE` + `FORCE` RLS and a deny-all policy, so even if a grant is ever added by mistake no tenant role can read the encrypted secrets.

## 6. Regression matrix (mandatory)

Per the engagement rules, before certifying Wave 2 the previously-certified wave was re-run live:

| Re-run | Result |
|---|---|
| **Wave 1** (`live_cert_red_team_wave1.py`, RT-01..08) | ✅ **26/26** — no regression |

No previously-Closed RT issue regressed. The RLS hardening touches only the named tables' policies; the Wave-1 constraints (unique indexes, CHECK, idempotency store, row locks) are untouched and re-verified live.

## 7. Cert-script note

One probe assertion was self-corrected during the run: `relrowsecurity::text` renders psql's boolean as `'true'` (not `'t'`), so the RT-15 enable/force check compared against `'truetrue'`. This was a cert-script-only false negative (the flags were correct live: `t | t`); fixed, and the final run is a clean **25/25**.

## 8. Disposition

RT-09, RT-10, RT-11, RT-12, RT-13, RT-14, RT-15 → **Closed** (fixed, deployed to the live VPS pilot, live-certified 25/25, Wave-1 regression 26/26). Migration `20260815000000_red_team_wave2_tenant_privacy_rls.sql` applied and ledgered on the live DB. Commit hash recorded in `RED_TEAM_MASTER_TRACKER.md` on commit.

**Waves 3–5 remain Open, awaiting owner approval. Wave 3 is NOT started.**
