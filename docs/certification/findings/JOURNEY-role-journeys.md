# JOURNEY — Complete Role Journeys (Workstream 3)

**Workstream:** 3 (Complete role journeys, 13 roles) · **Date:** 2026-07-29
**Repo:** `/Users/surendrakanna/Documents/Akshara_ERP-release` · **Branch:** `release/v1.0-playstore`
**Method:** static code trace of the shipping release build — router
(`lib/router/**`), shells (`lib/features/*/shell/*`), nav registries
(`lib/features/admin/admin_navigation_provider.dart`, `lib/shared/navigation/persona_nav.dart`),
RBAC (`lib/core/security/**`), hide gates (`lib/core/config/school_build_scope.dart`,
`lib/router/surface_backend_gate.dart`), and the screens each landing route renders.
Read-only. Nothing was changed. Companion index: `docs/certification/FEATURE_INVENTORY.md`.

**Tap counting convention.** A "tap" = one deliberate touch on an interactive
target after the app is already open and authenticated at the persona's landing
route. Opening the "More" sheet counts as 1; choosing a tile inside it counts as
1. Scrolling is not a tap. Where a screen's own sub-nav must be used, that is a
tap. Counts are from the widget tree, not from a running device (no release
binary can run in this harness — see boundaries at the end).

---

<!-- Sections appended below as each is traced. -->
## 1. The role model — what the product claims vs what the code defines

### 1.1 Three different role vocabularies, none of which agree

| Layer | Where | Count | Values |
|---|---|---|---|
| **Shell persona** | `UserRole` (`lib/features/auth/auth_models.dart`) | **4** | `parent`, `teacher`, `student`, `staff` |
| **Client ERP role** | `ErpRole` (`lib/core/security/erp_role.dart:2-17`) | **15** | superAdmin, schoolAdmin, principal, vicePrincipal, management, financeAdmin, admissionsCounselor, teacher, parent, student, transportManager, hostelManager, librarian, inventoryManager, storekeeper |
| **Server role** | `role_definitions` seeds (`supabase/migrations/20260608100000_rbac_foundation.sql:166-193`, `20260851000000_…:33`, `20260887000000_student_health.sql:42`) | **29** | the 15 above **plus** organizationOwner, organizationAdmin, schoolGroupDirector, financeManager, **hrManager**, marketingManager, classTeacher, coordinator, counselor, petTeacher, danceTeacher, musicTeacher, **officeStaff**, **healthStaff** |

**14 roles the server can legitimately issue have no client representation.**
Three of them are roles this workstream was asked to certify:

| Role asked for | Client `ErpRole`? | Server role? | Verdict |
|---|---|---|---|
| Principal | ✅ `principal` | ✅ | represented |
| Vice Principal | ✅ `vicePrincipal` | ✅ | represented |
| Teacher | ✅ `teacher` (+ own shell) | ✅ | represented |
| Finance | ✅ `financeAdmin` | ✅ (+ unrepresented `financeManager`) | represented |
| **HR** | ❌ **none** | ✅ `hrManager` (granted `viewAdminHub`, `viewHr`, `manageHr`) | **unrepresentable client-side** |
| **Office Staff** | ❌ **none** | ✅ `officeStaff` (granted **`viewAdminHub` only**) | **unrepresentable, and powerless even server-side** |
| **Reception** | ❌ none | ❌ none | **does not exist anywhere** |
| Librarian | ✅ `librarian` | ✅ | represented |
| Transport | ✅ `transportManager` | ✅ | represented |
| **Nurse** | ❌ **none** | ✅ `healthStaff` | **unrepresentable client-side** |
| Parent | ✅ `parent` (+ own shell) | ✅ | represented |
| Student | ✅ `student` (+ own shell) | ✅ | represented |
| Management | ✅ `management` | ✅ | represented |

The code says so itself. `lib/features/auth/qa_login_persona.dart:17-19`:
> "HR and Director have no dedicated ErpRole, so they carry a curated
> `[customPermissions]` subset … rather than a role's full union."

A QA persona was invented to paper over a role the product does not have.

### 1.2 An unknown server role resolves client-side to **Super Admin**

This is the consequence, and it is the most serious finding in this workstream.

Login (live API path) → `AuthMapper.toUser` →
```dart
erpRole: ErpRole.fromName(raw['role'] ?? raw['erpRole']) ?? ErpRole.superAdmin,
```
(`lib/core/repositories/api/auth/mapper/auth_mapper.dart:63-66`; the same
`?? ErpRole.superAdmin` default is repeated at `lib/core/auth/auth_session_manager.dart:172`).
That `AuthUser.erpRole` is then copied verbatim into the session claims —
`lib/features/auth/auth_provider.dart:309-311` — so `claims.erpRoles == [superAdmin]`.

The backend's login payload carries a **single** `role: ctx.resolved.primaryRole`
slug (`supabase/functions/_shared/auth_handlers.ts:126`). If a school assigns
`officeStaff`, `hrManager`, `counselor`, `coordinator`, `classTeacher`,
`financeManager`, `marketingManager`, `petTeacher`, `danceTeacher`,
`musicTeacher`, `healthStaff`, `organizationOwner`, `organizationAdmin` or
`schoolGroupDirector` as a user's primary role, `ErpRole.fromName` returns null
and the client treats that person as **Super Admin** for every role-keyed check.

Permissions are unaffected (they come from the server snapshot,
`rbac_service.dart:72-82`), so most surfaces stay correctly locked. But every
gate keyed on the **role** rather than a permission flips open:

| Gate | Conjunct? | Outcome for a mis-mapped user |
|---|---|---|
| `canAssignOrganizationPlansProvider` (`lib/core/entitlements/subscription_admin_provider.dart:15-18`) | **role only, no permission** | `/admin/plan/assign` renders and its Save button is enabled — an office clerk is offered the organization plan-assignment screen. Backend is the real enforcement, so the write should fail, but the UI lies about their authority |
| `ControlCenterGuard` (`lib/router/route_guards.dart:499-501`) | `AND viewControlCenter` | safe |
| `RbacModuleRegistry.canAccessControlCenter` (`:168`) | `AND hasViewPermission` | safe |
| `kRoleWorkspaces` → workspace resolution (`lib/core/workspace/workspace.dart:177-193`) | role only | user is placed in the **School Administration** workspace regardless of their real job |
| `AdminHubScreen` hero (`admin_hub_screen.dart:39-63`) | role → workspace → config | user is shown the **school-administration fabricated stat block** (see JOURNEY-001) |

There is a second, contradictory fallback for the same condition:
`AuthClaims.fromJson` (`lib/features/auth/auth_claims.dart:126-132`) drops
unrecognised names from the `roles` array and, if that leaves the list empty,
falls back to **`ErpRole.parent`**. So the same unknown role becomes `superAdmin`
on the login path and `parent` on the session-restore-from-JSON path. Two
opposite guesses for identical input.

**Defects raised:** `JOURNEY-002` (P0), `JOURNEY-003` (P1).

### 1.3 How many roles have a dedicated persona shell

Four shells exist: `ParentShell`, `TeacherShell`, `StudentShell`, `AdminShell`.

- **3 roles** get a purpose-built shell: parent, teacher, student.
- **12 client roles** share one shell — `AdminShell` — differentiated **only** by
  which tiles survive the permission filter in `adminNavDestinationsProvider`
  (`lib/features/admin/admin_navigation_provider.dart:277-319`) and which
  workspace `kRoleWorkspaces` grants them.
- **0** of Principal, Vice Principal, Finance, HR, Office Staff, Reception,
  Librarian, Transport, Nurse or Management has a shell, a home screen, a
  role-specific information architecture, or a task list of its own.

The differentiation the admin shell *does* have is the **workspace**
(`WorkspaceId`, 10 values), which is a coarser cut than the role: `librarian` →
`library`, `transportManager` → `transport`, `inventoryManager` **and**
`storekeeper` → the same `inventory` workspace, and superAdmin, schoolAdmin,
principal, vicePrincipal, management **all** → the single
`schoolAdministration` workspace. Five very different jobs, one identical
surface.

This is the structural answer to the workstream's question: **NIKSHA OS has 4
personas and 10 workspaces, not 13 roles.** A product claiming role awareness
ships role-shaped *permission sets* over a shared admin surface.

---

## 2. Where each role lands after login

`_authRedirect` (`lib/router/app_router.dart:2112-2115`) → `homeRouteForAuth`
(`:2306-2311`) → `homeRouteForStaffErp` (`lib/features/auth/qa_login_persona.dart:207-216`),
which is a 5-arm switch with a catch-all:

```dart
ErpRole.financeAdmin      => RouteNames.financeDashboard,
ErpRole.inventoryManager  => RouteNames.inventoryDashboard,
ErpRole.principal         => RouteNames.managementDashboard,
ErpRole.vicePrincipal     => RouteNames.managementDashboard,
ErpRole.superAdmin        => RouteNames.admin,
_                         => RouteNames.admin,
```

| Role | Lands on | Is the landing screen the job, or a launcher? |
|---|---|---|
| superAdmin | `/admin` | launcher (17 tiles) |
| schoolAdmin | `/admin` | launcher (16 tiles) |
| **principal** | `/management/dashboard` | **the job** — KPI row, trends, approvals panel |
| **vicePrincipal** | `/management/dashboard` | the job (identical to principal) |
| management | `/admin` | launcher — *even though `/management/dashboard` exists and they hold `viewManagement`* |
| **financeAdmin** | `/finance/dashboard` | the job |
| admissionsCounselor | `/admin` | launcher showing **2** tiles (Admissions, Marketing) |
| transportManager | `/admin` | launcher showing **1** tile (Transport) |
| hostelManager | `/admin` | launcher showing **1** tile (Hostel) |
| librarian | `/admin` | launcher showing **1** tile (Library) |
| **inventoryManager** | `/inventory/dashboard` | the job |
| storekeeper | `/admin` | launcher showing **1** tile (Inventory) — *same workspace as inventoryManager, different landing* |
| teacher | `/teacher/dashboard` | the job |
| parent | `/parent/dashboard` | the job |
| student | `/student/dashboard` | the job |

Six roles land on a launcher they must immediately navigate out of, and **four
of them are launchers with a single tile**: the tile grid is a one-item menu.
`storekeeper` and `inventoryManager` hold the same workspace and the same
module, and land in different places — there is no rule being followed, only an
incomplete switch. **Defect `JOURNEY-004` (P1).**

### 2.1 The landing screen shows fabricated numbers — on day one and every day

`AdminHubScreen` renders `AksharaWorkspaceLanding` with
`stats: kWorkspaceLandingConfig[workspace.id].stats`
(`lib/features/admin/screens/admin_hub_screen.dart:39-63`). Those stats are
**compile-time constants** (`lib/features/admin/workspace_landing_config.dart:27-84`):

