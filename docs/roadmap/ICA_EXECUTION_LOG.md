# PROGRAM ICA — EXECUTION LOG

**Scope:** Interim Certification Audit remediation (SSOT: `AKSHARA_CONSTITUTION_ALIGNED_MASTER_ROADMAP.md` §5.6 · PROGRAM ICA).
**Surface:** canonical trunk `integration/w0-canonical` (worktree `Akshara_ERP-w0`).
**Method (per program law):** every item was **re-verified on the trunk** (line numbers shift; the payment-provider abstraction landed after the audit) before any edit; each landed under an internal EOS gate with a regression guard. This log records what is DONE — not a re-plan.

---

## Batch 1 — the live/reachable P0s (roadmap directive §5.6: "do the P0s (A1/A2/A5) first; they are live/reachable" + B1 with W2 identity)

| ICA | Title | Class | Verify verdict | EOS | Commit |
|---|---|---|---|---|---|
| **A5** | Unsigned Razorpay webhook accepts forged capture | Finance/Security P0 | STILL-PRESENT (worse post-refactor: P0-02 made the forged event actually post to the books) | PASS | `287364d3` |
| **B1** | De-authorized guardian reads revoked child (RLS) | Security P0 | STILL-PRESENT + BROADER (7 policies, not 5) | PASS | `d40e4207` |
| **A1** | Recovery dashboard 100× money understatement | Finance/Data-Model P0 | STILL-PRESENT | PASS | `d070a152` |
| **A6** | Payment INTEGER rupees truncate paise | Finance/Data-Model P1 | STILL-PRESENT | PASS | `d070a152` |
| **A2** | Offline-instrument reconcile double-credit race | Finance/Engineering P0 | STILL-PRESENT | PASS | `bc23b73c` |

### A5 — forged-capture webhook (`287364d3`)
- **Root cause:** `verifyRazorpayWebhookSignature` returned `true` for a null signature in stub mode (default on the pilot); the public webhook route then wrote real collections/receipts for zero payment. The handler's `RAZORPAY_ALLOW_UNSIGNED` guard never fired because `valid` was already `true`.
- **Fix (fail-closed, no gateway creds needed):** an absent signature is never valid in any mode; stub mode accepts only the explicit `stub_signature` token; money-affecting webhooks are refused (403) while the provider is in stub mode unless the off-by-default dev flag is set. `payment_service.ts` untouched (forgery stopped before it).
- **Guard/tests:** flipped the tests that encoded the vulnerable behavior (`razorpay_client_test`, `payment_provider_test`) to lock the secure contract; added handler + live-signature happy-path tests. **Payment dir 38/0.**
- **Gate:** must land before the payment webhook route is exposed on any deployed build and before the live gateway (P0-02) is enabled. ✅ now on the trunk.

### B1 — guardian active-link RLS (`d40e4207`)
- **Root cause:** soft-unlink retains the `student_guardians` row as `status='inactive'`; 7 parent-scope policies matched ANY link. PRA-P1-02 fixed only finance+enrollments.
- **Fix:** migration `20260920000080` recreates all 7 verbatim, adding only `AND sg.status='active'` inside the guardian sub-select (attendance_records, exam_mark_entries, exam_remarks, homework_submissions, intel_parent_guidance, attendance_corrections read + insert). Purely tightening; idempotent.
- **Guard:** static drift scanner resolves the latest def per policy and fails on any parent-scope guardian sub-select missing the predicate (proven non-vacuous; floor ≥15, effective count 27). **Guard 3/0, trunk-integrity 5/0.**
- **Tracked to deploy:** runtime RLS probe across all 7 surfaces (documented; add to `tenant_isolation_probes.ts`, executes against the pilot tenant at the owner-gated deploy / W11 live security cert).

### A1 + A6 — money-unit unification (`d070a152`)
- **Standard adopted:** every `*_minor` column is BIGINT integer paise (×100 in / ÷100 out); all other stored money stays NUMERIC(12,2) rupees.
- **A1 fix:** recovery writer now truly scales rupees→paise; both recovered-amount SUMs emit true paise so the ÷100 reader is correct and `attainmentPct` stays paise/paise. Migration `…060` = one-time ×100 backfill of promises/targets written by the pre-fix writer (**not idempotent by design; runs once at deploy**; concessions untouched).
- **A6 fix:** migration `…062` alters `payment_requests.amount` / `payment_intents.amount` INTEGER→NUMERIC(12,2) so paise round-trip; no payment source change.
- **Guards/tests:** `finance_money_unit_invariant_test` (static: `_minor`⇒BIGINT, no INTEGER money col), `finance_recovery_money_test` (round-trip), payment paise round-trip case. **Finance dir 307/0.**
- **Tracked follow-up (P2, NO live bug):** installments/head-allocation NUMERIC columns misnamed `_minor` are read by `transport_expenses`/`finance_mapper`/`finance_aging`; the coordinated cross-module rename (was migration `…061`) is deferred and the invariant test pins them against INTEGER regression via the `DEFERRED_NUMERIC_MINOR` set.

