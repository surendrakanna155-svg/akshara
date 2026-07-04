# Akshara ERP — NEXT ACTIVE WAVE

**This is the ONLY file Opus 4.8 reads before each autonomous wave** — together with its state companion [`../execution/EXECUTION_DASHBOARD.md`](../execution/EXECUTION_DASHBOARD.md). Keep it small — current work only.
**Updated by:** the executor at each wave boundary (on EOS PASS + commit → advance to the next wave; refresh the dashboard at the same moment).
**Authority:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) · run per [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) · journal to [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md).

> **Previous waves:** **P1-CODE-1 (REL-1..5) ✅** · **P1-CODE-2 (REL-6..9) ✅** · **P1-CODE-3 (backend hardening) ✅** · **P1-CODE-5 — HR payroll engine ✅** · **P1-PROD-0 — XCT foundations ✅ COMPLETE (2026-07-04, `83bc267`)** — EOS FOUNDATION PASS. **XCT-1** shared PDF-table primitive `buildGridTable` (3 bespoke tabular-PDF builders consolidated onto the ONE pipeline that ~15 modules already ride). **XCT-2** reminder rail `_shared/reminders/reminders_service.ts` (`scheduleReminder` + `runDueReminders = runDueScheduledBroadcasts` — one runner; a due reminder fires end-to-end into a pending in-app delivery, proven by test). **XCT-3** shared read-only `AksharaDateField` → `showDatePicker` (HR leave create+on-behalf ×4 + probation + intelligence meeting-date). · **P1-PROD-1 — C1 Finance Fee-Recovery CRM ✅ COMPLETE (2026-07-04, `c1b9feb`)** — EOS FEATURE PASS. Discovery-first: FIN-R1/R3/R5 verified existing (not rebuilt). Built **FIN-R2 telecaller call queue** (server-ranked "who to call next" riding the same open/overdue accounts the defaulters list uses — no duplicate source; broken→due→never-contacted→stale ranking; `GET /finance/recovery/call-queue`; client `_CallQueueSection` reusing the existing dialogs; log/PTP re-ranks live) + fixed **FIN-R4** (history sheet → live provider). · **P1-PROD-2 — C2 Finance Counter/Statements/Reports ✅ COMPLETE (2026-07-04, `fa30e00`)** — EOS FEATURE PASS. Discovery-first: FIN-1/2/7/8 verified existing (real exports on the XCT-1 shared pipeline). Closed **FIN-6**: `issueInvoice` drops the hardcoded +30 (uses `due_days` + generates the schedule); new shared `finance_aging.overdueDaysSql` makes **installment due dates drive aging** across defaulters / recovery call-queue / finance-intelligence / student-risk (behaviour-preserving for the default single-term config). Backend-only · analyze 0 · deno finance 147/0 · intelligence 51/0. · **P1-PROD-3 — C4 Exams Fast Marks & Tabulation ✅ VERIFIED COMPLETE (2026-07-04, no code)** — discovery-first found EXM-1/2/3 already built + tested (bulk marks save + keyboard nav + validation + AB/ML/DB; tabulation totals/%/rank/grade with present-only exclusion; register CSV/PDF via shared service). Per EOS rule #4 no rebuild. deno exam 118/0 · flutter exam client 109/0. · **P1-PROD-4 — C5 Academic Registers & Certificates ✅ COMPLETE (2026-07-04, `1fc6104`)** — discovery-first found ATT-1 (office register) / ATT-2 (monthly students×days grid) / SIS-1 (certs) all built (real SQL + shared export + immutable cert register). Closed one gap: ATT-2 cell-level render test. attendance+sis 73/0. · **P1-PROD-5 — C7 HR Payroll & Salary Registers ✅ COMPLETE (2026-07-04, `524105e`)** — discovery-first found HR-1 register + HR-2 batch payslips already built; closed HR-2's individual per-employee payslip PDF (`buildPayslipPdf` + picker sheet). Client-only, read-only. analyze 0 · suite 3616 pass (0 new). · **P1-PROD-6 — C8 Transport Fleet, Roster & Fee ✅ VERIFIED COMPLETE (2026-07-04, no code)** — discovery-first found TRN-1/2/3/4/9 all built; **money boundary CONFIRMED intact + test-enforced** (zero payment code in Transport; get-or-create per-year account; Finance = sole payment engine). One candidate gap (TRN-9 app-level dedupe race) money-contained + unsafe to hot-patch → tracked `TRN9-DEDUPE`. deno transport 36/0 · finance-assignments 12/0 · flutter transport 42/0. · **P1-PROD-7 — C9 Inventory·Library·Communication ✅ COMPLETE (2026-07-04, `2ecee77`)** — discovery-first found all six (INV-1/2·LIB-1/2·COM-1/2) built (inventory governance intact: FOR UPDATE lock, negative-block 422+DB CHECK, immutable ledger, maker-checker SoD 409; memory was stale). Closed one gap: LIB-2 bulk-import test via a behavior-preserving `planImportRow` extraction. deno inv+lib 76/0 · comm 27/0.

