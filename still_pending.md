# Akshara ERP — Master Product & Commercial Audit

> **RECONCILED 2026-06-30 → [`docs/PRODUCT_COMMERCIAL_BACKLOG.md`](docs/PRODUCT_COMMERCIAL_BACKLOG.md).**
> This audit is the read-only INPUT. Every gap below has been classified into the backlog's five
> queues (Must Before Pilot / Must Before GA / Future QW / Phase 2 / Future Vision) with the locked
> owner decisions applied (O1–O10) and duplicates merged. **Do not re-file items from here as new
> work — consult the backlog.** Future audits should surface only genuinely NEW issues.

**Scope:** Read-only inspection of codebase (`lib/`, `supabase/`, `config/`, `openapi/`, `docs/`)  
**Live production config:** `config/live_release.json` (June 2026 pilot VPS)  
**Commercial plans in DB:** Trial · Standard · Professional · Enterprise (`supabase/migrations/20260717000000_subscription_plans_catalog.sql`)  
**Codebase scale:** 44 feature modules · 48 repository interfaces · ~140 SQL migrations · ~90 backend shared modules · ~822 Dart feature files

---

## Executive Summary

Akshara is a **broad, production-pilot-ready school ERP** with unusually deep AI/intelligence layers, a full mobile triad (parent/teacher/student), chain-level director tooling, and a nascent SaaS entitlement engine. The product is **commercially under-monetized in code**: subscription assignment and module gating exist, but **billing collection, usage quotas (SMS/storage/AI tokens), and marketplace add-ons are explicitly out of scope** in the entitlement migration.

**Rough implementation mix (audited list of ~155 capabilities):**

| Status | Count | % |
|--------|------:|--:|
| ✅ Production Ready | 52 | 34% |
| 🟢 Fully Implemented | 28 | 18% |
| 🟡 Mostly Implemented | 32 | 21% |
| 🟠 Partially Implemented | 28 | 18% |
| 🔴 Planned | 13 | 8% |
| ❌ Not Available | 2 | 1% |

**Estimated unique modules/features in Akshara: ~155–165** (130 requested items + ~25–35 additional discovered modules such as Question Intelligence, Dynamic Widgets, Organization Builder, vertical packs, Student/Employee 360, Memories, Achievement Promotion, Control Center CRM, etc.)

---

## Additional Investigation — Platform Capabilities

| Capability | Status | Evidence |
|------------|--------|----------|
| SMS quota system | 🔴 Planned | No tenant SMS budget tables; OTP rate-limit only |
| Storage quota system | 🔴 Planned | Per-file limits only (`storage_foundation` migration) |
| AI token quota system | 🔴 Planned | `anthropic_client.ts` tracks usage; no caps |
| Subscription plans | 🟢 Exists | `subscription_plans`, `plan_entitlements`, `organization_subscriptions` |
| Usage tracking | 🟡 Partial | Student/school counts in `PlanUsage`; no comms/AI usage |
| Feature flags | 🟢 Exists | `repository_config.dart` + `live_release.json` + school capabilities |
| Trial mode | 🟢 Exists | 30-day trial + 7-day grace in DB + `SubscriptionStatus.trial` |
| Demo mode | 🟢 Exists | `disableDemoAuth` in `environment.dart`; blocked in production |
| White-label licensing | 🟠 Partial | UI + mock; `WHITE_LABEL_PLATFORM_API_ENABLED` OFF live |
| School onboarding wizard | ✅ Exists | Unified onboarding + AI School Builder + setup wizard |
| Organization onboarding | ✅ Exists | Organization Builder (Enterprise) with real provisioning |
| Marketplace/Add-on architecture | 🔴 Planned | B2 migration: "NO … addons"; entitlements replace add-ons |

---

# Complete Feature Inventory

Format for each item: **Status · Backend · Frontend · Mobile · Web · AI · Dependencies · Commercial Category · Confidence**

---

## CORE ERP

### Authentication
**Status:** ✅ Production Ready  
**Backend:** JWT auth, refresh rotation, revocation — `supabase/functions/_shared/auth/`  
**Frontend:** Login, staff login, splash — `lib/features/auth/`  
**Mobile:** Yes · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Supabase edge API, secure token storage  
**Commercial Category:** Core ERP · **Confidence:** 92%

### OTP
**Status:** ✅ Production Ready  
**Backend:** OTP request/verify handlers, rate limiting  
**Frontend:** `/otp`, `/staff/otp` routes  
**Mobile:** Yes · **Web:** Yes  
**AI Used:** No  
**Dependencies:** SMS provider (Twilio, stub mode)  
**Commercial Category:** Core ERP · **Confidence:** 90%

### RBAC
**Status:** ✅ Production Ready  
**Backend:** Server-side permission enforcement + route inventory  
**Frontend:** 100+ permissions, route guards, mutation validators — `lib/core/security/`  
**Mobile:** Yes · **Web:** Yes  
**AI Used:** No (gates AI permissions separately)  
**Dependencies:** Permission sync on login/refresh  
**Commercial Category:** Core ERP · **Confidence:** 95%

### Multi School
**Status:** 🟠 Partially Implemented  
**Backend:** Director chain APIs ON; `multi_school_operations` OFF live  
**Frontend:** Director portfolio + `platform/multi_school/` (mock at live)  
**Mobile:** No · **Web:** Yes (ERP)  
**AI Used:** Yes (director executive summary)  
**Dependencies:** `DIRECTOR_API_ENABLED`, `module.multi_branch` (Professional+)  
**Commercial Category:** Enterprise · **Confidence:** 75%

### Organization Management
**Status:** 🟢 Fully Implemented  
**Backend:** Control Center + org subscriptions  
**Frontend:** Control Center schools, org plan assignment — `platform/control_center/`, `entitlements/`  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** `CONTROL_CENTER_API_ENABLED`, superAdmin RBAC  
**Commercial Category:** Enterprise · **Confidence:** 85%

### Admissions
**Status:** ✅ Production Ready  
**Backend:** Full funnel API — `ADMISSIONS_API_ENABLED` ON  
**Frontend:** 10 screens AD-01→AD-10 — `lib/features/admissions/`  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes — Admissions Assistant card (B4)  
**Dependencies:** Finance handoff, SIS conversion  
**Commercial Category:** Core ERP · **Confidence:** 93%

### Student Information (SIS)
**Status:** ✅ Production Ready  
**Backend:** Hybrid SIS repo — `SIS_API_ENABLED` ON  
**Frontend:** Registry, promotion, reshuffle, section balance — `lib/features/sis/`  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Admissions, academic assignment  
**Commercial Category:** Core ERP · **Confidence:** 92%

### Staff Management
**Status:** 🟡 Mostly Implemented  
**Backend:** HR hybrid API + Employee 360 (`EMPLOYEE_API_ENABLED` ON)  
**Frontend:** HR employees + `/employees/360` — `hr/`, `employee/`  
**Mobile:** No · **Web:** Yes  
**AI Used:** Limited  
**Dependencies:** HR module, approvals  
**Commercial Category:** Premium (HR/Payroll entitlement) · **Confidence:** 80%

### Teacher Management
**Status:** 🟡 Mostly Implemented  
**Backend:** Teacher API + HR overlap  
**Frontend:** HR performance/recruitment + teacher mobile app  
**Mobile:** Yes (teacher app) · **Web:** Yes  
**AI Used:** Yes — teacher effectiveness, student risk  
**Dependencies:** SIS class assignments, timetable  
**Commercial Category:** Core ERP · **Confidence:** 82%

### Parent Management
**Status:** 🟡 Mostly Implemented  
**Backend:** Parent API + SIS linkage  
**Frontend:** Parent app + parent meetings + activation flows  
**Mobile:** Yes · **Web:** Limited  
**AI Used:** Yes — parent insights, guidance  
**Dependencies:** SIS, finance, communication  
**Commercial Category:** Core ERP · **Confidence:** 85%

### Student App
**Status:** ✅ Production Ready  
**Backend:** `STUDENT_API_ENABLED` ON  
**Frontend:** 9 screens — `lib/features/student_app/`  
**Mobile:** Yes · **Web:** No (mobile shell)  
**AI Used:** Indirect (dashboard hints)  
**Dependencies:** Academic, attendance, homework repos  
**Commercial Category:** Core ERP · **Confidence:** 90%

