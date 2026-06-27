# AKSHARA — Red Team Completion Roadmap

**Companion to:** [`RED_TEAM_CERTIFICATION_AUDIT.md`](./RED_TEAM_CERTIFICATION_AUDIT.md) · validated by [`RED_TEAM_VALIDATION_REPORT.md`](./RED_TEAM_VALIDATION_REPORT.md)
**Date:** 2026-06-27 (validation reconciliation added 2026-06-27; Wave 1 closed 2026-06-27)
**Status:** ✅ **Wave 1 CLOSED** (RT-01..08 fixed, deployed, live 26/26 — commit `6b1e5c1`, [`RED_TEAM_WAVE_1_CERTIFICATION.md`](./RED_TEAM_WAVE_1_CERTIFICATION.md)). Waves 2–5 awaiting owner approval; no fixes applied beyond Wave 1.

> ## Validation reconciliation (post-validation pass)
>
> A validation pass re-checked all 35 findings against the actual code. The wave **order below is unchanged** (blast-radius ordering holds: 27 of 35 confirmed verbatim, no Critical overturned). The following **within-wave scope/severity changes** apply — see `RED_TEAM_VALIDATION_REPORT.md` for evidence:
>
> - **Wave 2:** **drop RT-15** from the required fix list — false positive / already mitigated (platform tables have *no* `erp_tenant` grant, so RLS is moot); keep only as optional defense-in-depth. **RT-12 is the priority of this wave** (only one with a confirmed live exploit path). **RT-10 downgraded** to Medium/defense-in-depth (no parent-scope caller found). RT-09/RT-11 fix pattern already exists in `20260725000000_parent_insights_parent_scope_rls.sql` — copy it.
> - **Wave 3:** **RT-18 and RT-23 are deploy-preconditions, not code fixes** — RT-18's flag is already ON for the pilot (B2 cert); both belong in a deploy checklist. **RT-22 narrows to 3 routes** — `POST /director/summary` is read-only, so its view-slug gate is correct (drop it from the finding).
> - **Wave 4:** **merge RT-24 + RT-25** into one "client double-submit" finding (notifier-layer + button-layer). **RT-28 removed** — its "optimistic toggle stays green on failure" mechanism does not exist in the cited code; genuine residue is covered by RT-24/25/27.
> - **Wave 5:** **RT-31 downgraded** to Medium — Storage buckets already enforce size caps + MIME allowlists in-repo (`20260622700000`, `20260806000020`); rescope to "validate at presign for early rejection."
> - **Net count:** 35 findings → **32 distinct genuine production issues** (−RT-15 false positive, RT-24+25 merged, −RT-28 duplicate).
>
> ## Reproduction reconciliation (live pass, 2026-06-27)
>
> A live reproduction pass (see [`RED_TEAM_REPRODUCTION_REPORT.md`](./RED_TEAM_REPRODUCTION_REPORT.md)) probed the VPS pilot read-only and via rolled-back `erp_tenant` transactions. It **did not overturn any finding** and **confirmed** the priorities above. Material results that affect sequencing:
>
> - **Wave 2 RLS leaks are now VERIFIED LIVE** (RT-09/10/11/12/13/14 directly observed on the live DB, rolled back) — RT-12 demonstrated end-to-end (parent A read parent B's private message; the correct sibling policy returned 0). **BUT they are currently *latent*:** the pilot has only one family / near-empty analytics tables, so there is no cross-family data to leak *yet*. **Action:** Wave 2 must land **before** a second family is onboarded — treat multi-family onboarding as the hard deadline for the RLS fixes.
> - **RT-15 confirmed NOT reachable** (`erp_tenant` → `permission denied`) and **RT-18 confirmed mitigated** (`ENTITLEMENT_ENFORCEMENT=true` live) — both stay low/optional.
> - **RT-23 stub mode is active live** (no Razorpay creds) — no real money flows yet, so it is a **go-live precondition** to close before payments are switched on, not an active incident.
> - Wave order (blast radius) **unchanged**. The single source of truth for status is now [`RED_TEAM_MASTER_TRACKER.md`](./RED_TEAM_MASTER_TRACKER.md).

This roadmap groups the 35 red-team findings into 5 logical waves, ordered by blast radius (data corruption & privacy first, polish & scale last). Waves are designed to be independent enough to ship one at a time. Per the engagement rules: **fix one wave at a time**, and after each approved wave run the full gate below before moving on.

## Per-wave pipeline (mandatory, every wave)

```
/gap-check
→ Fix
→ flutter analyze        (must stay: No issues found)
→ flutter tests          (existing + new tests for the wave)
→ backend tests          (deno test for _shared)
→ Patrol                 (where the wave touches a user-facing write flow)
→ Live VPS certification  (real auth, real DB, real RBAC — incl. the wave's "needs-live" items)
→ /deploy                (only if the change is gated & wanted)
→ /release-review
→ Commit
→ Push
→ STOP  (do not start the next wave without approval)
```

Each wave also produces a `docs/RED_TEAM_WAVE_<n>_CERTIFICATION.md` recording the live cert count, exactly like prior waves.

## Wave order at a glance

| Wave | Theme | Findings | Severity mix | Risk if skipped |
|---|---|---|---|---|
| 1 | Transactional Integrity — duplicates & lost updates | RT-01,02,03,04,05,06,07,08 | 2 Crit, 4 High, 2 Med | Money/identity corruption, lost records |
| 2 | Tenant & Privacy Isolation (RLS) | RT-09,10,11,12,13,14,15 | 1 Crit, 4 High, 1 Med, 1 Low | Cross-family PII leak/tamper |
| 3 | Session & Authorization Enforcement | RT-16,17,18,19,20,21,22,23 | 3 High, 2 Med, 3 Low | Revocation/demotion ineffective; gate bypass |
| 4 | Client Write Resilience | RT-24,25,26,27,28,29,30 | 3 High, 4 Med | Double-submit duplicates; invisible failures |
| 5 | Input/Upload Hardening & Scale | RT-31,32,33,34,35 | 2 High, 2 Med, 1 Low | Upload abuse, DB-connection cliff, bloat |

---

## Wave 1 — Transactional Integrity (duplicates & lost updates) — ✅ CLOSED (live 26/26, `6b1e5c1`, 2026-06-27)

> **Done.** All 8 findings fixed at root cause, deployed to the VPS pilot (migration `20260814000000`), and live-certified 26/26 — see [`RED_TEAM_WAVE_1_CERTIFICATION.md`](./RED_TEAM_WAVE_1_CERTIFICATION.md). The exit criteria below were met live (concurrent full payments → one 201 / one 422, outstanding settled at 0.00; double-submit → exactly one row; concurrent snapshot write loses nothing). The live cert caught a missing `erp_tenant` grant and a wrong-handler (the live teacher marks route is the pilot handler) — both fixed before certifying.

**Why first:** these are the only findings that produce *silent data corruption* in money and student identity — the two things a school cannot tolerate. They also underpin Wave 4: fixing client double-tap matters far less if the backend will dedupe.

**Findings:** RT-01, RT-02, RT-03, RT-04, RT-05, RT-06, RT-07, RT-08

**Fix shape (per finding):**
- **RT-01:** add a unique key / idempotency key for collections (e.g. `(invoice_id, client_request_id)` or honour an `Idempotency-Key`), and `SELECT … FOR UPDATE` the invoice before the outstanding check + decrement. Map violation → 409.
- **RT-02:** add `UNIQUE (school_id, admission_number)` on `student_profiles`; map violation → 409.
- **RT-03:** replace `MAX+1` student-code with a sequence/atomic counter, or retry-on-conflict.
- **RT-04 / RT-05:** replace `count(*)+1` ids with UUIDs (mirror the safe parent path).
- **RT-06:** make snapshot mutation atomic — `SELECT … FOR UPDATE` the snapshot row (or move list items to real rows / `jsonb_set` `||` update).
- **RT-07:** honour the already-advertised `Idempotency-Key` header in `runWrite` (store + replay), and/or add natural unique keys (e.g. `admissions_leads(school_id, phone)`).
- **RT-08:** server-side `0 <= marksObtained <= max_marks` + DB CHECK.

**Migrations:** likely 3–4 (unique constraints, CHECK, idempotency store).
**Exit criteria:** live cert proves a double-submit and a concurrent submit each yield exactly one row (or a clean 409), and a concurrent snapshot write loses nothing.

---

## Wave 2 — Tenant & Privacy Isolation (RLS)

**Why second:** these are confirmed cross-family **PII** read/write leaks — a privacy incident is as damaging as data corruption, and the fixes are small, surgical policy edits.

**Findings:** RT-09, RT-10, RT-11, RT-12, RT-13, RT-14, RT-15

**Fix shape:** one migration tightening each weak `USING`/adding `WITH CHECK`:
- RT-09/RT-11: add `student_id IN (SELECT sg.student_id FROM student_guardians sg WHERE sg.guardian_user_id = app_current_parent_user_id() AND sg.status='active')` to the parent-summary / meeting-summary policies.
- RT-10: add `parent_user_id = app_current_parent_user_id()`.
- RT-12: add an `EXISTS` thread-participation join for parent scope on `comm_messages`.
- RT-13: add a `WITH CHECK` restricting school-memory writes to `scope='school'` (keep parent/student read).
- RT-14: add `school_id = app_current_school_id()` to the audit/domain-event INSERT `WITH CHECK`.
- RT-15: `ENABLE ROW LEVEL SECURITY` + scope policies on the platform tables (defense-in-depth).

**Migrations:** 1 (grouped).
**Exit criteria:** live cert with a 2-parent / 2-school fixture proves each parent sees only their child's rows and cannot write another family's; cross-school audit insert is rejected.

---

## Wave 3 — Session & Authorization Enforcement

**Why third:** closes the stale-token window and the gate-bypass routes. Higher design surface than Waves 1–2 (touches the hot auth path), so it follows the data-integrity fixes.

**Findings:** RT-16, RT-17, RT-18, RT-19, RT-20, RT-21, RT-22, RT-23

**Fix shape:**
- **RT-16/RT-17:** per-request validity check — consult `sessions.revoked_at` and compare `permissions_version` against the live membership (with a short-TTL cache to protect the hot path); add an admin path that bumps `permissions_version` on role/override change.
- **RT-18:** make entitlement enforcement default-on (or assert the env flag in `/health/ready`) and document the requirement.
- **RT-20:** move the per-type `requirePermission` outside the `status !== "cancelled"` guard (cancel must require the approve slug or a dedicated cancel permission).
- **RT-19/RT-21:** add the appropriate `manage*` permission gate to payment-intent and audit-batch handlers.
- **RT-22:** swap the view slugs for manage slugs on the four write-via-view routes.
- **RT-23:** fail-closed on webhook signature unless an explicit dev override is set; assert stubMode off in prod.

**Migrations:** 0–1 (permission seed for cancel, if added).
**Exit criteria:** live cert proves logout-all blocks the old token immediately; a demoted user is blocked immediately; a non-approver cannot cancel; entitlement is enforced.

> Note: this wave is *enforcement hardening*, not a "Security Certification" — it only fixes the specific red-team findings above. It does not open a separate security-cert track.

---

## Wave 4 — Client Write Resilience

**Why fourth:** with the backend deduped (Wave 1) and authorized (Wave 3), harden the client so users can't trigger the failure modes in the first place and always see what happened.

**Findings:** RT-24, RT-25, RT-26, RT-27, RT-28, RT-29, RT-30

**Fix shape:**
- **RT-24:** add `if (state.isLoading) return;` to mutation `execute()` (ideally a shared base/mixin).
- **RT-25:** disable write buttons while the mutation `.isLoading` (apply the existing guarded-button template broadly).
- **RT-26:** add `catch` → user-visible failure on the swallowed-error screens.
- **RT-27:** replace ~48 `Text('$error')` with `failure.message` / `AksharaErrorState.fromFailure`.
- **RT-28:** revert optimistic toggle state on write failure (or disable until confirmed).
- **RT-29:** restrict auth auto-retry to idempotent verbs (or attach an idempotency key, leveraging Wave 1's server support).
- **RT-30:** apply `AksharaUnsavedChangesGuard` to key forms + a web `beforeunload` hook while a mutation is in flight.

**Migrations:** 0.
**Exit criteria:** Patrol proves double-tap fires one request; failures show a clean message + retry without losing input.

---

## Wave 5 — Input/Upload Hardening & Scale

**Why last:** important but lower immediate blast radius; RT-35 is the one to watch (scaling cliff) and may be promoted earlier if a load incident is observed.

**Findings:** RT-31, RT-32, RT-33, RT-34, RT-35

**Fix shape:**
- **RT-31:** content-type allowlist + max-bytes at presign and/or Supabase bucket policy.
- **RT-32:** shared bounded-string reader on the backend + `maxLength` on key client forms.
- **RT-33:** per-field min/max in `intOr` callers or DB CHECKs.
- **RT-34:** cap + paginate the parent children fan-out; virtualise the switcher list.
- **RT-35:** route tenant DB access through the PgBouncer pooler (6543) or add a connection pool.

**Migrations:** 1–2 (CHECKs / bucket policy if done in-repo).
**Exit criteria:** live cert proves oversized/wrong-type uploads and over-long/negative inputs are rejected; a load probe shows the pooled connection path holds under concurrency.

---

## Explicitly OUT OF SCOPE (do not start)

Per the engagement constraints, after the approved wave(s) this effort **stops**. The following are **not** part of this roadmap and must not be started here:

- Performance Certification
- UX Certification
- Security Certification
- Chaos Certification
- Legal & Compliance
- `FINAL_GA_CERTIFICATION`

No new features. No roadmap changes. No re-audit of already-certified areas. Certifications remain the source of truth.
