# Akshara ERP — NEXT ACTIVE WAVE

**This is the ONLY file Opus 4.8 reads before each autonomous wave** — together with its state companion [`../execution/EXECUTION_DASHBOARD.md`](../execution/EXECUTION_DASHBOARD.md). Keep it small — current work only.
**Updated by:** the executor at each wave boundary (on EOS PASS + commit → advance to the next wave; refresh the dashboard at the same moment).
**Authority:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) · run per [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) · journal to [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md).

> **Previous waves:** **P1-CODE-1 (REL-1..5) ✅** · **P1-CODE-2 (REL-6..9) ✅** · **P1-CODE-3 (backend hardening) ✅** · **P1-CODE-5 — HR payroll engine ✅** · **P1-PROD-0 — XCT foundations ✅ COMPLETE (2026-07-04, `83bc267`)** — EOS FOUNDATION PASS. **XCT-1** shared PDF-table primitive `buildGridTable` (3 bespoke tabular-PDF builders consolidated onto the ONE pipeline that ~15 modules already ride). **XCT-2** reminder rail `_shared/reminders/reminders_service.ts` (`scheduleReminder` + `runDueReminders = runDueScheduledBroadcasts` — one runner; a due reminder fires end-to-end into a pending in-app delivery, proven by test). **XCT-3** shared read-only `AksharaDateField` → `showDatePicker` (HR leave create+on-behalf ×4 + probation + intelligence meeting-date). · **P1-PROD-1 — C1 Finance Fee-Recovery CRM ✅ COMPLETE (2026-07-04, `c1b9feb`)** — EOS FEATURE PASS. Discovery-first: FIN-R1/R3/R5 verified existing (not rebuilt). Built **FIN-R2 telecaller call queue** (server-ranked "who to call next" riding the same open/overdue accounts the defaulters list uses — no duplicate source; broken→due→never-contacted→stale ranking; `GET /finance/recovery/call-queue`; client `_CallQueueSection` reusing the existing dialogs; log/PTP re-ranks live) + fixed **FIN-R4** (history sheet → live provider). · **P1-PROD-2 — C2 Finance Counter/Statements/Reports ✅ COMPLETE (2026-07-04, `fa30e00`)** — EOS FEATURE PASS. Discovery-first: FIN-1/2/7/8 verified existing (real exports on the XCT-1 shared pipeline). Closed **FIN-6**: `issueInvoice` drops the hardcoded +30 (uses `due_days` + generates the schedule); new shared `finance_aging.overdueDaysSql` makes **installment due dates drive aging** across defaulters / recovery call-queue / finance-intelligence / student-risk (behaviour-preserving for the default single-term config). Backend-only · analyze 0 · deno finance 147/0 · intelligence 51/0.

---

## ▶ CURRENT

- **Phase:** **P1 — Backend & Code Fixes** 🟠
- **Wave:** **P1-PROD-3 — C4 · Exams — Fast Marks & Tabulation (EXM-1, EXM-2, EXM-3)** — 🔵 next up (O2 top-priority: Exams). **Note: C3 (Staff Attendance Dashboard & Muster) DEFERS** — it depends on Phase B B4 / GA-1 live (staff-attendance / live-lane, owner-gated) → skip to the next unblocked Band-1 wave = C4.
- **Sequencing:** C4 depends only on **C0 (P1-PROD-0 ✅, XCT-1 export pipeline)**. **P2-UX-1 ∥-eligible** under disjoint ownership. **P1-CODE-4 (Identity) stays owner-gated (👤 batch below) — surfaced, NOT blocking.** Live lane (`P0-INFRA-1/3`, `P0-TEST-1/2/3`) stays owner-deferred.

### P1-PROD-3 tasks (this wave) — findings EXM-1/2/3
> ⚠ **Discovery-first (C1+C2 proved this — most of each wave was verify-not-rebuild):** an exam-administration backend + marks-entry client already exist (P1-CODE-3 era + exam waves). Assess coverage before writing; close only the verified gaps. Any exports ride the **XCT-1 shared pipeline**.