### Parent App
**Status:** ✅ Production Ready  
**Backend:** `PARENT_API_ENABLED` ON  
**Frontend:** 21 screens including fees, transport, experience hub  
**Mobile:** Yes · **Web:** No  
**AI Used:** Yes — insights route, copilot dock  
**Dependencies:** Payment, communication, finance  
**Commercial Category:** Core ERP · **Confidence:** 91%

### Teacher App
**Status:** ✅ Production Ready  
**Backend:** `TEACHER_API_ENABLED` ON  
**Frontend:** 16 screens — attendance, homework create, parent comms  
**Mobile:** Yes · **Web:** No  
**AI Used:** Yes — student risk screen  
**Dependencies:** Attendance, academic APIs  
**Commercial Category:** Core ERP · **Confidence:** 90%

### Principal Dashboard
**Status:** ✅ Production Ready  
**Backend:** Management API ON  
**Frontend:** MG-01 dashboard, approvals, analytics — `lib/features/management/`  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes — copilot context, intelligence hub, PDF export  
**Dependencies:** Cross-module aggregations  
**Commercial Category:** Core ERP · **Confidence:** 90%

### Director Dashboard
**Status:** ✅ Production Ready  
**Backend:** `DIRECTOR_API_ENABLED` ON  
**Frontend:** 9 chain screens — portfolio, revenue, marketing, compliance  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes — executive summary, board-pack export  
**Dependencies:** Multi-school data, `module.trust_org` (Enterprise)  
**Commercial Category:** Enterprise · **Confidence:** 88%

---

## ACADEMICS

### Attendance
**Status:** ✅ Production Ready  
**Backend:** `ATTENDANCE_API_ENABLED` ON — mark/submit/corrections  
**Frontend:** Teacher mobile + management corrections admin  
**Mobile:** Yes · **Web:** Yes  
**AI Used:** No  
**Dependencies:** SIS class rosters  
**Commercial Category:** Core ERP · **Confidence:** 90%

### Face Recognition Attendance
**Status:** 🔴 Planned  
**Backend:** SRS/docs only (`face_recognition_logs` in SRS text)  
**Frontend:** None  
**Mobile:** No · **Web:** No  
**AI Used:** Would use CV — not built  
**Dependencies:** Hardware integration — none  
**Commercial Category:** Future Product · **Confidence:** 95% (confirmed absent)

### Face ID Attendance
**Status:** 🔴 Planned  
**Backend:** None  
**Frontend:** None  
**Mobile:** No · **Web:** No  
**AI Used:** No  
**Dependencies:** Device biometrics — not implemented  
**Commercial Category:** Future Product · **Confidence:** 95%

### Geo-fencing Attendance
**Status:** 🔴 Planned  
**Backend:** None  
**Frontend:** SRS/Figma references only; audit confirms "no GPS/biometric"  
**Mobile:** No · **Web:** No  
**AI Used:** No  
**Dependencies:** Location services — not wired  
**Commercial Category:** Future Product · **Confidence:** 94%

### Timetable
**Status:** ✅ Production Ready  
**Backend:** `ACADEMIC_TIMETABLE_API_ENABLED` ON  
**Frontend:** Academics hub + school_completion automation/optimization/intelligence  
**Mobile:** Yes (parent/teacher/student views) · **Web:** Yes  
**AI Used:** Yes — timetable intelligence, substitute manager, room allocation  
**Dependencies:** Academic subjects, teacher assignments  
**Commercial Category:** Core ERP · **Confidence:** 88%

### Homework
**Status:** ✅ Production Ready  
**Backend:** Teacher/parent/student homework APIs  
**Frontend:** Full flows in all 3 mobile personas + intelligence screen  
**Mobile:** Yes · **Web:** No  
**AI Used:** Yes — homework intelligence analytics  
**Dependencies:** Academic module  
**Commercial Category:** Core ERP · **Confidence:** 88%

### Assignments
**Status:** 🟠 Partially Implemented  
**Backend:** Folded into homework + education paper models  
**Frontend:** No standalone "Assignments" module; education PDF has `HomeworkAssignment`  
**Mobile:** Via homework · **Web:** Via education  
**AI Used:** Limited  
**Dependencies:** Homework, education  
**Commercial Category:** Core ERP · **Confidence:** 70%

### Lesson Planning
**Status:** 🟡 Mostly Implemented  
**Backend:** School completion repo ON  
**Frontend:** Lesson logs screen in `school_completion/`  
**Mobile:** No · **Web:** Yes  
**AI Used:** Limited  
**Dependencies:** Syllabus, timetable  
**Commercial Category:** Premium · **Confidence:** 72%

### Syllabus Tracking
**Status:** 🟡 Mostly Implemented  
**Backend:** Syllabus automation API in school_completion  
**Frontend:** `syllabus_automation_screen.dart`, academic progress alerts  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes — auto-generate/clone syllabus  
**Dependencies:** Academic years, subjects  
**Commercial Category:** Premium · **Confidence:** 78%

### Exams
**Status:** ✅ Production Ready  
**Backend:** `EXAM_API_ENABLED` ON — full exam lifecycle  
**Frontend:** Exam administration + mobile exam views  
**Mobile:** Yes · **Web:** Yes  
**AI Used:** Yes — exam intelligence screen  
**Dependencies:** Academic, marks entry  
**Commercial Category:** Core ERP · **Confidence:** 90%

### Marks Entry
**Status:** ✅ Production Ready  
**Backend:** Exam admin marks-entry phase  
**Frontend:** `exam_administration_screen.dart` with marks-entry filter  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Exam module, approvals  
**Commercial Category:** Core ERP · **Confidence:** 87%

### Report Cards
**Status:** ✅ Production Ready  
**Backend:** Student report card API paths  
**Frontend:** Parent + student report card screens, PDF export service  
**Mobile:** Yes · **Web:** Limited  
**AI Used:** No  
**Dependencies:** Exam marks, academic data  
**Commercial Category:** Core ERP · **Confidence:** 85%

### Progress Analytics
**Status:** 🟢 Fully Implemented  
**Backend:** Intelligence + academic progress APIs  
**Frontend:** Student progress, academic progress, parent insights  
**Mobile:** Yes · **Web:** Yes  
**AI Used:** Yes — AI-generated summaries  
**Dependencies:** Exams, attendance, homework  
**Commercial Category:** Premium · **Confidence:** 83%

---

## FINANCE

### Fee Management
**Status:** ✅ Production Ready  
**Backend:** `FINANCE_API_ENABLED` ON — structures, assignment, collections  
**Frontend:** 16 finance screens FN-01→FN-11+  
**Mobile:** Yes (parent fees) · **Web:** Yes  
**AI Used:** Yes — finance copilot, collection intelligence  
**Dependencies:** SIS student accounts  
**Commercial Category:** Core ERP · **Confidence:** 92%

### Online Payments
**Status:** ✅ Production Ready  
**Backend:** Razorpay Universal Payment Engine — `PAYMENT_API_ENABLED` ON  
**Frontend:** Parent payment screen, pay-now flow  
**Mobile:** Yes · **Web:** Limited  
**AI Used:** No  
**Dependencies:** Razorpay keys (stub mode without)  
**Commercial Category:** Core ERP · **Confidence:** 90%

### Offline Payments
**Status:** ✅ Production Ready  
**Backend:** Finance QR/UPI handlers + offline collection recording  
**Frontend:** Finance collections + parent receipts  
**Mobile:** Yes · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Finance module  
**Commercial Category:** Core ERP · **Confidence:** 85%

### Scholarships
**Status:** 🟡 Mostly Implemented  
**Backend:** Finance concession/scholarship workflows  
**Frontend:** Create scholarship dialog in `finance_workflow_actions.dart`  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Fee structures, discounts  
**Commercial Category:** Core ERP · **Confidence:** 75%

### Discounts
**Status:** 🟡 Mostly Implemented  
**Backend:** Discount rules in finance repo  
**Frontend:** Create/edit discount rule dialogs  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Fee assignment  
**Commercial Category:** Core ERP · **Confidence:** 78%

### Accounting
**Status:** 🟠 Partially Implemented  
**Backend:** Finance ledger concepts; inventory-finance bridge ON  
**Frontend:** Reconciliation, executive dashboard — no full GL/chart of accounts  
**Mobile:** No · **Web:** Yes  
**AI Used:** Limited  
**Dependencies:** Finance, inventory_finance  
**Commercial Category:** Premium · **Confidence:** 65%

