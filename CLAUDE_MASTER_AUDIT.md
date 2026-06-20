# CLAUDE Master Audit — ERP Hardening Execution Status

Single source of truth for the cross-domain authorization/correctness hardening.
Per-domain detail lives in code + tests; this file tracks **status only**.

Legend: ✅ done & certified · 🟡 in progress · ⬜ not started

---

# 🟡 ACTIVE PHASE — WORKSPACE & UX CONSOLIDATION

> ERP Hardening + Domain Certification = **COMPLETE** (everything below the divider).
> New phase goal: make Akshara feel **simple, modern, fast, beautiful, premium —
> demo-grade so schools buy on sight.** NOT adding features/modules/domains.
> Audit-driven (WORKSPACE_ARCHITECTURE_AUDIT, MASTER_RECOMMENDATION_REPORT,
> UI_UX_AUDIT_REPORT, MOBILE_FIRST_AUDIT, SCREEN_CONSOLIDATION_REPORT,
> REAL_WORLD_SCHOOL_AUDIT, PROJECT_HEALTH_AUDIT, IDEAS_BACKLOG).
> Batches: 1 Workspace Architecture Enforcement · 2 Navigation Simplification ·
> 3 Mobile-first · 4 Dashboard modernization · 5 Screen consolidation.
> Per batch: Audit → Plan → Implement → Test → Certify → update this file.

## ✅ UX Batch 1 — Workspace Architecture Enforcement = DONE & CERTIFIED (2026-06-20)
All 5 steps complete. Certified end-to-end: `flutter analyze` **0 errors**; full
Flutter suite **2112 pass** (1 staging-only skip); +19 new tests across the steps.
- **Step 1** Multi-role identity (a user holds several roles; permissions union).
- **Step 2** First-class `Workspace` abstraction (lib/core/workspace/) + role→workspace
  registry (many-to-many) + providers (userWorkspaces, activeWorkspace, hasMultiple).
- **Step 3** Persona leaks closed — schoolAdmin/management no longer hold
  Salon/Restaurant/Healthcare/Accommodation/Industry/WhiteLabel/PlatformOps perms
  (superAdmin remains platform owner); nav already gated by SchoolBuildScope.
- **Step 4** Workspace-scoped Admin Hub (grid shows only the active workspace's
  modules) + **premium workspace switcher** (gradient chips) for multi-hat users +
  premium graphic module cards + **QA "Teacher + Inventory" (Surendra) demo persona**.
- **Step 5** Cross-shell leak closed — `/teacher/*` reachable only by staff who
  actually hold the teacher role (multi-hat); non-teaching staff bounced. Also
  removed the latent staff→/parent,/student fall-through.

### Switcher reachability — FIXED (2026-06-20, follow-up; was wrongly deferred)
The earlier "switcher only on Admin Hub" was a **functional gap**, not polish: a
multi-hat user could enter a workspace but not switch to another without returning
to the hub or logging out. Now closed:
- New compact `WorkspaceSwitcherButton` (app-bar pill → "Switch workspace" bottom
  sheet) lives in **every shell's chrome**: `AdminAppBar` (admin/staff) and the
  shared `AksharaAppBar` (teacher/parent/student). Auto-hides for single-workspace
  users, so single-role personas see zero change (goldens stay pixel-identical).
- A multi-role user can move between assigned workspaces **from any screen, any
  shell**, both directions (admin→teacher AND teacher→admin), at any time.
