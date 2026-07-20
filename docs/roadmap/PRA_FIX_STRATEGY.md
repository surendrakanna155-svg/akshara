# PRA FIX STRATEGY — Root-Cause Optimization of the Product Reality Audit

**Status:** 🔵 **DRAFT for owner review — planning only, no code written.** · **Date:** 2026-07-17
**Companion to:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) → §PROGRAM PRA (the frozen 117-item register).
**Purpose:** regroup the 117 audit items by **root cause** (not module), identify the **minimum set of structural changes** that eliminate the **maximum number of items**, and estimate effort / regression risk / items-closed per change. Implementation has **not** begun.

> **Method note.** Every claim below was checked against source. Where possible the defect was **executed**, not inferred: the route-shadow was reproduced with a Deno harness (both routers returned `MATCHED (HTTP 401)` for the same request); the pilot test suite was run (**127 passed / 0 failed** — proving the coverage gap, not correctness). Two root-cause sweeps completed; four were cut short by a session usage limit and were finished inline by the orchestrator (money-guards, lifecycle confirmed by direct search; canonical + claims characterized from confirmed evidence — see §7 for the honest residual gap).

---

## 0. The headline

The 24 P0s are not 24 projects. **Nine themes** account for all 117 items, and the leverage is extreme: **~10 structural changes close ~60 of the 117 items.** But three findings from this phase change the plan materially, and must be read before any code is touched:

1. **The register's prescribed fix for `PRA-P0-11` is wrong and would take the mobile app down.** It says "validate `classLabel` against `listTeacherClassLabels`." That function reads `timetable_slots` — the table with **zero code writers** (`PRA-P0-07`). Applied as written, every teacher write fails closed for every real tenant. **`PRA-P0-07` must be fixed before `PRA-P0-11`, and the ownership oracle must be `teacher_subject_assignments`, never `listTeacherClassLabels`.** (§Theme 1.)

2. **"The fix is usually deletion" is true for exactly one route.** The pilot lane looked like a shadow of the governed lane; on execution, **13 of its 14 routes are the *only* implementation** — `routeTeacher`/`routeParent` return 404 for them. Deleting them 404s the app. Only `PUT /teacher/exams/marks/:id` is a true shadow. The rest must be **governed in place**, not deleted. (§Theme 1.)

3. **Two new money races and two coupling traps were found.** Fixing a headline P0 *activates* a latent one unless they ship together: fixing `PRA-P0-02` (payment wiring) without guarding payment-capture creates a double-collection race; fixing `PRA-P1-54` (vault) without `PRA-P2-30` (base64) exposes secrets. (§Theme 3, §Coupling.)

**Net new findings this phase:** 2 money-race instances + 12 live-mock/bypass sites + 1 benign route shadow + 1 dead handler = **16 new**, listed in §6. They do not yet have `PRA-*` IDs; adding them is a register amendment for owner sign-off (freeze law).

---

## 1. Theme leverage summary (ordered by ROI)

| # | Theme | Primary items closed | New items | Effort | Risk | One-change leverage |
|---|---|---|---|---|---|---|
| **T1** | Govern the pilot mobile-write lane | P0-07, P0-11, P0-12 | +3 | **L** (T1c) / S (T1a,b) | Med–High | 3 P0 + kills a whole invisible-shadow class |
| **T2** | Sever demo scaffolding from live providers | P0-05, P0-06, P0-08, P0-09, P0-10, P0-17, P1-32 | +12 | **L** (cluster A) | Med–High | 7 items; cluster D = 2 items in **3 lines** |
| **T3** | Money terminal-write guard discipline | P0-03, P0-04, P2-10 | +2 | **M** | Med | 5 money races, one proven pattern |
| **T4** | Access / relationship lifecycle (reversal) | P0-01, P1-02, P2-34 | 0 | **M** | Med | 1 revocation service ⇒ 3 items, 3 modules |
| **T5** | Repair the online-payment wiring | P0-02 | (+M-2 guard) | **M** | High | the single worst money defect |
| **T6** | Consolidate canonical metrics | P0-22, P0-23, P1-47, P2-22 | +? (see §7) | **M** | Med | 4 dashboard-integrity items |
| **T7** | Delete-the-lie: fake integration claims | P0-16, P0-24, P1-40, P1-50, P1-55 | +2 | **S–M** | Low | 5 items, most by deletion |
| **T8** | Server-persist school settings | P1-08, P1-13, P1-33, P1-34, P2-12 | 0 | **M** | Low | 5 items, one persistence mechanism |
| **T9** | Real notification delivery | P0-18, P1-45 | 0 | **M** | Med | reaches parents at all |

The remaining ~40 items (mostly P1/P2 that are genuine single-feature builds — TC board fields, ID cards, question-bank seeding, promotion engine, staff attendance adapters, multi-school provisioning) are **not** theme-collapsible; they are listed in §8 as standalone work, honestly.

---

## Theme 1 — Govern the pilot mobile-write lane  ·  **the structural spine**

**Root cause.** `supabase/functions/_shared/pilot/pilot_operations_*` (4,321 LOC) is not a demo side-lane — it is the **production write path** for the entire teacher/parent/student mobile surface (attendance draft/submit, teacher leave, parent leave, student homework submit, teacher homework ×6, exam marks), and its `attendance_sessions`/`attendance_records` tables are the **sole source** feeding management, analytics, intelligence, director and SIS-360. It grew separately from the governed module routers, so: (a) one route is a true duplicate that shadows the certified handler; (b) its writers check *permission* but never *class ownership*; (c) there is **no canonical teacher→class binding** — three rival models exist; (d) **no test exercises the ordered dispatch loop**, which is why the shadow was invisible.

**Evidence (executed).** Deno harness: `routePilotOperations` and `routeTeacher` both return `MATCHED (HTTP 401)` for `PUT /teacher/exams/marks/:id`; `app.ts:121` (pilot) precedes `:158` (teacher); loop returns on first match (`:168-172`) → the unscoped `handleTeacherExamMarkUpdate` wins every request. Pilot suite: **127/0** green, because tests assert permission and stop at "503 to DB" — never reaching the ownership check.

