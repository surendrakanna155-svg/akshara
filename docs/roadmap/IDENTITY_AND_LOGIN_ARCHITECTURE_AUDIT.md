# Akshara ERP — Identity & Login Architecture Audit  🔴 P0

**Status:** ✅ **AUDIT COMPLETE (2026-07-17)** — this is the *Phase 1* deliverable of the owner's
"Continuation Roadmap Update & Identity Architecture Review". It is a **read-only audit of current
code** (branch `feature/qp-content-readiness`), not an implementation. Every claim cites `file:line`.
**Method:** prior PASS reports and comments were not accepted as evidence — only source.
**Companion:** [`PROGRAM_SOP_IDENTITY_AND_PLATFORM.md`](PROGRAM_SOP_IDENTITY_AND_PLATFORM.md) (the locked
decisions + governance + reconciliation) and the master roadmap Program SOP section.

> **Headline verdict:** the owner's login *philosophy is already the implemented philosophy.*
> Login today is **Mobile Number → OTP → backend automatically resolves School + User + Role +
> Permissions + Landing** — the client never picks a role. The gaps are not in the philosophy; they
> are in **multi-school selection, student-via-parent login, mobile-number change, the transfer
> lifecycle, identity-mutation audit events, and account ownership fields** — most of which are
> **already logged as frozen PRA findings or the deferred `P1-CODE-4` identity item.** This audit
> reconciles them so no duplicate roadmap work is created.

---

## 0. Architecture at a glance

- **Not Supabase Auth/GoTrue.** Auth is a hand-rolled **HS256 JWT + OTP** system in
  `supabase/functions/_shared/` (`jwt.ts:32-59`, `auth_handlers.ts`). The `users`/`sessions`/
  `refresh_tokens` tables are app-owned; Supabase session persistence is explicitly disabled
  (`db.ts:4-8`).
- **One global identity per phone.** `users` has `phone TEXT NOT NULL UNIQUE`
  (`supabase/migrations/20260607100000_core_platform_schema.sql:33-42`). A phone maps to exactly one
  `users.id` platform-wide; roles/schools fan out through join tables, never through duplicate user
  rows.
- **Backend decides everything.** After OTP verify, `resolveAuthSessionContext`
  (`auth_context.ts:73-105`) picks scope in a fixed order `["school","organization","parent",
  "student"]`, resolves the role, and embeds `role`, `permissions[]`, `scope`, `school_id`,
  `tenant_id` directly into the JWT (`buildAccessClaims`, `auth_handlers.ts:116-138`). The client
  only *renders* what the server decided — landing route is chosen from the server `scope`
  (`lib/features/auth/auth_role_mapping.dart:6-18`, `lib/router/app_router.dart:2482-2500`;
  web `web/src/lib/auth/roles.ts:42-79`).

**This is exactly the owner's stated law:** *"Users never manually choose their role … the backend
determines School, User, Role, Permissions, Landing page."* ✅ **No redesign of the core flow is
required** — only the gaps below.

---

## 1. Owner Phase-1 review checklist — item-by-item findings

