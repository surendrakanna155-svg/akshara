# Exam Security Audit — Authorization Review

> **Date:** 2026-06-19 · **Scope:** Authorization for the exam feature (sessions, marks, verification, approval, publish, ranks, export). **Audit only — no code changed.**
> **Method:** Read of client RBAC (`lib/core/security/`), exam feature gating (`lib/features/academics/exam_admin/`, `lib/features/teacher/exams/`), repository layer, and the Supabase edge/RLS layer (`supabase/functions/`, `supabase/migrations/`).

## TL;DR

The **client** has a clean, granular permission model for exams. The **server does not enforce it.** Edge functions gate exam endpoints on coarse `viewSis` / `manageSis` + school scope only — not the granular exam permissions, not teacher→subject/class assignment, not any coordinator role. The marks-entry scoping shipped in `3d05ef7` is **client-side only**. Net effect against the real backend: **any staff user with `manageSis` in a school can read, edit, process, and publish marks for every class and subject in that school.**

Two roles in the request — **Exam Coordinator** and **Class Teacher** — **do not exist as ERP roles.** They are concepts the code only partially models.

---

## Roles: what actually exists

`ErpRole` ([erp_role.dart](lib/core/security/erp_role.dart)) defines: superAdmin, schoolAdmin, principal, vicePrincipal, management, financeAdmin, admissionsCounselor, teacher, parent, student, + operational roles.

- **No `examCoordinator` role.** "Verify marks" is granted by `Permission.verifyExamResults`, held by principal / VP / schoolAdmin / superAdmin / management — i.e. the *same* people who approve. The "coordinator" step has no distinct identity.
- **No `classTeacher` role.** Class-teacher status is a per-class attribute in [teacher_assignment_registry.dart](lib/core/teaching/teacher_assignment_registry.dart) (`classTeacherGrade`/`classTeacherSection`). It grants **no extra exam permissions** — a class teacher has exactly the same exam rights as any teacher, and for marks entry class-teacher status is irrelevant (marks follow the *subject* assignment).

## Permission → role grants (client matrix)

From [role_permissions.dart](lib/core/security/role_permissions.dart):

| Permission | Teacher | Principal | VP | schoolAdmin | management | Parent | Student |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| `viewExams` | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ |
| `manageExams` | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ |
| `manageExamMarks` | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ |
| `submitExamResults` | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ |
| `verifyExamResults` | ✗ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ |
| `approveExamResults` | ✗ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ |
| `publishExamResults` | ✗ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ |

Student has **no** exam permissions (`{}`). Parent has none either; both see published results via **scope** (server `child_ids` / `student_id`), not via a permission.

---

## Capability × Role matrix (effective behavior today)

Legend: ✓ allowed · ✗ denied · ⚠️ allowed but only *client-side* scoped/gated (server does not enforce the restriction) · N/I not implemented.

| Capability | Teacher | Class Teacher | Exam Coordinator¹ | Principal | Parent | Student |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| **1. View exam sessions** | ⚠️ own subjects² | ⚠️ same as teacher | ✓ all | ✓ all | own children (published only) | own (published only) |
| **2. View marks** | ⚠️ own subjects² | ⚠️ same as teacher | ✓ all | ✓ all | ✗ (pre-publish) | ✗ (pre-publish) |
| **3. Edit marks** | ⚠️ own subjects² | ⚠️ same as teacher | ✓ all | ✓ all | ✗ | ✗ |
| **4. Verify marks** | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ |
| **5. Approve results** | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ |
| **6. Publish results** | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ |
| **7. View ranks** | N/I | N/I | N/I | N/I | N/I (intended, gated by toggle) | N/I (intended) |
| **8. Export reports** | ⚠️ ungated³ | ⚠️ ungated³ | ✓ ungated³ | ✓ ungated³ | ✗ | ✗ |

¹ "Exam Coordinator" = whoever holds `verifyExamResults` (principal / VP / schoolAdmin / management). Not a real role.
² Subject scoping is **client-side only** (`3d05ef7`). Server returns all marks for the school.
³ Export has **no permission gate** of any kind — see capability 8.