### A2 — offline reconcile double-credit (`bc23b73c`)
- **Root cause:** unlocked read + terminal UPDATE guarded on `status <> 'bounced'` (not `= 'pending_reconciliation'`) + no idempotency key → two collections for one instrument when invoice outstanding ≥ 2× amount.
- **Fix (Money-Integrity race pattern + DB backstop):** `FOR UPDATE` the instrument before the reconciled-check; terminal UPDATE guard `AND status='pending_reconciliation'` + throw-on-0-rows (fail-closed rollback); `offlinePaymentId` + `offline-reconcile:<id>` idempotency key into `createCollection`; migration `…070` adds `finance_collections.offline_payment_id` + partial UNIQUE index (≤1 collection per instrument).
- **Guard/tests:** `qa_x_022` rewritten so the mock counts collection inserts and honors the pending guard (exactly-one + fail-closed cases). **Finance dir 307/0.**
- **Tracked to deploy:** concurrent live-cert `scripts/qa/live_cert_offline_reconcile_double_credit.sh` (authored, `bash -n` clean) — runs two concurrent reconciles as the non-bypass `erp_tenant` role and asserts exactly one collection persists.

---

---

## Batch 2 — Domain Correctness + Data Integrity (feeds W4/W5/W3 · absorption map §5.6)

| ICA | Title | Class | Verify verdict | EOS | Commit |
|---|---|---|---|---|---|
| **H1** | Term tabulation drops same-subject exams | Data-Model/Product P1 | STILL-PRESENT (defect also in `loadReportCards`) | CONDITIONAL PASS | `75bc8e2e` |
| **H4** | Student-risk fabricates optimistic low-risk defaults | Product/Safeguarding P1 | STILL-PRESENT (fail-UNSAFE) | CONDITIONAL PASS | `0a231743` |
| **H4-ext** | Same defect on `predictions_service` + `student_success_service` | Product/Safeguarding P1 | present (success) / test-red (predictions) | PASS | `943ce2d5` |
| **H3** | Management attendance returns 0% (not null) on zero denom | Implementation P2 | STILL-PRESENT (secondary "drags avg" claim REFUTED — pooled ratio) | PASS | `db78adac` |
| **E1** | No DB single-current-enrollment guarantee | Data-Model P1 | STILL-PRESENT | CONDITIONAL PASS | `fa26ded0` |

- **H1** `75bc8e2e` — tabulation + report cards now key on the assessment slot `(subject, exam_type)`: distinct exam_types in a term are summed; a same-slot supplementary still replaces (PRA-P1-12 preserved); AB/ML/DB NULL rule intact. Dir 174/0. **Tracked P2:** two *distinct* exams of the *same* exam_type need an explicit `supersedes` marker (Option B, future migration).
- **H4** `0a231743` + **H4-ext** `943ce2d5` — removed the 92%/85% fabrication; a no-data student is now floored to needs-review (never 'low'/'low-concern'), carries a `no_monitoring_data` caveat + provenance flags, and stays visible on score-ordered early-warning lists — across all three surfaces (`student_risk_repository`, `predictions_service`, `student_success_service`). H4-ext also repaired a predictions-dir test regression the H4 commit introduced (H4 was validated only against `intelligence/`). Intelligence 177/0, predictions 5/0. **Tracked P2:** export the mirrored `UNMONITORED_REVIEW_SCORE` (now in 3 files); first-class `unmonitored` band via CHECK migration + engine re-normalization; UI caveat.
- **H3** `db78adac` — per-class attendance returns null (not 0%) on zero denominator; the school-wide pooled ratio already excludes zero-denom classes (no change needed). Dir 18/0. **Tracked (client):** all-null school scalar stays 0 until `management_payload_builders.ts` is null-tolerant.
- **E1** `fa26ded0` — migration `…090` self-heal dedup + partial UNIQUE index `WHERE is_current=true`; repository maps 23505 → 409 conflict (no handler edit). Dir 203/0. **Tracked to deploy:** two-session concurrency live-cert.

