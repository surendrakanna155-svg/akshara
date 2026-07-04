# Owner Dashboard Audit

**Version:** 1.0  
**Date:** June 2026  
**Scope:** School owner / principal / superAdmin dashboard surfaces  
**Personas:** `ErpRole.principal` (primary), `ErpRole.schoolAdmin`, `ErpRole.superAdmin`

There is no dedicated `schoolOwner` role. **Principal** lands on Management Dashboard (`/management/dashboard`). **Super Admin** lands on Admin Hub (`/admin`) plus Control Center.

---

## Executive Summary

| Metric | Value |
|--------|-------|
| **Dashboard completion %** | ~78% (surfaces exist, data loads) |
| **Functional completion %** | ~52% (actions work end-to-end) |
| **Mock dependency %** | ~85% (repository mock in pilot mode) |
| **Write-capable dashboard items** | 4 of ~120 inventoried actions |

**Classification key:**  
**A** Fully Functional · **B** Mock Only (reads work, mock data) · **C** Partial (navigate/read OK, write/stub gaps) · **D** Not Implemented (stub/no-op)

---

## Top Missing Dashboard Capabilities

1. **Export buttons** — Management, HR, Control Center, Transport, Hostel, Alumni dashboards use empty `onPressed: () {}`
2. **AI insight actions** — ~12 insight cards stubbed across Management + module dashboards
3. **Dashboard period filters** — Management FY/Q filters update UI state only (not repo query)
4. **Approval on dashboard** — Preview only; write happens on Tasks screen (recently completed)
5. **Global notifications inbox** — No owner notification center; alerts are inline banners only
6. **KPI drill-down** — All `*KpiRow` widgets are display-only (no tap → detail)
7. **Management settings save** — MG-08 save button stubbed
8. **Operations Hub actions** — Critical alerts / pending actions display-only
9. **Principal priority cards** — Today's priorities have `onTap: null`
10. **Finance executive export** — SnackBar queue only, not real PDF

---

## 1. Management Dashboard (MG-01) — Primary Owner Home

**Screen:** `lib/features/management/dashboard/management_dashboard_screen.dart`  
**Route:** `/management/dashboard`  
**Data:** `managementDashboardFutureProvider` → `ManagementRepository.getDashboard()`

| Item | Purpose | Data source | Status | Navigation | Write |
|------|---------|-------------|--------|------------|-------|
| FY/Q filter bar | Period filter | Local `managementDashboardFilterProvider` | **C** | N/A | No (not wired to repo) |
| Export button | Dashboard export | N/A | **D** | None | No |
| School health score | Composite health | Computed from KPIs in panel | **B** | None | No |
| Summary KPI strip | Fee/admissions snapshot | Dashboard data | **B** | None | No |
| Today's priorities | Approval + defaulter cards | Dashboard data | **C** | Cards non-tappable | No |
| Quick action: Attendance | Shortcut | Static routes | **A** | `/management/analytics` | No |
| Quick action: Fees | Shortcut | Static | **A** | `/management/finance` | No |
| Quick action: Risk | Shortcut | Static | **A** | `/management/intelligence` | No |
| Quick action: Approvals | Shortcut | Static | **A** | `/management/tasks` | No |
| Alert center banners | Fee/queue alerts | Dashboard data | **A** | `/management/tasks` | No |
| Fee defaulter warning | Threshold alert | Dashboard KPI | **A** | `/finance/defaulters` | No |
| Revenue KPI row | Executive KPIs | Dashboard | **B** | None | No |
| Revenue trend chart | 12-month trend | Dashboard | **B** | None | No |
| Expense breakdown | Segment chart | Dashboard | **B** | None | No |
| Approval queue preview | Top 5 pending | Dashboard | **C** | Row → source module | No (approve on Tasks) |
| Admissions snapshot | Funnel snapshot | Dashboard | **B** | None | No |
| Fee snapshot | Collection snapshot | Dashboard | **B** | None | No |
| AI insight card | Management summary | Dashboard | **A** | `/management/tasks` | No |

**MG-01 completion:** ~72% surface · ~58% functional

---

## 2. Management Sub-Screens (MG-02 → MG-08)

| Screen | KPIs | Charts | AI insight | Export | Write surfaces |
|--------|------|--------|------------|--------|----------------|
| MG-02 Analytics | B | B | **D** stub | — | None |
| MG-03 Admissions | B | B | **A** → reports | — | None |
| MG-04 Finance | B | B | **D** stub | — | None (read-only executive) |
| MG-05 Academics | B | B | **D** stub | — | None |
| MG-06 Performance | B | B | **D** stub | — | None |
| MG-07 Tasks | B | — | **D** stub | — | **A** Approve/Reject |
| MG-08 Settings | — | — | — | — | **D** save stub |

---

## 3. Management Intelligence Hub

**Screen:** `lib/features/management/intelligence/intelligence_hub_screen.dart`  
**Route:** `/management/intelligence`

| Tab | Content | Status | Write |
|-----|---------|--------|-------|
| Analytics | Risk + ops KPIs | **B** | No |
| School Health | Health score | **B** | No |
| Risk Center | Risk summaries | **B** | No |
| Trends | Time series | **B** | No |
| Principal Summary | Briefing text | **B** | No |

