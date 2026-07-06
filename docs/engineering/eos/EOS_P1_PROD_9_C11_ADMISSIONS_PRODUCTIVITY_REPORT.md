# EOS Report — P1-PROD-9 · C11 · Admissions / Front-office productivity (ADM-1..5)

**Scope:** FEATURE (Admissions) — reports export, contact auto-log, bulk lead actions, follow-ups-due inline, New-Application lead picker.
**Date:** 2026-07-04 · **Gate:** **PASS** (0 P0 / 0 P1) · **Ledger:** appended.
**Anchors:** Constitution Part 7B (*Certification Categories*, *Evidence Requirements*), Part 8 (*Release Decision*); EOS rule #4. Cites the law; does not restate it.

---

## 1. Discovery-first — ADM-2/3/4/5 already built; ADM-1 was CSV-only

Four of the five items exist end-to-end with real persistence + RBAC + tests. Completion criterion (`FINAL_QA_ROADMAP.md:564`) met after closing the ADM-1 PDF gap.

| Item | Verdict | Evidence |
|---|---|---|
| **ADM-1** real reports export | ✅ (CSV existed; **PDF added this wave**) | Real report data (`admissions_reports_repository.ts getReports`, `GET /admissions/reports`); client screen exported CSV via `AksharaReportExportService.shareGridCsv` — now also PDF (§2). |
| **ADM-2** auto-log WhatsApp/call to timeline | ✅ EXISTS | `admissions_lead_activities` table; `handleAddLeadNote` (activity_type note/whatsapp/call, auto-titled + audited); client `autoLogWhatsAppNote` on WhatsApp send + explicit Log call/WhatsApp; timeline widget renders activities. |
| **ADM-3** bulk lead actions (multi-select) | ✅ EXISTS | `handleBulkLeadActions` (MAX_BULK cap, per-lead activity+audit) `POST /admissions/leads/bulk`; client multi-select + bulk action bar; tests `admissions_leads_completion_test.ts`, `admissions_client_features_test.dart` (ADM-3 group). |
| **ADM-4** follow-ups-due inline actions | ✅ EXISTS | `admissions_lead_follow_ups` table; complete/reschedule handlers (+ activity); client "Follow-ups due today" table + Complete/Reschedule/Call sheet; tests (ADM-4 group). |
| **ADM-5** New-Application real lead picker | ✅ EXISTS | `showAdmissionsLeadPickerDialog` (real leads); New Application seeds from the picked lead (no placeholder junk); test (ADM-5 group). |

**Also verified (governance):** admission approval **is** maker-checker SoD-gated (`admissions_repository.ts setApprovalDecision` — maker `submitted_by` ≠ checker → `SELF_APPROVE_DENIED`/409; migration `20260846000000_admissions_approval_sod`), consistent with the C10 approval-SoD hardening.

## 2. Gap closed — ADM-1 PDF export

The admissions reports screen exported **CSV only** — the shared `shareGridPdf` existed but was never invoked (unlike every other module, which offers CSV **and** PDF). Fix in [admissions_reports_screen.dart](../../../lib/features/admissions/reports/admissions_reports_screen.dart):
- Extracted the per-tab grid into `_gridForTab(data, tab)` (title/headers/rows) so CSV and PDF share exactly the same columns.
- Added a PDF export path via `AksharaReportExportService.shareGridPdf` (module label "Admissions · Reports"); the filter-bar trailing now offers **both** CSV and PDF (compact keyed icon buttons — sized so they don't overflow the filter bar on narrow widths).
- Evidence: `adm1_reports_export_widget_test.dart` (2/2 — tapping Export PDF/CSV fires the respective shared-service grid export, captured via a fake service); `admissions_phase3_screens_test.dart` updated to assert both export affordances render.

## 3. Automatic-failure check (Part 7B) — none

Client-only export wiring — the reports backend already returns real aggregates; no money, no auth, no data-loss surface touched. No new failures.

## 4. Regression evidence

- `flutter analyze` → **0**.
- `flutter test` (full) → **3618 passed / 2 failed / 0 new** (the 2 are pre-existing **UX-7** TeacherDashboard 360×640 overflow → P2-UX). *(A transient router-smoke overflow introduced by a first two-labelled-button layout was caught in-wave and fixed with compact icon buttons before commit.)*
- `flutter test test/features/admissions/ test/contracts/admissions/` → **110 passed / 0 failed** (incl. the new ADM-1 export tests).
- No `supabase/**` changes → no deno leg.

## 5. Noted (tracked, not this-wave gaps)

- ADM-2 client test — no widget test asserts `autoLogWhatsAppNote` fires on WhatsApp send (backend activity write is covered; client is thin). Minor test-debt.

## 6. Verdict

**EOS gate: PASS.** 0 P0 / 0 P1. ADM-2/3/4/5 verified existing (no rebuild); the one gap (ADM-1 PDF export) closed + tested; admission-approval SoD verified intact; no automatic-failure; regression green (2 known UX-7 carried). **Advance → C12 (Finance productivity & receipting — deps C1+C2, both done).**

**Commit:** `10f8461` (feat+test) · docs(eos) close companion follows.
