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

## Validation (trunk, this batch)
`deno check` all changed source → exit 0 · payment dir **38/0** · finance dir **307/0** · shared guards + trunk-integrity + money invariant **11/0**.

## Deploy-gated tail (owner-gated — NOT auto-run here)
These complete the "live certification" lifecycle step and run at the **owner-gated trunk→pilot redeploy** (deploy authority is owner-held; the shared VPS is production):
1. A2 concurrent double-credit live-cert.
2. B1 runtime RLS probe (7 de-authorized surfaces = 0 rows; still-active guardian = full rows).
3. A1 recovery-dashboard rupee-figure check against a seeded ledger + the one-time `…060` money backfill (owner confirms recovery-CRM row presence on the pilot before applying).
4. A5 gate: the webhook signature enforcement must be in the deployed build before the route is exposed / live gateway enabled.

## Remaining ICA backlog (not in this batch)
- **Owner-gated (do NOT auto-implement):** ICA-G1 (`domain_events` bus vs log), ICA-G2 (entitlement-flip timing), ICA-G3 (per-tenant custom roles), ICA-B2 policy (OTP pilot-phone removal). Raised in the ICA owner-decision batch (§5.6).
- **ASIP session (do NOT implement here):** ICA-G4 (client mock/real fail-closed → ASIP support fabricated tickets) — handled by the dedicated AI Support Engineering session.
- **Feeds W10 (hardening) / W4-W5 (domain):** ICA-A3/A4/A7, ICA-B3…B9, ICA-C1…C7, ICA-D1…D7, ICA-E1…E3, ICA-F1…F8, ICA-H1…H4 — buildable next under their waves' EOS gates (see §5.6 absorption map).
