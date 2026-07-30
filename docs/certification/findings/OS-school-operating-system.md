# WS10 — School Operating System Coherence Certification

**Workstream 10** · branch `release/v1.0-playstore` · READ-ONLY audit, nothing fixed.
Companion register entries use the prefix `OS-`.

## The decisive question

> Is NIKSHA OS **one integrated School Operating System**, or a collection of
> independent ERP modules wearing a shared theme?

This is not a question about whether the modules work. Workstreams 2–8 answer
that, and mostly the answer is yes. This is a question about whether the product
is what its name claims: an *operating system* for a school, in which an event in
one place becomes knowledge everywhere it matters.

## What WS4 already established (not re-derived here)

Workstream 4 returned **NOT CERTIFIED** on the propagation dimension, with
evidence this workstream accepts and builds on:

- The **domain-event bus is dead** — 368 write sites into `domain_events`,
  nothing reads the table (XMOD-001).
- **Nine periodic jobs, three crons** (XMOD-016).
- **31 manual human steps** stand where automation was designed.
- One genuine positive: **attendance-percentage is canonical**, with 11
  consumers.

The RC closure report is honest about this: *"Not certified, by design: event-
driven propagation. The log is production grade; the bus is not"*
(`docs/roadmap/RC_CLOSURE_REPORT.md`).

This workstream examines the **other four dimensions**: shared state, role and
workspace awareness, DAI integration, and the cross-cutting platform layers
(audit, diagnostics, notifications, dashboards, reporting). It closes with a
per-module INTEGRATED / ISOLATED verdict.

---

## 1. Shared state — is one canonical truth read, or does each module compute its own?

WS4 found attendance-percentage canonical and called it a positive. **The
decisive question for this workstream was whether that is the rule or the
exception.** It is the exception, and the evidence for that is unusually clean.

### 1.1 The positive, verified and worth stating precisely

`supabase/functions/_shared/attendance/attendance_percentage.ts` is genuinely
canonical. It exports paired SQL and TypeScript families that agree **by
construction** — `ATTENDED = present + late + 0.5 × half_day`,
`DENOM = marked − excused`, `ROUND(...)::int`, and `null` (never 0) on a zero
denominator. This matches the owner decision recorded for attendance-% exactly.

Nine production consumers import it:
`attendance/attendance_office_repository.ts:16` ·
`intelligence/student_risk_repository.ts:2` · `director/director_repository.ts:15` ·
`sis/student_360_service.ts:2` · `operations/operations_hub_service.ts:3` ·
`management/management_aggregate_repository.ts:9` ·
`dashboard/dashboard_service.ts:17` · `pilot/pilot_attendance_repository.ts:2` ·
`parent_experience/parent_experience_service.ts:2` (plus 4 test files). The
Flutter client never recomputes it — it only maps it.

**This is exactly what an OS looks like.** It is also, on the evidence below,
the only place in the product that looks like one.

### 1.2 OS-001 — the canonical value is destroyed at a third client mapper (P0, extends XMOD-010)

The module's own header states the rule: on a zero denominator return `null`,
**never 0**. Client mappers collapse it anyway, with `as int? ?? 0`:

- `lib/core/repositories/api/parent/mapper/parent_mapper.dart:394` — **already
  registered as XMOD-010**
- `lib/core/repositories/api/phase5/phase5_mapper.dart:150` — **already
  registered as XMOD-010**
- **`lib/core/repositories/api/student/mapper/student_mapper.dart:221` — not in
  XMOD-010.** The student app's own attendance view.

Only the third is new, and it is registered as OS-001 rather than folded in
silently, because XMOD-010's recommended fix ("make the model fields nullable")
was scoped to two files and would leave this one behind.

**A student with nothing marked is shown 0% attendance in their own app.** The
backend was careful, the wire format preserved the distinction, and the last
mapping step threw it away — three times, in three modules, which is itself the
Section 1 thesis in miniature: the canonical value exists and each module
independently decides what to do with it.

### 1.3 The rest of the table

Thirteen quantities that more than one module needs:

| Quantity | Canonical fn? | Implementations | Agree? |
|---|---|---|---|
| Student attendance % | **YES** | 1 + 9 consumers | Yes in backend; **client nulls→0** |
| Active student count | no | **≥8 sites, 4 definitions** | **No** |
| Exam % → grade letter | two rival "defaults" | 2 scales + 24 inline sites | **No** |
| Exam percentage math | no helper anywhere | **13 Flutter + 11 backend, inline** | **No** |
| Total collected | no | **≥12 sites, 3 status filters** | **No** |
| Collection rate | `computeCollectionRate` | 1 consumer + 1 fork | **No** |
| Staff present today | no | 2 | **No** |
| Working days / holidays | no service | 2 | **No** |
| Academic year / term | **no resolver at all** | **66 hard-coded literals** | **No** |
| Student status vocabulary | 3 competing enums | 3 | **No** |
| Outstanding dues | no | 5 (XMOD-014, already registered) | **No** |
| `sections.strength` | write-only column | 0 maintainers (XMOD-026) | n/a |
| Risk score | per-module | ≥3 vocabularies | **No** |

### 1.4 OS-002 — four definitions of "how many students does this school have", and billing uses the loosest (P0)

- `status = 'active'`: `director/director_repository.ts:118,324,338,734`;
  `sis/sis_dashboard_repository.ts:105`;
  `management/management_aggregate_repository.ts:341`
- **no status filter at all**: `analytics/analytics_metrics_service.ts:15`;
  `copilot/copilot_context_engine.ts:192`; `sis/sis_dashboard_repository.ts:102`;
  and — decisively — **`entitlements/entitlement_limits.ts:121`, which enforces
  the paid seat slab.**
- `sis_student_enrollments WHERE is_current = true`:
  `analytics_metrics_service.ts:19`; `copilot_context_engine.ts:197`;
  `sis_dashboard_repository.ts:113`
- a fourth flavour in finance:
  `count(DISTINCT student_id) FROM finance_student_accounts WHERE status='open'`,
  labelled `total_students`, at `finance/finance_dashboard_repository.ts:62-65`

Two consequences, both commercial:

1. **Alumni and transferred students count against the school's licence.** The
   entitlement check applies no status filter, so a school that has been running
   for three years is billed for every student who ever attended.