| Workspace (who sees it) | Headline the school is shown |
|---|---|
| School Administration (superAdmin, schoolAdmin, management, + every mis-mapped role per §1.2) | **1,248 Students · 86 Staff · 96% Attendance** |
| Finance (financeAdmin, on `/admin`) | **₹4.2L Collected today · ₹1.8L Pending · 92% This month** |
| Front Office (admissionsCounselor) | 23 Open enquiries · 14 Admissions · 9 Visitors today |
| Inventory (inventoryManager, storekeeper) | 642 SKUs · 12 Low stock · 38 Issued today |
| Transport (transportManager) | 18 Routes · 22 Buses · 97% On-time |
| Hostel (hostelManager) | 312 Residents · 96 Rooms · 88% Occupancy |
| Library (librarian) | 8,450 Titles · 214 On loan · 7 Overdue |

The file's own comment concedes it: *"Stats are curated demo figures consistent
with the seeded school so demos read as live."* They are not labelled as demo
anywhere in the UI — they render in the same premium hero as any real KPI.

**Day one at a brand-new school**: the principal's Admin Hub says the school has
1,248 students and 96% attendance before a single child is enrolled; the
librarian's says 8,450 titles and 7 overdue books before a single book is
catalogued; the finance workspace claims ₹4.2 lakh collected today before a
single rupee has been received.

Two of the seven blocks are **fabricated attendance and fabricated financial
data presented to a school user as fact**, which the register's standing rule
makes P0 without argument. **Defect `JOURNEY-001` (P0).**

### 2.2 The Admin Hub has no empty state

`AdminHubScreen` builds `Wrap(children: [for (final destination in modules) …])`
with no `isEmpty` branch (`admin_hub_screen.dart:86-97`). A user whose permission
filter yields nothing — a real, reachable case: the seeded `officeStaff` role
holds **only** `viewAdminHub` (`20260608100000_rbac_foundation.sql:238`), and
`AdminModule.admin` is explicitly excluded from the grid at `:29-31` — gets the
hero with its fabricated numbers, the line *"Jump to a module you are authorized
to access"*, and then **nothing at all**. No message, no explanation, no route
onward. **Defect `JOURNEY-005` (P1).**

### 2.3 The staff bottom nav is ordered by declaration, not by frequency

`AdminBottomNav` shows `destinations.take(4)`
(`lib/features/admin/admin_bottom_nav.dart:31,50`), and `destinations` preserves
`kAllAdminNavDestinations` declaration order: Admin Hub, Admissions, **Marketing**,
Finance, SIS, Exams, …

For a principal or school admin on a phone the four permanent tabs are therefore
**Admin Hub · Admissions · Marketing · Finance**. Management, SIS, Exams, HR,
Approvals — the surfaces a head of school actually opens daily — are all behind
the "More" drawer (2 taps), while Marketing, an entitlement-gated growth module,
holds a permanent slot. **Defect `JOURNEY-006` (P2).**

---
## 3. Six live modules can never appear on the Admin Hub

Three staff navigation surfaces exist, and they do **not** read the same list:

| Surface | Provider | Workspace-scoped? |
|---|---|---|
| Admin Hub tile grid (`admin_hub_screen.dart:28`) | `workspaceScopedNavDestinationsProvider` | **yes** |
| Phone bottom nav (`admin_bottom_nav.dart:47`) | `workspaceScopedNavDestinationsProvider` | **yes** |
| Nav rail / mobile drawer (`admin_navigation_rail.dart:56`) | `adminNavDestinationsProvider` | **no** |

`workspaceScopedNavDestinationsProvider` keeps a destination only if
`workspace.containsModule(destination.module)`
(`admin_navigation_provider.dart:325-337`). Cross-referencing
`AdminModule` (30 values, `admin/models/admin_nav_models.dart:6-38`) against the
union of every `Workspace.modules` set (`lib/core/workspace/workspace.dart:59-173`)
gives the modules that belong to **no workspace at all**:

`certificateDesk` · `gatePass` · `complaints` · `studentHealth` ·
`schoolCompletion` · `organizationBuilder` · `platformOperations` · `industry` ·
`healthcare` · `salon` · `restaurant` · `accommodation` · `whiteLabel`

The last seven are hidden in a school build anyway. The first six are **live,
un-hidden, school-facing modules**:

| Module | What it is | Where it can still be reached |
|---|---|---|
| **Certificates** (`/certificate-requests`) | bonafide / study / conduct / TC / fee certificate desk | drawer or rail only |
| **Gate Pass** (`/gate-passes`) | early-pickup / authorised student release | drawer or rail only |
| **Complaints** (`/complaints`) | school-internal issue tracking with SLA | drawer or rail only |
| **Infirmary** (`/student-health`) | student health incidents, medication authorisation | drawer or rail only |
| **School Completion** (`/school/completion`) | ~20 screens: subjects, timetables, syllabus automation, lesson logs, academic progress, communications, pilot toolkit | drawer or rail only |
| **Org Builder** (`/organization-builder`) | chain provisioning | drawer or rail only (chain orgs) |

So the Admin Hub — the screen 6 of 15 roles land on, and the screen whose own
subtitle says *"Jump to a module you are authorized to access"* — omits five
day-to-day school desks that the drawer sitting immediately behind it lists.
On a phone those five are also absent from the bottom nav, so the only route is
menu → scroll the drawer.

This is the same class of bug the code already fixed once and re-introduced:
`admin_navigation_provider.dart:109-113` records that School Completion "had
routes + real screens but ZERO inbound navigation — reachable only by typing the
URL", and a nav destination was added for it. That destination is then stripped
again by the workspace filter for every user. `FEATURE_INVENTORY.md` §3e lists
all five as "tile-reachable" — that conclusion was drawn from
`kAllAdminNavDestinations` before the workspace filter, and is not what a user
sees.

**Defect `JOURNEY-008` (P1).**

---

## 4. Role-by-role journeys

For each role: landing → the highest-frequency tasks → taps → day one → what
they can see that they should not, or cannot see that they need.

