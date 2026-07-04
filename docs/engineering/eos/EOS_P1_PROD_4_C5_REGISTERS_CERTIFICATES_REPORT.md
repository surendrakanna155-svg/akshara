# EOS Report — P1-PROD-4 · C5 · Academic Registers & Certificates (ATT-1/ATT-2/SIS-1)

**Scope:** FEATURE (Academics / SIS) — office attendance register, monthly class register, student certificates.
**Date:** 2026-07-04 · **Gate:** **PASS (covered by existing implementation + tests; one test-coverage gap closed)** · **Ledger:** appended.
**Anchors:** Constitution Part 7B (*Certification Categories*, *Evidence Requirements*), Part 8 (*Release Decision*); EOS rule #4 (*never re-audit / rebuild covered work*). Cites the law; does not restate it.

---

## 1. Outcome — C5 already implemented end-to-end; one test-coverage gap closed

Discovery-first found all three items already built with real backend + client + shared export + tests. Completion criterion (`FINAL_QA_ROADMAP.md:555`: "register renders + exports; certificates generate as print-ready PDFs") is met. **No feature rebuild** — the only change is one added test.

| Item | Verdict | Evidence |
|---|---|---|
| **ATT-1** office attendance register (AC-06) | ✅ EXISTS | `office_attendance_screen.dart` register tab: class+date filter, present/absent/late/excused display (`_MarkBadge`), CSV+PDF export via `AksharaReportExportService.shareGridPdf/shareGridCsv`; real backend `getAttendanceRegister` (`attendance_office_repository.ts`, `GET /attendance/register`, viewSis + school scope). Tests: `office_attendance_screen_test.dart`, `attendance_office_route_contract_test.ts`. |
| **ATT-2** monthly class register (students × days) | ✅ EXISTS (+ new cell-level test) | `_MonthlyTab`/`_MonthlyMatrix` — students × days grid (P/A/L/E cells + % column), class+month filter, CSV+PDF export via the shared service; real backend `getMonthlyRegister` (`EXTRACT(DAY FROM session_date)` → per-student marks map, `GET /attendance/register/monthly`). Data source (student daily marking) is real (`handleTeacherAttendanceSubmit` → `attendance_sessions`/`attendance_records`). |
| **SIS-1** Bonafide/Study/Conduct certificates | ✅ EXISTS (identity cluster) | `POST /sis/students/{id}/certificates` (`handleIssueCertificate`, manageSis, rejects transfer→422, audited, immutable `sis_certificate_issues` register — SELECT+INSERT only); client `showSisIssueCertificateDialog` + `SisCertificatePdfService.buildCertificatePdf` (print-ready PDF, bespoke formal layout). Tests: `sis_certificates_repository_test.ts`, `sis_certificate_pdf_service_test.dart`, `sis_certificates_test.dart`. |

## 2. Gap closed — ATT-2 cell-level render test

ATT-2 had backend + route-contract + tab-render coverage but **no cell-level assertion** that the students×days matrix actually renders. Added `office_attendance_screen_test.dart` → "ATT-2 · monthly tab renders the students×days register matrix": switches to the Monthly tab and asserts the `DataTable` renders a real student row, per-day P/A/L/E code cells, the `%` column, and the CSV/PDF export affordances (which ride the shared pipeline). Test-only — no `lib/**` change.

## 3. Automatic-failure check (Part 7B) — none

Test-only change. The certificate register is immutable (SELECT+INSERT only) with audit; attendance reads are tenant + school scoped with RBAC (viewSis / markAttendance). No money, no auth, no data-loss surface touched.

## 4. Regression evidence

- `flutter analyze` → **0** (only a test file + docs changed → full suite unaffected; 3613→3614 pass, 2 known UX-7 → P2-UX).
- `flutter test test/features/management/attendance/ test/features/sis/` → **73 passed / 0 failed** (incl. the new ATT-2 test).
- `deno test --allow-env --allow-read supabase/functions/_shared/attendance/ _shared/sis/` → **151 passed / 1 failed** — the 1 failure is the pre-existing **ISO-COUNT** `sis_probe_validation_test` (stale probe-count total; untouched by this wave, documented tracked defect).

## 5. Noted (not a C5 gap)

- ATT-1 student office-register filters are class+date only (no department/status filter). "Filter" is satisfied; department/status filtering is a **UX enhancement** → P2-UX, not a completion gap (adding it would be inventing scope).
- Staff attendance muster (HR-6) is a separate, also-built feature — not conflated with the student office register.

## 6. Verdict

**EOS gate: PASS.** 0 P0 / 0 P1. ATT-1/ATT-2/SIS-1 verified existing (real, tested — no rebuild); one genuine test-coverage gap (ATT-2 cell-level render) closed; no automatic-failure; regression green (2 known UX-7 + 1 known ISO-COUNT carried). **Advance → C7 (HR Payroll & Salary Registers, HR-1/HR-2).** Note: **C6 (Homework core) defers** — HWK-1 is an owner-gated contract/schema change (`due_label` free-text → real `due_date DATE`, needs an owner-approved migration) → surfaced as an owner decision, not auto-started. **C3** also remains deferred (GA-1 live).

**Commit:** `1fc6104` (test) · docs(eos) close companion follows.