---

## ▶ CURRENT

- **Phase:** **P1 — Backend & Code Fixes** 🟠
- **Wave:** **P1-PROD-8 — C10 · Principal Approval Center batch actions (PRI-1)** — 🔵 next up. (**C3** defers on GA-1 live; **C6** defers — HWK-1 owner schema change; **C4/C5/C7/C8/C9** ✅ complete.)
- **Sequencing:** C10 depends on **none** (principal-facing; may co-run with C3). Note: a batch approve/reject notifier already exists in other modules (HR batch-decide, approval_batch_decide) — verify the Approval Center reuses/needs it. **P2-UX-1 ∥-eligible.** **P1-CODE-4 (Identity) stays owner-gated.** Live lane stays owner-deferred.

### P1-PROD-8 tasks (this wave) — finding PRI-1
> ⚠ **Discovery-first (every C-wave so far was mostly verify-not-rebuild):** an Approval Center + a shared `approval` batch-decide backend (`approval_batch_decide`) likely exist. Assess coverage before writing; close only verified gaps. Each decision must persist + **audit** (SoD/maker-checker where applicable).

| Sub | Sev | What |
|---|---|---|
| **PRI-1** | P1 | Batch approve/reject (multi-select) in the Approval Center — clear 5–15 daily approvals in bulk. |

### EOS gate
- Scope: **FEATURE (Principal/Approvals)**. PASS required. **Completion (roadmap `FINAL_QA_ROADMAP.md:560`):** multi-select approve/reject persists + **audits each decision**. **Governance tripwire:** approvals that gate money/value (fee concession, stock write-off) keep their maker-checker SoD — batch action must not bypass it. Regression: `flutter analyze` 0 · `flutter test` no NEW failures (2 known UX-7) · `deno test`+`deno check` green for any touched `supabase/functions/**`.

### 👤 SURFACED OWNER DECISIONS — identity cluster (gates P1-CODE-4, resolve in a batch)
See [[akshara-decision-queue]] + [[student-identity-architecture-decision]]. These do **not** pause the pipeline; they gate **P1-CODE-4 (Identity finish)** only:
- **PLAT-0** — build Public Student ID (PSID) now vs defer post-pilot.
- **C5 / ADM-D3** — admission-number immutability (set-once-locked vs editable).
- **IC-1…IC-6** — esp. `users.phone` NOT NULL UNIQUE = de-facto identity; is a **change-phone flow (PLAT-4)** in scope for P1-CODE-4, or deferred?
- **SIS-D1** — TC / no-dues gate on identity transitions.
- **Admissions approval SoD** — maker-checker on admission approval.
- **MOD-1 (👤)** — Finance-posting scope also gates the unified recovery-CRM scope (C1 did not reach that edge — call queue rode the existing defaulter source); surface if a later finance wave needs it.
- **HWK-1 / C6 (👤 NEW)** — Homework due-date is a **contract/schema change**: free-text `due_label` → real `due_date DATE` (keystone for reminders/overdue/sorting). Needs an **owner-approved migration** before C6 can build. Surfaced; C6 deferred until approved.

### Next
On P1-PROD-8 (C10) EOS PASS + commit → **C11 (Admissions productivity) / C12 (Finance productivity — deps C1+C2, both done) / C13 (Academic-work productivity)…** per the C-table (`FINAL_QA_ROADMAP.md` §Phase C), skipping deferred waves (**C3** GA-1 live, **C6** HWK-1 owner migration). Once the identity batch above is resolved → **P1-CODE-4**. Owner-scope tasks P1-CODE-6/7/8 remain 👤.

> **Deferred live-lane tail (run in the dedicated live phase):** `P0-INFRA-1` off-site backup · `P0-INFRA-3` alert delivery · `P0-TEST-1/2/3` CI + isolation-in-CI + live-regression cron.
> **Tracked pre-existing defect (NOT a wave regression):** `ISO-COUNT` — 5 "tenant isolation probe count" tests (communication/payment/pilot/sis) assert stale totals (220/213) vs the registry's actual 233 probes; fails at pre-wave commits too. Reconcile the counts + verify the +13 probes. Small, isolated.

### Regression required
- `deno test` + `deno check` green for touched `supabase/functions/**` · `flutter analyze` 0 · `flutter test` no NEW failures (beyond the 2 known UX-7).

### Exit criteria (all true → wave complete)
- [ ] Multi-select batch approve/reject in the Approval Center persists + audits each decision (verify existing batch-decide; close gaps).
- [ ] Batch action respects maker-checker SoD where a decision gates money/value (no bypass).
- [ ] `/eos` FEATURE PASS; journal row + roadmap C10 ✅ + ledger PRI-1; advance this file to the next unblocked C-wave + refresh the dashboard.

> **Rule:** never begin the next wave with an open P0 or an EOS BLOCKED. Owner-decision (👤) tasks surface in a batch and do not pause the pipeline; live-lane (⏳) tasks defer until provisioned; non-blocked tasks proceed.