### 4.1 Principal · `ErpRole.principal` (105 permissions)

**Lands on** `/management/dashboard` — a real working screen, not a launcher:
KPI row, attendance-pending widget, approval-queue preview, admissions and fee
snapshots, trend chart (`management/dashboard/management_dashboard_screen.dart:120-265`).
This is the best landing in the product.

| Task | Path | Taps |
|---|---|---|
| Clear the approval queue | landing → any approval card / KPI / insight → `/management/approvals` (`:262,382,413`) | **1** |
| See who has not marked attendance | landing → `_AttendancePendingWidget` (`:389-401`) → `/management/office-attendance` | **1** |
| Check today's collection | landing → `_FeeSnapshotCard`, or sub-nav → Finance | **0–1** |
| Approve exam results (publish) | `/management/approvals` → item → Approve | **3** |
| Read the daily brief | **not available** — no client calls `/intelligence/briefs/*`; the Flutter composer `lib/core/dai/dai_brief.dart` is DEAD (M28) | **∞** |

**Day one (no students, no marks, no fees):** the management dashboard is served
by `ErpAsyncBody` with a real `emptyMessage` ("No management data for the
selected filters.") and no mock fallback — checked
`management/management_providers.dart`, which contains **no** `.mock()` reference.
Honest. The filter chips, however, are the hard-coded strings
`['FY 2026-27','Q1','All quarters']` (`:32-36`) — a school opening in a different
financial year is shown the wrong year label. **`JOURNEY-009` (P2).**

**Sees what they should not:** nothing found at the route level — the principal's
permission set is intended to be wide. **Cannot see what they need:** the daily
brief (dead), and the five desks in §3.

**Friction:** every approval card on the dashboard navigates to the approvals
*list*, not to that approval (`:382,413`); the principal must find the row again.

### 4.2 Vice Principal · `ErpRole.vicePrincipal` (105 permissions)

`RolePermissionMatrix` gives vicePrincipal a set **identical** to principal, and
`homeRouteForStaffErp` gives them the identical landing. The only place the two
roles differ anywhere in `lib/` is
`exam_marks_entry_provider.dart:342-345`, which resolves the *remark author* label.

A vice principal is therefore not a role in this product; it is a job title on a
principal account. In a real school the VP's separation of duties matters —
`approval/approval_repository.ts:375-385` enforces SoD server-side on exam
approval, but the client offers no way to tell the two apart, and every
principal-only surface is equally open to the VP. Recorded as an observation, not
a defect: no incorrect behaviour was traced, only an absent distinction.

### 4.3 Teacher · `ErpRole.teacher` (31 permissions) — the one fully-designed role

**Lands on** `/teacher/dashboard` — greeting, staff check-in card, today's
schedule, pending-attendance warning banner, students-needing-attention,
adaptive feed, pending tasks, quick actions
(`teacher/dashboard/teacher_dashboard_screen.dart:74-194`). Genuinely useful.

| Task | Path | Taps |
|---|---|---|
| **Mark class attendance** | dashboard banner "mark_attendance" → `/teacher/attendance` (preselected via `?class=` from a schedule row, `teacher_navigation.dart:66-72`) → tap the 2–3 absentees → "Fill remaining present" → "Submit" | **~6 for a 40-child class** |
| Own check-in | dashboard check-in card → `/teacher/my-attendance` | **1** |
| Set homework | bottom nav "Teach" → Create → fill → post | **3 + form** |
| Enter marks | bottom nav "Teach" (matchPrefix covers `/teacher/exams`) → marks entry | **2** |
| Reply to a parent | bottom nav "Messages" → thread | **2** |
| Apply for leave | "More" → "Leave" | **2** |

Attendance marking is the best-executed flow in the product: exception-first
grid, bulk-mark with a destructive-overwrite confirm and Undo
(`teacher_attendance_screen.dart:215-272`), debounced draft autosave, a sticky
live tally, and a submit button that names the blocker (`"$unmarkedCount unmarked"`).

**Day one:** correct and honest at both levels —
`data.classes.isEmpty` → *"No classes scheduled for attendance."*; roster empty →
*"No students are enrolled in this class yet. They appear here as soon as the
office enrols them."*, deliberately separated from the "no search matches" case
(`:414-437`). This is the reference empty state for the whole product.
The **dashboard** is the exception: `teacherDashboardProvider` falls back to
`TeacherDashboardData.mock()` (`teacher_dashboard_provider.dart:322`) — CERT-002.

**Cannot see what they need — 15 of their 31 permissions unlock nothing.**
`canAccessAdminErpShell` requires `auth.role == UserRole.staff`
(`route_guards.dart:271-273`), and a teacher is `UserRole.teacher`. Every route
these permissions gate is in `RouteNames.adminErpRoutes`:

`viewStudent360`, `viewExams`, `viewEmployees`, `viewSubjects`,
`viewSubjectAssignments`, `viewLessonAnalytics`, `viewAchievementPromotion`,
`viewTeacherEffectiveness`, `viewStudentSuccessIntelligence`,
`viewExamIntelligence`, `viewHomeworkIntelligence`, `viewStudentRisk`,
`viewSchoolCalendar`, `viewEducation`, `viewTeacherAssistant`.

Two of these were already fixed by adding teacher-shell siblings
(`/teacher/lesson-logs`, `/teacher/syllabus-progress`, with the reason written
out at `teacher_shell.dart:74-81`). The rest were not.

**A live dead end on the daily path.** On `/teacher/class-teacher-dashboard`,
tapping a student under "Students requiring attention" calls
`openStudent360(context, item.sisStudentId)`
(`teacher_class_teacher_dashboard_screen.dart:122`) → `context.push('/student-360/<id>')`.
`student360` is in `RouteNames.adminErpRoutes:644`, so `_canAccessRoute`
(`app_router.dart:2273-2275`) → `canAccessAdminErpShell` → **false** → the router
redirects to `homeRouteForRole(UserRole.teacher)` = `/teacher/dashboard`.
The class teacher taps a child's name and is thrown back to Home with no
message. The same happens on the "Open Student 360" button in the risk dossier
(`teacher_student_risk_screen.dart:170-177`) — a button explicitly wrapped in
`AksharaViewAction(permission: Permission.viewStudent360)`, which the teacher
holds, so it renders, and then bounces. The working alternative
(`/teacher/student-risk/:id`) is bound to **long-press** only. **`JOURNEY-010` (P1).**

### 4.4 Finance · `ErpRole.financeAdmin` (12 permissions)

**Lands on** `/finance/dashboard` — KPI row, collection trend, recent payments,
admissions handoff queue, defaulters banner (fires only above 40 defaulters,
`finance_dashboard_screen.dart:69`). Useful.

| Task | Path | Taps (phone) |
|---|---|---|
| **Take a counter payment** | sub-nav "More" → "Collections" → "Record collection" → dialog | **3 + form** |
| Cheque / DD / PDC | sub-nav "More" → "Offline Payments" | **2** |
| Chase defaulters | banner (only if >40) or insight card → `/finance/defaulters` | **1** |
| Assign a fee structure | sub-nav "Fee Assignment" (inline, 4th tab) | **1** |
| Day close / reconcile | sub-nav "More" → "Reconciliation" | **2** |

`AksharaModuleSubNav` shows `maxInlineOnMobile = 4`
(`lib/shared/widgets/akshara_navigation.dart:296,320`), and `kFinanceNavScreens`
(`finance/finance_navigation.dart:6-21`) is ordered
Dashboard · Fee Structures · Student Accounts · Fee Assignment · **Collections** ·
**Offline Payments** · … So on a phone the two screens where money is actually
taken are both in the overflow sheet, while Fee Structures — a once-a-year
configuration screen — holds a permanent inline slot. The dashboard itself has
**no** "Record collection" action. **`JOURNEY-011` (P1).**

**Day one:** `FinanceAsyncBody` with `emptyMessage: 'No finance data for the
selected filters.'` and no mock fallback — honest. But if this user opens
`/admin`, their workspace hero asserts **"₹4.2L Collected today · ₹1.8L Pending"**
(JOURNEY-001).

**Sees what they should not:** `financeAdmin` holds only 12 permissions and the
route map matches them; nothing over-broad was found.

### 4.5 HR · **no such role**

There is no `ErpRole` for HR. `viewHr`/`manageHr` are held by superAdmin,
schoolAdmin, principal, vicePrincipal and management —
i.e. **the only way to run payroll in NIKSHA OS is to be the principal or a
school admin.** A dedicated HR manager cannot exist client-side even though the
server seeds `hrManager` with exactly the right grants
(`20260608100000_rbac_foundation.sql:228`).

If a school *does* assign `hrManager`, §1.2 applies: that person is mapped to
`ErpRole.superAdmin` client-side, lands on `/admin`, is shown the
school-administration fabricated hero, sees a tile grid filtered by their real
(HR-only) server permissions — **HR + Employee Platform** — and is simultaneously
offered `/admin/plan/assign` because that gate is role-keyed.

Journey once inside HR (whoever holds it):

| Task | Path | Taps |
|---|---|---|
| Approve staff leave | `/hr/dashboard` → sub-nav "Leave" (4th inline tab) → batch decide | **2** |
| Run payroll | sub-nav "More" → "Payroll" → Run | **3** |
| Check the muster | sub-nav "Attendance" | **1** |
| Decide manual-attendance requests | `/hr/attendance` → `staff_check_in_card.dart:89,98` | **2** |
| Leave accrual | **impossible from the UI** — `POST /hr/leave/accrual/run` has zero Dart callers (M28) | **∞** |

**What breaks:** approving leave writes a status flip and nothing else
(XMOD-CHAIN 2). The approver must then remember to mark that employee's
attendance by hand — and there is no HR attendance write endpoint at all, so
they cannot. The muster will print `A`. Detailed in `SIM-real-school.md`.

**Defect `JOURNEY-012` (P1)** — no HR role.

### 4.6 Office Staff / Reception · **no such role client-side; near-powerless server-side**

`officeStaff` exists as a server role and is granted exactly two things:
`viewAdminHub` (`20260608100000_rbac_foundation.sql:238`) and
`requestStudentCertificate` + `approveCertificateRequest`
(`20260884000000_certificate_requests.sql:134-149`). **Reception does not exist
in any layer.**

Trace of an office clerk's first minute:

1. Log in. `ErpRole.fromName('officeStaff')` → null → `?? ErpRole.superAdmin`
   (`auth_mapper.dart:63-66`).
2. `homeRouteForStaffErp(superAdmin)` → `/admin`.
3. Workspace = `schoolAdministration` → hero renders **"1,248 Students · 86 Staff
   · 96% Attendance"** (JOURNEY-001).
4. Tile grid = permissions ∩ workspace modules. Their only module-bearing
   permission is `requestStudentCertificate`, and `AdminModule.certificateDesk`
   is in **no** workspace (§3) → **zero tiles**, and `AdminHubScreen` has no
   empty-state branch (§2.2) → a blank area under the fabricated hero.
5. The drawer (not workspace-scoped) *does* list Certificates. Nothing on screen
   suggests opening it.

So the role the certificate desk was built for lands on a screen with fabricated
numbers, no tiles, no empty state, and no signpost to the one thing they can do.
And the desk itself is where the school's front office would raise the whole
front-office workload — gate passes, complaints, visitor handling — none of which
`officeStaff` is granted.

**Defects `JOURNEY-002`, `JOURNEY-005`, `JOURNEY-008`, `JOURNEY-013` (P1, no
front-office role).**

### 4.7 Librarian · `ErpRole.librarian` (3 permissions)

**Lands on** `/admin` — a tile grid containing exactly **one** tile, "Library",
under a hero claiming **"8,450 Titles · 214 On loan · 7 Overdue"** on a school
whose catalogue is empty.

| Task | Path | Taps |
|---|---|---|
| Issue a book | `/admin` → Library tile → "Issue book" (`library_dashboard_screen.dart:58`) | **2** (1 of them wasted) |
| Take a return | Library → sub-nav "Returns" (inline, 4th) | **2** |
| Chase overdues | Library dashboard banner → `/library/overdue` (`:89`) | **2** |
| Collect a fine | Library → sub-nav "More" → "Fines" | **3** |

The library module itself is well-built. The journey defect is entirely the
landing: `homeRouteForStaffErp` has no `librarian` arm, so a single-module role
is routed through a single-tile menu (JOURNEY-004) that lies about the
collection size (JOURNEY-001).

**Cannot see what they need:** there is no way to close a departed student's
membership — `library/library_router.ts:54,102` exposes only `GET`/`POST
/library/members` (XMOD chain 6, hop 5).

### 4.8 Transport · `ErpRole.transportManager` (3 permissions)

**Lands on** `/admin`, one tile ("Transport"), hero claiming **"18 Routes · 22
Buses · 97% On-time"** before a single route is created.

| Task | Path | Taps |
|---|---|---|
| Allocate a student to a route | Transport → sub-nav "Allocation" (5th → **overflow on a phone**) | **3** |
| **Raise the fee demand for that allocation** | Transport → Settings → "Raise demand" (`transport_workflow_actions.dart:647,834`) | **3 more, and nothing prompts it** |
| Mark bus attendance | Transport → sub-nav "More" → "Attendance" | **3** |
| Notify a delay | Transport → "More" → "Tracking" → notify | **3** |

`kTransportNavScreens` is Dashboard · Routes · Vehicles · Drivers · **Allocation** ·
**Attendance** · Tracking · … so on a phone the two daily operations (allocation,
attendance) are both behind "More" while Vehicles and Drivers — registry screens
— sit inline. Same shape as the Finance ordering defect. **Folded into
`JOURNEY-011`.**

**Nobody tells the driver anything.** XMOD chain 6 hop 2b: the only transport
notification in the codebase is `POST /transport/notify-delay`. A student leaving
the school, a route change, or a stop change reaches the driver by telephone.

### 4.9 Nurse · **`healthStaff`, server-only**

Migration `20260887000000_student_health.sql:42-43` creates the role and grants it
`manageStudentHealth` and `administerStudentMedication` **exclusively** (`:460-468`)
— the migration's own comment says giving a drug to a child must be an explicit,
auditable act. The design is right. The client cannot express it:

- `ErpRole` has no `healthStaff` value, so `claims.erpRoles` = `[superAdmin]`
  (§1.2) and `RoleGuard`/`hasRole` checks see a super admin, not a nurse.
- `AdminModule.studentHealth` is in no workspace (§3), so the Infirmary tile can
  never render on the hub — the nurse's console is drawer-only.
- `lib/features/student_health/care_alert/care_alert_widget.dart` — the widget
  that would show a teacher a child's care alert — is imported nowhere in `lib/`
  (M28, DEAD). The teacher-facing half of student health does not render at all.

A school nurse can be given the right database permissions and still have no
correct identity, no landing, no tile and no way to reach teachers.
**`JOURNEY-014` (P1).**

### 4.10 Management · `ErpRole.management` (58 permissions)

**Lands on** `/admin`, not `/management/dashboard` — despite holding
`viewManagement`, and despite `homeRouteForStaffErp` routing principal and
vicePrincipal to exactly that screen. A wasted screen for the role the module is
named after (JOURNEY-004).

| Task | Path | Taps |
|---|---|---|
| Read school performance | `/admin` → Management tile → sub-nav "Performance" (6th → overflow) | **3** |
| Approvals | `/admin` → Management → dashboard approval card | **2** |
| Finance overview | `/admin` → Finance tile (they hold `viewFinance`) | **2** |

**Sees what they should not:** `management` holds `viewFinance`, `viewSis`,
`viewHr`, `viewHostel`, `viewLibrary`, `viewInventory`, `viewTransport`,
`viewDirectorPortal`, `viewOrganizationBuilder`, `viewAiWallet` — 58 permissions,
the second-widest set in the product — while holding **no** exams, timetable,
communications, lesson-log or subject permissions. A trustee who can read every
employee's salary structure and every student's dossier but cannot look at the
timetable is not a coherent role. Recorded as an observation; no wrong behaviour
was traced, only a questionable grant shape. Whether a school's "management"
users should hold `viewHr` is an owner decision, not a code defect.

### 4.11 Parent · `ErpRole.parent` (6 permissions)

**Lands on** `/parent/dashboard`. Bottom nav Home · Academics · Fees · Messages ·
More; the More sheet correctly drops `SchoolBuildScope`-hidden destinations, so
the PTM tile does not render in a school build (`persona_nav.dart:212-213`).

| Task | Path | Taps |
|---|---|---|
| Is my child in school today | landing (attendance summary on the dashboard) | **0** |
| **Pay a fee** | nav "Fees" → "Pay now" → method → pay | **3–4** |
| See homework | nav "Academics" → Homework | **2** |
| See results | nav "Academics" → Exams | **2** |
| Message the teacher | nav "Messages" → thread → send | **3** |
| Apply for the child's leave | "More" → "Leave" (`parent_navigation.dart:41-47` opens the Apply section directly) | **2** |

**Day one and on any API failure — three separate fabrications.** Two are already
registered (CERT-001 `/parent/fees` ₹23,000 statement + four fake "Paid" rows;
CERT-002 `ParentDashboardData.mock()` / `ParentHomeworkData.mock()`). A **third**
was found in this workstream and is not in the register:

`parentPaymentSummaryProvider` (`parent/payment/parent_payment_provider.dart:47-101`)
resolves `data ?? async.value ?? _fallbackSummary(installmentId)`.
`watchRepositoryFuture` returns null whenever the future is not in the `data`
state (`lib/core/providers/repository_future.dart:12-13`) and `AsyncError.value`
is null, so **every failed or still-loading payment-summary load renders the
fallback**: child **"Ravi Kumar"**, class **"8-A"**, *"Due 12 Jun 2026"*,
₹4,000 + ₹200 late fee, with a four-line breakdown. The screen's app bar shows
that name and class as the subtitle (`parent_payment_screen.dart:102-104`), and
`submitParentPayment` sends `amount: summary.totalAmount`
(`parent_payment_provider.dart:134-145`) — the fabricated ₹4,200 — to
`POST /parent/payments/initiate`.

The screen's *terminal* state is honest ("You have NOT been charged",
`parent_payment_screen.dart:110-120`) — that part is correct and should be kept.
The defect is the summary the parent reads and authorises before it.
**`JOURNEY-007` (P0).**

