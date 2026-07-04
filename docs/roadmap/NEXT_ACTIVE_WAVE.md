# Akshara ERP — NEXT ACTIVE WAVE

**This is the ONLY file Opus 4.8 reads before each autonomous wave** — together with its state companion [`../execution/EXECUTION_DASHBOARD.md`](../execution/EXECUTION_DASHBOARD.md). Keep it small — current work only.
**Updated by:** the executor at each wave boundary (on EOS PASS + commit → advance to the next wave; refresh the dashboard at the same moment).
**Authority:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) · run per [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) · journal to [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md).

> **Previous waves:** **P1-CODE-1 (REL-1..5) ✅** · **P1-CODE-2 (REL-6..9) ✅** · **P1-CODE-3 (backend hardening) ✅** · **P1-CODE-5 — HR payroll engine ✅** · **P1-PROD-0 — XCT foundations ✅ COMPLETE (2026-07-04, `83bc267`)** — EOS FOUNDATION PASS. **XCT-1** shared PDF-table primitive `buildGridTable` (3 bespoke tabular-PDF builders consolidated onto the ONE pipeline that ~15 modules already ride). **XCT-2** reminder rail `_shared/reminders/reminders_service.ts` (`scheduleReminder` + `runDueReminders = runDueScheduledBroadcasts` — one runner; a due reminder fires end-to-end into a pending in-app delivery, proven by test). **XCT-3** shared read-only `AksharaDateField` → `showDatePicker` (HR leave create+on-behalf ×4 + probation + intelligence meeting-date). analyze 0 · suite 3611 pass (0 new fails) · deno touched 108/1-known-ISO-COUNT.

---

## ▶ CURRENT

- **Phase:** **P1 — Backend & Code Fixes** 🟠
- **Wave:** **P1-PROD-1 — C1 · Finance Fee Recovery / Collections CRM (FIN-R1..R5)** — 🔵 next up
- **Sequencing:** C1 depends only on **C0 (P1-PROD-0 ✅, done)**. **P2-UX-1 (feel & trust pack) is ∥-eligible** to start under disjoint file ownership once P0 exits. **P1-CODE-4 (Identity) stays owner-gated (👤 batch below) — surfaced, NOT blocking.** Live lane (`P0-INFRA-1/3`, `P0-TEST-1/2/3`) stays owner-deferred.

### P1-PROD-1 tasks (this wave) — findings FIN-R1..R5
> ⚠ **Discovery-first:** a `finance_recovery_crm.sql` migration + `finance_recovery_actions.dart` already exist (recovery-contacts / promises-to-pay / targets). Per XCT-style discipline this wave **verifies what's built, expands the defaulter list into the CRM (does not duplicate), and closes gaps** — not a rebuild. Assess coverage before writing.

| Sub | Sev | What |
|---|---|---|
| **FIN-R1** | P1 | Recovery dashboard (defaulter list *expands* into a real recovery view). |
| **FIN-R2** | P1 | Telecaller call queue. |
| **FIN-R3** | P1 | Promise-to-pay (PTP). |
| **FIN-R4** | P1 | Contact / reminder history (persisted). |
| **FIN-R5** | P1 | Collector performance metrics (computed from real data). |

### EOS gate
- Scope: **FEATURE (Finance)**. PASS required. **Completion (roadmap `FINAL_QA_ROADMAP.md:551`):** call queue → log outcome → PTP → contact-history persist **round-trip**; collector metrics compute from real data. Regression: `flutter analyze` 0 · `flutter test` no NEW failures (2 known UX-7) · `deno test`+`deno check` green for any touched `supabase/functions/**` (finance). Money-safety tripwires apply (no duplicate financial txn; maker-checker where value-reducing per [[fin-d4-fee-concession-decision]]).

### 👤 SURFACED OWNER DECISIONS — identity cluster (gates P1-CODE-4, resolve in a batch)
See [[akshara-decision-queue]] + [[student-identity-architecture-decision]]. These do **not** pause the pipeline; they gate **P1-CODE-4 (Identity finish)** only:
- **PLAT-0** — build Public Student ID (PSID) now vs defer post-pilot.
- **C5 / ADM-D3** — admission-number immutability (set-once-locked vs editable).
- **IC-1…IC-6** — esp. `users.phone` NOT NULL UNIQUE = de-facto identity; is a **change-phone flow (PLAT-4)** in scope for P1-CODE-4, or deferred?
- **SIS-D1** — TC / no-dues gate on identity transitions.
- **Admissions approval SoD** — maker-checker on admission approval.
- **MOD-1 (👤)** — Finance-posting scope also gates the unified recovery-CRM scope; surface if C1 reaches that edge.

### Next
On P1-PROD-1 EOS PASS + commit → **P1-PROD-2 (C2)** per the C-wave table (`FINAL_QA_ROADMAP.md` §Phase C); once the identity batch above is resolved → **P1-CODE-4**. Owner-scope tasks P1-CODE-6/7/8 (Finance-posting / Hostel / Alumni) remain 👤 — surface when reached.

> **Deferred live-lane tail (run in the dedicated live phase):** `P0-INFRA-1` off-site backup · `P0-INFRA-3` alert delivery · `P0-TEST-1/2/3` CI + isolation-in-CI + live-regression cron.
> **Tracked pre-existing defect (NOT a wave regression):** `ISO-COUNT` — 5 "tenant isolation probe count" tests (communication/payment/pilot/sis) assert stale totals (220/213) vs the registry's actual 233 probes; fails at pre-wave commits too. Reconcile the counts + verify the +13 probes. Small, isolated.

### Regression required
- `deno test` + `deno check` green for touched `supabase/functions/**` · `flutter analyze` 0 · `flutter test` no NEW failures (beyond the 2 known UX-7).

### Exit criteria (all true → wave complete)
- [ ] Recovery CRM round-trip works: call queue → log outcome → PTP → contact-history persists (verified, gaps closed, no duplication of the existing defaulter list).
- [ ] Collector performance metrics compute from real data.
- [ ] `/eos` FEATURE PASS; journal row + roadmap P1-PROD-1 ✅ + ledger FIN-R1..R5; advance this file to **P1-PROD-2 (C2)** + refresh the dashboard.

> **Rule:** never begin the next wave with an open P0 or an EOS BLOCKED. Owner-decision (👤) tasks surface in a batch and do not pause the pipeline; live-lane (⏳) tasks defer until provisioned; non-blocked tasks proceed.
