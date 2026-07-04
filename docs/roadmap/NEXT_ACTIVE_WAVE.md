# Akshara ERP — NEXT ACTIVE WAVE

**This is the ONLY file Opus 4.8 reads before each autonomous wave** — together with its state companion [`../execution/EXECUTION_DASHBOARD.md`](../execution/EXECUTION_DASHBOARD.md). Keep it small — current work only.
**Updated by:** the executor at each wave boundary (on EOS PASS + commit → advance to the next wave; refresh the dashboard at the same moment).
**Authority:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) · run per [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) · journal to [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md).

> **Previous waves:** **P1-CODE-1 (REL-1..5) ✅** · **P1-CODE-2 (REL-6..9) ✅** · **P1-CODE-3 (backend hardening) ✅** · **P1-CODE-5 — HR payroll engine ✅** · **P1-PROD-0 — XCT foundations ✅ COMPLETE (2026-07-04, `83bc267`)** — EOS FOUNDATION PASS. **XCT-1** shared PDF-table primitive `buildGridTable` (3 bespoke tabular-PDF builders consolidated onto the ONE pipeline that ~15 modules already ride). **XCT-2** reminder rail `_shared/reminders/reminders_service.ts` (`scheduleReminder` + `runDueReminders = runDueScheduledBroadcasts` — one runner; a due reminder fires end-to-end into a pending in-app delivery, proven by test). **XCT-3** shared read-only `AksharaDateField` → `showDatePicker` (HR leave create+on-behalf ×4 + probation + intelligence meeting-date). · **P1-PROD-1 — C1 Finance Fee-Recovery CRM ✅ COMPLETE (2026-07-04, `c1b9feb`)** — EOS FEATURE PASS. Discovery-first: FIN-R1/R3/R5 verified existing (not rebuilt). Built **FIN-R2 telecaller call queue** (server-ranked "who to call next" riding the same open/overdue accounts the defaulters list uses — no duplicate source; broken→due→never-contacted→stale ranking; `GET /finance/recovery/call-queue`; client `_CallQueueSection` reusing the existing dialogs; log/PTP re-ranks live) + fixed **FIN-R4** (history sheet → live provider). · **P1-PROD-2 — C2 Finance Counter/Statements/Reports ✅ COMPLETE (2026-07-04, `fa30e00`)** — EOS FEATURE PASS. Discovery-first: FIN-1/2/7/8 verified existing (real exports on the XCT-1 shared pipeline). Closed **FIN-6**: `issueInvoice` drops the hardcoded +30 (uses `due_days` + generates the schedule); new shared `finance_aging.overdueDaysSql` makes **installment due dates drive aging** across defaulters / recovery call-queue / finance-intelligence / student-risk (behaviour-preserving for the default single-term config). Backend-only · analyze 0 · deno finance 147/0 · intelligence 51/0. · **P1-PROD-3 — C4 Exams Fast Marks & Tabulation ✅ VERIFIED COMPLETE (2026-07-04, no code)** — discovery-first found EXM-1/2/3 already built + tested (bulk marks save + keyboard nav + validation + AB/ML/DB; tabulation totals/%/rank/grade with present-only exclusion; register CSV/PDF via shared service). Per EOS rule #4 no rebuild. deno exam 118/0 · flutter exam client 109/0.

---

## ▶ CURRENT

- **Phase:** **P1 — Backend & Code Fixes** 🟠
- **Wave:** **P1-PROD-4 — C5 · Academic Registers & Certificates (ATT-1, ATT-2, SIS-1)** — 🔵 next up. (**C3** still defers on GA-1 live; **C4** ✅ verified-complete.)
- **Sequencing:** C5 depends only on **C0 (P1-PROD-0 ✅, XCT-1 export pipeline)**. **P2-UX-1 ∥-eligible** under disjoint ownership. **P1-CODE-4 (Identity) stays owner-gated (👤 batch below) — surfaced, NOT blocking.** Live lane (`P0-INFRA-1/3`, `P0-TEST-1/2/3`) stays owner-deferred.

