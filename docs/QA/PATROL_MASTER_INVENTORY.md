# Akshara Patrol Coverage Expansion — Master Inventory

**Branch:** `release/v1.0-preprod`  
**Date:** June 2026  
**Purpose:** Release-grade Patrol blueprint targeting **360 end-to-end suites** (300–400 range)  
**Status:** Planning & test design only — no Patrol code in this document

---

## Executive Summary

| Metric | Current | Target |
|--------|--------:|-------:|
| Patrol workflow files | ~93 | ~120 (grouped) |
| Atomic Patrol suites (`patrolTest`) | ~120 | **360** |
| Journey manifest entries | 79 | 360 (mapped) |
| Module route coverage | ~91% nav | **100% operational** |

### Pack Overview

| Pack | ID Range | Suites | Focus | Execution Wave |
|------|----------|-------:|-------|----------------|
| **Pack A** | AK-PT-001 → 100 | 100 | Daily school operations, auth, fees, mobile portals, security | **Wave 1 — Pack 1** |
| **Pack B** | AK-PT-101 → 200 | 100 | Academics, exams, attendance chains, teacher/principal, HR | **Wave 2 — Pack 2** |
| **Pack C** | AK-PT-201 → 300 | 100 | Vertical ERP (transport, hostel, inventory, library), comms, reports | **Wave 3 — Pack 3** |
| **Pack D** | AK-PT-301 → 360 | 60 | Multi-school SaaS, director, control center, platform, data integrity | **Wave 4 — Pack 4** |

### Criticality Legend

| Level | Meaning | Release gate |
|-------|---------|--------------|
| **P0** | School cannot operate without this; security/data-loss risk | Must pass before pre-prod sign-off |
| **P1** | Important operational workflow; workaround exists | Must pass before production |
| **P2** | Secondary, analytics, or platform-advanced | Post-release or nightly |

### Existing Coverage Key

| Symbol | Meaning |
|--------|---------|
| ✅ | Suite exists today (partial or full) |
| 🔶 | Partial — nav/smoke only; needs deep workflow |
| ⬜ | Net-new suite |

---

## Pack A — Core Operations & Mobile (AK-PT-001 → 100)

*Execution priority: **Pack 1** — highest operational risk*

### A1. Authentication & Session (001–012)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-001 | Auth | All | QA persona login — principal | P0 | ✅ |
| AK-PT-002 | Auth | All | QA persona login — teacher | P0 | ✅ |
| AK-PT-003 | Auth | All | QA persona login — parent | P0 | ✅ |
| AK-PT-004 | Auth | All | QA persona login — student | P0 | ✅ |
| AK-PT-005 | Auth | All | QA persona login — finance | P0 | ✅ |
| AK-PT-006 | Auth | All | QA persona login — super admin | P0 | ✅ |
| AK-PT-007 | Auth | All | Staff OTP login flow | P0 | 🔶 |
| AK-PT-008 | Auth | All | Logout clears session and returns to login | P0 | ✅ |
| AK-PT-009 | Auth | All | Session restore after app background/kill | P0 | ✅ |
| AK-PT-010 | Auth | All | Expired session redirects to login | P0 | ⬜ |
| AK-PT-011 | Auth | Super Admin | Role context persists across module navigation | P1 | 🔶 |
| AK-PT-012 | Auth | Super Admin | Tenant/school switch updates dashboard context | P0 | 🔶 |

### A2. Security & RBAC (013–028)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-013 | Security | Parent | Parent cannot access ERP admin routes | P0 | ✅ |
| AK-PT-014 | Security | Student | Student cannot access finance module | P0 | ✅ |
| AK-PT-015 | Security | Teacher | Teacher cannot access control center | P0 | ✅ |
| AK-PT-016 | Security | Finance | Finance cannot access HR payroll mutations | P0 | ⬜ |
| AK-PT-017 | Security | Principal | Principal denied super-admin-only routes | P0 | ✅ |
| AK-PT-018 | Security | All | Deep-link to protected route without auth → login | P0 | ⬜ |
| AK-PT-019 | Security | All | Unauthorized route shows access denied (not blank) | P0 | ✅ |
| AK-PT-020 | Security | Super Admin | RBAC inventory — admissions routes | P0 | ⬜ |
| AK-PT-021 | Security | Super Admin | RBAC inventory — finance routes | P0 | ⬜ |
| AK-PT-022 | Security | Super Admin | RBAC inventory — SIS routes | P0 | ⬜ |
| AK-PT-023 | Security | Super Admin | RBAC inventory — HR routes | P1 | ⬜ |
| AK-PT-024 | Security | Super Admin | RBAC inventory — transport routes | P1 | ⬜ |
| AK-PT-025 | Security | Super Admin | Mutation denied without manage permission | P0 | ⬜ |
| AK-PT-026 | Security | Super Admin | Audit event on denied access attempt | P1 | ⬜ |
| AK-PT-027 | Security | Parent | Parent operational flows — fees, PTM, transport | P0 | ✅ |
| AK-PT-028 | Security | Student | Student operational flows — progress, exams | P0 | ✅ |

