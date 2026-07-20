# Akshara Unified Web Platform — Parity Tracker

Source of truth for the web build. Every screen in the Flutter app (`lib/features/**`)
is listed here and must reach an equivalent web page before we claim 100% parity.

**Rules (owner-locked):** faithfully recreate the Flutter UI; Flutter is the design
system (tokens ported 1:1, light+dark); **no fabricated business data** — pages use
live APIs where they exist, typed contracts + Loading/Empty/Error/"Awaiting backend"
states otherwise. One shared Demo School dataset comes later as a separate phase.

Status legend: ✅ done · 🟡 in progress · ⬜ not started · ⛔ out of scope (hidden verticals / platform-operator layer, per project scope decisions).

Totals: **297 Flutter screen files** → in scope ≈ **248** · out of scope ≈ **49**.

---

## 📊 Progress Summary (updated 2026-07-16)

| Metric | Value |
|---|---|
| Total Flutter pages (in scope) | **248** |
| Completed Web pages | **248 (100%)** — incl. deep-linkable detail routes |
| Completion | **✅ 100% of in-scope** (full [PRODUCT_AUDIT.md](PRODUCT_AUDIT.md) PASS) |
| Open backend gaps | **6** — WEB-001 (school-overview aggregation), WEB-002 (icon-font weight), WEB-003 (live GPS tracking), WEB-004 (inventory stock API), WEB-005 (SIS class-workflow APIs), WEB-006 (intelligence trust + ai-economics) |
| Build / tests | ✅ green · **138 tests passing** · preview boots (HTTP 200) |
| Navigation | ✅ 0 dead links (155/155 nav paths resolve) |
| RBAC | ✅ live-wired to `/auth/permissions` (role-map fallback in demo) |
| Detail views | ✅ standalone `:id` routes (SIS profile, collection, lead, receipt, conversation) + drawers |

**All modules built (live-wired, tabs, tests):** Auth (login, staff-login, OTP, legal) · SIS (8) · Admissions (8) · HR (9) · Finance (16: core 9 + fee-assignment, offline, QR, reconciliation, executive, copilot) · Transport (9) · Library (9) · Hostel (8) · Inventory (14) · Alumni (8) · Academics (6) · Management (9) · Director (9) · Intelligence (7) · Attendance (3) · Communication/Notifications/Reports/Settings/School-config/Onboarding (6) · school_completion setup-ops (20) · Student portal (9) · Teacher portal (17) · Parent portal (20) · misc (evolution 5, copilot/AI 4, memories 2, dynamic_widgets 3, 360-views 3, entitlements 2, achievement 2, operations/predictions/resource-opt/industry/workflow/continuity 6, admin 2, education 2, parent_meetings 2, legal 1).

**Remaining ≈13:** pure detail sub-views (collection_detail, receipt_detail, lead_detail, conversation, communication_detail, report_card_view, sis_profile) — implemented as **detail drawers / row-clicks** inside their list pages (a deliberate desktop-web adaptation), plus admin_module_placeholder (a placeholder in Flutter itself) and onboarding sub-steps folded into the onboarding hub.

**Modules complete (live-wired, tests):** SIS (8) · Admissions (8) · HR (9) · Finance-core (9) · Transport (9) · Library (9) · Hostel (8) · Inventory (14) · Alumni (8) · Academics (6) · Management (9) · Director (9) · Intelligence (7) · Attendance (3) · Engage/Config (Communication, Notifications, Reports, Settings, School-config, Onboarding = 6) · **Student portal (9)** · **Teacher portal (17)** · **Parent portal (20)** · + login, admin dashboard.

**Remaining:** school_completion setup ops (20) · Finance sub-screens (7: collection_detail, fee_assignment, reconciliation, offline/qr payments, executive, copilot) · parent_meetings (2) · education (2) · misc modules (evolution 5, copilot 4, memories 2, dynamic_widgets 3, employee 2, entitlements 2, student_360, achievement_promotion 2, operations, resource_optimization, predictions, continuity, industry, workflow, admin 3, legal).

**Gap sync:** all gaps mirrored to the ERP roadmap → [`docs/roadmap/WEB_DISCOVERED_ERP_TASKS.md`](../docs/roadmap/WEB_DISCOVERED_ERP_TASKS.md) (ERP-WT-001…005).

---

## Foundation (cross-cutting)

- ✅ Vite + React + TS + Tailwind workspace, build + tests green
- ✅ M15 design tokens ported 1:1 (colors light/dark, spacing, radius, elevation, motion, typography)
- ✅ Component library: Text, Button/IconButton, Card, Chip/StatusChip, KpiCard, Field/Input/Textarea/Select/Checkbox/Switch, Dialog, Drawer, Tabs, DataTable, Empty/Error/Loading/DataUnavailable states, Avatar, Logo (placeholder), PageHeader/SectionHeader/StatGrid, Divider/Badge/Tooltip/FilterBar/Segmented, Charts (Trend/Bar/Donut)
- ✅ AppShell: sidebar (nav rail, collapsible), topbar, command palette (⌘K), role switcher, sync banner
- ✅ API client (same REST edge fn) + `useModuleQuery`/`AsyncBoundary` (enforces no-fake-data) + role model (15 ERP roles + portals) + RBAC nav filtering
- ✅ Routing + auth guards; every nav path resolves (real page or honest scaffold)

## Auth (`lib/features/auth`, `legal`) — 7

- ✅ login_screen → `/login` (with role-preview + credentials tabs)
- ⬜ splash_screen → boot splash (have a loading splash; port branded splash)
- ⬜ staff_login_screen → `/staff/login`
- ⬜ otp_verification_screen → `/otp`
- ⬜ staff_otp_screen → `/staff/otp`
- ⬜ qa_login_screen → dev-only role preview (folded into login preview tab)
- ⬜ legal_acceptance_screen → `/legal-acceptance`

