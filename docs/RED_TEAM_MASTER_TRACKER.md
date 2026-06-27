# AKSHARA — Red Team Master Tracker

**This is the single source of truth for every Red Team issue** until each reaches `Closed`. Nothing is deleted; merged/duplicate/false-positive IDs are **retained** with their disposition recorded.

**Last updated:** 2026-06-27 (Wave 3 CLOSED) · **HEAD:** `<pending-commit>` · **Branch:** `feature/scope-trim-school-build`
**Inputs:** [`RED_TEAM_CERTIFICATION_AUDIT.md`](./RED_TEAM_CERTIFICATION_AUDIT.md) · [`RED_TEAM_VALIDATION_REPORT.md`](./RED_TEAM_VALIDATION_REPORT.md) · [`RED_TEAM_REPRODUCTION_REPORT.md`](./RED_TEAM_REPRODUCTION_REPORT.md) · [`RED_TEAM_COMPLETION_ROADMAP.md`](./RED_TEAM_COMPLETION_ROADMAP.md)
**Wave status:** ✅ **Wave 1 (RT-01..08) CLOSED** — live 26/26, [`RED_TEAM_WAVE_1_CERTIFICATION.md`](./RED_TEAM_WAVE_1_CERTIFICATION.md), commit `6b1e5c1`, 2026-06-27. ✅ **Wave 2 (RT-09..15) CLOSED** — live 25/25 + Wave-1 regression 26/26, [`RED_TEAM_WAVE_2_CERTIFICATION.md`](./RED_TEAM_WAVE_2_CERTIFICATION.md), migration `20260815000000`, 2026-06-27. ✅ **Wave 3 (RT-16..23) CLOSED** — live 24/24 + Wave-1 regression 26/26 + Wave-2 regression 25/25, [`RED_TEAM_WAVE_3_CERTIFICATION.md`](./RED_TEAM_WAVE_3_CERTIFICATION.md), edge-only (no migration), 2026-06-27. Waves 4–5 remain **Open** (awaiting approval).

## Lifecycle

```
Open → In Progress → Fixed → Certified → Closed
```

**Wave 1 (RT-01..08) is `Closed`** (fixed, deployed, live-certified 26/26 — see commit `6b1e5c1` / [`RED_TEAM_WAVE_1_CERTIFICATION.md`](./RED_TEAM_WAVE_1_CERTIFICATION.md)). **Wave 2 (RT-09..15) is `Closed`** (fixed, deployed, live-certified 25/25, Wave-1 regression 26/26 — see migration `20260815000000_red_team_wave2_tenant_privacy_rls.sql` / [`RED_TEAM_WAVE_2_CERTIFICATION.md`](./RED_TEAM_WAVE_2_CERTIFICATION.md)). **Wave 3 (RT-16..23) is `Closed`** (fixed, deployed edge-only, live-certified 24/24, Wave-1 regression 26/26, Wave-2 regression 25/25 — see [`RED_TEAM_WAVE_3_CERTIFICATION.md`](./RED_TEAM_WAVE_3_CERTIFICATION.md)). All remaining issues (Waves 4–5) are **Open**. Status changes only as waves are approved and executed.

## Disposition legend

- **Verification:** VERIFIED LIVE · VERIFIED TEST · STATIC ONLY · NOT REPRODUCIBLE
- **Environment:** Live (observed/queried on VPS) · Live-schema (enabling condition read off prod, destructive trigger withheld) · Static (code only)
- **Status:** Open (all, pending approval)

## Counts at a glance

| | |
|---|---|
| Original findings | 35 |
| Confirmed real defects | 33 |
| Verified Live | 21 (RT-09..15 in Wave 2; RT-16..23 verified live post-fix in Wave 3) |
| Verified Test | 0 |
| Static Only | 19 |
| Not Reproducible | 2 |
| False positives | 1 (RT-15) |
| Merged / duplicate IDs (retained) | RT-25→RT-24, RT-28→RT-24/26/27 |
| **Final genuine distinct issues** | **32** |