### A3. Admissions — Intake to Enrollment (029–048)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-029 | Admissions | Admissions Counselor | Dashboard KPIs load | P0 | ✅ |
| AK-PT-030 | Admissions | Admissions Counselor | Create new lead | P0 | 🔶 |
| AK-PT-031 | Admissions | Admissions Counselor | Lead follow-up scheduling | P1 | ⬜ |
| AK-PT-032 | Admissions | Admissions Counselor | Convert lead to application | P0 | 🔶 |
| AK-PT-033 | Admissions | Admissions Counselor | Application form multi-step completion | P0 | ✅ |
| AK-PT-034 | Admissions | Admissions Counselor | Document upload checklist | P0 | 🔶 |
| AK-PT-035 | Admissions | Admissions Counselor | Document verification approve | P0 | 🔶 |
| AK-PT-036 | Admissions | Principal | Application approval workflow | P0 | 🔶 |
| AK-PT-037 | Admissions | Principal | Application rejection with reason | P1 | ⬜ |
| AK-PT-038 | Admissions | Admissions Counselor | Enrollment wizard — student step | P0 | ✅ |
| AK-PT-039 | Admissions | Admissions Counselor | Enrollment wizard — parent step | P0 | ✅ |
| AK-PT-040 | Admissions | Admissions Counselor | Enrollment wizard — class assignment | P0 | 🔶 |
| AK-PT-041 | Admissions | Admissions Counselor | Parent linking during enrollment | P0 | ⬜ |
| AK-PT-042 | Admissions | Finance | Fee handoff from admissions | P0 | ⬜ |
| AK-PT-043 | Admissions | Admissions Counselor | Full E2E journey — lead to enrolled | P0 | ✅ |
| AK-PT-044 | Admissions | Principal | Admissions reports filter and view | P1 | 🔶 |
| AK-PT-045 | Admissions | Super Admin | Admissions settings persistence | P1 | ✅ |
| AK-PT-046 | Admissions | Super Admin | Admissions export — leads CSV | P1 | ✅ |
| AK-PT-047 | Admissions | Super Admin | Admissions export — applications PDF | P1 | ✅ |
| AK-PT-048 | Admissions | Super Admin | Admissions filters — status, grade, date | P1 | ⬜ |

### A4. Fees & Finance — Collection Chain (049–068)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-049 | Finance | Finance Admin | Finance dashboard MTD collection | P0 | ✅ |
| AK-PT-050 | Finance | Finance Admin | Fee structure creation | P0 | 🔶 |
| AK-PT-051 | Finance | Finance Admin | Fee assignment to student | P0 | ✅ |
| AK-PT-052 | Finance | Finance Admin | Fee generation for term | P0 | 🔶 |
| AK-PT-053 | Finance | Finance Admin | Collect fee — cash | P0 | ✅ |
| AK-PT-054 | Finance | Finance Admin | Collect fee — offline cheque/DD | P0 | ✅ |
| AK-PT-055 | Finance | Finance Admin | QR payment initiation | P1 | ✅ |
| AK-PT-056 | Finance | Finance Admin | Receipt generation after collection | P0 | ✅ |
| AK-PT-057 | Finance | Finance Admin | Receipt verification | P0 | 🔶 |
| AK-PT-058 | Finance | Finance Admin | Defaulter list and drill-down | P0 | 🔶 |
| AK-PT-059 | Finance | Finance Admin | Discount application | P1 | ⬜ |
| AK-PT-060 | Finance | Finance Admin | Refund processing | P1 | 🔶 |
| AK-PT-061 | Finance | Finance Admin | Invoice management lifecycle | P1 | ✅ |
| AK-PT-062 | Finance | Finance Admin | Full finance journey — assign → collect → receipt | P0 | ✅ |
| AK-PT-063 | Finance | Finance Admin | Finance reports — collections summary | P1 | 🔶 |
| AK-PT-064 | Finance | Finance Admin | Finance export — collections PDF | P1 | ✅ |
| AK-PT-065 | Finance | Finance Admin | Finance filters — date, class, status | P1 | ✅ |
| AK-PT-066 | Finance | Finance Admin | Reconciliation view | P2 | ⬜ |
| AK-PT-067 | Finance | Finance Admin | Finance settings persistence | P1 | ⬜ |
| AK-PT-068 | Finance | Finance Admin | Executive finance dashboard | P2 | ⬜ |

### A5. Parent Portal — Daily Use (069–088)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-069 | Parent | Parent | Dashboard loads with child summary | P0 | ✅ |
| AK-PT-070 | Parent | Parent | Attendance detail view | P0 | ✅ |
| AK-PT-071 | Parent | Parent | Timetable view | P1 | ✅ |
| AK-PT-072 | Parent | Parent | Homework list and detail | P0 | ✅ |
| AK-PT-073 | Parent | Parent | Exam schedule view | P0 | ✅ |
| AK-PT-074 | Parent | Parent | Fees overview and due amounts | P0 | ✅ |
| AK-PT-075 | Parent | Parent | Pay fee flow | P0 | ✅ |
| AK-PT-076 | Parent | Parent | Receipt history | P0 | ✅ |
| AK-PT-077 | Parent | Parent | Receipt PDF open/download | P0 | ✅ |
| AK-PT-078 | Parent | Parent | Notices carousel and detail | P1 | ✅ |
| AK-PT-079 | Parent | Parent | Events calendar | P1 | ✅ |
| AK-PT-080 | Parent | Parent | PTM schedule and booking | P0 | 🔶 |
| AK-PT-081 | Parent | Parent | Transport route and stop visibility | P0 | 🔶 |
| AK-PT-082 | Parent | Parent | Messages — conversation list | P1 | 🔶 |
| AK-PT-083 | Parent | Parent | Messages — send reply | P1 | ⬜ |
| AK-PT-084 | Parent | Parent | Leave request submission | P1 | ⬜ |
| AK-PT-085 | Parent | Parent | Profile and child switcher | P1 | ✅ |
| AK-PT-086 | Parent | Parent | Notifications inbox | P1 | ⬜ |
| AK-PT-087 | Parent | Parent | Academic report view | P1 | ⬜ |
| AK-PT-088 | Parent | Parent | Red-team operational — all tabs reachable | P0 | ✅ |

### A6. Student Portal — Learner View (089–100)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-089 | Student | Student | Dashboard home | P0 | ✅ |
| AK-PT-090 | Student | Student | Attendance summary | P0 | ✅ |
| AK-PT-091 | Student | Student | Homework due list and submit | P0 | 🔶 |
| AK-PT-092 | Student | Student | Exam schedule | P0 | ✅ |
| AK-PT-093 | Student | Student | Report card view | P0 | 🔶 |
| AK-PT-094 | Student | Student | Progress dashboard | P0 | 🔶 |
| AK-PT-095 | Student | Student | Timetable day view | P1 | ✅ |
| AK-PT-096 | Student | Student | Notices feed | P1 | ✅ |
| AK-PT-097 | Student | Student | Profile view | P1 | ✅ |
| AK-PT-098 | Student | Student | Settings — preferences | P2 | ✅ |
| AK-PT-099 | Student | Student | Red-team operational — academics tab | P0 | ✅ |
| AK-PT-100 | Student | Student | Notifications deep link | P1 | ⬜ |

