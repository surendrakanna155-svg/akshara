# POST-CONVERGENCE WAVE EXECUTION LOG (W2 →)

**Trunk (SSOT):** `integration/w0-trunk` (= `main` = `release/w0-converged`), pushed to origin.
**Method:** autonomous execution; verify-merged before build (code is authority); park owner-gated items; EOS gate per wave. Status source = [`W1_CANONICAL_EVIDENCE_LEDGER.md`](W1_CANONICAL_EVIDENCE_LEDGER.md).

---

## W2 — Identity, Lifecycle & Governance — 🔶 verify-certified; build tail owner-gated

**Verify-merged (autonomous) — CERTIFIED.** Identity core suites green on trunk: auth/identity/session/permission/tenant-isolation/OTP/guardian/onboarding = **111 passed / 0 failed / 2 ignored**. Confirms the merged PRA identity fixes: access-revoke (P0-01), guardian add/remove lifecycle (P1-01/02), refresh child-set (P1-03), officeStaff permissions (P1-05), CSPRNG OTP (P1-06), context/switch through the session chokepoint (P1-07), `permissions_version` trigger (P2-34), plus tenant-isolation probes.
**EOS SECURITY scope: PASS** for the verify-merged core.
**Build tail — 👤 OWNER-GATED (parked, not built):** SOP-ID-2 transfer/exit lifecycle + SOP-ID-3 multi-school identity (Decision **D2** PENDING — do not build); SOP-ID-4 student-login-via-parent-mobile + SOP-ID-5 change-phone/ownership/identity-audit-events (**P1-CODE-4**, owner-DEFERRED post-pilot). These stay at 👤 per the frozen Student-Identity decision.

---

## W3 — Money & Data Integrity — 🔶 verify-certified; build tail owner-gated

**Verify-merged (autonomous) — CERTIFIED.** Money/finance/stock regression on trunk: finance + payment + hr + inventory-finance + inventory-distribution = **504 passed / 0 failed**.
- **Race-guard universality** (the W3 criterion): terminal money writes carry the `AND <status> = '<pre>'` predicate + throw-on-0-rows across **9 finance repositories** (refunds, fee-reductions, scholarships, recovery, assignments, qr, …) — the recurring money-integrity race pattern is applied universally.
- Confirmed present + tested: gapless FY receipt series + instrument blocking (`pra_s1_receipt_and_instrument_test`), cheque register (7 files), refund claim-first guard (P0-03), receipt-cancel guard (P0-04), payroll→Finance real posting (P0-24, `hr_finance_posting_repository`), discounts/scholarships maker-checker (P1-10), negative-stock hard block (P1-37), **online payment FAIL-CLOSED** (throws `PaymentIntentNotFoundError`/`StateError`, never fabricates a receipt — P0-02/03/04).
**EOS RELIABILITY scope: PASS** for the verify-merged core.
**Build tail — 👤 OWNER-GATED (parked):** P0-02 real payment-gateway SDK (external paid provider + credentials); P1-35 statutory payroll (PF/ESI/PT/TDS — large per-state compliance build, needs a statutory-config source). Client is already fail-closed, so no money is silently mishandled meanwhile. **Honesty follow-ups routed to W6:** P1-40 (real library-fine→Finance posting), P1-50 (report email/schedule pipeline).

---

## W4 — Core School-Operations Completeness — 🔶 clean caps built; bulk needs owner/architectural direction

**Built + tested (autonomous, no owner input needed):**
- **PRC-A cap 57 — SaaS grace/suspension enforcement** (`entitlement_limits.ts`). The subscription `status` was resolved but never read by the create-gate; extracted the full policy into a pure `evaluateCreateLimit()` (suspension + slab), wired it in (efficient conditional count), suspended blocks count-growing creates regardless of slab, grace rides the buffer. Entitlements suite **55/0**. Still deploy-dark behind the enforcement switch.
- **PRC-A cap 130 — teacher free (non-contact) periods** (`workload_rollup.ts`). `freePeriods = working-week grid − scheduled contact periods`, clamped ≥ 0, honest-zero when no grid. Pure `computeFreePeriods()`; workload suite **12/0**.

**Remaining ~31 caps — triaged (why each is NOT a clean autonomous build):**