---

## Batch 3 — Perf + DEFINER hardening (feeds W10)

| ICA | Title | Class | EOS | Commit |
|---|---|---|---|---|
| **C1** | attendance_records missing tenant/student index | Perf P1 | PASS | `5282491f` |
| **B3** | onboarding/subscription SECURITY DEFINER fns lack in-DB guards | Sec P1 | PASS | `d5c49644` |
| **C3** | listAttendanceSessions unbounded | Perf P1 | PASS | `f554b9ab` |

- **C1** — mig `…100`: `(org,school,student)` + `(org,school)` indexes; per-query coverage mapped for EXPLAIN at deploy. **Gate:** before multi-school scale-out.
- **B3** — mig `…110`: in-fn guards on `onboarding_ensure_school_membership` (tenant-owns-school + session-school match + role allowlist), `onboarding_upsert_user_by_phone` (fail-closed on null context; global `users` table means the app gate stays the true boundary — documented), `assign_organization_subscription` (actor-binding + real-org; cross-org-by-design documented). Static drift guard `onboarding_secdef_guard_test`.
- **C3** — code-only: pagination (cap 100) + 90-day window (override 1..366). **⚠ Client-contract change:** `GET /attendance/sessions` data → `{items,total,page,pageSize,hasMore}` (no Dart/web consumer found; verify at client integration).

## Batch 4 — Idempotency/reliability cluster (feeds W10)

| ICA | Title | Class | EOS | Commit |
|---|---|---|---|---|
| **A4** | idempotency wrapper non-atomic / key-poisoning | Eng P1 | PASS | `359e6afb` |
| **D1** | idempotency replay ignores method/path | Eng P1 | PASS | `359e6afb` |
| **D3** | request_idempotency has no retention/reaper | Eng/Ops P2 | PASS | `76f22244` |