### Where each capability is gated (client)

1. **View exam sessions** — route guard `examAdministration → viewExams` ([route_guards.dart:66](lib/router/route_guards.dart#L66)). Note: **teacher holds `viewExams`**, so a teacher can open the Exam Administration hub (create is separately gated by `manageExams`). Teacher app list is scoped to subject assignments via `getMarksEntryExams`/`getUpcomingExams` ([mock_teacher_repository.dart](lib/core/repositories/mock/mock_teacher_repository.dart)).
2. **View marks / 3. Edit marks** — `Permission.manageExamMarks` on the save action ([exam_marks_entry_screen.dart:409](lib/features/academics/exam_admin/exam_marks_entry_screen.dart#L409)) and the `updateExamMark` mutation ([mutation_permission_registry.dart:747](lib/core/security/mutation_permission_registry.dart#L747)). Teacher holds it. Mark field disabled once `published` ([exam_marks_entry_screen.dart](lib/features/academics/exam_admin/exam_marks_entry_screen.dart) — `enabled: canEdit && !mark.published`).
4. **Verify marks** — `Permission.verifyExamResults` ([exam_marks_entry_provider.dart:107](lib/features/academics/exam_admin/exam_marks_entry_provider.dart#L107)).
5. **Approve results** — `Permission.approveExamResults` in the approval center ([mutation_permission_registry.dart:194](lib/core/security/mutation_permission_registry.dart#L194)); RBAC asserted in `approval_center_provider`.
6. **Publish results** — `Permission.publishExamResults` ([exam_marks_entry_provider.dart:174](lib/features/academics/exam_admin/exam_marks_entry_provider.dart#L174), [teacher_mutations_provider.dart:229](lib/features/teacher/teacher_mutations_provider.dart#L229)); on approval the adapter calls `publishExamResults` automatically.
7. **View ranks** — only `ExamReportSettings.showRankToParents` exists ([exam_grading.dart:106](lib/core/exams/exam_grading.dart#L106)). **No rank is computed or delivered anywhere** — `PublishedExamResult` has no rank field; nothing in parent/student/teacher results references rank. Must be honored when Slice 5/6 build delivery.
8. **Export reports** — **no permission**. The export button ([exam_marks_entry_screen.dart:43](lib/features/academics/exam_admin/exam_marks_entry_screen.dart#L43)) is a bare `IconButton` in the AppBar, not wrapped in `AksharaViewAction`/`AksharaManageAction`. There is no `exportReports`/`viewReports` permission in [permissions.dart](lib/core/security/permissions.dart). Anyone who reaches the marks-entry screen can export every student's name + marks to CSV.

---

## Server-side enforcement (Supabase)

### What the server DOES enforce
- **Authentication** — Bearer JWT on every request (`auth_interceptor`).
- **Coarse permission** — exam endpoints require `viewSis` (read) or `manageSis` (write): [exam_administration_handlers.ts](supabase/functions/_shared/academics/exam_administration/exam_administration_handlers.ts) → `requirePermission(claims, "viewSis")` / `"manageSis"`.
- **Tenant/school scope** — RLS on `exam_sessions`, `exam_mark_entries`, `teacher_entities` restricts rows to `organization_id` + `school_id` (+ parent/student scope on results).
- **Approval gate on publish** — the publish handler checks an approval exists.

### What the server does NOT enforce (the gaps)
| # | Missing check | Evidence | Impact |
|---|---|---|---|
| S1 | **Granular exam permissions** (`manageExamMarks`, `verifyExamResults`, `approveExamResults`, `publishExamResults`) | Handlers check only `viewSis`/`manageSis`, although the client's own [server_rbac_route_inventory.dart:70-74](lib/core/security/server_rbac_route_inventory.dart#L70-L74) lists the granular ones as expected. **Drift between expected and actual.** | Any `manageSis` user performs *all* write/verify/publish operations; verify/approve/publish are not separated server-side. |
| S2 | **Teacher → subject/class scoping** | `listExamMarks` / `updateExamMark` filter only by org+school+examId; no teacher-assignment join. | A teacher can read/edit marks for **any** class & subject. Slice 4a scoping is client-only. |
| S3 | **Coordinator/role distinction for verify vs. manage** | No role check beyond `manageSis`. | "Verification" is not a real server gate. |
| S4 | **Coordinator/role check on publish** | Approval is checked; role is not. | Any `manageSis` user can drive publish. |
| S5 | **`teacher_id`/`user_id` column on `teacher_entities`** | Table is keyed by org+school+entity_type+id only. | Row-level teacher scoping is *impossible* at the DB without a schema change (contrast `parent_entities.student_id`). |
| S6 | **`teacher_id` / assignment in JWT** | Server claims carry `role`, `permissions`, `scope`, `student_id`, `child_ids` — no teacher id/assignment. | No efficient identity to scope by even if policies were added. |
| S7 | **Separation of duties (verifier ≠ approver)** | Neither client nor server enforces it; same principal holds both. | Self-approval of one's own verification. |

### Client-only gaps (lower severity, still real)
- **C1** Marks-entry screen reached via in-screen navigation; only `examAdministration` has a route guard ([route_guards.dart](lib/router/route_guards.dart)). Verify the marks-entry route can't be deep-linked past the `manageExamMarks` action gate.
- **C2** Export (capability 8) ungated client-side.

---

## Severity summary

- **Critical:** S1, S2 — server enforces neither granular exam permissions nor teacher scoping → cross-class marks read/write by any `manageSis` user.
- **High:** S3, S4, S5 — no verify/publish role enforcement server-side; schema can't express teacher scoping.
- **Medium:** S6, S7, C2 — missing identity claim, no separation of duties, ungated export.
- **Low / future:** C1, rank-delivery (capability 7) must be built to honor `showRankToParents` server-side.

---

## Recommended final exam workflow (before Slice 5)

A workflow where **every gate is enforced on both client and server**, and roles map to real identities:

1. **Subject teacher** enters marks — scoped to their `subjectAssignments` (subject + grade + section). *Enforce server-side*, not just client (fix S2/S5/S6).
2. **Submit for verification** (`submitExamResults`) — teacher hands off; marks lock from further teacher edits.
3. **Exam Coordinator verifies** (`verifyExamResults`) — checks completeness/correctness, forwards. **Make this a real identity:** either introduce `ErpRole.examCoordinator`, or add a per-exam `coordinator_user_id` on `exam_sessions` and check it. The coordinator should *not* also be the approver for the same exam (fix S3/S7).
4. **Principal approves** (`approveExamResults`) — distinct from the verifier; on approve, results publish automatically (existing adapter). Enforce role server-side (fix S1/S4).
5. **Publish → parents/students** see results via their existing scope. **Ranks** shown only if `showRankToParents` is on, computed and filtered **server-side** (build in Slice 5/6, capability 7).
6. **Export** — add an `exportReports` (or reuse `manageExamMarks`) gate on the export button, and scope exports to the teacher's classes.

### Concrete prerequisites to close the audit (no code yet — for planning)
- **P1 (Critical):** Edge functions check the granular exam permissions, not just `manageSis` (close S1).
- **P2 (Critical):** Add `teacher_id`/assignment to `teacher_entities` (+ JWT claim) and join teacher assignments in RLS / handlers so marks read/write is scoped to the teacher's subject+class (close S2/S5/S6).
- **P3 (High):** Model the coordinator as a real identity (role or per-exam assignment) and enforce verifier ≠ approver (close S3/S7).
- **P4 (Medium):** Gate export with a permission and scope its rows (close C2).
- **P5 (Future, with Slice 5/6):** Compute rank server-side and filter by `showRankToParents` per school (capability 7).

> **Recommendation:** Address at least **P1 + P2** (the two Critical, server-side) before building Slice 5 (parent/student results), because Slice 5 widens read exposure of published results and will reuse the same unscoped teacher/marks endpoints. P3–P5 can follow.