### Payroll
**Status:** 🟡 Mostly Implemented  
**Backend:** HR hybrid API with payroll endpoints  
**Frontend:** `hr_payroll_screen.dart` + approval queue seeds  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** HR, approvals (`module.hr_payroll` Professional+)  
**Commercial Category:** Premium · **Confidence:** 72%

### Expense Management
**Status:** 🟠 Partially Implemented  
**Backend:** Approval type `expense` in demo seeds; hostel mentions expense ledger placeholder  
**Frontend:** Approval center handles expense requests; no dedicated expense module  
**Mobile:** No · **Web:** Partial  
**AI Used:** No  
**Dependencies:** Approvals, finance  
**Commercial Category:** Premium · **Confidence:** 60%

---

## ADMINISTRATION

### Library
**Status:** ✅ Production Ready  
**Backend:** `LIBRARY_API_ENABLED` ON  
**Frontend:** 8 screens — catalog, issues, fines, reports  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** `module.library` (Professional+)  
**Commercial Category:** Premium · **Confidence:** 88%

### Inventory
**Status:** ✅ Production Ready  
**Backend:** `INVENTORY_API_ENABLED` + distribution ON  
**Frontend:** 12 screens including copilot, lifecycle, distribution  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes — inventory copilot, stock forecasting  
**Dependencies:** `module.inventory` (Professional+)  
**Commercial Category:** Premium · **Confidence:** 87%

### Asset Management
**Status:** 🟡 Mostly Implemented  
**Backend:** Inventory assets submodule  
**Frontend:** Inventory assets/categories/maintenance screens (not separate module)  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes (via inventory intelligence)  
**Dependencies:** Inventory module  
**Commercial Category:** Premium · **Confidence:** 78%

### Hostel
**Status:** ✅ Production Ready  
**Backend:** `HOSTEL_API_ENABLED` ON  
**Frontend:** 8 screens — rooms, mess, visitors, leave  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** `module.hostel` (Professional+)  
**Commercial Category:** Premium · **Confidence:** 86%

### Transport
**Status:** ✅ Production Ready  
**Backend:** `TRANSPORT_API_ENABLED` ON  
**Frontend:** 9 admin screens + parent transport  
**Mobile:** Yes (parent) · **Web:** Yes  
**AI Used:** No  
**Dependencies:** `module.transport` (Professional+)  
**Commercial Category:** Premium · **Confidence:** 85%

### GPS Bus Tracking
**Status:** 🟠 Partially Implemented  
**Backend:** Vehicle `gpsDeviceId` in models  
**Frontend:** `transport_tracking_screen.dart` — **explicit placeholder**, no live map SDK  
**Mobile:** No · **Web:** Yes (placeholder)  
**AI Used:** No  
**Dependencies:** Third-party GPS integration — not built  
**Commercial Category:** Add-on · **Confidence:** 88%

### Visitor Management
**Status:** 🟠 Partially Implemented  
**Backend:** Hostel visitor log API  
**Frontend:** Hostel visitors + log visitor dialog with gate pass IDs  
**Mobile:** No · **Web:** Yes (hostel-scoped only)  
**AI Used:** No  
**Dependencies:** Hostel module  
**Commercial Category:** Premium · **Confidence:** 70%

### Reception
**Status:** ❌ Not Available  
**Backend:** None  
**Frontend:** No reception desk module  
**Mobile:** No · **Web:** No  
**AI Used:** No  
**Dependencies:** N/A  
**Commercial Category:** Future Product · **Confidence:** 92%

### Gate Pass
**Status:** 🟠 Partially Implemented  
**Backend:** Hostel gate pass IDs in visitor/leave models  
**Frontend:** Hostel workflow only; no school-wide gate pass  
**Mobile:** No · **Web:** Partial  
**AI Used:** No  
**Dependencies:** Hostel  
**Commercial Category:** Premium · **Confidence:** 68%

---

## COMMUNICATION

### SMS
**Status:** 🟢 Fully Implemented  
**Backend:** Twilio provider + stub mode — `notification_providers.ts`  
**Frontend:** Broadcast admin, communication delivery analytics  
**Mobile:** Via notifications · **Web:** Yes  
**AI Used:** Yes — AI-drafted SMS in intelligence  
**Dependencies:** Communication hub; no SMS quota  
**Commercial Category:** Core ERP · **Confidence:** 85%

### Email
**Status:** 🟢 Fully Implemented  
**Backend:** Email provider in communication hub  
**Frontend:** Broadcast templates, delivery tracking  
**Mobile:** Indirect · **Web:** Yes  
**AI Used:** Yes — draft generation  
**Dependencies:** Communication module  
**Commercial Category:** Core ERP · **Confidence:** 84%

### Push Notifications
**Status:** 🟢 Fully Implemented  
**Backend:** FCM HTTP v1 + device token handlers  
**Frontend:** Notifications inbox — `lib/features/notifications/`  
**Mobile:** Yes · **Web:** Limited  
**AI Used:** No  
**Dependencies:** `COMMUNICATION_API_ENABLED`  
**Commercial Category:** Core ERP · **Confidence:** 86%

### WhatsApp
**Status:** 🟢 Fully Implemented  
**Backend:** MSG91/Gupshup/stub providers — `whatsapp_providers.ts`  
**Frontend:** WhatsApp provider config screen in school_completion  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes — intelligence drafts for WhatsApp scenarios  
**Dependencies:** School WhatsApp provider setup  
**Commercial Category:** Premium · **Confidence:** 83%

### Circulars
**Status:** 🟡 Mostly Implemented  
**Backend:** Broadcast/notice delivery pipeline  
**Frontend:** Broadcast admin + notices (not labeled "circulars")  
**Mobile:** Yes (notices) · **Web:** Yes  
**AI Used:** Limited  
**Dependencies:** Communication  
**Commercial Category:** Core ERP · **Confidence:** 75%

### Announcements
**Status:** 🟡 Mostly Implemented  
**Backend:** Notices API for student/parent  
**Frontend:** Notice carousel on parent dashboard, student notices  
**Mobile:** Yes · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Communication  
**Commercial Category:** Core ERP · **Confidence:** 78%

### Parent Communication
**Status:** ✅ Production Ready  
**Backend:** Parent messages + teacher parent-communication APIs  
**Frontend:** Parent messages, teacher parent comms, PTM  
**Mobile:** Yes · **Web:** Limited  
**AI Used:** Yes — communication intelligence drafts  
**Dependencies:** Communication, parent meetings  
**Commercial Category:** Core ERP · **Confidence:** 87%

### Teacher Communication
**Status:** ✅ Production Ready  
**Backend:** Teacher messages API  
**Frontend:** Teacher messages screen + templates  
**Mobile:** Yes · **Web:** No  
**AI Used:** Limited  
**Dependencies:** Communication module  
**Commercial Category:** Core ERP · **Confidence:** 85%

---

## AI & INTELLIGENCE

### AI Copilot
**Status:** ✅ Production Ready  
**Backend:** Copilot sessions/messages — `AI_COPILOT_ENABLED` ON  
**Frontend:** 8 assistant types, floating dock, persona shells — 28+ files  
**Mobile:** Yes (dock overlay) · **Web:** Yes  
**AI Used:** Yes — core product  
**Dependencies:** Anthropic/OpenRouter via edge  
**Commercial Category:** Premium · **Confidence:** 91%

### Adaptive AI
**Status:** 🟡 Mostly Implemented  
**Backend:** Intelligence pipelines with context-aware responses  
**Frontend:** Capability filter, persona routing, screen context injection  
**Mobile:** Yes · **Web:** Yes  
**AI Used:** Yes  
**Dependencies:** Copilot + intelligence repos  
**Commercial Category:** Premium · **Confidence:** 75%

### AI Insights
**Status:** ✅ Production Ready  
**Backend:** `INTELLIGENCE_API_ENABLED` ON — 20+ intelligence methods  
**Frontend:** Intelligence hub, student success, trust hub  
**Mobile:** Limited · **Web:** Yes  
**AI Used:** Yes  
**Dependencies:** Cross-module data  
**Commercial Category:** Premium · **Confidence:** 88%

### AI Reports
**Status:** 🟡 Mostly Implemented  
**Backend:** Narrative generation in predictions/director  
**Frontend:** PDF export with AI summaries (management, parent insights)  
**Mobile:** Limited · **Web:** Yes  
**AI Used:** Yes  
**Dependencies:** Report export service  
**Commercial Category:** Premium · **Confidence:** 78%

