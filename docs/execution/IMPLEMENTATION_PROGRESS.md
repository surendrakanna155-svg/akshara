# Akshara ERP — Implementation Progress (Permanent Execution Journal)

**Status:** 🟢 Permanent journal · **Started:** 2026-07-03 · **HEAD at start:** `68f15cb`
**Governs:** execution of [`../roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md`](../roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md) per [`../roadmap/AUTONOMOUS_EXECUTION_PLAN.md`](../roadmap/AUTONOMOUS_EXECUTION_PLAN.md).
**Rule:** append **one row per completed task/wave**, immediately after its EOS PASS + commit. Never rewrite history; only append.

> This is the single, permanent record of what was actually built. It is the ground truth for the
> roadmap's progress dashboard — the two must always agree (Autonomous Plan §9).

---

## 1. Journal schema (every completed task records)

| Field | Meaning |
|---|---|
| **Date** | ISO date of completion |
| **Commit** | short SHA (the commit made *after* EOS PASS) |
| **Phase** | P0…P8 |
| **Task ID** | roadmap task (e.g. `P0-CODE-1`) |
| **Files changed** | key paths / count |
| **EOS result** | PASS / CONDITIONAL PASS (P1s tracked) — never BLOCKED (BLOCKED never commits) |
| **Evidence** | test/gate/artifact proving the outcome (path or count) |
| **Audit finding** | the finding ID(s) closed (from `AUDIT_FINDINGS_LEDGER.md`) |
| **Roadmap item** | same as Task ID; links back to the roadmap row |

---

## 2. Progress summary

| Phase | Tasks total | ✅ Complete | 🔵 In progress | ⚪ Pending | EOS-gated |
|---|---:|---:|---:|---:|---|
| **Planning** | — | ✅ FROZEN 2026-07-04 | — | — | audit-verified |
| P0 — Truth/Docs/Live-Verify | 19 | 14 (DOC-1/2/3/4/5, SEC-1/2/3, INFRA-2/4/5/6, CODE-1/2) | 0 | 5 (⏳ live-lane: INFRA-1/3, TEST-1/2/3) | per task |
| P1 — Backend & Code Fixes | 13 (+22 PROD waves incl. P1-PROD-22 staff-attendance GA track) | 14 (CODE-1/2/3/5, PROD-0, C1, C2, C4✓, C5, C7, C8✓, C9, C10, C11) | 0 | 21 (next: C12 Finance productivity — C3+C6 defer; CODE-4 👤-gated) | per wave |
| P2 — UI/UX | 5 | 0 | 0 | 5 | per wave |
| P3 — Adaptive AI (W1.1–1.5 · W2.0–2.9) | 2 (15 sub-waves) | 0 | 0 | all | per sub-wave |
| P4 — Red Team Prep | 2 | 0 | 0 | 2 | verdict |
| P5 — Red Team Fixes | 1 (+findings) | 0 | 0 | 1 | per fix |
| P6 — Pilot Simulation | 1 | 0 | 0 | 1 | QA-R-001/002 |
| P7 — Production Cert | 1 | 0 | 0 | 1 | QA-R-012 |
| P8 — GA Readiness | 5 | 0 | 0 | 5 | RELEASE |

**Overall:** 🔵 **EXECUTING.** Planning frozen 2026-07-04; **Wave 1 (P0 · W1 — Documentation Truth) ✅ COMPLETE
(commit `c2b8e27`, EOS DOCS PASS).** The next autonomous wave is defined in
[`../roadmap/NEXT_ACTIVE_WAVE.md`](../roadmap/NEXT_ACTIVE_WAVE.md) (now **P0 · W2 — Safety Fixes**). Each wave:
implement → validate → `/eos` PASS → commit → append a journal row here.

---

## 3. Pre-execution baseline (verified during the Fable audit — NOT re-work; recorded so it isn't repeated)

> These were verified during the audit (see `docs/audits/`, `AUDIT_FINDINGS_LEDGER.md §A`). They are **not**
> roadmap tasks and must **not** be restarted. Listed here as the execution baseline.