Compounding it, the dashboard "Pay now" action hard-codes the installment:
`case 'pay_fee': context.push('${RouteNames.parentPayment}?installmentId=term_2')`
(`parent_navigation.dart:33-36`), and `handleParentFeesNavigation` defaults to
`installmentId ?? 'term_2'` (`:113`). A parent tapping Pay Now from Home always
opens the fixture installment, whatever they actually owe. This is the same
demo-id residue as CERT-003, on the *payment* path rather than the receipt path.
**`JOURNEY-015` (P1).**

**Dead-end links:** in `handleParentDashboardNavigation`'s default branch,
`notice_n1` and `event_e2` route to `RouteNames.parentPtm`
(`parent_navigation.dart:83-85`) — a route hidden by `SchoolBuildScope`, whose
builder returns `AccessDeniedScreen`. The More sheet correctly hides PTM; this
handler does not. **`JOURNEY-016` (P2).**

**Cannot see what they need:** a parent holds `requestStudentCertificate`
server-side (`20260884000000_certificate_requests.sql:134-140`) and the backend
explicitly supports the parent scope
(`certificate_desk/certificate_desk_handlers.ts:167-182`), but the only screen is
`/certificate-requests`, an admin-ERP route. A parent cannot request a bonafide
certificate in the app; the office must raise it for them (XMOD manual step 27).

