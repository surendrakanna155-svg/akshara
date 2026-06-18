# WORKSPACE ARCHITECTURE AUDIT — Akshara ERP

> **Audit date:** 2026-06-18 · **Base commit:** `70194d6`
> **Target model:** USER → ROLE → WORKSPACE → TASK
> **Verdict:** ❌ **The workspace model is NOT implemented.** Today the app is a *role-filtered single dashboard*. The intended model is structurally impossible in the current data model.

---

## 1. The intended architecture (owner's vision)

```
USER  →  ROLE(s)  →  WORKSPACE(s)  →  TASKS
```

- A **Teacher** sees a **Teacher Workspace**.
- A **Teacher + Inventory Manager** sees **two workspaces** and switches between them.
- A **Teacher + Exam Coordinator** sees a **Teacher Workspace** and an **Exam Workspace**.
- **Nobody sees the whole ERP** — only their workspaces and the tasks inside them.

This is the correct mental model for a simple ERP. It maps to how schools actually think ("my teaching hat" vs "my store-keeping hat").

## 2. What actually exists in code

There is **no `Workspace` class, enum, or model anywhere** in `lib/` (verified by search). Instead there are two layers:

| Layer | Code | Purpose |
|-------|------|---------|
| **App shell selector** | `UserRole {parent, teacher, student, staff}` (`lib/features/auth/auth_models.dart:7`) | Picks *which app* you enter |
| **Permission set** | `ErpRole {15 roles}` (`lib/core/security/erp_role.dart:2`) | Computes a flat list of allowed permissions |

Every `staff` user lands in **one shared Admin shell** (`lib/features/admin/admin_hub_screen.dart`) showing a **single flat grid of up to 22 module cards** (`lib/features/admin/admin_navigation_provider.dart:12-189`), filtered only by removing cards the role lacks permission for.

> The `lib/features/workflow/` folder is **not** workspaces — it is an automation-rules engine. Do not be misled by the name.

**So the real model is:** `USER → ROLE → (one big filtered menu) → TASK`. The WORKSPACE layer is missing entirely.

## 3. Violations of the workspace model

### V1 — One shared staff shell, not scoped workspaces 🔴
A librarian and a super-admin traverse the *identical* shell; only the visible card list differs. Entry is gated only by `role == UserRole.staff` (`lib/router/route_guards.dart:172`), not by the specific job. There is no "Teacher Workspace" or "Inventory Workspace" as a bounded space.

### V2 — Single-role data model makes multi-hat users impossible 🔴
`AuthState.role` is a single value (`auth_models.dart:152`); `AuthClaims.erpRole` is a single value (`auth_claims.dart:21`); the login token carries one `role` string. **A person who is both Teacher and Inventory Manager cannot be represented.** The owner's headline example is structurally unsupported today.

### V3 — Flat global module list instead of responsibility grouping 🟠
`kAllAdminNavDestinations` is a global list of *all* 22 modules + non-school verticals (Healthcare, Salon, Restaurant, Accommodation, White Label, Platform Ops). Filtering is subtractive, so a broadly-granted role sees the **entire ERP** rather than a bounded workspace (`admin_navigation_provider.dart:12-189`).

### V4 — Over-broad role grants leak unrelated modules 🟠
`principal`, `schoolAdmin`, and `vicePrincipal` each receive ~90+ permissions, including non-school verticals. A **school principal currently has `viewSalonBusiness`, `viewRestaurantHospitality`, `viewAccommodation`, `viewHealthcare`** (`lib/core/security/role_permissions.dart:189-194, 279-379`). This is both a UX violation (sees things irrelevant to a school) and a least-privilege violation.

### V5 — Cross-shell leakage 🟠
`_canAccessRoute` lets any `UserRole.staff` enter `/teacher/*` routes unconditionally — `location.startsWith('/teacher') || canAccessAdminErpShell` — with no check that the staff member is actually a teacher (`lib/router/app_router.dart:2265`).

### V6 — No workspace switcher UI 🟠
Even if multi-role existed, there is no UI affordance to switch between "Teacher mode" and "Inventory mode." The home route is a single `switch` returning one destination (`qa_login_persona.dart:88`).

## 4. RBAC violations (security view)

