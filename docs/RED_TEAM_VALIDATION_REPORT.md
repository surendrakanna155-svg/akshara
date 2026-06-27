# AKSHARA — Red Team Validation Report

**Date:** 2026-06-27
**Branch:** `feature/scope-trim-school-build` (HEAD `4f7f821` — same commit the audit was run against)
**Companion to:** [`RED_TEAM_CERTIFICATION_AUDIT.md`](./RED_TEAM_CERTIFICATION_AUDIT.md) · [`RED_TEAM_COMPLETION_ROADMAP.md`](./RED_TEAM_COMPLETION_ROADMAP.md)
**Nature:** This is a **validation pass only**. No code was modified, nothing deployed, nothing certified, no fix started. Every one of the 35 red-team findings was re-checked against the actual current code — opening each cited `file:line`, re-running the systemic greps, and searching for guards/constraints/later migrations the auditor may have missed — by five independent verification tracks (one per audit category).

---

## Headline numbers

| Metric | Count |
|---|---|
| **Original findings** | **35** |
| Fully confirmed (accurate as written) | 27 |
| Partially-correct (real issue, but severity/mechanism/scope needs correction) | 6 → RT-10, RT-19, RT-22, RT-28, RT-31 (and RT-18 code-accurate but env-mitigated) |
| **False positives** (full) | **1** → RT-15 |
| Already mitigated by config / prior cert | RT-15 (no-grant), RT-18 (pilot env flag ON), RT-31 (bucket limits exist) |
| **Duplicates removed / merged** | **2** → RT-24+RT-25 merged; RT-28 folded into RT-24/25/27 |
| Findings needing live verification | RT-09, RT-10, RT-11, RT-12, RT-13, RT-18, RT-19, RT-23, RT-31, RT-35 |
| **Final count of genuine, distinct production issues** | **32** |

**How 35 → 32:** start at 35 → remove RT-15 (false positive / already mitigated) → merge RT-24 + RT-25 into one double-submit finding (−1) → fold RT-28 into RT-24/25/27 as a duplicate (−1) = **32 distinct actionable issues**.

