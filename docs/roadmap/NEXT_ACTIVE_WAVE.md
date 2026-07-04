# Akshara ERP — NEXT ACTIVE WAVE

**This is the ONLY file Opus 4.8 reads before each autonomous wave** — together with its state companion [`../execution/EXECUTION_DASHBOARD.md`](../execution/EXECUTION_DASHBOARD.md). Keep it small — current work only.
**Updated by:** the executor at each wave boundary (on EOS PASS + commit → advance to the next wave; refresh the dashboard at the same moment).
**Authority:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) · run per [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) · journal to [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md).

> **Previous waves:** **P1-CODE-1 (REL-1..5) ✅** · **P1-CODE-2 (REL-6..9) ✅** · **P1-CODE-3 (backend hardening) ✅** · **P1-CODE-5 — HR payroll engine ✅ COMPLETE (2026-07-04)** — EOS FEATURE PASS across `56939bb` (backend engine: salary structures + draft-run generation, money-safe, 409 `EMPLOYEE_CODE_TAKEN`) + `770ed00` (client structure→generate→run UI incl. fresh-school empty-state bootstrap; leave dialog's hardcoded employeeId → real employee picker; payroll un-hidden behind `module.hr_payroll` 402). deno HR 85/0 · analyze 0 · suite 3605 pass (0 new fails).

---

## ▶ CURRENT

- **Phase:** **P1 — Backend & Code Fixes** 🟠
- **Wave:** **P1-PROD-0 — XCT foundations (C0)** — 🔵 next up (unblocks ALL C-waves P1-PROD-1..21 + P3 W1.4)
- **Sequencing:** P1-PROD-0 depends only on P0 (done for the code lane). **P1-CODE-4 (Identity) stays owner-gated (👤 identity-decision batch below) — surfaced, NOT blocking.** Live lane (`P0-INFRA-1/3`, `P0-TEST-1/2/3`) stays owner-deferred. ⚠ **Owner instruction (2026-07-04): STOP after P1-CODE-5 close — do NOT auto-start this wave; wait for explicit owner approval.**

### P1-PROD-0 tasks (this wave) — findings XCT-1/2/3
| Sub | Sev | What |
|---|---|---|
| **XCT-1** | P1 | Shared export pipeline (grid → CSV/PDF service). ⚠ Partially built + reused (finance/HR/teacher exports ride it) — this wave VERIFIES coverage/consistency and closes gaps, not a rebuild. |
| **XCT-2** | P1 | Reminder / scheduling rail (in-app reminders; needed later by P3 W1.4 nightly jobs, fee-reminder ladders). |
| **XCT-3** | P1 | Real date pickers replacing free-text `YYYY-MM-DD` fields (HR leave/probation dialogs are known offenders). |

### EOS gate
- Scope: **FOUNDATION**. PASS required. Done-when (roadmap): **≥3 real exports · ≥1 in-app reminder fires · date pickers in place**. Regression: `flutter analyze` 0 · `flutter test` no NEW failures (2 known UX-7) · deno green for any touched `supabase/functions/**`.

### 👤 SURFACED OWNER DECISIONS — identity cluster (gates P1-CODE-4, resolve in a batch)
See [[akshara-decision-queue]] + [[student-identity-architecture-decision]]. These do **not** pause the pipeline; they gate **P1-CODE-4 (Identity finish)** only:
- **PLAT-0** — build Public Student ID (PSID) now vs defer post-pilot.
- **C5 / ADM-D3** — admission-number immutability (set-once-locked vs editable).
- **IC-1…IC-6** — esp. `users.phone` NOT NULL UNIQUE = de-facto identity; is a **change-phone flow (PLAT-4)** in scope for P1-CODE-4, or deferred?
- **SIS-D1** — TC / no-dues gate on identity transitions.
- **Admissions approval SoD** — maker-checker on admission approval.

### Next
On P1-PROD-0 EOS PASS + commit → **P1-PROD-1 (C1 — Finance Recovery CRM)** per the C-wave table (`FINAL_QA_ROADMAP.md` §Phase C); once the identity batch above is resolved → **P1-CODE-4**. Owner-scope tasks P1-CODE-6/7/8 (Finance-posting / Hostel / Alumni) remain 👤 — surface when reached.

> **Deferred live-lane tail (run in the dedicated live phase):** `P0-INFRA-1` off-site backup · `P0-INFRA-3` alert delivery · `P0-TEST-1/2/3` CI + isolation-in-CI + live-regression cron.
> **Tracked pre-existing defect (NOT a wave regression):** `ISO-COUNT` — 5 "tenant isolation probe count" tests (communication/payment/pilot/sis) assert stale totals (220/213) vs the registry's actual 233 probes; fails at pre-wave `3957fab` too. Reconcile the counts + verify the +13 probes. Small, isolated.

### Regression required
- `deno test` + `deno check` green for touched `supabase/functions/**` · `flutter analyze` 0 · `flutter test` no NEW failures (beyond the 2 known UX-7).

### Exit criteria (all true → wave complete)
- [ ] ≥3 real exports ride ONE shared pipeline (verified, gaps closed).
- [ ] ≥1 in-app reminder fires through the new scheduling rail (test proves it).
- [ ] Free-text `YYYY-MM-DD` fields replaced with real date pickers on the known offenders.
- [ ] `/eos` FOUNDATION PASS; journal row + roadmap P1-PROD-0 ✅ + ledger XCT-1/2/3; advance this file to **P1-PROD-1 (C1)** + refresh the dashboard.

> **Rule:** never begin the next wave with an open P0 or an EOS BLOCKED. Owner-decision (👤) tasks surface in a batch and do not pause the pipeline; live-lane (⏳) tasks defer until provisioned; non-blocked tasks proceed.
