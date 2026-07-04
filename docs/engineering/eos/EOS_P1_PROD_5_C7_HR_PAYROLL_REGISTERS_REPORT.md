# EOS Report — P1-PROD-5 · C7 · HR Payroll & Salary Registers (HR-1/HR-2)

**Scope:** FEATURE (HR) — salary register export + payslip run.
**Date:** 2026-07-04 · **Gate:** **PASS** (0 P0 / 0 P1) · **Ledger:** appended.
**Anchors:** Constitution Part 7B (*Certification Categories*, *Evidence Requirements*, *Automatic-Failure Conditions*), Part 8 (*Release Decision*); EOS rule #4. Cites the law; does not restate it.

---

## 1. Discovery-first — the engine + most of C7 already existed

The P1-CODE-5 payroll engine (salary structures + `generatePayrollRun`, server-side netPay) and the C7 exports were already built. The roadmap's "stub snackbar" assumption is **stale** — `hr_payroll_screen.dart:180` comments "replaces the old stub snackbar."

| Item | Verdict | Evidence |
|---|---|---|
| **HR-1** salary register export (per-employee Basic/Allowances/Deductions/Net + totals) | ✅ EXISTS (verified) | Backend `buildSalaryRegister` (`hr_reports_repository.ts`, `GET /hr/payroll/register`); client `HrReportExporters.shareSalaryRegisterPdf/Csv` (rows + `TOTAL` row) via `AksharaReportExportService`; UI buttons on the payroll screen. Tests: `hr_reports_repository_test.ts`, `hr_reports_export_widget_test.dart`. |
| **HR-2** payslip run — all-employees batch | ✅ EXISTS (verified) | `sharePayslipsBundlePdf` (one document, section per employee) + `sharePayslipsCsv`; `GET /hr/payroll/payslips`. |

## 2. Real gap closed — HR-2 individual per-employee payslip PDF

HR-2's item description is "one-click payslip run (**per-employee PDF** + all-for-run)". The all-for-run **batch** existed; a **strictly individual, one-file-per-employee** payslip PDF did **not**. Built it (client-only — the payslip data already comes from the engine via `getPayslips`):

- New per-document builder `AksharaReportExportService.buildPayslipPdf` / `sharePayslipPdf` ([akshara_report_export_service.dart](../../../lib/core/reports/akshara_report_export_service.dart#L79)) — mirrors `buildReceiptPdf`; a single employee's earnings + deductions tables with net pay called out. Decoupled from HR domain models (primitive params only).
- `HrReportExporters.sharePayslipPdf(HrPayslip, {period})` maps the view-model onto it (no HR CSV/PDF layout invented — rides the shared service).
- UI: an **"Individual payslips"** action on the payroll export bar opens a picker sheet listing the run's employees, each with a per-employee download (`_IndividualPayslipSheet`), reusing the already-loaded `hrPayslipsProvider(runId)` bundle.
- Evidence: `hr_reports_export_widget_test.dart` "HR-2 · individual payslips sheet downloads a single per-employee slip" (opens the sheet, taps a per-employee download, asserts a single `payslip:` export fired — not the bundle grid — + success feedback); `akshara_report_export_csv_test.dart` "buildPayslipPdf produces a non-empty single-employee PDF".

## 3. Automatic-failure check (Part 7B) — none

Client-only, **read-only rendering**: payroll figures are computed server-side by the P1-CODE-5 engine; the payslip/register exports introduce **no new money math**. No duplicate financial transaction, no data loss, no auth change. viewHr-gated payroll screen unchanged.

## 4. Regression evidence

- `flutter analyze` → **0**.
- `flutter test` (full) → **3616 passed / 2 failed / 0 new** (the 2 are pre-existing **UX-7** TeacherDashboard 360×640 overflow → P2-UX).
- `flutter test test/features/hr/ test/core/reports/ test/contracts/hr/` → **103 passed / 0 failed** (incl. the new individual-payslip widget + `buildPayslipPdf` service tests).
- No `supabase/**` changes → no deno leg.

## 5. Verdict

**EOS gate: PASS.** 0 P0 / 0 P1. HR-1 register + HR-2 batch payslips verified existing (no rebuild); the one genuine gap — HR-2 individual per-employee payslip PDF — built and tested; no automatic-failure; regression green (2 known UX-7 carried). **Advance → C8 (Transport Fleet, Roster & Fee).**

**Commit:** `524105e` (feat) · docs(eos) close companion follows.