### AI Recommendations
**Status:** 🟢 Fully Implemented  
**Backend:** Unified recommendation intelligence, admissions next-best-actions  
**Frontend:** Admissions assistant card, inventory reorder recs  
**Mobile:** Limited · **Web:** Yes  
**AI Used:** Yes  
**Dependencies:** Intelligence repo  
**Commercial Category:** Premium · **Confidence:** 82%

### AI Chat
**Status:** ✅ Production Ready  
**Backend:** Copilot session chat with RBAC  
**Frontend:** `/copilot`, `/ai-assistant` routes  
**Mobile:** Yes · **Web:** Yes  
**AI Used:** Yes  
**Dependencies:** `viewAiCopilot` / `runAiCopilot` permissions  
**Commercial Category:** Premium · **Confidence:** 90%

### Workflow Automation
**Status:** 🟠 Partially Implemented  
**Backend:** `WORKFLOW_API_ENABLED` **OFF** live → mock  
**Frontend:** `/management/workflow-automation` screen exists  
**Mobile:** No · **Web:** Yes  
**AI Used:** Limited  
**Dependencies:** Workflow repo, approvals  
**Commercial Category:** Enterprise · **Confidence:** 70%

### Smart Notifications
**Status:** 🟡 Mostly Implemented  
**Backend:** Communication delivery queue + intelligence draft scenarios  
**Frontend:** Delivery analytics, template-based smart comms  
**Mobile:** Yes · **Web:** Yes  
**AI Used:** Yes — multi-language draft generation  
**Dependencies:** Communication + intelligence  
**Commercial Category:** Premium · **Confidence:** 74%

### Predictive Analytics
**Status:** ✅ Production Ready  
**Backend:** `PREDICTIONS_API_ENABLED` ON — fee-default, admission-conversion, student-risk  
**Frontend:** Predictions screen with AI narrative  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes  
**Dependencies:** `feature.ai_predictions` (Enterprise only)  
**Commercial Category:** Enterprise · **Confidence:** 87%

---

## REPORTS

### Analytics
**Status:** ✅ Production Ready  
**Backend:** Analytics intelligence API ON  
**Frontend:** Management analytics MG-02, school completion comms analytics  
**Mobile:** No · **Web:** Yes  
**AI Used:** Limited  
**Dependencies:** Cross-module aggregations  
**Commercial Category:** Core ERP · **Confidence:** 85%

### Dashboards
**Status:** ✅ Production Ready  
**Backend:** Evolution dynamic dashboard + widget platform  
**Frontend:** Dynamic widgets layout editor/runtime, principal/director dashboards  
**Mobile:** Limited · **Web:** Yes  
**AI Used:** Yes — widget intelligence  
**Dependencies:** `EVOLUTION_API_ENABLED`, dynamic widgets  
**Commercial Category:** Premium · **Confidence:** 88%

### Principal Reports
**Status:** ✅ Production Ready  
**Backend:** Management + per-module report APIs  
**Frontend:** Management PDF export, module report screens  
**Mobile:** No · **Web:** Yes  
**AI Used:** Limited  
**Dependencies:** Management module  
**Commercial Category:** Core ERP · **Confidence:** 86%

### Director Reports
**Status:** ✅ Production Ready  
**Backend:** Director reports + board-pack export  
**Frontend:** `director_reports_screen.dart`  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes — executive AI summary  
**Dependencies:** Director module (Enterprise)  
**Commercial Category:** Enterprise · **Confidence:** 85%

### Custom Reports
**Status:** 🟠 Partially Implemented  
**Backend:** Per-module fixed report endpoints  
**Frontend:** Module-specific report screens (no report builder)  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Individual modules  
**Commercial Category:** Premium · **Confidence:** 65%

### BI Dashboards
**Status:** 🟡 Mostly Implemented  
**Backend:** Management + control center analytics  
**Frontend:** KPI rows, trend charts, segment panels — no PowerBI/Tableau integration  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes — platform intelligence (mock live OFF)  
**Dependencies:** Analytics APIs  
**Commercial Category:** Enterprise · **Confidence:** 72%

---

## BRANDING

### White Label
**Status:** 🟠 Partially Implemented  
**Backend:** API stub returns empty; `WHITE_LABEL_PLATFORM_API_ENABLED` OFF  
**Frontend:** Full hub — branding, logos, themes, deployment profiles  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Control center white-label probe  
**Commercial Category:** Enterprise · **Confidence:** 70%

### School Branding
**Status:** 🟢 Fully Implemented  
**Backend:** Startup onboarding branding repo  
**Frontend:** School completion branding screen, onboarding branding step  
**Mobile:** Limited · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Onboarding, school_completion  
**Commercial Category:** Core ERP · **Confidence:** 82%

### Custom Domain
**Status:** 🔴 Planned  
**Backend:** None  
**Frontend:** Deployment profiles mention deployment concepts only  
**Mobile:** No · **Web:** No  
**AI Used:** No  
**Dependencies:** DNS/hosting — not built  
**Commercial Category:** Enterprise · **Confidence:** 90%

### Custom Theme
**Status:** 🟠 Partially Implemented  
**Backend:** Branding colors stored per school  
**Frontend:** `/settings/appearance` + white label theme management  
**Mobile:** Limited · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Theme system (`app_theme.dart`)  
**Commercial Category:** Premium · **Confidence:** 75%

### Multi-language
**Status:** 🟡 Mostly Implemented  
**Backend:** Intelligence supports multiple languages for drafts  
**Frontend:** `content_localization.dart`, locale typography (incl. RTL Urdu)  
**Mobile:** Partial · **Web:** Partial  
**AI Used:** Yes — multilingual parent guidance  
**Dependencies:** i18n infrastructure (not full app translation)  
**Commercial Category:** Premium · **Confidence:** 68%

### Localization
**Status:** 🟡 Mostly Implemented  
**Backend:** Content-level localization in repos  
**Frontend:** Locale-aware typography; not comprehensive l10n arb files  
**Mobile:** Partial · **Web:** Partial  
**AI Used:** Limited  
**Dependencies:** Flutter locale support  
**Commercial Category:** Premium · **Confidence:** 65%

---

## INTEGRATIONS

### Payment Gateway
**Status:** ✅ Production Ready  
**Backend:** Razorpay — orders, webhooks, stub mode  
**Frontend:** Parent pay flow, finance reconciliation  
**Mobile:** Yes · **Web:** Limited  
**AI Used:** No  
**Dependencies:** `PAYMENT_API_ENABLED`  
**Commercial Category:** Core ERP · **Confidence:** 90%

### Biometric Devices
**Status:** 🔴 Planned  
**Backend:** None  
**Frontend:** Fictional "Biometric sync error" in attendance correction demo text  
**Mobile:** No · **Web:** No  
**AI Used:** No  
**Dependencies:** Hardware SDK — none  
**Commercial Category:** Add-on · **Confidence:** 93%

### Face Recognition Devices
**Status:** 🔴 Planned  
**Backend:** None  
**Frontend:** None  
**Mobile:** No · **Web:** No  
**AI Used:** No  
**Dependencies:** None  
**Commercial Category:** Add-on · **Confidence:** 93%

### RFID
**Status:** 🔴 Planned  
**Backend:** None for attendance  
**Frontend:** Mock inventory mentions RFID scanner placeholder  
**Mobile:** No · **Web:** No  
**AI Used:** No  
**Dependencies:** None  
**Commercial Category:** Add-on · **Confidence:** 90%

### QR Attendance
**Status:** 🔴 Planned  
**Backend:** Finance QR is UPI payment only, not attendance  
**Frontend:** None  
**Mobile:** No · **Web:** No  
**AI Used:** No  
**Dependencies:** None  
**Commercial Category:** Add-on · **Confidence:** 92%

### API
**Status:** 🟢 Fully Implemented  
**Backend:** ~90 edge modules, single `api` function router  
**Frontend:** OpenAPI contract registry — `openapi/akshara-erp-v1.yaml`  
**Mobile:** Consumes API · **Web:** Consumes API  
**AI Used:** N/A  
**Dependencies:** Supabase edge deployment  
**Commercial Category:** Enterprise · **Confidence:** 88%

### Third-party Integrations
**Status:** 🟡 Mostly Implemented  
**Backend:** Twilio, MSG91, Gupshup, FCM, Razorpay, Anthropic/OpenRouter  
**Frontend:** Provider config screens  
**Mobile:** Yes · **Web:** Yes  
**AI Used:** Yes (AI providers)  
**Dependencies:** API keys per provider  
**Commercial Category:** Core ERP · **Confidence:** 82%

