# NIKSHA OS — Systemic Remediation Roadmap

**Produced:** 2026-07-29 · **Input:** `PROGRAM_STATE.md`, `DEFECT_REGISTER.md`
(196 entries · 36 P0 · 104 P1 · 50 P2 · 6 P3), eleven workstream findings under
`docs/certification/findings/`.
**Status:** PLANNING ONLY. No code changed. Nothing committed.

---

## 0. The thesis of this roadmap

Certification cycle 1 did not find 196 unrelated bugs. It found **five defective
habits**, each of which minted defects until a certification agent happened to
walk past one. The register is the *sample*; the five causes are the *population*.

The RC phase's recorded failure mode was fixing instances rather than classes —
"the two attendance routes found in RC were not an outlier; they were a sample"
(`PROGRAM_STATE.md` §Fourth systemic item). This roadmap is written to not repeat
that. Every work item below is stated as **one change that removes a class**, with
the registered defects it closes named by ID, and — critically — a **mechanical
guard** (a test that fails today) so the class cannot silently return.

**The five root causes**

| RC | Name | Registered defects in the class | Why it is one cause, not many |
|---|---|---|---|
| **RC-1** | Fabricated data as production fallback | 21 | One idiom — `?? Something.mock()` at the end of a provider — copied across 9 providers, plus 6 const "demo figures" tables and 6 demo-fixture id maps. `/parent/payment` does not merely display the fabricated ₹4,200; it **sends** it to the initiate endpoint. |
| **RC-2** | Privilege / role mapping fails open | 14 | Unknown server role → `ErpRole.superAdmin` on login and → `ErpRole.parent` on restore. 29 server roles vs 15 client. Every "role X cannot do their job" defect and every "role X sees things they should not" defect is downstream of one enum and one fallback. |
| **RC-3** | Dates & academic-year resolution | 14 | Dates persisted as **display labels** with the real date column sitting unused on the same row. The fee counter sends the literal `'Today'` → `fiscalYearOf('Today')` = `NaN-NaN` → the parent's receipt reads `SCH/NaN-NaN/000042`. No academic-year resolver exists at all: 66 hard-coded literals in two different dash characters. |
| **RC-4** | RBAC inventory is not a gate | 12 | 97 mutating routes absent from the inventory, 91 stale rules — and the suite never dispatches a route, so an unlisted ungated route **passes**. The inventory is a document that looks like a control. |
| **RC-5** | No single source of truth per quantity | 23 | 1 of 13 cross-module quantities is canonical. 4 definitions of "student count" with **billing on the unfiltered one**; 2 grading scales disagreeing at 35% (server F, report card D); 3 definitions of "collected"; 5 of "outstanding dues". |
| — | Residual (wiring, notification, UX, polish, owner) | 112 | Genuine independent defects; sequenced into Phases 3 and 4 behind the five, plus the 4 live-pilot items in §8. |

The five classes account for **84 of 196** entries and **21 of 36 P0s**. The
remaining 15 P0s are residual security / data-integrity / financial defects —
DAI-001, DAI-004, XMOD-001, XMOD-003, XMOD-004, XMOD-006, XMOD-007, XMOD-008,
E2E-019, API-119, OS-007, OS-009 and the three live-pilot items — and they are
scheduled by severity, not by cause.

The 112 residual entries are not "the rest of the bugs". They are what remains
once the five generators are switched off, and Phases 3 and 4 sequence them
**behind** the causes so each is fixed once, on a correct foundation, rather than
twice. The ordering is the whole point: fixing the dashboards before the canonical
counts, or the notifications before the scheduler, produces work that has to be
redone.

---

## 1. How to read every item

Each work item states, in this order:

- **Root cause** — which of RC-1…RC-5 (or `residual`) it eliminates.
- **Defects closed** — register IDs. A defect appears under exactly one item as
  *closed*; where another item is required for the user-visible effect, it is
  listed as *unblocked* rather than closed.
- **The change** — the single change, stated as an outcome, not a task list.
- **Files** — repo-relative. `_shared/` = `supabase/functions/_shared/`.
- **Blast radius** — what else observably moves.
- **Regression risk** — and what specifically can break.
- **Verification** — *the test that proves it, phrased so that it fails today.*
  An item with no such test is not finished; a fix without one is how RC-1 got to
  nine instances.
- **Dependencies** — hard ordering only.
- **Effort** — S (≤1 day) · M (2–4 days) · L (1–2 weeks) · XL (>2 weeks), one
  engineer.

---

## 2. Ordering constraints that are NOT negotiable

These are carried forward from `PROGRAM_STATE.md` and the register. Violating any
one of them makes the product **worse than it is today**.

### 2.1 DAI-005 and DAI-016 are load-bearing on each other

`openPerson` being structurally unreachable is the **only** thing currently hiding
34 wrong answers. `_person` is the last resolver rule and swallows the entire
out-of-vocabulary space at confidence 60 — `payroll`, `timetable`, `gate pass`,
`pending approvals`, `support ticket` all resolve to *"Looking for Payroll…"*. The
user is protected solely by the consumer discarding every `openPerson` intent
(`global_search_overlay.dart:85`).

**Therefore: fixing DAI-005 alone makes the product visibly worse** — 34 silent
misroutes become 34 confident false answers on the principal's search bar.

**Rule: DAI-016 lands first or in the same commit as DAI-005. Never DAI-005 alone.**
The AI harness enforces this and fails if `openPerson` gains a route while the
`_person` junk-drawer is still open (AI-001). Do not weaken that harness assertion
to unblock a wave.

### 2.2 The domain-event status literal must not flip before the drain cron exists

`enqueueDomainEvent` inserts rows **already terminal** (`status='published'`) while
the drain selects only `('pending','failed')`. Flipping the insert literal without
an installed scheduler converts a table nothing reads into a table of **permanently
stranded unpublished events** across 171 event types and 368 write sites.

**Rule: scheduler first (XMOD-016), status literal second, in separate releases.**
Subscribers must be registered and idempotent before the first drain runs over a
populated table. Sequenced as W3.1 → W3.2 in Phase 3; they may not be merged into
one release.

### 2.3 API-105 / API-107 / API-108 are about the LIVE pilot, not this repo

These three are the only findings in the entire register about the **running
system** rather than the code. They were found by read-only probes against the
deployed pilot.

- **API-105** — the deployed build has no central auth chokepoint; anonymous calls
  get 404/422, not 401. `eng4_5_forced_auth_test` asserts ICA-F1 makes these 401 —
  that is a **repo** property. The deployed build is behind the repo.
- **API-107** — `/health/*` answer the public internet, leaking school count,
  backup SHA-256 and the isolation matrix; the guard keys off the same `APP_ENV`
  flag that puts login OTPs in the response body.
- **API-108** — the pilot's own RLS isolation matrix is **RED right now**: four
  student-scope probes fail. School-to-school and parent-to-child pass, so it is a
  **persona boundary** failure, not a tenant leak.

**Rule: these are owner/infra actions, not code changes in this repo.** They are
carried in §8 as a separate owner-gated track and are deliberately **excluded from
every phase's exit criteria**, because no amount of engineering in this repository
can close them. They are also, right now, the highest real-world risk in the
document. Do not let a green Phase 1 be read as "the pilot is safe".

### 2.4 Two P0s are deliberately NOT in Phase 1 — stated, not hidden

- **XMOD-004** (bus allocation raises no fee demand) is P0 but it is a *missing
  workflow*, not a wrong figure. It **creates money**, so it needs the idempotent
  demand path and the double-bill guard that Phase 3's allocation work builds.
  Fixing it in Phase 1 in isolation risks double-billing every student whose
  demand was already raised manually.
- **XMOD-001** (domain events never delivered) is P0 and is held to Phase 3 by
  §2.2 — the scheduler must exist first.

Everything else P0 lands in Phase 1 or Phase 2, both of which are pre-pilot gates.

---

## 3. PHASE 1 — security · data integrity · financial correctness · fabricated data · privilege

**Exit criterion:** no production render path can reach a fabricated financial,
attendance, examination or records value; no unknown role gains privilege; no
session is un-endable; the money write path cannot silently lose or mis-date a
collection; the audit trail cannot diverge from the mutation it describes.

**Explicitly NOT an exit criterion:** API-105 / API-107 / API-108 (§2.3).

---

### W1.1 — One honest-async contract; delete the mock terminal fallback

- **Root cause:** RC-1.
- **Defects closed:** **CERT-001**, **CERT-002**, **JOURNEY-007**, **WIDGET-001**,
  **WIDGET-002**, **CERT-006**, **E2E-005**, **E2E-011**, **E2E-012**, **E2E-021**
  (10 — seven P0). **This is the largest single retirement in the roadmap.**
- **The change.** Two halves, and **both are required** — the register is explicit
  that they are independent gaps and that fixing either alone leaves the screen
  lying (WIDGET-001 root cause, (1) and (2)):
  1. **Delete every `?? *.mock()` / `?? _fallbackSummary(...)` terminal fallback**
     from production providers. Where a non-null shape is needed, add `.empty()` —
     `StudentDashboardData.empty()` (`student_dashboard_provider.dart:274-285`) is
     the in-tree pattern and it is already correct.
  2. **Make screens derive state from the real `AsyncValue`.** Today
     `parent_dashboard_screen.dart:39-41`, `teacher_dashboard_screen.dart:31-33`
     and the fees/homework/payment screens read only
     `*LoadingProvider`/`*ErrorProvider` — `StateProvider<bool>` defaulting to
     `false` and, verified by grep across `lib/`, **never written outside tests**.
     `student_dashboard_screen.dart:36-39` ORs `async.isLoading` / `async.hasError`
     and is the pattern to copy.
  3. For **JOURNEY-007** specifically the fix is not display-only: the pay action
     must be **disabled without a server-issued summary**, because
     `submitParentPayment` sends `amount: summary.totalAmount` to
     `POST /parent/payments/initiate` (`parent_payment_provider.dart:134-145`).
     Keep the existing fail-closed `pendingGatewayVerification` state — that part
     is right.
  4. **E2E-011 / E2E-005** are the same idiom in service form:
     `TeacherStudentRiskService._snapshotFor` composes attendance/marks/homework/fees
     from constants and `MockAttendanceSyncStore`, and the corrections admin card
     reads `MockAttendanceSyncStore.instance`. Both mock stores must be removed
     from the release path; the risk dossier's four rows source from
     `/attendance/*`, the exams feed, the homework store and
     `/finance/student-accounts`, with a per-row honest unknown.
     **Until those four sources are wired, the risk screen must not ship** — it is
     fabricated where it works and throws `StateError` where it does not.
  5. **E2E-021**: `AiContentService` (`ai_content_service.dart:32-39`) must rethrow
     instead of returning the user's own prompt stamped `generatedAt: now()`.
  6. **E2E-012** is the same singleton in export form: **Export marks summary**
     builds its CSV/PDF from `ExamAdministrationStore.instance.marksEntryProgress()`,
     which calls `ensureSeeded()` and in a release build returns the **seeded demo
     exam** (`exam_math_8a`, *"Unit Test — Mathematics"*, mock roster) — while the
     exam list on the same screen comes from the API and shows the school's real
     exams. **The file leaves the app**: it is a shareable document of examination
     data about an exam that does not exist. Derive the rows from
     `examAdministrationListProvider` + the live marks data the screen already
     renders (or add `GET /academics/exams/progress`).
- **Files.** `lib/features/parent/fees/fees_provider.dart:290-301` ·
  `parent/dashboard/parent_dashboard_provider.dart:304-316` and
  `parent_dashboard_screen.dart:38-41` ·
  `parent/homework/parent_homework_provider.dart:21-33` ·
  `parent/payment/parent_payment_provider.dart:63,66-101` ·
  `teacher/dashboard/teacher_dashboard_provider.dart:312-324` and
  `teacher_dashboard_screen.dart:29-33` ·
  `hr/reports/hr_reports_provider.dart:34` · `hr/hr_models.dart:628` ·
  `lib/core/providers/repository_future.dart:5-14` (the shared `whenOrNull(data:)`
  that returns null for BOTH loading and error — the enabling mechanism) ·
  `lib/core/communication/teacher_student_risk_service.dart:95-140` ·
  `lib/core/repositories/mock/mock_attendance_sync_store.dart` ·
  `lib/features/management/attendance/attendance_corrections_admin_screen.dart:6,30,63-76` ·
  `lib/features/copilot/content/ai_content_service.dart:32-39`.