---

## Pack B — Academics, Staff & Management (AK-PT-101 → 200)

*Execution priority: **Pack 2***

### B1. Attendance (101–118)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-101 | Attendance | Teacher | Mark class attendance — present | P0 | ✅ |
| AK-PT-102 | Attendance | Teacher | Mark class attendance — absent/late | P0 | 🔶 |
| AK-PT-103 | Attendance | Teacher | Bulk mark all present | P0 | ⬜ |
| AK-PT-104 | Attendance | Teacher | Submit attendance sheet | P0 | ✅ |
| AK-PT-105 | Attendance | Teacher | Class teacher dashboard attendance shortcut | P0 | 🔶 |
| AK-PT-106 | Attendance | Principal | School-wide attendance review | P0 | ⬜ |
| AK-PT-107 | Attendance | Principal | Attendance correction approval | P1 | ⬜ |
| AK-PT-108 | Attendance | Super Admin | HR staff attendance view | P1 | 🔶 |
| AK-PT-109 | Attendance | Hostel Manager | Hostel attendance marking | P1 | 🔶 |
| AK-PT-110 | Attendance | Transport Manager | Transport attendance on route | P1 | ⬜ |
| AK-PT-111 | Attendance | Parent | Parent sees updated attendance same day | P0 | 🔶 |
| AK-PT-112 | Attendance | Student | Student sees attendance percentage | P0 | 🔶 |
| AK-PT-113 | Attendance | Teacher | Substitute teacher attendance handoff | P1 | ✅ |
| AK-PT-114 | Attendance | Super Admin | Attendance reports export | P1 | ⬜ |
| AK-PT-115 | Attendance | Principal | Low attendance alert on management dashboard | P1 | ⬜ |
| AK-PT-116 | Attendance | Teacher | Attendance for multiple sections same day | P1 | ⬜ |
| AK-PT-117 | Attendance | Super Admin | Attendance filter by class/date | P1 | ⬜ |
| AK-PT-118 | Attendance | Teacher | Offline attendance queue sync | P2 | ⬜ |

### B2. Academics — Subjects, Timetable, Homework (119–143)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-119 | Academics | Super Admin | Subjects management — create subject | P0 | ⬜ |
| AK-PT-120 | Academics | Super Admin | Subject assignment to class | P0 | 🔶 |
| AK-PT-121 | Academics | Super Admin | SIS academic assignment save | P0 | ⬜ |
| AK-PT-122 | Academics | Super Admin | Timetable hub — view weekly grid | P0 | 🔶 |
| AK-PT-123 | Academics | Super Admin | Timetable automation — generate draft | P1 | ⬜ |
| AK-PT-124 | Academics | Super Admin | Timetable optimization — apply suggestion | P1 | ✅ |
| AK-PT-125 | Academics | Super Admin | Substitute teacher assignment | P1 | ✅ |
| AK-PT-126 | Academics | Super Admin | Teacher reassignment workflow | P1 | ✅ |
| AK-PT-127 | Academics | Teacher | Teacher timetable view | P0 | ✅ |
| AK-PT-128 | Academics | Teacher | Homework create — assign to class | P0 | 🔶 |
| AK-PT-129 | Academics | Teacher | Homework review submissions queue | P0 | ✅ |
| AK-PT-130 | Academics | Teacher | Homework grade and feedback | P0 | ⬜ |
| AK-PT-131 | Academics | Teacher | Lesson log — mark topic complete | P1 | ⬜ |
| AK-PT-132 | Academics | Super Admin | Syllabus automation progress | P1 | ⬜ |
| AK-PT-133 | Academics | Super Admin | Academic progress dashboard | P1 | 🔶 |
| AK-PT-134 | Academics | Principal | Management academics overview | P0 | 🔶 |
| AK-PT-135 | Academics | Principal | Management timetable sub-nav | P1 | 🔶 |
| AK-PT-136 | Academics | Student | Student homework submit E2E | P0 | ⬜ |
| AK-PT-137 | Academics | Parent | Parent homework visibility after teacher assign | P0 | ⬜ |
| AK-PT-138 | Academics | Super Admin | Room allocation for classes | P1 | ⬜ |
| AK-PT-139 | Academics | Super Admin | Education remark entry | P1 | ✅ |
| AK-PT-140 | Academics | Super Admin | Homework intelligence dashboard | P2 | 🔶 |
| AK-PT-141 | Academics | Super Admin | Timetable intelligence insights | P2 | ⬜ |
| AK-PT-142 | Academics | Teacher | Class teacher dashboard — today's classes | P0 | 🔶 |
| AK-PT-143 | Academics | Teacher | Teacher assistant — class filter | P2 | ⬜ |