---

## MEDIA & STORAGE

### Cloud Storage
**Status:** 🟢 Fully Implemented  
**Backend:** Supabase storage buckets + `storage_service.ts`  
**Frontend:** Upload flows in admissions, memories, education  
**Mobile:** Limited · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Supabase storage  
**Commercial Category:** Core ERP · **Confidence:** 85%

### Storage Quotas
**Status:** 🔴 Planned  
**Backend:** Per-file size limits only (50 MiB memories, 25 MiB admissions)  
**Frontend:** No org-level quota UI  
**Mobile:** No · **Web:** No  
**AI Used:** No  
**Dependencies:** Entitlement layer extension needed  
**Commercial Category:** Add-on · **Confidence:** 88%

### File Uploads
**Status:** ✅ Production Ready  
**Backend:** Storage foundation migration  
**Frontend:** Admissions documents, memories, education imports  
**Mobile:** Limited · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Storage service  
**Commercial Category:** Core ERP · **Confidence:** 87%

### Photos
**Status:** 🟢 Fully Implemented  
**Backend:** Memories module, admissions photos  
**Frontend:** School memories screens, memory events  
**Mobile:** Limited · **Web:** Yes  
**AI Used:** No  
**Dependencies:** `PHASE5_API_ENABLED`  
**Commercial Category:** Premium · **Confidence:** 80%

### Documents
**Status:** ✅ Production Ready  
**Backend:** Admissions docs, education PDFs, receipt PDFs  
**Frontend:** Document checklist, PDF services  
**Mobile:** Yes (receipts) · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Storage + report export  
**Commercial Category:** Core ERP · **Confidence:** 86%

### Backup
**Status:** 🟠 Partially Implemented  
**Backend:** Batch7 storage/backups mentioned in archived certs; no full live backup API confirmed in audit  
**Frontend:** `backup_restore_screen.dart` — UI shell with job dialogs  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Cloud export destinations (Google Drive, OneDrive described)  
**Commercial Category:** Enterprise · **Confidence:** 55%

### Archive
**Status:** 🟡 Mostly Implemented  
**Backend:** Education paper `archived` lifecycle state  
**Frontend:** Archive actions in education module  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Education module  
**Commercial Category:** Premium · **Confidence:** 72%

### Media Library
**Status:** 🟡 Mostly Implemented  
**Backend:** Memories repository  
**Frontend:** School memories module (not generic DAM)  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Phase 5  
**Commercial Category:** Premium · **Confidence:** 70%

---

## CRM & GROWTH

### Admission CRM
**Status:** ✅ Production Ready  
**Backend:** Full admissions funnel API  
**Frontend:** Leads, scoring, counselor leaderboard, pipeline  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes — admissions assistant  
**Dependencies:** Core admissions  
**Commercial Category:** Core ERP · **Confidence:** 92%

### Marketing CRM
**Status:** 🟢 Fully Implemented  
**Backend:** Growth platform API — `module.marketing` (Professional+)  
**Frontend:** `/growth` — campaigns, inquiries dashboard  
**Mobile:** No · **Web:** Yes  
**AI Used:** Limited  
**Dependencies:** Evolution repo  
**Commercial Category:** Premium · **Confidence:** 83%

### Lead Management
**Status:** ✅ Production Ready  
**Backend:** Admissions leads API  
**Frontend:** Leads table, profile panel, follow-up history, timeline  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes — lead scoring display  
**Dependencies:** Admissions  
**Commercial Category:** Core ERP · **Confidence:** 90%

### Counsellor Portal
**Status:** 🟡 Mostly Implemented  
**Backend:** Counselor metrics in admissions reports  
**Frontend:** Counselor leaderboard, lead assignment — no separate portal persona  
**Mobile:** No · **Web:** Yes  
**AI Used:** Limited  
**Dependencies:** Admissions RBAC  
**Commercial Category:** Core ERP · **Confidence:** 72%

### Campaign Management
**Status:** 🟢 Fully Implemented  
**Backend:** Growth campaigns + alumni campaigns  
**Frontend:** Create campaign dialogs, achievement promotion multi-channel  
**Mobile:** No · **Web:** Yes  
**AI Used:** Limited  
**Dependencies:** Marketing entitlement  
**Commercial Category:** Premium · **Confidence:** 80%

---

## COMMUNITY

### Alumni Portal
**Status:** ✅ Production Ready  
**Backend:** `ALUMNI_API_ENABLED` ON  
**Frontend:** 9 alumni screens — registry, events, donations  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** `module.alumni` (Professional+)  
**Commercial Category:** Premium · **Confidence:** 86%

### Alumni Network
**Status:** 🟡 Mostly Implemented  
**Backend:** Alumni registry + mentorship matching  
**Frontend:** Mentorship screen, campaigns  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Alumni module  
**Commercial Category:** Premium · **Confidence:** 75%

### Events
**Status:** 🟢 Fully Implemented  
**Backend:** Alumni events API  
**Frontend:** Alumni events screen + parent events  
**Mobile:** Yes (parent events) · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Alumni, parent modules  
**Commercial Category:** Premium · **Confidence:** 82%

### Donations
**Status:** 🟢 Fully Implemented  
**Backend:** Alumni donations tracking  
**Frontend:** Alumni donations screen  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Alumni module  
**Commercial Category:** Premium · **Confidence:** 80%

### Community Portal
**Status:** ❌ Not Available  
**Backend:** None  
**Frontend:** No standalone community module  
**Mobile:** No · **Web:** No  
**AI Used:** No  
**Dependencies:** N/A  
**Commercial Category:** Future Product · **Confidence:** 90%

---

## WEBSITE

### School Website Builder
**Status:** 🔴 Planned  
**Backend:** None  
**Frontend:** "School Website" is publish destination in achievement promotion only  
**Mobile:** No · **Web:** No  
**AI Used:** No  
**Dependencies:** CMS — not built  
**Commercial Category:** Future Product · **Confidence:** 92%

### Dynamic Pages
**Status:** 🟠 Partially Implemented  
**Backend:** Dynamic widget platform (dashboard layouts, not public pages)  
**Frontend:** Dynamic widgets layout editor/runtime  
**Mobile:** No · **Web:** Yes (internal)  
**AI Used:** Limited  
**Dependencies:** Evolution, widget platform  
**Commercial Category:** Premium · **Confidence:** 70%

### News
**Status:** 🟠 Partially Implemented  
**Backend:** Notices/broadcasts  
**Frontend:** Notices, achievement promotion publishing  
**Mobile:** Yes · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Communication  
**Commercial Category:** Core ERP · **Confidence:** 68%

### Gallery
**Status:** 🟡 Mostly Implemented  
**Backend:** Memories/photos storage  
**Frontend:** School memories events  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Phase 5 memories  
**Commercial Category:** Premium · **Confidence:** 72%

### Blog
**Status:** ❌ Not Available  
**Backend:** None  
**Frontend:** None  
**Mobile:** No · **Web:** No  
**AI Used:** No  
**Dependencies:** N/A  
**Commercial Category:** Future Product · **Confidence:** 95%

### SEO
**Status:** 🔴 Planned  
**Backend:** None  
**Frontend:** None  
**Mobile:** No · **Web:** No  
**AI Used:** No  
**Dependencies:** Website builder — prerequisite missing  
**Commercial Category:** Future Product · **Confidence:** 95%

---

## TRANSPORT

### Live GPS
**Status:** 🟠 Partially Implemented  
**Backend:** Vehicle `gpsDeviceId` in models  
**Frontend:** `transport_tracking_screen.dart` — explicit placeholder, no live map SDK  
**Mobile:** No · **Web:** Yes (placeholder)  
**AI Used:** No  
**Dependencies:** Third-party GPS integration — not built  
**Commercial Category:** Add-on · **Confidence:** 88%

### Route Planning
**Status:** 🟢 Fully Implemented  
**Backend:** Transport routes API  
**Frontend:** Routes, vehicles, drivers, allocation screens  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Transport module  
**Commercial Category:** Premium · **Confidence:** 85%

### Driver App
**Status:** 🔴 Planned  
**Backend:** Driver records in admin transport only  
**Frontend:** No driver mobile persona  
**Mobile:** No · **Web:** No  
**AI Used:** No  
**Dependencies:** New mobile shell needed  
**Commercial Category:** Add-on · **Confidence:** 90%

