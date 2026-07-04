# EOS Report — P1-PROD-0 · XCT Foundations (C0)

**Scope:** FOUNDATION — the three cross-cutting foundations the C-waves (P1-PROD-1..21) and P3 W1.4 depend on: **XCT-1** shared export pipeline, **XCT-2** reminder/scheduling rail, **XCT-3** real date pickers.
**Date:** 2026-07-04 · **Gate:** **PASS** (0 P0 / 0 P1) · **Ledger:** appended.
**Anchors:** Constitution Part 7B (*Certification Categories*, *Evidence Requirements*, *Automatic-Failure Conditions*), Part 8 (*Release Decision*). This report cites the law; it does not restate it.

---

## 1. Done-when (roadmap `NEXT_ACTIVE_WAVE.md`) — all met

| Exit criterion | Verdict | Evidence |
|---|---|---|
| ≥3 real exports ride ONE shared pipeline (verified, gaps closed) | ✅ | ~15 modules already ride `AksharaReportExportService` (finance/HR/teacher/exams/inventory/transport/SIS/library/director/admissions/parent/student). The **3 remaining bespoke tabular-PDF builders** that hand-rolled `pw.TableHelper.fromTextArray` now ride the shared primitive `buildGridTable` — see §2. |
| ≥1 in-app reminder fires through the scheduling rail (test proves it) | ✅ | `reminders_service_test.ts` — "a DUE reminder fires end-to-end into a pending in-app delivery" (claim → audience fan-out → `INSERT INTO notification_deliveries` `'pending'` → source row finalized `'sent'`). deno 5/5. |
| Free-text `YYYY-MM-DD` fields replaced with real date pickers on the known offenders | ✅ | HR leave (create + on-behalf, from/to ×4) + probation (×1) + intelligence meeting-date now use `AksharaDateField` (read-only → `showDatePicker`). §4. |

## 2. XCT-1 — export-pipeline consolidation (Code Quality / Architecture)

**Finding (verify, not rebuild):** CSV export was already fully centralized; the only real duplication was **3 PDF services re-implementing the grid-table styling** (border grey400 / bold header / grey200 decoration).

- New shared primitive `AksharaReportExportService.buildGridTable({headers, rows, rightAlignFrom})` — [akshara_report_export_service.dart:598](../../../lib/core/reports/akshara_report_export_service.dart#L598); `buildGridReportPdf` now delegates to it (single styling source).
- Routed onto the primitive (duplication removed): [management_dashboard_pdf_service.dart](../../../lib/features/management/reports/management_dashboard_pdf_service.dart) (2 tables), [operations_hub_pdf_service.dart](../../../lib/features/operations/operations_hub_pdf_service.dart) (4 tables), [finance_audit_register_service.dart](../../../lib/core/reports/finance_audit_register_service.dart) (register table; its CSV path already reused the service).
- Evidence: `test/core/reports/xct1_shared_grid_table_test.dart` (3/3) — primitive returns a table; `buildGridReportPdf` emits a real PDF; the previously-bespoke `OperationsHubPdfService` now produces a valid PDF through the shared primitive.

## 3. XCT-2 — reminder / scheduling rail (Reliability)

**Finding:** the scheduled-broadcast substrate (persisted `scheduled_at` → atomic `FOR UPDATE SKIP LOCKED` claim → fan-out → pending in-app delivery) already existed and was labelled XCT-2, but (a) its end-to-end *fire-through* was **unproven** (only route + validator tests existed) and (b) there was **no module-facing "reminder" API** — modules would have to call comms internals.

- New `_shared/reminders/reminders_service.ts`: `scheduleReminder(...)` (authoring seam; validates/normalizes `remindAt`, delegates to the scheduled-broadcast write path) and `runDueReminders = runDueScheduledBroadcasts` (**literally one runner** — a module reminder and a scheduled broadcast can never diverge). This is the "one rail every module reuses; no module invents its own."
- Fires **in-app** into `notification_deliveries` (the source the client notifications inbox reads). External push/SMS/WhatsApp stays owner-gated by design (roadmap `FINAL_QA_ROADMAP.md:549`) — not a gap.
- Evidence: `reminders_service_test.ts` 5/5 — due-fires-end-to-end, nothing-due-fires-nothing, single-runner identity, `scheduleReminder` persists+normalizes, `scheduleReminder` rejects bad `remindAt` (422) with no row written.

## 4. XCT-3 — real date pickers (Code Quality / UX-correctness)

- New shared `AksharaDateField` — [akshara_date_field.dart](../../../lib/shared/forms/akshara_date_field.dart): read-only field → `showDatePicker`, writes canonical ISO `yyyy-MM-dd` back to the caller's controller (existing `.text.trim()` call sites unchanged, but can no longer receive malformed input).
- Applied to the named offenders: `hr_workflow_actions.dart` leave (create + on-behalf) from/to + probation-end; plus the ISO `teacher_effectiveness_screen.dart` meeting-date.
- Evidence: `test/shared/forms/akshara_date_field_test.dart` (3/3 — read-only rejects typed text; tap opens picker; selection writes ISO). The two HR flow tests (`hr_final_slice`, `mod2_3_payroll_engine_client`) were updated to **drive the picker** — proving the field works inside the real dialogs.

## 5. Automatic-failure check (Part 7B) — none triggered

No data loss · no security breach · no permission escalation · no tenant-isolation regression · no critical crash · no duplicate financial transaction · no broken auth/sync · no critical regression. XCT-1/3 are client rendering/input; XCT-2 adds an authoring seam + tests over an existing, already-audited delivery path.

## 6. Regression evidence

- `flutter analyze` → **0 issues.**
- `flutter test` (full) → **3611 passed / 2 failed / 0 new.** The 2 failures are the pre-existing **UX-7** `TeacherDashboard` 360×640 overflow (fails on clean HEAD; tracked → P2-UX).
- `deno test --allow-env --allow-read` (touched: communication + reminders) → **108 passed / 1 failed.** The 1 failure is the pre-existing **ISO-COUNT** probe-count drift (`communication_probe_validation_test.ts`, untouched by this wave; documented as a tracked pre-existing defect, not a wave regression).

## 7. Verdict

**EOS gate: PASS.** 0 P0 / 0 P1. All three done-when criteria met with test evidence; no automatic-failure condition; regression gates green (2 known UX-7 + 1 known ISO-COUNT carried, all pre-existing and tracked). Project-level GA gating is unchanged (live lane + later phases). **Advance → P1-PROD-1 (C1 — Finance Recovery CRM).**

**Commit:** `83bc267` (feat) · docs(eos) close companion follows.