All tabs: retry invalidates reads. No KPI drill-down.

---

## 4. Control Center (Super Admin / Platform Owner)

**Screen:** `lib/features/control_center/dashboard/control_center_dashboard_screen.dart`  
**Route:** `/control-center/dashboard`

| Item | Status | Navigation | Write |
|------|--------|------------|-------|
| Export | **D** | None | No |
| Expiring schools banner | **A** | Subscriptions | No |
| Platform KPIs | **B** | None | No |
| Growth / MRR charts | **B** | None | No |
| ERP module adoption chips | **A** | Module routes | No |
| AI insight | **A** | Success metrics | No |

---

## 5. Cross-Cutting Owner Surfaces

| Surface | Route | Data | Functional % | Write |
|---------|-------|------|--------------|-------|
| Admin Hub placeholder | `/admin` | Static | **D** | No |
| Principal Command | `/principal-command` | Evolution repo | **A** query | NL query only |
| Akshara Intelligence | `/intelligence` | Intelligence repo | **C** | Generate if permitted |
| Operations Hub | `/operations/hub` | Operations repo | **B** | None |
| Dynamic Dashboard | `/dashboard/dynamic` | Evolution repo | **A** | Layout save |
| Pilot Toolkit | `/school/pilot` | School completion | **B** | None |
| Finance Executive | `/finance/executive` | Finance intelligence | **C** | Export snackbar only |
| AI Copilot | `/copilot` | Copilot repo | **A** | Send message |

---

## 6. Module Dashboards (Owner-Visible)

Pattern: repository dashboard provider + KPI row (display-only) + warning banner (often navigates) + AI insight (mixed).

| Module | Screen | Export | Banner nav | AI insight | Manage actions |
|--------|--------|--------|------------|------------|----------------|
| Admissions | AD-01 | — | — | **D** | — |
| Finance | FN-01 | — | **A** defaulters | **A** | View-only for Principal |
| SIS | SIS-01 | — | Conversion queue | **D** | — |
| HR | HR-01 | **D** | **A** leave/recruitment | **A** | Partial |
| Library | LB-01 | — | **A** overdue | **A** | Issue wired (P0 #2) |
| Inventory | INV-01 | SnackBar | **A** procurement | **A** | View-only Principal |
| Alumni | AL-01 | **D** | — | **A** | — |
| Transport | TR-01 | **D** | **A** tracking | **C** | Super Admin only |
| Hostel | HO-01 | **D** | **A** attendance | — | Assign wired (P0 #3) |

---

## 7. Notifications & Approval Queues

| Surface | Location | Status | Write |
|---------|----------|--------|-------|
| Global notification inbox | — | **D** Not implemented | — |
| Management approval preview | MG-01 dashboard | **C** Navigate only | On MG-07 |
| Management approval queue | MG-07 Tasks | **A** | Approve/Reject |
| Finance handoff queue | FN-01 | **C** Display | On finance screens |
| SIS conversion queue | SIS-01 | **C** Display | On SIS screens |
| Operations critical alerts | Operations Hub | **B** Display only | — |

---

## 8. Reports & Shortcuts

| Type | Examples | Status |
|------|----------|--------|
| Management drill links | MG-04 finance links | **A** navigate |
| Report catalog tiles | Per-module HO/LB/TR reports | **C** mostly read-only |
| Quick actions panel | MG-01 principal panel | **A** |
| Sub-nav tabs | All ERP modules | **A** |
| SIS/Finance deep links | Insight cards | **A** |

---

## Summary Metrics

| Category | Count (approx.) | A | B | C | D |
|----------|-----------------|---|---|---|---|
| KPI cards (all dashboards) | ~85 | 0 | 80 | 5 | 0 |
| Charts / segments | ~35 | 0 | 35 | 0 | 0 |
| Quick actions / shortcuts | ~18 | 14 | 0 | 2 | 2 |
| AI insight cards | ~22 | 8 | 0 | 2 | 12 |
| Export buttons | ~8 | 0 | 1 | 1 | 6 |
| Approval / write actions | ~6 | 4 | 0 | 2 | 0 |
| Filters | ~12 | 0 | 0 | 12 | 0 |
| Notifications | ~5 | 0 | 3 | 2 | 0 |

**Weighted dashboard completion:** ~78% (UI + data present)  
**Weighted functional completion:** ~52% (real actions + writes)  
**Mock dependency:** ~85% (pilot uses mock repositories)

---

## Recommendations

1. **P1:** Wire Management dashboard Export + period filters to repo query  
2. **P1:** Replace AI insight stubs with navigation targets already defined in copy  
3. **P1:** Add KPI tap → drill routes (fee KPI → finance dashboard, etc.)  
4. **P2:** Global notification center for owner personas  
5. **P2:** Enable approve/reject inline on MG-01 approval preview (or remove misleading preview)  
6. **P3:** Real PDF export pipeline shared across module dashboards  

---

## References

- `lib/features/management/dashboard/management_dashboard_screen.dart`
- `lib/features/management/widgets/management_principal_overview_panel.dart`
- `lib/features/control_center/dashboard/control_center_dashboard_screen.dart`
- `docs/ERP_FINAL_COMPLETION_PLAN.md`
