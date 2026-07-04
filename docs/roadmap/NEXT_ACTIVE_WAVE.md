# Akshara ERP — NEXT ACTIVE WAVE

**This is the ONLY file Opus 4.8 reads before each autonomous wave** — together with its state companion [`../execution/EXECUTION_DASHBOARD.md`](../execution/EXECUTION_DASHBOARD.md). Keep it small — current work only.
**Updated by:** the executor at each wave boundary (on EOS PASS + commit → advance to the next wave; refresh the dashboard at the same moment).
**Authority:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) · run per [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) · journal to [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md).

> **Previous waves:** **P1-CODE-1 (REL-1..5) ✅** · **P1-CODE-2 (REL-6..9) ✅** · **P1-CODE-3 (backend hardening) ✅** · **P1-CODE-5 — HR payroll engine ✅** · **P1-PROD-0 — XCT foundations ✅ COMPLETE (2026-07-04, `83bc267`)** — EOS FOUNDATION PASS. **XCT-1** shared PDF-table primitive `buildGridTable` (3 bespoke tabular-PDF builders consolidated onto the ONE pipeline that ~15 modules already ride). **XCT-2** reminder rail `_shared/reminders/reminders_service.ts` (`scheduleReminder` + `runDueReminders = runDueScheduledBroadcasts` — one runner; a due reminder fires end-to-end into a pending in-app delivery, proven by test). **XCT-3** shared read-only `AksharaDateField` → `showDatePicker` (HR leave create+on-behalf ×4 + probation + intelligence meeting-date). · **P1-PROD-1 — C1 Finance Fee-Recovery CRM ✅ COMPLETE (2026-07-04, `c1b9feb`)** — EOS FEATURE PASS. Discovery-first: FIN-R1/R3/R5 verified existing (not rebuilt). Built **FIN-R2 telecaller call queue** (server-ranked "who to call next" riding the same open/overdue accounts the defaulters list uses — no duplicate source; broken→due→never-contacted→stale ranking; `GET /finance/recovery/call-queue`; client `_CallQueueSection` reusing the existing dialogs; log/PTP re-ranks live) + fixed **FIN-R4** (history sheet → live provider). analyze 0 · suite 3613 pass (0 new fails) · deno finance 143/0.

---

## ▶ CURRENT

- **Phase:** **P1 — Backend & Code Fixes** 🟠
- **Wave:** **P1-PROD-2 — C2 · Finance Counter, Statements & Reports (FIN-1, FIN-2, FIN-6, FIN-7, FIN-8)** — 🔵 next up
- **Sequencing:** C2 depends only on **C0 (P1-PROD-0 ✅, XCT-1 export pipeline)**. **P2-UX-1 ∥-eligible** under disjoint ownership. **P1-CODE-4 (Identity) stays owner-gated (👤 batch below) — surfaced, NOT blocking.** Live lane (`P0-INFRA-1/3`, `P0-TEST-1/2/3`) stays owner-deferred.

### P1-PROD-2 tasks (this wave) — findings FIN-1/2/6/7/8
> ⚠ **Discovery-first (C1 proved this valuable — most of the wave was verify-not-rebuild):** assess existing scaffolding before writing. Exports MUST ride the **XCT-1 shared pipeline** (`AksharaReportExportService` — `buildGridReportPdf`/`shareGridCsv`/`buildGridTable`); do not hand-roll CSV/PDF.

| Sub | Sev | What |
|---|---|---|
| **FIN-1** | P1 | Daily collection summary export. |
| **FIN-2** | P1 | Printable student fee statement / ledger. |
| **FIN-6** | P1 | Installment / term-wise due schedule (replaces the hardcoded +30d due date; **drives aging**). |
| **FIN-7** | P1 | Transaction-level day collection report. |
| **FIN-8** | P1 | Class-wise dues report. |

### EOS gate
- Scope: **FEATURE (Finance)**. PASS required. **Completion (roadmap `FINAL_QA_ROADMAP.md:552`):** each report exports **real transactions**; installment due dates drive aging. Regression: `flutter analyze` 0 · `flutter test` no NEW failures (2 known UX-7) · `deno test`+`deno check` green for any touched `supabase/functions/**` (finance). Money-safety tripwires apply (reports are read-only; FIN-6 due-schedule is informational — the invoice's single outstanding stays authoritative, no per-term money movement).

### 👤 SURFACED OWNER DECISIONS — identity cluster (gates P1-CODE-4, resolve in a batch)
See [[akshara-decision-queue]] + [[student-identity-architecture-decision]]. These do **not** pause the pipeline; they gate **P1-CODE-4 (Identity finish)** only:
- **PLAT-0** — build Public Student ID (PSID) now vs defer post-pilot.
- **C5 / ADM-D3** — admission-number immutability (set-once-locked vs editable).
- **IC-1…IC-6** — esp. `users.phone` NOT NULL UNIQUE = de-facto identity; is a **change-phone flow (PLAT-4)** in scope for P1-CODE-4, or deferred?
- **SIS-D1** — TC / no-dues gate on identity transitions.
- **Admissions approval SoD** — maker-checker on admission approval.
- **MOD-1 (👤)** — Finance-posting scope also gates the unified recovery-CRM scope (C1 did not reach that edge — call queue rode the existing defaulter source); surface if a later finance wave needs it.

### Next
On P1-PROD-2 EOS PASS + commit → **P1-PROD-3 (C3 — Staff Attendance Dashboard & Muster; note: needs Phase B B4 / GA-1 live)** or the next unblocked C-wave per the C-table (`FINAL_QA_ROADMAP.md` §Phase C); once the identity batch above is resolved → **P1-CODE-4**. Owner-scope tasks P1-CODE-6/7/8 (Finance-posting / Hostel / Alumni) remain 👤 — surface when reached.

> **Deferred live-lane tail (run in the dedicated live phase):** `P0-INFRA-1` off-site backup · `P0-INFRA-3` alert delivery · `P0-TEST-1/2/3` CI + isolation-in-CI + live-regression cron.
> **Tracked pre-existing defect (NOT a wave regression):** `ISO-COUNT` — 5 "tenant isolation probe count" tests (communication/payment/pilot/sis) assert stale totals (220/213) vs the registry's actual 233 probes; fails at pre-wave commits too. Reconcile the counts + verify the +13 probes. Small, isolated.

### Regression required
- `deno test` + `deno check` green for touched `supabase/functions/**` · `flutter analyze` 0 · `flutter test` no NEW failures (beyond the 2 known UX-7).

### Exit criteria (all true → wave complete)
- [ ] Each C2 report (FIN-1/2/7/8) exports **real transactions** through the XCT-1 shared pipeline (verified, gaps closed, no hand-rolled CSV/PDF).
- [ ] FIN-6 installment/term due schedule replaces the hardcoded +30d and drives aging (informational — no per-term money movement).
- [ ] `/eos` FEATURE PASS; journal row + roadmap P1-PROD-2 ✅ + ledger FIN-1/2/6/7/8; advance this file to the next C-wave + refresh the dashboard.

> **Rule:** never begin the next wave with an open P0 or an EOS BLOCKED. Owner-decision (👤) tasks surface in a batch and do not pause the pipeline; live-lane (⏳) tasks defer until provisioned; non-blocked tasks proceed.
