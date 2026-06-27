# AKSHARA — Red Team Master Tracker

**This is the single source of truth for every Red Team issue** until each reaches `Closed`. Nothing is deleted; merged/duplicate/false-positive IDs are **retained** with their disposition recorded.

**Last updated:** 2026-06-27 (Wave 1 CLOSED) · **HEAD:** `6b1e5c1` · **Branch:** `feature/scope-trim-school-build`
**Inputs:** [`RED_TEAM_CERTIFICATION_AUDIT.md`](./RED_TEAM_CERTIFICATION_AUDIT.md) · [`RED_TEAM_VALIDATION_REPORT.md`](./RED_TEAM_VALIDATION_REPORT.md) · [`RED_TEAM_REPRODUCTION_REPORT.md`](./RED_TEAM_REPRODUCTION_REPORT.md) · [`RED_TEAM_COMPLETION_ROADMAP.md`](./RED_TEAM_COMPLETION_ROADMAP.md)
**Wave status:** ✅ **Wave 1 (RT-01..08) CLOSED** — live 26/26, [`RED_TEAM_WAVE_1_CERTIFICATION.md`](./RED_TEAM_WAVE_1_CERTIFICATION.md), commit `6b1e5c1`, 2026-06-27. Waves 2–5 remain **Open** (awaiting approval).

## Lifecycle

```
Open → In Progress → Fixed → Certified → Closed
```

**Wave 1 (RT-01..08) is `Closed`** (fixed, deployed, live-certified 26/26 — see commit `6b1e5c1` / [`RED_TEAM_WAVE_1_CERTIFICATION.md`](./RED_TEAM_WAVE_1_CERTIFICATION.md)). All remaining issues (Waves 2–5) are **Open**. Status changes only as waves are approved and executed.

## Disposition legend

- **Verification:** VERIFIED LIVE · VERIFIED TEST · STATIC ONLY · NOT REPRODUCIBLE
- **Environment:** Live (observed/queried on VPS) · Live-schema (enabling condition read off prod, destructive trigger withheld) · Static (code only)
- **Status:** Open (all, pending approval)

## Counts at a glance

