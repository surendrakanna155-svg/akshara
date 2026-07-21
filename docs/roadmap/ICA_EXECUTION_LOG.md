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
**Full backend suite (all batches together): `deno test supabase/functions/` → 4048 passed · 0 failed · 3 ignored** (the 3 ignored = the env-gated real-DB isolation tests, i.e. the ICA-D4 CI gap — a separate backlog item). `deno check` on every changed source → exit 0.

## Migration slots consumed on the trunk (for cross-lane fold-in coordination)
`…060` (A1 recovery backfill) · `…062` (A6 payment NUMERIC) · `…070` (A2 offline guard) · `…080` (B1 guardian RLS) · `…090` (E1 single-current) · `…100` (C1 attendance indexes) · `…110` (B3 DEFINER guards) · `…130` (D3 idempotency reaper) · `…140` (B6 audit school-bind). **Current trunk max = `…140`.** **⚠ ASIP fold-in note:** the ASIP KB migration `…060` collides with A1's `…060` (tracked ASIP P1-D); its planned renumber to `…090` is also taken — **the ASIP fold-in must pick `…150`+ (above this trunk's current max `…140`).** Not actioned here (ASIP is a separate lane).

## Deploy-gated tail (owner-gated — NOT auto-run here)
These complete the "live certification" lifecycle step and run at the **owner-gated trunk→pilot redeploy** (deploy authority is owner-held; the shared VPS is production):
1. A2 concurrent double-credit live-cert.
2. B1 runtime RLS probe (7 de-authorized surfaces = 0 rows; still-active guardian = full rows).
3. A1 recovery-dashboard rupee-figure check against a seeded ledger + the one-time `…060` money backfill (owner confirms recovery-CRM row presence on the pilot before applying).
4. A5 gate: the webhook signature enforcement must be in the deployed build before the route is exposed / live gateway enabled.

## Remaining ICA backlog

**Done so far (Batches 1–5):** A1, A2, A5, A6, B1, B3, B4, B5, B6, B8, B9, C1, C3, D1, D3, E1, H1, H3, H4(+ext). **19 of 49 items** (all P0s + the live/reachable set + first tranche of W10/W11 hardening).

- **Owner-gated (do NOT auto-implement):** ICA-G1 (`domain_events` bus vs log), ICA-G2 (entitlement-flip timing), ICA-G3 (per-tenant custom roles), ICA-B2 policy (OTP pilot-phone removal). Raised in the ICA owner-decision batch (§5.6).
- **ASIP session (do NOT implement here):** ICA-G4 (client mock/real fail-closed) + **ICA-B7** (support mirror bridge incident-id guard) — both modify the ASIP support lane; handled by the dedicated AI Support Engineering session.
- **Still buildable (next batches, unblocked):**
  - Perf/W10: **C2** (dashboard all-time aggregates → bounded/matview), **C4** (`bulkAssignFeeStructure` N+1), **C5** (connection-pool ceiling / pooler — infra), **C6** (broadcast >5,000 truncation), **C7** (keyset pagination).
  - Reliability/CI: **A7 + D4 + D5 + D6** (real-DB concurrency + CI postgres gate + atomic-claim + SoD double-decide — a coherent CI-infra sub-batch), **D7** (backend coverage gate).
  - Data model: **E2** (soft FKs), **E3** (migration idempotency guards).
  - Architecture/W10: **F1** (auth middleware — same target as the W10 central-chokepoint item), **F2** (single student-identity service), **F3** (god-file decomposition), **F4** (prefix→router registry), **F5** (JSONB↔relational invariant), **F6** (`inventory_finance` single router), **F7** (raw SQL → repository), **F8** (dead code + hot-path dynamic imports).
  - Domain/finance: **A3** (receipt-number scoping — gate before multi-school receipt-sequencing), **H2** (TC dues-wording vs inventory/library gate).