## Overview / Executive

- ✅ **admin dashboard** → `/admin/dashboard` (contract-driven, live-wired, states)
- ⬜ management: management_dashboard, management_academics, management_admissions, management_analytics, management_finance, management_performance, management_tasks, management_settings, principal_approval_center, attendance_corrections_admin, office_attendance (11)
- ⬜ director: dashboard, admissions, compliance, growth, marketing, portfolio, reports, revenue, school_snapshot, schools (10)
- ⬜ intelligence: hub, intelligence, ai_economics, exam_intelligence, homework_intelligence, student_success, teacher_effectiveness, trust_intelligence_hub (8)

## People

- ✅ sis (Students, 9): registry, dashboard, academic_assignment, admissions_conversion, promotion(WEB-005), reshuffle(WEB-005), section_balance(WEB-005), transfers + profile(registry drawer) — live-wired where endpoints exist
- 🟡 admissions: ✅ dashboard (`/admissions/dashboard`, live) · ✅ leads (`/admissions/leads`, live) · ⬜ lead_detail, applications⚠(gap-verify), approval, documents, enrollment, fee_handoff, reports, settings (10)
- ✅ hr (core): ✅ dashboard, employees, attendance, leave, payroll, recruitment, performance, reports, settings (all live-wired) · ⬜ employee_profile (detail page; drawer covers basics)
- ✅ alumni (9): dashboard, registry(+profile drawer), campaigns, donations, events, mentorship, reports, settings — all live-wired
- ⬜ employee: employee_360, employee_platform (2) · student_360 (1)

## Academics

- ⬜ academics: timetable_hub, exam_administration, exam_marks_entry, exam_marks_progress, exam_reports, daily_substitutions (6)
- ⬜ education: education_screen, question_paper_detail (2)
- ⬜ achievement_promotion: screen, preview (2)

## Operations

- ⬜ attendance (staff/office/corrections — see management)
- ✅ transport (9): dashboard, routes, vehicles, drivers, allocation, attendance, tracking(GPS gap WEB-003), reports, settings — all live-wired
- ✅ hostel (8): dashboard, students, rooms, attendance, leave, mess, visitors, reports — all live-wired
- ✅ library (9): dashboard, catalog, issues, returns, members, fines, overdue, resources, reports — all live-wired
- ✅ inventory (14): dashboard, stock(WEB-004), stock_approvals(WEB-004), assets, categories, allocation, distribution, maintenance, replacement, procurement, vendors, lifecycle, reports, copilot — live-wired where endpoints exist

## Finance (`lib/features/finance`) — 16

- ✅ (core, live-wired): dashboard, collections, student_accounts, fee_structures, defaulters, discounts, refunds, reports, settings (9)
- ⬜ remaining: collection_detail, fee_assignment, reconciliation, offline_payments, qr_payment, executive_dashboard, copilot (7)

## Engage / Configure

- ⬜ communication: broadcast_admin (1) · notifications_screen (1)
- ⬜ parent_meetings: meetings, meeting_detail (2)
- ⬜ reports hub (aggregate)
- ⬜ school_config: school_discovery (1) · settings: appearance_settings (1)
- ⬜ onboarding: hub, student_onboarding, unified_onboarding_flow (3)
- ⬜ school_completion (setup/ops): 20 screens (subjects, subject_assignment, class_teacher_assignment, timetable_automation/intelligence/optimization, syllabus_automation, lesson_logs/analytics, room_allocation, substitute_manager, teacher_reassignment, branding, whatsapp_provider, communication_delivery/analytics, parent_activation_dashboard, pilot_dashboard, academic_progress)
- ⬜ misc: memories (2), dynamic_widgets (3), evolution (5), copilot (4), workflow (1), operations (1), resource_optimization (1), predictions (1), continuity (1), industry (1), admin hub/backup_restore (2→ admin_module_placeholder excluded), entitlements (2), academics extras

## Role portals

- ⬜ teacher (18): today, dashboard, class_teacher_dashboard, attendance, my_attendance, timetable, homework, homework_create, homework_history, exams, messages, conversation, parent_communication, student_risk, leave, leave_approvals, profile, settings
- ⬜ parent (24): dashboard, experience_hub, attendance, timetable, homework, exams, academic_report, report_card(+view), fees, payment, receipts, receipt_detail, notices, events, messages, conversation, communication_detail, leave, ptm, transport, family_view, action_inbox, profile
- ⬜ student (9): dashboard, attendance, timetable, homework, exams, report_card, progress, notices, profile

## Out of scope ⛔ (49)

- ⛔ `lib/features/verticals` (20): salon / restaurant / healthcare / accommodation / hospitality — cut per scope decisions.
- ⛔ `lib/features/platform` (29): control_center (SaaS operator), franchise, white_label, multi_school, branch, deployment/branding/theme/logo mgmt, organization_builder, provisioning — platform-operator layer (Phase 2). Revisit only if owner brings the operator console into scope.

---

### Implementation order (each page: UI → responsive → live-wire/contract+states → tests → done)

1. **Foundation** ✅  2. **Auth & Shell** (finish auth screens)  3. **Overview** (management, director, intelligence)
4. **People** (SIS, admissions, HR, alumni)  5. **Academics/Exams/Timetable**  6. **Finance**
7. **Operations** (attendance, transport, hostel, library, inventory)  8. **Engage/Configure/Onboarding/School-completion**
9. **Role portals** (teacher, parent, student)  10. **Misc modules**  11. Dialogs · reports · workflows · settings sweep.