### Parent Tracking
**Status:** 🟡 Mostly Implemented  
**Backend:** Parent transport API  
**Frontend:** `parent_transport_screen.dart` — route/stop info (not live map)  
**Mobile:** Yes · **Web:** No  
**AI Used:** No  
**Dependencies:** Transport module  
**Commercial Category:** Premium · **Confidence:** 78%

### Bus Attendance
**Status:** 🟢 Fully Implemented  
**Backend:** Transport attendance in transport repo  
**Frontend:** Transport attendance screen  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Transport + SIS  
**Commercial Category:** Premium · **Confidence:** 82%

---

## SECURITY

### Audit Logs
**Status:** ✅ Production Ready  
**Backend:** `AUDIT_API_ENABLED` ON + upload queue  
**Frontend:** Per-module audit (admissions, parent, teacher, management, etc.)  
**Mobile:** Yes · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Audit logger + upload service  
**Commercial Category:** Core ERP · **Confidence:** 90%

### Device Management
**Status:** 🟠 Partially Implemented  
**Backend:** FCM device token registration  
**Frontend:** Session metadata; no MDM console  
**Mobile:** Yes (push tokens) · **Web:** Limited  
**AI Used:** No  
**Dependencies:** Communication  
**Commercial Category:** Enterprise · **Confidence:** 60%

### Session Management
**Status:** ✅ Production Ready  
**Backend:** JWT refresh rotation, revocation, reuse detection  
**Frontend:** `auth_session_manager.dart`, secure storage  
**Mobile:** Yes · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Auth API  
**Commercial Category:** Core ERP · **Confidence:** 92%

### Data Encryption
**Status:** ✅ Production Ready  
**Backend:** TLS in production, encrypted storage patterns  
**Frontend:** `flutter_secure_storage` on native  
**Mobile:** Yes · **Web:** Partial (SharedPreferences fallback)  
**AI Used:** No  
**Dependencies:** Platform secure storage  
**Commercial Category:** Core ERP · **Confidence:** 88%

### Backup (Security)
**Status:** 🟠 Partially Implemented  
**Backend:** Not confirmed live  
**Frontend:** Backup restore screen UI only  
**Mobile:** No · **Web:** Yes (UI)  
**AI Used:** No  
**Dependencies:** Backup infrastructure  
**Commercial Category:** Enterprise · **Confidence:** 55%

### Restore
**Status:** 🟠 Partially Implemented  
**Backend:** Not confirmed live  
**Frontend:** Backup restore screen UI only  
**Mobile:** No · **Web:** Yes (UI)  
**AI Used:** No  
**Dependencies:** Backup infrastructure  
**Commercial Category:** Enterprise · **Confidence:** 50%

---

## SAAS PLATFORM

### Subscription Management
**Status:** 🟢 Fully Implemented  
**Backend:** Plans catalog, org subscriptions, 402 enforcement (opt-in)  
**Frontend:** Plan entitlements screen, org plan assignment  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** `ENTITLEMENT_API_ENABLED`  
**Commercial Category:** Enterprise · **Confidence:** 85%

### Billing
**Status:** 🔴 Planned  
**Backend:** Explicitly out of scope in B2 migration  
**Frontend:** Control center billing screen — display/probe only  
**Mobile:** No · **Web:** Yes (stub)  
**AI Used:** No  
**Dependencies:** Payment collection — not built  
**Commercial Category:** Enterprise · **Confidence:** 90%

### SMS Pack Management
**Status:** 🔴 Planned  
**Backend:** None  
**Frontend:** None  
**Mobile:** No · **Web:** No  
**AI Used:** No  
**Dependencies:** Quota system  
**Commercial Category:** Add-on · **Confidence:** 92%

### Storage Pack Management
**Status:** 🔴 Planned  
**Backend:** None  
**Frontend:** None  
**Mobile:** No · **Web:** No  
**AI Used:** No  
**Dependencies:** Quota system  
**Commercial Category:** Add-on · **Confidence:** 92%

### AI Token Management
**Status:** 🔴 Planned  
**Backend:** Usage metadata only  
**Frontend:** AI access preferences (user-level, not tenant quota)  
**Mobile:** Limited · **Web:** Yes  
**AI Used:** N/A  
**Dependencies:** Entitlement extension  
**Commercial Category:** Add-on · **Confidence:** 88%

### Organization Builder
**Status:** ✅ Production Ready  
**Backend:** Real provisioning jobs — `ORGANIZATION_BUILDER_API_ENABLED` ON  
**Frontend:** Hub, AI interview, preview, provisioning — `platform/organization_builder/`  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes — AI interview for org setup  
**Dependencies:** `feature.organization_builder` (Enterprise) + chain scope  
**Commercial Category:** Enterprise · **Confidence:** 88%

### Tenant Management
**Status:** ✅ Production Ready  
**Backend:** RLS multi-tenant, tenant context interceptors  
**Frontend:** Control Center schools, school config discovery  
**Mobile:** N/A · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Supabase RLS, `SCHOOL_CONFIG_API_ENABLED`  
**Commercial Category:** Enterprise · **Confidence:** 90%

---

## FUTURE PRODUCTS & ADDITIONAL MODULES DISCOVERED

### Question Intelligence Platform
**Status:** ✅ Production Ready  
**Backend:** Full education module — bank, papers, AI gap-fill, blueprint solver  
**Frontend:** `lib/features/education/` — bank, papers, import, PDF  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes — Anthropic/OpenRouter generation  
**Dependencies:** `EDUCATION_API_ENABLED` ON  
**Commercial Category:** Future Product (or Premium add-on) · **Confidence:** 90%

### AI Question Generator
**Status:** ✅ Production Ready  
**Backend:** `education_ai_question_gapfill.ts`, generator routes  
**Frontend:** Generate/regenerate with AI in education UI  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes  
**Dependencies:** Question intelligence platform  
**Commercial Category:** Future Product · **Confidence:** 88%

### Blueprint Generator
**Status:** ✅ Production Ready  
**Backend:** Blueprint solver in education module  
**Frontend:** Paper blueprint workflow  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes  
**Dependencies:** Education module  
**Commercial Category:** Future Product · **Confidence:** 85%

### Question Bank
**Status:** ✅ Production Ready  
**Backend:** `education_question_intelligence.sql` — fingerprint dedup, provenance  
**Frontend:** Education bank screens  
**Mobile:** No · **Web:** Yes  
**AI Used:** Limited  
**Dependencies:** Education API  
**Commercial Category:** Future Product · **Confidence:** 88%

### Assessment Platform
**Status:** 🟡 Mostly Implemented  
**Backend:** Exam lifecycle + education papers (not unified CBT platform)  
**Frontend:** Exam admin + education papers — no secure exam workspace/CBT  
**Mobile:** Exam views only · **Web:** Yes  
**AI Used:** Yes — exam intelligence  
**Dependencies:** Exam + education modules  
**Commercial Category:** Future Product · **Confidence:** 75%

### Dynamic Widget Platform (B11)
**Status:** ✅ Production Ready  
**Backend:** Widget pack catalog, layout persistence  
**Frontend:** Layout editor + runtime renderer  
**Mobile:** No · **Web:** Yes  
**AI Used:** Limited  
**Dependencies:** Evolution API  
**Commercial Category:** Enterprise · **Confidence:** 85%

### Achievement Promotion / Multi-channel Publishing
**Status:** 🟢 Fully Implemented  
**Backend:** Phase 5 promotion workflows  
**Frontend:** Draft → generate → approve → publish to apps/WhatsApp/social  
**Mobile:** Targets mobile apps · **Web:** Yes  
**AI Used:** Yes — asset generation  
**Dependencies:** `PHASE5_API_ENABLED`  
**Commercial Category:** Premium · **Confidence:** 80%

### Student 360 / Employee 360
**Status:** 🟢 Fully Implemented  
**Backend:** Student360 + employee intelligence repos  
**Frontend:** `/student-360/:id`, `/employees/360/:id`  
**Mobile:** Teacher student-risk (subset) · **Web:** Yes  
**AI Used:** Yes  
**Dependencies:** SIS, HR, intelligence  
**Commercial Category:** Premium · **Confidence:** 82%

### School Memories
**Status:** 🟢 Fully Implemented  
**Backend:** Phase 5 memories repo  
**Frontend:** Memory events, photo galleries  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Storage, phase5  
**Commercial Category:** Premium · **Confidence:** 78%