---

## Master table

> Severity = validated severity (original in parentheses where changed). P = recommended priority (from validation report). Wave = roadmap wave.

| RT | Module | Sev | Status | Verification | Env | Evidence | Root cause | Wave / P | User impact | Data risk | Security risk | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| RT-01 | Finance / Fee collection | Critical | Closed | STATIC ONLY | Live-schema | Live: `finance_collections` no unique on `invoice_id` (PK on `id` + plain index); `createCollection` read-then-write no `FOR UPDATE`/idempotency | TOCTOU + no DB unique/lock/idempotency | W1 / **P1** | Double payment, negative outstanding, broken reconciliation | **High — money corruption** | Low | Destructive repro (commit dup) withheld; constraint absence confirmed live |
| RT-02 | SIS / Student create | Critical | Closed | STATIC ONLY | Live-schema | Live: `student_profiles` `UNIQUE(student_id)` only, no `(school_id,admission_number)` unique | App-level SELECT-then-INSERT, no DB unique | W1 / **P1** | Duplicate student; marks/fees split across copies | **High — identity corruption** | Low | Constraint absence confirmed live |
| RT-03 | SIS / Student code | High | Closed | STATIC ONLY | Live-schema | Live: `students` `UNIQUE(school_id,student_code)` **present**; code = `MAX+1` no lock | Race to PK conflict | W1 / P2 | Concurrent enrolment 500s; staff retry blind | Low (constraint protects) | Low | Integrity protected; availability bug |
| RT-04 | Attendance / Corrections | High | Closed | STATIC ONLY | Live-schema | Live: PK `(org,school,id)`; id = `att_corr_${count+1}` | `count(*)+1` id, no lock | W1 / P3 | Concurrent 500s / dup pending corrections | Low | Low | Path already accepts `input.id` (UUID fix easy) |
| RT-05 | Academics / Exam admin | Medium | Closed | STATIC ONLY | Live-schema | Live: `exam_sessions` PK `(org,school,id)`; id=`exam_${count+1}` | `count(*)+1` id | W1 / P3 | Dup exams / 500 under concurrency | Low | Low | Marks upserts confirmed safe |
| RT-06 | HR / Library / Mgmt snapshots | High | Closed | STATIC ONLY | Static | `mutateSnapshot` find→mutate→replace, no `FOR UPDATE`; **5** call sites (audit said 4) | Read-modify-write last-writer-wins | W1 / P2 | Leave requests / approvals silently vanish | Medium — lost records | Low | `hr_write_handlers.ts:388` was missed by audit |
| RT-07 | Entity-write framework + CRM | Medium | Closed | STATIC ONLY | Static | `runWrite` ignores `Idempotency-Key` (CORS-allowed, consumed only by payments); leads no `(school_id,phone)` unique | No idempotency on generic inserts | W1 / P3 | Double-tap dups everything; dup leads skew CRM | Medium | Low | Umbrella over RT-01/RT-02 |
| RT-08 | Academics / Exam marks | High | Closed | STATIC ONLY | Live-schema | Live: `exam_mark_entries.marks_obtained INTEGER`, **no CHECK**; handler only `Number.isFinite` | No server bound, no DB CHECK | W1 / P2 | Corrupt grades; %>100 / negative | Medium — grade corruption | Low | Bad-marks commit withheld; no-CHECK confirmed live |
| RT-09 | Parent / Academic summaries | Critical | **Closed** | **VERIFIED LIVE** | Live | Pre-fix: non-guardian parent read child summary → `rows_visible=1`. Post-fix (cert 25/25): non-guardian → **0**, real guardian → **1** | Policy gates only org+school, no guardian pin, no WITH CHECK | W2 / **P1** | Any parent reads/alters any child's academic summary | **High — cross-family PII** | **High** | **FIXED** `20260815000000`: `parent_academic_summaries_access` guardian-pin (USING+WITH CHECK), mirrors `20260725000000`. Closed 2026-06-27 |
| RT-10 | Parent / Engagement analytics | Medium (was High) | **Closed** | **VERIFIED LIVE** | Live | Post-fix (cert): parent scope read → **0**; staff (school) → **1** | Policy org+school only, keyed `parent_user_id`, no pin | W2 / P3 | Cross-parent metric leak | Medium (metrics, not child PII) | Medium | **FIXED** `20260815000000`: `parent_engagement_scope` restricted to school scope (no parent-facing reader). Closed 2026-06-27 |
| RT-11 | Parent / Teacher effectiveness | High | **Closed** | **VERIFIED LIVE** | Live | Post-fix (cert): parent scope read → **0**; staff (school) → **1** | Same shape as RT-09 (per-child, org+school only) | W2 / **P1** | Cross-family meeting-summary leak | **High — cross-family PII** | **High** | **FIXED** `20260815000000`: `parent_meeting_summaries_scope` restricted to school scope (no parent surface). Closed 2026-06-27 |
| RT-12 | Communication Hub | High | **Closed** | **VERIFIED LIVE** | Live | Post-fix (cert): non-participant parent read thread → **0** + INSERT **RLS-denied**; owning parent reads own msg → **1** | `comm_messages_thread` lacks thread-participation check | W2 / **P1** | Parent reads/posts into any family's thread | **High — private message leak + injection** | **High** | **FIXED** `20260815000000`: `comm_messages_thread` now checks `comm_threads` participation (USING+WITH CHECK), mirrors `comm_threads_participant`. Closed 2026-06-27 |
| RT-13 | School Memories | High | **Closed** | **VERIFIED LIVE** | Live | Pre-fix: parent INSERT → `INSERT 0 1`. Post-fix (cert): parent INSERT **RLS-denied**, parent SELECT still works, staff INSERT → **1** | `FOR ALL` USING allows parent/student scope, no WITH CHECK | W2 / P2 | Parent/student tamper with school-wide memory | Medium — unauthorized write | Medium | **FIXED** `20260815000000`: split into read (school/parent/student) + school-only write policies, ×3 tables. Closed 2026-06-27 |
| RT-14 | Audit / Domain events | Medium | **Closed** | **VERIFIED LIVE** | Live | Pre-fix: school-A wrote `domain_events` tagged school-B → `INSERT 0 1`. Post-fix (cert): cross-school INSERT **RLS-denied**, same-school → **1** | INSERT WITH CHECK pins only `organization_id`, not `school_id` | W2 / P3 | Within-org cross-school audit/event pollution | Low | Medium — forensic integrity | **FIXED** `20260815000000`: `domain_events_school_insert`/`_update` pin `school_id` for per-school scopes; org scope kept for outbox drain. Closed 2026-06-27 |
| RT-15 | Platform / secret vault | Low | **Closed** | **VERIFIED LIVE** | Live | Pre-fix: no RLS (relied on no-grant). Post-fix (cert): `relrowsecurity=t`+`force=t`, deny-all policy; `erp_tenant` SELECT → **permission denied** | Tables created without ENABLE RLS | W2 / P4 | None currently | None | Latent only | **FALSE POSITIVE for current exploitability** — closed as defense-in-depth. **FIXED** `20260815000000`: ENABLE+FORCE RLS + `platform_secret_vault_deny_all`. Closed 2026-06-27 |
| RT-16 | Auth / Session lifecycle | High | **Closed** | **VERIFIED LIVE** | Live | Post-fix (cert 24/24): valid token → 200; after `revoked_at` set, SAME token → **401 `SESSION_REVOKED`** | No per-request session-revocation check | W3 / P2 | Logout/revoke ineffective ≤15 min | Low | **High — stolen/revoked token usable** | **FIXED** edge-only: `session_validation.ts` `assertSessionValid` in `authenticateRequest` consults `sessions.revoked_at`. Closed 2026-06-27 |
| RT-17 | Auth / RBAC lifecycle | High | **Closed** | **VERIFIED LIVE** | Live | Post-fix (cert): token at live version → 200; after version bump, SAME token → **401 `PERMISSIONS_STALE`**; fresh token → 200 | Stale permissions frozen in JWT | W3 / P2 | Demoted user keeps perms ≤15 min | Medium | **High — privilege persistence** | **FIXED** same chokepoint compares `permissions_version` vs live membership; demotion bumps version (precedent `20260627110000`). Closed 2026-06-27 |
| RT-18 | Entitlements | Medium (was High) | **Closed** | **VERIFIED LIVE** | Live | Live env (cert): `ENTITLEMENT_ENFORCEMENT=true` on `akshara-edge` | Enforcement no-op unless flag set | W3 / P3 | Module bypass only if flag unset | Low | Low | **Deploy-precondition** — flag confirmed live; documented in Wave-3 cert §6. Default stays OFF by design (safe dark deploys). Closed 2026-06-27 |
| RT-19 | Payment | Medium | **Closed** | **VERIFIED LIVE** | Live | Post-fix (cert): school scope → initiate/confirm **403**; parent scope passes (201 stub) | Missing authz gate on init/confirm | W3 / P3 | Any authed tenant user creates/confirms intents | Medium | Medium (RLS-dependent) | **FIXED** `requirePaymentWriteScope` (parent + school_id), mirrors `payment_intents` parent-only-write RLS. Closed 2026-06-27 |
| RT-20 | Approval engine | High | **Closed** | **VERIFIED LIVE** | Live | Post-fix (cert): non-approver `cancel` → **403** (stays pending); manager (`manageManagement`) → 200 | Cancel path skips approve permission | W3 / P2 | Non-approver cancels any approval (workflow DoS) | Medium | **High — authz bypass** | **FIXED** `handleDecision` authorizes every decision incl. cancel (approve-perm / `manageManagement` / self-requester). Closed 2026-06-27 |
| RT-21 | Audit ingestion | Medium | **Closed** | **VERIFIED LIVE** | Live | Post-fix (cert): parent scope → `/audit/events/batch` **403**; staff scope → 200 (accepted=1) | Auth-only ingestion | W3 / P3 | Low-priv user pollutes audit trail (≤100/call) | Low | Medium — forensic integrity | **FIXED** restricted to staff (school/org) scope; events stay actor/tenant/school-pinned. Closed 2026-06-27 |
| RT-22 | Promotion / Intel / Approval-audit | Low | **Closed** | **VERIFIED LIVE** | Live | Post-fix (cert): each of promotions/track, parent-meeting-summary, approvals/audit rejects view-only (403), admits manage (not 403) | View-slug on write paths | W3 / P3 | View-only user triggers generation/metric/audit writes | Low | Low-Med | **FIXED** 3 routes → manage slugs (`manageAchievementPromotion`/`manageLessonLogs`/`manageManagement`); `/director/summary` correctly excluded. Closed 2026-06-27 |
| RT-23 | Payment webhook | Low | **Closed** | **VERIFIED LIVE** | Live | Post-fix (cert): forged `X-Razorpay-Signature` → `/webhooks/razorpay` **403** even in stub mode | `if(!valid && !stubMode)`; stub defaults true | W3 / P4 | Forged webhooks accepted if stub on in prod | High (financial) **if live** | **High — signature bypass** | **FIXED** fail-closed; signature enforcement decoupled from stub (`RAZORPAY_ALLOW_UNSIGNED` explicit dev override). Go-live precondition (creds + stub off) in cert §6. Closed 2026-06-27 |
| RT-24 | All write notifiers | High | Open | STATIC ONLY | Static | grep `if(state.isLoading) return` = **0**; `state=AsyncLoading();state=await guard()` everywhere | No re-entry guard | W4 / P2 | Double-tap → duplicate write | Medium (amplifies RT-01/02) | Low | **MERGED with RT-25** (notifier layer) |
| RT-25 | Finance/Teacher/Exam/etc. | High | Open | STATIC ONLY | Static | teacher-attendance `isSubmitted` flips only after await; button not disabled in-flight | Button not disabled while loading | W4 / P2 | Double-tap duplicates (some screens) | Medium | Low | **MERGED → tracked under RT-24** (button layer). Retained ID. Some screens already guard (SIS) |
| RT-26 | SIS profile / Finance offline | High | Open | STATIC ONLY | Static | `_save()` finally-only no catch; offline-pay no try/catch | Swallowed write errors | W4 / P2 | User thinks save worked → re-taps | Medium — silent data loss | Low | Compounds RT-24/25 |
| RT-27 | Transport/Exam/Edu/etc. | Medium | Open | STATIC ONLY | Static | grep `Text('$error')/$e` = **48**; broader raw-interpolation = **97** sites | Raw `ApiFailureException.toString()` shown | W4 / P3 | Unprofessional/confusing error text | Low — minor info disclosure | Low | `fromFailure` mapper exists but UI bypasses it |
| RT-28 | Transport / HR attendance | — (was Medium) | Open | **NOT REPRODUCIBLE** | Static | Cited screen uses confirm-dialog write, not optimistic toggle | Mechanism does not exist as described | W4 / — | — | — | — | **Duplicate of RT-24/26/27** — residue tracked there; ID retained |
| RT-29 | Core network | Medium | Open | STATIC ONLY | Static | `AuthInterceptor._retry` replays original request (incl POST) verbatim after 401 refresh | Verb-agnostic auto-retry | W4 / P3 | Rare silent duplicate write at token-expiry boundary | Medium | Low | Auto-triggers on expiry; no idempotency key |
| RT-30 | All forms | Medium | Open | STATIC ONLY | Static | grep `beforeunload`=0; `UnsavedChangesGuard` in 1–2 of ~63 forms; `PopScope` in 2 (auth) | No refresh/back guard | W4 / P4 | Lost form input on accidental back/refresh | Low — UX/data loss | None | Guard exists, under-applied |
| RT-31 | Storage / uploads | Medium (was High) | Open | STATIC ONLY | Live-schema | App presign sets no contentType/size; **buckets DO enforce** size+MIME (`20260622700000`, `20260806000020`) | No app-layer validation at presign | W5 / P3 | Mislabelled-but-allowed object; poor rejection UX | Low — no leak | Low | **"No enforcement" was FALSE**; rescope to presign early-rejection |
| RT-32 | Cross-cutting forms | Medium | Open | STATIC ONLY | Live-schema | Live DB: **671 text cols, 0 varchar(n), 0 bounded**; `str()` unbounded; 0/63 client `maxLength` | No length bounds anywhere | W5 / P3 | DB bloat, UI overflow, large-payload DoS | Low-Medium | Low | Confirmed on live schema |
| RT-33 | Cross-cutting entity writes | Medium | Open | STATIC ONLY | Static | `intOr` no floor/ceiling; mitigated where DB CHECK exists | Unbounded numeric reader | W5 / P3 | Negative/absurd values where no CHECK | Medium | Low | Instance overlap with RT-08 (different file) |
| RT-34 | Auth / Parent context | Low | Open | STATIC ONLY | Static | 3 unbounded `.in()`/select in `resolveParentContext`/`loadChildProfiles` | No `.limit()` on fan-out | W5 / P4 | Slow login for outlier guardians | Low | None | Low real risk at family sizes |
| RT-35 | Backend infra | High | Open | STATIC ONLY | Live | Live env: DB url port **5432** (direct), **no pooler container** | Per-request connect/end, no pool | W5 / P2 | Connection exhaustion under spike → 500 cascade | Low (works at pilot scale) | Low | No load test run (would DoS); config confirmed live |