### 4.12 Student · `ErpRole.student` (**0 permissions in the local matrix**)

`RolePermissionMatrix._permissionsForRole` has **no entry for `ErpRole.student`**.
Access is pure persona ownership over the nine `/student/*` routes
(`isPersonaOwnedRoute`, `app_router.dart:2220-2230`).

**Lands on** `/student/dashboard`. Nav: Home · Learn · Schedule · Results · More
(Report Card, Progress, Notices, Profile).

| Task | Path | Taps |
|---|---|---|
| What is due today | landing | **0** |
| Submit homework | nav "Learn" → item → submit | **3** |
| See results | nav "Results" | **1** |
| See my attendance | dashboard attendance **KPI tile** (`student_dashboard_screen.dart:140-142`) | **1** — but `/student/attendance` appears in **neither** the primary nor the More list (`student_shell.dart:24-73`); it is only a `matchPrefixes` entry on the Results tab. Leaving the dashboard loses the only entry point |
| Read notifications | **impossible** — the bell pushes `/parent/notifications` (`student_navigation.dart:35`), which `_canAccessRoute` bounces back to the student dashboard. **CERT-004** |

**Day one:** `StudentDashboardData.empty()` (`student_dashboard_provider.dart:274-285`)
— the correct honest fallback, and the pattern CERT-001/002 and JOURNEY-007
should adopt.