### Operations Hub / Resource Optimization
**Status:** 🟡 Mostly Implemented  
**Backend:** Phase 5 APIs ON  
**Frontend:** `/operations/hub`, `/resource-optimization`  
**Mobile:** No · **Web:** Yes  
**AI Used:** Limited  
**Dependencies:** Phase 5  
**Commercial Category:** Enterprise · **Confidence:** 72%

### Control Center (Platform Operator)
**Status:** ✅ Production Ready  
**Backend:** 15+ platform screens API  
**Frontend:** Schools, CRM, billing probe, monitoring, white-label ops  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes — platform intelligence (partial)  
**Dependencies:** SuperAdmin RBAC  
**Commercial Category:** Enterprise (internal) · **Confidence:** 86%

### Industry Vertical Packs (Healthcare, Salon, Restaurant, Accommodation)
**Status:** 🟠 Partially Implemented  
**Backend:** API repos exist; all vertical flags **OFF** live  
**Frontend:** 20 screens across 4 verticals with intelligence screens  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes (mock when off)  
**Dependencies:** Vertical API enablement  
**Commercial Category:** Future Product · **Confidence:** 80%

### Branch / Franchise Management
**Status:** 🟠 Partially Implemented  
**Backend:** Mock-only repositories (no API repo)  
**Frontend:** Branch + franchise screens  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Multi-branch entitlement  
**Commercial Category:** Enterprise · **Confidence:** 65%

### Continuity Module
**Status:** 🟠 Partially Implemented  
**Backend:** `CONTINUITY` flag OFF live  
**Frontend:** `/sis/continuity` screen  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** SIS  
**Commercial Category:** Premium · **Confidence:** 60%

### Academic Operations
**Status:** 🟠 Partially Implemented  
**Backend:** `ACADEMIC_OPERATIONS_API_ENABLED` OFF  
**Frontend:** Routed but mock at live  
**Mobile:** No · **Web:** Yes  
**AI Used:** Unknown  
**Dependencies:** Academic module  
**Commercial Category:** Premium · **Confidence:** 55%

### Platform Operations / Platform Intelligence
**Status:** 🟠 Partially Implemented  
**Backend:** OFF live  
**Frontend:** Platform ops hub, tenant isolation, readiness screens  
**Mobile:** No · **Web:** Yes  
**AI Used:** Yes (intelligence screen)  
**Dependencies:** Platform flags  
**Commercial Category:** Enterprise (internal) · **Confidence:** 65%

### Approval Workflow Engine
**Status:** 🟢 Fully Implemented  
**Backend:** `APPROVAL_API_ENABLED` ON  
**Frontend:** Principal approval center, cross-module approval queues  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** RBAC approve permissions  
**Commercial Category:** Core ERP · **Confidence:** 85%

### School Config / Capability Gating (B2)
**Status:** ✅ Production Ready  
**Backend:** Per-school module enable/disable  
**Frontend:** School config discovery screen  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Entitlements + school capabilities  
**Commercial Category:** Enterprise · **Confidence:** 88%

### Parent Experience Hub (Phase 5)
**Status:** 🟢 Fully Implemented  
**Backend:** Parent experience repo  
**Frontend:** 6-tab parent experience hub  
**Mobile:** Yes · **Web:** No  
**AI Used:** Limited  
**Dependencies:** Phase 5  
**Commercial Category:** Premium · **Confidence:** 80%

### Global Search
**Status:** 🟢 Fully Implemented  
**Backend:** Search registry  
**Frontend:** Admin global search overlay  
**Mobile:** No · **Web:** Yes  
**AI Used:** No  
**Dependencies:** Admin shell  
**Commercial Category:** Core ERP · **Confidence:** 78%

---

# Deliverable 2 — Grouped by Implementation Status

### ✅ Production Ready (52)
Authentication, OTP, RBAC, Admissions, SIS, Student/Parent/Teacher Apps, Principal Dashboard, Director Dashboard, Attendance (manual), Timetable, Homework, Exams, Marks Entry, Report Cards, Fee Management, Online/Offline Payments, Library, Inventory, Hostel, Transport, Parent/Teacher Communication, AI Copilot, AI Insights, AI Chat, Predictive Analytics (Enterprise), Analytics, Dashboards, Principal/Director Reports, Payment Gateway, File Uploads, Documents, Admission CRM, Lead Management, Audit Logs, Session Management, Data Encryption, Organization Builder, Tenant Management, Question Intelligence Platform, AI Question Generator, Blueprint Generator, Question Bank, Dynamic Widget Platform, Control Center, School Config, Approval Workflow, Parent App flows (fees/payment), Exam Administration

### 🟢 Fully Implemented (28)
Organization Management, Progress Analytics, SMS, Email, Push, WhatsApp, AI Recommendations, Marketing CRM, Campaign Management, Events, Donations, Route Planning, Bus Attendance, Subscription Management, Achievement Promotion, Student/Employee 360, School Memories, API/OpenAPI, Cloud Storage, Third-party Integrations, Global Search, Parent Experience Hub, Photos, Alumni events/donations path, Operations intelligence surfaces, AI content generation, Platform CRM (sales pipeline)

### 🟡 Mostly Implemented (32)
Staff/Teacher/Parent Management, Lesson Planning, Syllabus Tracking, Scholarships, Discounts, Payroll, Asset Management, Circulars, Announcements, Adaptive AI, AI Reports, Smart Notifications, BI Dashboards, School Branding, Multi-language, Localization, Counsellor Portal, Alumni Network, Parent Tracking, Gallery, Assessment Platform, Operations Hub, Resource Optimization, Custom theme, Archive, Media Library, News, Visitor Management (hostel-scoped)

### 🟠 Partially Implemented (28)
Multi School (ops), Assignments, Accounting, Expense Management, GPS/Live GPS, Visitor/Gate Pass, Workflow Automation, Custom Reports, White Label, Custom Theme, Dynamic Pages (internal), Backup/Restore, Device Management, Branch/Franchise, Continuity, Academic Operations, Platform Ops/Intelligence, Vertical packs (UI only live), Marketing CRM overlap areas, Gate pass, Storage per-file limits only

### 🔴 Planned (13)
Face Recognition, Face ID, Geo-fencing Attendance, Biometric Devices, Face Recognition Devices, RFID attendance, QR Attendance, Custom Domain, Website Builder, Blog, SEO, Billing collection, SMS/Storage/AI token packs, Driver App, Community Portal (borderline ❌)

### ❌ Not Available (2)
Reception, Community Portal (standalone), Blog (confirmed absent)

---

# Deliverable 3 — Grouped by Commercial Category

| Category | Features |
|----------|----------|
| **Core ERP** | Auth, OTP, RBAC, Admissions, SIS, Finance, Attendance, Exams, Homework, Timetable, Mobile triad, Principal dashboard, Communication (SMS/email/push), Audit, Session mgmt, Encryption, Admission CRM, Lead mgmt, Parent/teacher comms, Payment gateway, File uploads, Documents, Analytics, Principal reports, Global search, Approvals, School branding (basic) |
| **Premium** | Transport, Hostel, Library, Inventory, Alumni, HR/Payroll, Marketing/Growth, Parent Insights, AI Copilot, Intelligence hub, Homework intelligence, Dynamic dashboards, WhatsApp, Achievement promotion, Memories, Student/Employee 360, Custom theme, Multi-language, GPS (when built), Inventory AI, Finance intelligence |
| **Enterprise** | Director dashboard, Multi-school/trust org, Predictive analytics, Organization Builder, White label, Control Center, Tenant/platform ops, Workflow automation, BI dashboards, Custom domain (future), Backup/restore, API access, Branch/franchise |
| **Add-on** | Live GPS tracking, Driver app, Biometric/RFID/QR attendance, SMS packs, Storage packs, AI token packs, Face recognition |
| **Future Product** | Question Intelligence Platform (could be separate SKU), Assessment/CBT platform, Website builder, Industry verticals (healthcare/salon/restaurant/accommodation), Community portal, Blog/SEO |

---

# Deliverable 4 — Suggested Plan Packaging

### Base Plan (maps to **Standard** — single school, ≤500 students)
- Authentication + OTP + RBAC
- Admissions CRM + Lead management
- SIS / Student registry
- Finance: fee structures, collections, offline payments
- Attendance (manual)
- Exams + marks entry + report cards
- Homework + timetable
- Principal dashboard + basic analytics
- Parent / Teacher / Student mobile apps
- SMS + email + push notifications
- Basic announcements/notices
- Audit logs + session security
- School branding (logo/colors via onboarding)