| Date | Item | Result | Source |
|---|---|---|---|
| 2026-07-03 | `flutter analyze` | 0 issues | audit (live run) |
| 2026-07-03 | Cross-tenant RLS isolation (read+write, cross-tenant/cross-school/parent) | PASS (verified) | `docs/audits/11 §3b` (QA-2/LV-11) |
| 2026-07-03 | Edge connects as `erp_tenant` (NOBYPASSRLS) | Confirmed | `docs/audits/11 §2` (DB-2) |
| 2026-07-03 | Entitlement enforcement ON | Confirmed | `docs/audits/11 §2` (ENG-2/OPS-5) |
| 2026-07-03 | Automated encrypted backups + monthly restore drill | Running + passing | `docs/audits/11 §3` (LV-2/LV-8) |
| 2026-07-03 | Watchdog monitoring | Running | `docs/audits/11 §3` (LV-9) |
| 2026-07-03 | AI live via OpenRouter (key present) | Confirmed | `docs/audits/11 §2` (AI-4 part) |
| 2026-07-03 | Live tenant DB password | Rotated (≠ git default) | `docs/audits/11 §2` (DB-1 live) |

*(These do not require re-verification to start Phase 0. Where a task exists to make them permanent/regression-guarded — e.g. P0-TEST-2 isolation-in-CI, P0-INFRA-6 role assertion — it is tracked in the roadmap.)*

---

## 4. Execution log (append one row per completed task — newest at bottom)

> **Wave 0 = Planning (frozen 2026-07-04).** Recorded below as history; it is *not* an implementation wave.
> **Implementation history begins at Wave 1** (P0 · W1 — Documentation Truth, per `NEXT_ACTIVE_WAVE.md`).

