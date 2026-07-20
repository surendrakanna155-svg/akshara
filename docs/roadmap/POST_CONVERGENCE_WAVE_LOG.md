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