2. **Analytics's "students" and Director's "students" for the same school on the
   same day are structurally different numbers.** Note that
   `sis_dashboard_repository.ts` alone uses **two** of the definitions, at `:102`
   and `:105`.

This is compounded by a client-side defect: `lib/core/repositories/api/sis/dto/sis_enum_codec.dart:31`
maps **`SisStudentStatus.prospect => 'active'`**. An unenrolled *prospect* is
written to the server as an active student — inflating every `status='active'`
count above, **including the billing seat count**. Three status vocabularies
exist (DB: `active|inactive|alumni|transferred`, `sis/sis_status_codec.ts:5`;
API: `active|inactive|graduated|transferred`, `:2`; Flutter:
`active|prospect|transferred|exited|alumni`, `lib/features/sis/sis_models.dart:30`)
and the backend codec is disciplined about the mapping while the client codec is
not.

### 1.5 OS-003 — a 35% student is F on the server and D on the report card (P0)

`supabase/functions/_shared/academics/exam_administration/exam_administration_repository.ts:200-208`
defines `DEFAULT_GRADE_BANDS` as 7 bands ending `>=40 D, >=0 F`.
`lib/core/exams/exam_grading.dart:47-55` defines `ExamGradingScale.standard` as
6 bands ending `>=50 C, >=0 D`.

**Both are documented in their own source as "identical to the legacy fixed
grading."** They are not. A student scoring 35% receives **F** from the server
and **D** on the client-rendered report card.

The Flutter side additionally ships three presets — `cbseScholastic`,
`stateBoardSsc`, `percentageDivision` (`exam_grading.dart:60-115`) — with **no
backend counterpart**, so a school on the State Board preset gets client grades
the server can never reproduce. (XMOD-030 registers that the State-Board SSC
scale is unreachable; this is the divergence underneath it.)

### 1.6 OS-004 — exam percentage: no helper, 24 inline sites, three rounding rules, one crash (P0)

There is no shared percentage helper anywhere in the product.

- Backend (`exam_administration_repository.ts`): raw double passed to
  `gradeForPercent` at `:306, :967, :1070, :1760, :2356`; 2-dp via
  `Math.round(p*100)/100` at `:1534, :1663`; 2-dp via `Math.round(x*10000)/100`
  at `:1602, :2378`.
- Flutter: integer `.round()` at `exam_report_card.dart:34,103`; raw double at
  `:168, :226, :308`; 2-dp at `exam_administration_store.dart:1279`; raw at
  `exam_reports.dart:258, 311, 360`.

**And one of them crashes.** `lib/features/parent/exams/exam_models.dart:57`:

```dart
int get percent => ((scoreObtained / maxScore) * 100).round();
```

with **no `maxScore == 0` guard** — `0/0` → `NaN.round()` → `UnsupportedError`
in the parent app. Line 99 of the same file *does* guard. Two rules, one file.

### 1.7 OS-005 — "collected" means three different things, and one file uses two of them 111 lines apart (P1)

- `collection_status = 'completed'`: `director_repository.ts:125,298,456`;
  `copilot_context_engine.ts:143`; `dashboard/dashboard_service.ts:64`;
  `pilot_snapshot_repository.ts:779`; `finance_recovery_repository.ts:382,444`;
  `finance_reports_repository.ts:33`; `finance_tally_repository.ts:54`
- `IN ('completed','partially_refunded','refunded')`:
  `finance_dashboard_repository.ts:75,118`;
  `management_aggregate_repository.ts:352`; `finance_intelligence_service.ts:58`
- `IN ('completed','partially_refunded')`: `finance_intelligence_service.ts:169`

**`finance_intelligence_service.ts` uses two different definitions of
"collected" 111 lines apart** — `:58` counts refunded money as collected, `:169`
does not — so its own collection-rate KPI at `:180` is internally inconsistent.
That KPI is itself an inline fork of `computeCollectionRate`
(`finance_dashboard_repository.ts:39`), which has exactly **one** production
caller (`:163`).

A school reconciling its Tally export (`'completed'` only) against the finance
dashboard (`+refunded`) against the management aggregate (`+refunded`) will get
three different day-books. This sits alongside XMOD-014's five definitions of
"outstanding dues" — the same disease on the other side of the ledger.

### 1.8 OS-006 — there is no academic-year resolver; 66 hard-coded literals in two different dash characters (P1)

`TenantContext` (`lib/core/tenant/tenant_context.dart:7-18`) carries **only**
`tenantId`, `schoolId`, `organizationId`, `userId`. **No academic year. No
term.** So every module invents one:

`finance/fee_structures/finance_fee_structures_provider.dart:14`
`StateProvider<String>((ref) => '2026-27')` ·
`sis/academic_assignment/sis_academic_assignment_screen.dart:44` `'2026–27'` ·
`admissions/admissions_models.dart:609` `'2026–27'` ·
`finance/finance_workflow_actions.dart:194` `'2026-27'` ·
`school_completion/substitute_manager_screen.dart:27` and
`teacher_reassignment_screen.dart:25` hard-code `academicYearId = 'year_1'`.

**66 hard-coded year literals across `lib/` — 31 with an ASCII hyphen
(`2026-27`) and 29 with an en-dash (`2026–27`).** These are compared by string
equality (`mock_finance_repository.dart:2726`,
`mock_academic_operations_repository.dart:370`), so **Finance's year and SIS's
year are different strings for the same year.**

The backend has the real source of truth — `academic_years.is_current`
(`academic/academic_years_repository.ts:118-119`) — and **nothing in `lib/`
reads it** to seed these defaults. This also means the product cannot roll over
to 2027-28 without a code change in 66 places.

### 1.9 Section 1 verdict

**Canonical shared state is the exception, not the rule.** Across 13
cross-module quantities, exactly one has a single named canonical function with
real adoption — and even it is corrupted at the client mapper (OS-001). A second
(`computeCollectionRate`) exists with one caller and is already forked.
Everything else is computed independently per module, with measurable
disagreement in status predicates, rounding, zero-guards and inclusion rules.

The decisive detail: **`attendance_percentage.ts`'s own header describes it as
fixing three contradictory implementations found by a gap sweep.** It is a
deliberate one-off remediation, not an architectural pattern the codebase
follows. It proves the team knows how to build canonical shared state and has
done it once.

---

## 2. Cross-cutting layers — platform services, or per-module reimplementation?