| # | Review item | Verdict | Evidence |
|---|---|---|---|
| 1 | **OTP authentication flow** | ✅ Implemented | `POST /auth/login` (`auth_handlers.ts:204-354`) → `otp_requests` (SHA-256 hashed OTP), `POST /auth/verify-otp` (`:356-464`). Rate-limited (`otp_rate_limit.ts:25-65`); SMS via Fast2SMS (`sms_provider.ts`), OTP returned in-response only for pilot/dev (`:87-91`). |
| 2 | **Mobile-number ownership model** | ✅ Implemented | Global `UNIQUE` on `users.phone` (`core_platform_schema.sql:35`) — the *only* phone-uniqueness constraint. One phone ⇒ one identity; multiple roles/schools via `school_memberships`, `student_guardians`, `school_membership_roles`. |
| 3 | **User identity model** | ✅ Implemented | Single `users` row per human; affiliation via `organization_memberships` (`:44-56`), `school_memberships` (`:58-70`), `student_guardians` (`phase2_rls_scope.sql:24-38`), `students.user_id`, `employees.user_id`. |
| 4 | **School membership model** | ✅ Implemented (single-active in practice) | `school_memberships UNIQUE(user_id, school_id)` with `status ∈ {active,suspended,revoked}`; multi-role via `school_membership_roles` (`rbac_foundation.sql:48-60`). Schema **allows** many memberships; the client never lets a user hold/pick more than one active school → see gap G1. |
| 5 | **Role resolution logic** | ✅ Implemented (backend-authoritative) | `resolveAuthSessionContext` (`auth_context.ts:73-105`), primary role via `resolvePrimaryRoleSlug` (`permission_resolver.ts:52-62`); role + permissions minted into JWT. Client never chooses. |
| 6 | **Parent login flow** | ✅ Implemented | `parent` scope resolves `student_guardians` (`auth_context.ts:246-306`); multiple children aggregated into `childIds`/`childProfiles` and surfaced to the child-switcher (`auth_provider.dart:519-541`). Fan-out capped at 50 (`auth_context.ts:60-63`). |
| 7 | **Student login flow** | ⚠ Partial — **student-via-parent-mobile does NOT exist** | Student login requires the student to have their **own distinct phone** (`students.user_id IS NOT NULL`, `auth_context.ts:308-343`; `auth_login_helpers.ts:10-40`). Admissions never sets `students.user_id` (`admissions_repository.ts:1252-1258`); import sets it only when a separate `studentPhone` is supplied (`onboarding_user_provisioning.ts:235-268`). → gap **G2**. Conflicts with frozen *Student Identity Architecture Decision* ("login = OTP-to-PARENT; student phone NEVER required"). |
| 8 | **Teacher/staff login flow** | ✅ Implemented | Same OTP endpoints; `school` scope via `school_memberships` (`staff_login_provider.dart:156-201`). Note: staff screen shows an **Email tab** the backend rejects (`EMAIL_NOT_SUPPORTED`, `auth_handlers.ts:52-55`) → cosmetic gap **G7**. |
| 9 | **Multi-school handling** | ⚠ Partial scaffolding, **no working UX** | `POST /auth/context/switch` exists (`auth_handlers.ts:560-618`) but has **zero client callers** (Flutter or web). No active-school selector UI. If a user has 2+ active school memberships and sends no `schoolId`, `resolveSchoolContext` does `.limit(1)` with **no `ORDER BY`** → arbitrary silent pick (`auth_context.ts:107-123`). No `school_groups` table exists. → gap **G1** (= frozen `PRA-P1-04`). |
| 10 | **Session creation** | ✅ Implemented | `sessions` row per login/refresh/switch (`auth_handlers.ts:140-202`); live session re-validation on every request (`permission_middleware.ts:20-48`, `session_validation.ts`) — logout/revoke takes effect immediately, not just at token expiry. |
| 11 | **Token generation** | ✅ Implemented | HS256 JWT (`jwt.ts:32-59`); claims carry `sub, tenant_id, school_id, role, permissions[], scope, child_ids[], session_id` (`jwt.ts:11-30`). Refresh tokens hashed, single-use, reuse-detection revokes the family (`auth_handlers.ts:466-558`). |
| 12 | **Active-school selection logic** | ❌ Absent | No selector; implicit first-match only (see #9 / G1). |
| 13 | **Transfer / TC workflow** | ⚠ Partial — exists but does **not** manage the identity lifecycle | `issueTransferCertificate` (`sis_certificates_repository.ts:336-417`): no-dues gate → sequential serial → `UPDATE students SET status='transferred'`. It does **not** touch `student_guardians` or `school_memberships`, so the **parent keeps active visibility of a transferred child indefinitely** (`auth_context.ts:246-306` filters only guardian `status='active'`). No inter-school transfer. → gaps **G3, G4** (= frozen `PRA-P2-28`). |
| 14 | **Admission workflow** | ✅ Implemented | Lead → application → approval (SoD) → enrollment creates `students`; guardian auto-linked by **global phone lookup** (`app.lookup_guardian_user_for_enrollment`, `20260611400000_*.sql:100-109`). RBAC `manageAdmissions`. |
| 15 | **User lifecycle (create / modify / deactivate)** | ⚠ Partial | Creation via admissions, onboarding import/invite (`manageOnboarding`), employee role-assign. **No dedicated "create employee" endpoint** (only via import); `hrManager` cannot run onboarding import. **No `created_by`/`approved_by`/`last_modified_by`/`status` on `users`**; memberships have `status` but no ownership columns. → gaps **G5, G6**. |
| 16 | **Edge cases** | ⚠ See gap register | Multi-active-school silent pick (G1); staff-who-are-parents locked out (G1 = `PRA-P1-04`); transferred child still visible to parent (G3); no mobile-change (G5 = `P1-CODE-4`); no guardian/custody change (G5); email-tab dead path (G7). |

---

## 2. Gap register (reconciled — every gap maps to existing or new work)

**Legend:** *Reconcile* = the gap is already tracked; SOP **elevates/extends** it (no duplicate item). *New* = genuinely missing, becomes new SOP work.

| Gap | Description (evidence) | Owner requirement it blocks | Disposition |
|---|---|---|---|
| **G1** | No active-school selector; `handleContextSwitch` has zero callers; 2-school users get an arbitrary `.limit(1)` pick; staff-who-are-parents can't see their child (`auth_context.ts:66-71,107-123,273-276`) | Phase 3 (Multi-School), Phase 4 (Parent login) | **Reconcile → elevate `PRA-P1-04`** (P1→P0 under SOP-ID) |
| **G2** | No student-login-via-parent-mobile; student needs own phone (`auth_context.ts:308-343`, `admissions_repository.ts:1252-1258`) — contradicts frozen *Student Identity Architecture Decision* | Phase 4 (Student login) | **New (SOP-ID-4)** — reconcile against the frozen identity decision (which *mandates* OTP-to-parent) |
| **G3** | TC sets `students.status='transferred'` but leaves `student_guardians`/`school_memberships` active → parent retains visibility; login entitlement not explicitly revoked (`sis_certificates_repository.ts:400-406`) | Phase 2 (Transfer lifecycle: deactivate old membership, remove login entitlement) | **New (SOP-ID-2)** — extends existing TC engine (SIS-D1), not a rebuild |
| **G4** | No inter-school transfer; moving a child = TC-out + re-admit, losing history (`PRA-P2-28`, `sis_transfers_screen.dart:16-17`) | Phase 2/3 (transfer to new school, reactivate mobile) | **Reconcile → elevate `PRA-P2-28`** (P2→P0 under SOP-ID) |
| **G5** | No mobile-number change; no guardian/custody change; only `UPDATE users` path never touches `phone` (`20260615110000_*.sql:25-33`); parent profile phone is read-only (`parent_profile_screen.dart:109-113`) | Phase 4 (Mobile update, Guardian change) + Identity-Ownership audit | **Reconcile → elevate/extend `P1-CODE-4`** (already scopes change-phone/PLAT-4; deferred → P0 under SOP-ID) |
| **G6** | `users` has no `status`/`created_by`/`approved_by`/`last_modified_by`; identity mutations (user created, role changed, mobile changed, login enabled/disabled, membership revoked) are **not** in the audit catalog (`audit_repository.ts`, `mutation_audit_catalog.ts` — confirmed absent) | Identity-Ownership Governance (P0): every user has Creator/Approver/Last-Modified + mandatory audit events | **New (SOP-ID-5)** — extends the existing generic audit engine (`audit_events`), does not replace it |
| **G7** | Staff login Email tab has no working backend path (`staff_login_screen.dart:128-147` vs `EMAIL_NOT_SUPPORTED`) | — (correctness) | **New (SOP-ID small fix)** — hide/disable or wire |
| **G8** | Add-a-branch and chain consolidation broken (`PRA-P1-51/52`, `PRA-P2-27`) — Org Builder makes a disconnected tenant, not a branch | Phase 3 (multi-school org support) | **Reconcile → elevate `PRA-P1-51/52`** |

**Nothing here is a new philosophy.** G1/G4/G8 are already frozen PRA findings; G5 is already `P1-CODE-4`. Only **G2 (student-via-parent login), G3 (transfer identity lifecycle), G6 (ownership fields + identity audit events)** are net-new — and all three *extend* existing engines (auth-context, TC/SIS, audit) rather than introduce parallel modules.

---

## 3. Reconciliation with prior frozen decisions (must be honored)

- **Student Identity Architecture Decision (FINAL, frozen 2026-07-01):** *Public Student ID
  `<SCHOOL_CODE>-<NNNN>`, UUID = only PK, admission# separate/configurable, **student phone NEVER
  required, login = OTP-to-PARENT.*** → The current code **deviates** (student login needs the
  student's own phone). Gap **G2** must be closed *toward the frozen decision*, i.e. a student is
  reachable through the parent's OTP session, not by mandating a student SIM. **This audit confirms
  the frozen decision; the code, not the decision, is what changes.**
- **Attendance-Auth Decision (FINAL, frozen):** staff-attendance auth = GPS + live-face, never OS
  biometric/PIN. Unaffected by this program (login-OTP ≠ attendance-auth) — do not conflate.
- **Identity-Permanence invariant (`P1-CODE-4`):** change-phone must keep UUID/PSID/links intact.
  SOP-ID-5 inherits this invariant verbatim.

## 4. Backward-compatibility note (owner requirement)

The core flow (Mobile → OTP → auto-resolution) is **preserved unchanged**. All SOP-ID work is
**additive**: an active-school selector only appears when a user has >1 active membership (single-
school users see no change); student-via-parent login adds a path, removes none; ownership columns
are nullable-backfilled; identity audit events are new rows in an existing table. No existing token,
session, RLS policy, or single-school journey is altered destructively.

---

## 5. What this audit does NOT do

It does not implement anything. The build is governed by **Program SOP** (see companion) under the
mandatory EOS gate + 15-point Definition-of-Done; a feature is DONE only when all 15 checkpoints pass
and EOS returns PASS. **Execution placement/sequencing is OWNER DECISION D2 (pending, not adopted),
and Smart OMR is OWNER DECISION D1 (pending) — both are recorded as pending owner decisions, to be
finalized after all audits complete. Nothing here authorizes implementation of either.**
