# Akshara ERP — Library Module Specification (Consolidated)

**Document ID:** `AKS-LB-SPEC-v1.0`  
**Module:** Library Management  
**Screens:** LB-01 → LB-08  
**Platform:** Web primary (`1440×1024`) · Tablet · Mobile companion (`390×844`)  
**Source:** SRS Part 3 §13 · Part 6 §17 · DesignSystem.md · StudentSIS.md

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [User Roles & Permissions](#2-user-roles--permissions)
3. [Navigation & Information Architecture](#3-navigation--information-architecture)
4. [Screen Specifications](#4-screen-specifications)
5. [Mobile Screen Inventory](#5-mobile-screen-inventory)
6. [Dialogs & Wizards](#6-dialogs--wizards)
7. [Cross-Module Links](#7-cross-module-links)
8. [Figma Organization](#8-figma-organization)
9. [Build Checklist](#9-build-checklist)

---

## 1. Module Overview

### Purpose

School library operations: book catalog, issue/return, fines, digital resources, and utilization reports (SRS Part 3 §13).

### Screen Inventory

| ID | Screen | Primary Users | Priority |
|----|--------|---------------|----------|
| LB-01 | Library Dashboard | Library Staff | P1 |
| LB-02 | Book Catalog | Library Staff | P1 |
| LB-03 | Issue & Return | Library Staff | P1 |
| LB-04 | Members | Library Staff | P1 |
| LB-05 | Fines & Payments | Library Staff, Finance 👁 | P2 |
| LB-06 | Digital Resources | Library Staff, Student 👁 | P2 |
| LB-07 | Library Reports | Library Staff, Principal 👁 | P2 |
| LB-08 | Library Settings | Library Staff | P2 |

**Total frames:** 8 primary + 5 dialogs = **13**

---

## 2. User Roles & Permissions

| Action | Library Staff | Student | Teacher | Principal |
|--------|---------------|---------|---------|-----------|
| Manage catalog | ✅ | ❌ | ❌ | 👁 |
| Issue/return | ✅ | ❌ | ❌ | ❌ |
| View own loans | ❌ | ✅ app | ✅ | ❌ |
| Pay fines | ❌ | 👁 parent pays | ❌ | ❌ |
| Digital resources | ✅ upload | ✅ read | ✅ read | 👁 |
| Reports | ✅ | ❌ | ❌ | 👁 |

---

## 3. Navigation & Information Architecture

| # | Label | Icon | Screen |
|---|-------|------|--------|
| 1 | Dashboard | `dashboard` | LB-01 |
| 2 | Catalog | `menu_book` | LB-02 |
| 3 | Issue/Return | `swap_horiz` | LB-03 |
| 4 | Members | `groups` | LB-04 |
| 5 | Fines | `payments` | LB-05 |
| 6 | Digital | `cloud_download` | LB-06 |
| 7 | Reports | `assessment` | LB-07 |
| 8 | Settings | `settings` | LB-08 |

---

## 4. Screen Specifications

### LB-01 Dashboard

KPIs: Total books · Issued today · Overdue · Fines MTD · Popular title  
Charts: Issue trend · Category distribution  
Quick actions: Scan issue · Add book · Overdue list

### LB-02 Book Catalog

Table: ISBN · Title · Author · Category · Copies · Available · Shelf · Actions  
Bulk import CSV · barcode scan add

### LB-03 Issue & Return

Split: Member search `400` · Active loans + scan ISBN workflow  
Issue: due date auto · max books rule · confirm  
Return: condition note · fine calc if overdue

### LB-04 Members

Students + staff · active loans count · membership status · block if fines > limit

### LB-05 Fines

Overdue fine table · waive (audited) · link Finance FN-02 optional fee head `library_fine`

### LB-06 Digital Resources

E-books · PDFs · links · class-level access rules

### LB-07 Reports

Reports.md: **RPT-LB-001** Available · **RPT-LB-002** Overdue · **RPT-LB-003** Popular

### LB-08 Settings

Max books per student · loan period · fine per day · categories · holidays

---

## 5. Mobile Screen Inventory

| ID | Screen | User | Notes |
|----|--------|------|-------|
| LB-M-01 | Quick Issue | Library staff | Barcode scan · member QR |
| LB-M-02 | Quick Return | Library staff | Scan book barcode |
| LB-M-03 | My Books | Student | Loan list · due dates |
| LB-M-04 | Digital Reader | Student | In-app PDF viewer |

---

## 6. Dialogs & Wizards

| ID | Name | Used on |
|----|------|---------|
| LB-D-01 | AddBook | LB-02 |
| LB-D-02 | IssueConfirm | LB-03 |
| LB-D-03 | ReturnConfirm | LB-03 |
| LB-D-04 | WaiveFine | LB-05 |
| LB-D-05 | ImportCatalog | LB-02 |

---

## 7. Cross-Module Links

| From | To |
|------|-----|
| LB-04 | StudentSIS SIS-02 | Student lookup |
| LB-05 fines | Finance FN-02 | Optional fee collection |
| LB-03 overdue | Notifications.md | Reminder to student/parent |
| LB-07 | Reports.md | RPT-LB-* |
| Issue/return | Audit.md | `library.issue`, `library.return` |

---

## 8. Figma Organization

```
📁 11 — Library Management
├── LB-01 → LB-08 [D/T/M]
└── Dialogs LB-D-01 → LB-D-05
```

---

## 9. Build Checklist

| Step | Task |
|------|------|
| 1 | LB-02 catalog + LB-D-01 |
| 2 | LB-03 issue/return flow |
| 3 | LB-M-01/M-02 mobile scanner |
| 4 | LB-01 dashboard |
| 5 | LB-05 fines + Finance link |
| 6 | LB-06 digital · LB-07 reports |

---

**End of Library Module Specification v1.0**