The four layers were tested by enumerating all 72 backend module directories
under `supabase/functions/_shared/` and asking, per module and with evidence,
whether it participates.

### 2.1 The shared services that exist

| Layer | Path | Real? |
|---|---|---|
| Audit writer | `_shared/audit/audit_repository.ts:283` (`recordServerAuditEvent`), `:380` (`recordMutationAudit`) | yes |
| Audit catalog | `_shared/audit/mutation_audit_catalog.ts:15` (`emitMutationAudit`) + ~25 per-module specs | yes — **305 call sites** |
| Notification rail | `_shared/communication/notification_service.ts:40,83,218` | yes — **9 callers** |
| Error envelope | `_shared/http.ts:33,46` | yes — 200 non-test files |
| Request context | `_shared/request_context.ts:15` | **1 caller** — effectively dead |
| RBAC | `_shared/route_registry.ts:119`, `_shared/permission_middleware.ts` (146 files) | yes |
| Report/export (client) | `lib/core/reports/akshara_report_export_service.dart` | yes — 20+ callers |
| Report/export (backend) | — | **none exists** |
| Widget registry | `_shared/widget_platform/widget_pack_catalog.ts` + `lib/features/dynamic_widgets/` | exists, **unconsumed** |

### 2.2 AUDIT — a real platform layer, ~85% adopted, structurally unsafe

**48 of 62 mutating modules participate**, through one writer and one catalog,
at 305 call sites. That is a platform layer, and it should be credited as one.

Two defects sit inside it.

**OS-007 (P0) — audit is not transactional at any of its 305 call sites.**
`runTenant` (`_shared/tenant_db.ts`) issues no `BEGIN`/`COMMIT`; only 15 files in
the entire backend touch `savepoint`. `emitMutationAudit` is a separate awaited
statement **after** the mutation — e.g.
`finance/finance_collections_handlers.ts:398-408`, where `cancelCollection`
commits and *then* audits. If the audit insert throws, the mutation has already
committed, and the caller receives a 500. **The data changed, no audit row
exists, and the user was told the operation failed.** On a fee cancellation that
is the worst of all three outcomes. The RC phase hardened the attendance
correction path to audit "in-transaction with real before→after"; that guarantee
does not hold, because there are no transactions.

**OS-008 (P1) — three modules built private audit trails invisible to `/audit`.**
`approval/approval_repository.ts:214` writes `approval_audit_entries`;
`vault/vault_service.ts:107,134` writes `platform_secret_audit_log`;
`student_health/student_health_repository.ts:71` writes
`student_health_access_log`. A principal or an auditor reading the audit console
sees none of it. Reimplementing a platform service privately is worse than
skipping it: the trail exists, so the gap is invisible.

Six further modules mutate with **zero** audit of any kind:
`approval/approval_repository.ts:277`, `entity_write/entity_write_store.ts:103`,
`expense_ledger/expense_ledger_repository.ts:109`,
`parent_experience/parent_experience_service.ts:87`,
`storage/storage_quota_repository.ts:66`, `vault/vault_service.ts:93`, and
`student_health/student_health_repository.ts:235`.

### 2.3 OS-009 — NOTIFICATIONS are not a platform service. They are a module. (P0)

This is the strongest single piece of evidence in the workstream.

`_shared/communication/notification_service.ts` is a well-built rail —
`enqueueFromTemplate`, `processDeliveryQueue`, `enqueueNotificationRequested`.
**It has nine callers outside `communication/` itself**, against roughly 62
mutating modules. Adoption: **≈15%.**

Modules that do notify: `gate_pass` (`gate_pass_repository.ts:479,489`),
`support` (`support_handlers.ts:129`), `teacher`
(`teacher_parent_communication_handlers.ts:134`), `transport`
(`transport_write_handlers.ts:720`), `promotion`, `school_completion`
(`communication_bridge_service.ts:151`), `pilot`
(`pilot_operations_handlers.ts:253,1180`), `student_health`
(`student_health_operations.ts:174`), `reminders`.

**Everything else changes state and tells nobody.** Three that make the point
without further comment:

- **`payment` moves money and notifies nobody.**
- **`attendance` marks a child absent and notifies nobody.**
- **`library` records an overdue book and notifies nobody.**

`communication/` is a peer module that other modules mostly do not know exists
— not a rail they sit on. **53 modules' state changes never reach a person.**
This confirms and generalises SIM-003 (complaints: zero notification hits) and
XMOD-023 (issued certificates never delivered), which are not two isolated
misses but two samples from a 53-module population.

### 2.4 OS-010 — DIAGNOSTICS do not exist at the module layer (P1)

`_shared/request_context.ts:15` (`setRequestContext`) has **exactly one caller**:
`auth_handlers.ts:211`. There is no `_shared/observability`, no request-scoped
logger, no error reporter, and no correlation propagation beyond an optional
`x-correlation-id` header read at `audit_repository.ts:396`.

The one genuine cross-cutting piece is the error envelope
(`_shared/http.ts:46`, used by 200 files, with a single raw
`new Response(JSON.stringify(` outlier). So the error *shape* is uniform and
observability is absent. When a principal reports "fees didn't save this
morning", there is no request-scoped trail to answer with. The RC phase's
request-identity work (userId/sessionId/tenantId from the verified JWT) built
the payload; nothing calls it.

### 2.5 OS-011 — REPORTING has no backend service and ~55 modules have no reporting surface (P1)

Zero shared CSV/PDF/report service exists in `_shared/`. Eight hand-rolled
report files span only four modules: `finance/finance_reports_*`,
`finance/finance_tally_export.ts`, `hr/hr_reports_*`,
`admissions/admissions_reports_*`, `education/education_paper_export.ts`.

The client does have a genuine shared service
(`lib/core/reports/akshara_report_export_service.dart`, 20+ callers) — but 8
modules still ship bespoke `*_report_exporters.dart` on top of it.

**About 55 backend modules have no reporting surface at all** — including
attendance, complaints, certificates, inventory, hostel and staff duty, every
one of which holds data a principal will be asked for by a board, a parent, or
an inspector.

### 2.6 OS-012 — the dashboard platform exists, is fully built, and has zero consumers (P1)

`lib/features/dynamic_widgets/` ships a registry, a layout editor and a runtime
screen (6 files). The backend ships
`_shared/widget_platform/widget_pack_catalog.ts` with 6 widget ids —
`homework_summary`, `operations_summary`, `fee_collection`, `school_health`,
`student_risk`, `attendance_risk` — plus full CRUD and a router entry.

