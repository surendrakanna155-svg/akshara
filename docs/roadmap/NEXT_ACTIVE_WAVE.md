# Akshara ERP — NEXT ACTIVE WAVE

**This is the ONLY file Opus 4.8 reads before each autonomous wave** — together with its state companion [`../execution/EXECUTION_DASHBOARD.md`](../execution/EXECUTION_DASHBOARD.md). Keep it small — current work only.
**Updated by:** the executor at each wave boundary (on EOS PASS + commit → advance to the next wave; refresh the dashboard at the same moment).
**Authority:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) · run per [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) · journal to [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md).

> **Previous waves:** **P1-CODE-1 (REL-1..5) ✅** · **P1-CODE-2 (REL-6..9) ✅** · **P1-CODE-3 (backend hardening) ✅** · **P1-CODE-5 — HR payroll engine ✅** · **P1-PROD-0 — XCT foundations ✅ COMPLETE (2026-07-04, `83bc267`)** — EOS FOUNDATION PASS. **XCT-1** shared PDF-table primitive `buildGridTable` (3 bespoke tabular-PDF builders consolidated onto the ONE pipeline that ~15 modules already ride). **XCT-2** reminder rail `_shared/reminders/reminders_service.ts` (`scheduleReminder` + `runDueReminders = runDueScheduledBroadcasts` — one runner; a due reminder fires end-to-end into a pending in-app delivery, proven by test). **XCT-3** shared read-only `AksharaDateField` → `showDatePicker` (HR leave create+on-behalf ×4 + probation + intelligence meeting-date). · **P1-PROD-1 — C1 Finance Fee-Recovery CRM ✅ COMPLETE (2026-07-04, `c1b9feb`)** — EOS FEATURE PASS. Discovery-first: FIN-R1/R3/R5 verified existing (not rebuilt). Built **FIN-R2 telecaller call queue** (server-ranked "who to call next" riding the same open/overdue accounts the defaulters list uses — no duplicate source; broken→due→never-contacted→stale ranking; `GET /finance/recovery/call-queue`; client `_CallQueueSection` reusing the existing dialogs; log/PTP re-ranks live) + fixed **FIN-R4** (history sheet → live provider). · **P1-PROD-2 — C2 Finance Counter/Statements/Reports ✅ COMPLETE (2026-07-04, `fa30e00`)** — EOS FEATURE PASS. Discovery-first: FIN-1/2/7/8 verified existing (real exports on the XCT-1 shared pipeline). Closed **FIN-6**: `issueInvoice` drops the hardcoded +30 (uses `due_days` + generates the schedule); new shared `finance_aging.overdueDaysSql` makes **installment due dates drive aging** across defaulters / recovery call-queue / finance-intelligence / student-risk (behaviour-preserving for the default single-term config). Backend-only · analyze 0 · deno finance 147/0 · intelligence 51/0. · **P1-PROD-3 — C4 Exams Fast Marks & Tabulation ✅ VERIFIED COMPLETE (2026-07-04, no code)** — discovery-first found EXM-1/2/3 already built + tested (bulk marks save + keyboard nav + validation + AB/ML/DB; tabulation totals/%/rank/grade with present-only exclusion; register CSV/PDF via shared service). Per EOS rule #4 no rebuild. deno exam 118/0 · flutter exam client 109/0. · **P1-PROD-4 — C5 Academic Registers & Certificates ✅ COMPLETE (2026-07-04, `1fc6104`)** — discovery-first found ATT-1 (office register) / ATT-2 (monthly students×days grid) / SIS-1 (certs) all built (real SQL + shared export + immutable cert register). Closed one gap: ATT-2 cell-level render test. attendance+sis 73/0. · **P1-PROD-5 — C7 HR Payroll & Salary Registers ✅ COMPLETE (2026-07-04, `524105e`)** — discovery-first found HR-1 register + HR-2 batch payslips already built; closed HR-2's individual per-employee payslip PDF (`buildPayslipPdf` + picker sheet). Client-only, read-only. analyze 0 · suite 3616 pass (0 new). · **P1-PROD-6 — C8 Transport Fleet, Roster & Fee ✅ VERIFIED COMPLETE (2026-07-04, no code)** — discovery-first found TRN-1/2/3/4/9 all built; **money boundary CONFIRMED intact + test-enforced** (zero payment code in Transport; get-or-create per-year account; Finance = sole payment engine). One candidate gap (TRN-9 app-level dedupe race) money-contained + unsafe to hot-patch → tracked `TRN9-DEDUPE`. deno transport 36/0 · finance-assignments 12/0 · flutter transport 42/0. · **P1-PROD-7 — C9 Inventory·Library·Communication ✅ COMPLETE (2026-07-04, `2ecee77`)** — discovery-first found all six (INV-1/2·LIB-1/2·COM-1/2) built (inventory governance intact: FOR UPDATE lock, negative-block 422+DB CHECK, immutable ledger, maker-checker SoD 409; memory was stale). Closed one gap: LIB-2 bulk-import test via a behavior-preserving `planImportRow` extraction. deno inv+lib 76/0 · comm 27/0. · **P1-PROD-8 — C10 Principal Approval Center batch ✅ COMPLETE (2026-07-04, `7c9294b`)** — PRI-1 batch approve/reject already built; **closed a money-SoD gap**: `decideApproval` self-approve guard was inventoryPo-only → extended to `{inventoryPo, feeConcession, refund, feeStructure}` so a requester can't approve their OWN money waiver (single+batch; FIN-D4). deno approval 59/0. · **P1-PROD-9 — C11 Admissions productivity ✅ COMPLETE (2026-07-04, `10f8461`)** — ADM-2/3/4/5 verified built + tested (auto-log, bulk actions, follow-ups inline, real lead picker; admission-approval SoD-gated). Closed ADM-1 PDF export gap (`shareGridPdf` wired; CSV+PDF). analyze 0 · suite 3618 pass (0 new) · admissions 110/0.