| ID | Issue | Severity | Evidence |
|----|-------|----------|----------|
| R1 | Enforcement is 100% client-side; no server re-check | 🔴 | `rbac_service.dart`; `enableApiMode:false` |
| R2 | `ServerRbacRouteInventory` is dead code (0 references) | 🔴 | `server_rbac_route_inventory.dart` |
| R3 | "Server permission sync" is an explicit stub ("no HTTP sync in v2.0") | 🔴 | `server_permission_provider.dart:12` |
| R4 | Mutation guards are manual per-provider; ~40 files must each remember to call `assertManagePermission`; registry is descriptive, not enforced | 🟠 | `mutation_permission_validator.dart:25`, `mutation_permission_registry.dart` |
| R5 | QA login returns the full role matrix and forces mock mode | 🟠 | `rbac_service.dart:50`, `environment.dart:112-119` |
| R6 | Over-broad default grants (V4) violate least privilege | 🟠 | `role_permissions.dart` |

## 5. Roles found in code

- **`UserRole`** (shell): `parent, teacher, student, staff`
- **`ErpRole`** (15): `superAdmin, schoolAdmin, principal, vicePrincipal, management, financeAdmin, admissionsCounselor, teacher, parent, student, transportManager, hostelManager, librarian, inventoryManager, storekeeper`

Note: `vicePrincipal` exists in the enum and gets permissions, but a prior audit (`RED_TEAM_OPERATIONAL_AUDIT.md`) flagged that there is **no real VP delegation/acting-principal workflow** — the role is a permission bundle, not a working persona.

## 6. Recommended target design (no code now — design only)

1. **Introduce a first-class `Workspace` concept.** A workspace = a named bundle of modules + tasks for one responsibility (e.g. `TeacherWorkspace`, `ExamWorkspace`, `InventoryWorkspace`, `FinanceWorkspace`, `PrincipalWorkspace`).
2. **Make the user→role mapping many-to-many.** A user can hold several roles; each role maps to one or more workspaces.
3. **Replace the flat admin grid** (`kAllAdminNavDestinations`) with workspace-scoped navigation. The home screen shows the user's workspace(s); if more than one, a **workspace switcher** (top-level segmented control or launcher) lets them flip hats.
4. **Scope permissions by workspace, and tighten defaults.** Remove vertical permissions from school roles. A principal should never see Salon/Restaurant.
5. **Move enforcement server-side.** Turn on API mode; implement the dormant permission-sync; make `ServerRbacRouteInventory` real; add a central mutation gate instead of 40 manual asserts.
6. **Define the VP/delegation model properly** (acting principal, approval delegation).

### Suggested initial workspace catalog (for first 10 schools)
| Workspace | Primary roles | Core tasks |
|-----------|---------------|-----------|
| Teacher | teacher, class teacher | attendance, homework, marks entry, messages |
| Principal | principal, vice principal | approvals inbox, school KPIs, staff, notices |
| Exam | exam coordinator (new) | exam create/schedule, paper, publish, report cards |
| Finance | financeAdmin, accountant | fees, receipts, concessions, refunds |
| Front Office | admissionsCounselor | admissions, enquiries, enrollment, certificates |
| Inventory | inventoryManager, storekeeper | stock, purchase orders, distribution |
| Transport | transportManager | routes, vehicles, drivers |
| Hostel | hostelManager | rooms, allocation, attendance |
| Library | librarian | catalog, issue/return, fines |
| Parent (app) | parent | child's attendance/fees/homework/results |
| Student (app) | student | timetable, homework, results |

> Everything outside this catalog (verticals, franchise, white-label, platform ops) should be **out of the default build** for schools.

## 7. Priority fixes (ranked)

1. 🔴 Make the data model multi-role (precondition for everything else).
2. 🔴 Introduce the `Workspace` abstraction + switcher.
3. 🔴 Move RBAC enforcement server-side (depends on turning on API mode).
4. 🟠 Tighten role grants; strip vertical permissions from school roles.
5. 🟠 Replace flat admin grid with workspace-scoped nav.
6. 🟠 Fix cross-shell leakage (V5) and add a central mutation gate (R4).
7. 🟡 Build the real VP/delegation persona.

**Bottom line:** The workspace vision is sound and is the single highest-leverage architectural change for "users only see their job." It is a meaningful redesign, not a tweak — but it also naturally forces the scope-trimming the product needs.