**Sees what they should not:** nothing at the client route level. The real leak
is server-side and already recorded in XMOD — `/parent/experience/hub` returns
unpublished marks, and a merely-scheduled exam reads as 0% because
`provisionMarkSlots` inserts `marks_obtained = 0`.

### 4.13 The roles nobody asked about but the switch still routes

`superAdmin` → `/admin` (17 tiles, correct — it is a launcher role).
`schoolAdmin` → `/admin` (16 tiles, correct).
`admissionsCounselor` → `/admin` → 2 tiles (Admissions, Marketing) under
*"23 Open enquiries · 14 Admissions · 9 Visitors today"*, none of which is real.
`hostelManager` → `/admin` → 1 tile, hero *"312 Residents"*.
`storekeeper` → `/admin` → 1 tile; `inventoryManager`, same workspace and same
single module, → `/inventory/dashboard` directly. There is no rule, only an
unfinished switch.

---
## 5. Summary — the 13 roles

| # | Role asked for | Exists as… | Dedicated shell | Landing | Landing is useful | Taps to #1 task | Day-one honest |
|---|---|---|---|---|---|---|---|
| 1 | Principal | `ErpRole.principal` | ✗ (admin shell) | `/management/dashboard` | **yes** | 1 (approvals) | yes |
| 2 | Vice Principal | `ErpRole.vicePrincipal` (= principal) | ✗ | `/management/dashboard` | yes | 1 | yes |
| 3 | Teacher | `ErpRole.teacher` | **✓ TeacherShell** | `/teacher/dashboard` | **yes** | ~6 (attendance) | screen yes, dashboard **no** (CERT-002) |
| 4 | Finance | `ErpRole.financeAdmin` | ✗ | `/finance/dashboard` | yes | 3 (collect) | yes |
| 5 | **HR** | **nothing** (server `hrManager` only) | ✗ | — | — | — | — |
| 6 | **Office Staff** | **nothing** (server `officeStaff`, 1 permission) | ✗ | `/admin` | **no — zero tiles** | ∞ | **no** (JOURNEY-001) |
| 7 | **Reception** | **nothing anywhere** | ✗ | — | — | — | — |
| 8 | Librarian | `ErpRole.librarian` | ✗ | `/admin` (1 tile) | **no** | 2 | **no** (JOURNEY-001) |
| 9 | Transport | `ErpRole.transportManager` | ✗ | `/admin` (1 tile) | **no** | 3 | **no** (JOURNEY-001) |
| 10 | **Nurse** | **nothing** (server `healthStaff` only) | ✗ | `/admin` | **no — Infirmary tile cannot render** | drawer only | **no** |
| 11 | Parent | `ErpRole.parent` | **✓ ParentShell** | `/parent/dashboard` | yes | 0 (attendance) / 3 (pay) | **no** (CERT-001/002, JOURNEY-007) |
| 12 | Student | `ErpRole.student` (0 perms) | **✓ StudentShell** | `/student/dashboard` | yes | 0 | **yes** — the reference pattern |
| 13 | Management | `ErpRole.management` | ✗ | `/admin` | **no** | 2 | **no** (JOURNEY-001) |