### Professional Plan (maps to **Professional** — up to 5 schools, ≤2000 students)
Everything in Base, plus:
- Transport, Hostel, Library, Inventory, Alumni, HR/Payroll
- Multi-branch support
- Marketing/Growth engine + campaigns
- Parent Insights (AI)
- AI Copilot + Intelligence hub (non-predictive)
- WhatsApp integration
- Dynamic dashboards + dynamic widgets
- Achievement promotion / multi-channel publishing
- School Memories, Student/Employee 360
- Question Intelligence Platform (strong differentiator — consider gating here)
- Syllabus automation, lesson logs, timetable intelligence
- Finance intelligence, inventory copilot

### Enterprise Plan (unlimited scale, trusts/chains)
Everything in Professional, plus:
- Director dashboard + chain portfolio
- Trust organization module (`module.trust_org`)
- Predictive analytics (fee default, admission conversion, student risk)
- Organization Builder (AI provisioning)
- White-label platform (when backend completed)
- Workflow automation (when live-enabled)
- Control Center access (for Akshara operators / large groups)
- Open API / integration SLA positioning
- Custom reports / BI dashboards
- Backup/restore + advanced security posture

### Marketplace Add-ons (not yet built — future revenue)
| Add-on | Rationale |
|--------|-----------|
| SMS/Message packs | No quota system yet; high-margin consumable |
| Storage packs | Per-school media/memories growth |
| AI token packs | Copilot + question generation consumption |
| Live GPS + parent live map | Transport placeholder exists |
| Biometric / RFID / QR attendance | Hardware partner integrations |
| Driver mobile app | Fleet operations |
| Secure CBT / Exam workspace | Assessment platform extension |
| Website builder + SEO | Achievement promotion already publishes *to* website |
| Industry vertical packs | Healthcare/salon/restaurant/accommodation UI ready |
| White-label deployment + custom domain | Enterprise upsell |

---

# Deliverable 5 — Duplicate or Overlapping Features

| Overlap | Details |
|---------|---------|
| **CRM × 2** | Admissions CRM (school leads) vs Control Center CRM (Akshara platform sales) — same acronym, different buyers |
| **Homework vs Assignments vs Education papers** | Three surfaces for academic work distribution; no clear product boundary |
| **Intelligence vs Copilot vs Evolution vs Predictions** | Four AI entry points with overlapping personas (principal, parent, teacher) |
| **Management dashboard vs Principal Command vs Dynamic Dashboard** | Three principal-facing dashboard concepts |
| **Director marketing vs Growth platform vs Achievement promotion** | Three marketing/campaign surfaces at different org levels |
| **Reports vs Analytics vs Intelligence vs BI** | Per-module fixed reports + analytics screens + AI intelligence — no unified reporting layer |
| **Notices vs Announcements vs Circulars vs Broadcasts** | Same communication primitive, different labels |
| **Inventory assets vs Asset Management** | Assets live inside Inventory, not a separate product |
| **Backup (Security) vs Backup (Media)** | Same UI screen serves both narratives |
| **Multi School vs Director vs Multi-school Operations vs Trust Org** | Chain management split across 4 modules with inconsistent live API status |
| **Onboarding wizards × 3** | Unified onboarding, setup wizard, organization builder interview — powerful but confusing commercially |
| **Student App vs Parent views of same data** | Attendance, homework, exams duplicated across personas |
| **Hostel visitors vs Visitor Management** | School-wide visitor management implied in marketing; only hostel-scoped in code |
| **White Label vs School Branding vs Custom Theme** | Three branding layers with different maturity levels |

---

# Deliverable 6 — Planned but Unimplemented (High Confidence)

1. Face recognition / Face ID attendance  
2. Geo-fencing attendance  
3. Biometric hardware integration  
4. RFID attendance (inventory RFID is placeholder only)  
5. QR code attendance (finance QR is payments only)  
6. Driver mobile app  
7. Reception desk module  
8. School website builder / CMS  
9. Blog + SEO  
10. Custom domain deployment  
11. Commercial billing (invoicing, MRR, renewals, payment collection)  
12. SMS / storage / AI token quota & pack management  
13. Marketplace purchasable add-ons  
14. Community portal (standalone)  
15. Full general ledger / accounting  
16. Dedicated expense management module  
17. Secure CBT exam workspace (referenced in archived docs)  
18. App biometric lock (parent/teacher mobile — documented, not coded)  
19. Live GPS map integration  
20. Platform white-label persistence (API OFF live)

---

# Deliverable 7 — Hidden Gems (Marketing Differentiators)

These are **implemented or substantially built** but easy to under-market:

1. **Question Intelligence Platform** — Full AI question bank, blueprint solver, fingerprint dedup, paper review workflow, live-certified. Rare in Indian school ERP market; could be a standalone product.

2. **8-persona AI Copilot with floating dock** — Role-aware assistants (admissions, finance, principal, teacher, parent…) with screen-context injection and module capability filtering.

3. **Organization Builder with real provisioning** — AI interview → preview → synchronous provision jobs. Enterprise-grade onboarding automation.

4. **Dynamic Widget Platform (B11)** — Drag-and-drop dashboard layouts per role with runtime renderer; "build your own principal dashboard."

5. **Achievement Promotion Center** — Multi-channel publish (parent/student/teacher apps + WhatsApp + Facebook/Instagram + school website destination) from one workflow.

6. **Predictive Analytics (B9)** — Fee default, admission conversion, student risk with AI narrative (Enterprise-gated but built).

7. **Parent Insights with PDF export** — AI-generated multilingual progress summaries without open chat (privacy-friendly positioning).

8. **Principal NL Query Center** — Natural-language principal intelligence tab.

9. **Unified Approval Engine** — Cross-module approvals (admissions, finance, payroll, expenses) in one principal queue.

10. **Entitlement + School Capability dual gating** — Plan ceiling × per-school module toggles = flexible packaging without code deploys.

11. **Razorpay Universal Payment Engine** — Parent app pay-now with stub mode for pilots; finance QR/UPI for offline schools.

12. **AI School Builder in onboarding** — Prefill school config from AI during unified onboarding (B7).

13. **Student 360 / Employee 360** — Unified risk/performance profiles pulling intelligence across modules.

14. **Industry vertical packs** — Healthcare, salon, restaurant, accommodation UIs exist (future expansion beyond schools).

15. **OpenAPI contract registry** — Production API with schema validation; enterprise integration story.

16. **Timetable Intelligence** — Automation, optimization, substitute manager, room allocation, teacher reassignment wizard.

17. **Inventory AI Copilot** — Stock forecasting and reorder recommendations (unusual for school ERP).

18. **Evolution Growth Platform** — Built-in marketing CRM for schools (campaigns + inquiries), not just admissions.

---

# Deliverable 8 — Total Unique Modules/Features Count

| Layer | Count |
|-------|------:|
| Feature folders (`lib/features/`) | 44 |
| Repository interfaces | 48 |
| Backend shared modules (`supabase/functions/_shared/`) | ~90 |
| Audited named capabilities (requested list) | 130 |
| Additional discovered modules | ~25–35 |
| **Total unique marketable capabilities** | **~155–165** |
| Production-ready or fully implemented (≥🟢) | ~80 (52%) |
| Partial or planned | ~75 (48%) |

---

## Commercial Readiness Notes (for strategy team)

1. **Sell what is live:** `config/live_release.json` enables ~45 API modules on the pilot VPS. Verticals, white-label, workflow, multi-school ops, and platform intelligence are **intentionally OFF** (would 404).

2. **Entitlements exist; billing does not.** You can assign Trial/Standard/Professional/Enterprise and gate modules today, but **cannot collect subscription payments in-product**.

3. **Strongest moat:** AI depth (copilot + intelligence + question platform + predictions) layered on a complete school operations core — broader than typical "attendance + fees" competitors.

4. **Biggest packaging gap:** Advanced attendance (face/geo/RFID/QR) and GPS are **marketing liabilities** if promised — only manual attendance and transport admin are real.

5. **Question Intelligence** is the clearest **separate SKU** candidate (assessment/content product distinct from core ERP).

---

*Audit conducted read-only from codebase inspection (June 2026). Confidence scores reflect code presence, live flag status, and backend/UI completeness — not live VPS runtime verification or commercial certification status.*