| Sub | Sev | What |
|---|---|---|
| **EXM-1** | P1 | Fast marks entry (bulk/grid marks capture — speed + validation). |
| **EXM-2** | P1 | Tabulation (compute totals/averages/rank/grade across subjects). |
| **EXM-3** | P1 | Result/tabulation sheet export (mark sheet / tabulation register). |

### EOS gate
- Scope: **FEATURE (Exams)**. PASS required. **Completion (roadmap `FINAL_QA_ROADMAP.md` §Phase C, C4):** fast marks entry persists real marks; tabulation computes from real marks; tabulation sheet exports. Regression: `flutter analyze` 0 · `flutter test` no NEW failures (2 known UX-7) · `deno test`+`deno check` green for any touched `supabase/functions/**`. Respect the frozen exam-result status design ([[exam-result-status-design]]): absent/medical-leave/debarred = NULL marks + AB/ML/DB, excluded from totals/avg/rank/pass-fail/grade-dist.

### 👤 SURFACED OWNER DECISIONS — identity cluster (gates P1-CODE-4, resolve in a batch)
See [[akshara-decision-queue]] + [[student-identity-architecture-decision]]. These do **not** pause the pipeline; they gate **P1-CODE-4 (Identity finish)** only:
- **PLAT-0** — build Public Student ID (PSID) now vs defer post-pilot.
- **C5 / ADM-D3** — admission-number immutability (set-once-locked vs editable).
- **IC-1…IC-6** — esp. `users.phone` NOT NULL UNIQUE = de-facto identity; is a **change-phone flow (PLAT-4)** in scope for P1-CODE-4, or deferred?
- **SIS-D1** — TC / no-dues gate on identity transitions.
- **Admissions approval SoD** — maker-checker on admission approval.
- **MOD-1 (👤)** — Finance-posting scope also gates the unified recovery-CRM scope (C1 did not reach that edge — call queue rode the existing defaulter source); surface if a later finance wave needs it.

### Next
On P1-PROD-3 (C4) EOS PASS + commit → **C5 (Academic Registers & Certificates)** then **C6/C7/C8…** per the C-table (`FINAL_QA_ROADMAP.md` §Phase C), skipping deferred waves (**C3** waits on GA-1 live). Once the identity batch above is resolved → **P1-CODE-4**. Owner-scope tasks P1-CODE-6/7/8 (Finance-posting / Hostel / Alumni) remain 👤 — surface when reached.

> **Deferred live-lane tail (run in the dedicated live phase):** `P0-INFRA-1` off-site backup · `P0-INFRA-3` alert delivery · `P0-TEST-1/2/3` CI + isolation-in-CI + live-regression cron.
> **Tracked pre-existing defect (NOT a wave regression):** `ISO-COUNT` — 5 "tenant isolation probe count" tests (communication/payment/pilot/sis) assert stale totals (220/213) vs the registry's actual 233 probes; fails at pre-wave commits too. Reconcile the counts + verify the +13 probes. Small, isolated.

### Regression required
- `deno test` + `deno check` green for touched `supabase/functions/**` · `flutter analyze` 0 · `flutter test` no NEW failures (beyond the 2 known UX-7).

### Exit criteria (all true → wave complete)
- [ ] Fast marks entry persists real marks (grid/bulk capture, validated; honours the AB/ML/DB status design).
- [ ] Tabulation computes totals/avg/rank/grade from real marks (absent/ML/debarred excluded per [[exam-result-status-design]]); tabulation sheet exports via the shared pipeline.
- [ ] `/eos` FEATURE PASS; journal row + roadmap C4 ✅ + ledger EXM-1/2/3; advance this file to C5 + refresh the dashboard.

> **Rule:** never begin the next wave with an open P0 or an EOS BLOCKED. Owner-decision (👤) tasks surface in a batch and do not pause the pipeline; live-lane (⏳) tasks defer until provisioned; non-blocked tasks proceed.
