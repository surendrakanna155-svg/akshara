# Export Parity Audit — Pilot Scope

**Date:** 2026-06-18  
**Modules:** Academics · Attendance · Finance · Student 360 / SIS  
**Status key:** Real · Partial · Preview stub · Missing

---

## Summary

| Status | Before sprint | After sprint |
|--------|---------------|--------------|
| **Real** | 5 | 10 |
| **Partial** | 2 | 2 |
| **Preview stub** | 4 | 1 |
| **Missing** | 6 | 3 |

---

## Academics

| Surface | Path | Before | After |
|---------|------|--------|-------|
| Education question paper | `education_screen.dart` | Real | Real |
| Education homework | `education_screen.dart` | Real | Real |
| Education report card PDF | `education_screen.dart` | Preview queued | **Real** (`EducationPdfService.printReportCardRemark`) |
| Exam administration list | `exam_administration_screen.dart` | Missing | Missing |
| Exam marks CSV | `exam_marks_entry_screen.dart` | Missing | **Real** (`shareTabularCsv`) |

---

## Attendance

| Surface | Path | Before | After |
|---------|------|--------|-------|
| Management dashboard PDF | `management_dashboard_screen.dart` | Real (includes attendance KPIs) | Real |
| Teacher mark attendance | `teacher_attendance_screen.dart` | Missing | Missing |
| Management corrections admin | `attendance_corrections_admin_screen.dart` | Missing | Missing |
| Management analytics | `management_analytics_screen.dart` | Missing | Missing |

*Attendance register export deferred — out of minimum pilot export checklist (P0-FIN-003 scope was finance-first).*

---

## Finance

| Surface | Path | Before | After |
|---------|------|--------|-------|
| Finance reports PDF | `finance_reports_screen.dart` | Partial real | Partial real |
| Finance reports Excel/CSV | `finance_reports_screen.dart` | Snackbar only | **Real** (`shareTabularCsv`) |
| Finance audit register | `finance_reports_screen.dart` | Real | Real |
| Finance executive dashboard | `finance_executive_dashboard_screen.dart` | Preview queued | **Real** (tabular PDF) |
| Finance email report | `finance_reports_screen.dart` | Preview stub | Preview stub (deferred — no email pipeline) |
| Parent receipt PDF | `app_router.dart` | Real | Real |
| ERP collection receipt | `finance_collection_detail_screen.dart` | Backend only | Backend only (UI deferred) |

---

## Student 360 / SIS

| Surface | Path | Before | After |
|---------|------|--------|-------|
| SIS registry export | `sis_registry_screen.dart` | Preview stub | **Real** (CSV share) |
| Student 360 dossier PDF | `student_360_screen.dart` | Missing | **Real** (overview PDF) |
| SIS profile | `sis_profile_screen.dart` | Missing | Missing (links to Student 360) |

---

## Shared services

| Service | Path |
|---------|------|
| `AksharaReportExportService` | `lib/core/reports/akshara_report_export_service.dart` |
| `FinanceAuditRegisterService` | `lib/core/reports/finance_audit_register_service.dart` |
| `EducationPdfService` | `lib/features/education/education_pdf_service.dart` |
| `ManagementDashboardPdfService` | `lib/features/management/reports/management_dashboard_pdf_service.dart` |

`shareTabularCsv` added to `AksharaReportExportService` for pilot CSV delivery.

---

## Remaining pilot gaps (P2)

1. Attendance class/month register CSV  
2. ERP finance receipt download on collection detail  
3. Finance report PDF enrichment (trend rows vs metadata-only)