- Startup verified: a multi-hat user lands where the switcher is present.
- `WorkspaceSwitcher` file moved to `lib/shared/widgets/` (it's now cross-cutting).
- Coverage: 3 router integration tests (startup reachable; switch admin→teacher;
  switch back teacher→inventory) + a visual golden of the multi-hat hub.
- Visually validated (golden render): app-bar switcher + gradient active/outline
  chips + workspace-scoped grid + premium gradient module cards.
- Certified: `flutter analyze` 0 errors; full suite **2116 pass** (1 staging skip).

### Original plan (for reference)

**Target model:** USER → ROLE → WORKSPACE → TASK. **Today:** USER → ROLE →
(one flat 22-module ERP grid) → TASK. The WORKSPACE layer is missing.

**Findings — all re-verified against current code (2026-06-20):**
- V1 🔴 No `Workspace` abstraction exists in `lib/` (confirmed: 0 results).
- V2 🔴 Single-role model — `AuthState.role` (auth_models.dart:152) & `erpRole`
  (auth_claims.dart:21) are single-valued; a Teacher+InventoryManager is
  unrepresentable.
- V3 🟠 Flat global grid — `kAllAdminNavDestinations` (admin_navigation_provider.dart:13-190)
  lists 22 modules incl. 6 non-school verticals (Healthcare, Salon, Restaurant,
  Accommodation, White Label, Platform Ops), filtered subtractively.
- V4 🟠 Persona leak — `schoolAdmin` (role_permissions.dart:190-194) & `management`
  (535-547) receive all 5 vertical view-perms; a school admin can see
  Salon/Restaurant/Healthcare. (principal/VP already clean.)
- V5 🟠 Cross-shell leak — any `UserRole.staff` may enter `/teacher/*`
  unconditionally (`app_router.dart:2272-2273`; `route_guards.dart:177-179`).
- V6 🟠 No workspace switcher UI in production (QA-only switcher = logout).

**Scope decision (RESOLVED 2026-06-20 — owner chose MULTI-ROLE REWRITE FIRST):**
build the many-roles-per-user identity model as the foundation, then scope
workspaces on top. Larger/riskier (touches auth/claims/token/test accounts) but
the correct end-state and the true precondition for the workspace model.

**Planned steps (each ends with tests + `flutter analyze` 0-err certification):**
1. ✅ **Multi-role identity model = DONE & CERTIFIED (2026-06-20).** A user can now
   hold several `ErpRole`s. `AuthClaims.erpRoles` is the source of truth (ordered,
   primary first); legacy `erpRole`/`role`/`forRole`/`demoForRole(erpRole:)` kept
   as primary-role shims so all ~60 existing RBAC tests + call sites are
   unchanged. `UserPermissions.forRoles` / `RolePermissionMatrix.permissionsForRoles`
   **union** permissions across all held roles; `RbacService` gains `roles` +
   `hasRole`. Role guards (RoleGuard, ControlCenterGuard) now satisfy on ANY held
   role. Session round-trips multiple roles (toJson writes `roles`; fromJson reads
   `roles`, falls back to legacy `role`). `signInStaff(erpRoles:)` can mint a
   multi-hat session (Step 4 switcher will consume it; demo-login UI wiring +
   Surendra Teacher+Inventory account deferred to Step 4). Proof: Teacher+Inventory
   union has both markAttendance AND manageInventory, neither alone leaks the
   other, neither grants control center. Certified: `flutter analyze` 0 errors;
   full suite **2093 pass** (+7 new multi-role tests; 1 staging-only skip).
2. **Workspace abstraction** — first-class `Workspace` (Teacher, Principal, Exam,
   Finance, Front Office, Inventory, Transport, Hostel, Library + Parent/Student
   app shells) + a many-to-many `role → workspace(s)` registry (now genuinely
   multi-hat). Model + mapping + tests; no UI yet.
3. **Scope trim / strip persona leaks** — remove vertical view-perms from school
   roles; gate non-school verticals out of the default school build's nav. A
   principal/schoolAdmin never sees Salon/Restaurant/Healthcare/etc.
4. **Workspace-scoped navigation + switcher** — replace the flat 22-card grid
   with workspace-scoped nav; premium launcher + hat-switcher for multi-workspace
   users. Demo-grade visuals (new graphic cards, clean hierarchy).
5. **Close cross-shell leakage** — `/teacher/*` reachable only by users whose
   roles include teaching; fix any guard-bypassing routes (principal-command,
   growth). Guard tests.

**Future-readiness check (per phase mandate — design only, validated in step 2):**
- Future school types (IIT/NEET Foundation, Residential, Semi-Residential,
  Corporate, Small) = different workspace SETS over the same abstraction → the
  step-2 `Workspace` + registry supports them as data, no structural block.
- AI School Builder evolution (School Profile → AI config → dynamic workspaces /
  dashboards / nav / cards) sits directly on the step-2 registry: "AI config"
  becomes the producer of the role→workspace map. Step 2 is the enabling layer.
- **Explicit guardrail:** do NOT build future school types or AI School Builder
  now; only ensure Batch 1 doesn't preclude them. (See IDEAS_BACKLOG +
  docs/FUTURE_VISION_AI_SCHOOL_BUILDER.md.)