### B3. Exams & Results (144–165)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-144 | Exams | Super Admin | Exam creation — term assessment | P0 | 🔶 |
| AK-PT-145 | Exams | Super Admin | Exam scheduling — class/section | P0 | ⬜ |
| AK-PT-146 | Exams | Teacher | Teacher exams list | P0 | ✅ |
| AK-PT-147 | Exams | Teacher | Marks entry — single student | P0 | ⬜ |
| AK-PT-148 | Exams | Teacher | Marks entry — bulk class | P0 | ⬜ |
| AK-PT-149 | Exams | Principal | Exam approval before publish | P0 | ⬜ |
| AK-PT-150 | Exams | Super Admin | Result publishing workflow | P0 | ⬜ |
| AK-PT-151 | Exams | Student | Student exam results visibility | P0 | 🔶 |
| AK-PT-152 | Exams | Parent | Parent exam results visibility | P0 | 🔶 |
| AK-PT-153 | Exams | Student | Report card generation view | P0 | 🔶 |
| AK-PT-154 | Exams | Super Admin | Exam intelligence dashboard | P1 | 🔶 |
| AK-PT-155 | Exams | Super Admin | Exam reports export | P1 | 🔶 |
| AK-PT-156 | Exams | Principal | Management performance tab | P1 | 🔶 |
| AK-PT-157 | Exams | Teacher | Exam marks correction request | P1 | ⬜ |
| AK-PT-158 | Exams | Super Admin | Grade scale configuration | P1 | ⬜ |
| AK-PT-159 | Exams | Super Admin | Co-scholastic remarks | P2 | ⬜ |
| AK-PT-160 | Exams | Parent | Parent academic report PDF | P1 | ⬜ |
| AK-PT-161 | Exams | Super Admin | Result publish notification trigger | P1 | ⬜ |
| AK-PT-162 | Exams | Student | Progress screen — term trend | P1 | 🔶 |
| AK-PT-163 | Exams | Super Admin | Exam filter by term/subject | P1 | ⬜ |
| AK-PT-164 | Exams | Teacher | Internal assessment vs board exam | P2 | ⬜ |
| AK-PT-165 | Exams | Super Admin | Exam workflow automation hook | P2 | ⬜ |

### B4. Student Lifecycle / SIS (166–185)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-166 | SIS | Super Admin | SIS dashboard | P0 | ✅ |
| AK-PT-167 | SIS | Super Admin | Student registry — search/filter | P0 | ✅ |
| AK-PT-168 | SIS | Super Admin | Student profile creation | P0 | 🔶 |
| AK-PT-169 | SIS | Super Admin | Student profile edit | P0 | ✅ |
| AK-PT-170 | SIS | Super Admin | Parent record link to student | P0 | ⬜ |
| AK-PT-171 | SIS | Super Admin | Onboarding hub — new student wizard | P0 | 🔶 |
| AK-PT-172 | SIS | Super Admin | Admissions conversion to SIS record | P0 | ⬜ |
| AK-PT-173 | SIS | Super Admin | Class/section promotion | P0 | 🔶 |
| AK-PT-174 | SIS | Super Admin | Section reshuffle | P1 | ⬜ |
| AK-PT-175 | SIS | Super Admin | Section balance analytics | P1 | ⬜ |
| AK-PT-176 | SIS | Super Admin | Student transfer — inter-school | P1 | ⬜ |
| AK-PT-177 | SIS | Super Admin | Student archive/inactive | P1 | ⬜ |
| AK-PT-178 | SIS | Super Admin | Alumni conversion from graduate | P1 | ⬜ |
| AK-PT-179 | SIS | Super Admin | Student 360 view | P1 | ⬜ |
| AK-PT-180 | SIS | Super Admin | SIS academic operations bundle | P0 | ✅ |
| AK-PT-181 | SIS | Super Admin | SIS continuity planning | P1 | ✅ |
| AK-PT-182 | SIS | Super Admin | SIS filters — grade, section, status | P1 | ✅ |
| AK-PT-183 | SIS | Principal | Student registry read-only access | P1 | 🔶 |
| AK-PT-184 | SIS | Super Admin | Bulk student import preview | P2 | ⬜ |
| AK-PT-185 | SIS | Super Admin | Student document attachments | P2 | ⬜ |

### B5. Teacher Portal (186–195)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-186 | Teacher | Teacher | Dashboard — today's classes | P0 | ✅ |
| AK-PT-187 | Teacher | Teacher | Attendance workflow E2E | P0 | ✅ |
| AK-PT-188 | Teacher | Teacher | Homework queue navigation | P0 | ✅ |
| AK-PT-189 | Teacher | Teacher | Exams and marks entry | P0 | 🔶 |
| AK-PT-190 | Teacher | Teacher | Messages — thread open | P1 | 🔶 |
| AK-PT-191 | Teacher | Teacher | Leave request — casual/sick | P1 | ⬜ |
| AK-PT-192 | Teacher | Teacher | Class teacher dashboard | P0 | 🔶 |
| AK-PT-193 | Teacher | Teacher | Settings and profile | P2 | ✅ |
| AK-PT-194 | Teacher | Teacher | Timetable week navigation | P1 | ✅ |
| AK-PT-195 | Teacher | Teacher | Copilot dock — teacher context | P2 | ✅ |

### B6. Principal & Management (196–200)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-196 | Management | Principal | Principal dashboard overview | P0 | ✅ |
| AK-PT-197 | Management | Principal | Analytics — enrollment trend | P0 | 🔶 |
| AK-PT-198 | Management | Principal | Management approval queue | P0 | ✅ |
| AK-PT-199 | Management | Principal | KPI drill-down navigation | P1 | ✅ |
| AK-PT-200 | Management | Principal | Management dashboard export | P1 | ✅ |

---

## Pack C — ERP Verticals, Comms & Reports (AK-PT-201 → 300)

*Execution priority: **Pack 3***

### C1. HR (201–220)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-201 | HR | Super Admin | HR dashboard | P0 | ✅ |
| AK-PT-202 | HR | Super Admin | Employee create — teacher | P0 | ✅ |
| AK-PT-203 | HR | Super Admin | Employee edit and detail | P0 | ✅ |
| AK-PT-204 | HR | Super Admin | Employee deactivate | P1 | ⬜ |
| AK-PT-205 | HR | Super Admin | Staff attendance register | P1 | 🔶 |
| AK-PT-206 | HR | Super Admin | Leave request submission | P1 | ✅ |
| AK-PT-207 | HR | Principal | Leave approval workflow | P0 | ✅ |
| AK-PT-208 | HR | Super Admin | Payroll run — preview | P0 | ✅ |
| AK-PT-209 | HR | Super Admin | Payroll run — finalize | P0 | 🔶 |
| AK-PT-210 | HR | Super Admin | Payslip generation | P1 | ⬜ |
| AK-PT-211 | HR | Super Admin | Recruitment pipeline view | P2 | 🔶 |
| AK-PT-212 | HR | Super Admin | Performance review cycle | P2 | 🔶 |
| AK-PT-213 | HR | Super Admin | HR reports — headcount | P1 | 🔶 |
| AK-PT-214 | HR | Super Admin | HR settings persistence | P1 | ⬜ |
| AK-PT-215 | HR | Super Admin | Employee 360 view | P2 | ⬜ |
| AK-PT-216 | HR | Principal | Staff review on management dashboard | P1 | ⬜ |
| AK-PT-217 | HR | Super Admin | Teacher creation → SIS teaching assignment | P0 | 🔶 |
| AK-PT-218 | HR | Super Admin | HR filters — department, role | P1 | ⬜ |
| AK-PT-219 | HR | Super Admin | HR export — payroll summary | P1 | ⬜ |
| AK-PT-220 | HR | Super Admin | Substitute staffing from HR record | P1 | ⬜ |