**10 of 13 roles have no dedicated persona shell.** Three of the thirteen do not
exist in the client at all, and one of those three (Reception) exists nowhere in
the system. Six roles land on a launcher; four of those launchers hold one tile.
Seven of the seven Admin-Hub workspace heroes show fabricated numbers.

## 6. What was checked and found clean

Recorded so an empty finding is not mistaken for an unperformed check.

- **The "More" sheets honour the hide gates.** `MoreNavSheet` filters on
  `SchoolBuildScope.isRouteHidden` (`persona_nav.dart:212-213`), so parent PTM
  never renders a tile that would bounce to Access Denied. `HostelSubNav`
  (`:24`), `ManagementSubNav` (`:24`) and `SisSubNav` (`:24`) apply the same
  predicate. Only the parent *navigation handler* misses it (JOURNEY-016).
- **Persona-ownership is segment-precise.** `isPersonaOwnedRoute` /
  `_isUnderPathSegment` (`app_router.dart:2220-2236`) cannot be fooled by
  `/student-health` or `/student-360`; the earlier `startsWith` bug is closed.
- **`ParentExamsData.mock()`** (`parent/exams/exam_models.dart:132`) exists but
  has **zero call sites** — it is a dead constructor, not a live fallback.
  Grepped across `lib/`.
- **Management, Finance, Library, Transport and Hostel providers contain no
  `.mock()` fallback.** The five live per-screen mock fallbacks are exactly the
  ones already registered (CERT-001, CERT-002 ×3, CERT-006); this workstream
  found one more (JOURNEY-007) and no others.
- **Teacher attendance empty states** distinguish "no classes", "no roster yet"
  and "no search matches" — three separate honest messages.
- **The payment flow's terminal state is fail-closed and honest** — it says "You
  have NOT been charged" rather than fabricating a receipt
  (`parent_payment_screen.dart:110-120`).
- **`ControlCenterGuard` and `RbacModuleRegistry.canAccessControlCenter` both
  AND the role check with a permission check**, so the §1.2 role mis-mapping does
  **not** open Control Center. Verified line by line.

## 7. Verification boundaries

- **Static trace only.** No release binary was run — `guardForRelease` requires
  production plus a live API — so every tap count is derived from the widget tree
  and the router, not measured on a device. Counts assume the happy path with
  data already loaded.
- **No live tenant was read.** Which server roles a real school actually assigns
  (`officeStaff`, `hrManager`, `healthStaff`, `classTeacher`, `coordinator`) is a
  data question. §1.2's impact is proven from code but its *frequency* is not
  knowable here. What is certain is that the client's fallback for that case is
  `ErpRole.superAdmin`.
- **Server permission snapshots could not be fetched**, so every statement about
  what a role sees *in production* rests on the migration seeds plus
  `RolePermissionMatrix`, not on a live `effectivePermissions` array.
- **The web app (`web/`) was not traced.** All findings are Flutter + migrations.
- **Tablet/desktop layouts** were read but not exercised; the sub-nav overflow
  findings (JOURNEY-011) are phone-specific by construction
  (`AksharaBreakpoints.isMobile`).

## 8. Defects raised by this workstream

`JOURNEY-001` (P0) · `JOURNEY-002` (P0) · `JOURNEY-003` (P1) · `JOURNEY-004` (P1) ·
`JOURNEY-005` (P1) · `JOURNEY-006` (P2) · `JOURNEY-007` (P0) · `JOURNEY-008` (P1) ·
`JOURNEY-009` (P2) · `JOURNEY-010` (P1) · `JOURNEY-011` (P1) · `JOURNEY-012` (P1) ·
`JOURNEY-013` (P1) · `JOURNEY-014` (P1) · `JOURNEY-015` (P1) · `JOURNEY-016` (P2)

All recorded in `docs/certification/DEFECT_REGISTER.md`. Nothing was fixed.
