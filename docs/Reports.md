# Akshara ERP — Enterprise Report Catalog

**Document ID:** `AKS-RPT-CATALOG-v1.0`  
**Scope:** Master catalog for all report surfaces — eliminates duplicate report UIs  
**Source:** ArchitectureReview AR-011 · SRS Part 3/8 · Module specs  
**Rule:** Module "Reports" screens are **launchers + filters** — generation logic lives here

---

## Table of Contents

1. [Overview](#1-overview)
2. [Dashboard Tier Model](#2-dashboard-tier-model)
3. [Report ID Convention](#3-report-id-convention)
4. [Finance Reports](#4-finance-reports)
5. [Management & Executive Reports](#5-management--executive-reports)
6. [Admissions & Marketing Reports](#6-admissions--marketing-reports)
7. [Academic Reports](#7-academic-reports)
8. [HR Reports](#8-hr-reports)
9. [Operations Reports](#9-operations-reports)
10. [Director Portfolio Reports](#10-director-portfolio-reports)
11. [Module Launcher Mapping](#11-module-launcher-mapping)
12. [Shared Report UI Pattern](#12-shared-report-ui-pattern)
13. [Build Checklist](#13-build-checklist)

---

## 1. Overview

### Problem

Five modules duplicate "Reports Center" patterns: **MG-08**, **DR-09**, **FN-11**, **MK-09**, **HR-08**, plus scattered report cards in Hostel, Transport, Academic.

### Solution

| Layer | Responsibility |
|-------|----------------|
| **Reports.md (this catalog)** | Canonical report definitions, parameters, permissions, output formats |
| **Report Service** | Edge Function `generate-report` — single engine |
| **Module launchers** | Filtered subsets + deep link to catalog ID |
| **FN-10 / Audit** | Log every `report.catalog_export` |

---

## 2. Dashboard Tier Model

Per ArchitectureReview AR-009–011 — avoid duplicate KPI dashboards:

| Tier | Owner screens | Data scope | Editable actions |
|------|---------------|------------|------------------|
| **Operational** | FN-01, AD-01, HR-01, HO-01 | Single school · live transactions | ✅ Full CRUD in module |
| **Executive** | MG-01, MG-05, MG-06, MG-08 | Single school · aggregates | 👁 Read + approve only |
| **Portfolio** | DR-01, DR-04, DR-07, DR-09 | Multi-school · no PII | 👁 Compare + export only |

### Embed Rule

MG-06, MK-08, DR-07 admissions analytics → **embed AD-09 APIs** (source of truth funnel).  
MG-05, DR-04 revenue → **embed FN-11 summary APIs** — no duplicate chart specs in MG/DR.

**Banner text (Executive/Portfolio):** `"Read-only aggregate · Drill to operational module for actions"`

---

## 3. Report ID Convention

`RPT-{DOMAIN}-{###}`

| Domain | Code |
|--------|------|
| Finance | `FN` |
| Management | `MG` |
| Admissions | `AD` |
| Marketing | `MK` |
| Academic | `AC` |
| HR | `HR` |
| Hostel | `HO` |
| Transport | `TR` |
| Director | `DR` |
| SIS | `SIS` |

---

## 4. Finance Reports

| ID | Name | Parameters | Roles | Launcher |
|----|------|------------|-------|----------|
| RPT-FN-001 | Fee Collection Summary | FY, term, class | Finance, Management | FN-11 |
| RPT-FN-002 | Defaulter List | class, amount_min, days_overdue | Finance | FN-03, FN-11 |
| RPT-FN-003 | Income Statement | FY, quarter | Finance, Management, Director 👁 | FN-11 |
| RPT-FN-004 | Expense Breakdown | FY, category | Finance, Management | FN-11, FN-05 |
| RPT-FN-005 | Payroll Register | month, department | Finance, Management | FN-06, FN-11 |
| RPT-FN-006 | Budget vs Actual | FY, department | Finance, Management | FN-09, FN-11 |
| RPT-FN-007 | Cash Flow | FY, month | Finance | FN-11, FN-08 |
| RPT-FN-008 | GST Summary | quarter | Finance | FN-11 |
| RPT-FN-009 | Vendor Payment Log | date_range | Finance | FN-07 |
| RPT-FN-010 | Audit Export | module, severity, date | Finance, Management | FN-10 |

---

## 5. Management & Executive Reports

| ID | Name | Parameters | Roles | Launcher |
|----|------|------------|-------|----------|
| RPT-MG-001 | Executive Board Pack | FY, quarter | Management, Director | MG-08, DR-09 |
| RPT-MG-002 | School Performance Summary | term, class_range | Management, Principal 👁 | MG-04 |
| RPT-MG-003 | Approval History | type, date | Management | MG-03 |
| RPT-MG-004 | Financial Executive Summary | FY | Management | MG-05 → FN-11 embed |
| RPT-MG-005 | Staff Strength | department | Management | MG-07 |
| RPT-MG-006 | Compliance Summary | date | Management, Director | DR-08 |

---

## 6. Admissions & Marketing Reports

| ID | Name | Parameters | Roles | Launcher |
|----|------|------------|-------|----------|
| RPT-AD-001 | Admissions Funnel | year, source, counselor | Counselor, Management | **AD-09 (source of truth)** |
| RPT-AD-002 | Conversion by Source | year, campaign | Marketing, Management | AD-09, MK-08 embed |
| RPT-AD-003 | Counselor Performance | year | Management | AD-09 |
| RPT-AD-004 | Time to Admission | year | Management, Director 👁 | AD-09, DR-07 embed |
| RPT-MK-001 | Campaign ROI | campaign_id, date | Marketing | MK-09 |
| RPT-MK-002 | Cost Per Lead | channel, date | Marketing, Director 👁 | MK-08, DR-06 embed |
| RPT-MK-003 | Referral Performance | date | Marketing | MK-10 |
| RPT-MK-004 | Social Engagement | platform, date | Marketing | MK-05 |

**AR-010 rule:** MG-06, MK-08, DR-07 show KPI strip + deep link to AD-09 — not duplicate funnel charts.

---

## 7. Academic Reports

| ID | Name | Parameters | Roles | Launcher |
|----|------|------------|-------|----------|
| RPT-AC-001 | Class Attendance Summary | class, date_range | Principal | AC-06, PR-02 |
| RPT-AC-002 | Exam Results Analysis | exam_id, class | Principal | AC-02, PR-08 |
| RPT-AC-003 | Report Card Batch | term, class | Principal | AC-05 |
| RPT-AC-004 | Homework Completion | class, date_range | Teacher, Principal | AC-01 |
| RPT-AC-005 | Weak Subject Analysis | exam_id | Principal | AC-02, PR-16 |

---

## 8. HR Reports

| ID | Name | Parameters | Roles | Launcher |
|----|------|------------|-------|----------|
| RPT-HR-001 | Headcount | department, date | HR, Management | HR-08 |
| RPT-HR-002 | Staff Attendance Summary | date_range | HR, Principal 👁 | HR-04 |
| RPT-HR-003 | Leave Balance | department | HR | HR-05 |
| RPT-HR-004 | Recruitment Funnel | date_range | HR | HR-03 |
| RPT-HR-005 | Performance Distribution | cycle | HR | HR-06 |
| RPT-HR-006 | Turnover Analysis | FY | HR, Management | HR-08 |

---

## 9. Operations Reports

| ID | Name | Parameters | Roles | Launcher |
|----|------|------------|-------|----------|
| RPT-HO-001 | Hostel Occupancy | block, date | Warden, Management 👁 | HO-09 |
| RPT-HO-002 | Hostel Attendance | session, date | Warden | HO-04, HO-09 |
| RPT-HO-003 | Visitor Log | date_range | Warden | HO-05 |
| RPT-HO-004 | Mess Cost | month | Warden, Finance 👁 | HO-07 |
| RPT-TR-001 | Route Utilization | route_id | Transport coord | TR-09 |
| RPT-TR-002 | GPS Trip Log | vehicle, date | Transport coord | TR-08 |
| RPT-SIS-001 | Enrollment by Class | academic_year | Admin, Principal | SIS-08 |
| RPT-SIS-002 | Transfer/Exit Log | date_range | Admin, Management | SIS-08 |
| RPT-LB-001 | Available Books | category | Library Staff | LB-07 |
| RPT-LB-002 | Overdue Books | date | Library Staff | LB-07 |
| RPT-LB-003 | Popular Titles | term | Library Staff | LB-07 |
| RPT-INV-001 | Asset Register | category | Inventory Manager | INV-07 |
| RPT-INV-002 | Maintenance Cost | date_range | Inventory Manager | INV-07 |
| RPT-INV-003 | Depreciation Schedule | FY | Inventory Manager, Finance 👁 | INV-07 |
| RPT-AL-001 | Alumni Engagement | quarter | Management, Marketing | AL-09 |
| RPT-AL-002 | Donations Summary | FY | Finance, Management | AL-05 |

---

## 10. Director Portfolio Reports

| ID | Name | Parameters | Roles | Launcher |
|----|------|------------|-------|----------|
| RPT-DR-001 | Portfolio Revenue | FY, schools[] | Director | DR-04, DR-09 |
| RPT-DR-002 | School Comparison | metric, FY | Director | DR-03 |
| RPT-DR-003 | Growth by School | FY | Director | DR-05 |
| RPT-DR-004 | Marketing ROI Portfolio | FY | Director | DR-06 |
| RPT-DR-005 | Admissions Yield Portfolio | FY | Director | DR-07 |
| RPT-DR-006 | Compliance Dashboard | FY | Director | DR-08 |
| RPT-DR-007 | Board Pack Multi-School | FY, quarter | Director | DR-09 |

**Privacy:** All DR reports — aggregated only, no student names (SRS Part 5 §3).

---

## 10b. Platform Reports (Akshara Control Center)

| ID | Name | Parameters | Roles | Launcher |
|----|------|------------|-------|----------|
| RPT-ACC-001 | Platform MRR/ARR | month | Akshara Director | ACC-05 |
| RPT-ACC-002 | School Health Scores | — | Akshara CS | ACC-07 |
| RPT-ACC-003 | Churn Risk Schools | — | Akshara Director | ACC-07 |
| RPT-ACC-004 | Sales Pipeline | quarter | Akshara Sales | ACC-06 |
| RPT-ACC-005 | Support SLA | month | Akshara Support | ACC-08 |

---

## 11. Module Launcher Mapping

| Module screen | Catalog IDs exposed | Pattern |
|---------------|---------------------|---------|
| FN-11 Financial Reports | RPT-FN-001 – RPT-FN-010 | Full finance catalog |
| MG-08 Reports Center | RPT-MG-001 – RPT-MG-006 + links to FN/AD | Executive launcher |
| DR-09 Strategic Reports | RPT-DR-001 – RPT-DR-007 | Portfolio launcher |
| MK-09 Marketing Reports | RPT-MK-001 – RPT-MK-004 | Marketing launcher |
| HR-08 HR Reports | RPT-HR-001 – RPT-HR-006 | HR launcher |
| HO-09 Hostel Reports | RPT-HO-001 – RPT-HO-004 | Operations launcher |
| TR-09 Transport Reports | RPT-TR-001 – RPT-TR-002 | Operations launcher |
| AC-08 Academic Reports | RPT-AC-001 – RPT-AC-005 | Academic launcher |
| SIS-08 SIS Reports | RPT-SIS-001 – RPT-SIS-002 | SIS launcher |
| AD-09 Admission Analytics | RPT-AD-001 – RPT-AD-004 | **Canonical admissions analytics** |
| LB-07 Library Reports | RPT-LB-001 – RPT-LB-003 | Library launcher |
| INV-07 Inventory Reports | RPT-INV-001 – RPT-INV-003 | Inventory launcher |
| AL-09 Alumni Reports | RPT-AL-001 – RPT-AL-002 | Alumni launcher |
| ACC-05/07/09 | RPT-ACC-001 – RPT-ACC-005 | Platform launcher |

---

## 12. Shared Report UI Pattern

**Component:** `Report/CatalogLauncher` (DesignSystem)

| Element | Spec |
|---------|------|
| Report card | `272×120` — title · description · last run |
| Parameter drawer | `400px` right — dynamic fields per catalog ID |
| Preview | PDF iframe or table preview |
| Actions | Generate · Schedule · Export · Email |

**Scheduling:** MG-D-05 `ScheduleReport` references catalog ID + cron.

---

## 13. Build Checklist

| Step | Task |
|------|------|
| 1 | Implement `generate-report` Edge Function with catalog registry |
| 2 | Wire FN-11 to RPT-FN-* |
| 3 | Refactor MG-08, DR-09 as launchers (remove duplicate chart specs) |
| 4 | AD-09 as admissions analytics source — embed in MG-06, MK-08, DR-07 |
| 5 | Audit log on every export |
| 6 | Director PII guard on all RPT-DR-* |
| 7 | Document catalog IDs in each module spec §Reports |

---

**End of Enterprise Report Catalog v1.0**