---

## ▶ CURRENT

- **Phase:** **P1 — Backend & Code Fixes** 🟠
- **Wave:** **P1-PROD-10 — C12 · Finance productivity & receipting (FIN-3, FIN-4, FIN-5, FIN-9, FIN-R6, FIN-R7)** — 🔵 next up. (**C3** defers on GA-1 live; **C6** defers — HWK-1 owner schema change; **C4/C5/C7/C8/C9/C10/C11** ✅ complete.)
- **Sequencing:** C12 depends on **C1 + C2 (both done)**. ⚠ **FIN-R6 (collection targets) NEEDS FIN-D6** — surface as an owner decision (👤) if reached; the rest (FIN-3/4/5/9, FIN-R7) proceed. Money-adjacent: FIN-4 duplicate-reprint must stamp DUPLICATE + audit (no new money); FIN-R7 cheque/DD/PDC + bounce tracking touches payment instruments — Finance stays the payment engine, no duplicate money math. **P2-UX-1 ∥-eligible.** **P1-CODE-4 (Identity) stays owner-gated.** Live lane stays owner-deferred.

### P1-PROD-10 tasks (this wave) — findings FIN-3/4/5/9, FIN-R6, FIN-R7
> ⚠ **Discovery-first (every C-wave so far was mostly verify-not-rebuild):** a Finance receipt/PDF + analytics backend exists (FinanceReceiptPdfService, receipts, reports). Assess coverage before writing; close only verified gaps. Receipts/exports ride the **XCT-1 shared pipeline**.

| Sub | Sev | What |
|---|---|---|
| **FIN-3** | P1 | Indian-format receipt polish (logo/letterhead/amount-in-words/ORIGINAL-COPY; English preserved). |
| **FIN-4** | P1 | Duplicate-receipt reprint (+DUPLICATE stamp + audit). |
| **FIN-5** | P1 | Batch receipt printing. |
| **FIN-9** | P1 | Outstanding analytics. |
| **FIN-R6** | P1 | Collection targets *(⚠ needs FIN-D6 owner decision — surface if reached)*. |
| **FIN-R7** | P1 | Cheque/DD/PDC + bounce tracking. |

### EOS gate
- Scope: **FEATURE (Finance)**. PASS required. **Completion (roadmap `FINAL_QA_ROADMAP.md:565`):** receipts render Indian-format with amount-in-words; duplicate reprint is stamped + audited; batch printing works; outstanding analytics compute from real data; cheque/PDC lifecycle + bounce tracked. **Money-safety tripwire:** no new payment/collection path (Finance = sole engine); reprints/analytics are read-only; FIN-R7 records instrument status, does not double-count money. Regression: `flutter analyze` 0 · `flutter test` no NEW failures (2 known UX-7) · `deno test`+`deno check` green for any touched `supabase/functions/**`.

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
On P1-PROD-10 (C12) EOS PASS + commit → **C13 (Academic-work productivity — deps C4 done + C6 defers) / C14 (Teacher & Attendance productivity) / C15 (HR & SIS productivity)…** per the C-table (`FINAL_QA_ROADMAP.md` §Phase C), skipping deferred waves (**C3** GA-1 live, **C6** HWK-1 owner migration). Once the identity batch above is resolved → **P1-CODE-4**. Owner-scope tasks P1-CODE-6/7/8 remain 👤.

> **Deferred live-lane tail (run in the dedicated live phase):** `P0-INFRA-1` off-site backup · `P0-INFRA-3` alert delivery · `P0-TEST-1/2/3` CI + isolation-in-CI + live-regression cron.
> **Tracked pre-existing defect (NOT a wave regression):** `ISO-COUNT` — 5 "tenant isolation probe count" tests (communication/payment/pilot/sis) assert stale totals (220/213) vs the registry's actual 233 probes; fails at pre-wave commits too. Reconcile the counts + verify the +13 probes. Small, isolated.

### Regression required
- `deno test` + `deno check` green for touched `supabase/functions/**` · `flutter analyze` 0 · `flutter test` no NEW failures (beyond the 2 known UX-7).

### Exit criteria (all true → wave complete)
- [ ] Receipt Indian-format polish (FIN-3); duplicate reprint stamped + audited (FIN-4); batch receipt print (FIN-5); outstanding analytics from real data (FIN-9); cheque/DD/PDC + bounce tracked (FIN-R7). Verify existing; close gaps. FIN-R6 surfaced if FIN-D6 unresolved.
- [ ] No new payment/collection path introduced (Finance = sole engine; money-safety intact).
- [ ] `/eos` FEATURE PASS; journal row + roadmap C12 ✅ + ledger FIN-3/4/5/9·R6/R7; advance this file to the next unblocked C-wave + refresh the dashboard.

> **Rule:** never begin the next wave with an open P0 or an EOS BLOCKED. Owner-decision (👤) tasks surface in a batch and do not pause the pipeline; live-lane (⏳) tasks defer until provisioned; non-blocked tasks proceed.