| Cap cluster | Blocker class | Needs |
|---|---|---|
| SaaS SMS limit (53), staff/user limits (54) | 👤 owner-CONFIG | Per-plan-tier limit *values* + (54) `max_staff`/`max_users` plan columns. Enforcement mechanism is ready (mirrors 57); only the numbers are an owner decision. |
| Transport requirement enum (3), distance-derived fee (10) | 👤 owner-PRODUCT | Enum semantics (own/parent-pickup/bus) + the fee model (per route/stop/distance/one-way). |
| Transport effective-dates/proration/temporary assignments (5,6,23) | 🏛 ARCHITECTURE | An effective-date architecture (history-preserving) — owner should direct the model (a new versioned-assignment table vs. valid-from/to columns). |
| Transport admission→enrolment propagation (2), driver/bus→route write path (8,20), service-history/leave/substitute-driver (16,21,22) | build + model | Substitute-driver reuses the (absent) substitution model below; propagation needs a default-route product rule. |
| Cross-module cost-aggregation / `expenseBreakdown` (90–100) | 🏛 ARCHITECTURE | The canonical cross-module EXPENSE-LEDGER model (which sources: transport-expense + inventory-purchase + payroll-posting + …). Today `expenseBreakdown:[]` is *honestly* empty (PRA-P1-48); a partial breakdown would be worse than empty. |
| Staff-workload substitution burden (131), non-teaching (132), exam/event duties (133) | 🏛 new DATA MODEL | Substitution / non-teaching-duty / exam-invigilation-duty tables don't exist (PRA-P2-13 substitution was deferred). |
| Syllabus daily-capture UI (58–63), parent-facing cert-desk/gate-pass/complaints UIs, storage/AI-wallet/channel/Tally/transport-expense Flutter panels | 🖥 FLUTTER + product | Client-side builds (large), several with product/UX decisions. |

