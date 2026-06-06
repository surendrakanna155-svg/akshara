# Akshara ERP — Alumni Module Specification (Consolidated)

**Document ID:** `AKS-AL-SPEC-v1.0`  
**Module:** Alumni Portal  
**Screens:** AL-01 → AL-10 · Mobile AL-M-01 → AL-M-08  
**Platform:** Web admin · Alumni mobile app (`390×844`)  
**Source:** SRS Part 4 §8 · Part 6 · Marketing MK-10 · StudentSIS SIS-05

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [User Roles & Permissions](#2-user-roles--permissions)
3. [Navigation — Admin Portal](#3-navigation--admin-portal)
4. [Admin Screen Specifications](#4-admin-screen-specifications)
5. [Alumni Mobile App](#5-alumni-mobile-app)
6. [Dialogs & Wizards](#6-dialogs--wizards)
7. [Cross-Module Links](#7-cross-module-links)
8. [Figma Organization](#8-figma-organization)
9. [Build Checklist](#9-build-checklist)

---

## 1. Module Overview

### Purpose

Engage graduated students: profiles, success stories, events, networking, donations — with admin management and dedicated alumni mobile app (SRS Part 4 §8).

### Lifecycle Entry

Student **exit** in StudentSIS SIS-05 with reason `Completed` → optional convert to **Alumni** record · retain academic history · revoke student app access · grant alumni app access.

### Screen Inventory — Admin (Web)

| ID | Screen | Primary Users | Priority |
|----|--------|---------------|----------|
| AL-01 | Alumni Dashboard | School Management, Marketing | P2 |
| AL-02 | Alumni Registry | Admin | P2 |
| AL-03 | Profile Management | Admin | P2 |
| AL-04 | Events | Admin, Alumni 👁 | P2 |
| AL-05 | Donations | Admin, Finance 👁 | P2 |
| AL-06 | Success Stories | Admin, Marketing | P2 |
| AL-07 | Engagement Analytics | Management, Marketing | P2 |
| AL-08 | Referral Tracking | Marketing | P2 |
| AL-09 | Alumni Reports | Management | P3 |
| AL-10 | Alumni Settings | Admin | P3 |

### Screen Inventory — Alumni Mobile

| ID | Screen | Priority |
|----|--------|----------|
| AL-M-01 | Splash / Login | P2 |
| AL-M-02 | Alumni Dashboard | P2 |
| AL-M-03 | My Profile | P2 |
| AL-M-04 | Events | P2 |
| AL-M-05 | Donate | P2 |
| AL-M-06 | Success Stories | P3 |
| AL-M-07 | Network / Directory | P3 |
| AL-M-08 | Notifications | P2 |

---

## 2. User Roles & Permissions

| Action | Alumni (self) | Admin | Marketing | Finance |
|--------|---------------|-------|-----------|---------|
| View directory | ✅ opted-in | ✅ | 👁 | ❌ |
| Edit own profile | ✅ | ❌ | ❌ | ❌ |
| RSVP events | ✅ | ✅ manage | 👁 | ❌ |
| Donate | ✅ | 👁 | ❌ | 👁 reconcile |
| Submit success story | ✅ | 🔒 publish | ✅ | ❌ |
| Refer admission | ✅ | 👁 | ✅ MK-10 | ❌ |
| View donation amounts (others) | ❌ | ✅ | ❌ | ✅ |

**Privacy:** Directory shows batch, year, industry — phone/email only if member opts in.

---

## 3. Navigation — Admin Portal

| # | Label | Screen |
|---|-------|--------|
| 1 | Dashboard | AL-01 |
| 2 | Registry | AL-02 |
| 3 | Events | AL-04 |
| 4 | Donations | AL-05 |
| 5 | Stories | AL-06 |
| 6 | Analytics | AL-07 |
| 7 | Referrals | AL-08 |
| 8 | Reports | AL-09 |

---

## 4. Admin Screen Specifications

### AL-01 Dashboard

KPIs: Total alumni · Active members · Events this quarter · Donations YTD · Referrals converted  
Engagement chart · top stories carousel

### AL-02 Registry

Table: Name · Batch · Year · Industry · City · Status · Last active · Referrals · Actions  
Import from SIS exit batch · manual add

### AL-04 Events

Create reunion · webinar · fundraiser · RSVP tracking · notify alumni (Notifications.md)

### AL-05 Donations

Campaigns · Razorpay donations · receipt · Finance reconciliation FN-04 income category `donation`

### AL-06 Success Stories

Moderation queue · publish to website sync (SRS Part 4 §5) · alumni mobile feed

### AL-07 Engagement

DAU/MAU · event attendance · donation funnel · chapter activity

### AL-08 Referral Tracking

Links to Marketing MK-10 · attribution when referral converts to admission

---

## 5. Alumni Mobile App

**Shell:** `Shell/AlumniMobileLayout` — bottom nav: Home · Events · Donate · Network · More

### AL-M-02 Dashboard

Welcome · upcoming events · school news · donate CTA · referral share link

### AL-M-05 Donate

Amount · campaign · Razorpay · receipt · 80G certificate optional

### AL-M-07 Network

Search by batch/year/industry · connect request (P3) · no student data access

---

## 6. Dialogs & Wizards

| ID | Name | Used on |
|----|------|---------|
| AL-D-01 | ConvertToAlumni | SIS-05 exit |
| AL-D-02 | CreateEvent | AL-04 |
| AL-D-03 | PublishStory | AL-06 |
| AL-D-04 | DonationReceipt | AL-05 |
| AL-D-05 | ReferralShare | AL-M-02 |

---

## 7. Cross-Module Links

| From | To |
|------|-----|
| SIS-05 exit | AL-D-01 | Alumni creation |
| AL-08 | Marketing MK-10 | Referral program |
| AL-05 | Finance FN-04 | Donation income |
| AL-04 events | Notifications.md | Alumni audience |
| AL-06 publish | Marketing website sync | SRS Part 4 §5 |
| Donations | Audit.md | `alumni.donation` |

---

## 8. Figma Organization

```
📁 13 — Alumni Portal
├── Admin AL-01 → AL-10 [D/T]
├── Mobile AL-M-01 → AL-M-08 [M]
└── Dialogs AL-D-01 → AL-D-05
```

---

## 9. Build Checklist

| Step | Task |
|------|------|
| 1 | SIS-05 → AL-D-01 handoff |
| 2 | AL-02 registry |
| 3 | AL-M-02 mobile dashboard + login |
| 4 | AL-04 events + AL-M-04 |
| 5 | AL-05/M-05 donations + Finance |
| 6 | AL-06 stories · AL-07 analytics |
| 7 | MK-10 referral integration |

---

**End of Alumni Module Specification v1.0**