| Date | Commit | Phase | Task ID | Files changed | EOS result | Evidence | Audit finding | Roadmap item |
|---|---|---|---|---|---|---|---|---|
| 2026-07-03 | (uncommitted) | Planning | P0-DOC-3 | docs/roadmap/*, docs/audits/*ROADMAP*, FINAL_QA_ROADMAP banner | n/a (planning) | ONE roadmap + ledger + pointers | DOC-3 | P0-DOC-3 |
| 2026-07-04 | (uncommitted) | Planning | FREEZE | docs/roadmap/* (finalized), docs/design/adaptive-ai/ folded into P3, NEXT_ACTIVE_WAVE + FINALIZATION report | n/a (planning) | ROADMAP_FINALIZATION_REPORT.md | — | planning freeze |
| 2026-07-04 | `c2b8e27` | P0 | **P0-DOC-1/2/4/5 (W1 — Documentation Truth)** | `docs/ProjectStatus.md` (rewrite), `docs/FINAL_QA_MASTER_TRACKER.md` (evidence-grade framing + over-claim re-scope), `docs/TechnicalDebt/TD-P0-01-RLS-Enforcement.md` (closed-with-residual), `docs/AuditArchitecture.md` (target-not-built banner), `docs/Operations/{Backup,Restore}-Runbook.md` (→ redirect stubs), `docs/README.md`, `.gitignore` (govern `.claude/skills|commands`; ignore golden-failure diffs + `flutter_*.log`), + ~600-file cleanup/governance tree committed · 766 files | **PASS** (EOS DOCS) | `flutter analyze` 0; docs-only (0 `lib/**`/`supabase/**`); tracker frozen (0 rows rewritten); cleanup = moves-to-archive (content preserved) | DOC-1, DOC-2, DOC-4/QA-1, DB-9/DOC-5, DB-6/DOC-6, DOC-7 | P0-DOC-1/2/4/5 |

| 2026-07-04 | `c80f18c` | P0 | **P0-SEC-1** (W2 — Safety Fixes) | `lib/core/config/environment.dart` (fail-closed `guardForRelease`), `android/app/build.gradle.kts` (no debug-signing + task-graph guard), `test/core/config/environment_test.dart` (+5) | **PASS** (EOS SEC) | `flutter analyze` 0; env tests 11/11 | SEC-1, SEC-2 | P0-SEC-1 |

| 2026-07-04 | `619338b` | P0 | **P0-SEC-2** (W2) | `lib/features/auth/auth_session_storage.dart` (secure backend + legacy migrate/scrub), `lib/features/auth/auth_provider.dart` (provider wiring), +4 test files | **PASS** (EOS SEC) | `flutter analyze` 0; full suite 3563 pass, 0 new failures (2 pre-existing UX-7) | SEC-3 | P0-SEC-2 |

| 2026-07-04 | `6408d90` | P0 | **P0-CODE-1** (W2) | `supabase/functions/_shared/finance/finance_collections_repository.ts` (row_version guard + CollectionConflictError), `finance_collections_handlers.ts` (409 + expectedVersion parse), `finance_mapper.ts` (collectionRowToApi), +4 test files (row_version literals + 3 ENG-1 tests) | **PASS** (EOS RELIABILITY) | deno finance 136/0; deno check clean; api typechecks | ENG-1 | P0-CODE-1 |

| 2026-07-04 | `63358bc` | P0 | **P0-SEC-3** (W2) | `lib/router/app_router.dart` (QA route behind `kReleaseMode`), `lib/core/auth/auth_repository_providers.dart` (mock fail-closed) | **PASS** (EOS SEC) | `flutter analyze` 0; full suite 3563 pass, 0 new failures; router/auth/security 157/0 | SEC-9, SEC-10 | P0-SEC-3 |

| 2026-07-04 | `bacc56a` | P0 | **P0-INFRA-4/5/6** (W2) | `supabase/functions/_shared/tenant_db.ts` (+`assertEdgeTenantRole`, bypassRls), `tenant_handlers.ts` (health 503 on wrong role), `tenant_db_test.ts` (+4), `supabase/migrations/20260610100000_*.sql` (credential→GUC), `scripts/production_launch_verify.sh` (role assertion) | **PASS** (EOS OPS+SEC) | tenant_db 7/0; health 14/0; api typechecks; bash -n clean | LV-10, DB-1/OPS-6, DB-2 | P0-INFRA-4/5/6 |

| 2026-07-04 | `3cbf45c` | P0 | **P0-CODE-2** (W2) | `lib/router/surface_backend_gate.dart` (new gate), `lib/router/route_guards.dart` (ErpRouteGuard wiring), management/sis/control-center sub-navs (ConsumerWidget + filter), `test/router/surface_backend_gate_test.dart` | **PASS** (EOS FEATURE) | gate 4/4; analyze 0; full suite 3567 pass, 0 new failures | ENG-3/MOD-4 | P0-CODE-2 |

| 2026-07-04 | `5908509` | P1 | **P1-CODE-1 · REL-1/REL-4** (Reliability finish, part 1) | Idempotency-Key Dio interceptor (all mutating verbs) + boot/app-resume `syncEngine.flush()` outbox flush | **PASS** (EOS RELIABILITY, wave-close `afd1106`) | universal idempotency (was ~4%); no dup on retry | REL-1, REL-4 | P1-CODE-1 |

| 2026-07-04 | `66f9f35` | P1 | **P1-CODE-1 · REL-2** (part 2) | marks "Save all" (`bulkUpdateMarks`) routed through `ReliableWriter` (was raw `_dio.post`) | **PASS** (EOS RELIABILITY, wave-close `afd1106`) | grid Save-all queues idempotent/resumable | REL-2 | P1-CODE-1 |

| 2026-07-04 | `afd1106` | P1 | **P1-CODE-1 · REL-3/REL-5** (part 3, wave-close) | `lib/features/academics/exam_admin/exam_marks_entry_screen.dart` (DraftAutosaveMixin on `_MarksEntryBodyState` + didUpdateWidget tighten), `lib/features/finance/finance_workflow_actions.dart` (extract `_RecordCollectionForm` + money-safe resume), exam store/requests/mapper/datasource/provider (`rowVersion`→`expectedVersion`), `lib/core/testing/qa_test_keys.dart`, +3 test files | **PASS** (EOS RELIABILITY) | analyze 0; full suite **3584 pass, 0 new failures** (2 known UX-7); +11 tests; backend untouched | REL-3, REL-5 | P1-CODE-1 |

| 2026-07-04 | `c0f450f` | P1 | **P1-CODE-2** (Reliability polish, REL-6..9) | `lib/core/reliability/store/{reliability_store,in_memory_reliability_store,sqflite_reliability_store,reliability_store_opener}.dart` (reclaim + open result), `sync/sync_engine.dart` (reclaim + ordering + reachability gate), `connectivity/*` (isReachable), `sync_center/{sync_summary,sync_center_controller,sync_banner}.dart` + `reliability_providers.dart` + `main.dart` (degraded telemetry), `lib/core/network/interceptors/offline_read_cache_interceptor.dart` (TTL), +3 test files + fakes | **PASS** (EOS RELIABILITY) | analyze 0; full suite **3599 pass, 0 new failures** (2 known UX-7); +15 tests; backend untouched | REL-6, REL-7, REL-8, REL-9 | P1-CODE-2 |

| 2026-07-04 | `370028c` | P1 | **P1-CODE-3 · ENG-7/ENG-8** (Backend hardening, part 1) | `api/app.ts` (central generic SERVER/CONFIG error), `_shared/http.ts` (`MAX_BULK_ITEMS`), exam/hr/approval/admissions/pilot/transport handlers (bulk caps), `api/qw4_error_paths_test.ts` + `api/eng8_bulk_cap_test.ts` | **PASS** (EOS SECURITY) | no raw internal error to client; 6 bulk arrays 422-before-DB; api 14/0; exam+hr+approval 132/0 | ENG-7(=SEC-6), ENG-8(=SEC-11) | P1-CODE-3 |

| 2026-07-04 | `56e4942` | P1 | **P1-CODE-3 · ENG-10** (part 2) | attendance/promotion/parent-experience/memories/school-config/inventory-intelligence/subscription-admin handlers (18 val 400→422), memories/school-config/inventory route-contract tests | **PASS** (EOS ARCH) | validation failures uniformly 422; affected module tests 116/0 | ENG-10 | P1-CODE-3 |

| 2026-07-04 | `3957fab` | P1 | **P1-CODE-3 · ENG-4/ENG-5** (part 3) | `api/eng4_5_forced_auth_test.ts` (forced-auth choke + route-registry lint) | **PASS** (EOS SECURITY) | unauth→401 across all module groups; 13/13; invariant continuously enforced | ENG-4, ENG-5 | P1-CODE-3 |

| 2026-07-04 | `b4bee40` | P1 | **P1-CODE-3 · ENG-9/DB-6** (part 4, wave-close) | `_shared/config.ts` (`auditRetentionDays`), `_shared/audit/audit_repository.ts` (retention seam), `api/eng9_error_code_taxonomy_test.ts`, `_shared/audit/db6_retention_seam_test.ts`, 7 mock-config builders | **PASS** (EOS ARCH) | error-code taxonomy lint 2/2; audit-retention seam 3/3; **full deno 2021 pass, 0 new failures** (5 pre-existing probe-count drifts → ISO-COUNT); analyze 0 | ENG-9, DB-6 | P1-CODE-3 |

| 2026-07-04 | `56939bb` | P1 | **P1-CODE-5 · MOD-2/MOD-3 (backend)** (HR payroll engine, part 1) | `supabase/functions/_shared/hr/hr_write_handlers.ts` (`parseSalaryStructure`/`upsertSalaryStructure`/`generatePayrollRun` pure transforms + `handleUpsertSalaryStructure`/`handleGeneratePayrollRun`; `employeeCodeExists` → 409 `EMPLOYEE_CODE_TAKEN` on create), `hr_router.ts` (POST `/hr/payroll/structures` + `/hr/payroll/run/generate`), `mod2_3_payroll_engine_test.ts` (11), `qw4_hr_route_contract_test.ts` (manageHr gate on both new writes) | **PASS** (EOS FEATURE, wave-close `770ed00`) | deno HR 85/0; deno check clean; netPay = basic+allow−deduct server-side; 422 `PAYROLL_NO_STRUCTURES`/`SALARY_STRUCTURE_INVALID`; 409 regen-processed; idempotent draft regen | MOD-2, MOD-3 | P1-CODE-5 |

| 2026-07-04 | `770ed00` | P1 | **P1-CODE-5 · MOD-2/MOD-3 (client, wave-close)** | `lib/features/hr/payroll/hr_payroll_screen.dart` (`_PayrollManageActions` structure/generate/process bar + empty-state bootstrap), `hr_workflow_actions.dart` (salary-structure + generate-run dialogs; leave dialog → real employee picker, hardcoded `HR-EMP-102` removed), `hr_mutations_provider.dart` (+2 notifiers), `hr_requests.dart`/`hr_models.dart` (+`HrSalaryStructure`), API repo lane (paths/DTOs/datasource/mapper), hybrid fallback, mock engine parity (+ write store), `qa_test_keys.dart`, `test/features/hr/mod2_3_payroll_engine_client_widget_test.dart` (+6) | **PASS** (EOS FEATURE) | analyze 0; full suite **3605 pass, 0 new failures** (2 known UX-7); fresh-school structure→generate→process flow test green; payroll un-hidden behind `module.hr_payroll` 402 (`app.ts:105`) | MOD-2, MOD-3 | P1-CODE-5 |

| 2026-07-04 | `83bc267` | P1 | **P1-PROD-0 · XCT foundations (C0)** — export pipeline · reminder rail · date pickers | **XCT-1:** `lib/core/reports/akshara_report_export_service.dart` (new shared `buildGridTable` primitive; `buildGridReportPdf` delegates), `management/reports/management_dashboard_pdf_service.dart` (2 tables), `operations/operations_hub_pdf_service.dart` (4), `core/reports/finance_audit_register_service.dart` (register table), `test/core/reports/xct1_shared_grid_table_test.dart` (+3). **XCT-2:** `supabase/functions/_shared/reminders/reminders_service.ts` (`scheduleReminder` + `runDueReminders = runDueScheduledBroadcasts`), `reminders_service_test.ts` (+5). **XCT-3:** `lib/shared/forms/akshara_date_field.dart` (new `AksharaDateField`), `hr/hr_workflow_actions.dart` (leave create+on-behalf from/to ×4 + probation), `intelligence/teacher_effectiveness/teacher_effectiveness_screen.dart` (meeting-date), `test/shared/forms/akshara_date_field_test.dart` (+3), 2 HR flow tests updated to drive the picker | **PASS** (EOS FOUNDATION) | analyze 0; full suite **3611 pass, 0 new failures** (2 known UX-7); deno touched (communication+reminders) **108 pass / 1 known ISO-COUNT** (untouched); ≥3 exports on ONE pipeline ✓, reminder fires end-to-end (test) ✓, date pickers on named offenders ✓ | XCT-1, XCT-2, XCT-3 | P1-PROD-0 |

| 2026-07-04 | `c1b9feb` | P1 | **P1-PROD-1 · C1 — Finance fee-recovery CRM (FIN-R1..R5)** | Discovery-first (FIN-R1/R3/R5 verified existing, not rebuilt). **FIN-R2 call queue (new):** `finance_recovery_repository.ts` (`listCallQueue`), `finance_recovery_handlers.ts` (pure `callQueuePriority`/`callQueueReason` + `handleFinanceCallQueue`), `finance_router.ts` (GET `/finance/recovery/call-queue`), `qw4_finance_route_contract_test.ts` (+1 route), `finance_recovery_test.ts` (+7); client `finance_models.dart` (`CallQueueEntry`), interface/api/remote/hybrid/mock repo lane, `finance_recovery_dto.dart`+mapper, `finance_recovery_provider.dart` (call-queue providers + invalidation), `finance_defaulters_screen.dart` (`_CallQueueSection`/`_CallQueueTile`), `qa_test_keys.dart`, `test/features/finance/fin_r2_call_queue_widget_test.dart` (+2). **FIN-R4 fix:** history sheet → live `financeStudentContactsFutureProvider`. | **PASS** (EOS FEATURE) | analyze 0; full suite **3613 pass, 0 new fails** (2 known UX-7); deno finance **143/0**; api typecheck clean; round-trip (queue→log→re-rank) test green; recovery CRM additive (no money-path touch) | FIN-R1, FIN-R2, FIN-R3, FIN-R4, FIN-R5 | P1-PROD-1 |

| 2026-07-04 | `fa30e00` | P1 | **P1-PROD-2 · C2 — Finance Counter, Statements & Reports (FIN-1/2/6/7/8)** | Discovery-first (FIN-1/2/7/8 verified existing — real exports on the XCT-1 shared pipeline, not rebuilt). **FIN-6 (real gap):** new `finance_aging.ts` (`overdueDaysSql` — days-overdue from earliest installment term due date, COALESCE→invoice.due_date), applied in `finance_defaulters_handlers.ts`, `finance_recovery_repository.ts` (listCallQueue), `finance_intelligence_service.ts`, `intelligence/student_risk_repository.ts`; `finance_invoices_repository.ts` issueInvoice drops hardcoded `+30` → `due_days` setting + generates schedule; `finance_aging_test.ts` (+4). | **PASS** (EOS FEATURE) | backend-only (no lib/** → flutter unaffected, 3613 pass/2 known UX-7); analyze 0; deno finance **147/0**, intelligence **51/0**; api typecheck clean; behaviour-preserving for default single-term config; aging informational (no money movement) | FIN-1, FIN-2, FIN-6, FIN-7, FIN-8 | P1-PROD-2 |

| 2026-07-04 | (no code) | P1 | **P1-PROD-3 · C4 — Exams Fast Marks & Tabulation (EXM-1/2/3) — VERIFICATION** | Discovery-first found C4 already built end-to-end + tested (fast bulk marks save + keyboard nav + validation + AB/ML/DB status; tabulation totals/%/rank/grade with present-only exclusion; tabulation register CSV/PDF via the shared service). Per EOS rule #4 + "don't invent features," NO rebuild made. | **PASS** (EOS FEATURE — covered by existing impl + tests) | deno exam-administration **118/0**; flutter exam client **109/0**; no files changed. Noted for P2-UX: EXM-1 grid affordance (not a C4 gap). | EXM-1, EXM-2, EXM-3 | P1-PROD-3 |

| 2026-07-04 | `1fc6104` | P1 | **P1-PROD-4 · C5 — Academic Registers & Certificates (ATT-1/ATT-2/SIS-1)** | Discovery-first: all three already built (ATT-1 office register + ATT-2 monthly students×days grid, both real SQL + shared CSV/PDF export; SIS-1 Bonafide/Study/Conduct immutable-register + print-ready PDFs from the identity cluster). Per EOS rule #4 no rebuild. One gap closed: **ATT-2 cell-level render test** (`office_attendance_screen_test.dart` — monthly matrix DataTable + code cells + % + export). Test-only. | **PASS** (EOS FEATURE — covered by existing + test gap closed) | flutter attendance+sis **73/0**; deno **151/0 + 1 known ISO-COUNT**; analyze 0; suite unaffected. C6 defers (HWK-1 owner schema change); C3 defers (GA-1 live). | ATT-1, ATT-2, SIS-1 | P1-PROD-4 |

| 2026-07-04 | `524105e` | P1 | **P1-PROD-5 · C7 — HR Payroll & Salary Registers (HR-1/HR-2)** | Discovery-first: HR-1 salary register export (rows + TOTAL, CSV+PDF) + HR-2 all-employees payslip batch already built (roadmap "stub snackbar" stale). Closed the one gap — **HR-2 individual per-employee payslip PDF**: `AksharaReportExportService.buildPayslipPdf`/`sharePayslipPdf` (per-document, decoupled), `HrReportExporters.sharePayslipPdf`, "Individual payslips" picker sheet (`_IndividualPayslipSheet`) reusing `hrPayslipsProvider`; `qa_test_keys.dart`. Client-only, read-only rendering. | **PASS** (EOS FEATURE) | analyze 0; full suite **3616 pass, 0 new fails** (2 known UX-7); HR+reports+contracts **103/0**; no backend changes | HR-1, HR-2 | P1-PROD-5 |

| 2026-07-04 | (no code) | P1 | **P1-PROD-6 · C8 — Transport Fleet, Roster & Fee (TRN-1/2/3/4/9) — VERIFICATION** | Discovery-first: all five items already built (fleet CRUD w/ guards, ISO doc-expiry + date picker, stop roster export via shared service, stop editor w/ reorder, TRN-9 fee→Finance demand). **Money boundary CONFIRMED intact + test-enforced** (zero payment code in Transport; get-or-create per-year account; double-invoice blocked by Finance assignment uniqueness). Per EOS rule #4 no rebuild. One candidate gap (TRN-9 app-level dedupe race) NOT hot-patched — money-contained + unsafe to drive-by-fix (route-vs-structure semantics) → tracked `TRN9-DEDUPE`. | **PASS** (EOS FEATURE — covered by existing + tests; money boundary verified) | deno transport **36/0** (incl. money-boundary test), finance-assignments **12/0**, flutter transport **42/0**; no files changed | TRN-1, TRN-2, TRN-3, TRN-4, TRN-9 | P1-PROD-6 |

| 2026-07-04 | `2ecee77` | P1 | **P1-PROD-7 · C9 — Inventory, Library & Communication (INV-1/2·LIB-1/2·COM-1/2)** | Discovery-first: all six already built (inventory memory was stale — INV-1/3/6 stock ledger fully done; governance intact: FOR UPDATE lock, negative-block 422+DB CHECK, immutable stock_movements ledger, maker-checker SoD 409). Per EOS rule #4 no rebuild. **One gap closed — LIB-2 bulk-import test:** extracted pure `planImportRow` (behavior-preserving) in `library_write_handlers.ts` + 4 unit tests (dedupe/partial-success). | **PASS** (EOS FEATURE) | deno inventory+library **76/0** (+4), comm report+audience **27/0**; api typecheck clean; backend-only (flutter unaffected) | INV-1, INV-2, LIB-1, LIB-2, COM-1, COM-2 | P1-PROD-7 |

| 2026-07-04 | `7c9294b` | P1 | **P1-PROD-8 · C10 — Principal Approval Center batch (PRI-1)** | Discovery-first: PRI-1 batch approve/reject already built (multi-select UI + `POST /approvals/batch-decide` + audit-each + partial-success + client wiring + backend tests). Per EOS rule #4 no rebuild. **Closed a money-SoD gap:** `decideApproval` self-approve guard was `inventoryPo`-only → extended to `{inventoryPo, feeConcession, refund, feeStructure}` (`SELF_APPROVE_DENIED_TYPES`) so a requester can't approve their OWN money waiver on single OR batch (FIN-D4); reject-by-same-person still allowed. `approval_separation_of_duties_test.ts` (+3), `approval_batch_decide_test.ts` (+1). | **PASS** (EOS FEATURE — closes a permission-escalation exposure) | deno approval **59/0** (+4), finance fee-concession **2/0**; api typecheck clean; backend-only (flutter unaffected) | PRI-1 | P1-PROD-8 |

| 2026-07-04 | `10f8461` | P1 | **P1-PROD-9 · C11 — Admissions / Front-office productivity (ADM-1..5)** | Discovery-first: ADM-2 (auto-log WhatsApp/call to timeline), ADM-3 (bulk lead actions), ADM-4 (follow-ups-due inline), ADM-5 (New-App real lead picker) all built + tested; admission approval SoD-gated (self-approve→409). Per EOS rule #4 no rebuild. **Closed ADM-1 PDF export gap:** `admissions_reports_screen.dart` extracted `_gridForTab`, added `shareGridPdf` path (CSV+PDF, compact icon buttons — fixed a filter-bar overflow in-wave), `qa_test_keys.dart` (+2 keys); `adm1_reports_export_widget_test.dart` (+2), phase3 test updated. | **PASS** (EOS FEATURE) | analyze 0; full suite **3618 pass, 0 new fails** (2 known UX-7); admissions **110/0**; client-only (no backend) | ADM-1, ADM-2, ADM-3, ADM-4, ADM-5 | P1-PROD-9 |
| 2026-07-06 | `2bd7ecd` | P1 | **P1-PROD-10 · C12 — Finance productivity & receipting (FIN-3/4/5/9, FIN-R6/R7)** | Discovery-first: **FIN-4** (duplicate reprint stamps `DUPLICATE`+audits, RBAC), **FIN-5** (batch receipt PDF), **FIN-9** (aging/defaulters/reports/intelligence on real data) verified already built. Per EOS rule #4 no rebuild. **Closed FIN-3:** shared `indianDigitGroups` (Indian lakh/crore) on the receipt PDF `_formatInr`, consistent with the existing Indian amount-in-words (was Western 3-digit). **Built FIN-R7** cheque/DD/PDC + bounce on the `finance_offline_payments` **tracking ledger** — added `pdc` method, `instrument_date`/`bank_name`, terminal `bounced` status + bounce audit; **money-safe** (that ledger never posts to `finance_collections`; bounce reverses no money; test-enforced); migration `20260850…` + repo + `handleBounceOfflinePayment` + route + `offlinePaymentBounced` audit + full client (enum/codec/model/mapper/request/repo×3/notifier/api-path/screen: PDC option, instrument fields, Bounced tab, mark-bounced). **FIN-R6:** owner resolved **FIN-D6** (principal sets, collectors see own) → enriched recovery dashboard `collectorPerformance` with `target`+`attainmentPct` (reuses FIN-R5 `collectorPerformanceForMonth` + `listRecoveryTargets`); principal-gated set-target action + notifier + repo×3. Money-safety tripwire intact (Finance = sole engine; targets/reprints/analytics read-only). | **PASS** (EOS FEATURE) | analyze 0; full suite no-new-fail (2 known UX-7); deno finance+audit **172/0**; deno check green; **+13 tests** (FIN-3 ×5, FIN-R7 backend ×6, FIN-R7+FIN-R6 contract ×2) | FIN-3, FIN-4, FIN-5, FIN-9, FIN-R6, FIN-R7 | P1-PROD-10 |
| 2026-07-06 | `0a8c2a3` | P1 | **P1-PROD-11 · C13 (Exams half) — Academic-work productivity (EXM-4/5/6/7)** | Discovery-first: **EXM-4** (merit list + subject topper), **EXM-5** (pass/fail + grade-distribution report), **EXM-7** (datesheet PDF) all verified built end-to-end (backend + client + CSV/PDF exports). Per EOS rule #4 no rebuild. **Closed EXM-6** — the FIRST caller of the shared **XCT-2** reminder rail: `listOverdueMarksEntry` (marks_entry phase, deadline passed, marks still pending) + `handleRemindPendingMarks` (manageExams) checks pending AT trigger (no false reminder) then schedules ONE in-app `all_teachers` reminder via `scheduleReminder` (fires through the scheduled-broadcast runner into teacher inboxes); pure `buildMarksReminder` digest; audited `exam.marks_reminder.sent`; `POST /academics/exams/marks/remind` + route-contract. Client: marks-progress board shows deadline + "Overdue" badge, manageExams-gated "Remind teachers" action → count snackbar; `MarksEntryProgress.isOverdue` + repo/notifier/api-path. **Homework half HWK-3..8 deferred with C6.** Exam-result governance untouched (no marks/results mutated). | **PASS** (EOS FEATURE) | analyze 0; full suite no-new-fail (2 known UX-7); deno exam-administration **124/0**, reminders+audit **24/0**; deno check green; **+12 tests** (EXM-6 builder ×4, route-contract ×2, model isOverdue ×4, screen ×2) | EXM-4, EXM-5, EXM-6, EXM-7 | P1-PROD-11 |
| 2026-07-06 | `9e5602a` | P1 | **P1-PROD-12 · C14 — Teacher & Attendance productivity (TCH-1/2/3/4, ATT-3/4)** | Discovery-first: **TCH-4** (weekly timetable `TeacherTimetableScreen` + server-backed cover/substitution alert `CoverAlertCard`/`teacherTodayCoverProvider`), **ATT-3** (absentees-only "fill remaining present" fast-mark `fillRemainingAsPresent`), **ATT-4** (office not-yet-marked monitor `/attendance/pending` + `_PendingTab`) all verified built. Per EOS rule #4 no rebuild. Closed 3 gaps: **TCH-1** — the today-schedule-row tap landed on the weekly timetable; re-pointed via a new `schedule_attendance_<classLabel>` action → `teacherAttendance?class=<label>` (attendance screen already supported the preselect), leaving the pending-banner `mark_attendance_` path untouched. **TCH-2** — teacher-home "Marks to enter" task now reflects overdue: reuses EXM-6 `MarksEntryProgress.isOverdue` → urgent (error) tone + "Marks overdue" label (`PendingTask.overdue`). **TCH-3** — my-class marks-summary export (Class/Subject/Entered/Total/Pending/Status incl. Overdue) on the shared XCT-1 grid pipeline (`TeacherReportExporters.shareMarksSummaryCsv/Pdf`), wired as an export action on the teacher exams screen. Attendance integrity untouched (nav-only, no register mutation); no new scheduler. Client-only (0 `supabase/**`). | **PASS** (EOS FEATURE) | analyze 0; full suite no-new-fail (2 known UX-7); teacher-dashboard golden unchanged; **+4 tests** (TCH-1 nav, TCH-2 overdue tone, TCH-3 rows-unit + export-button) | TCH-1, TCH-2, TCH-3, TCH-4, ATT-3, ATT-4 | P1-PROD-12 |

*(Wave-2 onward: the executing session appends one row per task as each passes EOS and commits.)*

---

## 5. How to use this journal (executor)

1. Complete a wave through the Autonomous-Plan loop (implement → validate → regression → docs → `/eos`).
2. **Only on EOS PASS**, commit.
3. **Immediately** append one row here with the real commit SHA + evidence + finding + roadmap id.
4. Flip the wave's Status in the roadmap and its finding in the ledger.
5. Add the EOS verdict to `docs/engineering/eos/EOS_RUN_LEDGER.md`.
6. Never edit past rows; the journal is append-only and permanent.

*Progress dashboard (roadmap §0) + this journal must always agree. If they diverge, execution has drifted — halt and reconcile (Autonomous Plan §9).*
