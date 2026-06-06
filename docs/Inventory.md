# Akshara ERP — Inventory Module Specification (Consolidated)

**Document ID:** `AKS-INV-SPEC-v1.0`  
**Module:** Inventory & Asset Management  
**Screens:** INV-01 → INV-08  
**Platform:** Web primary · Tablet · Mobile companion  
**Source:** SRS Part 3 §14, §17–18 · Part 6 §18 · DesignSystem.md · Finance.md

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

Track school assets: furniture, IT equipment, lab gear, sports equipment — with allocation, maintenance, procurement, and audit trail (SRS Part 3 §14, §17–18).

### Screen Inventory

| ID | Screen | Primary Users | Priority |
|----|--------|---------------|----------|
| INV-01 | Inventory Dashboard | Inventory Manager | P1 |
| INV-02 | Asset Registry | Inventory Manager | P1 |
| INV-03 | Asset Allocation | Inventory Manager | P1 |
| INV-04 | Maintenance Log | Inventory Manager | P1 |
| INV-05 | Purchase Requests | Inventory Manager, Management 🔒 | P2 |
| INV-06 | Stock & Consumables | Inventory Manager | P2 |
| INV-07 | Inventory Reports | Inventory Manager, Management 👁 | P2 |
| INV-08 | Inventory Settings | Inventory Manager | P2 |

**Total frames:** 8 primary + 6 dialogs = **14**

### Asset Categories

Furniture · Computers · Lab Equipment · Projectors · Sports · Vehicles (link Transport) · Hostel assets (link Hostel)

---

## 2. User Roles & Permissions

| Action | Inventory Manager | Management | Finance | Teacher |
|--------|-------------------|------------|---------|---------|
| Register assets | ✅ | 👁 | ❌ | ❌ |
| Allocate to room/person | ✅ | ❌ | ❌ | ❌ |
| Log maintenance | ✅ | 👁 | ❌ | ❌ |
| Submit purchase request | ✅ | 🔒 approve | 👁 | ❌ |
| View assigned assets | 👁 | 👁 | ❌ | ✅ own |
| Write-off asset | ✅ | 🔒 approve | ❌ | ❌ |

---

## 3. Navigation & Information Architecture

| # | Label | Screen |
|---|-------|--------|
| 1 | Dashboard | INV-01 |
| 2 | Assets | INV-02 |
| 3 | Allocation | INV-03 |
| 4 | Maintenance | INV-04 |
| 5 | Procurement | INV-05 |
| 6 | Consumables | INV-06 |
| 7 | Reports | INV-07 |
| 8 | Settings | INV-08 |

---

## 4. Screen Specifications

### INV-01 Dashboard

KPIs: Total assets · In maintenance · Unallocated · PR pending · Value depreciated  
Charts: Assets by category · Maintenance cost MTD

### INV-02 Asset Registry

Table: Asset ID · Name · Category · Serial · Location · Custodian · Status · Purchase date · Value · Actions  
Status: Active · Maintenance · Retired · Lost

### INV-03 Allocation

Floor/room map optional · assign asset to classroom/lab/teacher · transfer history

### INV-04 Maintenance Log

Scheduled · in-progress · completed · vendor · cost · link FN-07 vendor payment

### INV-05 Purchase Requests

Workflow: Request → Management MG-03 (future tab) or MG approve → PO → Finance  
Table: Item · qty · estimate · requester · status · approver

### INV-06 Consumables

Stock levels · reorder threshold · issue to department

### INV-07 Reports

Reports.md: **RPT-INV-001** Asset register · **RPT-INV-002** Maintenance cost · **RPT-INV-003** Depreciation

### INV-08 Settings

Categories · depreciation rules · approval thresholds · locations

---

## 5. Mobile Screen Inventory

| ID | Screen | User | Notes |
|----|--------|------|-------|
| INV-M-01 | Asset Scan | Inventory staff | QR on asset tag · view detail |
| INV-M-02 | Quick Maintenance | Inventory staff | Photo + note log |
| INV-M-03 | My Assigned Assets | Teacher | Read-only list |

---

## 6. Dialogs & Wizards

| ID | Name | Used on |
|----|------|---------|
| INV-D-01 | AddAsset | INV-02 |
| INV-D-02 | AllocateAsset | INV-03 |
| INV-D-03 | MaintenanceEntry | INV-04 |
| INV-D-04 | PurchaseRequest | INV-05 |
| INV-D-05 | WriteOff | INV-02 |
| INV-D-06 | StockAdjust | INV-06 |

---

## 7. Cross-Module Links

| From | To |
|------|-----|
| INV-05 approve | Management MG-03 | Procurement approval |
| INV-04 cost | Finance FN-07 | Vendor payments |
| INV-02 write-off | Audit.md | `inventory.writeoff` critical |
| INV-07 | Reports.md | RPT-INV-* |
| Hostel/Transport assets | HO-02 / TR-03 | Cross-reference only |

---

## 8. Figma Organization

```
📁 12 — Inventory Management
├── INV-01 → INV-08 [D/T/M]
└── Dialogs INV-D-01 → INV-D-06
```

---

## 9. Build Checklist

| Step | Task |
|------|------|
| 1 | INV-02 registry + asset QR |
| 2 | INV-03 allocation |
| 3 | INV-04 maintenance |
| 4 | INV-M-01 mobile scan |
| 5 | INV-05 procurement workflow |
| 6 | INV-01 dashboard + reports |

---

**End of Inventory Module Specification v1.0**