---

## ✅ UX Batch 2 — Navigation Simplification = DONE & CERTIFIED (2026-06-20)
Goal: ≤5 primary bottom-nav items (4 tabs + a "More" tab), fix the bottom-nav
selected-state highlight, and surface the workspace switcher consistently.
Owner decisions honoured: Admin NavigationRail left as-is (admin mobile → Batch
3); Parent **Messages promoted** to a primary tab; switcher kept in the app bar
**and** surfaced in the More sheet; **Parent done first** (largest UX issue).

- **Step 1 — Shared nav model.** New `PersonaNavSpec` (primary + overflow
  destinations) + `PersonaBottomNav` / `MoreNavSheet`
  (lib/shared/navigation/persona_nav.dart) replace the three hand-rolled
  per-shell `_destinations` lists and `_selectedIndex` ladders. Single source of
  truth — the teacher/student/parent shells now just declare a `navSpec`.
  `PersonaNavDestination.matchPrefixes` carries the route→tab mapping that used
  to drift in the per-shell ladders.
- **Step 2 — Selected-state highlight fixed.** Root cause: the selected bottom-nav
  icon was `scheme.primary` sitting **inside** the `primaryContainer` indicator
  pill — a low-contrast, washed-out highlight. Now `onPrimaryContainer` (matches
  the drawer theme) in `_navigationBarTheme` (lib/theme/app_theme.dart). Fixes
  all three bottom-nav personas at once.
- **Step 3 — "More" tab + ≤5 primary.** Each bottom-nav shell now shows 4 primary
  tabs + a premium "More" grid sheet:
  - Parent: Home · Academics · Fees · **Messages** · More
    (More = Leave, Notices, Events, PTM, Transport, Profile). This **un-buries
    the 8 screens** that were previously folded invisibly into the Home tab —
    the batch's biggest win.
  - Teacher: Home · Classes · Teach · Messages · More
    (More = Timetable, Leave, Parent Concerns).
  - Student: Home · Learn · Schedule · Results · More
    (More = Report Card, Progress, Notices, Profile).
- **Step 4 — Workspace switcher consistency.** Kept in every shell's app bar
  (Batch 1) **and** surfaced at the top of the More sheet (auto-hidden for
  single-workspace users). A multi-hat user can now switch from the More sheet
  too.
- **Coverage (+30 tests):** persona_nav_spec_test (17 — ≤4 primary invariant,
  no-duplicate-routes, every More route lights the More tab not Home, Parent
  Messages-promoted + un-buried decisions), persona_bottom_nav_test (7 — More
  tab/sheet renders, navigates + closes, route-aware selection, switcher shown
  for multi-hat / hidden for single-workspace), navigation_bar_highlight_test
  (6 — selected icon = onPrimaryContainer, light + dark).
- **Certified:** `flutter analyze` **0 errors** (only pre-existing test-file
  lint warnings remain); full Flutter suite **2146 pass** (1 staging-only skip).

---

## 🟡 UX Batch 3 — Mobile-first (IN PROGRESS) — split into 3a + 3b
Goal: bring the admin shell to the same phone-quality bar the consumer apps
already meet, and close the remaining MOBILE_FIRST_AUDIT items (#1/#2 were done
in Batch 2). Owner-approved plan: **3a = Steps 1–2** (breakpoints + admin mobile
nav, the deferred-from-Batch-2 headline), **3b = Steps 3–5** (Director portal,
polish cluster, shared wizard + bottom-sheet filters). Owner decisions honoured:
admin gets a **bottom nav + the drawer kept reachable from "More"**.

