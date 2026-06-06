# Akshara ERP — Platform Control Center Specification (Consolidated)

**Document ID:** `AKS-ACC-SPEC-v1.0`  
**Module:** Akshara Company Dashboard (Platform Admin)  
**Screens:** ACC-01 → ACC-12  
**Platform:** Web desktop (`1440×1024` · `1920×1080`)  
**Source:** SRS Part 4 §11–17 · Part 6 §1–5 · Part 5 §3 · Director.md (differentiated)

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Persona Differentiation](#2-persona-differentiation)
3. [User Roles & Permissions](#3-user-roles--permissions)
4. [Navigation & Information Architecture](#4-navigation--information-architecture)
5. [Screen Specifications](#5-screen-specifications)
6. [AI Business Copilot](#6-ai-business-copilot)
7. [Dialogs & Wizards](#7-dialogs--wizards)
8. [Cross-Module Links](#8-cross-module-links)
9. [Security & Privacy](#9-security--privacy)
10. [Figma Organization](#10-figma-organization)
11. [Build Checklist](#11-build-checklist)

---

## 1. Module Overview

### Purpose

**Akshara platform operations** for Super Admin, Akshara Director, Sales, Marketing, and Support teams — manage schools, subscriptions, revenue, sales CRM, customer success, support tickets, and white label (SRS Part 4 §11–17).

> **Not School Director:** Chain school oversight is **Director.md (DR-*)** — school-level aggregates with drill to Management. This module is **platform-level** with **zero school PII**.

### Screen Inventory

| ID | Screen | Primary Users | Priority |
|----|--------|---------------|----------|
| ACC-01 | Platform Dashboard | Akshara Director, Super Admin | P1 |
| ACC-02 | Schools Registry | Super Admin | P1 |
| ACC-03 | School Onboarding Wizard | Super Admin, Sales | P1 |
| ACC-04 | Subscriptions & Plans | Super Admin | P1 |
| ACC-05 | Platform Revenue | Akshara Director | P1 |
| ACC-06 | Sales CRM | Akshara Sales | P1 |
| ACC-07 | Customer Success | Akshara Support / CS | P1 |
| ACC-08 | Support Tickets | Akshara Support | P1 |
| ACC-09 | Platform Analytics | Akshara Director, Marketing | P1 |
| ACC-10 | White Label Manager | Super Admin | P2 |
| ACC-11 | System Logs | Super Admin | P2 |
| ACC-12 | Platform Settings | Super Admin | P2 |

**Total frames:** 12 primary + 8 dialogs = **20**

---

## 2. Persona Differentiation

| Persona | Module | Data scope | PII |
|---------|--------|------------|-----|
| **School Director** | Director.md DR-* | Own organization schools | ❌ aggregates only |
| **Akshara Director** | ACC-01, ACC-05, ACC-09 | All platform schools | ❌ no student/parent names |
| **Super Admin** | Full ACC-* | Platform config | ❌ operational only |
| **School Management** | Management.md | Single school | ✅ school PII |

### Mandatory Banner (All ACC Screens)

`1136×40` error-container: **"Platform view · No school student or parent PII · Aggregates only"**

---

## 3. User Roles & Permissions

| Action | Super Admin | Akshara Director | Sales | Support | Marketing |
|--------|-------------|------------------|-------|---------|-----------|
| Create/delete school | ✅ | ❌ | ❌ | ❌ | ❌ |
| View school PII | ❌ | ❌ | ❌ | 🔒 with approval | ❌ |
| Manage subscriptions | ✅ | 👁 | ❌ | ❌ | ❌ |
| Platform revenue | ✅ | ✅ | 👁 | ❌ | ❌ |
| Sales pipeline | 👁 | 👁 | ✅ | ❌ | ❌ |
| Support tickets | 👁 | 👁 | ❌ | ✅ | ❌ |
| White label | ✅ | 👁 | ❌ | ❌ | ❌ |
| Platform analytics | ✅ | ✅ | 👁 | 👁 | ✅ |

Support school data access requires **ticket-linked approval** with audit (SRS Part 6 §5).

---

## 4. Navigation & Information Architecture

### Side Navigation

| # | Label | Screen |
|---|-------|--------|
| 1 | Dashboard | ACC-01 |
| 2 | Schools | ACC-02 |
| 3 | Subscriptions | ACC-04 |
| 4 | Revenue | ACC-05 |
| 5 | Sales CRM | ACC-06 |
| 6 | Customer Success | ACC-07 |
| 7 | Support | ACC-08 |
| 8 | Analytics | ACC-09 |
| 9 | White Label | ACC-10 |
| 10 | System Logs | ACC-11 |
| 11 | Settings | ACC-12 |

---

## 5. Screen Specifications

### ACC-01 Platform Dashboard

KPIs: Total schools · Active · Trial · Expiring 30d · MRR · ARR · Churn risk count  
Charts: School growth · Revenue trend · Plan distribution  
AI brief: schools expiring · low adoption alerts

### ACC-02 Schools Registry

Table: School ID · Name · Plan · Students count · Status · Created · MRR · Health score · Actions  
Actions: View metrics · Impersonate admin (audited) · Suspend · Upgrade plan

### ACC-03 School Onboarding Wizard

Steps: School info · plan · branch setup · white label · admin user invite · Supabase tenant · go-live checklist

### ACC-04 Subscriptions & Plans

Plans: Standard · Premium · Enterprise (dedicated DB per Part 5 §5)  
Billing · renewals · invoices · upgrade/downgrade

### ACC-05 Platform Revenue

MRR/ARR · by plan · by region · churn · expansion revenue · no per-student fee detail

### ACC-06 Sales CRM

Pipeline: Lead → Contacted → Demo → Proposal → Negotiation → Won (SRS Part 4 §12)  
**Distinct from school Admissions AD-*** — these are **school-as-customer** leads.

### ACC-07 Customer Success

Per-school: feature usage heatmap · adoption score · renewal probability · AI churn risk  
Low usage alerts → assign CS owner

### ACC-08 Support Tickets

Statuses: Open · In Progress · Resolved · Closed  
SLA timers · school link · optional approved data access scope

### ACC-09 Platform Analytics

School growth · student growth (counts only) · revenue · marketing performance cross-school

### ACC-10 White Label Manager

Per school: logo · primary color · custom domain · login background (TechnicalArchitecture.md §13.6)

### ACC-11 System Logs

Platform errors · deployment · feature flags · not school audit (school audit → FN-10 / Audit.md)

### ACC-12 Platform Settings

Feature flags · API rate limits · maintenance mode · email templates

---

## 6. AI Business Copilot

**Panel:** `AI/PlatformCopilot` — dock on ACC-01, ACC-07, ACC-09

### Scope

Platform aggregates only — never query individual student names.

### Example Prompts

| Prompt | Output |
|--------|--------|
| "Schools expiring next month" | List school names + plan + renewal date |
| "Top 5 low-adoption schools" | CS score + suggested actions |
| "MRR trend last 12 months" | Chart + narrative |
| "Which campaigns drove most school signups" | Sales + marketing attribution |
| "Churn risk summary" | AI-scored schools |

### Actions

Schedule CS call · Send renewal reminder · Open ACC-06 deal · Export summary

---

## 7. Dialogs & Wizards

| ID | Name | Used on |
|----|------|---------|
| ACC-D-01 | CreateSchool | ACC-02 |
| ACC-D-02 | OnboardWizard | ACC-03 |
| ACC-D-03 | PlanChange | ACC-04 |
| ACC-D-04 | ImpersonateAdmin | ACC-02 (audited critical) |
| ACC-D-05 | SupportDataAccess | ACC-08 |
| ACC-D-06 | ChurnIntervention | ACC-07 |
| ACC-D-07 | WhiteLabelPreview | ACC-10 |
| ACC-D-08 | MaintenanceMode | ACC-12 |

---

## 8. Cross-Module Links

| From | To |
|------|-----|
| ACC-02 drill | Director DR-02 | Same org — `school_context_id` param |
| ACC-02 drill | Management MG-01 | Impersonation / scoped login |
| School metrics | Reports.md | RPT-ACC-* (platform reports) |
| ACC-06 won | ACC-03 | Onboard new school |
| All actions | Audit.md | `platform.*` events |
| White label | DesignSystem.md §20 | Theme tokens |
| Notifications | NT internal | CS/Sales team alerts |

---

## 9. Security & Privacy

| Rule | Implementation |
|------|----------------|
| No student PII | API returns counts and aggregates only |
| Support access | ACC-D-05 approval + time-limited scope + audit |
| Impersonation | Super Admin only · banner visible to school user · full audit |
| Dedicated DB tier | ACC-04 Enterprise → separate Supabase URL at login |
| Akshara employees | SRS Part 5 §3 — platform metrics visible, school private data not |

---

## 10. Figma Organization

```
📁 00 — Akshara Platform / Control Center
├── ACC-01 → ACC-12 [D]
├── Dialogs ACC-D-01 → ACC-D-08
└── Prototype: Onboard school · CS churn flow
```

**Frame naming:** `ACC-{##}-{ScreenName}-D`

---

## 11. Build Checklist

| Step | Task |
|------|------|
| 1 | ACC-01 dashboard + privacy banner |
| 2 | ACC-02 schools + ACC-D-01 |
| 3 | ACC-03 onboarding wizard |
| 4 | ACC-04 subscriptions |
| 5 | ACC-06 sales CRM pipeline |
| 6 | ACC-07 CS + churn AI |
| 7 | ACC-08 support tickets |
| 8 | ACC-10 white label |
| 9 | AI copilot prompts |
| 10 | Audit + impersonation safeguards |

---

**End of Akshara Control Center Specification v1.0**