---

## Status roll-up

| Wave | Findings (incl. retained merged IDs) | P1 | P2 | P3 | P4 |
|---|---|---|---|---|---|
| W1 — Transactional integrity ✅ **CLOSED (live 26/26, `6b1e5c1`)** | RT-01,02,03,04,05,06,07,08 | RT-01, RT-02 | RT-03, RT-06, RT-08 | RT-04, RT-05, RT-07 | — |
| W2 — Tenant & privacy (RLS) ✅ **CLOSED (live 25/25 + W1 regression 26/26, `20260815000000`)** | RT-09,10,11,12,13,14,15 | RT-09, RT-11, RT-12 | RT-13 | RT-10, RT-14 | RT-15 |
| W3 — Session & authorization ✅ **CLOSED (live 24/24 + W1 26/26 + W2 25/25, edge-only)** | RT-16,17,18,19,20,21,22,23 | — | RT-16, RT-17, RT-20 | RT-18, RT-19, RT-21, RT-22 | RT-23 |
| W4 — Client write resilience | RT-24,(25),26,27,(28),29,30 | — | RT-24(+25), RT-26 | RT-27, RT-29 | RT-30 |
| W5 — Input/upload & scale | RT-31,32,33,34,35 | — | RT-35 | RT-31, RT-32, RT-33 | RT-34 |