### C2. Transport (221–238)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-221 | Transport | Transport Manager | Transport dashboard | P0 | ✅ |
| AK-PT-222 | Transport | Transport Manager | Route creation | P0 | ✅ |
| AK-PT-223 | Transport | Transport Manager | Vehicle registration | P0 | 🔶 |
| AK-PT-224 | Transport | Transport Manager | Driver assignment | P0 | 🔶 |
| AK-PT-225 | Transport | Transport Manager | Student route allocation | P0 | ✅ |
| AK-PT-226 | Transport | Transport Manager | Activate route for operations | P0 | ✅ |
| AK-PT-227 | Transport | Transport Manager | Live tracking map load | P1 | 🔶 |
| AK-PT-228 | Transport | Transport Manager | Transport attendance | P1 | ⬜ |
| AK-PT-229 | Transport | Transport Manager | Transport reports export | P1 | 🔶 |
| AK-PT-230 | Transport | Transport Manager | Transport settings | P1 | ⬜ |
| AK-PT-231 | Transport | Parent | Parent transport — route/stop/ETA | P0 | 🔶 |
| AK-PT-232 | Transport | Super Admin | Bulk student transport assignment | P1 | ⬜ |
| AK-PT-233 | Transport | Transport Manager | Route edit — stop reorder | P1 | ⬜ |
| AK-PT-234 | Transport | Transport Manager | Vehicle maintenance log | P2 | ⬜ |
| AK-PT-235 | Transport | Transport Manager | Transport fee linkage | P1 | ⬜ |
| AK-PT-236 | Transport | Transport Manager | GPS provider settings | P2 | ⬜ |
| AK-PT-237 | Transport | Principal | Transport KPI on management view | P2 | ⬜ |
| AK-PT-238 | Transport | Transport Manager | Transport filter by route/vehicle | P1 | ⬜ |

### C3. Hostel (239–253)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-239 | Hostel | Hostel Manager | Hostel dashboard — occupancy | P0 | ✅ |
| AK-PT-240 | Hostel | Hostel Manager | Room creation and configuration | P0 | 🔶 |
| AK-PT-241 | Hostel | Hostel Manager | Student room allocation | P0 | ✅ |
| AK-PT-242 | Hostel | Hostel Manager | Room change / swap | P1 | ⬜ |
| AK-PT-243 | Hostel | Hostel Manager | Hostel student registry | P0 | 🔶 |
| AK-PT-244 | Hostel | Hostel Manager | Hostel attendance | P1 | 🔶 |
| AK-PT-245 | Hostel | Hostel Manager | Hostel leave approval | P1 | ⬜ |
| AK-PT-246 | Hostel | Hostel Manager | Mess menu management | P2 | 🔶 |
| AK-PT-247 | Hostel | Hostel Manager | Visitor check-in/out | P1 | ✅ |
| AK-PT-248 | Hostel | Hostel Manager | Hostel reports | P1 | 🔶 |
| AK-PT-249 | Hostel | Hostel Manager | Occupancy management — full house | P0 | ⬜ |
| AK-PT-250 | Hostel | Warden | Warden daily rounds workflow | P1 | ⬜ |
| AK-PT-251 | Hostel | Parent | Parent hostel visibility (if enrolled) | P2 | ⬜ |
| AK-PT-252 | Hostel | Hostel Manager | Hostel fee linkage | P1 | ⬜ |
| AK-PT-253 | Hostel | Hostel Manager | Hostel filters — block, floor | P2 | ⬜ |

### C4. Inventory (254–268)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-254 | Inventory | Inventory Manager | Inventory dashboard | P0 | ✅ |
| AK-PT-255 | Inventory | Inventory Manager | Asset/item creation | P0 | 🔶 |
| AK-PT-256 | Inventory | Inventory Manager | Category management | P1 | 🔶 |
| AK-PT-257 | Inventory | Inventory Manager | Stock inward / procurement PO | P0 | ✅ |
| AK-PT-258 | Inventory | Inventory Manager | Stock allocation to department | P0 | 🔶 |
| AK-PT-259 | Inventory | Inventory Manager | Stock consumption recording | P0 | ⬜ |
| AK-PT-260 | Inventory | Inventory Manager | Asset maintenance log | P1 | 🔶 |
| AK-PT-261 | Inventory | Inventory Manager | Asset replacement workflow | P1 | ✅ |
| AK-PT-262 | Inventory | Inventory Manager | Book distribution to students | P1 | ✅ |
| AK-PT-263 | Inventory | Inventory Manager | Inventory lifecycle E2E | P0 | ✅ |
| AK-PT-264 | Inventory | Inventory Manager | Vendor management | P1 | ⬜ |
| AK-PT-265 | Inventory | Inventory Manager | Inventory reports export | P1 | 🔶 |
| AK-PT-266 | Inventory | Inventory Manager | Low stock alert | P1 | ⬜ |
| AK-PT-267 | Inventory | Inventory Manager | Inventory copilot assist | P2 | ⬜ |
| AK-PT-268 | Inventory | Inventory Manager | Inventory filters — category, location | P1 | ⬜ |