- **Blast radius.** Every persona dashboard's first frame changes. The golden
  suite **pins the mock path** — `test/golden/golden_test_helpers.dart:79-81,123-125`
  overrides all nine dashboard loading providers to `false` — so the goldens must
  be re-baselined against the honest states. Do this **once**, at the end of Phase 1
  (see §7 do-not-attempt #12).
- **Regression risk.** Low-medium. The real risk is not the code but the **tests**:
  the existing "error state" tests
  (`test/features/parent/parent_fees_screen_widget_test.dart:88`,
  `qa_c_001_parent_app_behaviour_cert_test.dart:145`,
  `parent_payment_provider_test.dart:62`) assert a state the live path cannot
  reach. They must be rewritten, not merely re-run, or Phase 1 will show green on
  the same false premise that let this ship.
- **Verification (fails today).** A widget test that drives each of the nine
  providers through a repository that **throws**, and asserts the rendered tree
  contains `AksharaErrorState` and does **not** contain `₹4,200`, `Ravi Kumar`,
  `9:02 AM`, `9:12 AM`, `142 active staff` or `96.2%`. Plus a repo-wide lint:
  **no file under `lib/` outside `lib/core/repositories/mock/` may reference
  `.mock()`**. Both fail today.
- **Dependencies.** None. This is the first thing that should be done.
- **Effort.** M (2–4 days) for the nine providers + guard; **+M** for E2E-011's
  four real data sources, which is the only non-mechanical part.

---

### W1.2 — Delete compile-time "demo figures" and every fixture-id map

- **Root cause:** RC-1.
- **Defects closed:** **JOURNEY-001**, **WIDGET-011**, **CERT-003**,
  **JOURNEY-015**, **JOURNEY-016**, **POLISH-010**, **E2E-002**, **E2E-009**,
  **E2E-013** (9 — two P0).
- **The change.** Three mechanically distinct residues, one habit:
  1. **Const stat tables.** Delete `stats` from `kWorkspaceLandingConfig`
     (`workspace_landing_config.dart:27-84`, whose own comment concedes *"curated
     demo figures … so demos read as live"*). Keep the motif/eyebrow; the hero
     widget already accepts an empty list. **Do not substitute a different
     constant.** Same for WIDGET-011: make the health score **nullable** and render
     "Not enough data yet" — never blend `?? 68` and `?? 31` into a confident 51,
     and parse a typed percentage rather than stripping non-digits from a
     money-or-percent string (which pegs the score at 100 for `₹12,45,000`).
  2. **Fixture-id translation maps in production routers.** Delete
     `'ph_1' => 'rcpt_term_1'` and `_receiptIdForInstallment`
     (`app_router.dart:2353-2376`); carry the **real** receipt id on
     `PaymentHistoryItem`/`FeeInstallment`. Delete `installmentId ?? 'term_2'`
     (`parent_navigation.dart:33-36,110-115`) and the `notice_n1`/`event_e2`/
     `notice_n3` special cases (`:82-93`), which additionally target
     `/parent/ptm` — a **blocked route prefix**, so the parent taps a school notice
     and is told access is denied. Make the `default:` arm at `:133-134` surface an
     honest failure instead of `break`.
  3. **Seeded `TextEditingController(text: …)` in production dialogs.** Empty them:
     the attendance-correction date `'12 Jun 2026'` and reason *"Biometric sync
     error — student was present"* (`teacher_attendance_workflow.dart:31-34`) —
     which a teacher unknowingly files as a governance assertion that reaches the
     approval card, `attendance_corrections.date_label/.reason` **and the audit
     event**; the create-exam `Term 2 / 15 Mar 2026 / 9:00 AM - 10:30 AM / Room 8A`
     (`exam_create_dialog.dart:21-26`); and the offline-payment `'inv_1'`
     (`finance_offline_payments_screen.dart:277-296`), which additionally needs the
     invoice picker + required-field validation from `showRecordCollectionDialog`,
     because an instrument booked against a non-existent invoice **can never be
     reconciled and has no edit action** — the cheque sits in Pending forever.
- **Files.** As listed above, plus
  `lib/features/admin/screens/admin_hub_screen.dart:39-63` ·
  `lib/features/management/widgets/management_principal_overview_panel.dart:24-39` ·
  `lib/core/config/school_build_scope.dart:82-83` ·
  `_shared/finance/finance_offline_payments_handlers.ts:80-95` (server-side
  invoice-exists check, 422).
- **Blast radius.** The `/admin` hero — the first screen 6 of 15 staff roles see
  every day — becomes name-only until real per-workspace summary providers exist.
  That is the correct interim and the hub already handles it.
- **Regression risk.** Very low for the deletions (no data path involved).
  Low-medium for CERT-003, which needs the receipt id present on the fee model.
- **Verification (fails today).** (a) A test asserting `kWorkspaceLandingConfig`
  declares **zero** `AksharaWorkspaceStat` values. (b) A router test asserting no
  route builder maps a literal string id to another literal string id. (c) A form
  test asserting every `TextEditingController` constructed in a production dialog
  starts with `text: ''`. (d) A management-dashboard test asserting the health ring
  renders the not-enough-data state when either input is absent. All four fail today.
- **Dependencies.** CERT-003 depends on the fee model carrying a real receipt id.
- **Effort.** S–M.

---

### W1.3 — A real file picker, or no upload action at all

- **Root cause:** RC-1.
- **Defects closed:** **E2E-017** (P0, priority candidate).
- **The change.** There is **no file picker in the product**. All four upload
  surfaces — SIS student documents, admissions documents, student homework
  submission, teacher homework attachment — post the same hard-coded 5-line blank
  PDF (`%PDF-1.4 … MediaBox[0 0 200 200] … %%EOF`) through the real
  presign→PUT→confirm Storage path, under a user-typed file name. Add `file_picker`
  (or extend the existing `image_picker`, currently used **only** by the support
  screen) and pass real bytes + real MIME + real name on all four paths; add
  MIME/size validation at the presign endpoint. **Until that ships, hide the four
  upload actions** — writing a blank page is worse than offering nothing.
- **Files.** `sis/sis_mutations_provider.dart:136-160` ·
  `sis/sis_workflow_actions.dart:28-40,74-90` (and the **verify** dialog at
  `:98-130`) · `admissions/admissions_workflow_actions.dart:478-487` ·
  `student_app/student_mutations_provider.dart:60-90` ·
  `teacher/teacher_mutations_provider.dart:618-648` · `pubspec.yaml:58`.
- **Blast radius.** Blocks certification of admissions document verification, SIS
  document verification, TC/clearance (**XMOD-021**) and homework grading — all
  four currently rest on documents that may be blank pages a clerk marked
  **verified**.
- **Regression risk.** Low-medium; the server side is already correct.
- **Data action (not optional).** Every document row created by these paths is
  suspect. Produce the list and mark them **unverified**; an admission approved on
  a documents-complete checklist made of blank pages is a governance decision that
  needs revisiting.
- **Verification (fails today).** A test asserting no upload call site passes the
  synthetic `%PDF-1.4` constant, plus an integration test that the bytes uploaded
  equal the bytes chosen. Fails today because the constant *is* the payload.
- **Dependencies.** None.
- **Effort.** M.

---

### W1.4 — One fail-closed role resolver, and the five missing roles, in one release

- **Root cause:** RC-2.
- **Defects closed:** **JOURNEY-002** (P0), **JOURNEY-003**.
  **Unblocks:** JOURNEY-012, JOURNEY-013, JOURNEY-014, OS-014, JOURNEY-004.
- **The change.** Today an unrecognised server role resolves to
  **`ErpRole.superAdmin`** on login (`auth_mapper.dart:63-66`, repeated at
  `auth_session_manager.dart:172`) and to **`ErpRole.parent`** on session restore
  (`auth_claims.dart:126-132`) — the same user is a super admin in one code path
  and a parent in the other, so their workspace, landing route and hub tiles change
  between a fresh login and an app relaunch. The server defines **29** role slugs;
  the client enum has **15**.
  One shared resolver, failing **closed**: introduce `ErpRole.unknown` (or make
  `AuthUser.erpRole` nullable) granting **no workspace and no role-keyed gate**, and
  render an explicit *"your role is not supported by this app version"* state. Add a
  permission conjunct to `canAssignOrganizationPlansProvider`, which is role-only
  today — which is why an office clerk or a school nurse currently renders the
  organization plan-assignment screen **and its Save action**.
  **In the same release**, add the five real school roles the server already seeds:
  `hrManager`, `officeStaff`, `healthStaff`, `classTeacher`, `coordinator`, each with
  a `RolePermissionMatrix` entry matching the server grants and a `kRoleWorkspaces`
  entry.
- **Files.** `lib/core/repositories/api/auth/mapper/auth_mapper.dart:56-72` ·
  `lib/core/auth/auth_session_manager.dart:172` ·
  `lib/features/auth/auth_claims.dart:107-145` ·
  `lib/features/auth/auth_provider.dart:303-320` ·
  `lib/core/security/erp_role.dart:2-17` · `lib/core/security/role_permissions.dart` ·
  `lib/core/workspace/workspace.dart:177-193` ·
  `lib/core/entitlements/subscription_admin_provider.dart:15-18` ·
  `supabase/functions/_shared/auth_handlers.ts:119-138` ·
  `supabase/migrations/20260608100000_rbac_foundation.sql:166-193`.
- **Blast radius.** Every role-keyed gate in the client.
- **Regression risk. Medium, and this is the one item in Phase 1 with a real
  chance of locking users out.** Failing closed removes access from any live user
  currently benefiting from the accidental super-admin mapping. **The enum
  additions must ship in the same release as the fail-closed default** — never
  fail-closed first.
- **⚠ OWNER GATE.** A live audit of which role slugs are actually assigned in the
  pilot is required before this ships. It could not be performed during
  certification (SSH is owner-bound). Treat as a §8 prerequisite, not a blocker on
  writing the code.
- **Verification (fails today).** A table test over **all 29 server slugs**
  asserting that client resolution is either a mapped `ErpRole` or `ErpRole.unknown`,
  that `unknown` opens no workspace and passes no role-keyed gate, and that the
  login path and the restore path return the **identical** value for every slug.
  Fails today on both counts.
- **Dependencies.** None. Prerequisite for W1.6 and for Phase 2's workspace work.
- **Effort.** M.

---

### W1.5 — Every persona can end its session

- **Root cause:** RC-2 (privilege granting fails open; privilege **revocation** is
  impossible).
- **Defects closed:** **POLISH-001** (P0, priority candidate).
- **The change.** In a release build the only profile affordance for principal,
  teacher, accountant and every other staff role is a snackbar reading
  **"Profile menu coming soon."** `confirmAndLogout` has three call sites: the
  **dev-only** branch of the admin scaffold, the parent profile screen, and nothing
  else — because `guardForRelease` forces `enableQaLogin: false`
  (`environment.dart:161`) and the log-out sheet sits inside the QA branch
  (`admin_content_scaffold.dart:88-111`). **Parents can log out. Nobody else can.**
  Move the sheet out of the QA branch and give it a real profile menu (name, role,
  school, Appearance, Support, Log out). It is one conditional away.
- **Files.** `lib/features/admin/admin_content_scaffold.dart:57,88-111` ·
  `lib/core/config/environment.dart:161` · `lib/features/auth/auth_logout.dart:11` ·
  `lib/features/admin/admin_app_bar.dart:120-131` ·
  `lib/features/teacher/profile/teacher_profile_screen.dart:157,166,173`.
- **Blast radius.** One shell + the teacher/student profile screens.
- **Regression risk.** Low.
- **Why it cannot wait.** Indian schools run shared devices. A teacher who finishes
  marking attendance cannot end their session, so the next person inherits
  authenticated access to student PII, fee collection and marks entry; a departed
  staff member keeps a live session until the token expires. It is also the first
  personal affordance a principal touches in an evaluation.
- **Verification (fails today).** A release-configuration widget test
  (`enableQaLogin: false`) asserting that **each** persona shell exposes an
  affordance that reaches `confirmAndLogout`. Fails today for every staff persona.
- **Dependencies.** None. The cheapest P0 in the register.
- **Effort.** S.

---

### W1.6 — DAI cards are gated by shell reachability, not by permission alone

- **Root cause:** RC-2.
- **Defects closed:** **DAI-001** (P0), **DAI-002**, **AI-006**.
  **Scope correction carried forward:** AI-006 refines DAI-002 — `homework` is not
  uniformly broken, it is **conditional on holding `ErpRole.teacher`**, so the
  remedy is to gate the card, not to delete the intent.
- **The change.** `_resolveDai` filters on **permission** only
  (`global_search_overlay.dart:86-87`). A permission cannot express "holds
  `ErpRole.teacher`" or "may enter the admin ERP shell", so a principal who **does**
  hold `Permission.viewAttendance` is shown *"Opening today's attendance."*, taps,
  and is silently returned to `/admin` — the single most-typed principal query in
  the product. Four more intents (`myFees`, `myAttendance`, `exams`(own),
  `homework`) carry `requiredPermission: null` and bounce the same way.
  Replace the permission filter with a **reachability predicate**: drop any intent
  whose route the current session cannot enter. The predicate already exists in
  production — `isAdminErpRoute` + `isPersonaOwnedRoute` + `canAccessAdminErpShell`
  (`app_router.dart:2264-2292`); the overlay simply does not call it.
  Then re-point `attendanceToday` at an admin-ERP surface:
  `dai_brief.dart:211-216` **already solved this exact problem for the same data**
  (`RouteNames.managementAnalytics`), with the reasoning written out. Reuse it.
  Drop `myFees`/`myAttendance`/`exams`(own) from the admin-surfaced set, adopting
  the decision already recorded for the sibling surface —
  `global_search_registry.dart:193-212` removed the Parent/Teacher/Student Dashboard
  entries on 2026-07-28 concluding *"the correct fix is no tile rather than a tile
  that silently bounces"*.
- **Files.** `lib/features/admin/global_search/global_search_overlay.dart:81-89` ·
  `lib/core/dai/dai_resolver.dart:194-212,215-270` ·
  `lib/router/app_router.dart:2264-2292`.
- **Blast radius.** The admin search card set shrinks. Nothing else.
- **Regression risk.** Low — a reachability predicate is strictly narrower than
  what renders today.
- **Verification (fails today).** A resolver invariant test asserting **every**
  `DaiIntent.route` is in `RouteNames.adminErpRoutes` — mirroring the assertion
  `dai_brief_test.dart` already makes for the brief — plus an overlay test that
  renders no card for a session that cannot enter the route. Fails today for
  `attendanceToday`, `homework`, `myFees`, `myAttendance` and `exams`(own).
- **Dependencies.** None. **Explicitly independent of the DAI-005/DAI-016 pair
  (§2.1)** — this item touches the consumer's filter, not the `_person` rule, and
  can ship without them.
- **Effort.** S.

---

### W1.7 — A DAI answer may not claim a filter the destination drops

- **Root cause:** RC-1 (a fabricated claim, arrived at by a different route).
- **Defects closed:** **DAI-004** (P0). **Closes with it:** **DAI-014**.
- **The change.** The resolver extracts `className`, `section`, `threshold`,
  `routeNumber`, `receiptNumber` and interpolates them into the answer sentence —
  *"Showing students below 75% attendance."* — and the sole consumer navigates with
  the **bare route constant** (`context.go(_daiAnswer!.route!)`,
  `global_search_overlay.dart:170`). Every extracted parameter is discarded at the
  navigation boundary. The principal lands on the **complete unfiltered roster**
  with nothing on screen indicating a filter was requested and dropped.
  For v1.0 take option (b) from the register: **weaken every sentence to match
  reality** ("Opening the defaulters list — filter to Class 10 there") and add a
  resolver-level invariant test that fails when an intent carries an extracted
  field the route cannot consume. **`lowAttendance` is the exception** — `/sis/students`
  cannot filter by attendance at all, so that intent must be **re-pointed or
  withdrawn**, not merely re-worded. Clamp threshold to 1–100 and class to 1–12 in
  the same change (DAI-014), because the moment parameters are plumbed a `200%`
  filter reaches a real query, and `below -5%` currently becomes **5** (the minus is
  stripped by `_normalise` and the sign is lost, inverting the meaning).
  Parameter plumbing proper (option (a)) is Phase 3 — the pattern exists
  (`teacherAttendanceRouteBuilder` reads `?class=`, `app_router.dart:2606`) but it
  touches four destination screens.
- **Files.** `lib/core/dai/dai_resolver.dart:83-103,111-125,128-191,273-288` ·
  `lib/features/admin/global_search/global_search_overlay.dart:165-172,277-278`
  (whose doc comment asserts the card *"can never say something the system will not
  then do"* — an invariant enforced nowhere).
- **Blast radius.** Answer copy only, plus one withdrawn intent.
- **Regression risk.** Low. The golden DAI corpus pins the sentences; the diff is
  the point.
- **Verification (fails today).** An invariant test: for every intent, each
  non-null extracted field must be either (a) present in the emitted route's query
  string or (b) absent from the answer sentence. Fails today on all five fields.
- **Dependencies.** None. Sequence **after** W1.6 so the corpus is re-pinned once.
- **Effort.** S.

---

### W1.8 — The counter's payment date is a date

- **Root cause:** RC-3.
- **Defects closed:** **E2E-008** (P0, priority candidate), **XMOD-037**.
- **The change.** `showRecordCollectionDialog` sends the hard-coded literal
  `collectionDate: 'Today'`. One string breaks two derived computations:
  - **Day lock bypassed.** `isDateLocked` compares ISO strings **lexically**;
    `"Today" <= "2026-07-28"` is `false` (`'T'`=84 sorts after `'2'`=50), so the
    FIN-D1 guard returns "not locked" for **every collection made from the app**.
    Closed, reconciled and reported books silently take new money.
  - **Receipt numbers read `NaN`.** `fiscalYearOf("Today")` → Invalid Date →
    `getUTCFullYear()` is `NaN` → the function returns `"NaN-NaN"`, so the parent's
    receipt reads `SCH/NaN-NaN/000042`; and because `fiscal_year` is part of the
    `finance_receipt_sequences` key, **every fiscal year shares one sequence** and
    the per-year reset that makes numbering auditable never happens.

  The INSERT lands on the right date **only by luck** — PostgreSQL accepts `'today'`
  as a special literal — so `collection_date` is correct while everything computed
  from the same value in TypeScript is wrong.
  Four-part fix: (1) send `DateTime.now()` as `yyyy-MM-dd`; (2) validate
  `collection_date` against `^\d{4}-\d{2}-\d{2}$` in the handler, 422 otherwise;
  (3) make `fiscalYearOf` **throw** on an unparseable date rather than returning
  `"NaN-NaN"`; (4) make `isDateLocked` compare **parsed dates**. Plus XMOD-037:
  default `receipts.receipt_sequencing` to `true` for new schools (gapless numbering
  is implemented, in-transaction and correct — it is simply off out of the box),
  keeping the legacy path only for existing tenants mid-year.
- **Files.** `lib/features/finance/finance_workflow_actions.dart:1366-1372` ·
  `lib/core/repositories/api/finance/dto/create_collection_request_dto.dart:24-27` ·
  `_shared/finance/finance_collections_handlers.ts:308` ·
  `_shared/finance/finance_day_close_repository.ts:51-61` ·
  `_shared/finance/finance_collections_repository.ts:221-227,273-302,625-630` ·
  `_shared/finance/finance_settings_repository.ts:47-52`.
- **Blast radius.** Every counter collection. The instrument-reconcile path already
  passes a real ISO date and is unaffected.
- **Regression risk.** Low **in code**. The careful part is data: existing
  `finance_receipt_sequences` rows with `fiscal_year = 'NaN-NaN'`, and **receipt
  numbers already issued containing `NaN` are printed documents that will need
  reissue.** Produce that list before the code change, not after.
- **Verification (fails today).** (a) A handler test asserting
  `collection_date: 'Today'` returns 422. (b) A day-close test asserting a
  collection dated inside a closed day is **rejected** — today it is accepted.
  (c) A unit test asserting `fiscalYearOf` throws on `'Today'` rather than
  returning `"NaN-NaN"`. All three fail today.
- **Dependencies.** None — ships independently of everything else in the register.
- **Effort.** S for code, M including the receipt-reissue data pass.

---

### W1.9 — The money write path cannot silently lose a collection

- **Root cause:** residual — financial correctness (Phase 1 by owner scope).
- **Defects closed:** **API-119** (P0, priority candidate), **API-113**, **E2E-010**,
  **API-120**, **API-121**, **API-122**, **API-123**.
- **The change.**
  1. **API-119 — split the wire contract.** One 409 code carries two meanings.
     `send_classification.dart:25-37` maps **any** `IDEMPOTENCY_CONFLICT` to
     `SendClassification.confirmed` (terminal, never retried), but the backend
     returns that same code for a request **still in flight**, and releases the
     claim when the racing request fails. Result: the app records a fee collection
     as **confirmed** with nothing written to the books. Return a distinct
     `IDEMPOTENCY_IN_FLIGHT` (409) when the claim exists with a NULL payload;
     reserve `IDEMPOTENCY_CONFLICT` for a stored response; classify in-flight as
     `transient` so the outbox retries **with the same key**.
     **Ordering:** the client-only change (classify 409 as `transient` for
     high-risk operations) is safe to ship alone — extra retries are deduped by the
     same key. The contract split ships backend+client together.
  2. **API-113 — one money parser.** `parseFloat(String(raw))` is used as a
     validator: `"100abc"` → `100`, `"1e5"` → `100000`, `"12.999"` accepted at
     sub-paisa precision. The invoice lock, the over-collection guard and the
     day-close guard all operate on whatever number it produced. One shared parser
     rejecting anything that is not a canonical ≤2-decimal amount, bounded, applied
     to every money field. **Audit the client DTOs first** — a stricter parser may
     reject payloads that currently work.
  3. **E2E-010 — cash in the register is not money.** `createOfflinePayment`
     hard-codes `pending_reconciliation` for **every** method, including `Cash`,
     which is first in the dropdown and has no clearance event. The cashier sees
     *"Offline payment recorded."*; no collection is posted, no receipt exists, the
     invoice outstanding is unchanged and the parent still owes the full amount.
     Remove `Cash` from this dialog and route it to the counter collection dialog
     (which posts immediately); make the success copy state the actual effect.
  4. **API-120/121/122/123** — idempotent confirm response; forward the
     `Idempotency-Key` on confirm; reject a webhook with no event id rather than
     minting a random dedupe key; add a natural-key duplicate check on
     (invoice, amount, method) — **ICA-A2 already added exactly this backstop for
     offline instruments** (`finance_collections_offline_payment_uq`); the counter
     path has none.
- **Files.** `lib/core/reliability/sync/send_classification.dart:25-37` ·
  `_shared/idempotency_dispatch.ts` · `_shared/entity_write/module_write_handlers.ts:84-92` ·
  `_shared/finance/finance_collections_handlers.ts:127-132` ·
  `_shared/finance/finance_collections_repository.ts:432-476,451-469,531-560` ·
  `_shared/finance/finance_offline_payments_repository.ts:14-20` ·
  `lib/features/finance/payments/finance_offline_payments_screen.dart:308-317,400-408` ·
  `_shared/payment/payment_service.ts:245-302` · `_shared/payment/payment_handlers.ts:57-138,230`.
- **Blast radius.** Every finance write and the whole generic entity-write surface
  (which shares the 409 shape).
- **Regression risk.** Medium for API-113 (stricter parsing) and API-123 (a
  legitimate second identical payment — two instalments of the same amount on one
  day — **must remain possible**). Low for the rest.
- **Verification (fails today).** A race test: request A claims the key and fails;
  request B receives the in-flight 409; assert the outbox status is **not**
  `confirmed`. Plus parser table tests (`"100abc"`, `"1e5"`, `"12.999"` → 422) and
  a cash test asserting a collection row exists after recording cash. All fail today.
- **Dependencies.** API-123 must follow API-119.
- **Effort.** M–L.

---

### W1.10 — Three write paths that cannot complete at all

- **Root cause:** residual — data integrity.
- **Defects closed:** **E2E-019** (P0), **XMOD-008** (P0), **API-114**.
- **The change.** Each is small and each blocks a module's primary write:
  - **E2E-019** — `ApiInventoryRepository.createProcurementOrder` sends
    `'vendorId': request.vendorName.trim()` where a UUID FK is required, discarding
    the `vendorId` the dialog **did** capture. Postgres rejects with 22P02 and the
    handler's catch maps only `PO_LINES_REQUIRED`, so it surfaces as an unmapped
    500. Send `request.vendorId`; map 22P02/FK violations to 422.
  - **XMOD-008** — `certificate_type` includes `'fee'` in code and in the *request*
    table's CHECK, but the **issues** table's CHECK allows only four values and no
    later migration alters it. One migration widening the CHECK; map 23514 to a
    structured 422 rather than a 500.
  - **API-114** — `maxMarks: Number(...) || 100`. `0` is falsy and silently becomes
    a 100-mark exam; `-50` is stored (no positivity CHECK) and then **every**
    subsequent mark entry fails at the database, permanently. Require a positive
    integer (422) and add `CHECK (max_marks > 0)`.
- **Files.** `lib/core/repositories/api/inventory/api_inventory_repository.dart:143` ·
  `supabase/migrations/20260849000000_sis_certificates.sql:33-34` ·
  `_shared/sis/sis_certificate_handlers.ts:155-156` ·
  `_shared/academics/exam_administration/exam_administration_handlers.ts:458` ·
  `supabase/migrations/20260618120000_f4_exam_sessions.sql:16`.
- **Blast radius.** Unblocks goods receipt, the AP commitment and inventory→finance
  reconciliation, all of which consume the PO.
- **Regression risk.** Low. The `max_marks` CHECK needs a scan for existing bad rows.
- **Verification (fails today).** A PO-creation integration test; a
  `certificate_type: 'fee'` issue test; `maxMarks` table tests for `0`, `-50`, `1.5`.
  All fail today.
- **Effort.** S.

---

### W1.11 — Audit becomes transactional

- **Root cause:** residual — data integrity (RC-adjacent: the guarantee the product
  claims cannot be delivered by the architecture it has).
- **Defects closed:** **OS-007** (P0, priority candidate). **Unblocks:** OS-008.
- **The change.** `runTenant` issues no `BEGIN`/`COMMIT`; only 15 files in the whole
  backend touch `savepoint`. `emitMutationAudit` is a separate awaited statement
  **after** the mutation at **all 305 call sites**. So when the audit insert fails:
  the mutation has already committed, no audit row exists, **and the caller receives
  a 500 telling them it failed** — three wrong outcomes at once, and the operator
  will do it again. The RC phase's stated guarantee that the attendance-correction
  path audits *"in-transaction with real before→after"* **cannot hold, because
  there are no transactions.**
  Wrap mutation + audit in one transaction in `runTenant`, or make the audit write a
  deferred outbox row inside the same statement. The catalog and the writer are
  good; only the boundary is wrong.
- **Files.** `supabase/functions/_shared/tenant_db.ts` ·
  `_shared/audit/mutation_audit_catalog.ts:15` ·
  `_shared/audit/audit_repository.ts:283,380` ·
  `_shared/finance/finance_collections_handlers.ts:398-408` (the exemplar).
- **Blast radius.** **The shared DB entry point for every handler in the product.**
  This is the widest-blast item in Phase 1.
- **Regression risk. Medium-high.** Requires a full backend regression run, and
  care that long-running handlers do not hold transactions open. Schedule it as its
  own release with nothing else in it.
- **Verification (fails today).** A fault-injection test: force the audit insert to
  fail and assert the mutation is **rolled back** and the caller's 500 is
  truthful. This test **cannot be written today** — there is no transaction to roll
  back — which is itself the finding.
- **Dependencies.** None, but it is a prerequisite for trusting any audit-based
  claim, including every claim W1.12 makes.
- **Effort.** L.

---

### W1.12 — Identity comes from the token, never from the body

- **Root cause:** RC-4 (the gate is documentation, not enforcement).
- **Defects closed:** **E2E-003**, **API-110**, **API-112**, **XMOD-006** (P0).
- **The change.** Four places where the product trusts the caller for who they are
  or what they may still see:
  - **E2E-003** — `POST /attendance/corrections` reads `requesterId`,
    `requesterName` and `requesterRole` straight from the request body, persists
    them, renders them to the approver as *"By {requesterName} ({requesterRole})"*
    and copies them into the `correctionRequested` audit event. **The approval card
    and the forensic trail can both name someone who did not file the request.**
    The *parent* route already does this correctly and documents why. Pin
    `requesterId = claims.sub`, role to the caller's role, name server-resolved.
    Same file: `markToDb` maps **any** unrecognised mark string to `"present"` —
    reject instead.
  - **API-110** — `POST /approvals/audit` inserts a caller-supplied `actorId`/
    `actorName` while `auth.claims.sub` sits available and ignored. Derive from the
    session; validate `action` against the enum (422, not 500); consider deleting
    the route — no client calls it.
  - **API-112** — `handleBatchDecideApprovals` sets `const actorName = "Approver";`
    so every human-readable approval report is wrong for batch decisions.
  - **XMOD-006 (P0)** — `resolveParentContext` selects the student row but **never
    filters on `status`**, so a parent keeps full portal access to a child who has
    left. The sibling `resolveStudentContext` **does** `.eq("status","active")`, so
    the student loses access while the parent does not. Add the filter. Separately,
    allow last-guardian deactivation when the student is not active — today
    `LastGuardianError` means the only parent of a departed student **cannot be
    de-authorized through the API at all**.
- **Files.** `_shared/attendance/attendance_handlers.ts:400-403` (vs the correct
  `:472-475`), `:427-445` · `_shared/attendance/attendance_correction_repository.ts:47-54` ·
  `_shared/approval/approval_handlers.ts:596-597,675-720` ·
  `_shared/auth_context.ts:268-274,300,335-339` ·
  `_shared/sis/sis_guardians_repository.ts:164,168`.
- **Blast radius.** The approval audit trail and every parent session.
- **Regression risk.** Medium for XMOD-006 — a status typo or an over-broad filter
  locks legitimate parents out. Extend
  `_shared/guardian_active_link_rls_guard_test.ts` to cover **student** status, not
  only link status.
- **Verification (fails today).** (a) A handler test posting a correction with a
  forged `requesterId` and asserting the persisted row carries `claims.sub`.
  (b) A parent-context test asserting a transferred child is absent from `childIds`.
  Both fail today.
- **Dependencies.** Benefits from W1.11 (an audit assertion is only as good as its
  transaction).
- **Effort.** S–M.

---

### W1.13 — Stop returning raw exceptions; bound free text; fix CORS

- **Root cause:** residual — security.
- **Defects closed:** **API-117**, **API-115**, **API-109**.
- **The change.** Twelve handlers put the exception string in the response body; a
  `deno-postgres` error stringifies to the driver message, carrying the failing SQL
  fragment plus table, column and constraint names. **`auth_handlers.ts:345` is the
  worst case** — it returns the Supabase insert error's message verbatim on the
  **pre-authentication OTP request path**, i.e. to an anonymous caller. Delete the
  local catches and let the exception reach the central handler
  (`api/app.ts:363-380`, which is correct), or replace the message with a constant;
  add a lint banning `String(error)` / raw `error.message` inside a 5xx
  `errorEnvelope`. The ~120 other `error.message` uses are on **typed domain
  errors** with author-written messages and are correct — do not sweep those.
  Add a shared `boundedStr(body, key, max)` at the handler boundary plus
  `CHECK (char_length(col) <= n)` on high-traffic text columns — today the ASIP
  support tables are the only place in the product with length limits, and a single
  request can persist a multi-megabyte value that is then rendered into a receipt,
  a report and a PDF. Add `DELETE` to `Access-Control-Allow-Methods` (the API
  serves `DELETE` routes the web app cannot issue) and replace `*` with an origin
  allowlist.
- **Files.** `widget_platform_handlers.ts:45,68,105,130,156` ·
  `widget_layout_handlers.ts:101` · `setup_wizard_handlers.ts:73,105,163` ·
  `platform_providers_handlers.ts:51,58` · `control_center_write_handlers.ts:33` ·
  `school_calendar_handlers.ts:45` · `copilot_handlers.ts:69` ·
  **`auth_handlers.ts:345`** · `tenant_handlers.ts:98` · `platform_db.ts:196` ·
  `supabase/functions/api/app.ts:30-35`.
- **Blast radius.** Error envelopes only.
- **Regression risk.** Low. Pick generous length limits so real data is not rejected.
- **Verification (fails today).** A lint test that no `errorEnvelope(..., 5xx)`
  argument derives from `String(error)` or `error.message` on an untyped catch.
  Fails today at thirteen sites.
- **Effort.** S–M.

---

### W1.14 — The two parent-facing exam falsehoods (narrow predicate now, full convergence in Phase 2)

- **Root cause:** RC-5 — but the **P0 half is separable and must not wait**.
- **Defects closed:** **XMOD-005** (P0), **XMOD-009** (P0), and the one-line crash
  guard inside **OS-004** (P0). **Unblocks:** XMOD-029, XMOD-032, OS-003, OS-004
  (full) in Phase 2.
- **The change.** Three narrow edits, each strictly narrowing behaviour:
  1. Add `AND published = true` and a present-status filter to the **two
     parent-reachable** queries (`parent_experience_service.ts:118-131` →
     `weakTopics`; `student_360_service.ts:117-125` → `recentExams`). Today a
     scheduled, unmarked, unpublished exam appears in the parent app at **0%** and
     is listed among the child's "weak topics".
  2. Change `provisionMarkSlots` to insert `marks_obtained = NULL` rather than `0`
     (XMOD-032's mechanism), so an un-marked paper stops reading as a genuine zero.
     Backfill already-provisioned slots.
  3. Apply `countsTowardStats` in the **parent** report-card path
     (`exam_report_card.dart:166-168`) — the **admin** card in the *same file*
     filters correctly at `:222-227` — and carry the AB/ML/DB status code through
     the parent overlay so the client can distinguish 0 from Absent. Today the
     absent subject contributes 0 obtained **and its full `maxScore` to the
     denominator**, depressing the child's percentage and grade.
  4. Add the missing `maxScore == 0` guard at
     `lib/features/parent/exams/exam_models.dart:57` — `0/0 → NaN.round() →
     UnsupportedError`, **the parent app throws**. Line 99 of the same file already
     guards. This is a one-line release-blocker.
  **Extract the published+present predicate as a shared SQL fragment in this item**,
  so Phase 2 adopts it at the remaining five sites rather than re-deriving it.
- **Files.** `_shared/parent/parent_experience_service.ts:118-131,176-179,209` ·
  `_shared/sis/student_360_service.ts:117-125,305-307` ·
  `_shared/academics/exam_administration/exam_administration_repository.ts:434,439-440` ·
  `lib/core/exams/exam_report_card.dart:166-168` ·
  `_shared/pilot/pilot_snapshot_repository.ts:860` ·
  `lib/features/parent/exams/exam_models.dart:57`.
- **Blast radius.** Parent-facing exam surfaces only in this phase.
- **Regression risk.** Low — all four changes are strictly narrower or additive.
  The NULL provisioning needs a nullable-column migration plus a backfill.
- **Verification (fails today).** (a) A parent-feed test: schedule an unpublished
  exam with no marks, assert it is absent from `weakTopics` and `recentExams`.
  (b) A report-card test: one AB subject, assert the denominator excludes its
  `maxScore`. (c) `examPercent(0, 0)` does not throw. All three fail today.
- **Dependencies.** None. Feeds Phase 2 W2.4.
- **Effort.** M.

---

### W1.15 — A departed student cannot block a class's attendance

- **Root cause:** residual — a core daily workflow that cannot complete.
- **Defects closed:** **XMOD-007** (P0), narrow half. **Full fix in Phase 3 W3.4.**
- **The change.** Two rosters disagree. The **display** roster filters
  `AND s.status = 'active'`; the **submit validator** `activeRosterStudentIds`
  filters only `e.is_current = true` with no `students` join, so it still expects a
  mark for a child who is no longer in the list — and throws
  `AttendanceRosterMismatchError`. The teacher cannot take attendance for that class
  **at all**, and has no way to fix it. Nothing on any exit path sets
  `is_current = false`.
  Add the `students.status='active'` join to `activeRosterStudentIds` so the two
  rosters share one definition. That alone unblocks the teacher. **Closing the
  enrolment on exit (XMOD-022) is the correct root fix and belongs in Phase 3** —
  `is_current` is load-bearing for year rollover and must not double-close a student
  being re-enrolled.
- **Files.** `_shared/pilot/pilot_attendance_repository.ts:167-178,240-247,556`.
- **Blast radius.** One validator; it narrows an over-strict check.
- **Regression risk.** Low.
- **Verification (fails today).** Transfer a student out of a class, submit that
  class's attendance for the next day, assert 2xx. Fails today.
- **Effort.** S.

---

### W1.18 — An attendance correction changes the day it names

- **Root cause:** RC-3. Phase 1 by owner scope (data integrity + a core daily
  workflow that cannot complete).
- **Defects closed:** **E2E-004** (P0), **E2E-006**, **E2E-007**, **E2E-001**, and
  the date half of **E2E-002** (opened in W1.2).
- **The change.** `applyAttendanceCorrection` targets *"the session matching
  `attendance_corrections.session_date`, or — when that is NULL — the most recent
  submitted session"*. **`session_date` is never written by anything**: the INSERT
  column list omits it, no UPDATE sets it, a repo-wide grep finds no writer. So the
  NULL branch is the **only** branch that ever runs and **every correction lands on
  the latest submitted session** — a parent disputes 3 June, the principal approves,
  and **today's** mark changes. The date the teacher typed survives in `date_label`,
  on the approver's card **and in the audit event**, so the audit asserts a date the
  write did not use.
  The same gap has a second face: `upsertAttendanceSession` matches and inserts on
  `session_date = CURRENT_DATE` only and the submit request carries no date, so
  **there is no way to enter attendance for a past day at all**. A teacher out sick
  on Monday cannot enter Monday's register on Tuesday — and the correction workflow,
  the obvious workaround, silently edits Tuesday instead.
  Parse the correction's date into `session_date` at create time (reject an
  unparseable or out-of-year date, 422) and **require it**; then the existing query
  works as written. Accept an explicit `sessionDate` on
  `/teacher/attendance/submit`, bounded to a configurable back-window and blocked
  past a closed period. Carry the UPDATE's **affected-row count** into the approval
  effect payload and the audit event and render it (E2E-007) — today the count is
  computed, `console.warn`ed and discarded, and the approval reports success while
  the attendance is unchanged; *a server log is not a surface any school user has*.
  Make `PATCH /attendance/corrections/:id/status` delegate to
  `applyAttendanceCorrection` for `approved`, or restrict it to
  `rejected`/`cancelled`, and validate `status` against the four allowed values
  (E2E-006) — no client calls it today, so the change is safe.
  Finally, stop reporting a failed write as a data-entry mistake (E2E-001):
  `submitAttendance` returns `false` for **both** `unmarkedCount > 0` and
  `result == null`, so a roster mismatch, a holiday block, a co-teacher's lock or a
  401 all surface as **"Mark all students before submitting."** — on a grid that is
  already fully marked. Return a result type so the screen can show
  `aksharaErrorMessage(error)`; the backend already returns precise mapped errors
  and **none of them reach the teacher**.
- **Files.** `_shared/attendance/attendance_correction_repository.ts:157-181,231-262,276-291` ·
  `supabase/migrations/20260618130000_f5_attendance_corrections.sql:13` ·
  `_shared/pilot/pilot_attendance_repository.ts:57-62,84-95` ·
  `_shared/attendance/attendance_handlers.ts:519-593` ·
  `_shared/approval/approval_type_handlers.ts:141-166` ·
  `lib/features/teacher/attendance/teacher_attendance_provider.dart:206-229` ·
  `lib/features/teacher/attendance/teacher_attendance_screen.dart:462-479` ·
  `lib/features/teacher/attendance/teacher_attendance_workflow.dart:31-34`.
- **Blast radius.** Which row an approval mutates.
- **Regression risk. Medium.** Needs a migration to backfill or **annul**
  `session_date` on existing correction rows so historic corrections are not
  re-interpreted against the new branch. Annulling (marking them
  non-reapplicable) is the safer default.
- **Verification (fails today).** File a correction for 3 June, approve it, assert
  3 June's record changed **and today's did not**; and assert a correction matching
  no record returns a failure the approver can see. Both fail today.
- **Dependencies.** W1.2 supplies the date picker that produces a parseable value.
- **Effort.** M.

---

### W1.16 — Make the RBAC inventory a generated artefact and the suite a dispatcher

- **Root cause:** RC-4. **This is the single change that eliminates the class.**
- **Defects closed:** **API-100**, **API-101**, **API-102**, **API-103**,
  **API-104**, **OS-013**, **API-111** (7).
- **The change.** The inventory is a hand-maintained data file with no code-derived
  source and no test comparing it to the routers — **adding a route does not require
  touching it** — and the RBAC suite iterates the inventory and calls the *pure
  function* `requirePermission(claims, rule.permission)`. Neither test constructs a
  `Request`, calls `matchModuleRoute`, or invokes a handler. **So a route added with
  no gate passes the entire RBAC suite by simply not being listed** — and 97
  mutating routes are not listed, including `POST /finance/collections`,
  `/finance/refunds`, `/finance/day-close`, every `/approvals/:id/{approve,reject,cancel}`,
  all 26 `POST /school/*` writes and every `/academics/exams/*` mark write. In the
  other direction 91 rules describe routes that no longer exist — including
  `PUT /teacher/exams/marks/:id`, **deleted by PRA-P0-12 because it shadowed the
  governed route**, while the governed replacement is absent. Anyone consulting the
  inventory to answer "what gates a mark change?" reads a rule for a route that does
  not exist.
  Two moves, in this order:
  1. **Derive the route list mechanically.** Export a `(method, path, handler)`
     table from each router — `MODULE_ROUTES` already does this for prefixes — and
     fail the build when a mutating route has no inventory rule, when a rule has no
     route, and when a registered prefix has no inventory entry (OS-013: ten
     prefixes are outside the guard, `attendance` among them). Add
     `"/domain-events/process-pending"` to the `audit` prefix entry (API-104) and a
     guard test that every literal path a router accepts is covered by one of its
     declared prefixes.
  2. **Drive the matrix through the dispatcher.** Run `routeModuleRequest` with a
     synthetic `Request` and a claims fixture; assert **403 for a non-holder and
     non-403 for a holder** on every mutating route. The existing spy-DB harness is
     sufficient for status-code assertions. Keep the pure-function tests as unit
     coverage of `requirePermission`.
  The backfill of the 97 will surface genuine gate disagreements. **That is the
  point, not a side effect** — API-111 is one of them, found by hand: `viewPayments`
  appears **only** in the inventory; `handleGetPaymentIntent` never calls
  `requirePermission`, so any school-scope session (a teacher, a librarian, a
  transport clerk) can read any payment intent in its school by id. Of 96 permission
  slugs, it is the only one enforced nowhere — the other 95 are real, which is what
  makes the gap invisible.
- **Files.** `_shared/validation/rbac_route_inventory.ts` (315 rules) ·
  `_shared/validation/rbac_route_validation_test.ts:86-100` ·
  `_shared/validation/rbac_full_matrix_test.ts:31-70` ·
  `_shared/route_registry.ts:119,176-184,231` ·
  `_shared/attendance/attendance_router.ts:17-77` (11 routes, 1 rule) ·
  `_shared/payment/payment_handlers.ts:140-152`.
- **Blast radius.** CI, plus every route whose backfilled gate turns out to differ
  from what the handler enforces.
- **Regression risk.** Low for the generation and the tests (additive). **Medium
  for the backfill**, precisely because it will refuse routes that are open today.
  Land the generator + failing report first, triage the 97, then enforce.
- **Verification (fails today).** The generated diff itself: a test asserting
  `|routes_missing_from_inventory| == 0` and `|rules_without_routes| == 0`. It
  reports **97** and **91** today. Plus a dispatcher test that a non-holder gets 403
  on `POST /finance/collections` — impossible to express today because the suite
  never dispatches.
- **Dependencies.** API-101 needs API-100's complete route list to be meaningful.
- **Effort.** L.

---

### W1.17 — Authorise before you validate

- **Root cause:** RC-4.
- **Defects closed:** **API-118**, **API-116**.
- **The change.** Five attendance routes parse and reject query parameters
  **before** calling `withAuth`, so an unauthorised caller is told the parameter
  contract instead of being refused — live, unauthenticated:
  `GET /attendance/register/monthly` → **422 `classLabel is required`**. And because
  `api/app.ts` records the access-denied audit event by observing
  `response.status === 403` **centrally**, no audit row is written for these
  denials at all. Authenticate and authorise first, then validate; if the early
  parameter rejection is worth keeping, do it inside `withAuth` after the permission
  check.
  Alongside it, add the `school_id` bind to the 30 repository reads that restate
  only `organization_id` and rely on RLS alone (API-116). Isolation holds **today** —
  the matching RLS policies were read and they do restate
  `school_id = app_current_school_id()`, and the live pilot confirms
  `role: erp_tenant`, `bypassRls: false`. The risk is structural: any future path
  running one of these under `createServiceClient` reads across every school in the
  organization **with no second barrier**. Add a lint that a query touching a
  school-scoped table binds both. Check each for a legitimate org-scope caller —
  the director module genuinely needs the org view.
- **Files.** `_shared/attendance/attendance_handlers.ts:205-300` ·
  `supabase/functions/api/app.ts:341-352` ·
  `audit_repository.ts:107`, `finance_collections_repository.ts:398`,
  `payment_repository.ts:78,121`, and the full table in
  `docs/certification/findings/API-certification.md` §5.1.
- **Blast radius.** Five routes plus 30 reads.
- **Regression risk.** Low.
- **Verification (fails today).** Call each of the five routes with a missing
  required parameter as a **non-holder**; assert 403 and an access-denied audit row.
  Returns 422 and no audit row today.
- **Dependencies.** Same five routes as API-103 (W1.16).
- **Effort.** M.

---

### Phase 1 exit gate

1. Every W1.x verification test **exists, is in CI, and would have failed before
   the change**. A wave with a passing test that could also have passed before it
   is not finished.
2. The four RC-1 lints are live: no `.mock()` in `lib/`; no const stat tables;
   no literal-id maps in route builders; no seeded production `TextEditingController`.
3. Goldens re-baselined **once**, at the end of the phase.
4. Full backend regression after W1.11 (transactional audit), run alone.
5. §8 owner items acknowledged and tracked — **not** counted as closed.

---

## 4. PHASE 2 — canonical shared state · academic-year resolver · student count · grading · finance totals

**The premise.** Canonical shared state in this product is the **exception**: 1 of
13 cross-module quantities (attendance-%, whose own header records it as a one-off
remediation). Everything in Phase 2 is the same move, applied to the other twelve:
**one definition, in one place, with a paired SQL fragment, and a test that fails
when a second definition appears.** `attendance_percentage.ts` is the proof that
this works in this codebase — every item below is instructed to copy its shape.

**Exit criterion:** every quantity in the canonical registry (W2.8) has exactly one
producer, and a test fails on the appearance of a second.

**Do not wire anything new on top of these until they are done.** Phase 3 depends on
Phase 2 for the same reason a schedule depends on a calendar.

---

### W2.1 — An academic-year/term resolver, and a context that carries it

- **Root cause:** RC-3. **Foundational — schedule it first in the phase.**
- **Defects closed:** **OS-006**, **OS-017**, **JOURNEY-009**, **WIDGET-009**.
  **Unblocks:** OS-002 (needs an as-of date), E2E-014, E2E-020, W2.5.
- **The change.** There is **no academic-year resolver at all**. 66 hard-coded
  literals across `lib/` — **31 with an ASCII hyphen (`2026-27`) and 29 with an
  en-dash (`2026–27`)** — compared by string equality, so **Finance's year and SIS's
  year are literally different strings for the same year**. Rolling to FY 2027-28
  requires a code change in 66 places. The backend **has** the source of truth
  (`academic_years.is_current`, `academic_years_repository.ts:118-119`) and nothing
  in `lib/` reads it.
  Add `academicYearId` and `termId` to `TenantContext`
  (`tenant_context.dart:7-18`, which today carries only tenant/school/org/user),
  seeded from `academic_years.is_current` at session bootstrap; delete the 66
  literals; **normalise the dash at the codec boundary** so the two spellings can
  never diverge again.
  Then make it propagate. `activeWorkspaceProvider` is read by **exactly four files
  outside its own directory and zero feature modules**; class context is private to
  `lib/features/teacher/attendance/`; academic year has no global provider at all.
  The one thing that *does* propagate is `repositoryQueryProvider` — read by **173
  files**. **Use that as the vehicle**: extend it to carry workspace, academic year,
  term and (optionally) selected class. That is a change to one provider that 173
  files already watch, not 173 changes.
  With the resolver in place, JOURNEY-009 and WIDGET-009 are deletions: the
  Management chips `['FY 2026-27','Q1','All quarters']` become derived, which also
  fixes the Copilot context — the assistant is currently **told the period is
  "FY 2026-27" regardless of the real year** (`management_dashboard_screen.dart:140`).
- **Files.** `lib/core/tenant/tenant_context.dart:7-18` ·
  `lib/core/tenant/tenant_provider.dart:41-43,46` ·
  `lib/core/workspace/workspace_providers.dart:8-34` ·
  `finance/fee_structures/finance_fee_structures_provider.dart:14` ·
  `sis/academic_assignment/sis_academic_assignment_screen.dart:44` ·
  `admissions/admissions_models.dart:609` · `finance/finance_workflow_actions.dart:194` ·
  `school_completion/substitute_manager_screen.dart:27` ·
  `school_completion/teacher_reassignment_screen.dart:25` (`academicYearId = 'year_1'`) ·
  `management/dashboard/management_dashboard_screen.dart:32-36,140` ·
  `_shared/academic/academic_years_repository.ts:118-119`.
- **Blast radius.** 66 sites, mechanically; then the fetch scope of every module
  that starts receiving a year.
- **Regression risk.** **Medium.** The danger is not the 66 edits, it is
  **narrowing** — a module that previously fetched year-agnostically and now filters
  by the current year will appear to lose historical data. Ship the context first
  with modules still ignoring it, then adopt module by module.
- **Verification (fails today).** (a) A test asserting **zero** academic-year string
  literals matching `20\d\d[-–]\d\d` anywhere under `lib/` outside test fixtures —
  reports 66 today. (b) A codec test asserting both dash spellings normalise to one
  value. (c) A bootstrap test asserting `TenantContext.academicYearId` is non-null
  after session start and equals `academic_years.is_current`.
- **Dependencies.** None. Blocks W2.2, W2.5 and Phase 3's reminder work.
- **Effort.** L.

---

### W2.2 — One canonical active-student count — and the billing meter uses it

- **Root cause:** RC-5.
- **Defects closed:** **OS-002** (P0), **XMOD-026**.
- **The change.** Four structurally different definitions of "how many students",
  and **the entitlement seat check — the paid licence slab — uses the one with no
  status filter at all** (`entitlements/entitlement_limits.ts:121`). So **alumni and
  transferred students count against the school's paid licence**, and a principal is
  shown a different roll number depending on which screen they open. One file,
  `sis_dashboard_repository.ts`, uses two of the four definitions three lines apart
  (`:102` and `:105`).
  Compounding it, `sis_enum_codec.dart:31` maps
  **`SisStudentStatus.prospect => 'active'`**, so unenrolled prospects are written to
  the server as active students and inflate **every** count above, including the
  seat count. Three status vocabularies exist; the backend codec is disciplined, the
  client codec is not.
  One `countActiveStudents(schoolId, asOf)` in `_shared/`, defined against
  `sis_student_enrollments.is_current`, called by all four surfaces **and by
  entitlements**. Fix the prospect→active client mapping. In the same item, derive
  `sections.strength` (XMOD-026) — a stored integer written only from the section
  create/update request body, with **zero** increment/decrement writers anywhere,
  showing whatever a human last typed — as a `COUNT(*)` over current enrolments,
  which `sis_dashboard_repository.ts:101-108` already does correctly.
- **Files.** `_shared/entitlements/entitlement_limits.ts:121` ·
  `_shared/analytics/analytics_metrics_service.ts:15,19` ·
  `_shared/copilot/copilot_context_engine.ts:192,197` ·
  `_shared/sis/sis_dashboard_repository.ts:102,105,113` ·
  `_shared/director/director_repository.ts:118,324,338,734` ·
  `_shared/management/management_aggregate_repository.ts:341` ·
  `_shared/finance/finance_dashboard_repository.ts:62-65` ·
  `lib/core/repositories/api/sis/dto/sis_enum_codec.dart:31` ·
  `_shared/academic/academic_handlers.ts:552,592`,
  `_shared/academic/sections_repository.ts:229,269`.
- **Blast radius.** Every headcount surface, **and a billed quantity**.
- **Regression risk. Medium — this changes what a school is charged.**
- **⚠ OWNER DECISION (not engineering).** Whether the corrected seat count is
  applied **retroactively** to existing subscriptions is an owner call. Do not make
  it in code. See §7.
- **Verification (fails today).** A fixture school with 100 active, 20 transferred
  and 10 prospect students: assert **all four** surfaces and the entitlement meter
  return **100**. Today they return four different numbers and the meter returns 130.
- **Dependencies.** W2.1 (an as-of date needs a year resolver).
- **Effort.** M.

---

### W2.3 — One grading service, on the server

- **Root cause:** RC-5.
- **Defects closed:** **OS-003** (P0), **XMOD-030**, **E2E-015**, **E2E-016**.
- **The change.** **A 35% student is `F` on the server and `D` on the report card** —
  two rival "defaults", each documented in its own source as *"identical to the
  legacy fixed grading"*: `DEFAULT_GRADE_BANDS` (7 bands, `>=40 D, >=0 F`) and
  `ExamGradingScale.standard` (6 bands, `>=50 C, >=0 D`). Flutter additionally ships
  three presets — `cbseScholastic`, `stateBoardSsc`, `percentageDivision` — with **no
  backend counterpart**, so a school on the State Board preset gets client grades the
  server can never reproduce. Inside Flutter the lookup forks again: admin paths read
  `store.reportSettings.gradingScale` while the **parent/student** card hardcodes
  `ExamGradingScale.standard` (`exam_report_card.dart:179`). And `stateBoardSsc` is
  referenced only by its own declaration and the presets list — **no screen can
  select it.**
  Meanwhile the setting never leaves the device: `ExamReportSettingsNotifier` reads
  and writes only an in-memory singleton, and **no code in `lib/` calls
  `/academics/exams/grade-scale`** even though the backend implements `GET` and `PUT`
  and writes an audit row on save. So a principal's scale change is invisible to
  every other device and user and never audited. `examReportSettingsProvider` is
  additionally **declared twice under the same name** in two files; the reports
  screen imports the dependency-free `Provider`, which reads the singleton once and
  caches it for the app's lifetime.
  **One grading service on the server; the client renders what it is given.** Move
  the three presets server-side keyed to school config; have the client consume the
  server-resolved `grade_letter` that publish already bakes in
  (`exam_administration_repository.ts:966-971`) and **delete the client-side scale**.
  Back the notifier with `GET`/`PUT /academics/exams/grade-scale`. Delete the
  duplicate provider. Carry the school's scale, `rank` and `rankShown` on the
  published-results response — `rankShown` is hard-coded `false` today, so the
  school's `showRankToParents` setting has no effect on any surface.
- **Files.** `_shared/academics/exam_administration/exam_administration_repository.ts:200-224,966-971` ·
  `lib/core/exams/exam_grading.dart:37-42,47-55,60-115` ·
  `lib/core/exams/exam_report_card.dart:137-141,176-182,227` ·
  `lib/features/academics/exam_admin/exam_settings_provider.dart:14-37` ·
  `lib/features/academics/exam_admin/exam_reports_provider.dart:116-118` ·
  `_shared/academics/exam_administration/exam_administration_handlers.ts:1207-1290`.
- **Blast radius.** **Every issued grade**, on documents parents keep and show to
  the next school.
- **Regression risk. Medium-high.** Grades change wherever the school is not on
  `standard`. **Needs an owner decision on results already published** — reissue,
  or freeze historical report cards to the scale in force at publish time. The
  second is safer and is the recommendation.
- **Verification (fails today).** A table test over 0–100 asserting the server's
  letter and the client's letter are **identical at every percentage**, for each of
  the four scales. Fails today at 35% (and across the whole 40–50 band).
- **Dependencies.** None.
- **Effort.** L.

---

### W2.4 — One exam-percentage helper and one published+present predicate

- **Root cause:** RC-5.
- **Defects closed:** **OS-004** (P0, remainder after W1.14's crash guard),
  **XMOD-029**, **XMOD-032** (remainder).
- **The change.** There is **no shared percentage helper anywhere**, and the same
  percentage is computed with **three different rounding rules**: the backend passes
  a raw double at five sites, rounds to 2dp via `Math.round(p*100)/100` at two, and
  via `Math.round(x*10000)/100` at two more; Flutter uses integer `.round()` at two,
  raw doubles at three, 2dp at one and raw at three more. 24 inline sites total.
  One `examPercent(score, maxScore)` returning **nullable**, in a shared module with
  a **paired SQL definition** — exactly the shape `attendance_percentage.ts` already
  proves works in this codebase.
  Then adopt W1.14's published+present SQL fragment at the remaining five aggregate
  surfaces, which today omit **both** filters:
  `management_aggregate_repository.ts:182,191,213,222` (a `COUNT(*)` denominator that
  includes AB/ML/DB), `director_repository.ts:164-166,760-765`,
  `exam_intelligence_service.ts:96-101` (`total_marks = count(*)`),
  `analytics_metrics_service.ts:33-38` (counts unentered zeros as failures).
  **The correct behaviour already exists three times over** — tabulation
  (`exam_administration_repository.ts:1436-1505`), the backend report card
  (`:2340-2394`) and the Flutter admin card (`exam_report_card.dart:222-227`). This
  item is convergence, not invention.
- **Files.** as listed, plus `lib/features/parent/exams/exam_models.dart:57,99` ·
  `lib/core/exams/exam_report_card.dart:34,103,168,226,308` ·
  `lib/core/exams/exam_administration_store.dart:1279` ·
  `lib/features/.../exam_reports.dart:258,311,360`.
- **Blast radius.** Reported pass rates and class averages will **move**. That is the
  intended outcome and should be communicated to the pilot school before release,
  not after.
- **Regression risk.** Low-medium.
- **Verification (fails today).** (a) One property test asserting
  `examPercent` agrees between the SQL fragment and the Dart helper across a random
  score/maxScore corpus including `maxScore = 0`. (b) A fixture exam with one AB, one
  unentered and one unpublished component: assert **all seven** surfaces report the
  identical pass rate. Fails today on all seven.
- **Dependencies.** W1.14 (the predicate is extracted there).
- **Effort.** M.

---

### W2.5 — One "collected", one "outstanding dues"

- **Root cause:** RC-5.
- **Defects closed:** **OS-005**, **XMOD-014**, **XMOD-035**, **WIDGET-018**,
  **WIDGET-013**.
- **The change.** Two quantities, both money, both forked:
  - **"Collected"** has three definitions, differing on whether refunded money
    counts: `collection_status = 'completed'` at nine sites;
    `IN ('completed','partially_refunded','refunded')` at four;
    `IN ('completed','partially_refunded')` at one. **`finance_intelligence_service.ts`
    uses two of them 111 lines apart**, so its own collection-rate KPI at `:180` is
    internally inconsistent — and `:180` is itself an inline fork of
    `computeCollectionRate`, which has exactly one production caller.
    One `collectedAmount(scope, window)` with an **explicit, documented refund
    policy**; delete the forked rate calculation.
  - **"Outstanding dues"** has five: the stored
    `finance_student_accounts.outstanding_amount` (used by the **TC no-dues gate**,
    dunning and risk); invoice sum `IN ('issued','partially_paid')` (dashboard);
    invoice rows `NOT IN ('cancelled','draft')` **with `LIMIT 12` and no
    academic-year filter** (the **parent app**); invoice sum `NOT IN ('paid','cancelled')`
    (Student 360); `<> 'cancelled'` (monthly reports). The stored column is
    maintained only by hand-written compensation at each write site — the source
    itself states *"STORED aggregates … nothing re-derives them"* — with **no
    reconciliation job**. One `outstandingDuesSql()` used by all five; add a
    reconciliation check comparing the stored column against the derived sum; remove
    the parent view's `LIMIT 12`.
  Alongside: stop casting `NUMERIC(12,2)` to `::int` on Student 360 (XMOD-035 —
  ₹1,234.56 renders as ₹1,234); relabel or re-source the "At-risk fees" tile, which
  shows a **student count** under a money label beside a percentage tile
  (WIDGET-018); and reconcile the three contradictory alert thresholds — `> 40` on
  two dashboards, `> 20` in the Alert Centre, all absolute counts, so a 200-student
  school with **38 defaulters sees no warning at all** (WIDGET-013). Make the fee
  threshold proportional to enrolment; if absolute counts must stay for v1.0, at
  minimum reduce 20 and 40 to **one** constant.
- **Files.** the fourteen `collected` sites and five `dues` sites enumerated in
  OS-005 and XMOD-014 · `_shared/sis/student_360_service.ts:159-166` ·
  `_shared/finance/finance_invoices_repository.ts:286-311` ·
  `lib/features/management/widgets/management_principal_overview_panel.dart:209-223,282-323` ·
  `lib/features/management/dashboard/management_dashboard_screen.dart:149,156` ·
  `lib/features/finance/dashboard/finance_dashboard_screen.dart:69,76`.
- **Blast radius. High — this is money shown to parents and money that gates a
  school-leaving certificate.** The TC gate reads the stored column; changing the
  definition changes who can get a TC.
- **Regression risk. High.** Pair with XMOD-021 (Phase 3) so the gate's *inputs* and
  its *breadth* are not changed in two separate releases with a gap between them.
- **Verification (fails today).** A fixture student with a part-paid invoice, a
  refunded collection and a cancelled invoice: assert the **five** dues surfaces and
  the **three** collected surfaces each return one value. Fails today with up to five
  and three distinct answers.
- **Dependencies.** W2.1 (the parent view needs an academic-year filter to replace
  `LIMIT 12`).
- **Effort.** L.

---

### W2.6 — The canonical attendance null survives to the screen

- **Root cause:** RC-5.
- **Defects closed:** **XMOD-010** (P0), **OS-001** (P0), **XMOD-020**,
  **XMOD-038**, **WIDGET-017**, **WIDGET-016**.
- **The change.** `attendance_percentage.ts` is the product's **one** canonical
  quantity and its contract is explicit: *"the percentage is `null` — NEVER 0 and
  NEVER 100. Callers display this as —/no data, not as 0%"*. Three client mappers
  independently coerce it — `parent_mapper.dart:394`, `phase5_mapper.dart:150` and
  `student_mapper.dart:221`, all `as int? ?? 0` — so a parent, an ops hub and **a
  student in their own app** are each shown **0%** attendance, a false statement.
  **XMOD-010's recommended fix names only two of the three**; fixing it as written
  leaves the student app lying. That is precisely the instance-not-class failure this
  roadmap exists to avoid: fix all three, and add the contract test.
  Two server-side consumers break the same contract in the other direction:
  `analytics_metrics_service.ts:26-31,98` computes `absent / total` — excused and
  half-day in the denominator, late counted as neither — feeding the risk score and
  the principal's brief; and `parent_experience_service.ts:53` uses
  `canonicalPct ?? 100`, treating **"no data" as perfect attendance** when generating
  parent-facing grade, trend and alert text. Both must call
  `attendancePercentSql()`, as the other eleven consumers already do, and propagate
  null. HR's `Math.round((presentCount / workingDays) * 100)` (XMOD-038) must either
  reuse `attendedFromCounts`/`attendancePercentFromCounts` or **document the
  divergence in the canonical file** so the next reader does not assume it is a bug.
  Client-side: `AksharaProgressRing` must accept a nullable fraction and render an
  indeterminate/greyed state — today `(double.tryParse('$attendance') ?? 0) / 100`
  turns "unknown" into a **completely unfilled ring**, a strong visual assertion of
  near-zero attendance, while the caption honestly reads "—". Never map unknown to 0
  in a gauge. And put **typed** `homeworkPendingCount`/attendance/fee values on
  `ParentDashboardData` (WIDGET-016): the KPI currently counts *summary rows whose id
  mentions homework* (so it shows **1** while the row beneath reads **"2 homework due
  today"**) and derives the attendance and fee cards by **substring-scraping chip
  labels**, so any backend re-wording silently turns them into `'—'`.
  **Presentation strings are not a data source.**
- **Files.** `_shared/attendance/attendance_percentage.ts:24-26,63-113` ·
  `lib/core/repositories/api/parent/mapper/parent_mapper.dart:394` ·
  `lib/core/repositories/api/phase5/phase5_mapper.dart:150` ·
  `lib/core/repositories/api/student/mapper/student_mapper.dart:221` ·
  `_shared/analytics/analytics_metrics_service.ts:26-31,98` ·
  `_shared/parent/parent_experience_service.ts:53` ·
  `_shared/hr/hr_reports_repository.ts:361`, `_shared/hr/hr_read_repository.ts:321` ·
  `lib/features/parent/dashboard/parent_dashboard_screen.dart:295-358,360-481`.
- **Blast radius.** Nullability ripples into every widget consuming these models.
- **Regression risk.** Low-medium. Risk scores and the principal's brief will
  shift — expected, and correct.
- **⚠ Ordering.** XMOD-038 depends on **XMOD-003** (Phase 3): staff attendance % must
  not be recomputed while approved leave still reads as absence. Do the student-side
  work here; hold the HR half until W3.5.
- **Verification (fails today).** A contract test: for every client mapper and every
  server consumer of the canonical value, feed `null` and assert the rendered/returned
  value is the honest-state placeholder — **not** 0 and **not** 100. Fails today at
  five sites.
- **Effort.** M.

---

### W2.7 — The canonical-quantity registry (the guard that stops RC-5 returning)

- **Root cause:** RC-5 — **this is the mechanical guard, and without it Phase 2 is
  twelve patches rather than one fix.**
- **Defects closed:** none directly. **Prevents the recurrence of all 23.**
- **The change.** Create `_shared/canonical/` (mirroring `attendance_percentage.ts`)
  holding one module per cross-module quantity, each exporting a **TypeScript helper
  and a paired SQL fragment**, with a header stating the definition and the decision
  behind it. Register: active student count · collected · outstanding dues · exam
  percentage · grade letter · attendance percentage · pass rate · academic year ·
  term · fiscal year · receipt sequence · defaulter threshold · section strength.
  Then add the test that makes it a gate: a **source-scanning test** that fails when
  a SQL string outside `_shared/canonical/` contains a registered quantity's
  characteristic predicate — `collection_status =`, `outstanding_amount`,
  `status='active'` on `students`, `marks_obtained`, a `20\d\d[-–]\d\d` literal — 
  unless the file is on an explicit, reviewed allowlist. The allowlist is the point:
  a fourteenth definition then requires a **deliberate** entry rather than a
  copy-paste.
- **Blast radius.** CI only.
- **Regression risk.** None. The risk is social — an allowlist that grows without
  review is the same failure in a new costume. Require a reason string per entry.
- **Verification.** The test itself, run against the pre-Phase-2 tree: it must report
  the known counts (5 dues sites, 3 collected, 4 student-count, 24 exam-percentage,
  66 year literals). If it does not, the scanner is wrong, not the tree.
- **Dependencies.** Written first, enforced last — land it reporting-only at the
  start of Phase 2 and flip it to failing at the exit gate.
- **Effort.** M.

---

### Phase 2 exit gate

1. `_shared/canonical/` exists, the scanner is **failing-mode**, and its allowlist
   has a reviewed reason per entry.
2. The five convergence tests (student count, collected, dues, grade letter, exam
   percentage) pass with a **single** value per fixture.
3. Zero academic-year literals under `lib/`.
4. Owner decisions recorded: retroactive seat billing (W2.2), historical report-card
   grades (W2.3).
5. The pilot school is told, before release, that pass rates, class averages and
   collection figures will **change** — because they were wrong.

---

## 5. PHASE 3 — cross-module wiring · notifications · dashboards · integrations

**The premise.** This is where the product stops being 28 modules and starts being
an operating system — or is honestly renamed. Two structural facts frame it:
**nine periodic jobs and three installed crons**, and **a notification rail reaching
9 of ~62 mutating modules**. Nothing here works without W3.1 first.

**Exit criterion:** every state change a human must know about reaches a human, on a
schedule that runs without a person pressing a button; and every control that
implies an effect either has one or has been removed.

---

### W3.1 — A scheduler lane, and something watching it

- **Root cause:** residual — platform. **Hard prerequisite for W3.2, W3.3, W3.9.**
- **Defects closed:** **XMOD-016**, **SIM-001**.
- **The change.** Nine jobs described as periodic are each **a button a human must
  press**: the domain-event drain, late-fee accrual, payroll generate, leave
  accrual, student-risk compute, brief pre-warm, the notification queue drain, the
  parent-summary refresh and the transport document-expiry scan. The installed cron
  set is **three** entries: broadcast sweep, watchdog, nightly backup. The
  `x-internal-cron-token` pattern **exists and works** — it was simply only ever
  installed for one job. Extend the existing communication-cron installer to cover
  each job at an appropriate cadence, reusing the same internal-token auth.
  **Payroll stays manual by design** — do not automate it.
  Then the monitoring half, which is why SIM-001 belongs here rather than in Phase 4.
  The 5-minute broadcast cron is in fact **the only scheduled drain of the entire
  notification queue** (`runScheduledBroadcastsForOrg` → `scheduleNotificationDrain`
  → `processDeliveryQueue`, which claims **every** pending delivery for the org).
  So all parent notification in the product hangs off one cron whose authentication
  **the installer explicitly does not configure** — it *"leaves the cron firing 401s
  (safe — fails closed) until that step is done"*. The fail-closed behaviour is
  correct; **the absence of monitoring is the defect.** Add a watchdog check that
  (a) asserts the last `communication-cron.log` line is `OK` within 15 minutes and
  (b) hits a health endpoint exposing **pending-delivery count and oldest-pending
  age**, alerting above a threshold. Surface those two numbers on the Delivery
  Console so the school can see it too.
- **Files.** `deploy/akshara-vps/communication-cron/install-communication-cron.sh:6-12,26-38` ·
  `akshara-broadcast-cron.sh:29-51` ·
  `deploy/akshara-vps/monitoring/akshara-watchdog.sh:90-108,140-149` ·
  `_shared/communication/communication_cron_auth.ts:1-33` ·
  the nine job routes enumerated in XMOD-016.
- **Blast radius.** Several of these jobs **write money** (late fees) or **send
  parent messages**. Each needs its own idempotency and blast-radius review before
  it is switched on — enable them one at a time, not as a batch.
- **Regression risk.** Medium, entirely because of what the jobs do once they run.
- **⚠ OWNER GATE.** `INTERNAL_CRON_TOKEN` must be set on the `akshara-edge`
  container. Whether it is set on the pilot **could not be verified** (SSH
  owner-bound). Until it is, nothing in this wave has any effect.
- **Verification (fails today).** An ops test asserting every route in the
  "unscheduled jobs" list has a corresponding installed cron entry, plus a watchdog
  test asserting a stale/failing communication-cron log raises an alert. Both fail
  today.
- **Effort.** M (+owner infra).

---

### W3.2 — The domain-event bus actually delivers — **shipped separately, after W3.1**

- **Root cause:** residual — platform. **Governed by §2.2. Read it before starting.**
- **Defects closed:** **XMOD-001** (P0).
- **The change.** Two mutually exclusive statements: `enqueueDomainEvent` inserts
  the row **already terminal** (`VALUES (…, 'published', now())`) while the drain
  selects only `status IN ('pending','failed')`. The drain's result set is therefore
  **structurally always empty**, so `dispatchDomainEvent` never runs. Independently,
  the subscriber registry is **empty** — `registerDomainEventSubscriber` is called
  only from tests. 368 write sites across 171 event types write into a table nothing
  reads.
  Three steps, and **the order is the whole item**:
  1. Register real subscribers (idempotent — delivery is at-least-once by design).
  2. Confirm the drain cron from W3.1 is installed and running.
  3. **Only then** flip the insert to `status='pending', published_at=NULL`.

  Flipping the literal with an empty registry changes nothing but table churn.
  Flipping it **without the cron** strands every event unpublished across 171 types.
  Ship steps 1–2 in one release and step 3 in the next, with the first drain over a
  populated table **watched**, because it may be large.
  Add `"/domain-events/process-pending"` to the `audit` prefix table if W1.16 has
  not already (API-104).
- **Files.** `_shared/audit/audit_repository.ts:365` ·
  `_shared/audit/domain_events_worker.ts:41,73,86` ·
  `_shared/audit/domain_event_subscribers.ts:61-66,70,85` ·
  `_shared/audit/audit_router.ts:27,36`.
- **Blast radius.** 171 event types become drainable at once.
- **Regression risk. Medium-high**, and concentrated entirely in the first drain.
- **Verification (fails today).** Write an event, run the drain, assert
  `processed > 0` and that a registered subscriber received it exactly once under
  duplicate delivery. Returns `processed: 0` today regardless of how many events
  exist.
- **Dependencies.** **W3.1, hard.**
- **Effort.** M.

---

### W3.3 — Notification becomes a declared step of a mutation, not a module

- **Root cause:** residual — the strongest single disproof of "operating system".
- **Defects closed:** **OS-009** (P0, priority candidate), **XMOD-018**,
  **XMOD-019**, **XMOD-023**, **XMOD-013**, **SIM-002**, **SIM-003**, **SIM-004**,
  **CERT-004**, **POLISH-002** (10).
- **The change.** `notification_service.ts` is a well-built rail with **nine callers
  outside `communication/` itself, against roughly 62 mutating modules — ≈15%
  adoption.** `payment` moves money and notifies nobody. `attendance` marks a child
  absent and notifies nobody. `library` records an overdue book and notifies nobody.
  `communication/` is a **peer module other modules mostly do not know exists**, not
  a rail they sit on.
  The root change is structural: **treat enqueue as a first-class step of the
  mutation catalog — the same place `emitMutationAudit` already sits — so a module
  that declares an auditable mutation also declares its audience.** A mutation with
  no audience must be an explicit, reviewed `audience: none`, not an omission. That
  single move converts 53 silent modules from "nobody remembered" into "somebody
  decided".
  Then the named instances, which are samples of that population rather than
  separate bugs:
  - **XMOD-018/XMOD-019** — the absence alert hardcodes English strings and passes
    **no `templateCode`**, so the five-language `attendance_absence` template has
    **zero callers**; a parent with two children *"Student marked absent for class
    {class_id}"* cannot tell which one. And the alert is enqueued but never drained
    on that path — it ships only when some **unrelated** action happens to drain the
    org's queue. Route it through `enqueueFromTemplate` with `{studentName, date}`,
    drain post-commit best-effort as transport and gate-pass already do, and extend
    coverage beyond `mark === 'absent'` to corrections at minimum.
  - **SIM-002** — consecutive-absence and short-attendance alerts are computed
    correctly and read **only** by one `/management/*` screen. A child missing for a
    week produces a row nobody is obliged to open. Enqueue to the class teacher and
    guardian on first threshold crossing, idempotent per student/threshold/term.
    **Watermark the first run** or it floods parents with historical absences.
  - **SIM-003** — grepping `_shared/complaints/` for any notification call returns
    **zero hits**; on-track/breached is derived at **read** time only, so *a breach
    exists only while somebody has the complaints screen open*. Enqueue on raise,
    assign and resolve; add an SLA-breach sweep to W3.1's lane.
  - **XMOD-023** — an issued transfer certificate is never delivered; the PDF is
    rendered **client-side on the issuing staff device** and the certificate-desk
    path has no PDF surface at all. Notify the requesting parent and expose the
    document on both paths (a TC is a legal document — this needs an access-control
    review, not just a link).
  - **XMOD-013 / SIM-004** — `assignSubstitute` contains **no notification call**;
    `notifiedAudience` is the caller's own booleans echoed back and
    `timetableUpdated: true` is a hardcoded literal. Either notify, or **remove the
    claim from the response and the UI copy**. Fixing the copy is independent and
    should not wait for the notification work.
  - **CERT-004 / POLISH-002** — the persona notification surfaces. A student's bell
    pushes `/parent/notifications`, a route the student does not own, so
    `_authRedirect` bounces them to their dashboard and **the student can never read
    a notification**, though the backend surface is complete. The admin bell does the
    same thing, and `unreadNotifications` is piped through `AdminContentScaffold`
    with a default of `0` that **none of the 20 call sites passes**, so the badge can
    never show a count. F-128 already solved this for the teacher persona by adding
    `/teacher/notifications`; give the student and the admin shell the equivalent and
    wire the badge in the shell rather than per screen.
- **Files.** `_shared/communication/notification_service.ts:40,57-68,83,218-236` ·
  `_shared/communication/parent_comms_localization.ts:69-105` ·
  `_shared/pilot/pilot_operations_handlers.ts:245-263` ·
  `_shared/complaints/complaints_sla.ts:1-60` ·
  `_shared/school_completion/timetable_workforce_service.ts:326-349` ·
  `_shared/certificate_desk/**`, `_shared/sis/sis_certificate_handlers.ts` ·
  `lib/router/app_router.dart:2678-2679,284-296` ·
  `lib/router/student_navigation.dart:36-37` ·
  `lib/features/admin/admin_content_scaffold.dart:31,48,81,83-84` ·
  `lib/features/admin/admin_app_bar.dart:19,29,101-102`.
- **Blast radius. Real messages to real parents.** Needs per-event audience
  resolvers, rate limiting and a dry-run mode before the first live enable.
- **Regression risk. Medium-high** — the highest in Phase 3, and the reason each
  event type is enabled individually rather than by flipping the catalog on.
- **Verification (fails today).** A catalog test asserting **every** registered
  mutation declares either an audience or an explicit reviewed `none`. Plus, per
  instance: mark a child absent and assert a localized delivery naming the child
  reaches `sent`. Fails today for 53 modules and for the absence alert.
- **Dependencies.** **W3.1** (the rail needs a drain), **W1.11** (same transactional
  boundary — an enqueue that survives a rolled-back mutation is a false message).
- **Effort.** XL. Split by module; do not attempt as one wave.

---

### W3.4 — One student-exit orchestration

- **Root cause:** residual — entity continuity.
- **Defects closed:** **XMOD-022**, **XMOD-021**, **XMOD-024**, **XMOD-025**,
  **XMOD-031**, **XMOD-036**, **XMOD-039**, **OS-020**, **OS-021** (9).
- **The change.** A student leaves and **nothing happens** anywhere else. The TC
  engine never touches `sis_student_enrollments.is_current` — and
  `sis_students_repository.ts:374-376` *assumes* it "is typically already false" for
  transferred students, which nothing makes true — so the departed child remains on
  the exam roster, the promotion preview and the transport allocation roster. Late
  fees keep accruing on their invoices (the accrual join has **no `students` join at
  all**) and they stay on the defaulter list permanently, because the clearance
  contributor only *sums* and never zeroes `outstanding_amount` — a permanent
  defaulter ghost. Their bus seat, hostel bed and library membership all persist
  (`room.occupiedBeds` is incremented on assign and **never decremented** — the bed
  is permanently consumed; Library has **no close route at all**), and **nobody
  tells the bus driver — there is no code path that could.**
  Build the single `deactivateStudent` orchestration the register asks for, invoked
  by **every** exit path (TC, PATCH, PUT, year rollover), inside one transaction:
  close the enrolment, stamp a new `students.date_of_leaving` (XMOD-036 — **no such
  column exists anywhere**, and it is a statutory field on Indian school records),
  call the already-correct `stopStudentTransport` (which is complete and whose
  **only** caller today is `DELETE /transport/allocations/{id}`), check the resident
  out with a bed decrement, close the library membership via a new endpoint, close
  the finance assignment and account, and notify the route's driver/transport
  manager. Add `s.status='active'` to the three enrolment-keyed consumers as defence
  in depth.
  In the same wave, widen the clearance registry (XMOD-021): today it tracks **fees
  only** — library is `tracked:false`, hostel `tracked:false`, inventory
  advisory-only and **not even executed at the gate**, and **transport has no
  contributor at all**. Library *is* blocking, but only inside the TC engine, keyed
  on a free-text field a librarian types **with no FK** — so the read-only clearance
  report can show "cleared" while the gate blocks, and `enforceTransferClearance`
  checks finance only, so a `PATCH` to `status='transferred'` **bypasses the library
  block the TC path enforces**. Route every path through one registry, and add the
  `mapApprovalError` branch that turns a library-blocked desk TC from an **opaque
  500** into `blocked_dues` (XMOD-031).
  Then make the hub honest (OS-020): Student 360 is 1,050 lines containing **zero**
  `context.push`/`onTap`/`RouteNames.` — every module can push you in and **nothing
  carries you out** — and `Student360Profile` has **no `library`, `hostel`,
  `health`, `certificate` or `gatePass` field**, precisely the modules a school
  chases a student across at year end. Make each section navigable and add the
  missing fields; that also closes the clearance blind spot from the other side.
  Which requires OS-021's first item: **Hostel carries its own duplicate copy of the
  student roster** inside `hostel_entities`, so a hostel resident and an SIS student
  are two unrelated records. Re-key `hostel_entities` on the SIS student UUID,
  delete the duplicate roster, flip its clearance contributor to `tracked: true`.
  Alumni: derive from SIS graduation (today **graduating a student does not create an
  alumnus**). Backup & Restore: the status panel is a **hard-coded static card** and
  the route has zero navigation references — **connect it or remove the route**; a
  backup console reporting a fabricated status is a claim about data safety nobody
  can act on. Finally ship the parent-facing certificate request screen the backend
  already supports (XMOD-039) — or remove the parent scope so the capability stops
  being counted as delivered.
- **Files.** `_shared/sis/sis_certificates_repository.ts:299-331,520-682` ·
  `_shared/sis/sis_students_repository.ts:374-376,838-861` ·
  `_shared/clearance/clearance_contributors.ts:26-49,98-134` ·
  `_shared/clearance/clearance_engine.ts:99,167`, `clearance_gate.ts:39`,
  `clearance_handlers.ts:60-72` ·
  `_shared/finance/finance_assignments_repository.ts:236`,
  `finance_late_fee_repository.ts:106-118`,
  `finance_recovery_repository.ts:183-187,494-498` ·
  `_shared/transport/transport_write_handlers.ts:553,626-639` ·
  `_shared/hostel/hostel_write_handlers.ts:131,136,156-194` ·
  `_shared/hostel/hostel_read_repository.ts:224-225` ·
  `_shared/library/library_router.ts:54,102` ·
  `_shared/approval/approval_handlers.ts:48-64,498` ·
  `lib/features/student_360/student_360_screen.dart`, `student_360_models.dart:3-45`.
- **Blast radius.** Wide, and it **changes who can be issued a TC**. A wider gate
  blocks certificates that are being issued today — a real operational change for a
  school mid-year.
- **Regression risk. Medium-high.** This is exactly the kind of cascade that needs
  **maker-checker and a dry-run report first**: run the orchestration in report-only
  mode over the existing roster and show the school what it *would* have done.
- **⚠ OWNER DECISION.** Existing accrued late fees on ex-students need a
  waive-vs-retain decision **before** any cleanup.
- **Verification (fails today).** Transfer a student out, then assert: absent from
  the exam roster, promotion preview and transport roster; no new late fee accrues;
  absent from the defaulter list; bus seat, bed and library membership released;
  `date_of_leaving` set; a library-blocked desk TC returns `blocked_dues` not 500.
  Every one fails today.
- **Dependencies.** W1.15 (the narrow roster join), W2.5 (which dues number is
  authoritative), W1.11 (one transaction), W1.3 (documents cited by clearance must
  not be blank pages).
- **Effort.** XL.

---

### W3.5 — HR and leave: the narrow fixes only

- **Root cause:** residual. **⚠ See §7 — the leave-store consolidation (XMOD-011) is
  explicitly NOT in this program.**
- **Defects closed:** **XMOD-002** (P0), **XMOD-003** (P0), **XMOD-012**,
  **E2E-018**, and the HR half of **XMOD-038** (opened in W2.6).
- **The change.** Four fixes that do not require merging the two leave stores:
  1. **XMOD-002** — `mobile_leave_requests.from_date`/`.to_date` were added
     nullable with no default and no backfill, and **no client ever sends them**:
     the teacher and parent DTOs send only labels, and the teacher form's "From
     date" is a free-text `TextField`. Both consumers require
     `from_date IS NOT NULL`, so auto-excuse (ATT-D3 Part B) and substitution
     planning are **permanently inert for every leave created through the shipped
     product**. Replace the text fields with date pickers, send ISO dates, validate
     server-side, backfill from labels where parseable.
     **The backfill is a deliberate, audited migration, not a side effect** —
     turning auto-excuse on retroactively changes historical attendance percentages.
  2. **XMOD-003** — approved staff leave writes no attendance record and the muster
     infers "working day with no check-in → **Absent**" (and `'L'` in that report
     means *Late*, not Leave). Take the smaller, reversible option: **make the
     muster left-join approved leave before inferring absence**, covering both
     stores. Do not write synthetic attendance rows.
  3. **XMOD-012** — the LOP term reads `snapshot_attendance`, which has **no writer
     anywhere** in `supabase/functions/**`, so the absence deduction is permanently
     ₹0. Point it at the live `staff_check_ins` muster — **but only after (2)**, or
     approved leave is double-penalised as absence. **Hard ordering.**
  4. **E2E-018** — the payroll period is free text. `monthFromPeriod` matches
     `YYYY-MM`; the app's own default and helper text produce `"July 2026"`, which
     never matches, so `statutory.month` is **null on every run generated from the
     app** and a school that configured a special-month Professional Tax slab
     **silently never gets it** — a statutory deduction on the wrong slab, on every
     payslip in that month. And `payrollRunIdForPeriod` slugs the free text, so
     `"July 2026"`, `"Jul 2026"` and `"2026-07"` are **three distinct
     independently-processable runs for one month**. Month picker producing
     `YYYY-MM`; validate server-side; reject a second draft for a month that already
     has a processed run.
- **Files.** `supabase/migrations/20260830000000_attendance_half_day_and_leave_dates.sql:21-26` ·
  `_shared/pilot/pilot_leave_repository.ts:57-58` ·
  `_shared/pilot/pilot_operations_handlers.ts:307-308,349-350` ·
  `lib/features/teacher/leave/teacher_leave_screen.dart:206-214` ·
  `_shared/approval/leave_decision_effect.ts:37-42` ·
  `_shared/hr/hr_reports_repository.ts:279-284,338-352,361` ·
  `_shared/hr/hr_reports_handlers.ts:134-139` ·
  `_shared/hr/hr_write_handlers.ts:1341-1373,1467-1470,1573,1592-1621` ·
  `_shared/hr/statutory_payroll.ts:198-215,356-363` ·
  `lib/features/hr/hr_workflow_actions.dart:451,478-524`.
- **Blast radius. Salaries.** All four touch a payroll run.
- **Regression risk. High.** This is the wave most likely to pay someone the wrong
  amount. Run a **parallel payroll** — old computation and new, same month, diffed
  — before any live run. Do not ship (3) and (4) in the same release as (2).
- **Verification (fails today).** Approve leave for tomorrow, do not check in,
  assert the muster shows leave and payroll deducts nothing; and assert
  `"July 2026"` is rejected at the API while `"2026-07"` selects the special-month
  PT slab. Both fail today.
- **Dependencies.** (3) depends hard on (2). W2.6 holds the HR attendance-% half for
  this wave.
- **Effort.** L.

---

### W3.6 — Payroll reaches the books; the library addresses the right parent

- **Root cause:** residual — "built, tested, never wired", on the money path.
- **Defects closed:** **OS-022**.
- **The change.** Three modules that only *look* connected:
  - **HR/Payroll → Finance.** `hr_finance_posting_repository.ts:105` writes
    `payroll_finance_postings` and **no module reads that table**. The intended
    consumer, `_shared/expense_ledger/`, has **zero `postExpense` callers and is not
    registered in `route_registry.ts`**. The link is fully built and never
    connected. **Salary is the largest expense a school has and it does not reach
    the books.** Register `expense_ledger` in the route registry and call
    `postExpense` from the posting repository.
  - **Library.** Its one outbound call is a `scheduleReminder` that **fans out to
    the entire parent body** — the module's own comment says so. So every parent is
    told a book is overdue and **the parent who owes it is not told specifically**.
    Members are keyed **by name, not by student UUID**. Re-key on the student UUID
    (which W3.4 also needs) and address the reminder to that student's guardians.
  - **Complaints.** Covered by W3.3's enqueue-on-raise/assign/resolve.
- **Files.** `_shared/hr/hr_finance_posting_repository.ts:105` ·
  `_shared/expense_ledger/` · `_shared/route_registry.ts` ·
  `_shared/library/library_write_handlers.ts:30,207,1049` ·
  `_shared/complaints/complaints_repository.ts:436`.
- **Regression risk.** Low-medium for payroll→finance and complaints (both are
  wiring existing, working code). **Medium for Library** — re-keying members is a
  data migration.
- **Verification (fails today).** Run payroll, assert a matching expense-ledger row
  exists. Mark a book overdue, assert exactly the borrower's guardians receive a
  delivery and no other parent does. Both fail today.
- **Dependencies.** W3.3, W3.4.
- **Effort.** M.

---

### W3.7 — A bus allocation raises the fee it implies

- **Root cause:** residual — financial workflow (the P0 deferred from Phase 1, §2.4).
- **Defects closed:** **XMOD-004** (P0).
- **The change.** The allocate handler writes the allocation, the effective-dated
  history row and an audit row, then returns 201 — it never calls
  `raiseTransportDemandFor`, and **the code concedes the gap in a comment**. The
  student rides free until an admin independently remembers to open Transport
  Settings and press "Raise demand", re-picking a fee structure by hand. Raise the
  demand **inside the allocation transaction** using the existing idempotent
  `raiseTransportDemandFor` and its `(student, route, year, term)` dedupe key. Keep
  the bulk endpoint as a backfill. Needs a per-route default fee structure so no
  human input is required.
- **Files.** `_shared/transport/transport_write_handlers.ts:321-433,1716,1780-1786,1796,1855-1858` ·
  `lib/features/transport/transport_workflow_actions.dart:647,834`.
- **Blast radius. This creates money.**
- **Regression risk. Medium.** It **must not double-bill** students whose demand was
  already raised through the manual path — that is what the dedupe key is for, and
  it must be verified against real pilot data before enabling.
- **Verification (fails today).** Allocate a student, assert exactly one transport
  demand on their per-year account; allocate again, assert still one. Fails today
  (zero demands).
- **Dependencies.** W1.11 (one transaction), W2.1 (the year in the dedupe key).
- **Effort.** M.

---

### W3.8 — Every control either has an effect or is removed

- **Root cause:** residual — the "state written, never consumed" class.
- **Defects closed:** **WIDGET-008**, **WIDGET-010**, **POLISH-008**, **POLISH-006**.
- **The change.** Twenty-two filter bars across the product highlight on tap and
  change nothing: ten module dashboards (WIDGET-008) plus twelve list and detail
  screens (POLISH-008). In each, the selection provider is `watch`ed **only** to
  paint which chip looks selected; every `*DashboardFutureProvider` calls
  `getDashboard(query: repositoryQueryProvider)` — the unfiltered base query.
  **Management shows the intended shape** (`managementDashboardQueryProvider` maps
  the index to `{'period':…,'quarter':…}` and the future provider watches it); nine
  dashboards never got the equivalent.
  Per screen: **wire it or delete it.** Removal is the honest interim, and the
  product already set that precedent — `global_search_registry.dart:193-212` removed
  tiles rather than leave ones that silently bounce.
  **Two get priority for removal over wiring.** HR → Payroll's *"Current month /
  Last month / All runs"* is not a convenience filter: an accountant who selects
  "Last month" and is shown the current month's runs, unlabelled, is **actively
  misled about which payroll they are reading**. And **every screen in the
  Management workspace has a filter bar that does nothing** — five of the twelve,
  plus the dashboard — which is the principal's own workspace.
  Fix WIDGET-010 in the same pass: one single-select `StateProvider<int>` currently
  spans three unrelated dimensions on Finance, SIS and Admissions, so the control
  **cannot express "this month AND all classes" even in principle**.
  Also POLISH-006: `executeCopilotQuickAction` writes the prompt into
  `copilotMessageDraftProvider` — **a provider never read anywhere in the
  repository** — so every AI quick action, on every persona, opens a blank chat.
  Seed the composer from it on mount and clear it after read. Same defect shape, on
  the flagship AI surface.
- **Files.** the nine `*_dashboard_provider.dart` files and eleven list screens
  enumerated in WIDGET-008 and POLISH-008 ·
  `lib/features/management/management_providers.dart:14-32` (the target pattern) ·
  `finance/intelligence/finance_executive_dashboard_screen.dart:19,23,37-41,143` ·
  `lib/features/copilot/widgets/copilot_ai_quick_actions.dart:132`,
  `copilot/copilot_provider.dart:19`, `copilot/copilot_screen.dart:29`.
- **Regression risk.** Low to remove; medium to wire — each module's
  `GET /<module>/dashboard` must accept the filter params, **which is not verifiable
  from the client** (no Postgres lane). Confirm per module before promising a wire.
- **Verification (fails today).** A test per filtered surface asserting the
  outbound query **differs** between two chip selections. Where the decision is
  removal, a test asserting no filter bar renders. Fails today at 22 sites.
- **Dependencies.** W2.1 (chip *labels* must be tenant-derived — pointless to wire
  a chip labelled with the wrong year).
- **Effort.** L.

---

### W3.9 — Freshness is computed, not remembered

- **Root cause:** residual.
- **Defects closed:** **XMOD-017**, **XMOD-028**, **XMOD-015**, **XMOD-033**.
- **The change.** The parent academic summary returns the persisted row if one
  exists and only generates on a cold miss; the regenerate route has **zero
  non-test callers** and no cron — so a parent sees the original numbers **forever**.
  Student-risk snapshots reflect whenever someone last pressed compute. Either
  recompute on read (the numbers are cheap live queries elsewhere) or schedule the
  refresh in W3.1's lane — and in both cases **stamp the result with a generated-at
  the UI surfaces as freshness**, which is the honest half regardless of which
  option is chosen.
  Then stop the settings screen promising behaviour no code implements (XMOD-015):
  five finance catalogue entries — due-reminder days, overdue reminder, auto receipt
  SMS, allow-partial, invoice prefix — have **zero consumers**, and they render as
  editable with descriptions, which makes the school believe they are in force.
  Either implement the fee-reminder ladder on the existing XCT-2 rail or **remove
  the five entries**. Same for XMOD-033: the reminder rail's header names eight
  consumers and has **four**. Correct the comment or wire the missing ones — but
  do not leave documentation that a future engineer will trust.
- **Files.** `_shared/parent_experience/parent_experience_router.ts:48,80-90` ·
  `_shared/intelligence/intelligence_handlers.ts:92-98,139-152` ·
  `_shared/finance/finance_settings_repository.ts:55,62,75,82,95` ·
  `lib/features/finance/settings/finance_settings_screen.dart:115-137` ·
  `_shared/reminders/reminders_service.ts:10-20`.
- **Regression risk.** Low to remove; medium to implement (parent-facing messaging
  volume).
- **Verification (fails today).** Mark a month of attendance, reopen the parent
  summary, assert it changed. Fails today.
- **Dependencies.** W3.1.
- **Effort.** M.

---

### W3.10 — DAI, in the one order that does not make it worse

- **Root cause:** residual. **Governed by §2.1. Read it before starting.**
- **Defects closed:** **DAI-016**, **DAI-005**, **AI-001**, **DAI-007**, **DAI-006**,
  **DAI-009**, **DAI-010**, **DAI-011**, **DAI-012**, **DAI-013**, **DAI-008**,
  **DAI-015**, **DAI-003**, **AI-002**, **AI-003**, **AI-004**, **AI-005**,
  **OS-018**, **OS-019** (19).
- **The change, strictly in this order.**
  1. **DAI-016 first — close the junk drawer.** `_person` is the last rule and has
     **no positive evidence requirement**: it accepts any 1–3 token alphabetic
     residue, returns confidence 60 (≥ the floor), and therefore claims `payroll`,
     `timetable`, `pending approvals`, `support ticket`, `audit log`, `apply leave`
     and 28 more. **34 of 42 out-of-vocabulary queries in the certification corpus
     resolve to `openPerson`; honest refusal is 7/42 = 16.7%.** The resolver's own
     contract — *"never guesses"* — is not met; the user is protected **only** by the
     consumer discarding the result. Require positive person evidence: an explicit
     qualifier (`teacher`/`student`/`staff`/`sir`), a capitalised token in the **raw**
     query, or a directory hit — plus a module-noun stop list covering the 21
     uncovered modules. Absent that, return `unknown`.
  2. **DAI-005 second, never first.** `openPerson` always sets `route: null` and
     `needsDirectoryLookup` is unconditionally true, so the whole branch — name
     extraction, `DaiPersonHint` staff/student disambiguation, `_nonNameTokens`,
     `_titleCase`, every *"Looking for X…"* string — is **dead in production**. Feed
     `personName`/`personHint` into `AdaptiveSearchResults` (which today does its own
     independent name search and **throws the resolver's staff/student knowledge
     away**), or delete the branch. **The AI harness enforces the ordering** —
     `AI-002 · the junk drawer` asserts every swallowed query still has a null route
     and fails the moment `openPerson` gains one while the drawer is open. **Do not
     weaken that assertion to unblock this wave.**
  3. **DAI-007 + DAI-006 — a stated boundary.** DAI answers 7 of 28 modules; the
     other 21 fail **silently**, and the field says *"Ask anything"*. Add a small
     deterministic module-keyword map rendering a neutral card — *"I can't answer
     that yet. Opening Approvals."* — and change the hint to what the system does:
     *"Search or ask — 'fee defaulters', 'Class 8A', 'bus 5'"*. A closed,
     well-executed vocabulary is a feature; claiming an open one and failing is not.
     **DAI-007 is blocked by (1)** — the system cannot say "I do not handle that"
     while `_person` is claiming everything.
  4. **Rule precedence — AI-002, DAI-009, DAI-010, DAI-011 together.** `resolve()`
     returns the first rule that clears the floor; rules never compete and no rule
     reports leftover input. So `attendance defaulters` → **`feeDefaulters`** at
     confidence 90 answering an attendance question with a **money** list;
     `staff attendance today` opens **student** class attendance; `fee dues class 8`
     opens a class roster; and `fee defaulters class 8 and class 9` **raises
     confidence to 95 while dropping more of the query**. Prefer the head noun,
     require the earlier rule's own domain word, report residue, and add a
     staff/student attendance discriminator. Same root cause; fixing precedence
     addresses all four.
  5. **Coverage — OS-018, AI-003, DAI-012, DAI-013, AI-005, DAI-015.** Add intents
     for the four front-office desks **first**: they are orphaned from every
     workspace (JOURNEY-008), absent from the bottom nav and absent from search, so
     **there is no path to them at all**. Then roll numbers and admission numbers —
     *how Indian schools actually identify a student* — which are unresolvable today
     because `_person` rejects any string containing a digit. Then qualitative
     attendance phrasings ("attendance shortage" is the standard Indian-school term
     for exactly the report `lowAttendance` produces, and it does not resolve),
     prefixed receipt numbers, the sub-3-character floor that makes `8A` and `9B`
     unanswerable **whatever the resolver does**, and the ASCII/3-token name cap.
     **Every one of these widens what the resolver accepts — none may precede (1).**
  6. **DAI-008, AI-004, DAI-003, OS-019 — honesty about what this is.** No code path
     emits a confidence below 55, so the documented floor **cannot fire**; either
     compute confidence from evidence or delete the floor and say rejection is by
     rule. Correct `dai_resolver_test.dart`'s doc comment, which claims to certify
     phrasings for personas that **can never open the surface**. And decide OS-019
     explicitly: `DaiResolver` is `abstract final`, documented *"Pure and
     synchronous. No I/O"*, so cross-module query is **excluded by design, not
     missing**. **Reframe the copy as navigation** (cheap, honest) — see §7 for why
     a query tier is out of scope.
- **Files.** `lib/core/dai/dai_resolver.dart` (whole file) ·
  `lib/core/dai/dai_intent.dart:126-127` ·
  `lib/features/admin/global_search/global_search_overlay.dart:82-89,135-139,165-175` ·
  `lib/features/adaptive_ai/widgets/adaptive_search_results.dart` ·
  `test/core/dai/dai_certification_suite_test.dart`, `dai_resolver_test.dart:15-23,41-44,62-70`.
- **Blast radius.** The golden DAI corpus pins the current chain and **will move**.
  That is the visibility mechanism, not a problem.
- **Regression risk. Medium.** Tightening `_person` costs recall on genuine bare
  names ("Rohan" is confidence 60 today with no qualifier) — the directory fallback
  beneath the card already handles those, so the loss is smaller than it looks.
- **Verification (fails today).** Re-run the 209-query harness and assert honest
  refusal rises from **16.7%** and that **zero** module nouns resolve to
  `openPerson`. Plus the standing harness assertion from §2.1, which must remain
  green throughout.
- **Dependencies.** W1.6 and W1.7 land first (consumer-side gating and answer
  honesty), so this wave is purely resolver-side.
- **Effort.** L.

---

### W3.11 — Two more labels that should be dates

- **Root cause:** RC-3, tail.
- **Defects closed:** **E2E-014**, **E2E-020**.
- **The change.** `exam_sessions` stores only `date_label TEXT NOT NULL DEFAULT ''`
  and `time_label TEXT`; there is **no `exam_date` column** and the create handler
  does no parsing — so nothing can order a datesheet, detect a two-exams-one-slot
  clash, bound an exam to the academic year, or schedule a reminder from the exam
  date. **`marksEntryDeadline` is a validated timestamp on the same table**, so the
  pattern was known and not applied. Add `exam_date DATE` (+ optional
  start/end times), parse and validate on create, keep `date_label` for display,
  backfill where parseable. Same for the admissions follow-up, whose
  `scheduledLabel` is a display string nothing parses — a counsellor who types only
  the task creates a follow-up nominally due *"Tomorrow 10:00 AM"* forever.
- **Files.** `supabase/migrations/20260618120000_f4_exam_sessions.sql:12-13` ·
  `_shared/academics/exam_administration/exam_administration_handlers.ts:449-455`
  (vs `:470-483`, `parseDeadline`, which does it correctly) ·
  `lib/features/admissions/admissions_workflow_actions.dart:216,247-254,623`.
- **Regression risk.** Medium — migration plus a backfill of free-text dates.
- **Verification (fails today).** Create two exams for one class on one morning and
  assert a clash is detected. Impossible today.
- **Dependencies.** W1.2 (date pickers), W2.1 (year bounds), W3.1 (a reminder needs
  a scheduler).
- **Effort.** M.

---

### W3.12 — The two platform layers that exist and are not used

- **Root cause:** residual.
- **Defects closed:** **OS-008**, **OS-010**, **XMOD-034**, **API-124**.
- **The change.**
  - **OS-008** — audit is otherwise a genuine platform layer (48 of 62 mutating
    modules participate). Three modules **reimplement it privately**:
    `approval_audit_entries`, `platform_secret_audit_log`,
    `student_health_access_log` — none visible to `/audit`. **Reimplementing a
    platform service privately is worse than skipping it**, because the trail exists
    and the gap is invisible to anyone checking whether auditing happens. Route the
    three through `recordServerAuditEvent` with module-specific event types; add the
    seven unaudited write paths to the catalog; add a test asserting every module
    directory containing an INSERT/UPDATE imports the audit writer.
  - **OS-010** — `setRequestContext` has **exactly one caller**. There is no
    `_shared/observability`, no request-scoped logger, no error reporter, no
    correlation propagation beyond an optional header. A principal reports "fees
    didn't save this morning" and there is **nothing to search**. Call
    `setRequestContext` in the shared route dispatcher rather than in one handler,
    and emit it on every non-2xx. The RC phase already built the payload (with
    `student_id` deliberately excluded — preserve that).
  - **XMOD-034 / API-124** — the only caller of `deleteCache` in the whole app is
    the read interceptor overwriting its own entry, so a drained mutation never
    invalidates the reads it changed; and nothing asserts that a route reachable
    offline has a registered outbox policy. Have the sync engine invalidate the keys
    a drained mutation affects (carefully — over-invalidation degrades the offline
    experience, and the freshness chip already surfaces staleness honestly, which is
    what keeps this at P2); and enumerate the `OperationTypes` used by
    `ReliableWriter` call sites, asserting each has an explicit policy.
- **Files.** `_shared/approval/approval_repository.ts:214,277` ·
  `_shared/vault/vault_service.ts:93,107,134` ·
  `_shared/student_health/student_health_repository.ts:71,235` ·
  `_shared/request_context.ts:15`, `_shared/auth_handlers.ts:211` ·
  `lib/core/network/interceptors/offline_read_cache_interceptor.dart:116` ·
  `lib/core/reliability/store/reliability_store.dart:44,47` ·
  `lib/core/reliability/policy/operation_policy_registry.dart:33-80`.
- **Regression risk.** Low-medium.
- **Verification (fails today).** Approve something, then assert the decision appears
  in `/audit`. Fails today.
- **Dependencies.** W1.11.
- **Effort.** M.

---

### W3.13 — Workspaces hold jobs; landings and screen gates are derived from them

- **Root cause:** RC-2, tail. **W1.4 made the fallback safe; this makes the roles
  usable.**
- **Defects closed:** **JOURNEY-004**, **JOURNEY-005**, **JOURNEY-006**,
  **JOURNEY-008**, **JOURNEY-010**, **JOURNEY-012**, **JOURNEY-013**,
  **JOURNEY-014**, **OS-014**, **OS-016** (10).
- **The change.** The workspace model **degenerates at both ends**: five roles
  (superAdmin, schoolAdmin, principal, vicePrincipal, management) collapse into one
  workspace — so the product distinguishes a principal from a VP in its permission
  model and then shows them an identical workspace — while **eight of ten workspaces
  hold exactly one module and three hold zero**. An admissions counsellor cannot
  enrol the applicant they just admitted; a librarian cannot look up the student
  borrowing a book; a hostel manager cannot see a resident's fees. Populate
  workspaces around **jobs**: frontOffice = admissions + SIS + certificates +
  gate pass + complaints; finance and hostel and library each gain SIS lookup.
  Then **derive the landing** instead of switching on it. `homeRouteForStaffErp`
  enumerates 5 of 15 roles and sends the rest to `/admin` via `_ =>` — **even though
  every workspace already declares a `homeRoute` that is never consulted.** For four
  of those roles the resulting tile grid contains **exactly one tile**: a one-item
  menu costing a wasted screen and a wasted tap on every sign-in. Read
  `workspace.homeRoute`. Give the hub an `AksharaEmptyState` for the zero-tile case
  (JOURNEY-005) — today it renders the subtitle *"Jump to a module you are
  authorized to access"* above **nothing**, with the drawer (which is not
  workspace-scoped) silently holding the answer.
  Add the five orphaned desks — certificateDesk, gatePass, complaints, studentHealth,
  schoolCompletion (and organizationBuilder) — to a workspace; they are absent from
  **every** `Workspace.modules` set, so they can never render on the hub or the phone
  bottom nav and are drawer-only, while the rail reads the *un-scoped* provider so
  **the three nav surfaces disagree**. Make all three read one provider. Give
  `AdminNavDestination` an explicit priority rank so the phone's four tabs are not
  chosen by source-file order — today they are **Admin Hub · Admissions · Marketing ·
  Finance**, with Marketing (which may render *locked*) holding a permanent slot
  while Management, SIS, Exams, HR and the approval queue are behind "More".
  Give the teacher shell a `/teacher/student-360/:id` sibling (JOURNEY-010): the
  teacher **holds `Permission.viewStudent360`** so the button renders, and then the
  shell wall bounces them Home with no message — the permission and the shell
  disagree, and the working route is bound to `onLongPress` only. The same remedy was
  already applied to lesson logs and syllabus progress.
  Finally, section-gate the shared screens (OS-016): **17 of 310 screens (5.5%)**
  reference RBAC at all, and `student_360_screen.dart` has **zero** — so a hostel
  warden and the accountant both read a child's full behavioural and communication
  record. Use the per-action pattern `sis_profile_screen.dart` and
  `exam_marks_entry_screen.dart` already demonstrate.
- **Files.** `lib/core/workspace/workspace.dart:15-26,59-193` ·
  `lib/features/auth/qa_login_persona.dart:207-216` ·
  `lib/features/admin/admin_navigation_provider.dart:17-274,277-337` ·
  `lib/features/admin/screens/admin_hub_screen.dart:28-99` ·
  `lib/features/admin/admin_bottom_nav.dart:31-60` ·
  `lib/features/admin/admin_navigation_rail.dart:56` ·
  `lib/router/student360_navigation.dart:6-10`, `route_guards.dart:271-273` ·
  `lib/features/student_health/care_alert/care_alert_widget.dart` (mount it) ·
  `lib/features/student_360/student_360_screen.dart`.
- **Blast radius.** Which tiles every role sees, and where every role lands.
  Permission filtering still applies on top, so widening a workspace cannot grant
  access — only reveal what a role already had.
- **Regression risk.** Low-medium. **Except JOURNEY-014**, which surfaces sensitive
  health data: the migration's need-to-know intent and its access-log audit must be
  preserved **exactly**.
- **Verification (fails today).** (a) A nav invariant test asserting **every**
  non-hidden `AdminModule` belongs to at least one workspace and that the hub, the
  bottom nav and the rail resolve from one provider. (b) A landing test asserting
  each of the 15 roles lands on its workspace's declared `homeRoute`. (c) A
  Student 360 test asserting a finance role sees no behaviour section. All fail today.
- **Dependencies.** **W1.4** (the roles must exist and resolve closed first).
- **Effort.** L.

---

### Phase 3 exit gate

1. W3.1 shipped and **verified running on the pilot** before W3.2 or W3.3 enable
   anything. §2.2 honoured: the status literal is in a **later release** than the
   scheduler.
2. §2.1 honoured: the DAI harness ordering assertion is green and unmodified.
3. No control in the product highlights on tap without changing an outcome.
4. Every mutation in the catalog declares an audience or an explicit reviewed
   `none`.
5. A dry-run report for W3.4's exit orchestration reviewed by the school before it
   is enabled.

---

## 6. PHASE 4 — UX · polish · remaining P1/P2

**The premise.** Phase 4 is where the "one change, one class" discipline pays the
most, because polish is where instance-fixing is cheapest and therefore most
tempting. The register is explicit that the RC phase already fell into this trap
**three times**: it fixed one unreachable skeleton (there were six), one raw
`DioException` (one screen has 22 more), one 40→48dp tap target (**in the same file
it left three others**), and four dashboard headed holes (there were six more).
Every wave below is therefore stated as a **sweep with a lint**, not a list of
screens.

**Ordering inside the phase is not cosmetic: W4.1 must land first.**

---

### W4.1 — De-fork the shared async body — before anything else in this phase

- **Root cause:** residual. **Hard prerequisite for W4.2.**
- **Defects closed:** **POLISH-011**.
- **The change.** `ErpAsyncBody` was forked three times — into Finance, SIS and
  Admissions — byte-identical except a doc comment, and **all three forks dropped
  the `errorMessage` parameter** the canonical version carries. Delete the forks and
  import the shared one.
- **Why it is first.** Every improvement in W4.2 — pull-to-refresh, the permission
  state, the list skeleton — **will not reach Finance, SIS or Admissions**, the three
  highest-traffic admin modules in the product, unless this lands first. Otherwise
  every W4.2 fix is done four times, or (more likely) once, and the modules that
  matter most are silently excluded.
- **Files.** `lib/shared/async/erp_async_state.dart:35,77` ·
  `lib/features/{finance,sis,admissions}/*_async_state.dart:77`.
- **Regression risk.** Low.
- **Verification (fails today).** A test asserting exactly **one** definition of the
  async body widget exists in `lib/`. Reports four today.
- **Effort.** S.

---

### W4.2 — One async body, adopted everywhere, with the states it already owns

- **Root cause:** residual — the class the RC phase sampled.
- **Defects closed:** **POLISH-003**, **POLISH-004**, **POLISH-005**, **POLISH-012**,
  **POLISH-017**, **POLISH-021** (6).
- **The change.** Five state treatments, one wrapper:
  - **Refresh.** There are 19 `RefreshIndicator`s in the app and **18 are in the
    parent/student/teacher surfaces**; pull-to-refresh exists on **1 of 78 admin
    list screens**, and only two admin screens have a refresh button. An accountant
    watching the counter cannot reload the collections list without navigating away
    and back. Bind a `RefreshIndicator` to the `onRetry` callback **every one of the
    78 screens already passes** — one shared wrapper, not 78 changes.
  - **Permission denied.** 17 screens hand-roll it as a centred grey sentence on a
    blank `Scaffold` — **indistinguishable from a crash**, and it is the state a
    principal is *most* likely to hit, because exploring means opening things you
    are not entitled to. `AksharaErrorState.fromFailure` with
    `AksharaFailureKind.permission` already models it.
  - **Raw exceptions.** Platform Operations prints `App health error: DioException
    [connection error]: …` inline **in 22 places**, none with retry. The RC phase
    closed this exact class on the day-one import screen; **the instance was fixed
    and the class was not swept.**
  - **Swallowed errors.** Ten screens render **nothing** on failure — including
    **Finance → Defaulters, where an empty list tells a principal that nobody owes
    money** — and 17 more toast the error away in four seconds leaving a blank page
    with no retry. `ErpAsyncBody` **cannot be constructed without `onRetry`**, which
    is exactly why adoption is the fix rather than 27 edits.
  - **Loading and empty.** `akshara_skeleton.dart` defines six builders and **only
    `.dashboard()` has production call sites**; `.list()`, `.row()`, `.card()`,
    `.line()` and `.circle()` have zero. `AksharaAnimatedSwitcher` has zero uses, and
    `akshara_mount_fade.dart` has zero uses **while being the only widget in the repo
    that honours `MediaQuery.disableAnimations`** (see W4.5). Loading treatments
    number six across the app: 257 shared, 11 skeleton, **17 bare full-page
    spinners**, **35 `SizedBox.shrink()`** (content pops in with no feedback) and 25
    with nothing at all. Wire `.list()` into the list variant; retire whichever of
    the two coexisting empty-state visual languages is not chosen.
- **Files.** `lib/shared/async/erp_async_state.dart:77,110` ·
  `lib/shared/widgets/akshara_skeleton.dart` · `akshara_motion.dart:121` ·
  `premium/akshara_mount_fade.dart` · `platform_operations_hub_screen.dart:143,211-762`
  and the full file:line lists in POLISH-004, POLISH-012, POLISH-021.
- **Regression risk.** Low-medium; visible change, so golden regeneration.
- **Verification (fails today).** A rendered-tree lint over every routed screen
  asserting each of loading / empty / error / permission resolves to a shared widget,
  and that no `Text` in an error branch interpolates an exception object. Fails at
  ~70 sites today.
- **Dependencies.** **W4.1.**
- **Effort.** L.

---

### W4.3 — No headed holes, no cards that announce nothing

- **Root cause:** residual.
- **Defects closed:** **WIDGET-003**, **WIDGET-004**, **WIDGET-005**, **WIDGET-006**,
  **WIDGET-007**, **WIDGET-014**, **POLISH-014** (7).
- **The change.** On day one at an empty school the product renders section headers
  above nothing, fixed-height blank boxes, and — worst of the set — an **empty
  bordered Card with no content at all** on Hostel's health alerts. Specifics worth
  naming because they are claims rather than gaps: the student dashboard renders an
  **"Exam" card reading "In 0 days"** with three blank lines and a screen-reader
  label *"Exam reminder: , , , in 0 days"* for a school with no exams; the AI
  suggestion bar renders the **full brand-gradient card with a blank message and a
  blank action button** on three personas (the parent dashboard already guards it
  correctly — `if (data.aiInsight.message.isNotEmpty)`); and the Director dashboard's
  empty state **can never fire** because the screen passes
  `isDataEmpty: (_) => false`, hard-coding the predicate to false and making its own
  declared `emptyMessage` dead code.
  Guard **inside the shared widgets** wherever possible — one guard in
  `akshara_ai_suggestion_bar.dart` fixes all three call sites at once — and apply the
  `AksharaSectionEmpty` pattern the RC phase already added to four dashboards to the
  six it did not sweep.
  **Note:** the AI bar's eyebrow default is the string **"AKSHARA SUGGESTS"** while
  the app is renaming to **NIKSHA OS** — a user-visible legacy brand string on every
  persona dashboard. Fix it in this wave.
- **Files.** `management_segment_panel.dart:21-93` ·
  `parent_dashboard_screen.dart:198-202,538-575` ·
  `teacher_dashboard_screen.dart:177-180,312-344` ·
  `student_app/dashboard/widgets/exam_reminder_card.dart:19-132` ·
  `shared/widgets/premium/akshara_ai_suggestion_bar.dart:12-127` ·
  `director/director_dashboard_screen.dart:38-49,65-93` ·
  `management_dashboard_screen.dart:331-348` · the six dashboards in POLISH-014.
- **Regression risk.** Low, with golden regeneration.
- **Verification (fails today).** A widget test asserting **every headed dashboard
  section renders something at zero rows** across all 23 dashboards, and that no
  branded card renders with an empty message. Fails at ~14 sites today.
- **Effort.** M.

---

### W4.4 — Say each thing once; delete what has no rendering site

- **Root cause:** residual.
- **Defects closed:** **WIDGET-012**, **WIDGET-015**, **POLISH-024**, **OS-012** (4).
- **The change.** On the management dashboard the **same insight renders twice** —
  as an amber warning inside "Alert center" and again as an insight card at the
  bottom, both styled as something to approve, both wired to `/management/approvals`
  — and **pending approvals render three times** (priorities, alert centre, queue
  preview). Pick one home per fact; derive the insight card's `actionLabel` from the
  insight rather than hard-coding "View approvals" / "Review defaulters" so the
  button matches the sentence.
  Delete the three superseded hero widgets that ship with no caller. **The
  care-alert widget is not cleanup and must not be deleted by reflex** — it is bound
  to the **live** `GET /student-health/care-alerts` endpoint and has no rendering
  site, so a teacher is never told a child in their class has an active care alert.
  W3.13 mounts it; if the product decides otherwise, stop serving the endpoint.
  Delete the nine never-read providers, and — per §7 — **delete the dynamic-widget
  platform** rather than adopting it.
- **Files.** `management_principal_overview_panel.dart:143-223` ·
  `management_dashboard_screen.dart:148,233-235,257-263` ·
  `parent/dashboard/widgets/hero_card.dart`, `teacher/dashboard/widgets/greeting_header.dart`,
  `student_app/dashboard/widgets/hero_greeting_card.dart` ·
  `lib/features/dynamic_widgets/` (6 files), `_shared/widget_platform/widget_pack_catalog.ts` ·
  the nine identifiers in POLISH-024.
- **Regression risk.** Trivial for the deletions.
- **Verification (fails today).** A lint asserting every widget file under
  `lib/features/**/widgets/` has at least one importer, and every declared provider
  at least one reader. Reports 4 widgets and 9 providers today.
- **Dependencies.** W3.13 for the care alert.
- **Effort.** S–M.

---

### W4.5 — Accessibility: the settings the OS sends us are honoured

- **Root cause:** residual.
- **Defects closed:** **POLISH-007**, **POLISH-009**, **POLISH-015**, **POLISH-016**,
  **POLISH-018** (5).
- **The change.**
  - **Reduce motion has no effect anywhere in the app.** `motion.dart:33` is
    `animationsEnabledInEnvironment => !bool.fromEnvironment('FLUTTER_TEST')` and
    **never reads `MediaQuery.disableAnimations`**. Because every entrance animation
    routes through `AksharaMotionAppear` and every page transition through
    `page_transitions.dart:17`, the gate is global — so **one expression makes every
    animated surface compliant at once**. The correct check is already written, in
    `akshara_mount_fade.dart:55`, a widget with zero production call sites.
  - **Tap targets.** Six sites under 48dp — 40, 40, 40 and 36dp on the admin search
    field, the parent avatar, "View receipt" and the teacher's daily "Check in now" —
    **including in the very file the RC log records as fixed 40→48dp**, where three
    other sites in the same file use the token and the search field was missed. Plus
    24 `VisualDensity.compact` sites shaving ~8dp each. The reason it was not caught
    is the more important half: `tap_target_lint_test.dart` asserts only the **theme
    defaults** and pumps exactly two widgets — **a test whose premise is weaker than
    the claim it appears to defend.** Replace it with one that walks the rendered
    tree of representative screens.
  - **Contrast.** The existing RC fix and its test are **genuine** — 4.5 asserted,
    all 14 tone×scheme pairs enumerated, with a premise guard. But it covers one
    widget. Failing and uncovered: the KPI trend chip's neutral state at ~4.04:1
    (**the delta label under every KPI on four dashboards**, in two independent
    copies) and form hint text at ~3.42:1 (**every search box and form field**). And
    the gate itself is loose: `onSurfaceVariant on surface` — the app's default
    secondary body colour — is asserted at **3.0** while measuring 4.76:1, so the
    assertion is 1.76 points looser than reality and **would green-light a real
    regression**. Raise it to 4.5 and extend coverage to trend chips, hints, legends,
    on-accent and severity text.
  - **Layout.** Three fixed-width dropdowns totalling **540dp in one `Wrap` in a
    360dp viewport** on Exam Reports, and five more sites; and `SizedBox(height:)`
    wrappers on Admissions and Director KPI rows that **override the card's own
    growth** and defeat the shared text-scale fix. Both have in-tree templates — the
    Director shared widgets fall back to a `Column` before the `Wrap`, and the RC
    phase already replaced `SizedBox` with `ConstrainedBox(minHeight:)` on the
    section header.
  - **Record the known ceiling, do not hide it:** above ~1.6× text scale the KPI
    card and progress ring fall back to `maxLines:1 + ellipsis`, so a principal on
    maximum font sees a truncated money value (`₹12,4…`). That is a fact to state in
    the accessibility notes, not a defect to paper over.
- **Files.** `lib/theme/motion.dart:33`, `page_transitions.dart:17`,
  `premium/akshara_mount_fade.dart:55` · `lib/theme/accessibility.dart:6,80` ·
  `shared/widgets/akshara_kpi_card.dart:186,213`,
  `akshara_executive_kpi_card.dart:165` · `lib/theme/app_theme.dart:687,698-700` ·
  `shared/navigation/akshara_navigation.dart:667` ·
  `test/theme/tap_target_lint_test.dart`, `test/theme/rendered_contrast_audit_test.dart:46` ·
  the six `Wrap` and two `SizedBox` sites in POLISH-009 and POLISH-018.
- **Regression risk.** Low-medium; token changes require golden regeneration.
- **Verification (fails today).** (a) Pump with `disableAnimations: true` and assert
  no animation controller runs — fails today. (b) A rendered-tree tap-target lint —
  fails at six sites. (c) The contrast audit extended to the two failing pairs —
  fails at both.
- **Effort.** M.

---

### W4.6 — One page frame, one radius, one type scale

- **Root cause:** residual.
- **Defects closed:** **POLISH-019**, **POLISH-020**, **POLISH-022**, **POLISH-023**
  (4).
- **The change.** The baseline here is **genuinely clean and should be said so**:
  zero raw `Color(0x…)` in all 954 feature files, 3,497 `AksharaSpacing.*` uses, one
  icon family, a dark theme regression-locked by goldens, and twelve module
  scaffolds correctly delegating to `AdminContentScaffold` — the strongest part of
  the system. The strays are bounded and should be fixed **in order of return**:
  1. The `_segment_panel.dart:73` clone forked across **8 modules** carries 13 of the
     18 off-token radii — **one change kills 13**.
  2. Admissions' radius 14 used three times beside cards at 16 — the visible
     mixed-corner symptom on a daily screen.
  3. `const onTone = Colors.white;` on a token-resolved fill in the approval queue
     (will fail contrast on a light accent) — and note that two comments in
     `office_attendance_screen.dart` **document this exact WCAG failure being fixed
     once already**; the class was not swept.
  4. The 9 raw status colours in two switch maps on Office Attendance, a daily
     principal screen — and `return Colors.blue;` as the fallback when **a school's
     own brand colour** fails to parse.
  5. Emoji as iconography in three places (`Text('⚠ $w')`, `'👁 … ↗ …'`).
  6. `school_completion/` — **20 screens, 28 router refs** — on a bare `Scaffold`
     with no content grid, no `AdminAppBar`, no breadcrumbs. **Adopt
     `AdminContentScaffold` there first; it is the only bypassing cluster a school
     actually sees.** `verticals/` (20 screens) is MOCK/HIDDEN — see §7.
  7. A `labelMicro` token for the KPI micro-label currently hand-typed `fontSize: 10`
     in **five** files, and `AksharaSectionHeader` in place of the six ersatz
     platform pseudo-headers. (Note 52 of the 86 `fontSize:` literals are legitimate
     — inside `pw.TextStyle` in PDF services, which has no Flutter theme. Do not
     "fix" those.)
  8. The Admin Hub card interior, now sparse at full width: one short word floating
     in a 379×138dp rectangle, 8–12 times. A ListTile-shaped row with a **live count**
     would also give JOURNEY-005's empty hub something to say.
- **Regression risk.** Medium for POLISH-019 (visible layout change on 20 routed
  screens); low for the rest with golden regeneration.
- **Verification (fails today).** Lints for: off-token radius values, `Colors.<name>`
  in feature code, `fontSize:` outside `pw.TextStyle`, and routed screens not
  delegating to a module scaffold. All four report violations today.
- **Effort.** L.

---

### W4.7 — The things people need every day are one tap away

- **Root cause:** residual.
- **Defects closed:** **CERT-005**, **JOURNEY-011** (2).
- **The change.** `RouteNames.support` is referenced in exactly two places in
  `lib/` — its registration and the permission map — and **no widget anywhere
  navigates to it**. The route is correctly auth-gated so every persona *could*
  reach it; no affordance was ever added, so **the only way in is to type `/support`
  as a deep link**. This is the school's only channel to the Akshara Support Team,
  and its backend works. Add it to the shared settings/profile surface all four
  personas already reach, and to the Admin Hub / side rail for staff. (Note: the RC
  phase fixed the *data* half of this finding — the fabricated `SUP-####` reference
  — so the fix currently **benefits nobody**, which is the clearest small example of
  instance-over-class in the register.)
  Then reorder two sub-navs by daily frequency. Finance's **Collections** — which
  owns the "Record collection" dialog — and **Offline Payments** are the 5th and 6th
  entries and fall into the phone "More" sheet: **three taps to the money-taking
  dialog**, while Fee Structures (annual configuration) holds a permanent inline
  slot, and the finance dashboard has no "Record collection" action of its own.
  Transport's Allocation and Attendance overflow the same way while Vehicles and
  Drivers stay inline. Reorder the lists and add a primary collect action to the
  finance dashboard. **Routes unchanged.**
- **Files.** `lib/router/app_router.dart:301-322`, `route_guards.dart:66` ·
  `lib/features/admin/admin_navigation_provider.dart:17-270` ·
  `lib/features/finance/finance_navigation.dart:6-21` ·
  `lib/features/transport/transport_navigation.dart:6-16` ·
  `lib/shared/widgets/akshara_navigation.dart:287-345`.
- **Regression risk.** Very low.
- **Verification (fails today).** A navigation-graph test asserting `/support` is
  reachable from at least one affordance per persona, and that the finance and
  transport primary actions are within one tap of the module landing. Both fail today.
- **Effort.** S.

---

### W4.8 — An export button either exports or is visibly disabled

- **Root cause:** residual.
- **Defects closed:** **POLISH-013**, **OS-011** (2).
- **The change.** Six Export/Download/Print buttons produce a snackbar reading
  *"preview only. Export pipeline not connected yet."* **The copy is honest and
  deserves credit; the control is not** — it is a full-size, permission-gated button
  visually identical to the real exporters in the same module. On Library Reports a
  librarian sees a **working** CSV/PDF download on the overdue tab and a stub on the
  next. The product already has the right pattern one directory away:
  `hostel_reports_screen.dart:168-169` uses `onPressed: null` with the tooltip
  *"Export not available yet"* — visibly disabled, honest, impossible to mistake for
  a working control. **One line each.**
  OS-011 is the reason they are stubs: **there is no shared CSV/PDF/report service in
  `_shared/` at all**, and ~55 backend modules have no reporting surface — including
  attendance, complaints, certificates, inventory, hostel and staff duty, every one
  of which holds data a principal will be asked for by a board, a parent or an
  inspector. Per §7, **do not build that service in this program.** Close OS-011 as
  a **recorded product gap with a named owner and a date**, and close POLISH-013 by
  disabling the six controls.
- **Regression risk.** Trivial.
- **Verification (fails today).** A lint asserting no enabled action invokes
  `showAksharaReportExportPreviewSnackBar`. Reports six today.
- **Effort.** S.

---

### Phase 4 exit gate

1. W4.1 landed before W4.2 (otherwise Finance, SIS and Admissions are excluded from
   the phase).
2. Every wave shipped with its **lint**, not just its edits. A wave that fixed the
   listed sites and added no lint has re-sampled the class and is not done.
3. Goldens regenerated once, at the end of the phase.
4. The known text-scale ceiling (~1.6×) is documented in the accessibility notes.

---

## 7. What this program must NOT attempt — and the technical reason

A remediation program is defined as much by its exclusions as its contents. Each
item below is something a reasonable engineer would pick up while working nearby.
Each has a specific technical reason not to, **and a stated alternative** — an
exclusion without one is procrastination in a suit.

### 7.1 Do NOT consolidate the leave subsystem (XMOD-011)

Two disjoint leave stores exist: HR staff leave in the JSONB snapshot
`snapshot_leave.requests[]`, and teacher/parent-app leave in the table
`mobile_leave_requests`. Nothing bridges them; payroll reads only the first, the
substitution engine only the second.

**Why not now.** The consolidation is a **data migration out of JSONB, on the
payroll path**, and this program is *simultaneously* changing three other inputs to
the same salary computation: the absence/LOP term (XMOD-012), the muster's absence
inference (XMOD-003) and the payroll period key (E2E-018). **Four concurrent
changes to one salary calculation is how a school pays somebody the wrong amount**,
and unlike almost everything else in this register that error is not reversible by
a redeploy. The register itself rates the fix **High** risk and prescribes "sequence
behind a read-compat shim" — that shim is a project, not a wave.

**Instead:** W3.5's four narrow fixes — the muster **left-joins** approved leave
(covering *both* stores, which is possible without merging them), the LOP term moves
to the live muster only after that, date pickers make leave windows machine-readable,
and the payroll period becomes `YYYY-MM`. Record XMOD-011 as a **known
architectural debt with a named owner**, to be scheduled as its own program with a
parallel-payroll validation period.

### 7.2 Do NOT wire the Morning Brief (XMOD-027)

The backend is sound — T1 sections computed live per request, attendance included
for teachers — and no client calls `/intelligence/briefs/*` at all.

**Why not now.** The management dashboard **already has two** "what matters today"
surfaces, and they **duplicate each other** (WIDGET-012: the same insight rendered
twice, the same approval queue three times). `dai_brief.dart:14-19` records this
observation and **declined to ship the brief for exactly this reason**. Adding a
third before W4.4 resolves the duplication makes the principal's dashboard worse,
and the register's own recommendation is "either ship the client surface **or mark
the brief platform out of scope for v1**".

**Instead:** mark it out of scope for v1 and **remove it from the delivered-feature
count** so the inventory stops asserting a capability no user can see. Revisit only
after W4.4 has established one home per fact.

### 7.3 Do NOT adopt the dynamic-widget platform — delete it (OS-012)

A registry, a layout editor, a runtime screen, a backend catalog with 6 widget ids,
full CRUD and a router entry. **Zero consumers.** All 23 dashboards are bespoke.

**Why not.** Migrating 23 hand-built dashboards onto it is an XL rewrite that closes
**zero** registered defects, during a program whose thesis is that the dashboards
themselves are showing wrong numbers. And an unused platform layer is **worse than
no platform layer**: it carries maintenance and migration cost, it appears in
inventories as a capability, and it disguises the absence of a real dashboard
platform.

**Instead:** delete it (W4.4) and say so in the inventory.

### 7.4 Do NOT build a cross-module DAI query tier (OS-019)

**Why not.** `DaiResolver` is `abstract final class`, documented *"Pure and
synchronous. No I/O, no clock, no randomness"*. Cross-module query is not missing —
it is **excluded by the resolver's stated design contract**. A query tier is a new
subsystem with its own RBAC scoping problem (every composed predicate must respect
the asker's permissions), and the product does not need it to be honest.

**Instead:** reframe the copy. Changing *"Ask anything — …"* to *"Search or ask —
'fee defaulters', 'Class 8A', 'bus 5'"* closes DAI-006 in about an hour. **A closed,
well-executed vocabulary is a feature; claiming an open one and failing is not.**

### 7.5 Do NOT surface DAI in the parent/teacher/student shells (DAI-003)

Three intents (`myFees`, `myAttendance`, own `exams`) and the whole "my child"
vocabulary serve personas that **can never invoke them** — `DaiResolver` has one
production call site, inside the admin ERP chrome.

**Why not.** This is a **product decision**, not a defect fix, and building it makes
DAI-002's routes correct rather than broken — which sounds appealing and means
shipping the assistant into three more shells during a stabilisation program.

**Instead:** remove the personal intents (W1.6/W3.10). Do not leave both halves in
place.

### 7.6 Do NOT improve DAI recall before the junk drawer is closed (DAI-015, AI-003, AI-005, DAI-012, DAI-013)

Every one of these **widens what the resolver accepts**: 4–5 token names, unicode
names, numeric identifiers, qualitative attendance phrasings, prefixed receipt
numbers, and a lower character floor so `8A` reaches the resolver at all.

**Why not first.** While `_person` is the catch-all, each widening adds inputs to a
rule that already misclaims 34 of 42 out-of-vocabulary queries. AI-005 says it
plainly: lowering the floor "with the junk drawer still open is a reason to sequence
this **after** AI-001, not before". **This is the same trap as §2.1, one level down.**

**Instead:** they are all inside W3.10, strictly after step (1).

### 7.7 Do NOT build the shared backend reporting service (OS-011)

~55 backend modules have no reporting surface and there is no shared CSV/PDF service
in `_shared/` at all.

**Why not now.** It is a new platform service (query → typed rows → CSV/PDF) plus
per-module report definitions — comfortably XL — and it closes exactly **one**
register entry. It is a *product* gap, not a correctness defect: nothing is wrong,
something is absent.

**Instead:** W4.8 disables the six stub Export buttons with `onPressed: null` and an
honest tooltip — a pattern the product already uses one directory away — and OS-011
is recorded as a product gap with a named owner and a date. The client **does**
already have a genuine shared export service with 20+ callers, so the eventual work
is smaller than it looks.

### 7.8 Do NOT polish MOCK/HIDDEN surfaces

`verticals/` (20 screens), industry, white-label, multi-school, branch, franchise,
workflow automation, resource optimisation, education/QIE, Memories, Parent
Meetings, Continuity. Their flags are absent from `config/live_release.json`, their
repositories resolve to `Mock*`, and both hide gates are active.

**Why not.** POLISH-019's 40-screen scaffold-bypass count includes 20 vertical
screens **no school can open**. Spending Phase 4 on them buys nothing. The register
is explicit: *"Hiding a backend-less surface is the honest behaviour the inventory
documents, not a defect."*

**Instead:** W4.6 scopes the scaffold work to `school_completion/` — 20 screens and
28 router refs, and **the only bypassing cluster a school actually sees.**

### 7.9 Do NOT hand-edit the 91 stale RBAC rules (API-102)

Deleting them by hand produces a correct file and **leaves the class fully intact** —
the inventory is still hand-maintained, still has no code-derived source, and the
92nd stale rule appears with the next refactor. Generate the table (W1.16) and let
the diff go to zero as a consequence.

### 7.10 Do NOT decide the money questions in code

Three are owner decisions, and an engineer choosing a default is a school being
silently charged or a child's grade silently changed:
- **Retroactive seat billing** after the student-count fix (W2.2) — the school has
  been over-billed for alumni and transferred students. Refund, credit, or forward-only?
- **Already-published report cards** after the grading convergence (W2.3) — reissue,
  or freeze historical cards to the scale in force at publish time? (**Freeze is the
  recommendation**, but it is not engineering's call.)
- **Accrued late fees on ex-students** before the exit-orchestration cleanup (W3.4) —
  waive or retain?

### 7.11 Do NOT re-baseline goldens more than once per phase

The golden suite currently **pins the mock path** (`golden_test_helpers.dart:79-81,123-125`
overrides all nine dashboard loading providers to `false`). W1.1, W1.2, W4.3, W4.5
and W4.6 all move pixels. Re-baseline at each **phase** exit, not each wave, or the
review value of a golden diff is lost in noise.

### 7.12 Do NOT ship the two coupled changes as one release

Restating §2.1 and §2.2 here because they are the two exclusions most likely to be
violated by someone doing the obviously-correct-looking smaller thing:
- **DAI-005 alone** — makes the product visibly worse (34 confident false answers).
- **The domain-event status literal without the drain cron** — strands every event
  unpublished across 171 event types.

---

## 8. Owner / infrastructure track — outside this repository

**These four cannot be closed by any code change here.** They are carried separately
and are **excluded from every phase's exit criterion** (§2.3). They are also, right
now, the highest real-world risk in this document — a green Phase 1 does not make
the pilot safe.

| ID | Sev | What it is | The owner action |
|---|---|---|---|
| **API-105** | P0 | The **deployed** build has no central auth chokepoint. Anonymous `curl` to `/zzz/nope` → 404, `/support/incidents/not-a-uuid` → 422, `/attendance/register/monthly` → 422 — all with no `Authorization` header, all carrying the app's `x-correlation-id` and security headers, so they are produced by the application. `eng4_5_forced_auth_test` asserts ICA-F1 makes these 401 — **that is a repo property, not a production one.** Three routes that exist on this branch 404 live, so the pilot predates ICA-F1. | **Deploy the release branch**, then re-run the probe set and confirm every module path 401s. Until then no ICA-F1-dependent property may be asserted about production, and every handler-level `authenticateRequest` is load-bearing with no backstop. |
| **API-107** | P0 | `/health/tenant-access`, `/operations`, `/storage`, `/providers`, `/backup` answer the **public internet** unauthenticated, disclosing school count (`visible_schools=7`), the internal DB role name, which isolation tests fail, queue depths, the storage bucket, vault state and the nightly backup's **sha256, byte size and `offsite:false`**. The guard passing through requires **both** `INTERNAL_HEALTH_TOKEN` unset **and** `APP_ENV != "production"`. **The second-order risk is larger than the leak:** `APP_ENV != production` is the same flag `canReturnOtpInResponse` reads — outside production the login OTP is returned **in the response body**. That is account takeover with no SMS. It **was not tested** (a mutation + an authentication attempt, both out of a read-only scope). | **Read `APP_ENV`, `OTP_DEV_MODE`, `OTP_PILOT_PHONES` and `INTERNAL_HEALTH_TOKEN` off the live container before release.** Set `APP_ENV=production` and a real health token; re-probe to confirm 403. ⚠ Setting `APP_ENV=production` correctly disables OTP-in-response, which pilot logins may currently depend on — **verify SMS delivery works first.** Repo half: a startup assertion refusing to boot a production-hostname deployment with `APP_ENV != production`. |
| **API-108** | P0 | The pilot's own RLS isolation matrix is **RED right now**: `status: "degraded"`, `isolation.pass: false`, with four failing student-scope probes (`student_denied_student_profiles`, `…_sis_students_api`, `…_sis_student_create`, `…_sis_dashboard`, each `visible=1`, expected 0). **Every school↔school and parent↔child probe passes**, so this is a **persona** boundary failure, not cross-tenant leakage. | **Run the four probe SQL shapes under a `student`-scope session and report the row's identity.** If it is another student's record, fix the policy. If it is the student's **own** record, the probe is the defect and the pilot has been reporting a false `degraded` for as long as it has been deployed. Nothing in the repo can distinguish these — no Postgres lane, SSH owner-bound. |
| **API-106** | P1 | `/health` returns `{"version":"unknown","builtAt":null}`. Neither `AKSHARA_BUILD_SHA` nor a colocated `build_info.json` is populated, so **"which commit is live" is unanswerable by any black-box means** — exactly the question API-105 forced, which had to be answered by inference from route behaviour. | Set `AKSHARA_BUILD_SHA`/`AKSHARA_BUILD_TIME` in the deploy recipe; make the post-deploy smoke check **assert `/health` reports the SHA just deployed**. Do this **first** — it is what makes API-105 verifiable rather than inferred. |

**Two further owner prerequisites**, gating repo work rather than being defects:

- **W1.4 (role fail-closed)** needs a **live audit of assigned role slugs** before it
  ships, or users on unmapped slugs lose access on upgrade.
- **W3.1 (scheduler)** needs `INTERNAL_CRON_TOKEN` set on the `akshara-edge`
  container. Whether it is set today **could not be verified**; if it is not, the
  entire notification queue has never drained on schedule and W3.3 will have no
  effect.

**Recommended order:** API-106 → API-105 → API-107 → API-108. The build stamp first,
because every other conclusion about the running system currently rests on inference.

---

## 9. Closes-the-most — ranked by defects retired per change

Ranked by **registered defects closed by one coherent change**, with P0s weighted.
The first five are where a fixed budget should go.

| # | The single change | Closes | P0s | Wave | Effort |
|---|---|---|---|---|---|
| **1** | **One honest-async contract** — delete the `?? *.mock()` terminal fallback and make screens read the real `AsyncValue` instead of never-written `StateProvider<bool>`s | **10** — CERT-001/002/006, JOURNEY-007, WIDGET-001/002, E2E-005/011/012/021 | 7 | W1.1 | M–L |
| **2** | **The notification rail becomes a declared step of the mutation catalog** — audience alongside audit | **10** — OS-009, XMOD-013/018/019/023, SIM-002/003/004, CERT-004, POLISH-002 | 1 | W3.3 | XL |
| **3** | **One student-exit orchestration** invoked by every exit path, plus a widened clearance registry | **9** — XMOD-021/022/024/025/031/036/039, OS-020/021 | 0 | W3.4 | XL |
| **4** | **Delete every compile-time demo figure and fixture-id map** | **9** — JOURNEY-001/015/016, WIDGET-011, CERT-003, POLISH-010, E2E-002/009/013 | 2 | W1.2 | S–M |
| **5** | **Generate the RBAC inventory from the routers; drive the matrix through the dispatcher** | **7** — API-100/101/102/103/104/111, OS-013 | 0 | W1.16 | L |
| **6** | **Workspaces hold jobs; landings and gates derive from them** | **6** (+4 role defects unblocked by W1.4) — JOURNEY-004/005/006/008/010, OS-014, OS-016, JOURNEY-012/013/014 | 0 | W3.13 | L |
| **7** | **One shared async body, adopted** (after de-forking it) | **6** — POLISH-003/004/005/012/017/021 | 0 | W4.1+W4.2 | L |
| **8** | **The canonical attendance null survives to the screen** | **6** — XMOD-010, OS-001, XMOD-020/038, WIDGET-016/017 | 2 | W2.6 | M |
| **9** | **Close the DAI junk drawer, then wire the person path** (§2.1 order) | **6 directly** — DAI-005/016, AI-001, DAI-007/006, OS-018; enables 13 more | 0 | W3.10 | L |
| **10** | **One "collected", one "outstanding dues"** | **5** — OS-005, XMOD-014/035, WIDGET-013/018 | 0 | W2.5 | L |
| **11** | **No headed holes** — guard inside the shared widgets | **7** — WIDGET-003/004/005/006/007/014, POLISH-014 | 0 | W4.3 | M |
| **12** | **Every filter control has an effect or is removed** | **4** across **22 surfaces** — WIDGET-008/010, POLISH-008, POLISH-006 | 0 | W3.8 | L |
| **13** | **One grading service on the server** | **4** — OS-003, XMOD-030, E2E-015/016 | 1 | W2.3 | L |
| **14** | **An academic-year resolver on the context 173 files already read** | **4**; **unblocks OS-002, E2E-014/020, W2.5, W3.8, W3.11** | 0 | W2.1 | L |
| **15** | **The money write path cannot silently lose a collection** | **7** — API-119/113/120/121/122/123, E2E-010 | 1 | W1.9 | M–L |

**Highest leverage per unit of effort** (not the same list): **W1.5** (one
conditional, closes a P0 privacy P0), **W4.5's reduce-motion fix** (one expression,
makes every animated surface in the app compliant), **W4.6's `_segment_panel` clone**
(one file, kills 13 of 18 off-token radii), **W1.2's `kWorkspaceLandingConfig`
deletion** (a deletion, closes a P0 seen daily by 6 of 15 roles), and **W3.1**
(closes 2 but **unblocks 8**).

**Largest multiplier that closes nothing directly:** **W2.7**, the canonical-quantity
registry with its source scanner. It retires zero register entries and is the only
thing standing between Phase 2 and a fourteenth definition of "collected" in six
months. Treat its absence as a Phase 2 blocker.

---

## 10. Traceability — every one of the 196 entries is placed

Each register ID appears **exactly once** as *closed by* a wave. Nothing is
unassigned; nothing is assigned twice.

### Phase 1 — 64 entries (23 P0)

| Wave | Closes |
|---|---|
| W1.1 | CERT-001, CERT-002, CERT-006, JOURNEY-007, WIDGET-001, WIDGET-002, E2E-005, E2E-011, E2E-012, E2E-021 |
| W1.2 | JOURNEY-001, JOURNEY-015, JOURNEY-016, WIDGET-011, CERT-003, POLISH-010, E2E-002, E2E-009, E2E-013 |
| W1.3 | E2E-017 |
| W1.4 | JOURNEY-002, JOURNEY-003 |
| W1.5 | POLISH-001 |
| W1.6 | DAI-001, DAI-002, AI-006 |
| W1.7 | DAI-004, DAI-014 |
| W1.8 | E2E-008, XMOD-037 |
| W1.9 | API-119, API-113, API-120, API-121, API-122, API-123, E2E-010 |
| W1.10 | E2E-019, XMOD-008, API-114 |
| W1.11 | OS-007 |
| W1.12 | XMOD-006, E2E-003, API-110, API-112 |
| W1.13 | API-117, API-115, API-109 |
| W1.14 | XMOD-005, XMOD-009 |
| W1.15 | XMOD-007 |
| W1.16 | API-100, API-101, API-102, API-103, API-104, API-111, OS-013 |
| W1.17 | API-118, API-116 |
| W1.18 | E2E-004, E2E-006, E2E-007, E2E-001 |

### Phase 2 — 24 entries (5 P0: OS-001, OS-002, OS-003, OS-004, XMOD-010)

| Wave | Closes |
|---|---|
| W2.1 | OS-006, OS-017, JOURNEY-009, WIDGET-009 |
| W2.2 | OS-002, XMOD-026 |
| W2.3 | OS-003, XMOD-030, E2E-015, E2E-016 |
| W2.4 | OS-004, XMOD-029, XMOD-032 |
| W2.5 | OS-005, XMOD-014, XMOD-035, WIDGET-013, WIDGET-018 |
| W2.6 | XMOD-010, OS-001, XMOD-020, XMOD-038, WIDGET-016, WIDGET-017 |
| W2.7 | *(none — the guard that prevents recurrence)* |

### Phase 3 — 71 entries (5 P0: XMOD-001, XMOD-002, XMOD-003, XMOD-004, OS-009)

| Wave | Closes |
|---|---|
| W3.1 | XMOD-016, SIM-001 |
| W3.2 | XMOD-001 |
| W3.3 | OS-009, XMOD-013, XMOD-018, XMOD-019, XMOD-023, SIM-002, SIM-003, SIM-004, CERT-004, POLISH-002 |
| W3.4 | XMOD-021, XMOD-022, XMOD-024, XMOD-025, XMOD-031, XMOD-036, XMOD-039, OS-020, OS-021 |
| W3.5 | XMOD-002, XMOD-003, XMOD-012, E2E-018 |
| W3.6 | OS-022 |
| W3.7 | XMOD-004 |
| W3.8 | WIDGET-008, WIDGET-010, POLISH-006, POLISH-008 |
| W3.9 | XMOD-015, XMOD-017, XMOD-028, XMOD-033 |
| W3.10 | DAI-003, DAI-005, DAI-006, DAI-007, DAI-008, DAI-009, DAI-010, DAI-011, DAI-012, DAI-013, DAI-015, DAI-016, AI-001, AI-002, AI-003, AI-004, AI-005, OS-018, OS-019 |
| W3.11 | E2E-014, E2E-020 |
| W3.12 | OS-008, OS-010, XMOD-034, API-124 |
| W3.13 | JOURNEY-004, JOURNEY-005, JOURNEY-006, JOURNEY-008, JOURNEY-010, JOURNEY-012, JOURNEY-013, JOURNEY-014, OS-014, OS-016 |

### Phase 4 — 31 entries (0 P0)

| Wave | Closes |
|---|---|
| W4.1 | POLISH-011 |
| W4.2 | POLISH-003, POLISH-004, POLISH-005, POLISH-012, POLISH-017, POLISH-021 |
| W4.3 | WIDGET-003, WIDGET-004, WIDGET-005, WIDGET-006, WIDGET-007, WIDGET-014, POLISH-014 |
| W4.4 | WIDGET-012, WIDGET-015, POLISH-024, OS-012 |
| W4.5 | POLISH-007, POLISH-009, POLISH-015, POLISH-016, POLISH-018 |
| W4.6 | POLISH-019, POLISH-020, POLISH-022, POLISH-023 |
| W4.7 | CERT-005, JOURNEY-011 |
| W4.8 | POLISH-013, OS-011 |

### Owner track (§8) — 4 entries (3 P0)

API-105, API-106, API-107, API-108.

### Excluded by decision (§7) — 2 entries

XMOD-011 (leave-store consolidation — architectural debt, own program) ·
XMOD-027 (Morning Brief — out of scope for v1, removed from the feature count).

**Reconciliation.** Entries: 64 + 24 + 71 + 31 + 4 + 2 = **196** ✓ (register total
196). P0s: 23 (Phase 1) + 5 (Phase 2) + 5 (Phase 3) + 0 (Phase 4) + 3 (owner) + 0
(excluded) = **36** ✓. **Every P0 is in Phase 1, Phase 2, Phase 3 or the owner
track; none is excluded and none is deferred to Phase 4.**

Counts were derived the same way `DEFECT_REGISTER.md` derives its own — mechanically
from the `### <PREFIX>-<NNN> · <severity>` headings, not carried forward by hand.
Re-run the same extraction after any register append and re-check this table; the
register's own status table had already drifted once under concurrent writes.

---

## 11. Sequencing at a glance

```
PHASE 1  (pre-pilot gate)          PHASE 2  (pre-pilot gate)
├─ W1.1  honest async  ◄─ start    ├─ W2.7  registry (report-only) ◄─ start
├─ W1.2  demo residue              ├─ W2.1  year resolver + context
├─ W1.5  logout        (1 day)     ├─ W2.2  student count   ← W2.1
├─ W1.8  'Today'                   ├─ W2.3  grading service
├─ W1.10 3 blockers                ├─ W2.4  exam %          ← W1.14
├─ W1.3  file picker               ├─ W2.5  money totals    ← W2.1
├─ W1.4  role fail-closed ⚠owner   ├─ W2.6  attendance null
├─ W1.6  DAI reachability          └─ W2.7  registry → FAILING at exit
├─ W1.7  DAI honesty     ← W1.6
├─ W1.9  money integrity           PHASE 3
├─ W1.12 identity/trust            ├─ W3.1  scheduler ⚠owner  ◄─ MUST BE FIRST
├─ W1.13 error hygiene             ├─ W3.2  event drain   ← W3.1  §2.2 SEPARATE RELEASE
├─ W1.14 exam predicate            ├─ W3.3  notification rail ← W3.1, W1.11
├─ W1.15 roster join               ├─ W3.13 workspaces    ← W1.4
├─ W1.16 RBAC generated            ├─ W3.4  exit orchestration ← W1.15, W2.5
├─ W1.17 authz-before-validate     ├─ W3.10 DAI  §2.1: DAI-016 → DAI-005, NEVER alone
├─ W1.18 correction dates          ├─ W3.5  HR/leave narrow (parallel payroll first)
└─ W1.11 transactional audit       ├─ W3.6/7/8/9/11/12
   ◄─ ship ALONE, full regression  └─ (do NOT start XMOD-011 — §7.1)

PHASE 4        W4.1 ◄─ MUST precede W4.2, else Finance/SIS/Admissions excluded
               then W4.2 … W4.8, goldens re-baselined once at exit
```

**The three ordering rules that, if broken, make the product worse than today:**

1. **DAI-016 before (or with) DAI-005.** Never DAI-005 alone. The harness enforces
   it; do not weaken the harness. (§2.1)
2. **Scheduler before the domain-event status literal, in separate releases.** (§2.2)
3. **W4.1 before W4.2.** Otherwise the three highest-traffic admin modules are
   silently excluded from every Phase 4 improvement.

**And the one rule that governs the whole document:** a wave is finished when its
**guard** is in CI — the lint, the invariant test, the contract test, the generated
diff — not when the listed sites are edited. The RC phase fixed one unreachable
skeleton, one raw exception dump, one tap target and four dashboard holes, and each
time the class survived the instance. **Every wave here ships a guard, or it ships
the same defect again in six months under a different ID.**

