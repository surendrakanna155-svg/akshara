# AKSHARA — Red Team Reproduction Report

**Date:** 2026-06-27
**Branch / HEAD:** `feature/scope-trim-school-build` @ `4f7f821`
**Environment:** Live VPS pilot (`root@46.28.44.46`) — `akshara-edge` (up), `akshara-postgres` (`akshara_db`), via the owner-opened SSH control socket. DB probed as the real **`erp_tenant`** role (`rolsuper=f, rolbypassrls=f`), so RLS was faithfully enforced.
**Companion to:** [`RED_TEAM_CERTIFICATION_AUDIT.md`](./RED_TEAM_CERTIFICATION_AUDIT.md) · [`RED_TEAM_VALIDATION_REPORT.md`](./RED_TEAM_VALIDATION_REPORT.md) · tracked in [`RED_TEAM_MASTER_TRACKER.md`](./RED_TEAM_MASTER_TRACKER.md)

> **Nothing was fixed, deployed, committed, or certified.** No production data was modified. Every live write/leak probe ran inside a `BEGIN … ROLLBACK` transaction (or was a pure read / env check), so **zero rows persisted**. Findings that can only be reproduced by committing destructive data (duplicate money rows, audit injection, approval cancel, marks corruption) or by load-testing were **deliberately not triggered** — they are recorded with live *enabling-condition* evidence and STATIC classification instead.

---

## Safety policy applied

| Probe type | Ran live? | Why |
|---|---|---|
| Read-only schema / constraint / policy / grant queries | ✅ Yes | Non-destructive |
| RLS leak/write probes wrapped in `BEGIN … ROLLBACK` (as `erp_tenant`) | ✅ Yes | Observes the defect; persists nothing |
| Container env-var reads (`docker exec … env`) | ✅ Yes | Read-only |
| Committing duplicate payments / corrupt marks / injected audit rows | ❌ No | Would corrupt real pilot data |
| Calling write endpoints (cancel approval, audit batch, payment intents) | ❌ No | Mutates / injects production state |
| Connection-exhaustion load test | ❌ No | Would DoS the live box |

---

## Classification summary

Each issue is classified as exactly one of **VERIFIED LIVE / VERIFIED TEST / STATIC ONLY / NOT REPRODUCIBLE**.

| Classification | Count | Issues |
|---|---|---|
| **VERIFIED LIVE** (defect or precondition observed on the live system) | **7** | RT-09, RT-10, RT-11, RT-12, RT-13, RT-14, RT-23 |
| **VERIFIED TEST** (an existing automated test reproduces it) | **0** | — (the 4 Patrol red-team suites cover only client route-guards/happy-paths) |
| **STATIC ONLY** (code/schema-confirmed; safe live repro not possible without destructive commit) | **25** | RT-01, RT-02, RT-03, RT-04, RT-05, RT-06, RT-07, RT-08, RT-16, RT-17, RT-19, RT-20, RT-21, RT-22, RT-24, RT-25, RT-26, RT-27, RT-29, RT-30, RT-31, RT-32, RT-33, RT-34, RT-35 |
| **NOT REPRODUCIBLE** (mitigated live, or mechanism refuted) | **3** | RT-15 (mitigated), RT-18 (flag ON live), RT-28 (mechanism refuted) |

Of the 25 STATIC ONLY, **8 had their enabling condition confirmed against the live DB/config** (RT-01, RT-02, RT-03, RT-04, RT-05, RT-08, RT-32, RT-35) — the missing/present constraint, column type, or connection setting was read off production; only the destructive *trigger* was withheld for safety.

---

## Category A — Write-path (live schema confirmation)

Read off the **live** `akshara_db` (`pg_constraint`, `pg_indexes`, `information_schema`):