| | |
|---|---|
| Original findings | 35 |
| Confirmed real defects | 33 |
| Verified Live | 7 |
| Verified Test | 0 |
| Static Only | 25 |
| Not Reproducible | 3 |
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
| RT-09 | Parent / Academic summaries | Critical | Open | **VERIFIED LIVE** | Live | Probe: non-guardian parent read child summary → `rows_visible=1` (rolled back) | Policy gates only org+school, no guardian pin, no WITH CHECK | W2 / **P1** | Any parent reads/alters any child's academic summary | **High — cross-family PII** | **High** | Latent today (single-family pilot); fix before multi-family onboarding. Pattern exists in `20260725000000` |
| RT-10 | Parent / Engagement analytics | Medium (was High) | Open | **VERIFIED LIVE** | Live | Probe: parent read another parent's snapshot → `score=99` visible (rolled back) | Policy org+school only, keyed `parent_user_id`, no pin | W2 / P3 | Cross-parent metric leak | Medium (metrics, not child PII) | Medium | No parent-scope caller found → lower exposure |
| RT-11 | Parent / Teacher effectiveness | High | Open | **VERIFIED LIVE** | Live | Probe: parent read foreign child meeting summary → `rows_visible=1` (rolled back) | Same shape as RT-09 (per-child, org+school only) | W2 / **P1** | Cross-family meeting-summary leak | **High — cross-family PII** | **High** | Identical predicate to RT-09 |
| RT-12 | Communication Hub | High | Open | **VERIFIED LIVE** | Live | Probe: parent A read parent B private msg `"PRIVATE-MSG-FOR-FAMILY-B"`; `comm_threads` correctly returned 0 (rolled back) | `comm_messages_thread` lacks thread-participation check | W2 / **P1** | Parent reads/posts into any family's thread | **High — private message leak + injection** | **High** | **Most serious**; correct pattern exists in sibling `comm_threads_participant` |
| RT-13 | School Memories | High | Open | **VERIFIED LIVE** | Live | Probe: parent-scope `INSERT` into `school_memory_events` → `INSERT 0 1` ALLOWED (rolled back) | `FOR ALL` USING allows parent/student scope, no WITH CHECK | W2 / P2 | Parent/student tamper with school-wide memory | Medium — unauthorized write | Medium | Read scope OK; write scope too broad |
| RT-14 | Audit / Domain events | Medium | Open | **VERIFIED LIVE** | Live | Probe: school-A context wrote `domain_events` tagged school-B → `INSERT 0 1` (rolled back) | INSERT WITH CHECK pins only `organization_id`, not `school_id` | W2 / P3 | Within-org cross-school audit/event pollution | Low | Medium — forensic integrity | `domain_events` UPDATE policy equally weak; cross-tenant still blocked |
| RT-15 | Platform / secret vault | Low | Open | **NOT REPRODUCIBLE** | Live | Probe: `erp_tenant SELECT platform_secret_vault` → **permission denied**; 0 grants; `has_table_privilege=f/f/f` | Tables created without ENABLE RLS | W2 / P4 | None currently | None | Latent only | **FALSE POSITIVE for current exploitability** — mitigated by no-grant. Optional defense-in-depth |
| RT-16 | Auth / Session lifecycle | High | Open | STATIC ONLY | Static | `authenticateRequest` stateless verify; `revoked_at` never checked per-request; TTL 900s | No per-request session-revocation check | W3 / P2 | Logout/revoke ineffective ≤15 min | Low | **High — stolen/revoked token usable** | Shares root with RT-17; RLS still tenant-scopes |
| RT-17 | Auth / RBAC lifecycle | High | Open | STATIC ONLY | Static | `permissions_version` in JWT never compared to live membership; no admin bump | Stale permissions frozen in JWT | W3 / P2 | Demoted user keeps perms ≤15 min | Medium | **High — privilege persistence** | Refresh re-resolves; one fix in `authenticateRequest` closes RT-16+17 |
| RT-18 | Entitlements | Medium (was High) | Open | **NOT REPRODUCIBLE** | Live | Live env: `ENTITLEMENT_ENFORCEMENT=true` on `akshara-edge` | Enforcement no-op unless flag set | W3 / P3 | Module bypass only if flag unset | Low | Low | Mitigated on pilot (B2 cert); deploy-precondition for other envs |
| RT-19 | Payment | Medium | Open | STATIC ONLY | Static | `handleInitiatePayment`/`Confirm` auth-only, no `requirePermission`/scope (contrast gated `GetPaymentIntent`) | Missing authz gate on init/confirm | W3 / P3 | Any authed tenant user creates/confirms intents | Medium | Medium (RLS-dependent) | Not called live (mutating). Confirm payment-table RLS |
| RT-20 | Approval engine | High | Open | STATIC ONLY | Static | `handleDecision` wraps per-type `requirePermission` in `if(status!=="cancelled")` | Cancel path skips approve permission | W3 / P2 | Non-approver cancels any approval (workflow DoS) | Medium | **High — authz bypass** | Not called live (mutating) |
| RT-21 | Audit ingestion | Medium | Open | STATIC ONLY | Static | `handleAuditBatchUpload` no `requirePermission`; route `permission:null` | Auth-only ingestion | W3 / P3 | Low-priv user pollutes audit trail (≤100/call) | Low | Medium — forensic integrity | Not injected live; RLS tenant-scopes; cap 100 |
| RT-22 | Promotion / Intel / Approval-audit | Low | Open | STATIC ONLY | Static | Write POSTs gated by VIEW slugs: promotions/track, parent-meeting-summary, approvals/audit | View-slug on write paths | W3 / P3 | View-only user triggers generation/metric/audit writes | Low | Low-Med | **`GET /director/summary` excluded** (read-only, gate correct) |
| RT-23 | Payment webhook | Low | Open | **VERIFIED LIVE** | Live | Live env: no `RAZORPAY_*` keys → `stubMode=true`; signature check bypassed when stub | `if(!valid && !stubMode)`; stub defaults true | W3 / P4 | Forged webhooks accepted if stub on in prod | High (financial) **if live** | **High — signature bypass** | No real creds → no money flows yet; **go-live precondition** + synthetic-tenant fallback |
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
| W2 — Tenant & privacy (RLS) | RT-09,10,11,12,13,14,15 | RT-09, RT-11, RT-12 | RT-13 | RT-10, RT-14 | RT-15 |
| W3 — Session & authorization | RT-16,17,18,19,20,21,22,23 | — | RT-16, RT-17, RT-20 | RT-18, RT-19, RT-21, RT-22 | RT-23 |
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

**Wave 1 (RT-01..08): fixed, deployed to the VPS pilot, and live-certified 26/26 (commit `6b1e5c1`, 2026-06-27) → `Closed`. Waves 2–5 remain Open, awaiting owner approval of the wave order. Per the engagement rules, the next wave does not start without approval.**