**Zero dashboard screens import `dynamic_widget`.** All **23** dashboards in the
product are hand-built (`finance/dashboard/finance_dashboard_screen.dart`,
`sis/dashboard/sis_dashboard_screen.dart`, and 21 more including 4 non-school
verticals).

This is the WS9 pattern (Section B7 of `POLISH-product-polish.md`: built,
tested, never wired) reproduced at platform scale. An unused platform layer is
worse than no platform layer: it carries maintenance and migration cost, it
appears in inventories as a capability, and it makes the absence of a real
dashboard platform harder to see. WIDGET-015's four unrendered dashboard widgets
are downstream of this.

### 2.7 RBAC — the one unambiguous platform layer (PASS, with a gap)

`route_registry.ts:119` (`MODULE_ROUTES`) owns all module routing behind a
single-ownership guard, and `permission_middleware` appears in 146 files. This
is a real, adopted, enforced platform service and it should be recorded as the
best-integrated dimension in the product.

**OS-013 (P1):** `_shared/validation/rbac_route_inventory.ts:12` covers 47
prefixes against ~57 in the registry. Absent from the inventory: `attendance`,
`attendance-auth`, `copilot`, `analytics`, `homework`, `school`,
`school-config`, `support`, `plans`, `legal`. Those modules gate in-handler only
and are unverified by the invariant guard — the same drift that produced the RC
phase's five fail-open routes (`docs/roadmap/RC_EXECUTION_LOG.md:48-52`), where
`RouteNames.adminErpRoutes` and `kErpRouteViewPermissions` disagreed and both
gates keyed off the looser one. The invariant test added then covers the Flutter
side; the backend inventory has the same shape of hole.

### 2.8 Section 2 scorecard

| Layer | Verdict |
|---|---|
| RBAC | **Platform service.** Adopted, enforced. 10 prefixes outside the inventory guard. |
| Error envelope | **Platform service.** 200 files, uniform shape. |
| Audit | **Platform-shaped, ~85% adopted, structurally unsafe.** No transactions; 7 modules bypass, 3 of them by building private trails. |
| Notifications | **Not a platform service — a module.** ≈15% adoption. |
| Diagnostics | **Absent.** 1 caller. |
| Reporting | **No backend service.** 4 modules of ~72. |
| Dashboards | **Registry exists, 0 consumers.** 23 bespoke dashboards. |

**On the four questions asked per module, the median module scores 1 of 4: it
writes an audit row nobody reads, and tells no one anything.**

---

## 3. Role and workspace awareness

### 3.1 The declared model

- **4 shells** — `UserRole`, `lib/features/auth/auth_models.dart:7-11`: parent,
  teacher, student, staff.
- **10 workspaces** — `WorkspaceId`, `lib/core/workspace/workspace.dart:15-26`.
- **15 roles** — `ErpRole`, `lib/core/security/erp_role.dart:2-17` (12 staff-
  selectable at `:46-59`). WS3 counted 13 named; the enum carries 15.
- **Mapping** — `kRoleWorkspaces`, `workspace.dart:177-193`.

### 3.2 OS-014 — the workspace model collapses at both ends (P1)

**Five roles share one workspace.** superAdmin, schoolAdmin, principal,
vicePrincipal and management all resolve to `schoolAdministration`
(`workspace.dart:177-193`). The product distinguishes a principal from a
vice-principal in its permission model and then shows them the identical
workspace.

**Eight of ten workspaces hold exactly one module** —
finance→{finance}, inventory→{inventory}, transport→{transport},
hostel→{hostel}, library→{library}, frontOffice→{admissions, marketing}
(`workspace.dart:110,119,128,137,146,155`). **Three hold zero modules:**
teaching, parentSpace, studentSpace (`:95-102, :157-172`).

So a "workspace" is either a synonym for a single module or an empty shell. The
USER→ROLE→WORKSPACE→TASK model in the product's north star is declared in code
and not populated.

**What this costs a real user**, per role:

| Role | Lands in | Can they do their job from it? |
|---|---|---|
| principal / VP / schoolAdmin / management / superAdmin | schoolAdministration (17 modules) | No — Certificate Desk, Gate Pass, Complaints, Infirmary and School Completion are unreachable (3.3) |
| admissionsCounselor | frontOffice {admissions, marketing} | **No — cannot reach SIS to enrol the applicant they just admitted** |
| financeAdmin | finance {finance} | Barely — cannot open a student's SIS record to verify who owes |
| transportManager | transport {transport} | No — cannot open the student riding the bus |
| hostelManager | hostel {hostel} | No — no SIS, health or fees for residents |
| librarian | library {library} | No — cannot look up the borrowing student |
| inventoryManager / storekeeper | inventory {inventory} | No finance link for purchase or issue |
| teacher | teaching (0 modules) | Shell only; the ERP grid is empty by construction |

The admissions counsellor case is the clearest: the product's own primary
workflow — admit an applicant, then enrol them — spans two workspaces, and the
role that performs it can only see one.

### 3.3 Five live school desks belong to no workspace — already registered as JOURNEY-008

**Not re-registered.** JOURNEY-008 covers this defect completely, including the
three-way disagreement between hub, bottom nav and rail, and the correct fix.
It is restated here only because of what it means for the OS question, and
because Section 4 and Section 6 both depend on it.

`AdminModule` has 30 values (`lib/features/admin/models/admin_nav_models.dart:6-38`);
`schoolAdministration` contains 17 (`workspace.dart:67-93`). **Thirteen modules
belong to no workspace at all.** Eight are verticals/platform. **Five are live
school desks with real screens and real navigation destinations**
(`lib/features/admin/admin_navigation_provider.dart:75,83,91,102,115`):

**Certificate Desk · Gate Pass · Complaints · Student Health (Infirmary) ·
School Completion.**

They are stripped unconditionally by `workspaceScopedNavDestinationsProvider`
(`admin_navigation_provider.dart:330-336`, the `workspace.containsModule(...)`
filter), which is the **only** source the Admin Hub reads
(`lib/features/admin/screens/admin_hub_screen.dart:28`). **They are invisible on
every hub, for every role, including superAdmin.** They are reachable only by
typing a route.