### C5. Library (269–280)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-269 | Library | Librarian | Library dashboard | P0 | ✅ |
| AK-PT-270 | Library | Librarian | Catalog — add book | P0 | 🔶 |
| AK-PT-271 | Library | Librarian | Issue book to student | P0 | ✅ |
| AK-PT-272 | Library | Librarian | Return book — good condition | P0 | ✅ |
| AK-PT-273 | Library | Librarian | Return book — damaged fine | P1 | ⬜ |
| AK-PT-274 | Library | Librarian | Member registration | P1 | 🔶 |
| AK-PT-275 | Library | Librarian | Digital resources upload | P1 | ✅ |
| AK-PT-276 | Library | Librarian | Library fines collection | P1 | ⬜ |
| AK-PT-277 | Library | Librarian | Library reports | P1 | 🔶 |
| AK-PT-278 | Library | Student | Student library resources view | P2 | ⬜ |
| AK-PT-279 | Library | Librarian | Overdue reminder workflow | P2 | ⬜ |
| AK-PT-280 | Library | Librarian | Library filters — genre, availability | P2 | ⬜ |

### C6. Communication & Notices (281–292)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-281 | Communication | Super Admin | Notice publish — all parents | P0 | 🔶 |
| AK-PT-282 | Communication | Super Admin | Notice publish — class-specific | P0 | ⬜ |
| AK-PT-283 | Communication | Super Admin | Broadcast admin — multi-channel | P0 | ✅ |
| AK-PT-284 | Communication | Super Admin | Communication delivery status | P1 | ⬜ |
| AK-PT-285 | Communication | Super Admin | Communication analytics | P2 | ⬜ |
| AK-PT-286 | Communication | Parent | Parent notice received and readable | P0 | ✅ |
| AK-PT-287 | Communication | Student | Student notice feed | P1 | ✅ |
| AK-PT-288 | Communication | Teacher | Teacher message to parent | P1 | 🔶 |
| AK-PT-289 | Communication | Super Admin | WhatsApp provider configuration | P2 | ⬜ |
| AK-PT-290 | Communication | Super Admin | Deep link — notice opens correct screen | P1 | ⬜ |
| AK-PT-291 | Communication | Super Admin | PTM meeting summary distribution | P1 | ✅ |
| AK-PT-292 | Communication | Super Admin | Parent activation campaign | P2 | ⬜ |

### C7. Reports & Exports (293–300)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-293 | Reports | Principal | Academic reports — class performance | P0 | ⬜ |
| AK-PT-294 | Reports | Finance Admin | Fee collection report | P0 | 🔶 |
| AK-PT-295 | Reports | Principal | Attendance summary report | P0 | ⬜ |
| AK-PT-296 | Reports | HR Manager | HR headcount and leave report | P1 | 🔶 |
| AK-PT-297 | Reports | Super Admin | Cross-module operations hub | P1 | ✅ |
| AK-PT-298 | Exports | Finance Admin | Export preview — fee ledger | P1 | ✅ |
| AK-PT-299 | Exports | Super Admin | Export permission denied for unauthorized role | P0 | ⬜ |
| AK-PT-300 | Exports | Principal | Management dashboard PDF export | P1 | ✅ |

---

## Pack D — Platform, Multi-School & Data Integrity (AK-PT-301 → 360)

*Execution priority: **Pack 4***

### D1. Admin Hub & Configuration (301–312)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-301 | Admin | Super Admin | Admin hub landing | P0 | 🔶 |
| AK-PT-302 | Admin | Super Admin | School setup wizard | P0 | 🔶 |
| AK-PT-303 | Admin | Super Admin | School branding configuration | P1 | ⬜ |
| AK-PT-304 | Admin | Super Admin | Smart school discovery/config | P1 | ⬜ |
| AK-PT-305 | Admin | Super Admin | Pilot dashboard readiness | P2 | 🔶 |
| AK-PT-306 | Admin | Super Admin | School completion hub | P2 | ⬜ |
| AK-PT-307 | Admin | Super Admin | Workflow automation rules | P1 | ✅ |
| AK-PT-308 | Admin | Super Admin | Management settings persistence | P1 | 🔶 |
| AK-PT-309 | Admin | Super Admin | Management tasks queue | P1 | 🔶 |
| AK-PT-310 | Admin | Super Admin | Management actions — bulk operations | P1 | ✅ |
| AK-PT-311 | Admin | Super Admin | AI access settings | P2 | ✅ |
| AK-PT-312 | Admin | Super Admin | Principal command center | P1 | ⬜ |

### D2. Control Center (313–324)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-313 | Control Center | Super Admin | Control center dashboard | P0 | ✅ |
| AK-PT-314 | Control Center | Super Admin | School management — create/edit | P0 | 🔶 |
| AK-PT-315 | Control Center | Super Admin | Tenant subscription view | P1 | 🔶 |
| AK-PT-316 | Control Center | Super Admin | Billing overview | P1 | 🔶 |
| AK-PT-317 | Control Center | Super Admin | CRM pipeline | P2 | 🔶 |
| AK-PT-318 | Control Center | Super Admin | Role management | P0 | 🔶 |
| AK-PT-319 | Control Center | Super Admin | Provider configuration — AI/SMS | P1 | ⬜ |
| AK-PT-320 | Control Center | Super Admin | Feature flags toggle | P1 | ⬜ |
| AK-PT-321 | Control Center | Super Admin | Platform analytics | P1 | 🔶 |
| AK-PT-322 | Control Center | Super Admin | Route guard — non-super-admin denied | P0 | ✅ |
| AK-PT-323 | Control Center | Super Admin | Control center settings | P2 | 🔶 |
| AK-PT-324 | Control Center | Super Admin | White-label hub from control center | P2 | 🔶 |