- **A4** — `store()` wrapped (no 500-for-committed-write); in-flight NULL-payload claim re-claimable via atomic CAS after a 5-min TTL (self-heals the permanent-409 poison; re-dispatch stays exactly-once via the route's money-safe backstop); fresh-concurrency 409 kept transient (deliberately not a blind yield — would double-dispatch non-backstopped routes). Code-only.
- **D1** — claim() compares stored `(method,path)`; cross-endpoint key reuse → 422, checked before any replay.
- **D3** — mig `…130`: `reap_request_idempotency(7d completed, 1h orphan)` SECURITY DEFINER + REVOKE-from-PUBLIC (cross-tenant purge, ops-cron only, matches DB-6 seam) + supporting index. **Deploy/ops step:** schedule the hourly `SELECT reap_request_idempotency();`.
- Real-Postgres concurrent atomic-claim test = **ICA-D5/A7** (deploy-time CI gate, ICA-D4).

## Batch 5 — Security tail (feeds W11)

| ICA | Title | Class | EOS | Commit |
|---|---|---|---|---|
| **B4** | OTP stored as unsalted SHA-256 | Sec P2 | PASS | `65e9e39c` |
| **B8** | session revoke without owner check | Sec P2 | PASS | `65e9e39c` |
| **B9** | service_role setRequestContext no-op | Sec P2 | PASS | `65e9e39c` |
| **B5** | health token non-constant-time compare | Sec P2 | PASS | `9f0898c6` |
| **B6** | audit_events INSERT doesn't bind school_id | Sec P2 | PASS | `4da90ba7` |

- **B4** — dedicated `hashOtp` HMAC(otp, jwt-secret) in both OTP paths; `hashToken` left intact for refresh/gate-pass tokens.
- **B8** — refresh-token revoke now `.eq('user_id', claims.sub)`.
- **B9** — inert `setRequestContext` removed from `handleMe`; explicit filter kept + documented. *(Residual, owner-flagged: the same dead idiom at `issueSessionTokens:200` — no read follows, left in place.)*
- **B5** — `timingSafeEqualHex` for the internal health token.
- **B6** — mig `…140`: audit_events INSERT WITH CHECK now binds `school_id`.
- **⛔ ICA-B7 (support mirror bridge trusts attacker-chosen incident id)** — **NOT implemented here: it modifies the ASIP `support_platform_mirror.sql` → handled by the dedicated AI Support Engineering session** (likely folded into ASIP's own 5-P1 remediation).

---

## Validation
Batch 1: payment **38/0** · finance **307/0** · guards+trunk-integrity+money-invariant **11/0**.
Batch 2: combined 4 dirs + trunk-integrity **572/0**; intelligence **177/0**; predictions **5/0**.
Batches 3–5: guard tests + trunk-integrity green; attendance **43/0**; idempotency **9/0**; internal-health **5/0**.
Batches 6–7: finance **318/0**; communication **150/0**; director+management **53/0**.
Batches 8–10: sis+admissions+onboarding **320/0**; inventory_finance route-contract green; clearance+certificates **84/0** + flutter analyze clean + flutter test **+8**; approvals **72/0**.
**Full backend suite (all batches together): `deno test supabase/functions/` → 4075 passed · 0 failed · 3 ignored** (the 3 ignored = the env-gated real-DB isolation tests, i.e. the ICA-D4 CI gap — itself a remaining backlog item). `deno check` on every changed source → exit 0.

## Migration slots consumed on the trunk (for cross-lane fold-in coordination)
`…060` (A1 recovery backfill) · `…062` (A6 payment NUMERIC) · `…070` (A2 offline guard) · `…080` (B1 guardian RLS) · `…090` (E1 single-current) · `…100` (C1 attendance indexes) · `…110` (B3 DEFINER guards) · `…130` (D3 idempotency reaper) · `…140` (B6 audit school-bind) · `…160` (E2 operational FKs) · `…170` (A3 receipt scoping) · `…180` (F5 soft-ref detector). **Current trunk max = `…180`.** **⚠ ASIP fold-in note:** the ASIP KB migration `…060` collides with A1's `…060` (tracked ASIP P1-D); its planned renumber to `…090` is also taken — **the ASIP fold-in must pick `…190`+ (above this trunk's current max `…180`).** Not actioned here (ASIP is a separate lane).

## Deploy-gated tail (owner-gated — NOT auto-run here)
These complete the "live certification" lifecycle step and run at the **owner-gated trunk→pilot redeploy** (deploy authority is owner-held; the shared VPS is production):
1. A2 concurrent double-credit live-cert.
2. B1 runtime RLS probe (7 de-authorized surfaces = 0 rows; still-active guardian = full rows).
3. A1 recovery-dashboard rupee-figure check against a seeded ledger + the one-time `…060` money backfill (owner confirms recovery-CRM row presence on the pilot before applying).
4. A5 gate: the webhook signature enforcement must be in the deployed build before the route is exposed / live gateway enabled.

## Batch 6 — Perf + data model (feeds W10)

| ICA | Title | EOS | Commit |
|---|---|---|---|
| **C4** | bulkAssignFeeStructure N+1 → set-based | PASS | `c1654202` |
| **C6** | broadcast fan-out silent truncation >5,000 | PASS | `04716c41` |
| **E2** | operational soft FKs → real FKs (NOT VALID) + orphan detector | CONDITIONAL | `47cb9eea` |

- **C4** — cohort-invariant reads hoisted; `= ANY` batched reads; multi-row `INSERT…SELECT unnest ON CONFLICT`; ~540→~11 queries; per-student SAVEPOINT retained only as the concurrent-23505 fallback. *Residual (out of scope): `createAnnualInvoice` stays O(N).*
- **C6** — both entry points chunk the FULL cohort in bounded multi-row inserts; nothing dropped. *Sibling flagged: `publisher_dispatch.ts` MAX_PUBLISH_RECIPIENTS.*
- **E2** — mig `…160`: 3 FKs `ON DELETE CASCADE` **NOT VALID** + `detect_orphan_operational_rows()` (privileged). **Deploy: run detector + `VALIDATE CONSTRAINT`.** (Corrected the audit's premise — the cited soft-FK migration doesn't touch these columns; no deliberate decoupling existed.)

## Batch 7 — Hygiene + perf + finance availability

| ICA | Title | EOS | Commit |
|---|---|---|---|
| **F8** | dead no-op loop + hot-path dynamic imports | PASS | `57c44685` |
| **C2** | director/management dashboards recompute all-time aggregates | PASS | `367e4c21` |
| **A3** | receipt-number global UNIQUE collision | PASS | `ed8e3c98` |

- **F8** — removed finance_router no-op loop; 24 hot-path dynamic imports → static (cycle-checked). *Partial: same pattern in sis/academic/hr/admissions routers + other services left for an F8 sweep.*
- **C2** — attendance + exam-marks aggregates bounded to a trailing current-academic-year window in both dashboards (reused the repo's own interval convention; avoided the per-school academic_years table for org-wide rollups). ICA-H3 preserved; lifetime metrics unchanged. No matview.
- **A3** — mig `…170`: DROP global `finance_receipts_receipt_number_key` + scoped UNIQUE `(org,school,receipt_number)` (superset key, safe) + per-school `schools.code` default prefix. **Gate:** before multi-school receipt-sequencing.

*(Note: two interrupted C2/A3 attempts were fully reverted and redone clean from the certified baseline — no partial work committed. F8 was committed independently first.)*

## Batch 8 — Architecture P1/P2

| ICA | Title | EOS | Commit |
|---|---|---|---|
| **F2** | students identity table has three writers, no owning service | PASS | `e5dd2d75` |
| **F6** | inventory_finance HTTP surface split across two routers | PASS | `341a470d` |

- **F2** — new `sis/sis_student_identity.ts` is the sole writer of `students` + `student_profiles`; SIS/admissions/onboarding all route through it. Admissions now gets the canonical PSID; a racing 23505 rolls back the whole student creation — **no orphan**. Frozen identity format/admission#/idempotency preserved. No migration.
- **F6** — one `inventory_finance_router` owns both prefixes, registered once in `app.ts`, same handlers/guards (self-enforces `module.inventory` on `/inventory/*` only, per the org-builder precedent).

## Batch 9 — Data integrity + test hardening

| ICA | Title | EOS | Commit |
|---|---|---|---|
| **F5** | JSONB↔relational soft cross-module refs (no FK) | PASS | `2d439d25` |
| **E3** | inconsistent migration idempotency guards | PASS | `285485ce` |
| **D6** | approval SoD FakeDb can't catch a lost status guard | PASS | `e9befc93` |

- **F5** — mig `…180`: `detect_orphan_cross_module_refs()` (privileged) + `JSONB_RELATIONAL_INVARIANTS.md`. Confirmed no dangle possible today.
- **E3** — forward-looking re-runnability guard (cutoff `…060`, grandfathers 244 historical, 7 rules, non-vacuous) + `MIGRATION_CONVENTIONS.md`. All in-scope ICA migrations comply.
- **D6** — verified the real `decideApproval` already has the two-layer status guard → TEST-ONLY faithfulness fix + re-decide/TOCTOU coverage.

## Batch 10 — Trust + hygiene sweep

| ICA | Title | EOS | Commit |
|---|---|---|---|
| **H2** | TC certificate falsely asserts "all dues cleared" | PASS | `ee99a5d8` |
| **F8-sweep** | remaining no-op loops + hot-path dynamic imports | PASS | `c27d39fe` |

- **H2** — truthful "financial dues" wording (backend `clearanceStatement` → Dart PDF), **frozen SCE-1 gate unchanged** (finance-blocking, inventory/library advisory). Cross-toolchain verified (deno 84/0 + flutter analyze clean + flutter test +8). Library name-key fragility left as an owner item.
- **F8-sweep** — 4 more no-op loops (academic/admissions/hr/sis) + 18 dynamic→static imports (cycle-checked).

## Remaining ICA backlog

**Done so far (Batches 1–10): 32 of 49 items** — A1, A2, A3, A5, A6, B1, B3, B4, B5, B6, B8, B9, C1, C2, C3, C4, C6, D1, D3, D6, E1, E2, E3, F2, F5, F6, F8(+sweep), H1, H2, H3, H4(+ext). **All P0s + every buildable/locally-verifiable P1 + the W10/W11 perf/security/reliability/data-model/architecture tranche.**

- **Owner-gated (do NOT auto-implement) — 4:** ICA-G1 (`domain_events` bus vs log), ICA-G2 (entitlement-flip timing), ICA-G3 (per-tenant custom roles), ICA-B2 policy (OTP pilot-phone removal). Raised in the ICA owner-decision batch (§5.6).
- **ASIP session (do NOT implement here) — 2:** ICA-G4 (client mock/real fail-closed) + **ICA-B7** (support mirror bridge incident-id guard) — both modify the ASIP support lane; handled by the dedicated AI Support Engineering session.
- **CI-infra — validation is CI-on-push (deferred), not locally certifiable — 4:** **A7** (real-DB money-race concurrency tests) + **D5** (real-DB idempotency atomic-claim test) + **D4** (add a Postgres service to the CI gate so the isolation + money-race probes RUN and fail-not-skip) + **D7** (backend coverage gate). These make the existing perpetually-ignored env-gated tests actually execute; their green is provable only on a CI runner with Postgres.
- **Large refactors — recommend dedicated, individually-reviewed efforts (regression risk on the certified trunk) — 5:** **F1** (auth/RBAC middleware — 656 call sites; the roadmap itself scopes this to the W10 central-chokepoint item), **F3** (god-file decomposition — 3,000-line files), **F4** (prefix→router registry — changes routing across ~66 routers), **F7** (raw SQL → repository — 25 handler files), **C7** (generic-store keyset pagination — broad blast radius on the shared list store).
- **Infra/ops — 1:** **C5** (front tenant connections with a transaction-mode pooler / global connection ceiling — needs PgBouncer/Supavisor infra + deploy; the code-side POOL_SIZE ceiling is a partial).

---

## PHASE 2 — Owner decisions (all 4 approved + DONE) + standalone refactors

Owner approved G1/G2/G3/B2 (2026-07-21) with specific direction; each implemented as an independent verified batch (full lifecycle), EOS PASS, committed. Backend full suite after each stayed green; final = **4126 passed / 0 failed / 3 ignored**. Trunk `01f5a46d` → `883fc572`.

| Item | Owner direction | EOS | Commit | Migration |
|---|---|---|---|---|
| **G1** domain events | keep internal LOG; bus-ready interface; no external infra | PASS | `6ea8f208` | — |
| **G2** entitlement | production-ready + phased/gradual rollout via flags/config | PASS | `068467f6` | `…190` |
| **G3** custom roles | per-tenant custom roles; system roles immutable | PASS | `aef2fbab` | `…200` |
| **B2** OTP policy | remove all privileged/pilot OTP bypass from the prod path | PASS | `67e40236` | — |
| **F7** (refactor #1) | raw SQL → repository (standalone refactor) | PASS | `883fc572` | — |

- **G1** — in-process `DomainEventSubscriber` registry seam (`domain_event_subscribers.ts`); "published" now = "dispatched to all registered subscribers" (zero today; AI Signal Refinery stays direct-invoked). Doc `DOMAIN_EVENTS_ARCHITECTURE.md`. No external messaging library.
- **G2** — master mode `off`(default)/`allowlist`/`all` + per-org `organizations.entitlement_enforcement_enabled` + `detect_orgs_missing_entitlement_plan()` pre-flip audit + 17 ON-path tests. Default enforces nowhere (zero pilot risk).
- **G3** — org-scoped `role_definitions`/`role_permissions` (NULL=system), global-PK slug (no shadow), RLS system-read-only + org-write, hard org-match trigger, `/identity/roles` CRUD gated on `manageManagement`. +24 tests. **P1 follow-up: client role-mgmt UI + membership-assignment write-path.**
- **B2** — production can NEVER return an OTP in the login body for ANY phone (env short-circuit; allowlist inert in prod). +6 tests. Deploy: ship prod `AUTH_OTP_PILOT_PHONES` empty (belt-and-suspenders).
- **F7** — all 25 handlers cleared of raw SQL (caught a `queryCount` block the audit regex missed); 47 files (12 new repos + `db_savepoint.ts` kernel that also advances ICA-D2); pure behavior-preserving moves. Suite unchanged 4126/0/3.

**Migration slots added: `…190` (G2), `…200` (G3). Current trunk max = `…200`. ⚠ ASIP fold-in must renumber ≥ `…210`.**

**▶ Remaining backend (sequential, independent verified projects — do NOT batch): ~~F4~~ → F3 (god-file decomposition) → F1 (auth/RBAC middleware — W10 chokepoint) → C7 (generic-store keyset).** Then owner-deferred CI-infra (A7/D4/D5/D7) + C5 pooler. Final = owner-gated production deploy (after refactors + ASIP renumber-merge + prod-readiness cert + explicit authorization).

## PHASE 3 — Standalone refactors (each an independent verified project)

| Item | EOS | Commit | Migration |
|---|---|---|---|
| **F4** — prefix→router registry (declarative routing; greedy routers return null not 404) | PASS | `0a6f2136` | — (code-only) |
| **F3** — god-file decomposition (pilot_operations_repository.ts 3,311 LOC → barrel + 6 domain modules) | PASS | `6eba1fa4` | — (code-only) |
| **F1** — central auth/RBAC chokepoint (no route unauthenticated by omission) | PASS | `e0e98375` | — (code-only) |
| **C7** — generic list-store keyset pagination (opt-in, backward-compatible) | PASS | _(this commit)_ | — (code-only) |

### F4 — declarative module-route registry
- **Problem (verified on trunk):** `api/app.ts` held a hand-ordered `moduleRouters` array whose correctness depended on comments like "MUST precede routeFinance because it greedily owns its prefix and returns its own 404 (never null)". 52 routers were "greedy" — a path inside their prefix that matched no route returned their OWN `errorEnvelope("NOT_FOUND", "Route not found…", 404)` (53 sites), which shadowed any later router that owned a cross-prefix path. Two prod shadow bugs shipped exactly that way (PRA-P0-12 pilot→exam-marks; PRA-N-13 dead teacher handler→messages).
- **Fix (two parts):**
  1. **Flip (order-robustness):** all 53 greedy route-404 sites → `return null`; the SINGLE source of a route-level 404 is now the central dispatcher in app.ts (byte-identical envelope). `routeSupportPlatform` return type widened to `Response | null`. `deno check` clean. Because the message everywhere was the identical "Route not found", a genuinely-unmatched path is unchanged; the only behavioral delta (a later router claiming a path a greedy one used to 404) is validated by the full route-contract suite.
  2. **Declarative registry:** new `_shared/route_registry.ts` exports the ordered `MODULE_ROUTES` table (`{name, prefixes, route, note}`) with per-router prefix ownership + the migrated rationale, plus `matchModuleRoute()`. `app.ts` now dispatches via one `matchModuleRoute` call. Order is preserved verbatim but is no longer load-bearing (ownership is disjoint).
- **Guards:** new `route_registry_test.ts` (4 tests): (a) **static flip-lock** — scans every `_shared/**/*router*.ts` and fails if any re-introduces the greedy route-404; (b) registry shape/no-drift; (c) **single-ownership** — exactly one (correct) owner for a representative path set that STRESSES every cross-prefix overlap (`/finance` vs `/finance/inventory-reconciliation`; `/inventory` vs `/inventory/distribution` vs vendors; `/academic` vs `/academic/timetables` vs `/academics/exams`; `/parent|/teacher|/student` vs communication + pilot; `/platform` org-builder vs entitlements; `/school/*` vs `/school-config`), proving order-independence; (d) central-404. `trunk_integrity_test` "registered exactly once" updated to guard the new `route_registry.ts` (MODULE_ROUTES) + assert app.ts keeps the `matchModuleRoute` indirection (no inline `moduleRouters` array). 39 per-module route-contract tests updated from the old greedy "unmatched-in-prefix → 404 envelope" to the new "→ null" contract (405 wrong-method + 422 id-validation + dispatcher-404 assertions deliberately preserved).
- **Validation:** full backend suite **4130 passed / 0 failed / 3 ignored** (was 4126; +4 new registry tests; the 3 ignored = the unchanged env-gated real-DB tests). Only non-router/non-test source file changed = `api/app.ts`. Code-only, no migration.

### F3 — god-file decomposition (`pilot_operations_repository.ts`)
- **Problem:** 3,311 LOC / 82 exports mixing attendance, leave, homework, parent/student snapshot overlays, teacher reads, and tenant-isolation probes in one file.
- **Fix (pure behavior-preserving move):** split into 6 cohesive domain modules (`pilot_operations_probes.ts` 31, `pilot_attendance_repository.ts` 594, `pilot_leave_repository.ts` 409, `pilot_homework_repository.ts` 928, `pilot_snapshot_repository.ts` 866, `pilot_teacher_repository.ts` 470) + `pilot_operations_shared.ts` (27 — the only two genuinely cross-module privates, `periodTimeRange` + `listTeacherClassLabels`). `pilot_operations_repository.ts` is now an 11-line **barrel** (`export * from` the 6 domain modules; shared intentionally NOT re-exported so the public surface stays exactly the original 82 symbols). No cycles (shared imports no sub-module).
- **Zero importer changes** — all 17 consumers keep their unchanged named imports (barrel preserves every export).
- **Validation:** `deno check` clean on the barrel + main handlers; full backend suite **4130 / 0 / 3** (unchanged — a pure move alters no test outcome); an independent code-line multiset diff (original body vs union of new files) matched exactly (3111 == 3111). Code-only, no migration.

### F1 — central auth/RBAC chokepoint (W10 structural guarantee)
- **Problem (roadmap §W10):** auth/RBAC was enforced per-handler by convention — `authenticateRequest` at ~664 handler entry points. A handler that forgets it = an open route ("unauthenticated by omission"). No structural guarantee.
- **Fix (registry-first, minimal blast radius — the 664 handlers are NOT touched):**
  1. **Central gate** in `routeModuleRequest` (the F4 dispatch chokepoint every module route flows through): before dispatch, non-public routes are authenticated once; unauthenticated → 401 immediately. So no module route reaches a handler unauthenticated, even if the handler omits its own check. Fine-grained RBAC (requirePermission / scope) stays in the handlers, unchanged — the gate guarantees AUTHENTICATION, not authorization.
  2. **Public allowlist** (`PUBLIC_MODULE_ROUTE_PREFIXES` in route_registry.ts): the ONLY non-session routes, both HMAC-signature-authed — `/webhooks/<gateway>` (payment) + `/communications/delivery/webhook` (message-provider delivery status). Found by an exhaustive scan of every `verify*Signature` usage; a guard test asserts each actually bypasses the gate (so a valid signature is processed, not rejected for lack of a JWT).
  3. **Per-request memoization** of `authenticateRequest` (WeakMap keyed on the Request): the central gate authenticates once; the handlers' own 664 calls (and the idempotency scope resolver, which also authenticated) reuse the cached result — no extra session-validation DB read (removes a pre-existing double-auth on idempotent mutations).
- **Behavior change (intended hardening):** an UNAUTHENTICATED request to an unknown route now returns 401 (auth-first) instead of 404 — unauthenticated callers can no longer enumerate route existence. (Authenticated, an unknown route still 404s.) Updated 5 registry-gap/CORS/audit guards to authenticate their probe (preserving intent) and added ICA-F1 tests to `eng4_5_forced_auth_test.ts` (unauth → 401 universal; both webhooks bypass the gate).
- **Validation:** full backend suite **4132 / 0 / 3** (+2 F1 guarantee tests). `deno check` clean. Code-only, no migration.

### C7 — generic list-store keyset pagination
- **Problem:** the shared entity read stores (`entity_read_store` + `student_scoped` + `org` variants, 14 importers) paginate with `LIMIT/OFFSET` + a `count(*)` per call, so a deep page is O(offset) — poor at scale. "Broad blast radius" is why it was flagged.
- **Fix (additive, backward-compatible — the page/total API + all 14 importers are unchanged):** added keyset (cursor) pagination alongside offset. `academic_pagination.ts` gains `KeysetParams`/`KeysetResult` + a pure `keysetPageOf` helper (splits a `LIMIT pageSize+1` fetch into page + hasMore/nextCursor, no COUNT). All 3 stores gain `listEntitiesKeyset` — `WHERE … AND (id > :cursor) ORDER BY id LIMIT pageSize+1`, seeking past the cursor so every page is O(pageSize) at any depth. Exposed opt-in through `module_read_handlers` (`?cursor=` → keyset envelope `{items, pagination:{pageSize, cursor, nextCursor, hasMore}}`; absent → the original page/total path). New `keysetEnvelope` shaper.
- **Tests:** `c7_keyset_pagination_test.ts` (5) — full page-walk via nextCursor, exact-fit final page, empty, pageSize clamp (1..100), pageSize+1 probe (no OFFSET/COUNT), and the `keysetPageOf` helper.
- **Validation:** full backend suite **4137 / 0 / 3** (+5 C7 tests). `deno check` clean. Code-only, no migration. **Tracked deploy optimization:** a per-read-model `(organization_id, school_id, entity_type, id)` index maximizes the seek; the read-model tables are generic/per-module, so index tuning is a deploy-time step (EXPLAIN), not this code slice. **Follow-up:** the other read handlers (management/control_center/mobile) can adopt the identical opt-in cursor pattern.

## Parallel UI/UX lane (PROGRAM UXR)
Separate branch `feature/uxr-flutter-remediation` in worktree `/Users/surendrakanna/Documents/Akshara_ERP-uxr` (off trunk `aef2fbab`). Client-only Flutter polish independent of unfinished backend. ⚠ **UXR backlog docs (roadmap §5.6 PROGRAM UXR + `UXR_FINDINGS_REGISTER.md` + the audit) are on the QPL branch in the MAIN worktree `/Users/surendrakanna/Documents/Akshara_ERP`, NOT on the trunk/uxr worktree** — read backlog there, implement code in the uxr worktree. Done: I1+B4, G2(P0), D2, G6. Web items owner-FROZEN; backend-dependent + owner-gated UXR deferred. See memory [[uxr-flutter-ui-lane]].