This confirms JOURNEY-008 and is recorded here because of what it means for the
OS question specifically: these are not half-built features. They are finished
desks — Complaints has a full deterministic SLA policy (SIM-003), Certificate
Desk has a working issuance path (XMOD-023, XMOD-031) — that no user can find.
It is also why they appear as ISOLATED in Section 5 twice over: nothing routes
to them, and they route to nothing.

### 3.4 OS-016 — role opens the door and never furnishes the room (P1)

**17 of 310 `*_screen.dart` files (5.5%)** reference `rbacServiceProvider`,
`hasPermission` or `ErpRole` at all.

| Shared screen | Adapts to the viewer? |
|---|---|
| `lib/features/student_360/student_360_screen.dart` (1,050 lines) | **No** — zero role/permission reads. A teacher, a principal, a finance admin and a hostel manager see the **identical dossier**: fees, behaviour, communication, documents, all of it |
| `lib/features/finance/collections/finance_collections_screen.dart` | **No** |
| `lib/features/teacher/attendance/teacher_attendance_screen.dart` | **No** |
| `lib/features/sis/registry/sis_registry_screen.dart` | **No** |
| `lib/features/transport/routes/transport_routes_screen.dart` | **No** |
| `lib/features/library/**` | **No** — no screen in the module reads role |
| `lib/features/sis/profile/sis_profile_screen.dart` | **Yes** — per-action gates at `:101,115,129,144,473,541`, plus `hasPermission(approveClearanceWaiver)` at `:158` |
| `lib/features/academics/exam_admin/exam_marks_entry_screen.dart` | **Yes** — the best example in the repo: distinct gates for `manageExamMarks` (:507), `manageExams` (:524), `verifyExamResults` (:535), `submitExamResults` (:546), `publishExamResults` (:567), `moderateExamMarks` (:1004) |

Two of eight furnish the room. **The Student 360 case is the one with a
consequence:** a hostel warden and the finance admin both see the full
behavioural and communication history of a child, because the screen was
designed once and gated at the route.

The timetable is the structural tell. Rather than one role-adaptive screen there
are **four hard-forked copies** —
`academics/timetable/timetable_hub_screen.dart`,
`teacher/timetable/teacher_timetable_screen.dart`,
`student_app/timetable/student_timetable_screen.dart`,
`parent/timetable/parent_timetable_screen.dart`. Role is resolved by *file path
and route guard*, not by the screen. That is the architecture of four apps, not
one OS.

### 3.5 OS-017 — workspace is a navigation filter; no context propagates except tenant (P1)

`activeWorkspaceProvider` / `activeWorkspaceIdProvider` / `userWorkspacesProvider`
(`lib/core/workspace/workspace_providers.dart:8-34`) are read by **exactly four
files outside their own directory**: `admin/admin_navigation_provider.dart:328`,
`admin/screens/admin_hub_screen.dart:32`, `shared/navigation/persona_nav.dart:166`,
`shared/widgets/workspace_switcher.dart:19,22,46,68,71,156`.

**Zero feature modules read it.** Switching workspace changes which tiles render
and nothing else.

- **Academic year has no global provider** — a grep for
  `academicYearProvider|selectedAcademicYear|activeAcademicYear` across `lib/`
  returns **one** file (`school_completion/timetable_optimization_screen.dart`).
  See OS-006.
- **Class context is private.** `selectedClassProvider` / `selectedClassId`
  exists only inside `lib/features/teacher/attendance/` and
  `teacher/reports/teacher_report_exporters.dart`. **Picking Class 8A in
  attendance is invisible to Fees, Exams and SIS** — the user re-picks the class
  in every module.
- **The one thing that does propagate is tenant/school.**
  `repositoryQueryProvider` (`lib/core/tenant/tenant_provider.dart:41-43`) is
  read by **173 files**. That is genuinely shared — and it is a data-fetch scope,
  not a UI context. `currentUserContextProvider` (`:46`) is read by one file.

### 3.6 Inherited role defects, confirmed

- **JOURNEY-002 confirmed** — `lib/core/security/rbac_service.dart:106`:
  `UserRole.staff => UserPermissions.forRole(ErpRole.superAdmin)`. Any staff
  session without a parseable ERP claim receives full Super Admin permissions.
- **JOURNEY-004 confirmed and quantified** — `homeRouteForStaffErp`
  (`lib/features/auth/qa_login_persona.dart:207-216`) has arms for only 5 of 15
  roles. **Seven staff roles** (schoolAdmin, management, admissionsCounselor,
  transportManager, hostelManager, librarian, storekeeper) fall to
  `_ => RouteNames.admin` at `:214` and land on the launcher — **even though
  their own workspace declares a `homeRoute`** (`workspace.dart:126,135,144,153`)
  that is never consulted. The data to fix this exists and is not read.

---

## 4. DAI integration — 11 intents, 7 modules, zero shared state

### 4.1 The routing table

`lib/core/dai/dai_resolver.dart:66-78` (`_rules`), with intent definitions at
`:111-340`; intents enumerated in `lib/core/dai/dai_intent.dart:6-42`.

| Intent | Line | Destination | Module |
|---|---|---|---|
| `openReceipt` | :111-125 | `financeCollections` | Finance |
| `feeDefaulters` | :128-149 | `financeDefaulters` | Finance |
| `lowAttendance` | :152-172 | `sisStudents` | SIS |
| `openTransport` | :175-191 | `transportRoutes` | Transport |
| `attendanceToday` | :194-212 | `teacherAttendance` | Attendance |
| `homework` | :215-228 | `teacherHomework` | Homework |
| `exams` | :231-244 | `examAdministration` / `studentExams` | Exams |
| `myAttendance` | :247-257 | `studentAttendance` | Student self-service |
| `myFees` | :260-270 | `parentFees` | Parent self-service |
| `openClass` | :273-288 | `sisStudents` | SIS |
| `openPerson` | :295-340 | **null route** | — (DAI-005) |

**7 modules reachable** (Finance, SIS, Transport, Attendance, Homework, Exams,
self-service) — the 7-of-28 figure confirmed.

### 4.2 OS-018 — 23 of 30 modules are unaskable, including every desk a front office runs (P1)

Unreachable by DAI: admin, admissions, marketing, certificateDesk, gatePass,
complaints, studentHealth, schoolCompletion, hr, employee, management, hostel,
library, inventory, alumni, controlCenter, director, organizationBuilder,
platformOperations, industry, healthcare, salon, restaurant, accommodation,
whiteLabel, dynamicWidgets.