### D3. Multi-School & Director (325–342)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-325 | Multi-School | Director | Tenant isolation — data scoped per school | P0 | 🔶 |
| AK-PT-326 | Multi-School | Director | School switching updates all modules | P0 | 🔶 |
| AK-PT-327 | Multi-School | Director | Multi-school portfolio dashboard | P0 | ✅ |
| AK-PT-328 | Multi-School | Director | School onboarding wizard | P0 | 🔶 |
| AK-PT-329 | Multi-School | Director | Branch operations management | P1 | ✅ |
| AK-PT-330 | Multi-School | Director | Franchise portfolio view | P1 | ✅ |
| AK-PT-331 | Director | Director | Director dashboard KPIs | P0 | ✅ |
| AK-PT-332 | Director | Director | School comparison analytics | P0 | 🔶 |
| AK-PT-333 | Director | Director | Revenue and growth metrics | P1 | 🔶 |
| AK-PT-334 | Director | Director | Admissions funnel multi-school | P1 | ⬜ |
| AK-PT-335 | Director | Director | Compliance dashboard | P1 | ⬜ |
| AK-PT-336 | Director | Director | Director reports export | P1 | ⬜ |
| AK-PT-337 | Director | Director | Director portal full navigation | P0 | ✅ |
| AK-PT-338 | Multi-School | Director | Cross-school navigation without leak | P0 | ⬜ |
| AK-PT-339 | Multi-School | School Owner | Organization builder — interview | P1 | 🔶 |
| AK-PT-340 | Multi-School | School Owner | Organization builder — preview/provision | P1 | ✅ |
| AK-PT-341 | Multi-School | Director | Trust intelligence dashboard | P2 | ✅ |
| AK-PT-342 | Multi-School | Director | Platform operations — tenant isolation audit | P0 | ✅ |

### D4. Alumni & Extended Platform (343–352)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-343 | Alumni | Super Admin | Alumni dashboard | P1 | ✅ |
| AK-PT-344 | Alumni | Super Admin | Alumni registry search | P1 | ✅ |
| AK-PT-345 | Alumni | Super Admin | Alumni event creation | P2 | 🔶 |
| AK-PT-346 | Alumni | Super Admin | Donation campaign | P2 | 🔶 |
| AK-PT-347 | Alumni | Super Admin | Mentorship matching | P2 | 🔶 |
| AK-PT-348 | Alumni | Super Admin | Alumni reports | P2 | 🔶 |
| AK-PT-349 | Platform | Super Admin | Platform intelligence hub | P2 | ✅ |
| AK-PT-350 | Platform | Super Admin | Resource optimization | P2 | ✅ |
| AK-PT-351 | Platform | Super Admin | School memories admin | P2 | ✅ |
| AK-PT-352 | Platform | Super Admin | Growth campaign management | P2 | ✅ |

### D5. Data Integrity Cross-Module Chains (353–360)

| Suite ID | Module | Role | Workflow Name | Criticality | Status |
|----------|--------|------|---------------|:-----------:|:------:|
| AK-PT-353 | Data Integrity | Multi-role | **Chain A:** Admission → SIS profile → class assignment | P0 | 🔶 |
| AK-PT-354 | Data Integrity | Multi-role | **Chain B:** Admission → attendance → parent visibility | P0 | ⬜ |
| AK-PT-355 | Data Integrity | Multi-role | **Chain C:** Teacher marks → publish → student report card | P0 | ⬜ |
| AK-PT-356 | Data Integrity | Multi-role | **Chain D:** Teacher marks → publish → parent results | P0 | ⬜ |
| AK-PT-357 | Data Integrity | Multi-role | **Chain E:** Admission → fee assign → collect → parent receipt | P0 | 🔶 |
| AK-PT-358 | Data Integrity | Multi-role | **Chain F:** SIS student → transport assign → parent transport | P0 | 🔶 |
| AK-PT-359 | Data Integrity | Multi-role | **Chain G:** Teacher homework → student submit → parent view | P0 | ⬜ |
| AK-PT-360 | Data Integrity | Multi-role | **Chain H:** Notice publish → parent + student notification | P0 | ⬜ |

---

## Coverage Gap Analysis

### By criticality (target 360)

| Criticality | Count | % | Pack 1 target |
|-------------|------:|--:|:-------------:|
| P0 | 142 | 39% | 100% in Pack 1 |
| P1 | 158 | 44% | 60% in Pack 2 |
| P2 | 60 | 17% | Nightly only |

### By implementation status

| Status | Count | Action |
|--------|------:|--------|
| ✅ Exists | ~118 | Harden + split atomic suites |
| 🔶 Partial | ~72 | Deepen to mutation-level |
| ⬜ Net-new | ~170 | Implement in waves |

### Module coverage vs inventory

| Module | Routes | Inventory suites | Gap priority |
|--------|-------:|-----------------:|:------------:|
| Auth/Security | 8 | 28 | P0 |
| Admissions | 9 | 20 | P0 |
| Finance | 15 | 20 | P0 |
| Parent/Student/Teacher | 28 | 57 | P0 |
| Attendance | — | 18 | P0 |
| Academics/Exams | 20+ | 47 | P0 |
| SIS | 9 | 20 | P0 |
| Management | 11 | 15 | P1 |
| HR | 9 | 20 | P1 |
| Transport | 9 | 18 | P1 |
| Hostel | 8 | 15 | P1 |
| Inventory | 10 | 15 | P1 |
| Library | 8 | 12 | P1 |
| Communication | — | 12 | P1 |
| Reports/Exports | — | 8 | P1 |
| Control Center | 15 | 12 | P1 |
| Multi-School/Director | 12+ | 18 | P1 |
| Platform/Alumni | 20+ | 18 | P2 |

---

## Execution Roadmap

### Phase 0 — Foundation (Week 1)

1. Add `qa/patrol/patrol_inventory.json` — machine-readable export of this document
2. Extend `QaTestKeys` for top 50 unm keyed actions (per `ACTION_COVERAGE_MATRIX.md`)
3. Add QA personas: `transportManager`, `hostelManager`, `librarian`, `director`, `admissionsCounselor`
4. Split mega-files (`erp_workflows_test.dart`, `generated_journeys_test.dart`) into suite-per-file mapping

### Phase 1 — Pack 1 / Wave 1 (Weeks 2–4) — 100 suites