**Three rival teacher→class models** (pick one canonical): `timetable_slots` (**zero writers**), `teacher_assignments` (real writer `POST /academic/teacher-assignments`), `teacher_subject_assignments` (real writer `POST /school/teacher-subject-assignments`, **already the exam engine's oracle** → strongest candidate).

| Sub-fix | What | Closes | Effort | Risk |
|---|---|---|---|---|
| **T1a** | Delete the duplicate `PUT /teacher/exams/marks/:id` from `pilot_operations_router.ts:103-109` (+ its handler + pilot `updateExamMark`) so the certified `applyMarkUpdate` runs. Also delete dead `handleMessages` (benign shadow, §6 N-13). | **P0-12** | **S** (~½d) | **Med** — fail-closed adoption: a plain teacher is scoped against `teacher_subject_assignments`; a tenant that skipped the school-completion wizard 403s on mark entry (same behaviour already ships on `/academics/exams/*`). The client response *improves* (N-16). |
| **T1b** | One table-driven test over `moduleRouters` asserting no two routers match the same `(method, path)`. | 0 (prevents recurrence of the entire shadow class) | **S** (~½d) | **Low** — highest value/line here; would have caught both shadows. |
| **T1c** | Adopt `teacher_subject_assignments` as the canonical binding; point the `timetable_slots` readers (and mobile timetable reads) at it or sync it; **then** add `classLabel`/subject validation to the pilot writers. | **P0-07, P0-11** | **L** (>1wk) | **High** — construction, not deletion; touches the reporting trunk. |

**Ordering (mandatory):** T1a and T1b first (independent, S, low-risk). **T1c: `PRA-P0-07` before `PRA-P0-11`** — reverse order fails every teacher write closed. Do **not** use `listTeacherClassLabels` as the oracle.
**Does NOT belong here:** `PRA-P1-31` (teacher pending-list ignores day-of-week) is an ordinary missing `WHERE day_of_week = …` — a one-line fix that rides along, not a structural item. `timetable_slots` also underlies `PRA-P0-07`/`P0-08`; the canonical-binding work in T1c is a prerequisite for the timetable half of T2 cluster A.

---

## Theme 2 — Sever demo scaffolding from live production providers

**Root cause.** There is **no architectural boundary** preventing a live Flutter provider from constructing demo state (`analysis_options.yaml` is 6 lines; no `custom_lint`/`import_lint`; CI has no mock-import check). It's *a convention, not a constraint.* Three bypass mechanisms exist — `?? Mock…` default params, **unconditional `Mock…` returns inside `repository_providers.dart` itself** (`:376-381`), and **silent `catch → mock` inside the production API repo** (`api_parent_repository.dart:283,313,328`). **6 of the 8 load-bearing demo stores live *outside* `lib/core/repositories/mock/`**, so an import-lint scoped to that directory catches only 2 of 8 — the guard must be symbol/pattern-based.

**Clusters (each a shared fix):**

| Cluster | Items | Fix | Effort | Risk |
|---|---|---|---|---|
| **A. Teacher identity** (unify with T1c) | P0-10, P0-08, P0-09, N-1…N-6 (§6) | One **server-resolved teaching context keyed by user id** + a real teacher-directory repo. Same canonical binding as T1c serves both backend scope and Flutter identity. P0-09 also needs the missing FK on `academic_timetable_periods.teacher_id`. **P0-10 taints live writes** (`authorName` trusted server-side) → there is existing corrupt data to reconcile. | **L** | **High** |
| **B. Report card** | P0-06 (×2), P1-32 | One server-backed published-results source; `parent_exams_provider.dart:17` already does it correctly — copy it. | **M** | Med |
| **C. Approval adapter** | P0-05, N-9 | Inject `examAdministrationRepositoryProvider`; add `skipDomainEffects` to `enrichDetail`. | **S** | Low |
| **D. Platform mock repos** | N-7, N-8 | **3 lines in `surface_backend_gate.dart`** — the gate already handles exactly this. | **S** | Low — **best ROI in the whole plan.** |
| **E. API silent fallback** | N-10 | Delete the `catch → mock` fallback; fail closed. | **S** | Low |
| **F. Comms history** | P0-17 | Datasource method + provider switch (backend already shipped). | **S** | Low |
| **H. Recurrence guard** | — | Symbol-based lint banning demo-store imports from `lib/features/**` + a CI grep; `test/` exempt. Closes 0 items; prevents the class returning. | **S** | Low |

**Sequencing:** D → C → E → F (all S, days, close P0-05/P0-17 + 4 new) **before** A. Land guard H right after D. **Cluster A merges with Theme 1's T1c** — do not build the teaching-context resolver twice.
**Adjacent:** `PRA-P1-13` (grading scale) shares the `ExamAdministrationStore` process-singleton root but its fix is server persistence → **assigned to T8**, not here (avoids double-count).

---

## Theme 3 — Money terminal-write guard discipline

**Root cause.** A terminal state-write with no status predicate in its `WHERE`, over a row read without `FOR UPDATE`, at **READ COMMITTED** (`tenant_db.ts:123` bare `BEGIN`) → concurrent double-apply of a money delta. The **proven-correct** reference is `finance_fee_reductions_repository.ts:421` (`AND status='pending'` + throw-on-0-rows).

| Site | Verdict | Detail |
|---|---|---|
| `finance_refunds_repository.ts:372` (**P0-03**) | VULNERABLE | plain read, terminal write no `AND refund_status='pending'`; delta at :344-349. |
| `finance_collections_repository.ts:707` (**P0-04**) | VULNERABLE | guard `AND ($6 IS NULL OR row_version=$6)` vacuous — client never sends `expectedVersion`. |
| `inventory_finance_repository.ts:341` (**P2-10**) | VULNERABLE | GRN over-receipt TOCTOU; no `FOR UPDATE`, no upper-bound CHECK. |
| `inventory_distribution_repository.ts:368` fulfil (**NEW M-1**) | VULNERABLE | `loadReplacementRequest:288` plain SELECT; terminal `SET replacement_status='fulfilled'` no status predicate; calls stock-decrementing `createDistribution`. Concurrent double-fulfil double-issues stock / re-bills. |
| `payment_repository.ts:208` capture (**NEW M-2**) | VULNERABLE (latent) | `SET status='captured'` no `AND status<>'captured'`. Harmless only while P0-02 keeps `createCollection` dead; **becomes a double-collection race the instant P0-02 is fixed.** |
| `finance_late_fee_repository.ts:123` accrual | **REFUTED — GUARDED** | read is `FOR UPDATE OF fi` with `AND late_fee_amount = 0`; the account delta serializes behind the invoice lock. Not a finding. |

**Central-fix verdict.** Raising `tenant_db.ts` to `SERIALIZABLE` would close the class in one line **but** requires serialization-failure retry handling everywhere and would abort reads that currently succeed — high blast radius, rejected. The correct fix is **per-site application of the proven pattern** (`AND <status>='<pre>'` + throw-on-0-rows, + `FOR UPDATE` where a delta depends on the read) plus **one regression test per site** that fires two concurrent applies and asserts one succeeds. ~5 sites, one well-understood shape. Effort **M**, risk **Med** (a status guard could break a test that re-approves an already-approved row — audit those first).

---

## Theme 4 — Access / relationship lifecycle (reversal)

**Root cause.** The system can create every relationship and reverse none: enforcement checks are correct but **no runtime writer ever sets the state they check** (confirmed by search — zero `UPDATE school_memberships SET status` and zero `UPDATE/DELETE student_guardians` in `functions/`).

| Item | Dead gate | Fix |
|---|---|---|
| **P0-01** | `school_memberships.status` checked at `session_validation.ts:112-119`, never written | Permission-guarded revoke → `status='revoked'` + sweep that user's `sessions`/`refresh_tokens`, wired to HR offboarding. |
| **P1-02** | `student_guardians.status` gated in RLS, only ever INSERTed | Unlink writer → `status='inactive'`. **Ordering:** the finance and exam RLS policies (`20260704000000:23-27`, `20260703100000:30-34`) omit the `sg.status='active'` clause — **the RLS fix must land WITH the unlink writer**, or unlink silently leaks fees/marks. |
| **P2-34** | `permissions_version` compared but never bumped at runtime | DB trigger on role/override change. |

**One revocation capability closes P0-01 + P1-02** (two endpoints, one session/token-sweep helper). **Blast radius:** adding a membership revoker *activates* `session_validation`'s membership check in production for the first time — safe because the sole existing writer hardcodes `'active'` (all rows pass), but run a one-time audit for NULL/legacy statuses before shipping. Certificate-void (`PRA-P1-22`) and exam-unpublish (`PRA-P1-12`) are the same *theme* but separate *domain workflows* — keep them standalone (§8). Effort **M**, risk **Med**.

---

## Theme 5 — Repair the online-payment wiring  ·  *the single worst money defect*

**Root cause.** `payment_service.ts:113` hardcodes `invoiceId: null` → the `if (intent.invoice_id)` capture gate is always false → no `finance_collections`/`finance_receipts` row is ever written, and the parent is shown a fabricated `APS-…` receipt (`:238`). The Flutter client compounds it: `submitMockPayment` fabricates its own `transactionRef` and no gateway SDK exists.

**Fix.** Resolve the installment's invoice and persist it on the request/intent; **fail closed** when unresolvable; integrate a real gateway SDK so confirm carries a verified payment id + signature. **Couple with Theme 3 M-2:** guard the capture write in the same change, or fixing this opens a double-collection race. Effort **M**, risk **High** (money path + external SDK + needs a live gateway test). This is largely standalone — not theme-collapsible — but it is the top priority by impact.

---

## Theme 6 — Consolidate canonical metrics

**Root cause.** Business metrics are re-implemented inline per consumer instead of importing the one canonical function. The canonical `attendance/attendance_percentage.ts` has **8 correct importers**; `management_aggregate_repository.ts:87-95` re-implements it wrongly (counts `excused` as attended, drops `half_day`).

| Item | Kind | Fix |
|---|---|---|
| **P0-22** | wrong formula | replace inline SQL with `attendancePercentSql`/`attendedDaysSql`. |
| **P2-22** | wrong formula | per-class column must group, not reuse the school scalar. |
| **P0-23** | wrong period | "Revenue MTD" needs a month-scoped aggregate (formula is fine, scope is wrong). |
| **P1-47** | wrong definition | Management "defaulters" must reuse Finance's `daysOverdue > 0` count. |

Distinguish **wrong-formula** (import the canonical) from **wrong-period/scope** (needs a scoped aggregate) — different fixes. **Recurrence guard:** a cross-screen metric-consistency test. Effort **M**, risk **Med** (tests asserting the current wrong numbers will need re-baselining; goldens are clean — the `management_dashboard_*` failure artifacts are unrelated working-tree noise). ⚠ **Residual depth gap:** `analytics_metrics_service.ts` and `intelligence/priority/parent_sources.ts` compute attendance without importing the canonical — **candidate** new divergences, not yet confirmed (§7).

---

## Theme 7 — Delete-the-lie: fake integration claims

**Root cause.** Handlers/seeds return hardcoded strings or a success status claiming work that never happens. **Most of these are closed by deletion — cheap, immediately honest, near-zero risk.**

| Item | Claim | Recommendation |
|---|---|---|
| **P0-24** | payroll "posts to Finance FN-05"; dead `/finance/payroll` link | Delete the claim + dead link now (S); implement real ledger posting later (separate, L). |
| **P1-40** | library fines "sync to Finance" | Delete the claim; add an explicit cash-collection action later. |
| **P0-16** | teacher "Send to parent" returns `{status:"sent"}`, delivers nothing | **Do NOT just delete** — implement real enqueue (belongs with Theme 9); the false `sent` is the dangerous part. |
| **P1-50** | "Email report" preview-only snackbar (7+ screens) | Remove the buttons until the pipeline exists. |
| **P1-55** | "Export package" snackbar, no repository import | Remove the button; implement tenant export later (separate). |
| **N-11** (§6) | parent notice "acknowledge" faked locally | Delete the fallback; fail closed (overlaps Theme 2 cluster E). |

Split verdict per item: **delete-the-claim** = S/Low (P0-24 claim, P1-40, P1-50, P1-55); **implement** = separate larger builds. Closes 5 register items on the honesty axis; the real implementations are tracked as standalone (§8).

---

## Theme 8 — Server-persist school settings

**Root cause.** School-configurable settings are stored device-local, in-memory, or nowhere, so they silently do nothing. A per-school persistence mechanism already exists (`school_config` / `finance_settings`) and should be reused.

Closes **P1-13** (grading scale — currently an unpersisted singleton), **P1-08** (receipt prefix — zero consumers), **P1-33** (HR settings read-only), **P1-34** (leave policy hardcoded), **P2-12** (borrowing limit not per-role). One persistence pattern + wiring each consumer to read it. Effort **M**, risk **Low** (additive; each setting currently does nothing, so wiring it can't regress existing behaviour). ⚠ **Residual depth gap:** a full settings census was cut short by the session limit (§7) — expect a few more DEAD/READ-ONLY settings.

---

## Theme 9 — Real notification delivery

**Root cause.** The delivery substrate is push-only and, in the teacher→parent path, doesn't deliver at all. Closes **P0-18** (transactional SMS ignores DLT — TRAI compliance), **P1-45** (broadcasts push-only, no SMS/email fallback), and the delivery half of **P0-16**/**N-11**. A working SMS provider exists but is unreachable from the broadcast path. Effort **M**, risk **Med** (external SMS + DLT template registration is partly an ops task — see `PRA-P2-20`, the cron activation). Note `PRA-P0-17` (history) is **Theme 2**, not here.

---

## 6. New findings discovered this phase (need `PRA-*` IDs — owner sign-off per freeze law)

| # | Sev | Finding | Evidence |
|---|---|---|---|
| **N-1..N-6** | P1 | Teacher-identity fixture cluster reachable beyond the 3 named screens: `teacher_dashboard_provider.dart:322` renders `.mock()` (name "Priya Sharma") on any API error; `teacher_teaching_context_provider.dart:76` **throws for every real student** (comment claims "graceful fallback" — false); `teacher_student_risk_service.dart` reads 5 demo stores; `class_teacher_assignment_screen.dart:24` picker offers only 3 fixture teachers. | live-mock sweep |
| **N-7** | P1 | `repository_providers.dart:376-381` returns `MockBranch/MockFranchiseRepository` **unconditionally** (no flag); routes not surface-gated → live admin sees fabricated dashboards. | " |
| **N-8** | P2 | `resource_optimization_providers.dart:11` unconditional mock (calls real AI pipeline but fabricates on parse-fail). | " |
| **N-10** | P1 | `api_parent_repository.dart:313,328` — parent's **acknowledgement of a school notice is faked locally** on `catch`, no server record, no error (same unwinnable-dispute shape as P0-16, parent side). | " |
| **N-9** | P2 (masked) | `exam_results_approval_adapter.dart:113` `enrichDetail` lacks `skipDomainEffects` → "Exam session not found" for real exams; **surfaces the moment P0-05 is fixed.** | " |
| **N-11** | P1 | `finance_admissions_handoff_provider.dart:52` writes only StateProviders + a mock bridge — no server write, no flag. | " |
| **N-12** | P2 | `admissions_enrollment_provider.dart:108` mock write-store read after a real submit → `admissionsLastApprovalIdProvider` never set in prod. | " |
| **N-13** | P2 | `GET /teacher/messages` shadowed by `routeCommunication`; `teacher_handlers.ts:146 handleMessages` is **dead code** (benign — winner is the governed one). | pilot sweep |
| **N-14** | — | **No test exercises the ordered dispatch loop**; `teacher_router_test.ts:59` asserts a route production never reaches. (Recurrence root of the shadow class.) | pilot sweep |
| **N-15 (M-1)** | P1 | Inventory replacement **fulfil** double-apply race (unguarded terminal + no `FOR UPDATE` + stock-decrementing `createDistribution`). | money sweep |
| **N-16 (M-2)** | P1 (latent) | Payment **capture** write unguarded — double-collection race the moment P0-02 is fixed. | money sweep |

---

## 7. Honest residual gaps (finish after the session-limit reset, before freezing this strategy)

The session usage limit cut four sweeps short. Two were completed inline with high confidence (money, lifecycle). Two are characterized from confirmed seed evidence but **not exhaustively swept**:

- **Canonical metrics (T6):** confirmed the attendance divergence and measured canonical adoption (8 importers), but `analytics_metrics_service.ts` and `parent_sources.ts` are **unconfirmed candidate** divergences, and fee/exam-rank/occupancy metrics were not swept for duplication. **Action:** one focused sweep to close the census.
- **Claims + settings (T7/T8):** seed set confirmed; a full census of claim-strings and configurable-settings surfaces was not completed. Expect a handful more DEAD settings and dead-link claims.

These do not change the theme structure or the top-priority ordering; they may add a few P1/P2 items to T6/T7/T8.

---

## 8. Items that are genuinely standalone (not theme-collapsible)

Honest accounting — these are single-feature builds, one fix each, no shared root: TC board-mandated fields (P1-21), TC void/reprint (P1-22), ID cards (P1-23), certificate logo (P2-03), admissions seat/quota/waitlist (P1-24), application fee (P1-25), promotion-engine contract repair (P0-14), staff GPS/face adapters (P0-15), exam post-publish correction (P1-12), grading-into-report-card wiring, question-bank seeding (P1-27), QP reachability/nav (P1-26), homework storage bucket (P1-30), multi-school branch provisioning (P1-51/P1-52), audit-log read UI (P1-53), vault repair (P1-54, **couple with P2-30**), tenant export (P1-55 impl), transport vehicle-route assignment (P0-19) + fee-demand trigger (P0-20). Roughly **40 items**. Several are individually large (P0-14, P0-15, P0-19/20, P1-51/52).

---

## 9. Coupling traps (ship these pairs together — or a fix creates a defect)

1. **P0-02 + M-2** — repair payment wiring *and* guard the capture write together, or you open a double-collection race.
2. **P1-54 + P2-30** — repair the vault *and* replace base64 with real encryption together, or you convert a dormant issue into live secret exposure.
3. **P0-07 → P0-11** — order, not pairing: the timetable-table fix must precede the ownership check, or every teacher write fails closed.
4. **P0-05 → N-9** — fixing the approval adapter surfaces the masked `enrichDetail` bug; fix both in the same pass.
5. **P1-02 RLS + P1-02 writer** — the two RLS policies missing the status clause must be fixed *with* the unlink writer, or unlink silently leaks.

---

## 10. Recommended execution order (regression-gated per theme)

1. **Cheap, high-certainty, decoupled first:** T2-D (3 lines), T1a + T1b (delete shadow + dispatch test), T2-C/E/F, T7 delete-the-claim items, T2-H guard. — days, mostly S, closes ~10 items with low risk. Full regression after this batch.
2. **The money block:** T3 (all 5 races, one pattern) + T5 (payment wiring, coupled with M-2). Full regression + a concurrency test per site.
3. **The lifecycle block — Workstream ILR [✅ C1 approved]:** the single revocation primitive (membership/guardian status writer + session/token sweep + the two RLS status-clause fixes + perms_version trigger) closing PRA-P0-01 + P1-02 + P2-34, and serving as the base SOP-ID-2/ID-5-core consume. Fix **PRA-P1-07** (harden `handleContextSwitch` through `assertSessionValid`) in this block too — it is the pre-GA close of the auth-bypass and satisfies the **[✅ C2]** constraint that SOP-ID-3 may not ship before P1-07 is closed.
4. **The structural build:** T1c ∪ T2-A (canonical teacher→class binding — one resolver serving backend scope and Flutter identity; **P0-07 before P0-11**). This is the long pole; isolate it. **[✅ C3]** gate: no SOP-F4 "done" claim until P0-05/07/11/12 are closed here and in the exam fixes.
5. **Consolidation + settings + delivery:** T6, T8, T9.
6. **Standalone builds (§8)** as prioritized by the owner.

**Full regression after every theme**, per the owner's directive. No theme starts until the prior theme's EOS gate passes.

---

---

## 11. Reconciliation with Program SOP (parallel audit, 2026-07-17)

The parallel audit produced **Program SOP** (`PROGRAM_SOP_IDENTITY_AND_PLATFORM.md` + `IDENTITY_AND_LOGIN_ARCHITECTURE_AUDIT.md`, and a new §PROGRAM SOP in the master roadmap): **Track A** = identity/login/user-lifecycle (SOP-ID-1..5, 8 gaps G1–G8), **Track B** = operational feature suite (SOP-F1..12). Its own Decision Register §4-D4 already reconciled some overlaps. This section records the reconciliation *it missed*, the cross-audit couplings, and the merged execution shape. **No frozen row is deleted or re-scoped here — the approvals below are planning decisions; the frozen PRA/SOP rows remain physically unmodified until explicit owner sign-off to edit them.**

> **APPROVAL STATUS (owner, 2026-07-17) — planning decisions, implementation NOT authorized:**
> - **C1 — APPROVED** as the merged **Workstream ILR (Identity Lifecycle & Revocation)**.
> - **C2 — APPROVED** as a mandatory implementation dependency / ordering constraint.
> - **C3 — APPROVED** as a mandatory implementation dependency / ordering constraint.
> - **C4 — PENDING** — bound to owner decision **D2**; do not resolve or implement until D2 is finalized.
> - **D1 (OMR)** and **D2 (SOP placement)** remain PENDING and not approved.
> These approvals update the *implementation plan only*. No frozen roadmap record is mutated; implementation begins only on final owner authorization.

### 11.1 Owner-decision status — confirmed PENDING, not treated as approved
- **D1 (Smart OMR — SOP-F1/F2/F3):** ⛔ PENDING. Would reverse frozen *Assessment-Intelligence D2* ("OCR/OMR not pursued"). Not approved; F1/F2/F3 must not be built on this assumption.
- **D2 (SOP execution placement/sequencing):** ⛔ PENDING. The proposed "Track A before P4/P6, Track B before FREEZE-1" shape is *recorded, not adopted*.
- **D3 (student-via-parent login alignment):** confirmation only — closes *toward* the frozen identity decision; no conflict.
- **D4 (anti-duplication):** partially applied by SOP; **extended below.**
- Verified not-treated-as-approved: SOP is excluded from the Wave-Ledger; ledger unchanged at 53.5%; all SOP items ⚪/📋. ✅

### 11.2 Overlap map — SOP items ↔ PRA items (⚠ = link the SOP audit missed)

| SOP item | PRA / Theme it overlaps | SOP caught it? | Disposition |
|---|---|---|---|
| SOP-ID-2 (transfer/exit deactivates membership+guardian) | **PRA-P2-28** (inter-school transfer) + **⚠ PRA-P1-02** (guardian unlink) + **⚠ Theme 4** (revocation writer) | P2-28 only | **✅ C1 APPROVED — consumes Workstream ILR** (deactivation writer = the ILR primitive applied to transfer) |
| SOP-ID-3 (multi-school selector; wire `context/switch`) | **PRA-P1-04**, **PRA-P1-51/52**, **PRA-P2-27** + **⚠ PRA-P1-07** (context-switch bypass) | all but P1-07 | **✅ C2 APPROVED — ID-3 may not ship before P1-07 is fixed** (see 11.3-C2) |
| SOP-ID-4 (student-via-parent login) | frozen *Student Identity Architecture Decision*; PRA "student login compliant" | — | **Not a conflict:** see 11.3-C5 |
| SOP-ID-5 (identity-ownership + lifecycle + audit events) | **⚠ PRA-P0-01** (staff revocation) + **⚠ PRA-P1-02** (guardian) + **⚠ PRA-P2-34** (perms_version) + **P1-CODE-4** (change-phone) + pairs with **⚠ PRA-P1-53** (audit read UI) | P1-CODE-4 only | **✅ C1 APPROVED — ID-5 core = Workstream ILR** (see 11.3-C1) |
| SOP-F4 (evaluation workflow "extend") | **⚠ PRA-P0-05, P0-11, P0-12** (the eval workflow's actual P0 defects) | — | **✅ C3 APPROVED — F4 gated on P0-05/11/12** (cannot be DONE-per-DoD until these close) |
| SOP-F10 (dynamic certificate builder) | **⚠ PRA-P1-21, P1-22, P2-02, P2-03** (TC fields, void/reprint, conduct, logo) | — | **⏸ C4 PENDING (D2)** — fold the PRA cert fixes into F10, or do them standalone if F10 is D2-deferred; **do not resolve until D2** |
| SOP-F1/F2/F3 (OMR) | none (frozen-excluded scope) | n/a | D1-gated; net-new |
| SOP-F5/F6/F8/F9/F11 | none | n/a | net-new / extend; no PRA duplicate |
| SOP-F7 (weak-concept, Student 360/intelligence) | light: **PRA-P0-21** (parent-insights AI RLS-scope) shares the intelligence path | — | don't build F7 over the P0-21 bug |

### 11.3 Cross-audit findings this reconciliation surfaces

- **C1 [✅ APPROVED — Workstream ILR] — SOP-ID-5 core = PRA Theme 4 = PRA-P0-01 + P1-02 + P2-34.** SOP-ID-5's "login disable / membership revoked / guardian change / logical-delete + identity audit events" is **the same missing capability** as PRA-P0-01 (no membership-status writer), PRA-P1-02 (no guardian-unlink writer), and PRA-P2-34 (perms_version never bumped) — which Theme 4 already scopes as *one* revocation service (status writer + session/token sweep + the RLS status-clause fix). **These are one workstream, not three.** SOP's D4 linked ID-5 only to `P1-CODE-4`. **Consequence:** the identity-lifecycle CORE is **not** new D2-pending scope — it is *already a frozen PRA P0/P1 blocker that must ship pre-GA regardless of D2*. Only the SOP-*additional* governance on top (full ownership hierarchy fields, complete identity-audit-event catalog, dedicated create-employee/finance flows) is genuinely new and D2-sequenced.
- **C2 [✅ APPROVED — hard ordering constraint] — SOP-ID-3 must fix PRA-P1-07 in the same change (verified).** `handleContextSwitch` skips `assertSessionValid` and mints a new session+refresh from a possibly-revoked token; it has **zero client callers today**, so P1-07 is dormant. SOP-ID-3 = "wire the switcher" adds the first caller → **arms the bypass.** SOP-ID-3 **may not ship before P1-07 is fixed.** (P1-07 is itself a live internet-facing route, so it is also fixed in the pre-GA blocker set independently — see §10 Stage 2 — with this constraint as the backstop.)
- **C3 [✅ APPROVED — hard gate] — SOP-F4 is blocked by PRA-P0-05/P0-11/P0-12.** The "school-level evaluation workflow" SOP marks as ✅-exists is exactly where three exam P0s live (results can't publish; no per-class ownership; route-shadow bypasses scoping). F4's 15-point DoD **cannot pass** until those close — so F4 depends on the exam/pilot-lane fixes, not the reverse.
- **C4 [⏸ PENDING — bound to D2] — SOP-F10 vs the PRA certificate items is an owner sequencing choice.** If F10 (template builder) is built, it should absorb and close PRA-P1-21/P1-22/P2-02/P2-03. If F10 is D2-deferred, those four PRA items still need doing standalone pre-GA. Don't build both. **Do not resolve or implement until D2 is finalized.**
- **C5 — "student login compliant" (PRA) and "student-via-parent login missing" (SOP-G2) are the same code, not a contradiction.** PRA: the client forces `parent` role, so no *independent* student login exists → the frozen decision is honored ✅. SOP-G2: the backend student-scope path still requires the student's *own* phone, and there is no student-facing experience delivered *through* the parent session → a feature gap (SOP-ID-4). Both true; SOP-ID-4 closes the gap toward the frozen decision.

### 11.4 Merged execution shape (C1/C2/C3 APPROVED as planning; C4 pending D2)

The reconciliation collapses the two programs where they overlap:

1. **[✅ C1] Workstream ILR — Theme 4 ∪ SOP-ID-5-core ∪ SOP-ID-2-deactivation.** Build the revocation primitive once (membership/guardian status writer + session/token sweep + the two RLS status-clause fixes + perms_version trigger); the staff-exit case (P0-01), guardian-unlink (P1-02), perms-version (P2-34), and TC-transfer deactivation (SOP-ID-2/G3) are all consumers of it. This core is **non-optional and D2-independent** — it's a frozen PRA blocker.
2. **[✅ C3] Theme 1 (govern the pilot lane) gates SOP-F4.** The exam/ownership fixes (P0-05/07/11/12) must precede any SOP-F4 "done" claim.
3. **[✅ C2] SOP-ID-3 is hard-blocked on PRA-P1-07** (may not ship until P1-07 is fixed), and elevates PRA-P1-04/51/52 + P2-27 — the multi-school selector work.
4. **[⏸ C4 / D2] SOP-F10 vs the four PRA certificate items** — fold-in vs standalone, decided by D2; not resolved here.
5. **The SOP-*additional* governance (ownership hierarchy, full audit-event catalog, create-employee flows) and all of Track B remain D2-gated** and are not counted as blockers below.

### 11.5 Remaining P0/P1 blockers (must close pre-GA, independent of D1/D2)

This is the true blocker set the final plan must clear — unchanged by the SOP placement decision:
- **PRA P0s (24)** + the 2 new money races (M-1 replacement-fulfil, M-2 capture-guard, coupled to P0-02).
- **The identity-lifecycle core** (P0-01/P1-02/P2-34 ≡ SOP-ID-5-core) and **P1-07** (coupled to SOP-ID-3).
- Everything in D1/D2-gated SOP scope, the SOP-additional governance, Track B features, and the ~40 standalone §8 builds is **post-blocker / owner-sequenced**, not part of the pre-GA gate.

*No frozen PRA or SOP row was modified; §11 is a reconciliation ledger for owner approval. Merges (C1) and couplings (C2) become real only on owner sign-off.*

---

---

## 12. Completeness pass — full P0/P1 stage assignment (closes B1–B6)

Planning-only. §10 gave the high-leverage *thematic* order; **§12 is the authoritative per-item map** and supersedes §10 where they differ. Every P0 and every P1 is assigned below to either a **Tier-1 pre-GA stage** (mandatory before pilot/GA) or the **Tier-2 owner-deferrable register** (with its gating decision). No frozen roadmap record is modified; approved decisions (C1/C2/C3) and pending ones (C4/D1/D2) are unchanged.

### 12.1 Tier-1 — pre-GA mandatory stages (every P0 + every operational/integrity/security P1)

Global rule (all stages): **full affected-area regression green + EOS PASS before the next stage starts.** New tests that close the recurrence gap are noted per stage.

| Stage | Scope & items | Effort | Regression scope | EOS gate |
|---|---|---|---|---|
| **S0 — Decoupled quick wins** | P0-05, P0-12, P0-17, **P0-24 (claim/dead-link deletion — see B5)**, P1-40, P1-50; + new findings N-7/8/9/10/13. Surface-gate 3-liner, delete exam-marks shadow **+ dispatch-uniqueness test (N-14)**, approval-adapter, comms-history, API-fallback, delete-the-lie, **mock-import lint guard** | S | mobile + backend suites; new dispatch-uniqueness test; nav/surface smoke | SECURITY+FEATURE PASS |
| **S1 — Money & stock integrity** | P0-02, P0-03, P0-04, **M-1, M-2**; P1-08 (gapless receipt series), P1-09 (cheque bounce), P1-10 (discount/scholarship maker-checker), P1-11 (fee-statement refunds), P1-37 (inventory neg-stock guard), P1-38 (first-issue billing) | M | finance + inventory suites; **concurrency test per race site**; ledger-reconciliation test | SECURITY+MIGRATION+FEATURE PASS |
| **S2 — Identity Lifecycle & Revocation (Workstream ILR · C1)** | P0-01, P1-02, P2-34, **P1-07 (C2 backstop)**; P1-01 (2nd guardian), P1-03 (refresh children), P1-05 (officeStaff perms + override write), P1-06 (OTP crypto RNG), P1-53 (audit-log read UI), **P1-04 safety-core** (deterministic school resolution; staff-who-are-parents reach child) | M | auth/session/RBAC/RLS suites; **session-validation activation blast-radius audit** (non-'active'/NULL rows); guardian-unlink RLS-leak test | SECURITY+MIGRATION PASS |
| **S3 — Pilot-lane governance / canonical teacher↔class** | P0-07 **→** P0-11 (order mandatory), P0-08, P0-09, P0-10 (+ N-1..N-6); P1-15 (bulk-marks queued), P1-16 (timetable subject-matching), P1-31 (day-of-week filter) | L | pilot-lane + exam + timetable suites; **per-teacher ownership tests** (the coverage gap that shipped these green) | SECURITY+FEATURE PASS |
| **S4 — Reporting & metric integrity (+ B6)** | P0-22, P0-23, P1-47, P2-22; P1-48 (dashboard hardcoded []), P1-49 (report export); **P0-06 + P1-32 report card [B6 placed here]** | M | dashboard/report/report-card suites; **cross-screen metric-consistency test**; re-baseline dashboard goldens | FEATURE PASS |
| **S5 — Communication & delivery** | P0-16, P0-18, P1-45 (+ N-11); P1-44 (route-scoped delay broadcast) | M | comms/notification suites; DLT template path; fan-out scope test | FEATURE+SEC PASS *(DLT template registration = ops sub-task; see P2-20)* |
| **S6 — Academic-operations blockers** | **P0-13 [B1]** (admission approval gate), **P0-21 [B2]** (parent-insights AI RLS scope), **P0-14 [B4]** (promotion engine contract), P1-12 (post-publish correction/supplementary), P1-13 (grading-scale persistence), P1-14 (save-all mark loss), P1-17 (school-calendar UI), P1-18 (syllabus beyond Grade 10), P1-19 (SIS document storage), P1-20 (TC no-dues incl. library), P1-30 (homework storage bucket) | L | SIS/admissions/exams/academics suites; promotion-rollover integration test; **RLS scope test (P0-21)** | SECURITY+MIGRATION+FEATURE PASS |
| **S7 — Operational-module blockers** | **P0-15 [B4]** (staff GPS/face — = master-roadmap P1-PROD-22 Must-Before-GA), **P0-19 [B4]** (vehicle→route + capacity guard), **P0-20 [B4]** (transport fee demand), P1-33 (HR settings), P1-34 (leave accrual/carry-forward), P1-35 (payroll statutory compliance), P1-36 (LOP automation), P1-39 (inventory asset CRUD), P1-41 (library accession), P1-42 (library lost-book), P1-43 (transport attendance roster), P1-46 (AI gateway-bypass hardening); P2-12 (per-role borrow limit) | L | HR/payroll/transport/inventory/library/AI suites; child-safety capacity test (P0-19) | FEATURE+SEC PASS |

**Shared primitives reused across stages (build once):** the money-guard pattern (S1, proven at `finance_fee_reductions_repository.ts:421`); the revocation service (S2, consumed by SOP-ID-2/ID-5 per C1); the canonical teacher↔class binding (S3, serves backend scope + Flutter identity); the per-school settings-persistence mechanism (S6 grading + S7 HR consume one pattern).

**Cross-audit couplings honored:** C1 (S2 = ILR), C2 (P1-07 closed in S2 → SOP-ID-3 unblocked), C3 (SOP-F4 not "done" until S0+S3 exam fixes close), §9 pairs (P0-02+M-2 in S1; P1-54+P2-30 in Tier-2, ship together).

### 12.2 B5 — P0-24 (payroll→Finance) closure options (owner decides; not decided here)

The staged S0 work only deletes the false "posts to Finance" claim + dead link — honest, but salary still never reaches the ledger. Three closure paths:

| Option | What | Effort | Net effect |
|---|---|---|---|
| **A — Honesty-only** | S0 deletes the claim; real ledger-posting deferred to Tier-2 as a known documented gap | S | Stops the lie; salary still off-book (school reconciles in Tally) |
| **B — Full closure** | Implement real payroll→Finance ledger posting in **S7** | L | Salary hits the books; P0 business impact actually resolved |
| **C — Split (recommended shape)** | S0 deletes the lie now; **S7** implements posting pre-GA | S+L | Removes the misleading UI immediately, closes the integrity gap before GA |

**✅ B5 RESOLVED (owner, 2026-07-17): Option C.** P0-24 closure is **split**: the honesty correction (delete the false "posts to Finance" claim + dead `/finance/payroll` link) lands in **S0**; the real payroll→Finance ledger posting lands in **S7**. **P0-24 is NOT considered closed until the S7 ledger posting ships** — S0 only removes the actively-misleading UI. This is a closure-criteria decision, **not** a product-scope change.

### 12.3 Tier-2 — owner-deferrable register (each bound to a pending decision; **no P0 here**)

| Item(s) | Gating decision | Pull-forward flag |
|---|---|---|
| P1-04 (full multi-school selector UX), P1-51, P1-52, P2-27 | **D2** (SOP-ID-3 multi-school feature) | P1-04 *safety-core* already pulled to S2; the rest is chain/branch feature scope |
| P1-21 (board TC fields), P1-22 (TC void/reprint), P2-02 (conduct cert), P2-03 (cert logo) | **C4 / D2** (SOP-F10 cert builder) | ⚠ **Conditional:** TC is legally required to run a pilot. **If D2 defers F10, P1-21 + P1-22 must move to S6 pre-GA.** |
| P1-24 (admissions seat/quota/waitlist) | 👤 owner scope | ⚠ **RTE 25% is statutory** — pull to S6 if the pilot school holds RTE seats |
| P1-23 (ID cards), P1-25 (application fee) | 👤 owner scope | feature-completeness; deferrable |
| P1-26, P1-27, P1-28, P1-29 (QP / Education Suite) | 👤 QP-surfacing (K-lane, explicitly not GA-gating) | P1-29 (answer-key leak) is moot while P1-26 keeps QP unreachable; revisit together if QP is surfaced |
| P1-54 (vault dead code) + **P2-30 (base64 "encryption")** | 👤 own-provider-keys | ⚠ **Couple + conditional:** if pilot schools bring their own SMS/AI keys, pull both to S7 pre-GA (fix together per §9) |
| P1-55 (tenant data export) | 👤 procurement/exit | not daily-ops; deferrable |
| SOP-F5/F6/F7/F8/F9/F11, SOP-additional governance | **D2** (SOP placement) | net-new SOP scope |
| SOP-F1/F2/F3 (OMR) | **D1** | frozen-excluded until D1 |

**P2/P3 items (38):** not individually gated (none is a blocker); each rides its domain stage as a low-priority add or defers to Tier-2. Enumerated in the register §P2/§P3; not repeated here.

### 12.4 Coverage assertion

- **P0: 24/24 assigned to a Tier-1 stage** (none deferred). S0: 05,12,17,24 · S1: 02,03,04 · S2: 01 · S3: 07,08,09,10,11 · S4: 06,22,23 · S5: 16,18 · S6: 13,14,21 · S7: 15,19,20. ✅
- **P1: 55/55 assigned** — 42 to Tier-1 stages (incl. P1-04 safety-core), 13 to the Tier-2 register (incl. P1-04 full feature). ✅
- **B1** (P0-13)→S6 · **B2** (P0-21)→S6 · **B3** (P1 tail) fully placed above · **B4** (P0-14/15/19/20) → S6/S7 as **pre-GA**, removing the "post-blocker" mislabel · **B5** options presented (owner decides) · **B6** (report card)→S4. ✅

### 12.5 Readiness re-review (post-completeness-pass)

| # | Criterion | Result |
|---|---|---|
| 1 | Every P0/P1 has an explicit stage | ✅ **PASS** — 24/24 P0 + 55/55 P1 assigned (§12.4) |
| 2 | No unresolved dependency | ✅ **PASS** — P0-07→P0-11 (S3), C2 P1-07 (S2), C3 F4 gate, §9 pairs all placed |
| 3 | No duplicate workstreams | ✅ **PASS** — C1 merge holds; shared primitives named once (§12.1); item→stage is 1:1 |
| 4 | C1/C2/C3 reflected | ✅ **PASS** — S2=ILR/C1, C2 in S2, C3 gate on S0+S3 |
| 5 | C4/D1/D2 pending | ✅ **PASS** — all in Tier-2, unresolved (§12.3) |
| 6 | Regression + EOS per stage | ✅ **PASS** — every S0–S7 row carries a regression scope + EOS gate + global before-next-stage rule |
| 7 | Order internally consistent | ✅ **PASS** — B4 mislabel corrected; no P0 in Tier-2; Tier-1/Tier-2 split explicit |

**Residual dependencies on owner input (not readiness blockers — they gate *scope*, not the plan's completeness):** B5 closure choice for P0-24; D2 (which, if it defers SOP-F10, pulls P1-21/22 into S6); the conditional pull-forward flags (RTE P1-24, own-keys P1-54/P2-30). These are explicitly captured with their triggers, so the plan stays complete under any of the owner's choices.

## ✅ IMPLEMENTATION PLAN — READY FOR EXECUTION

Every P0 and P1 has an explicit stage, every dependency and approved coupling (C1/C2/C3) is placed, C4/D1/D2 remain pending, and every stage carries a regression + EOS gate. **No readiness blockers remain.** Recommended start: **Stage S0** (decoupled quick wins), one stage at a time, full regression + EOS PASS between stages. Awaiting final implementation authorization.

---

*Planning artifact — no production code, migrations, or fixes were written. Implementation begins only on owner instruction, one stage at a time, under the standing EOS gate.*