**You cannot ask NIKSHA OS about a library book, a hostel resident, a staff
member's leave, a gate pass, a certificate, or an infirmary visit.** Note the
overlap with JOURNEY-008: the five orphaned desks are unreachable from the hub *and*
unreachable from search, which is what makes them fully unreachable in practice.

### 4.3 OS-019 — DAI reads no state, so a cross-module question is architecturally impossible (P1)

`DaiResolver` is declared `abstract final class` and documented as **"Pure and
synchronous. No I/O, no clock, no randomness"** (`dai_resolver.dart:26-27`). It
reads **zero** state — no repository, no provider, no `ref`. Every intent
produces a route string the caller `context.go()`s
(`lib/features/admin/global_search/global_search_overlay.dart:170`).

It carries `className`, `section` and `threshold` as fields on the intent, and
**the destination screen never receives or applies them** — `sisStudents` is
pushed as a bare route. (This is the mechanism behind DAI-004's false claim and
DAI-011's wrong destination.)

So *"which Class 8 students have both low attendance and fee dues"* — the
canonical question an OS should answer and a module collection cannot — is not
merely unanswered. It is impossible by construction: `_feeDefaulters` and
`_lowAttendance` are **mutually exclusive rules in an ordered first-match list**
(`:50-53`), so whichever fires deep-links into one module's list screen and
drops the other half of the question on the floor.

The sibling `GlobalSearchRegistry` has 18 static entries — a menu index, not a
query engine.

**DAI is a natural-language shortcut to a navigation menu.** That is a
legitimate and useful thing to have built. It is not integration, and the
product's own "Ask anything" framing (DAI-006) claims otherwise.

---

## 5. The entity-continuity test — can you follow a student through the school?

The most legible test of "one OS" is whether a person can be followed from
module to module. NIKSHA OS has a screen designed exactly for this — Student 360
— which makes it the fairest possible place to run the test.

### 5.1 OS-020 — Student 360 is a one-way sink: 1,050 lines, zero outbound taps (P1)

`lib/features/student_360/student_360_screen.dart` contains **zero** occurrences
of `context.push`, `context.go`, `Navigator`, `RouteNames.` or `onTap`.

It renders sections titled Academic performance (`:98`), Attendance (`:105`),
Fees (`:112`), Transport (`:118`), Homework (`:124`), Behaviour (`:130`),
Communication (`:136`) and Documents (`:142`). Every one is built by `_Section`
(`:628-666`), which passes `List<(String, String)> entries` into an
`AksharaKeyValueCard`. **Plain text pairs. Not one is a tap target.**

| Hop | Exists? |
|---|---|
| Student → their fee ledger | **No** — the Fees section is static text |
| Student → their attendance register | **No** |
| Student → their exam results | **No** — `_ExamList` (`:688`) renders, never navigates |
| Student → their transport route | **No** — static text |
| Student → their library loans | **No — the data does not exist.** `Student360Profile` (`student_360_models.dart:3-45`) has **no `library` field**, and no hostel, health, certificate or gate-pass field either |
| Student → call the guardian | Yes — the only outbound action, and it **leaves the app** (`phone_call_launcher.dart`, `:6/:493`) |
| Student → export PDF | Yes (`_ExportButton`, `:905`) |

Inbound is healthy: five modules deep-link *in* via `openStudent360`
(`lib/router/student360_navigation.dart:7-10`) — student_success (`:309`),
sis_profile (`:342`), sis_registry (`:374`), the teacher class dashboard
(`:122`), teacher_student_risk (`:173`).

**Every module can push you into Student 360; nothing can carry you out.** The
entity-continuity test fails at hop one — and the shape of the failure is
diagnostic. The screen is not missing links; it is missing the *idea* that its
contents are entities. And its model has no field for the three modules a school
actually chases a student across at year end: library, hostel, health.

---

## 6. Per-module verdict

### 6.1 How each module was classified

Reconciled `lib/features/` (53 dirs) × `supabase/functions/_shared/` (73 dirs) ×
`docs/certification/FEATURE_INVENTORY.md` (M1–M28). Coupling was traced by
cross-directory imports in the Deno backend plus actual SQL table reads and
writes.

**A methodological finding worth stating before the table:** `lib/features/*`
has almost **zero cross-feature imports**. All real coupling in this product
lives in the backend. The Flutter client is 53 modules that do not know about
each other — which is defensible architecture, but it means the client can never
be the place integration is felt, and it explains Section 5's result at Student
360.

Definitions used:

- **INTEGRATED** — completing this module's primary action causes a real,
  traced change in another module's data, **and** it reads shared canonical
  state to do its job.
- **PARTIAL** — one of those, not both; or the link exists in code but is
  unwired.
- **ISOLATED** — works, but alone. No outbound consequence, no shared-state
  read. Nothing outside it learns that anything happened.

**"Writes a `domain_event`" does not count as an outbound consequence** — the
bus is dead (XMOD-001), so a domain event is a row in a table nobody reads.
Applying that rule is what separates this classification from the module list in
the feature inventory.

### 6.2 The table

| Module | Status | Outbound consequence | Reads shared state | Verdict |
|---|---|---|---|---|
| **Admissions** (M8) | LIVE | yes — handoff consumed by Finance (`_shared/finance/finance_assignments_repository.ts:1,860,1091,1144`); enrollments by `_shared/sis/sis_conversion_handlers.ts:27,191` | yes | **INTEGRATED** |
| **SIS** (M10) | LIVE | yes — `_shared/sis/sis_conversion_repository.ts:176,245` writes canonical `student_profiles` + `sis_student_enrollments` | yes (`sis_students_repository.ts:5,19`) | **INTEGRATED** |
| **Finance / Fees** (M9) | LIVE | yes — `finance_student_accounts` read by `_shared/clearance/clearance_contributors.ts:32`; receipts feed `dashboard_service.ts` | yes | **INTEGRATED** |
| **Transport** (M13) | LIVE | yes — `transport_write_handlers.ts:1796` calls Finance `assignFeeStructure`; `:701-710` guardian push | yes (`:24` SIS resolver) | **INTEGRATED** |
| **Clearance** (M21) | LIVE | yes — blocks TC issue via `sis_certificates_repository.ts:31,32` | yes — reads Finance + Inventory | **INTEGRATED** |
| **Certificate Desk** (M21) | LIVE ⚠ orphaned from nav | yes — `certificate_desk_approval_effect.ts:154` writes `sis_certificate_issues`; submits into Approvals | yes (`:47` clearance, `:38` SIS) | **INTEGRATED** |
| **Gate Pass** (M21) | LIVE ⚠ orphaned from nav | yes — `gate_pass_handlers.ts:133` → Approvals; `gate_pass_repository.ts:479` notifies guardian | yes | **INTEGRATED** |
| **Student Health** (M21) | LIVE ⚠ orphaned from nav | yes — `student_health_operations.ts:174` real parent notification, in-transaction | yes | **INTEGRATED** |
| **Onboarding** (M27) | LIVE | yes — writes canonical `students`, `student_profiles`, `sis_student_enrollments`, `student_guardians`, `employees` | yes | **INTEGRATED** |
| **Communication** (M18) | LIVE | yes — the sink 8 modules write into | yes | **INTEGRATED** |
| **Entitlements / Plans** (M25) | LIVE | yes — `withEntitlement` gates 12+ routers (`route_registry.ts:161-195`) | yes | **INTEGRATED** |
| **Management / Approvals** (M12) | LIVE | yes — approvals decide gate-pass, certificate, refund, stock-adjust outcomes | yes | **INTEGRATED** |
| **Attendance** (M5/M12) | LIVE | yes — feeds risk snapshots + 4 dashboards | yes | **INTEGRATED** |
| **Exams / Academics** (M17) | LIVE | yes — `exam_mark_entries` read by management + intelligence | yes | **INTEGRATED** |
| **Parent app** (M4) | LIVE ⚠ CERT-001/002 | yes — corrections, payments, leave | yes | **INTEGRATED** |
| **Teacher app** (M5) | LIVE | yes — attendance, marks, homework | yes | **INTEGRATED** |
| Timetable (M17) | LIVE | slots read by health/teacher/parent; substitution notifies nobody (SIM-004) | yes | PARTIAL |
| **HR / Payroll** (M11) | LIVE | **none real** — see 6.3 | yes | **PARTIAL** |
| Inventory (M16) | LIVE | distribution only — `inventory_distribution_repository.ts:2,233,298` → Payment; `clearance_contributors.ts:77` | partial — core is a JSONB blob | PARTIAL |
| Library (M15) | LIVE | **weak** — see 6.3 | **no** | PARTIAL (barely) |
| Complaints (M21) | LIVE ⚠ orphaned from nav | **none** — no notification producer (SIM-003) | weak — reads `inventory_vendors` for a dropdown | PARTIAL |
| Support (M3) | LIVE ⚠ no school entry point (CERT-005) | yes — mirrors to Control Center (`support_mirror.ts:14`), `propagateResolution` back | yes | PARTIAL |
| Achievement / Promotion (M27) | LIVE | yes — `publisher_dispatch.ts:14,15` → communication + social | no school-domain read | PARTIAL |
| Operations Hub (M27) | LIVE | none (read-only hub) | yes | PARTIAL |
| Intelligence / Analytics (M19) | LIVE | none (read-only by design) | yes | PARTIAL |
| Copilot / AI (M19) | LIVE | none (read-only) | yes | PARTIAL |
| Predictions (M19) | LIVE | none | yes | PARTIAL |
| Director (M24) | LIVE | none | yes | PARTIAL |
| Control Center (M23) | LIVE (superAdmin) | yes — receives support mirror | yes | PARTIAL |
| Student app (M6) | LIVE | yes (homework submit) | yes | PARTIAL — notifications dead (CERT-004) |
| School Config / Branding (M25) | LIVE | yes — calendar read by attendance/timetable | yes | PARTIAL |
| Evolution / Parent insights (M4/M19) | LIVE | none | yes | PARTIAL |
| **Hostel** (M14) | LIVE | **NONE** | **no** | **ISOLATED** |
| **Alumni** (M22) | HIDDEN (CODE-8) | **NONE** | **no** | **ISOLATED** |
| **Backup & Restore** (M7) | LIVE, orphan route | **NONE** | no | **ISOLATED** |
| **Memories** (M27) | HIDDEN | **NONE** | no | **ISOLATED** |
| **Parent Meetings** (M27) | HIDDEN | **NONE** — no backend write path | no | **ISOLATED** |
| **Continuity** (M10) | HIDDEN | **NONE** — no backend dir | no | **ISOLATED** |
| **Dynamic Widgets** (M27) | HIDDEN | **NONE** — full backend, 0 consumers (OS-012) | no | **ISOLATED** |

**Not judged — MOCK/HIDDEN in the release build**, per FEATURE_INVENTORY.md
M25/M26, so a school never reaches them: verticals (healthcare, salon,
restaurant, accommodation), industry framework, white-label, platform
operations, multi-school, branch, franchise, workflow automation, resource
optimisation, education/QIE. Their `*_API_ENABLED` flags are absent from
`config/live_release.json`, their repositories resolve to `Mock*`, and both hide
gates suppress them. **These are correctly excluded rather than counted as
isolated** — hiding a backend-less surface is the honest behaviour the product
inventory documents, not a defect.

### 6.3 OS-021 — the ISOLATED list (P1)

**This list is the answer to the workstream's question.** Seven modules ship in
the product and participate in nothing.

1. **Hostel** — `lib/features/hostel` / `_shared/hostel`. Touches only
   `hostel_entities` (`hostel_read_repository.ts:7,56`); imports nothing but
   audit, entitlements and the generic entity store. **It carries its own
   duplicate copy of the student roster** as a `student` entity type inside
   `hostel_entities` (`hostel_read_repository.ts:224-225`), so a hostel resident
   and an SIS student are two unrelated records. It is registered
   `tracked: false` in the clearance registry
   (`_shared/clearance/clearance_contributors.ts:115-125`) — which is XMOD-021's
   "no dues means fees only" seen from the other end — and it appears in no
   shared dashboard query. **This is the most consequential entry on the list:**
   a residential school's second-largest operational surface is a private
   database.
2. **Alumni** — zero SQL, zero cross-module imports beyond audit and
   entitlements; a pure `alumni_entities` JSONB blob. **Graduating a student in
   SIS does not create an alumnus.** (Also HIDDEN in V1 by owner decision
   CODE-8, so no pilot school sees it — but the isolation is structural, not a
   consequence of hiding.)
3. **Backup & Restore** — `lib/features/admin/backup/backup_restore_screen.dart`.
   No backend directory; the status panel is a hard-coded static card; and the
   route has **zero navigation references** (`app_router.dart:602` is the only
   mention). A backup console that reports a fabricated status is a claim about
   data safety nobody can act on.
4. **Memories** — self-contained album tables. HIDDEN.
5. **Parent Meetings** — UI built, **no backend write path at all**. HIDDEN.
6. **Continuity** — no backend directory; `CONTINUITY_API_ENABLED` absent. HIDDEN.
7. **Dynamic Widgets** — complete backend, zero consumers (OS-012). HIDDEN.

### 6.4 OS-022 — three modules that only *look* connected (P1)

Called out rather than buried, because each would pass a shallower audit:

- **Library** escapes ISOLATED only by `library_write_handlers.ts:1049`
  (`scheduleReminder` → `comm_broadcasts`) — and that call is a **blanket
  broadcast to the entire parent body**, not a message to the borrower's parent.
  The module's own source comment at `:30` says so: *"fan out to the whole parent
  body."* Its members are keyed **by name, not by student UUID**, it holds a
  `library_entities` JSONB store with no SIS read, and clearance registers it
  `tracked: false` (`clearance_contributors.ts:98-112`). **Functionally it is an
  isolated ledger with a megaphone**: every parent in the school is told a book
  is overdue, and the parent who actually owes it is not told specifically.
- **Complaints** escapes only by reading `inventory_vendors` to populate an
  assignment dropdown (`complaints_repository.ts:436`). It writes `complaints`
  and `complaint_events` and produces no notification of any kind, which is
  SIM-003 confirmed structurally rather than by symptom.
- **HR / Payroll** — `hr_finance_posting_repository.ts:105` writes
  `payroll_finance_postings`, and **no module reads that table** (the only
  mentions are inside `hr/` itself). The intended consumer,
  `_shared/expense_ledger/`, has **zero `postExpense` callers and is not
  registered in `_shared/route_registry.ts`**. The Finance import at
  `hr/hr_handlers.ts:12` is a response mapper only. **The payroll → finance link
  is fully built and never connected** — the same "built, tested, never wired"
  pattern WS9 found in the UI layer, here on the money path. Salary is the
  largest expense a school has, and it does not reach the books.

### 6.5 Score

| Verdict | Count | Share |
|---|---|---|
| INTEGRATED | **16** | 42% |
| PARTIAL | **15** | 39% |
| ISOLATED | **7** | 18% |

Of the 7 isolated, **3 are live in the release build** (Hostel, Backup &
Restore, and — via 6.4 — effectively Library); 4 are HIDDEN.

---

## 7. Verdict

**NOT CERTIFIED as a School Operating System.**

The product is best described as **a set of well-built independent modules
behind one router, one theme, one tenant scope and one genuine RBAC layer.**

The reason this is not a harsh reading is that the integration that *does* exist
is real and concentrated in exactly the right place: **the admission → enrolment
→ fee → attendance → exam spine is genuinely integrated.** Admissions hands off
to Finance and SIS with traced writes. SIS writes canonical student records.
Transport raises a real fee assignment. Clearance actually blocks a TC.
Certificate Desk, Gate Pass and Student Health all reach into Approvals, SIS and
the notification rail. Sixteen modules — 42% — earn INTEGRATED on strict
criteria. A school could run its core year on this.

**What fails is everything that would make those modules one system rather than
a well-connected core plus outbuildings:**

| Dimension | Result |
|---|---|
| Shared state | One canonical quantity of thirteen — and it is corrupted at the client mapper (OS-001). Four definitions of "how many students", two grading scales that disagree at 35%, three definitions of "collected", no academic-year resolver at all. |
| Cross-cutting layers | RBAC and the error envelope are platform. Audit is platform-shaped but non-transactional at all 305 sites. **Notifications reach 15% of modules.** Diagnostics have one caller. Reporting has no backend service. The dashboard registry has zero consumers. |
| Role & workspace | 8 of 10 workspaces hold one module; 3 hold none; 5 roles share one workspace; **5 live school desks belong to no workspace and are invisible to every role including superAdmin (JOURNEY-008).** 2 of 8 shared screens adapt to the viewer. Workspace is read by 4 navigation files and 0 feature modules. |
| DAI | 11 intents, 7 modules, **reads zero state**. A two-module question is impossible by construction. |
| Entity continuity | Student 360 — the screen built for this — has **zero outbound taps** in 1,050 lines, and its model has no field for library, hostel or health. |
| Module verdict | 16 INTEGRATED · 15 PARTIAL · **7 ISOLATED** |

### The single sentence

**A school using NIKSHA OS gets a genuinely integrated admissions-to-exams
spine, surrounded by modules that keep their own copies of the truth, tell
nobody what they did, and cannot be reached from the thing they are about.**

### What would change the verdict

These are the load-bearing repairs, in the order that maximises change per unit
of work. Note how few of them are new construction:

1. **Deliver the notification rail to the 53 modules that mutate without it**
   (OS-009). Attendance marking a child absent and telling nobody is the single
   clearest disproof of "operating system". The rail exists and works.
2. **Add the 5 orphaned desks to a workspace** (JOURNEY-008). One map entry each.
   Complaints, Certificate Desk, Gate Pass, Infirmary and School Completion are
   finished modules that no user can find.
3. **Put a school context — academic year, term, class — into `TenantContext`
   and make modules read it** (OS-006, OS-017). This is the missing spine of the
   workspace model, and it removes 66 hard-coded literals in two different dash
   characters.
4. **Make audit transactional** (OS-007). 305 call sites currently commit the
   mutation and then hope.
5. **Converge the counted quantities** — student count, grading, exam
   percentage, collected (OS-002/003/004/005). `attendance_percentage.ts` is the
   proof this team knows how; it needs to be the pattern rather than the
   exception.
6. **Give Student 360 outbound taps and the three missing data fields** (OS-020),
   and connect the payroll → finance posting (OS-022). Both are wiring, not
   design.

Items 1, 2 and 6 are wiring existing, working code. That is the honest shape of
this result: **the gap between "modules" and "OS" here is smaller than the gap
usually is, and almost none of it is architectural.**