**Goal:** All P0 daily operations green on emulator CI

| Sprint | Suites | Focus |
|--------|-------:|-------|
| 1.1 | 001–028 | Auth hardening + RBAC inventory |
| 1.2 | 029–048 | Admissions deep workflows |
| 1.3 | 049–068 | Finance collection chain |
| 1.4 | 069–100 | Parent + student P0 portals |

**CI gate:** `PATROL_PACK=1 ./qa/patrol/run_erp_coverage.sh` (~25 min)

### Phase 2 — Pack 2 / Wave 2 (Weeks 5–7) — 100 suites

| Sprint | Suites | Focus |
|--------|-------:|-------|
| 2.1 | 101–118 | Attendance E2E + parent/student sync |
| 2.2 | 119–165 | Academics + exams + results publish |
| 2.3 | 166–185 | SIS lifecycle |
| 2.4 | 186–200 | Teacher + principal management |

**CI gate:** Pack 1 + Pack 2 (~50 min)

### Phase 3 — Pack 3 / Wave 3 (Weeks 8–10) — 100 suites

| Sprint | Suites | Focus |
|--------|-------:|-------|
| 3.1 | 201–220 | HR payroll + leave |
| 3.2 | 221–253 | Transport + hostel |
| 3.3 | 254–280 | Inventory + library |
| 3.4 | 281–300 | Communication + reports |

**CI gate:** Packs 1–3 (~75 min) — nightly

### Phase 4 — Pack 4 / Wave 4 (Weeks 11–12) — 60 suites

| Sprint | Suites | Focus |
|--------|-------:|-------|
| 4.1 | 301–324 | Admin + control center |
| 4.2 | 325–342 | Multi-school + director |
| 4.3 | 343–360 | Alumni, platform, **data integrity chains** |

**CI gate:** Full 360 — pre-prod sign-off (~120 min)

---

## Pack Prioritization Recommendation

### Pack 1 — Highest Value (Execute First)

**AK-PT-001 → 100** — 100 suites, ~85 P0

Rationale: A school opens every morning needing login, attendance, fees, parent visibility, and security. Failure here blocks real operations.

**Must-include P0 chains for Pack 1:**
- AK-PT-043 (admission E2E)
- AK-PT-062 (finance full journey)
- AK-PT-075/076/077 (parent pay + receipt)
- AK-PT-101/104 (teacher attendance)
- AK-PT-013–019 (security denies)
- AK-PT-027/088/099 (red-team operational)

### Pack 2 — Academic Operations

**AK-PT-101 → 200** — completes the teaching-learning cycle

Rationale: Marks, exams, homework, and SIS promotion are the academic contract with parents. Second-highest dispute risk after fees.

**Critical path:** 144→150→151→152→153 (exam publish visibility)

### Pack 3 — ERP Verticals

**AK-PT-201 → 300** — supporting services

Rationale: HR, transport, hostel, inventory run parallel to academics. Failure degrades operations but school can open.

### Pack 4 — Platform & Integrity

**AK-PT-301 → 360** — SaaS scale + cross-module truth

Rationale: Multi-school and director features matter for SaaS customers; data integrity chains (353–360) are the **release certification gate** — run last when module suites are stable.

---

## Test Design Standards (for implementation phase)

### Suite anatomy

```
AK-PT-NNN/
  persona: QaLoginPersona.*
  preconditions: [tenant, school, seed student]
  steps: [login → navigate → mutate → assert]
  postconditions: [audit event, downstream visibility]
  tags: [module, criticality, pack]
```

### Naming convention

```
patrol_test/workflows/{module}/{ak_pt_nnn}_{slug}_e2e_test.dart
```

### File grouping (target ~120 files from 360 suites)

| File pattern | Suites per file |
|--------------|----------------:|
| `*_workflows_test.dart` | 5–15 nav smokes |
| `*_e2e_test.dart` | 1 deep journey |
| `red_team_*_e2e_test.dart` | 2–4 security scenarios |
| `data_integrity_*_e2e_test.dart` | 1 cross-role chain |

### Runner integration

```bash
# Proposed — not yet implemented
PATROL_PACK=1 ERP_COVERAGE_MODE=pack ./qa/patrol/run_erp_coverage.sh
PATROL_CRITICALITY=P0 ERP_COVERAGE_MODE=critical ./qa/patrol/run_erp_coverage.sh
```

---

## Appendix A — Mapping to Existing Patrol Files

| Existing file | Inventory suites covered |
|---------------|-------------------------|
| `erp_coverage_smoke_test.dart` | Smoke anchor for all packs |
| `parent_workflows_test.dart` | AK-PT-069–079, 085 |
| `student_workflows_test.dart` | AK-PT-089–098 |
| `teacher_workflows_test.dart` | AK-PT-186–194 |
| `admissions_e2e_journey_test.dart` | AK-PT-043 |
| `finance_full_journey_e2e_test.dart` | AK-PT-062, 357 |
| `teacher_attendance_e2e_test.dart` | AK-PT-101, 104, 187 |
| `transport_allocation_e2e_test.dart` | AK-PT-225, 358 |
| `red_team_*_e2e_test.dart` | AK-PT-013–019, 027–028, 088, 099 |
| `generated_journeys_test.dart` | AK-PT-001–006 nav anchors (81 journeys) |

---

## Appendix B — Persona Expansion Required

| Role | Current QA Persona | Needed for |
|------|-------------------|------------|
| Transport Manager | ❌ | AK-PT-221–238 |
| Hostel Manager / Warden | ❌ | AK-PT-239–253 |
| Librarian | ❌ | AK-PT-269–280 |
| Admissions Counselor | ❌ | AK-PT-029–048 |
| Director / School Owner | ❌ | AK-PT-325–342 |
| HR Manager | 🔶 (superAdmin proxy) | AK-PT-201–220 |

---

*Document owner: Agent E (QA Architect)*  
*Next step: Implement Phase 0 foundation, then Pack 1 sprint 1.1*