### P1-PROD-4 tasks (this wave) — findings ATT-1/ATT-2/SIS-1
> ⚠ **Discovery-first (C1/C2/C4 all proved this — mostly verify-not-rebuild):** **SIS-1 certificates were already built in the identity cluster** (POST `/sis/students/{id}/certificates` immutable issuance + client cert PDF UI — see [[student-identity-architecture-decision]]) — VERIFY, don't rebuild. Assess ATT-1/ATT-2 coverage before writing (an office-attendance screen + monthly register may partially exist). Exports ride the **XCT-1 shared pipeline**.

| Sub | Sev | What |
|---|---|---|
| **ATT-1** | P1 | Office attendance register (AC-06): filter, named present/absent/late, read + export. |
| **ATT-2** | P1 | Monthly class attendance register export (students × days grid). |
| **SIS-1** | P1 | Bonafide / Study / Conduct certificate generation (print-ready PDF, English) — **likely already built (identity cluster); verify**. |

### EOS gate
- Scope: **FEATURE (Academics/SIS)**. PASS required. **Completion (roadmap `FINAL_QA_ROADMAP.md:555`):** register renders + exports; certificates generate as print-ready PDFs. Regression: `flutter analyze` 0 · `flutter test` no NEW failures (2 known UX-7) · `deno test`+`deno check` green for any touched `supabase/functions/**`.

### 👤 SURFACED OWNER DECISIONS — identity cluster (gates P1-CODE-4, resolve in a batch)
See [[akshara-decision-queue]] + [[student-identity-architecture-decision]]. These do **not** pause the pipeline; they gate **P1-CODE-4 (Identity finish)** only:
- **PLAT-0** — build Public Student ID (PSID) now vs defer post-pilot.
- **C5 / ADM-D3** — admission-number immutability (set-once-locked vs editable).
- **IC-1…IC-6** — esp. `users.phone` NOT NULL UNIQUE = de-facto identity; is a **change-phone flow (PLAT-4)** in scope for P1-CODE-4, or deferred?
- **SIS-D1** — TC / no-dues gate on identity transitions.
- **Admissions approval SoD** — maker-checker on admission approval.
- **MOD-1 (👤)** — Finance-posting scope also gates the unified recovery-CRM scope (C1 did not reach that edge — call queue rode the existing defaulter source); surface if a later finance wave needs it.

### Next
On P1-PROD-4 (C5) EOS PASS + commit → **C6 (Homework core — ⚠ HWK-1 = contract/schema change, owner + migration) / C7 (HR Payroll & Salary Registers) / C8 (Transport)…** per the C-table (`FINAL_QA_ROADMAP.md` §Phase C), skipping deferred waves (**C3** waits on GA-1 live). Once the identity batch above is resolved → **P1-CODE-4**. Owner-scope tasks P1-CODE-6/7/8 (Finance-posting / Hostel / Alumni) remain 👤 — surface when reached.

> **Deferred live-lane tail (run in the dedicated live phase):** `P0-INFRA-1` off-site backup · `P0-INFRA-3` alert delivery · `P0-TEST-1/2/3` CI + isolation-in-CI + live-regression cron.
> **Tracked pre-existing defect (NOT a wave regression):** `ISO-COUNT` — 5 "tenant isolation probe count" tests (communication/payment/pilot/sis) assert stale totals (220/213) vs the registry's actual 233 probes; fails at pre-wave commits too. Reconcile the counts + verify the +13 probes. Small, isolated.

### Regression required
- `deno test` + `deno check` green for touched `supabase/functions/**` · `flutter analyze` 0 · `flutter test` no NEW failures (beyond the 2 known UX-7).

### Exit criteria (all true → wave complete)
- [ ] Office attendance register (ATT-1) + monthly class register (ATT-2) render and export via the shared pipeline (verify existing office-attendance surfaces; close gaps).
- [ ] SIS-1 Bonafide/Study/Conduct certificates generate as print-ready PDFs (verify the identity-cluster build; close any gap).
- [ ] `/eos` FEATURE PASS; journal row + roadmap C5 ✅ + ledger ATT-1/ATT-2/SIS-1; advance this file to the next unblocked C-wave + refresh the dashboard.

> **Rule:** never begin the next wave with an open P0 or an EOS BLOCKED. Owner-decision (👤) tasks surface in a batch and do not pause the pipeline; live-lane (⏳) tasks defer until provisioned; non-blocked tasks proceed.