## Merge / disposition ledger (nothing deleted)

| ID | Disposition | Tracked under | Reason |
|---|---|---|---|
| RT-15 | False positive / mitigated | RT-15 (kept, P4 optional) | `erp_tenant` has no grant → not reachable (live: permission denied) |
| RT-18 | Mitigated on pilot | RT-18 (kept, deploy-precondition) | `ENTITLEMENT_ENFORCEMENT=true` live |
| RT-25 | Merged | **RT-24** | Same double-submit root cause (button layer vs notifier layer) |
| RT-28 | Not reproducible / duplicate | **RT-24, RT-26, RT-27** | Optimistic-toggle mechanism does not exist; residue covered elsewhere |
| RT-22 (`/director/summary` sub-claim) | False sub-claim | RT-22 (rest valid) | Endpoint is read-only; view-slug gate is correct |

---

**Wave 1 (RT-01..08): fixed, deployed to the VPS pilot, and live-certified 26/26 (commit `6b1e5c1`, 2026-06-27) → `Closed`.**

**Wave 2 (RT-09..15): fixed via migration `20260815000000_red_team_wave2_tenant_privacy_rls.sql`, applied to the VPS pilot, and live-certified 25/25 under the `erp_tenant` role (rolled-back probes), with the Wave-1 regression re-run live at 26/26 (2026-06-27) → `Closed`. Evidence: [`RED_TEAM_WAVE_2_CERTIFICATION.md`](./RED_TEAM_WAVE_2_CERTIFICATION.md); cert script `scripts/qa/live_cert_red_team_wave2.py`.**

**Wave 3 (RT-16..23): fixed edge-function-only (no migration) — `_shared/session_validation.ts` (`assertSessionValid` in `authenticateRequest`) for RT-16/17, plus authorization gates on payment init/confirm (RT-19), approval cancel (RT-20), audit-batch ingestion (RT-21), three view-slug write routes (RT-22), and webhook fail-closed (RT-23); RT-18 is a deploy-precondition (flag confirmed live). Deployed to the VPS pilot and live-certified 24/24 over HTTPS with edge-minted scoped JWTs that reference real `sessions` rows + the live `permissions_version`. Wave-1 (26/26) and Wave-2 (25/25) regressions re-run live (2026-06-27) → `Closed`. Evidence: [`RED_TEAM_WAVE_3_CERTIFICATION.md`](./RED_TEAM_WAVE_3_CERTIFICATION.md); cert script `scripts/qa/live_cert_red_team_wave3.py`. Waves 4–5 remain Open, awaiting owner approval of the wave order. Per the engagement rules, the next wave does not start without approval.**