### ✅ UX Batch 3a — DONE & CERTIFIED (2026-06-20)
- **Step 1 — One breakpoint system (MOBILE_FIRST_AUDIT #6).** `lib/theme/
  breakpoints.dart` is now the single source of truth: added named tiers
  (`tabletMinWidth` 768, `largeMobileMinWidth` 428, `narrowMobileMaxWidth` 360)
  + content widths (`compactContentMaxWidth` 480, `readingContentMaxWidth` 640)
  + helpers (`isTabletUp`/`isLargeMobileUp`/`isNarrowMobile`). `MobileDashboardLayout`
  now forwards to it, and **33 feature files** that had inlined the same raw
  literals (`768`/`480`/`428`) were migrated to reference the canonical
  constants — same values, so zero behaviour change; the win is no future drift.
- **Step 2 — Admin mobile navigation (MOBILE_FIRST_AUDIT #3; deferred from
  Batch 2).** Two parts:
  - **2a Admin bottom nav on phones.** New `AdminBottomNav`
    (lib/features/admin/admin_bottom_nav.dart) gives the web ERP a bottom
    `NavigationBar` on ≤767px — up to 4 of the **active workspace's** modules
    (active module always kept visible) + a "More" tab that opens the full
    module drawer (owner's "bottom nav + keep drawer" decision). Tablet/desktop
    rail untouched.
  - **2b One collapsing sub-nav.** New shared `AksharaModuleSubNav`
    (lib/shared/widgets/akshara_navigation.dart) replaces the **12 hand-rolled**
    horizontal sub-nav strips (Finance 14, Control Center 15, Inventory 10,
    Director 9, … which used to run off-screen with no scroll cue). On phones it
    shows ≤4 inline tabs (scrollable) with a **pinned** "More" button → premium
    bottom sheet of the overflow screens; the selected screen is swapped inline
    so you always see where you are. Tablet/desktop = the original strip.
- **Coverage (+ ~13 tests):** breakpoints_test (canonical thresholds + helper
  boundaries + MobileDashboardLayout-forwarding), akshara_module_sub_nav_test
  (phone collapse, More-sheet, selected-overflow swap, tablet-all-inline),
  admin_shell_test (mobile bottom nav present + drawer reachable; hidden on
  tablet/desktop). Mobile-width dashboard goldens (finance/inventory/
  intelligence/approval) regenerated for the intended collapsed-sub-nav look
  (tablet goldens unchanged — change is mobile-only).
- **Certified:** `flutter analyze` **0 errors**; full Flutter suite **2154 pass**
  (1 staging-only skip).
- **Carry-over to 3b:** Director portal responsive (#5), AI center slot (#4),
  card-height truncation (#7), tablet-portrait tables (#8), shared multi-step
  wizard (#9), bottom-sheet filters (#10).

---

## Batches

| # | Domain | Status | Certification |
|---|--------|--------|---------------|
| — | **Exams** (P1 granular perms + P2 teacher scoping, server) | ✅ | deno authz 5/5; flutter exam 70/70; analyze 0 err |
| 0 | **Cross-cutting safety net** | ✅ | full edge graph `deno check` 0 err; CI gate added; deno unit 491 pass (only live-DB self-test skipped locally) |
| 1 | Finance (invoices/collections/refunds/concessions) | ✅ | already hardened; verified — 76 finance deno tests pass; granular approve perms + self-approve block + scope confirmed |
| 2 | SIS & Attendance | ✅ | **fixed**: attendance correction status endpoint now requires `approveAttendanceCorrection` (was `manageSis` — approval bypass). SIS read/write split verified. 89 deno tests pass |
| 3 | Admissions | ✅ | verified — approve=`approveAdmissions`, manage=`manageAdmissions`, read=`viewAdmissions` across 13 write routes; tests pass |
| 4 | HR / Staff | ✅ | verified — hr read-only (`viewHr`); employee writes `manageEmployees`; staff/student leave approval via granular approve perms; tests pass |
| 5 | Operations (transport/hostel/library/inventory) | ✅ | verified — transport/hostel/library read-only (factory-gated `viewX`, 0 write routes); inventory writes `manageInventory`/`manageAssetLifecycle`/`manageProcurementWorkflow`; tests pass |
| 6 | Governance & Intelligence | ✅ | verified — approval enforces per-type granular approve perms + blocks self-approval; intelligence gated on `viewXIntelligence`; tests pass |

**Whole-backend certification:** full edge graph `deno check` = 0 errors; deno unit suite = 491 pass (only `tenant_isolation_test` needs a live DB — runs in CI/staging).

## Batch 0 — what was done
- **CI gate**: `deno check supabase/functions/api/index.ts` added to `backend_staging.yml` before unit tests — type-checks the entire wired edge graph (not just test-reachable files), so "wired but never compiled" modules can't recur.
- **Fixed pre-existing breakage surfaced by the gate** (53 errors across 18 files), all pre-existing, none caught before because no test imported these modules:
  - Approval: `claims.name` (nonexistent) → dropped; `ApprovalRequestRow` import moved to its canonical source.
  - Attendance handlers: same `withAuth`/`tenantIds`/`claims.userId→sub` bugs as exams.
  - 8 routers: route-lookup ternary typed `| undefined` (benign false-positive, now correct).
  - ~35 `body` null-guards added across memories / parent_experience / promotion / attendance / inventory_intelligence handlers.
  - inventory_intelligence: `jsonResponse(..., 201)` → `{ status: 201 }`; `readJson` null coalesce.
  - parent_experience services: two row/return shape mismatches corrected.

## Batch 1 — Finance (findings)
Audited authz parity; **no fixes needed** — finance was built correctly:
- read = `viewFinance`, write = `manageFinance` (split confirmed across invoices, collections, fee structures).
- refund approval = `approveRefunds` (dedicated handler) ; concession = `approveFeeConcession` (generic approval). Per-type granular approve perms enforced in `approval_handlers` via `approvalPermissionForType`.
- self-approval blocked (`ApprovalSelfApproveDeniedError`); school/org scope enforced + tested.
- Certified: 76 finance deno tests pass.
- Carry-over (minor parity, not a hole): client has `approveFeeStructure` but fee-structure changes are gated by `manageFinance` with no approval flow server-side — wiring a fee-structure approval type is a feature, deferred.

## Exam domain — feature completion (Slices 1–6)
Closed end-to-end: grading engine → workspace hub → marks wiring → approve/publish
→ parent/student results → **report card with class rank** (parent + student;
rank shown per `showRankToParents`; attendance line from the shared attendance
store). Full exam Flutter suite green (84). Deferred by design:
- **Report card remark** — no data model/entry yet; needs a product decision (who writes it, where stored).
- **PDF export** — owner explicitly deferred ("downloadable PDF later").

## ✅ EXAM DOMAIN = CLOSED (100%)
All slices (1–6) + server authz hardening + per-exam-session remarks + PDF report
card complete and certified.
- Remarks: per (student, exam session), class-teacher authored, audit trail,
  shown on report card; app + server parity; only the class teacher may write.
- PDF report card (parent + student share): branding/logo placeholder, student
  details, class/section, subject marks, grades, total, %, rank (only when the
  school enables it), attendance %, class-teacher remark, principal-signature +
  school-seal placeholders; identical layout across grading systems.
- Certified: flutter analyze 0 errors; exam Flutter suite 94 pass; PDF generation
  verified (valid PDF); full edge `deno check` 0 errors; exam/approval server
  tests 12 pass.
- Deferred by owner: nothing blocking. (Future extension: principal / vice-
  principal remarks — schema already allows those author roles.)

## ✅ FEES & PAYMENTS = CLOSED
Payment loop now works end-to-end: a confirmed payment marks the installment
paid, lowers the amount due, updates progress, and adds a receipt to history
(was previously static). Receipt PDF download/share added (real PDF). Report
card PDF reused from exams. Certified: app analyze 0 errors; fees/payments/
finance suites 67 pass; PDF generation verified.
Carry-over: live Razorpay server path exists but is exercised only in
CI/staging; the in-app experience runs on the mock loop.

## ✅ ATTENDANCE = CLOSED
Teacher marks attendance → updates the parent KPI AND now the student view
(student was previously static; merge centralized in
MockAttendanceSyncStore.mergedMonth, used by both). Correction flow (submit →
principal approve, gated on approveAttendanceCorrection — Batch 2) updates the
sync store. Certified: app analyze 0 errors; attendance suites 16 pass (incl. F5
correction submit→approve integration).
Carry-over: aggregate class counts drive the single-primary-student mock;
per-student daily records are a backend (F-series) concern.

## ✅ MESSAGES & NOTICES = CLOSED
School broadcast → now reaches the targeted audience's notices (parents and/or
students), newest first, on top of the standing notices (was static before).
Existing pieces confirmed: teacher→parent concern inbox (read/acknowledge,
governance-gated), parent/student notices, language localization. Certified:
app analyze 0 errors; communication/notices/messages suites 17 pass.

## ✅ ADMISSIONS = CLOSED (already complete — verified, no fixes)
Full chain works end-to-end and is store-backed: lead → application → documents
→ approve → fee handoff ("Ready for fee setup") → SIS conversion queue (via
MockAdmissionsSisBridge). approveAdmission creates the handoff; submitEnrollment
queues the SIS conversion; admissions→finance bridge persists fee assignment.
Server authz certified earlier (Batch 3: approveAdmissions / manageAdmissions /
viewAdmissions). Certified: admissions feature + integration (e2e journey,
admissions→finance e2e) + SIS-bridge + write-contract suites all green (~78);
app analyze 0 errors. No code changes required.

## ✅ HOMEWORK = CLOSED
Loop complete: teacher assigns → student sees → student submits → teacher
reviews → grade + comment now reach the student AND parent (was teacher-side
only). Shared SchoolHomeworkStore records review per (homework, student);
student/parent items show a "Reviewed · Grade X — comment" line. Certified: app
analyze 0 errors; homework suites 13 pass.
Carry-over: full per-student "reviewed" lifecycle status (vs the additive
grade/comment line) would need a status-enum change across both apps — deferred.

## Everyday loops — status after the closing sweep
Closed & tested: Exams, Fees & Payments, Attendance, Messages & Notices,
Admissions, Homework, plus **Leave** (parent requests → principal approves →
parent sees approved/rejected; verified — `applyDecision` updates the parent's
own list; approval integration suites green).

Remaining areas are a **different kind of work** (no clean broken loop to close):
- **Timetable** — persona views render static weekly schedules (functional); a
  big integration would wire the academics scheduler/editor → teacher/student/
  parent grids. Large project, not a one-gap fix.
- **Transport / Library / Hostel / Inventory** — admin/operational modules that
  work (read views + staff CRUD), with an intentional live-tracking placeholder
  (future). No broken parent/student loop.

## ✅ #1 LEAVE BY CLASS TEACHER = DONE (app + server)
Student leave is now the class teacher's job (not principal). App: class-teacher
dashboard "Leave requests" lists their own class's pending leaves with
approve/reject (scoped via classTeacherOwnsLeave); reuses the approval pipeline
so the parent sees the decision; principal keeps visibility. Server: registered
approveStudentLeave (was uncatalogued → would 403 everyone) + granted to
oversight roles + teacher; approval handler scopes a teacher to their own class
(isClassTeacherForClass), principals/management unscoped. Certified: app analyze
0 err, RBAC/approval suites 151 pass; edge deno check 0 err, +1 scope test.
Follow-up: sibling approve perms (approveStaffLeave, approveAttendanceCorrection,
approveFeeConcession, approvePurchaseOrder) were also uncatalogued server-side —
NOW FIXED (see "APPROVAL PERMISSION CATALOG GAP" below).

## ✅ #2 ATTENDANCE BY CLASS TEACHER = DONE (app)
getAttendanceClasses scoped to the class teacher's own class (non-class-teacher
sees none). Tests green. Server note: there is **no attendance MARKING write
endpoint** server-side (sessions are read-only GET; the only writes are
corrections: create=manageSis, status decision=approveAttendanceCorrection), so
there is no marking route to class-teacher-scope. The real server gap turned out
to be the uncatalogued approve permission — see below.

## ✅ APPROVAL PERMISSION CATALOG GAP = FIXED (server)
Same class of bug as approveStudentLeave: four approve permissions were required
by edge handlers + present in the client matrix but never in the server catalog,
so they'd 403 everyone. Registered + granted (client-parity roles) in
20260701000000_approval_permissions_catalog_gap.sql:
- approveStaffLeave, approveAttendanceCorrection → leadership
  (superAdmin/schoolAdmin/principal/vicePrincipal/management)
- approveFeeConcession → + financeAdmin
- approvePurchaseOrder → + inventoryManager
Added a regression test (approval_permission_catalog_test.ts) that fails if any
F2_APPROVAL_TYPES permission is missing from the migration catalog — prevents
recurrence. Certified: deno check 0 err; approval/academic/attendance deno tests
125 pass.

## 🚧 #3 TIMETABLE auto-substitute — staged
- [x] Stage 1: rule-based substitution engine (DailyTimetableEngine) + tests —
  cover-by-free-teacher, subject preference, no double-booking, unfilled,
  coordinator override. No AI (plain rules), deterministic.
- [x] Stage 2: coordinator review screen ("Today's timetable & cover" from the
  Smart Timetable hub) — mark a teacher on leave → auto-fill → Substitute/Needs-
  cover badges → reassign via picker. MockDailyTimetableStore + tests (8 total).
- [x] Stage 3a: teacher "Today's classes" view (incl. "Covering X" subs).
- [x] Stage 3b: substitutions AUTO-derive from APPROVED staff leave for the
  viewed date (teachersOnLeaveForDate) — no daily manual marking. Base timetable
  is fixed; coordinator screen = pick date + view auto-cover + override. Owner
  design correction applied. Tests green.
- [ ] Stage 3c (only when live): truly-scheduled morning run is a server cron;
  in-app it computes on open for the selected date (same effect).

#3 TIMETABLE auto-substitute = effectively COMPLETE for the mock app (the only
remainder is the server cron, which needs the live backend).

## 🚧 TIMETABLE GENERATOR (first-time auto-build) — staged
Owner vision: after school setup (curriculum already chosen) + all teachers
added with subjects/classes, one **Generate** builds the full fixed weekly
timetable; coordinator/principal then tweak; leave-substitution (done) runs on
top. Plain rules, no AI. Start order chosen by owner: setup + templates → real
generator → coordinator tweak.

What already exists in the app (reused, not rebuilt):
- Curriculum is chosen at setup (`SchoolCurriculum` enum: cbse/icse/stateBoard/
  ib/cambridge/custom).
- Classes + sections captured in onboarding (`UnifiedOnboardingState`).
- Subjects + periods/week + class-subject + teacher-subject assignments exist
  (`school_completion`: AcademicSubject, ClassSubjectAssignment,
  TeacherSubjectAssignment, subject_assignment_screen).
- `mock_timetable_repository.generate()` is a STUB (round-robin subjects, one
  fake teacher, no clash checks) — must be replaced by the real generator.
- Class teacher is still HARD-CODED (`TeacherAssignmentRegistry`) — needs to
  become real per-section data.

Owner design rules to honour in the generator:
- Curriculum is NOT a fixed default — it follows the school's setup choice; the
  template proposes grade-appropriate subjects from that choice.
- Grade-appropriate: grades 1–5 combined EVS (no Physics/Chem/Bio), 6–8 combined
  Science + Social Science, 9–10 heavier load.
- Activities (Games/Computer/Library/Art) are weekly/twice-weekly with a room
  (Playground/Computer Lab/Library) — generator must not double-book a room.
- **First period of every section = its class teacher's period** (the class
  teacher takes attendance there). Generator reserves period 1 for the class
  teacher.
- After first-period attendance → auto polite notification to absent students'
  parents ("your child is absent"). Connects teacher↔parents. (Wording/flow to
  be discussed later — recorded, not built yet.)

- [x] Step 1a: curriculum templates catalog
  (lib/core/timetable/curriculum_templates.dart) — grade-band aware
  (lowerPrimary/middle/secondary), board-aware languages, room-bound activities,
  weekly-load helper. 11 tests pass; analyze clean.
- [x] Step 2: rule-based generator engine
  (lib/core/timetable/timetable_generator.dart) — reserves period 1 for the
  class teacher (their subject if needed, else homeroom), never double-books a
  teacher, one class per shared room per slot, spreads subjects, fills/free +
  plain warnings for anything unplaceable. 10 tests pass; analyze clean. Pure &
  deterministic.
- [x] Step 1b: class-teacher-per-section as real, editable data
  (lib/core/timetable/class_teacher_assignments.dart, seeded from the registry:
  8-A→Priya, 8-B→Patel) + a "Class Teachers" screen under School Completion hub
  (pick one teacher per section) + route. Feeds the generator's classTeacherId.
- [x] Step 2-wire: `mock_timetable_repository.generate()` now runs the real
  engine across all configured sections at once (clash-free), reserves period 1
  for each class teacher, 8×6 grid so the full CBSE curriculum fits, maps to
  TimetablePeriod and upserts entries. Old stub kept only for constructor seed.
  9 wiring/store tests + 141 affected-suite tests pass; analyze 0 errors.
  Carry-over: mock uses CBSE template (no provider access in repo) — live backend
  supplies the school's actual curriculum + teacher_subject_assignments.
- [x] Step 3: coordinator review/tweak of the generated grid. Editor tab now
  shows teacher NAMES (mockTimetableTeacherDirectory) not raw ids, fixes the
  move math to use the entry's real periodsPerDay (was hardcoded 6 — broke the
  8/day generated grid), and adds **Change teacher** per period. New
  `reassignPeriodTeacher` wired through interface + mock + api + hybrid + remote
  + paths. 2 editor/screen + 1 reassign test added; analyze 0 errors.
- [ ] Later: first-period absent-parent notification (polite messaging) —
  parked for owner wording discussion.

#3 TIMETABLE GENERATOR = effectively COMPLETE for the mock app: set class
teacher → Generate real clash-free timetable (period 1 = class teacher) → view &
tweak (move + reassign teacher). Live backend supplies real curriculum/teacher
assignments + the scheduled cron.
- [ ] Later: first-period absent-parent notification (polite messaging).

## ✅ EXAM SEPARATION OF DUTIES = DONE (server)
The coordinator who VERIFIED an exam's results can no longer also APPROVE/publish
them — verify and approve must be different people. Enforced in the single
approval chokepoint (`decideApproval`): on an `examResults` approval it looks up
the exam session's `coordinator_verified_by` and, if it equals the approver,
throws `ApprovalSeparationOfDutiesError` → 403 (mirrors the existing "can't
approve your own purchase order" rule). Rejections by the verifier are still
allowed (only approval is blocked); unverified sessions don't false-trip.
Certified: 5 new SoD tests + full approval/exam suites = 18 pass; edge
`deno check` 0 err.

## ✅ EXAM READ-MODEL teacher_id GAP = DONE (server)
The denormalized teacher read-model (`teacher_entities`) was only school-scoped —
any teacher/staff could read every teacher's snapshot rows (dashboard, exam
marks, messages...). Added a `teacher_id` owner column + per-teacher RLS so each
teacher only sees their own rows, bringing it to parity with its siblings
`parent_entities`/`student_entities` (which already scope by owner via RLS).
Migration `20260702000000_teacher_entities_teacher_scope.sql`: add+backfill+NOT
NULL `teacher_id`, re-key PK to `(org, school, teacher_id, entity_type, id)`,
new index, and replace `teacher_entities_school_scope` with
`teacher_entities_teacher_scope` (`teacher_id = app_current_user_id()`). No app
code change — the generic `entity_read_store` relies on RLS for owner scoping,
same as students/parents. Added a live-DB probe
(`teacher_b_cannot_see_other_teacher_probe_same_school`) so a second teacher in
the same school proves the scoping. Certified: full edge `deno check` 0 err;
deno `_shared` suite 499 pass (only the live-DB `tenant_isolation_test` is
skipped locally — runs in CI/staging).

## ✅ ROUTE GUARD GAP = FIXED (app)
Certification sweep caught it: `classTeacherAssignments` (the "Class Teachers"
screen added with the timetable generator) was registered as a route + reachable
from the School Completion hub, but was **missing from the route-permission guard
map** (`erpRoutePermissionFor` in route_guards.dart) — i.e. the screen was not
protected by a permission. Mapped it to `manageAcademicTimetable`, matching its
siblings Substitute Manager / Teacher Reassignment (held by superAdmin,
schoolAdmin, principal, vicePrincipal — the leadership roles that set class
teachers). The existing `route_protection_inventory_test` ("all ERP prefixes map
to a permission") now passes; it was the only red test in the suite.

## ✅ FULL CERTIFICATION SWEEP = GREEN (whole app + backend)
Ran the complete certification end-to-end after closing the exam carry-overs:
- `flutter analyze` = **0 errors** (only test-file lint warnings remain).
- Flutter test suite = **2086 pass** (1 skip), after fixing the route-guard gap
  above (was the single failing test).
- Backend: full edge `deno check` = **0 errors**; deno `_shared` suite =
  **499 pass** (only the live-DB `tenant_isolation_test` skipped locally —
  runs in CI/staging).
All major school domains (Exams, Finance/Fees, SIS/Attendance, Admissions,
HR/Staff, Operations, Governance/Intelligence, Messages, Homework, Leave,
Timetable generator + auto-substitute) are closed and certified.

## Known carry-overs (tracked, not blocking)
- Live-DB tests (`tenant_isolation_test.ts`) require a tenant DB; run in CI/staging only.
- Owner-parked feature (do not start without owner): first-period absent-parent
  polite notification (timetable generator) — awaiting wording decision.