**Overall verdict:** the audit is **high quality and overwhelmingly accurate.** 27 of 35 findings are confirmed verbatim; the corrections that exist mostly *strengthen* the audit (RT-06 has 5 call sites not 4; RT-07's idempotency-key header is genuinely consumed nowhere but payments). Only one finding (RT-15) is a clean false positive, and the auditor had already self-labelled it "latent, mitigated." The real shape of the work is slightly *smaller* and more sharply targeted than the raw 35 suggests, but no Critical was overturned.

---

## Master validation table

Severity column shows **validated** severity; where it differs from the audit the original is shown in (parentheses).

| RT | Module | Severity | One-line | Root cause | Evidence (verified file:line) | Static/Live | Reproducible | Already fixed by prior cert? | Duplicate of | False positive? | Recommended action |
|---|---|---|---|---|---|---|---|---|---|---|---|
| RT-01 | Finance / Fee Collection | Critical | Duplicate/lost fee collection | read-then-write, no `FOR UPDATE`, no idempotency, no unique key on `invoice_id` | `finance_collections_repository.ts:174-194`; `20260612500000_…collections.sql:4-23,39` | Static (window=Live) | Yes | No | umbrella RT-07 | No | **Fix** — `FOR UPDATE` invoice + idempotency key → 409 |
| RT-02 | SIS / Student create | Critical | Duplicate student identity (TOCTOU) | app-level SELECT-then-INSERT; no `UNIQUE(school_id, admission_number)` | `sis_students_repository.ts:354-361`; `20260613000000_sis_slice0_foundation.sql:30,35` | Static | Yes | RT-03; under RT-07 | No | **Fix** — add unique constraint → 409 |
| RT-03 | SIS / Student code | High | `MAX+1` student code races to PK conflict → 500 | `ORDER BY student_code DESC LIMIT 1`+1, no lock; `UNIQUE(school_id, student_code)` | `sis_status_codec.ts:87-102`; `20260609100000_phase2_rls_scope.sql:17` | Static | Yes | sibling RT-04/05 | No | **Fix** — sequence or retry-on-conflict |
| RT-04 | Attendance / Corrections | High | `count(*)+1` id → concurrent PK 500 / dup | id `att_corr_${count+1}` then INSERT, PK `(org,school,id)` | `attendance_correction_repository.ts:143-151`; `20260618130000_f5_attendance_corrections.sql:24` | Static | Yes | RT-05 | No | **Fix** — always UUID id (path already accepts `input.id`) |
| RT-05 | Academics / Exam admin | Medium | `count(*)+1` exam-session id → PK 500 / dup | id `exam_${count+1}` then INSERT | `exam_administration_repository.ts:214-220` | Static | Yes | RT-04 | No | **Fix** — UUID id (marks upserts confirmed safe) |
| RT-06 | HR/Library/Mgmt snapshots | High | Snapshot lost-update (last-writer-wins) | `mutateSnapshot` find→mutate→replace, no `FOR UPDATE` | `entity_write_store.ts:169-204`; sites `hr_write_handlers.ts:140,184,**388**`, `library:347`, `management:109` | Static | Yes | sibling RT-01 | No | **Fix** — optimistic version / JSONB upsert. *Audit said 4 sites; actually **5**.* |
| RT-07 | Entity-write framework + CRM | Medium | No idempotency on entity-write inserts | `runWrite` ignores `Idempotency-Key` (CORS-allowed but consumed only by payments); no leads `(school_id,phone)` unique | `entity_write_store.ts:75-90`; `module_write_handlers.ts:57-90`; `api/index.ts:74`; `20260611100000_admissions_slice1_leads.sql` | Static | Yes | umbrella over RT-01/02 | No | **Fix** — consume the header in `runWrite`; add leads unique |
| RT-08 | Academics / Exam marks | High | Marks accept negative / > max via API | only `Number.isFinite` check; no bound, no DB CHECK | `exam_administration_handlers.ts:301-304`; `exam_administration_repository.ts:421-428`; `20260614800000_pilot_operations.sql:79-92` | Static | Yes | instance of RT-33 | No | **Fix** — server bound `0 ≤ x ≤ max_marks` + CHECK |
| RT-09 | Parent / Academic summaries | Critical | Cross-child academic PII read+write | policy gates only org+school; table keyed per-child `student_id`, no guardian filter | `20260625000000_phase10_school_final.sql:231,240,246-250` | Static (reach=Live) | Yes | root w/ RT-10/11 | No | **Fix** — add guardian pin (pattern exists in `20260725000000`) |
| RT-10 | Parent / Engagement analytics | Medium (was High) | Cross-parent **metric** leak (not child PII) | policy gates only org+school; table keyed `parent_user_id`, no parent pin | `20260626060000_phase15_communication_analytics.sql:70,76,85-89` | Static | Partial — **no parent-scope caller found** | No | RT-09 class | Partial | **Fix (defense-in-depth)** — add `parent_user_id` pin; lower priority |
| RT-11 | Parent / Teacher effectiveness | High | Cross-child meeting-summary leak | same shape as RT-09 (per-child `student_id`, org+school only) | `20260626070000_phase16_teacher_effectiveness.sql:66-67,79-83` | Static (reach=Live) | Yes | RT-09 | No | **Fix** — add guardian (+teacher) pin |
| RT-12 | Communication Hub | High | Parent reads/writes any thread in school | `comm_messages_thread` checks tenant+school+scope but not thread participation; `getThread` org-only | `20260614700000_communication_hub.sql:202-214 vs 216-224`; `communication_repository.ts:429-439`; `communication_service.ts:138,201` | **Live exploit path** | Yes | None | No | **Fix** — add thread-participation `EXISTS` + enforce in `getThread`. **Most serious in Cat B** |
| RT-13 | School Memories | High | Parent/student can write school-wide rows | `FOR ALL` USING allows parent/student scope, no `WITH CHECK`; full CRUD grant | `20260622500000_phase5_foundation.sql:161-184` | Static (reach=Live) | Yes | None | No | **Fix** — `WITH CHECK (scope='school')` for writes |
| RT-14 | Audit / Domain events | Medium | Within-org cross-school event injection | INSERT `WITH CHECK` pins only `organization_id`, not `school_id` | `20260614500000_audit_ingestion_domain_events.sql:74-78,92-96`; domain re-defined still-weak `20260725000000:107-115` | Static | Yes | None | No | **Fix** — add `school_id` to INSERT CHECK (both tables) |
| RT-15 | Platform / secret vault | Low | Platform tables have RLS disabled | tables created without `ENABLE RLS` | `20260625000000_phase10_school_final.sql:99-173` | n/a | **No — not reachable from tenant role** | **Yes — mitigated** | None | **YES (false positive / mitigated)** | **Accept risk** — no-grant verified across ALL migrations; optional defense-in-depth |
| RT-16 | Auth / Session lifecycle | High | Logout/revoke doesn't kill in-flight token | `authenticateRequest` does stateless verify only; `revoked_at` never checked per-request | `permission_middleware.ts:14-35`; `jwt.ts:61-93`; `auth_handlers.ts:484` | Static (Live-confirmable) | Yes | No | root w/ RT-17 | No | **Fix** — per-request session-validity check / short TTL |
| RT-17 | Auth / RBAC lifecycle | High | Role demotion doesn't invalidate token; `permissions_version` dead | perms frozen in JWT; version never compared to live membership; no admin bump | `auth_handlers.ts:115-137,727`; `permission_middleware.ts:42`; `jwt.ts:21,82` | Static (Live-confirmable) | Yes | No | shares RT-16 root | No | **Fix** — compare `permissions_version` per request / re-resolve |
| RT-18 | Entitlements | Medium (was High) | Enforcement env-flag, OFF by default | `withEntitlement` no-ops unless `ENTITLEMENT_ENFORCEMENT=true` | `entitlement_enforcement.ts:12-19`; `entitlement_middleware.ts:131-141` | **Live (per-env)** | Code-accurate | **Yes (pilot) — B2 cert set flag ON on VPS** | None | Partial (config, not code) | **Monitor** — deploy-precondition; verified ON for pilot (`B2_STATUS_LEDGER.md:51`) |
| RT-19 | Payment | Medium | Payment init/confirm auth-only (no perm/scope) | handlers call `authenticateRequest` only; RLS still scopes rows | `payment_handlers.ts:37-74,76-116` (vs gated `:126-138`) | Static (exposure=Live) | Partial (RLS-dependent) | No | None | Partial | **Fix / Needs-live-verification** — add scope gate; confirm payment-table RLS |
| RT-20 | Approval engine | High | `cancel` bypasses per-type approve perm | per-type `requirePermission` wrapped in `if(status!=="cancelled")` | `approval_handlers.ts:276-357` (guard `:293`, perm `:300-303`, cancel `:375-381`) | Static | Yes | No | None | No | **Fix** — require approve/cancel perm outside the guard |
| RT-21 | Audit ingestion | Medium | `/audit/events/batch` auth-only → log injection | `handleAuditBatchUpload` never calls `requirePermission` | `audit_handlers.ts:19-55` | Static | Yes | No | theme w/ RT-22 | No | **Fix** — add permission gate (RLS still tenant-scopes) |
| RT-22 | Director/Promotion/Intel/Approval | Low | Writes gated by *view* slugs | view-slug `gate()` on write paths | promotions `achievement_promotion_handlers.ts:274-308`; meeting-summary `teacher_effectiveness_handlers.ts:149-184`; approvals/audit `approval_handlers.ts:411-459` | Static | Yes (3 of 4) | No | theme w/ RT-21 | **Partial — `/director/summary` is read-only, gate is correct** | **Fix 3 routes** (drop director/summary from the finding) |
| RT-23 | Payment webhook | Low | Signature bypassed in `stubMode` | `if(!valid && !stubMode)`; `stubMode` defaults **true** | `payment_handlers.ts:160-177`; `razorpay_config.ts:11-23` | Static (per-env=Live) | Yes | No | None | No | **Fix / deploy-precondition** — fail-closed; assert stub off in prod |
| RT-24 | All write notifiers | High | No re-entry guard in mutations | `state=AsyncLoading(); state=await guard(...)` with no `isLoading` precheck (grep=**0**) | `teacher_mutations_provider.dart:95-96,126-127,376-377`; `exam_marks_entry_provider.dart:60,88` | Static | Yes | No | **MERGE w/ RT-25** | No | **Fix** — shared mutation mixin w/ `if(isLoading) return` |
| RT-25 | Finance/Teacher/Exam/SIS/etc. | High | Write buttons not disabled in-flight | `canSubmit` flips only after await; no `isSubmitting` in gate | `teacher_attendance_provider.dart:177`; `teacher_attendance_screen.dart:242,349` | Static | Yes | No | **MERGE w/ RT-24** | No | **Fix** — disable on `.isLoading` (template exists: admissions/QR) |
| RT-26 | SIS profile / Finance offline | High | Silently swallowed write errors | `finally`-only / no catch; failure shows nothing | `sis_profile_edit_sheet.dart:127-150`; `finance_offline_payments_screen.dart:145-156,329-350` | Static | Yes | No | None | No | **Fix** — add catch → user-visible failure |
| RT-27 | Transport/Exam/Hostel/Edu/etc. | Medium | Raw `'$error'` shown to users | `SnackBar(Text('$error'))` = `ApiFailureException.toString()` (grep=**48**) | `transport_workflow_actions.dart:52,97,173` + 45 more | Static | Yes | No | None | No | **Fix** — route through `fromFailure`. *Hostel citations were off; transport/exam/edu accurate* |
| RT-28 | Transport/HR attendance | — | Optimistic toggle stays green on failure | **Mechanism refuted** — cited screen uses confirm-dialog write, not optimistic toggle | `transport_attendance_screen.dart:169-179`; `transport_workflow_actions.dart:106-174` | Static (refutes) | **No** | No | **DUPLICATE → RT-24/25/27** | **Partial (mechanism false)** | **Reclassify** — fold residue into RT-24/25/27; no separate fix |
| RT-29 | Core network | Medium | Auth interceptor retries failed write verbatim after 401 | `_retry` replays all verbs incl. POST | `auth_interceptor.dart:71-92,150-160` | Static (dup=Live) | Yes | No | None | No | **Fix** — retry idempotent verbs only / idempotency key |
| RT-30 | All forms | Medium | No browser-refresh/app-kill guard | `beforeunload`=**0**; `UnsavedChangesGuard` in **1** screen; `PopScope` in **2** (auth only) | `akshara_unsaved_guard.dart` (1 usage); greps verified | Static | Yes | No | None | No | **Fix** — apply guard to data-entry forms + web `beforeunload` |
| RT-31 | Storage / uploads | Medium (was High) | App presign sets no contentType/size | edge validates only non-empty filename | `storage_service.ts:54-57,112-113`; `school_memories_handlers.ts:225-227`; `admissions_handlers.ts:902-910` | Static | Yes | **Partly — bucket limits exist** | None | **Partial — "no enforcement" is FALSE** | **Fix (lower)** — bucket size+MIME limits DO exist (`20260622700000`, `20260806000020`); rescope to "validate at presign for early rejection" |
| RT-32 | Cross-cutting forms | Medium | No max-length on any text input | `str()`/`requireStr()` unbounded; 0 VARCHAR, ~682 TEXT, 0/63 client `maxLength` | `module_write_handlers.ts:96-119`; counts re-measured | Static | Yes | No | None | No | **Fix** — bounded-string reader + key-form `maxLength` |
| RT-33 | Cross-cutting entity writes | Medium | `intOr` accepts any finite int | no floor/ceiling; mitigated only where DB CHECK exists | `module_write_handlers.ts:121-133` | Static | Yes | No | overlaps RT-08 (systemic vs instance) | No | **Fix** — min/max params; keep RT-08 separate (different file) |
| RT-34 | Auth / Parent context | Low | Parent children fan-out no LIMIT | 3 unbounded `.in()`/select, no `.limit()` | `auth_context.ts:209-223,245-255` | Static | Yes | No | None | No | **Fix (defensive)** — `.limit(50)`; low real risk |
| RT-35 | Backend infra | High | No DB connection pooling (per-request connect) | `new Client → connect → end` per request; port 5432 not 6543; no pooler | `tenant_db.ts:89-108,119-121`; `.env.akshara.example:35` | Static (cliff=Live) | Yes | No | None | No | **Fix** — route via transaction-mode pooler (6543) / pool |

---

## Cross-check against prior certifications

The audit was run at HEAD `4f7f821`, **after** every prior certification (B1–B11, Engineering Waves 0–5, Journey Waves 0–5, Onboarding & Dynamic Config, Pilot School Simulation). So by construction these findings are *residual* — defects that survived the certs — and almost none were "already fixed." The meaningful intersections:

- **RT-18 (entitlement enforcement) ↔ Batch B2.** B2 was certified with `ENTITLEMENT_ENFORCEMENT=true` set on the live `akshara-edge` (`docs/B2_STATUS_LEDGER.md:51`, `docs/B2_STEP5_CERTIFICATION.md:67`). The finding is accurate about the *code default* (off) but **the production pilot already runs with the flag ON**. → Reclassify as a deployment-precondition (Monitor), not a code bug. Bites only un-configured environments.

- **RT-09 / RT-11 (parent-scoped RLS) ↔ Batch B3 + Journey Wave 5.** B3 established the canonical `student_guardians` parent-scope pattern; Journey Wave 5 added parent-correction RLS on the same pattern. The project even retrofitted the *correct* guardian-scoped policy onto `parent_insight_snapshots` in `20260725000000_parent_insights_parent_scope_rls.sql`. **It was simply not applied to the structurally identical `parent_academic_summaries` (RT-09) and `parent_meeting_summaries` (RT-11)** — newer phase10/16 tables that the parent-scope cert never touched. So the fix pattern is proven and copy-pasteable, but the gap is real.

- **RT-15 (platform tables) — already mitigated.** Verified across *all* migrations: no `GRANT … TO erp_tenant`, no `GRANT ON ALL TABLES`, no `ALTER DEFAULT PRIVILEGES` touches the platform secret tables. The edge runtime's `erp_tenant` role (NOSUPERUSER/NOBYPASSRLS) has zero privilege on them, so RLS is moot. This matches the auditor's own "latent, mitigated" label → **false positive for current exploitability.**

- All other findings: **No** prior cert fixed them. Transaction rollback, division-by-zero guards, empty-state reads, and the RBAC write-route sweep (verified-safe section of the audit) remain accurate — those areas are genuinely clean.

---

## Deduplication & systemic root causes

The 35 findings collapse onto a smaller set of root causes. Fixing the root cause once resolves the cluster:

1. **`count(*)+1` / `MAX+1` ID generation** → **RT-03, RT-04, RT-05** (and contributes to RT-02). One pattern fix (UUIDs / sequences / retry-on-conflict).
2. **Read-then-write with no row lock or idempotency** → **RT-01, RT-02, RT-06, RT-07** (RT-07 is the framework-level umbrella; RT-01/02 are concrete money/identity hotspots). Keep RT-07 separate (covers the whole entity-write framework + `admissions_leads`).
3. **Unbounded numeric/text input** → **RT-08 (instance), RT-32, RT-33 (systemic).** RT-08 does *not* route through `intOr`, so it needs its own fix even after RT-33.
4. **Parent-scoped RLS missing the per-child/per-parent pin** → **RT-09, RT-10, RT-11** (one migration, guardian-pin pattern already exists).
5. **Stateless JWT claims never re-checked at request time** → **RT-16, RT-17.** Single fix in `authenticateRequest` (consult `revoked_at` + compare `permissions_version`).
6. **Client double-submit** → **RT-24 + RT-25 MERGED** (notifier layer + button layer, one shared mutation pattern). **RT-28 folded in** as a duplicate (its unique "optimistic toggle" mechanism does not exist in the code).
7. **Security behavior hinging on an env flag that defaults unsafe** → **RT-18, RT-23.** Deploy-precondition checklist items.

**Explicit merges/removals applied to the count:** RT-24 + RT-25 → 1 finding; RT-28 → removed (duplicate of RT-24/25/27); RT-15 → removed (false positive / mitigated). Net 35 → **32 distinct genuine issues**.

---

## Findings needing live verification (carry into the relevant wave's VPS step)

- **RT-09 / RT-10 / RT-11 / RT-13** — confirm whether a parent/student-scope edge route actually reaches these tables under persona context (the DB-layer gap is unambiguous regardless; RT-10 has *no* parent caller found, lowering its real exposure).
- **RT-12** — confirm the live cross-family thread read/write with a 2-parent fixture (static analysis already found a concrete exploit path via `handleParentSendMessage`).
- **RT-18 / RT-23** — confirm the env values (`ENTITLEMENT_ENFORCEMENT`, `RAZORPAY_STUB_MODE`, Razorpay creds) on every target deploy.
- **RT-19** — confirm whether a low-privilege same-tenant user can reach another payer's payment intent (depends on `payment_intents` RLS, not validated here).
- **RT-31** — confirm the two bucket-policy migrations were actually applied to the VPS Storage buckets (size+MIME limits exist in-repo).
- **RT-35** — load-test to quantify the connection-exhaustion threshold.

---

## Final prioritized list (validated)

Re-prioritized by **validated** blast radius and reachability. This is the recommended fix order; it refines (does not overturn) the roadmap's wave structure.

### Priority 1 — Real production blockers (silent corruption / money / reachable cross-family PII)
| RT | Why P1 |
|---|---|
| **RT-01** | Duplicate / lost fee collection — money corruption, negative outstanding |
| **RT-02** | Duplicate student identity — splits attendance/marks/fees across copies |
| **RT-09** | Cross-child academic PII read **and** write (Critical, DB-layer unambiguous) |
| **RT-11** | Cross-child meeting-summary leak (same shape as RT-09) |
| **RT-12** | Cross-family message read/write — **confirmed live exploit path** |

### Priority 2 — High-risk, not an immediate blocker
| RT | Why P2 |
|---|---|
| **RT-03, RT-06** | Concurrency 500s / silent lost records (integrity) |
| **RT-08** | Corrupt grades via API (negative / >max) |
| **RT-13** | Unauthorized school-wide write surface |
| **RT-16, RT-17** | Stale-token window — revoke/demotion ineffective ≤15 min |
| **RT-20** | Non-approver can cancel any approval (workflow DoS) |
| **RT-24+25** (merged) | Client double-submit — amplifies RT-01/02 |
| **RT-26** | Silent write failures (user re-taps → compounds duplicates) |
| **RT-35** | DB-connection scaling cliff (fine at pilot, fails under spike) |

### Priority 3 — Medium improvements
| RT | Why P3 |
|---|---|
| **RT-04, RT-05, RT-07** | `count+1` / idempotency on non-money entities |
| **RT-10** | Parent-metric leak (defense-in-depth; no caller found) |
| **RT-14** | Within-org cross-school audit/event integrity |
| **RT-18** | Entitlement flag assurance (ON for pilot; document as precondition) |
| **RT-19** | Payment-intent authorization gate (RLS-dependent) |
| **RT-21** | Audit-batch ingestion gate |
| **RT-22** | View-slug write gates (3 routes; director/summary excluded) |
| **RT-27** | 48 raw-error leaks to users |
| **RT-29** | Verb-agnostic auth retry (narrow dup window) |
| **RT-31** | Presign early-rejection (bucket limits already enforce caps) |
| **RT-32, RT-33** | Input length/numeric bounds |

### Priority 4 — Low-risk polish
| RT | Why P4 |
|---|---|
| **RT-23** | Webhook stub-mode bypass (deploy-precondition) |
| **RT-30** | Unsaved-changes / `beforeunload` guard |
| **RT-34** | Parent fan-out `.limit()` (low real risk) |
| **RT-15** | RLS-on-platform-tables (already mitigated; optional defense-in-depth) |

---

## Conclusion

The Red Team audit is **validated as accurate and actionable.** Of 35 findings: **27 confirmed verbatim, 6 partially-correct (real but need a severity/scope/mechanism correction), 1 false positive (RT-15), 2 removed via dedup (RT-24/25 merge, RT-28 fold)** → **32 distinct genuine production issues.** No Critical was overturned; the only corrections that move severity *down* are RT-10 (no parent caller), RT-18 (env-mitigated on pilot), RT-31 (bucket limits exist) — and two corrections moved the audit's accuracy *up* (RT-06 = 5 sites, RT-07 idempotency genuinely unused).

The recommended wave order in `RED_TEAM_COMPLETION_ROADMAP.md` (integrity → RLS → auth → client → input/scale, by blast radius) **still holds**. The within-wave refinements are recorded in the roadmap's new reconciliation note.

**No fix has been started. No code modified. Awaiting owner approval before touching code or starting Wave 1.**
