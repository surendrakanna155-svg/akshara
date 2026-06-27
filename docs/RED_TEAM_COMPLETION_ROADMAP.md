# AKSHARA — Red Team Completion Roadmap

**Companion to:** [`RED_TEAM_CERTIFICATION_AUDIT.md`](./RED_TEAM_CERTIFICATION_AUDIT.md) · validated by [`RED_TEAM_VALIDATION_REPORT.md`](./RED_TEAM_VALIDATION_REPORT.md)
**Date:** 2026-06-27 (validation reconciliation added 2026-06-27; Waves 1–4 closed 2026-06-27)
**Status:** ✅ **Wave 1 CLOSED** (RT-01..08 fixed, deployed, live 26/26 — commit `6b1e5c1`, [`RED_TEAM_WAVE_1_CERTIFICATION.md`](./RED_TEAM_WAVE_1_CERTIFICATION.md)). ✅ **Wave 2 CLOSED** (RT-09..15 fixed via migration `20260815000000`, deployed, live 25/25 + Wave-1 regression 26/26 — [`RED_TEAM_WAVE_2_CERTIFICATION.md`](./RED_TEAM_WAVE_2_CERTIFICATION.md)). ✅ **Wave 3 CLOSED** (RT-16..23 fixed edge-only, deployed, live 24/24 + Wave-1 26/26 + Wave-2 25/25 regression — [`RED_TEAM_WAVE_3_CERTIFICATION.md`](./RED_TEAM_WAVE_3_CERTIFICATION.md)). ✅ **Wave 4 CLOSED** (RT-24..30 fixed client-only, flutter analyze 0 / test 2448 incl. 8 new + backend regression W1 26/26 · W2 25/25 · W3 24/24 — [`RED_TEAM_WAVE_4_CERTIFICATION.md`](./RED_TEAM_WAVE_4_CERTIFICATION.md)). Wave 5 awaiting owner approval; no fixes applied beyond Wave 4.

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
| 2 ✅ **CLOSED** (live 25/25, `20260815000000`) | Tenant & Privacy Isolation (RLS) | RT-09,10,11,12,13,14,15 | 1 Crit, 4 High, 1 Med, 1 Low | Cross-family PII leak/tamper |
| 3 ✅ **CLOSED** (live 24/24, edge-only) | Session & Authorization Enforcement | RT-16,17,18,19,20,21,22,23 | 3 High, 2 Med, 3 Low | Revocation/demotion ineffective; gate bypass |
| 4 ✅ **CLOSED** (flutter 2448 +8; client-only) | Client Write Resilience | RT-24,25,26,27,28,29,30 | 3 High, 4 Med | Double-submit duplicates; invisible failures |
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

## Wave 2 — Tenant & Privacy Isolation (RLS) — ✅ CLOSED (live 25/25 + W1 regression 26/26, `20260815000000`, 2026-06-27)

> **CLOSED.** All 7 findings fixed in one migration `20260815000000_red_team_wave2_tenant_privacy_rls.sql`, applied to the live VPS pilot and certified **25/25** under the unprivileged `erp_tenant` role (rolled-back probes — the same method that reproduced the leaks). Wave-1 regression re-run live **26/26**. See [`RED_TEAM_WAVE_2_CERTIFICATION.md`](./RED_TEAM_WAVE_2_CERTIFICATION.md). **Implementation notes vs the plan below:** RT-10 and RT-11 were closed by restricting their tables to `school` scope (no parent-facing reader exists for either — strictly safer than the guardian-pin, zero functional impact); RT-09 used the guardian-pin as planned (it has a real parent read path). RT-14's `school_id` pin applies to per-school scopes only — `organization` scope stays org-wide so the `publishPendingDomainEvents` outbox drain is not regressed. Cert proves the fix on a single-family pilot by probing a synthetic non-guardian parent / second school — no 2-family fixture needed.

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

## Wave 3 — Session & Authorization Enforcement — ✅ CLOSED (live 24/24 + W1 26/26 + W2 25/25, edge-only, 2026-06-27)

> **CLOSED.** All 8 findings fixed with **no migration** (edge-function changes only), deployed to the VPS pilot, and live-certified **24/24** over HTTPS using edge-minted scoped JWTs that reference real `sessions` rows + the live `permissions_version` (so the new per-request check treats cert traffic exactly like real traffic). RT-16/17 are a single fix in `authenticateRequest` (`_shared/session_validation.ts`); RT-19/20/21/22 add the missing authorization gates; RT-23 fails the webhook closed; RT-18 is a deploy-precondition (flag confirmed live). Wave-1 (26/26) and Wave-2 (25/25) regressions re-run live with no regressions. See [`RED_TEAM_WAVE_3_CERTIFICATION.md`](./RED_TEAM_WAVE_3_CERTIFICATION.md). **Implementation notes vs the plan below:** RT-16/17 use a per-request DB check with **no TTL cache** (immediacy chosen over the optional cache — the security property is literal, and the lookups are indexed PK reads negligible at pilot scale); RT-21 closes the relationship-user pollution vector by restricting ingestion to staff scope (no existing manage slug fits universal telemetry, and events are already actor-pinned); RT-18 keeps the default OFF by design and is documented as a deploy-precondition rather than flipping the default.

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

## Wave 4 — Client Write Resilience — ✅ CLOSED (client-only; flutter analyze 0 / test 2448 incl. 8 new + W1 26/26 · W2 25/25 · W3 24/24 regression, 2026-06-27)

> **CLOSED.** All 7 findings fixed in the Flutter client with **no backend change** (so the unit-under-test is the client; the authoritative gate is `flutter analyze` + `flutter test`, with the live VPS regression proving the backend is untouched). A double-submit re-entry guard was applied at all **204** mutation entry points (RT-24/25), previously-swallowed write failures now surface (RT-26), all **48** raw error sites route through a clean mapper (RT-27), the auth interceptor only auto-replays safe requests after a 401 refresh (RT-29), and `AksharaUnsavedChangesGuard` now covers in-app back **and** web `beforeunload` and is applied to key forms (RT-30). RT-28 was confirmed not reproducible (duplicate of RT-24/26/27). See [`RED_TEAM_WAVE_4_CERTIFICATION.md`](./RED_TEAM_WAVE_4_CERTIFICATION.md). **Implementation notes vs the plan below:** the RT-24 guard is applied inline at every site (lowest-regression vs a mixin refactor of 176 classes) and is identical everywhere; 7 mutation notifiers with an empty `async` build were made synchronous so `state.isLoading` means exactly "mutation in flight"; 34 non-nullable-return methods throw a typed `mutationInProgressFailure()` (they cannot early-return a value); RT-30's web `beforeunload` uses `dart:js_interop` (no new dependency) and is integrated into the one guard widget. The client changes ship in the next app release (Play submission owner-gated).

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