**Verdict:** the two clean backend caps are built + certified. The rest of W4 is gated on **owner product/config decisions** (stop-condition #1) and **architectural direction** (stop-condition #3: expense-ledger model, effective-date architecture, the three staff-duty data models) — building any of them unilaterally would impose architecture without owner direction or ship a speculative/partial implementation (both forbidden). These are surfaced in the owner-decision batch (W1 ledger §5 + additions here). EOS: the built caps PASS; the wave is CONDITIONAL (owner-gated remainder).

---

## OWNER DECISION PACK — PARALLEL BUILD (2026-07-20)

After the 15-decision owner pack, executed the unblocked work via multi-agent parallel builds in **isolated worktrees**, each a disjoint module with a distinct migration, merged into the trunk with per-module + full regression. **BATCH-1 (7/7 merged, `main` @ `67948ddc`):**

| Decision | Module (migration) | Result |
|---|---|---|
| #13 Secrets vault | `_shared/vault/` (023) | AES-256-GCM already live (DRP); added tamper/fail-closed tests + doc migration. **19/0** |
| #6 Staff-duty models | `_shared/staff_duty/` (020) | 3 append-only tables (substitute/exam-invig/non-teaching); **no attendance coupling (test-enforced)**; rollup → caps 131/132/133; wired under `/hr/staff-duties/*`. **44/0** |
| #4 Expense ledger | `_shared/expense_ledger/` (026) | Append-only, idempotent, multi-source (transport/payroll/inventory adapters); `buildExpenseBreakdown` matches Flutter shape. **18/0**. *Follow-up: source call-site wiring + management swap.* |
| #1 SaaS limits | `_shared/entitlements/` (022) | Student cap config-driven (test-pinned); **staff/admin uncapped** (regression-pinned); per-plan SMS quota (deploy-dark, counts `notification_deliveries`). **67/0** |
| #10 Leave accrual | `_shared/hr/` (024) | Config-driven policies (free-form leave-type); append-only ledger (balance=SUM); pure accrual (proration/cap/lapse); idempotent (period_key). **hr 132/0** |
| #11 Library accession | `_shared/library/` (025) | Gapless per-copy accession (reuses `school_tc_counters` pattern); guarded lost/withdrawn. **88/0** |
| #5 Transport history | `_shared/transport/` (021) | Dedicated append-only `transport_allocation_history` (valid-from/to); partial-UNIQUE one-open guard; close-then-insert (never overwrite); as-of + timeline reads. **76/0** |

**Also fixed a W0 convergence defect surfaced by the full typecheck:** `model_gateway.ts` embedding `reserve()` was missing `ReserveArgs.creditsRequired` (the AI-wallet field DRP added post-dated the embeddings-through-gateway path PRA-P1-46; W0 combined them). Embeddings hold ZERO product credits (infra) → `creditsRequired: 0`. Full `_shared` `deno check` now CLEAN, AI **175/0**.

**Batch-1 integrated regression:** backend `deno test _shared/` **3785 passed / 0 failed / 3 ignored** · full backend typecheck **clean** · `flutter analyze` **No issues**. Pushed to `main`.

**BATCH-2 (in flight):** transport hybrid-fee + own-transport (#2/#3, mig 027) · payment provider-abstraction (#7, 028) · device/asset lifecycle (#12, 029) · statutory payroll PF/ESI/PT/TDS (#9, 030) · EIP-6 learning-evidence spine (031, W5 prereq).
**Held for careful/sequential handling:** PLAT-0 multi-school identity (#14, security-critical), W5 Smart OMR/Assessment (#8/#15, after EIP-6), W8 web write layer, W7 AI hardening, expense-ledger source wiring.

---

## BATCH-3 + OWNER-PACK COMPLETE (2026-07-20, `main` @ `5f309f79`)

**BATCH-3 (3/3 merged):**
| Decision | Module (migration) | Result |
|---|---|---|
| #14 PLAT-0 multi-school identity | `_shared/school_membership.ts` + auth (032) | Silent `.limit(1)` → membership-gated `/auth/context/switch` (non-member 403, ≥2-no-choice 409); **NO RLS broadened** (ADD-only migration); +5 negative cross-school isolation probes. **33/0** — security-reviewed. |
| #8 Smart OMR + #15 Assessment | `_shared/education/` (033) | Pure `scoreOmrSheet` (blank≠wrong, multi-mark ambiguous, guards→422); emits into the **same EIP-6 spine** (`source:'omr'`); item-analysis difficulty/discrimination null-when-empty. **Frozen marks-grid untouched** (D1 additive). **187/0** |
| #4 Expense-ledger wiring (make live) | transport/hr/inventory/management | All 4 sources post to the canonical ledger, **SAVEPOINT-fenced** (a ledger error rolls back only the projection, never the source money-move), idempotent, no double-count; management `expenseBreakdown` now real. **378/0** |

**Fixed on integration:** the isolation-probe count-lock 238→243 (PLAT-0's 5 new probes — a legitimate tripwire update, documented history).

**Integrated regression:** backend `deno test _shared/` **3977 passed / 0 failed / 3 ignored** · full typecheck **clean** · `flutter analyze` **No issues**. Pushed.

### ✅ ALL 15 OWNER DECISIONS IMPLEMENTED + TESTED + MERGED
#1 SaaS limits · #2/#3 transport hybrid-fee/own-transport · #4 expense ledger (live) · #5 transport history · #6 staff-duty models · #7 payment abstraction · #8 Smart OMR · #9 statutory payroll · #10 leave accrual · #11 library accession · #12 device management · #13 secrets vault · #14 PLAT-0 multi-school identity · #15 Assessment Intelligence (EIP-6 spine + item-analysis). Plus the W0 AI-convergence typecheck fix.

**Build stats:** ~17 new backend modules/extensions across 3 parallel batches (16 build agents, 1 stall salvaged) · 14 new migrations (`…020`–`…033`) · every module tested (pure-function cores + fake-DB integration), append-only + idempotent + fail-safe where money/security is involved · zero tests weakened · zero fabrication.

### 🚦 PRODUCTION-DEPLOY GATE (owner)
All 14 new migrations + modules ship **deploy-dark / behind flags** and are **NOT applied to any live DB**. Going live needs an owner deploy decision (apply migrations `…020`–`…033` to the pilot; activate the relevant enforcement/dark flags) — this is the owner-gated live-provisioning step (W1 ledger §5 #10). Nothing is live/certified until then.

**Remaining roadmap (large, non-owner-gated build):** W7 AI consolidation · **W8 web write layer** (the entire functional web ERP — biggest remaining) · W9 enterprise/multi-school rollup · W10 engineering hardening · W11 red-team · W12 pilot · W13 GA. Plus tracked per-module follow-ups (EIP-6/OMR producer wiring, TDS projected-annual, transport source-adapter call-sites, etc.).