| RT | Live finding | Verdict |
|---|---|---|
| RT-01 | `finance_collections`: PK on `id`, plain `idx_finance_collections_invoice` only; **no unique on `invoice_id`**; CHECK `amount_collected>0` exists (doesn't dedupe) | STATIC ONLY · enabling condition **live-confirmed** |
| RT-02 | `student_profiles`: `UNIQUE(student_id)` + **non-unique** `idx_student_profiles_school_admission`; **no unique on `(school_id, admission_number)`** | STATIC ONLY · enabling condition **live-confirmed** |
| RT-03 | `students`: `UNIQUE(school_id, student_code)` **present** → integrity protected; concurrent create yields a 500, not a dup | STATIC ONLY · constraint **live-confirmed present** |
| RT-04 | `attendance_corrections` PK `(organization_id, school_id, id)` | STATIC ONLY · live-confirmed |
| RT-05 | `exam_sessions` PK `(organization_id, school_id, id)` | STATIC ONLY · live-confirmed |
| RT-06 | snapshot lost-update (read-modify-write, no `FOR UPDATE`) — not safely reproducible without a real concurrent commit | STATIC ONLY |
| RT-07 | no idempotency-key consumption in `runWrite`; no `(school_id, phone)` unique on leads | STATIC ONLY |
| RT-08 | `exam_mark_entries`: `marks_obtained INTEGER`, only UNIQUE+FKs, **no CHECK** bounding the value | STATIC ONLY · enabling condition **live-confirmed** |

The destructive reproduction (committing a duplicate collection / corrupt mark) was **not** performed on the live pilot. The absence of the backing constraint — the entire root cause — is confirmed on production.

---

## Category B — Tenant & privacy isolation (VERIFIED LIVE)

All probes ran as `erp_tenant` with `app.set_request_context(...)`, inside `BEGIN … ROLLBACK`. **RLS is enabled AND forced** on every flagged table (confirmed live).

### RT-09 — cross-child academic PII read — **VERIFIED LIVE**
- Live policy: `parent_academic_summaries_scope` = `USING (organization_id = app_current_tenant_id() AND school_id = app_current_school_id())`, **WITH CHECK = none**.
- Probe (read-only): set context as `parent` user `a3…001` — **who is not the guardian** (`a3…003`) of student `a4…001` — then `SELECT … WHERE student_id='a4…001'`.
- **Result:** `rows_visible_to_nonguardian_parent = 1`. A parent who is not the child's guardian read the child's academic summary. Cross-family PII read confirmed.

### RT-10 — cross-parent engagement-metric read — **VERIFIED LIVE**
- Same weak policy on `parent_engagement_snapshots` (keyed by `parent_user_id`).
- Probe: insert a synthetic snapshot for parent `a3…004` (score 99), read as parent `a3…001`.
- **Result:** `other_parent_rows_visible = 1, leaked_score = 99`. (Staff-metric data, not child PII → lower sensitivity, but the leak is real.)

### RT-11 — cross-child meeting-summary read — **VERIFIED LIVE**
- Same weak policy on `parent_meeting_summaries`.
- Probe: insert a synthetic meeting summary for `student_id='FOREIGN-CHILD-X'`, read as unrelated parent `a3…001`.
- **Result:** `foreign_meeting_rows_visible = 1`. Cross-family meeting-summary leak confirmed.

### RT-12 — cross-family message read/write — **VERIFIED LIVE (most serious)**
- Live: `comm_messages_thread` checks `tenant + school + scope` but **not thread participation**; the sibling `comm_threads_participant` correctly checks `parent_user_id = app_current_user_id()`.
- Probe: insert a foreign thread owned by parent `a3…004` + a private message, read as parent `a3…001`.
- **Result:**
  - `comm_messages` (broken): `foreign_thread_msgs_visible = 1, leaked_body = "PRIVATE-MSG-FOR-FAMILY-B"` — parent A read parent B's private message.
  - `comm_threads` (correct): `foreign_thread_rows_visible = 0` — the foreign thread itself is correctly hidden.
- The side-by-side proves the gap is specifically the `comm_messages` policy (the correct pattern exists one table over).

### RT-13 — parent writes school-wide memory — **VERIFIED LIVE**
- Live: `school_memory_events_school` `USING (… AND scope IN ('school','parent','student'))`, **no WITH CHECK**; `erp_tenant` holds INSERT.
- Probe: as `parent` scope, `INSERT INTO school_memory_events(… category='other', visibility='school')`.
- **Result:** `INSERT 0 1` — **`parent-scope INSERT into school-wide memory ALLOWED by RLS`** (rolled back). (A first attempt with an invalid `category` failed on the domain CHECK *after* passing RLS — itself proof RLS did not block it.)

### RT-14 — within-org cross-school event injection — **VERIFIED LIVE**
- Live: `domain_events_school_insert` / `audit_events_tenant_insert` WITH CHECK pin only `organization_id` (not `school_id`).
- Probe: `school` scope for school `a2…001`, `INSERT INTO domain_events(… school_id='a2…002')` (a *different* school in the same org).
- **Result:** `INSERT 0 1` — **`school-A context wrote domain_events for school-B ALLOWED`** (rolled back).

### RT-15 — platform secret tables — **NOT REPRODUCIBLE (mitigated, confirmed live)**
- Live: all `platform_*` tables have `relrowsecurity = f` (RLS off) **but** `erp_tenant` has **0 grants** and `has_table_privilege('erp_tenant','platform_secret_vault', …) = f/f/f`.
- Probe: as `erp_tenant`, `SELECT count(*) FROM platform_secret_vault` → **`ERROR: permission denied for table platform_secret_vault`**.
- The tenant role cannot touch these tables at all. Latent risk only if a future migration adds a grant without enabling RLS. Confirms the audit's own "latent, mitigated" label.

> **Critical blast-radius nuance:** the live pilot currently has **no school with ≥2 guardians** and the analytics tables are essentially empty (1 row total). So RT-09/10/11/12 are **real and reproducible at the policy layer but currently *latent in production*** — there is no second family's data to leak *yet*. They become live data-leaks the moment a second family is onboarded. This is why they remain P1: the fix must land **before** multi-family onboarding, not after.

---

## Category C — Session / auth / route-authz

Live env confirmed on `akshara-edge`:

### RT-18 — entitlement enforcement — **NOT REPRODUCIBLE (flag ON live)**
- `docker exec akshara-edge env` → **`ENTITLEMENT_ENFORCEMENT=true`**. Enforcement is active in production (matches the B2 cert). The "off by default" finding is a *deploy-time* risk only; not live-exploitable on the pilot.

### RT-23 — Razorpay webhook stub bypass — **VERIFIED LIVE (precondition active)**
- Live env has **no `RAZORPAY_*` keys at all** → `forceStub` defaults `"true"`, `enabled=false`, so **`stubMode = true` live** and the webhook signature check (`if(!valid && !razorpay.stubMode)`) is bypassed. Aggravating: the no-`order_id` path synthesizes a hardcoded tenant with `manageFinance`. The forged-webhook exploit itself was **not** sent (STATIC); but because no real Razorpay creds exist, **no real money flows yet** — this is a go-live precondition to fix before payments are switched on.

### RT-16, RT-17, RT-19, RT-20, RT-21, RT-22 — **STATIC ONLY**
Code-confirmed (see validation report). Reproduction requires either a logout/demote→replay token cycle (RT-16/17) or calling write/inject/cancel endpoints (RT-19/20/21/22) — the latter mutate production state, so were not triggered. All run under `withTenantContext`/RLS, which contains blast radius to the caller's own org. RT-22 excludes `GET /director/summary` (read-only; its view-slug gate is correct).

---

## Category D — Client write resilience — all **STATIC ONLY** (RT-28 NOT REPRODUCIBLE)

Reproduction would need fast manual double-tapping on a running app or new Patrol tests. The 4 existing `red_team_*_e2e_test.dart` suites cover **only** client route-guards and happy-path navigation; none drive the double-submit race, force a write failure, assert error-message text, or exercise the 401-retry path. Confirmed by reading the suites and the run logs under `qa/patrol/reports/red_team_remediation/*`.

- **RT-24 / RT-25** (merged): no notifier re-entry guard + buttons not disabled in-flight. Real user can trigger via double-tap; teacher-attendance `isSubmitted` flips only after the await. STATIC ONLY.
- **RT-26**: `finally`-only / no `catch` on SIS profile edit + finance offline payments → silent failure. STATIC ONLY.
- **RT-27**: raw `Text('$error')` — re-grep found **97** raw-interpolation message sites (≥48 are `$error`/`$e`). STATIC ONLY.
- **RT-28**: **NOT REPRODUCIBLE** — the "optimistic toggle stays green on failure" mechanism doesn't exist (confirm-dialog write). Residue covered by RT-24/26/27.
- **RT-29**: auth interceptor replays the original request verbatim (incl. POST) after a 401 refresh — auto-triggers on token expiry mid-write. STATIC ONLY.
- **RT-30**: `beforeunload`=0; `AksharaUnsavedChangesGuard` wired into only 1–2 of ~63 form screens. STATIC ONLY.
- **RT-31**: app presign sends a coarse content-type and no size — **but storage buckets enforce `file_size_limit` + `allowed_mime_types`** (migrations `20260622700000`, `20260806000020`). Reduced to a presign early-rejection/UX gap. STATIC ONLY.

---

## Category E — Input / scale

| RT | Live finding | Verdict |
|---|---|---|
| RT-32 | Live DB: **671 `text` columns, 0 `varchar(n)`, 0 columns with `character_maximum_length`** | STATIC ONLY · **live-confirmed** |
| RT-33 | `intOr` unbounded; mitigated only where a DB CHECK exists (RT-08 is the proven uncovered case) | STATIC ONLY |
| RT-34 | parent fan-out 3 unbounded `.in()`/select queries; low real risk | STATIC ONLY |
| RT-35 | Live env: `ERP_TENANT_DATABASE_URL=…@akshara-postgres:5432/…` (direct port, **not** 6543), **no pooler container** | STATIC ONLY · **live-confirmed** (no load test run) |

---

## Reproduction totals

| Metric | Count |
|---|---|
| **Original findings** | **35** |
| Confirmed as real defects | **33** (all except RT-15 false-positive and RT-28 refuted) |
| **Verified Live** | **7** (RT-09, RT-10, RT-11, RT-12, RT-13, RT-14, RT-23) |
| **Verified Test** | **0** |
| **Static Only** | **25** (8 with live enabling-condition confirmation) |
| **Not Reproducible** | **3** (RT-15 mitigated, RT-18 flag-ON, RT-28 refuted) |
| **False positives** | **1** (RT-15) |
| **Duplicate / merged** | **2 removed** (RT-24+RT-25 merged; RT-28 folded into RT-24/26/27) |
| **Final genuine distinct issues** | **32** |

**Reproduction did not overturn any Critical or High.** It *upgraded confidence* on the privacy cluster — RT-09/10/11/12/13/14 moved from static-only to **directly observed on the live DB** — and confirmed two mitigations live (RT-15, RT-18). The single most important operational insight: the cross-family RLS leaks are **proven reproducible but currently latent** because the pilot holds only one family's data; the fix must precede multi-family onboarding.

**No code changed. No deploy. No commit. Awaiting owner approval before any fix or Wave 1.**
