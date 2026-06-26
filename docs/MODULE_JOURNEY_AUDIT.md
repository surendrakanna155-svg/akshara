# AKSHARA — Module Journey Audit

**Date:** 2026-06-26  ·  **Repo commit:** `6fb48af` (Wave 5)  ·  **Mode:** read-only certification (no fixes applied)
**Method:** one parallel read-only agent per module traced every screen → provider → repository → API path → deployed backend route → RBAC → DB, checked mock-vs-live writes, error/loading/empty states, and real school journeys; cross-referenced existing `docs/*_CERTIFICATION.md`; ran GET-only probes against live VPS `https://akshara.veloraunisexsalon.com` and inspected deployed edge at `/opt/akshara/functions`.
**Companion:** `docs/MODULE_JOURNEY_ROADMAP.md` sequences these findings into execution waves.

> **✅ Journey Wave 0 CLOSED (2026-06-26):** the 8 "fake-data-as-real" items — Inventory `MJ-C1`, AI-Predictions `MJ-H1`, Staff/Employee `MJ-H2`, Notifications `MJ-H3`, Finance `MJ-H4`, Student `MJ-H5`/`MJ-L1`, Exams `MJ-H6` — are fixed, gates green, live-certified **14/14**. See `docs/JOURNEY_WAVE_0_CERTIFICATION.md`. The matching per-module issues below (Inventory "Distribution feature runs on mock", AI "Predictions serves MOCK in production", Staff "Employee Platform shows MOCK", Notifications demo fallbacks, Finance fake refund/scholarship prefills, Student/Exams fabricated-data-on-error) are **RESOLVED**.

> **✅ Journey Wave 1 CLOSED (2026-06-26):** the 7 data-integrity/money-identity items — Homework `MJ-C2` (teacher sees/grades submissions = HOMEW-1), `MJ-H7` (grade reaches student = HOMEW-2), `MJ-H8` (class-targeted delivery = HOMEW-5); Attendance `MJ-H9` (correction apply 0-row UPDATE fixed = ATTEN-1); HR `MJ-H10` (per-employee real profile = HR-1); Finance `MJ-H11` (Razorpay fail-closed = FINAN-1/PAREN-4); Hostel `MJ-M1` (logged visitor appears = HOSTE-2) — are **fixed at root cause, deployed, live-certified 16/16** (analyze 0 · flutter 2389 · deno 707, +27 new tests). Live cert also caught + fixed a latent `text=uuid` 500 in `reviewHomework` (reachable once MJ-C2 surfaced real submissions). See `docs/JOURNEY_WAVE_1_CERTIFICATION.md`. These specific issues below are **RESOLVED**.

> **Scope guard:** This audit does NOT re-open the closed `FINAL_COMPLETION_AUDIT/ROADMAP` (Waves 0–5) or the frozen product roadmap (B1–B11 / P-series). It only records *module-journey gaps* found while proving each module works as a real school would use it. No new features proposed.

## Gate baseline (this session)
| Gate | Result |
|------|--------|
| `flutter analyze` | **0 issues** |
| `flutter test` | **2389 passed / 1 skipped / 0 failed** |
| `deno test` (backend) | **680 passed / 0 failed / 2 ignored** |
| Live VPS `/health` | **ok** (real auth + RBAC confirmed active on probes) |

## Severity totals (per-module, pre-dedup)
**163 findings** — 🔴 Critical: **10**  ·  🟠 High: **42**  ·  🟡 Medium: **58**  ·  ⚪ Low: **53**

> The roadmap de-duplicates cross-cutting findings (e.g. an attendance gap seen from both Teacher and Parent) into single tracked items; counts there are lower.

## Module verdict index
| Code | Module | Verdict | C | H | M | L |
|------|--------|---------|--:|--:|--:|--:|
| `PAREN` | Parent | certified-with-gaps | 2 | 2 | 2 | 1 |
| `STUDE` | Student | certified-with-gaps | 0 | 1 | 3 | 2 |
| `TEACH` | Teacher | gaps-block-cert | 2 | 1 | 3 | 1 |
| `STAFF` | Staff | certified-with-gaps | 0 | 2 | 1 | 3 |
| `HR` | HR | certified-with-gaps | 0 | 3 | 5 | 1 |
| `PRINC` | Principal | certified-with-gaps | 1 | 1 | 1 | 1 |
| `ADMIN` | Admin | certified-with-gaps | 0 | 2 | 3 | 3 |
| `DIREC` | Director | certified-with-gaps | 0 | 0 | 1 | 3 |
| `SA` | Super Admin | certified-with-gaps | 0 | 0 | 2 | 2 |
| `ADMIS` | Admissions | gaps-block-cert | 1 | 2 | 3 | 0 |
| `FINAN` | Finance | certified-with-gaps | 0 | 1 | 2 | 2 |
| `ATTEN` | Attendance | certified-with-gaps | 0 | 2 | 3 | 3 |
| `EXAMS` | Exams | certified-with-gaps | 0 | 2 | 1 | 3 |
| `HOMEW` | Homework | gaps-block-cert | 1 | 4 | 3 | 2 |
| `COMMU` | Communication | gaps-block-cert | 1 | 2 | 1 | 2 |
| `TRANS` | Transport | certified-with-gaps | 0 | 2 | 2 | 3 |
| `HOSTE` | Hostel | certified-with-gaps | 0 | 2 | 4 | 1 |
| `LIBRA` | Library | certified-with-gaps | 0 | 3 | 4 | 2 |
| `INVEN` | Inventory | gaps-block-cert | 2 | 1 | 2 | 1 |
| `MARKE` | Marketing | certified-with-gaps | 0 | 2 | 3 | 4 |
| `AF` | AI Features | certified-with-gaps | 0 | 1 | 2 | 1 |
| `OB` | Organization Builder | certified-with-gaps | 0 | 1 | 0 | 3 |
| `DW` | Dynamic Widgets | certified-with-gaps | 0 | 0 | 2 | 3 |
| `NOTIF` | Notifications | certified-with-gaps | 0 | 2 | 1 | 2 |
| `ALUMN` | Alumni | certified-with-gaps | 0 | 3 | 1 | 2 |
| `VAIP` | Verticals & Industry Packs | certified-with-gaps | 0 | 0 | 3 | 2 |

**Verdict legend:** `certified-with-gaps` = core journeys work, gaps are non-blocking or have safe fallbacks · `gaps-block-cert` = at least one journey is broken/unsafe in a live build and must be fixed before the module can be certified · `mostly-unverified` = could not be confirmed.

---

## Per-module findings

### Parent
**Code:** `PAREN`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Traced every parent screen/provider to its repository and backend route. Verified live deployment via ssh akshara cat parent_router.ts / parent_insights_router.ts and 13 GET-only live probes (token = schoolAdmin scope; /parent/* reads return 403 = correct RBAC, while /parent/messages & /parent/communication/* return genuine 404 = missing routes). Confirmed live vs mock repository selection (config/live_release.json: PARENT_API_ENABLED=true) and grepped for mock/fallback/swallowed-error paths. Not exhaustively exercised: P-21 post-admission onboarding wizard, P-16 certificates, P-19 discipline screens (not present under lib/features/parent), and live GPS for P-15 — flagged transport as partial. student_360 is staff-facing (phase4 providers) and out of parent scope. Cited B3_PARENT_INSIGHTS_CERTIFICATION.md and WAVE2 multi-child cert for already-proven journeys; did not re-litigate those.

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Parent ↔ teacher two-way messaging (inbox + reply/compose) | 🔴 broken | Client calls /parent/messages (GET threads + POST send) and /parent/communication/inbox\|{id}\|read\|acknowledge (parent_api_paths.dart:16-23). NONE of these are in the deployed parent_router.ts (ssh confirmed only experience/acknowledge in POST block; static GET set has no messages/communication). Live probe: /parent/messages=404, /parent/communication/inbox=404. getMessageThreads has no fallback → always [] in live; conversation reply composer swallows the 404 silently (parent_conversation_screen.dart:164). Inbox silently falls back to in-memory MOCK store (api_parent_repository.dart:235-291). |
| Apply for student leave (parent → approval) | 🔴 broken | Client submitLeaveRequest POSTs to /parent/leave (parent_remote_datasource.dart:149-159) with NO fallback (api_parent_repository.dart:122-126). Deployed parent_router.ts POST block (ssh) handles ONLY payments/initiate, payments/confirm, experience/acknowledge — no POST /parent/leave → 404. submit fails before the approval-adapter step; error surfaces to user (parent_mutations_provider.dart:64-67 rethrows ApiFailureException). |
| PTM booking / parent meetings (view + create + follow-ups) | 🔴 broken | parentMeetingsRepositoryProvider is hardcoded to MockParentMeetingsRepository() with NO live branch (repository_providers.dart:389-392). createMeeting/saveNotes/saveSummary/scheduleFollowUp all write only to in-memory _meetings list (mock_parent_meetings_repository.dart:79-188). Parent PTM read (parent_ptm_provider.dart:39-64) and staff /parent-meetings Create Meeting (parent_meetings_screen.dart:43-147) both persist nothing in production. No /parent/ptm or parent-meetings route exists in backend. |
| Fee payment (initiate → confirm → receipt) | 🟡 partial | POST /parent/payments/initiate + /confirm deployed (parent_router.ts:31-39) and back ledger/receipt creation real (payment_service.ts:222-245). BUT no Razorpay SDK in app (pubspec has no razorpay_flutter); client confirmPayment sends only transactionRef, no razorpay_payment_id/signature (parent_requests.dart:39-46). Safe ONLY because RAZORPAY_STUB_MODE defaults true and VPS .env has no RAZORPAY_KEY_ID (confirmed via ssh) → stub capture, no real money. See Issues for the integrity risk if stub is ever disabled. |
| Bus tracking / transport allocation for active child | 🟡 partial | Uses live transportRepositoryProvider.getAllocations (parent_transport_provider.dart:22-24) under parent-scoped query; route exists (TRANSPORT_API_ENABLED). BUT matching to active child leans on MockCanonicalStudentRegistry + name/id heuristics (lines 18-34); a real parent whose child isn't in the mock registry matches only by allocation.sisStudentId==child.id or studentName — fragile for real data. Spec P-15 live GPS/ETA not verified present. |
| Academic summary / printable report | 🟡 partial | GET /parent/experience/summary + /report/printable deployed (parent_experience_router.ts:45-53). Live probe with invalid studentId returned 500 (INTERNAL_ERROR) instead of 404/422 — bad/unknown student id is not handled gracefully (handleGetParentSummary:93-96 wraps any error as 500). |
| Multi-child switching (select child → every per-child read refreshes) | ✅ verified | lib/features/parent/parent_active_child_provider.dart:82-105 selectParentActiveChild() syncs auth.selectedChild + profile child id and explicitly invalidates 14 per-child providers (dashboard/attendance/homework/exams/timetable/fees/receipts/notices/events/leave/profile/communication/experience). parentRepositoryQueryProvider:68-73 attaches activeChildId to every read. Server enforces membership: parent_experience_router.ts:26-35 assertParentChildAccess 403s an unlinked studentId. deno: 'JWT includes parent and student scope claims', 'claimsToTenantParams sets parentUserId'. Cited WAVE2 multi-child cert. |
| Per-child RLS / privacy (parent sees only own child) | ✅ verified | B3_PARENT_INSIGHTS_CERTIFICATION.md:43-66 + 'Per-child privacy' — snapshot/language RLS rewritten to student_guardians pattern; parent sees 0 rows for another student (DB-verified). parent_experience_router.ts:26-35 defense-in-depth child-id check. Live: all /parent/* reads 403 under non-parent schoolAdmin token (RBAC active). |
| Parent Insights (generate AI summary, language, PDF) | ✅ verified | B3 cert 13/13 live. Router paths /parent-insights/generate, /parent-insights/language-preference (GET/PUT), /parent-insights/students/{uuid} all deployed (ssh /opt/akshara/.../parent_insights_router.ts:21-33). Client EvolutionApiPaths match exactly (evolution_api_paths.dart:17-19). Entitlement-gated feature.parent_insights (index.ts:118). deno parent_insights_ai_test 4/4 green. |
| Fees → invoice → collect → receipt reaches parent | ✅ verified | Batch 4 money loop cert + B3. handleReceipts reads real finance_receipts not stale cache (parent_handlers.ts:38-42). deno 'overlayReceiptsFromFinance shapes real receipts for the parent app' green. GET /parent/fees, /parent/receipts deployed (403 under non-parent token = RBAC ok). |
| Attendance / homework / exams / timetable / notices / events visibility | ✅ verified | All GET routes deployed in parent_router.ts staticRoutes (dashboard/attendance/homework/exams/timetable/fees/receipts/notices/events/leave/profile/experience-hub) and live (403 under non-parent token). deno 'parent getSnapshot returns dashboard', 'overlayTimetableSnapshotFromSlots builds parent days' green. Client paths in parent_api_paths.dart match. |

**Live probes:**
- `GET /parent/dashboard (schoolAdmin token)` → 403 — route exists, RBAC denies non-parent scope (expected)
- `GET /parent/messages` → 404 — route NOT deployed (real gap, not RBAC)
- `GET /parent/communication/inbox` → 404 — route NOT deployed (real gap)
- `GET /parent/fees | /receipts | /notices | /events | /leave | /profile | /homework | /experience/hub` → all 403 — routes exist, RBAC active (expected for non-parent token)
- `GET /parent/timetable, /parent/exams` → 403 — deployed + RBAC (expected)
- `GET /parent/experience/summary?studentId=x` → 500 — INTERNAL_ERROR on invalid studentId (error-handling gap)
- `ssh akshara grep parent_router.ts POST block` → only payments/initiate, payments/confirm, experience/acknowledge — no POST /parent/leave, no messages/communication
- `ssh akshara grep parent_insights_router.ts` → generate, language-preference GET/PUT, students/{uuid} GET all deployed (matches client)
- `ssh akshara /opt/akshara/.env RAZORPAY_KEY_ID` → absent → Razorpay stub mode active (no real-money capture path live)

**Issues:**

#### PAREN-1 · Parent↔teacher messaging routes (/parent/messages, /parent/communication/*) not deployed — inbox silently shows MOCK data, reply silently no-ops
- **Module:** Parent
- **User Journey:** Parent ↔ teacher two-way messaging
- **Severity:** 🔴 Critical
- **Description:** The live build runs ApiParentRepository (PARENT_API_ENABLED=true in config/live_release.json). It calls GET/POST /parent/messages and /parent/communication/inbox|{id}|read|acknowledge, but the deployed backend parent_router.ts has none of these routes. getCommunicationInbox catches the 404 and returns ParentCommunicationInboxFallback (in-memory MOCK store) so parents see fabricated 'School messages'. getMessageThreads has no fallback and resolves to []; the Conversations list is always empty so the conversation/reply screen is unreachable, and the reply composer swallows the send 404 (clears input, no error). A real parent cannot message a teacher at all and is shown mock content as if real.
- **Evidence:** parent_api_paths.dart:16-23; parent_remote_datasource.dart:230-297; api_parent_repository.dart:176-201 (no fallback) & 235-291 (mock fallback); parent_conversation_screen.dart:151-167 (catch swallows); ssh /opt/akshara/functions/_shared/parent/parent_router.ts (no messages/communication routes); live probe /parent/messages=404, /parent/communication/inbox=404.
- **Root Cause:** Client message/communication API surface was built but the corresponding backend routes were never added to parent_router.ts (or wired to the existing communication module), and the repository masks the failure with a mock fallback instead of surfacing it.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### PAREN-2 · Parent meetings / PTM is mock-only in production (no live persistence)
- **Module:** Parent
- **User Journey:** PTM booking / parent meetings
- **Severity:** 🔴 Critical
- **Description:** parentMeetingsRepositoryProvider always returns MockParentMeetingsRepository regardless of API mode — there is no ApiParentMeetingsRepository and no backend route. All writes (createMeeting, saveNotes, saveSummary, completeAction, scheduleFollowUp) mutate an in-memory list and are lost on restart; nothing reaches the school backend. Both the parent read view and the staff 'Create Meeting' flow are non-functional for real use.
- **Evidence:** repository_providers.dart:389-392 (hardcoded Mock, no isModuleApiEnabled branch); mock_parent_meetings_repository.dart:79-188; parent_meetings_screen.dart:43-147 (Create Meeting button); parent_ptm_provider.dart:39-64; route_guards.dart:92 gates /parent-meetings but no server route exists.
- **Root Cause:** PTM/parent-meetings module was never given a live API repository or backend route; the mock implementation was left wired in for the live build.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### PAREN-3 · POST /parent/leave not deployed — parent leave application fails in live
- **Module:** Parent
- **User Journey:** Apply for student leave
- **Severity:** 🟠 High
- **Description:** The deployed parent_router.ts POST handler only matches payments/initiate, payments/confirm, experience/acknowledge; it returns 404 for POST /parent/leave. The client submitLeaveRequest posts to /parent/leave with no fallback, so a parent submitting a leave request gets an error and the request (and its downstream approval-center submission) never happens. GET /parent/leave (history) works, masking the gap during a quick demo.
- **Evidence:** parent_remote_datasource.dart:149-159; api_parent_repository.dart:122-126 (no fallback); parent_mutations_provider.dart:88-98; ssh parent_router.ts POST block (lines 30-40) has no /parent/leave; GET handleLeave present at line 55.
- **Root Cause:** Backend exposes only the GET (history) for leave; the POST submit route was never added even though the client and approval workflow depend on it.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### PAREN-4 · Fee confirm can capture without gateway verification if Razorpay stub mode is ever disabled (no app-side SDK)
- **Module:** Parent
- **User Journey:** Fee payment
- **Severity:** 🟠 High
- **Description:** confirmPayment only verifies the Razorpay signature when !stubMode AND razorpay_payment_id AND razorpay_signature are all present (payment_service.ts:210). The Flutter app has no Razorpay SDK and sends only transactionRef (synthesised client-side), so if an operator sets RAZORPAY_STUB_MODE=false (to go live with real payments) without first integrating the SDK, the verification branch is skipped and the intent is captured + a finance receipt created with zero proof of payment — a parent could mark fees paid without paying. Currently safe only because stub mode is on (VPS .env has no RAZORPAY_KEY_ID).
- **Evidence:** payment_service.ts:210-238; razorpay_config.ts:15 (RAZORPAY_STUB_MODE defaults 'true'); parent_requests.dart:39-46 (confirm request has no razorpay fields); parent_remote_datasource.dart:173-183; pubspec has no razorpay_flutter; ssh /opt/akshara/.env shows no RAZORPAY_KEY_ID.
- **Root Cause:** App never integrated the Razorpay Checkout SDK; the confirm endpoint treats missing signature fields as 'skip verification' rather than 'require verification when live', so disabling stub mode silently removes the integrity check.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Data-integrity

#### PAREN-5 · Communication inbox masks backend outage with mock fallback (no honest empty/error state)
- **Module:** Parent
- **User Journey:** Parent ↔ teacher two-way messaging
- **Severity:** 🟡 Medium
- **Description:** Even setting aside the missing routes, api_parent_repository.dart catches ALL exceptions from communication endpoints and substitutes mock store data (inbox), mock read/ack (no-op), violating the 'errors must surface, not swallow' rule. A real backend outage or RLS denial would show the parent stale mock messages and silently 'succeed' on mark-read/acknowledge.
- **Evidence:** api_parent_repository.dart:235-246, 248-262, 264-277, 279-292 (catch(_) → ParentCommunicationInboxFallback); parent_communication_inbox_fallback.dart reads in-memory ParentCommunicationStore (mock).
- **Root Cause:** Defensive mock fallback left in the live repository path instead of propagating failures to the UI's error state.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### PAREN-6 · Transport allocation matching depends on mock canonical registry / name heuristics for real children
- **Module:** Parent
- **User Journey:** Bus tracking / transport allocation
- **Severity:** 🟡 Medium
- **Description:** parentTransportAllocationProvider resolves the active child's bus by consulting MockCanonicalStudentRegistry and matching allocation.sisStudentId==child.id OR studentName==child.name. For a real parent whose child is not in the mock registry, a match only happens on exact id/name; otherwise it returns null (no allocation) even when one exists, so a real enrolled child may show 'no bus'. Spec P-15 live GPS/ETA/driver-contact features were not found wired.
- **Evidence:** parent_transport_provider.dart:18-37; relies on MockCanonicalStudentRegistry (core/repositories/mock).
- **Root Cause:** Child→allocation linkage still routed through mock canonical identity rather than the live student_id linkage; live GPS not implemented.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### PAREN-7 · Invalid/unknown studentId on /parent/experience/summary returns 500 instead of 404/422
- **Module:** Parent
- **User Journey:** Academic summary / printable report
- **Severity:** ⚪ Low
- **Description:** handleGetParentSummary wraps any error from getParentAcademicSummary/generate in a generic 500 INTERNAL_ERROR. A non-existent or malformed studentId (e.g. a child with no academic data yet) yields a 500 to the client rather than a clean empty/404, degrading the error experience and complicating client handling.
- **Evidence:** parent_experience_router.ts:65-97 (catch → 500); live probe /parent/experience/summary?studentId=x returned 500.
- **Root Cause:** No distinct not-found/empty handling around the summary generation; all failures collapse to 500.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

**Strengths (working well):**
- Multi-child switching is robust: selectParentActiveChild invalidates 14 per-child providers and activeChildId is attached to every read (parent_active_child_provider.dart:82-105, :68-73); server defense-in-depth child-id check (parent_experience_router.ts:26-35).
- Per-child RLS privacy is DB-certified (B3 cert: parent sees 0 rows for another student) and all /parent/* reads correctly 403 under a non-parent token (RBAC enforced live).
- Parent Insights is fully live-certified (B3 13/13) with deployed routes matching the client exactly, real AI with deterministic fallback, entitlement gating, and real PDF export.
- Fee/receipt visibility reads real finance_receipts (not stale cache) so office-recorded collections reach the parent app (parent_handlers.ts:38-42; deno overlayReceiptsFromFinance green).
- Core read journeys (dashboard/attendance/homework/exams/timetable/notices/events/profile) are all deployed and gated; payment initiate/confirm routes exist with real ledger+receipt posting and audit/outbox events.
- Strong test coverage in the gate logs for parent permissions, snapshots, insights AI, engagement/adoption analytics, and multi-child auth (selectChild).

---

### Student
**Code:** `STUDE`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Covered the full student_app feature tree (dashboard, timetable, homework+submit, exams/results, report card, attendance, notices, profile, shell/nav) end-to-end: screen -> provider -> repository -> remote datasource -> deployed router -> handler -> RBAC -> DB, with live GET probes on all 7 student endpoints (all correctly 403 for the schoolAdmin token, confirming deployment + student-scope enforcement) and VPS source confirmation of student_router.ts, pilot_operations_router.ts and index.ts. student_360 and SIS were sanity-checked for wiring (routeSis/routeStudent deployed) and rely on prior batch3/batch6 certs rather than re-litigation. No writes were issued. Could not exercise authenticated student-token reads (only a schoolAdmin token was available), so the exact read payload shape returned to a real student was inferred from the snapshot store + mappers rather than observed live.

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Student views school memories | 🔴 broken | Briefing lists 'memories' as a key student journey, but the student bottom-nav shell (student_shell.dart:22-72) has NO memories destination, and /memories route (app_router.dart:670-676, route_guards.dart:58 Permission.viewSchoolMemories) lives in the admin shell. No student entry point to lib/features/memories exists. Students cannot reach memories. |
| Student views/submits homework | 🟡 partial | Read: GET /student/homework deployed & student-scoped (live 403 with admin token). Submit: POST /student/homework/submit IS deployed via routePilotOperations (pilot_operations_router.ts:30, wired index.ts:110 before routeStudent:146; confirmed on VPS index.ts), RBAC student-scope enforced (pilot_operations_handlers.ts:254), persists to homework_submissions with upsert + audit (pilot_operations_repository.ts:200-216), no IDOR (student_id from claims). BUT the UI swallows result: student_homework_screen.dart:130-135 awaits submitStudentHomework with no try/catch, no SnackBar; submitStudentHomework returns null on failure (student_homework_provider.dart:65-73) and the screen never listens to submitStudentHomeworkProvider -> success and failure are both silent to the student. |
| Student views exam results / report card (results-to-student handoff) | 🟡 partial | Exams tab is live: studentExamsProvider -> getExams -> GET /student/exams (deployed, student-scoped 403). BUT the 'View report card' button (student_exams_screen.dart:244-249) opens parent ReportCardScreen fed by studentReportCardProvider, which reads ONLY in-memory mock stores (report_card_provider.dart:13-22: MockCanonicalStudentRegistry.primaryMobileStudentId, ExamAdministrationStore.instance, MockAttendanceSyncStore.instance) -> returns null in a live build -> ReportCardScreen shows empty state (report_card_screen.dart:45-46). Detailed report card never reflects real published results in live. |
| Student views dashboard (greeting, KPIs, schedule strip, homework due, AI CTA) | ✅ verified | studentDashboardProvider -> getDashboard (student_dashboard_provider.dart:241) -> ApiStudentRepository.getDashboard -> GET /student/dashboard. Route deployed & student-scope enforced: live probe GET /student/dashboard with schoolAdmin token -> 403 {"code":"FORBIDDEN","message":"Student data requires student scope"} (requireStudentScope at mobile_read_handlers.ts:40-42). AI CTA is an honest static 'Open AI tutor' link routing to real copilot (student_navigation.dart:38-44). |
| Student views timetable / daily schedule | ✅ verified | studentTimetableFutureProvider -> getTimetable -> GET /student/timetable (handleTimetableSnapshot). Live probe 403 student-scope (deployed). Backed by real student_entities snapshot table (student_scoped_entity_read_store.ts). |
| Student views attendance calendar + insight | ✅ verified | studentAttendanceFutureProvider -> getAttendance(month) -> GET /student/attendance?month=YYYY-MM (handleAttendanceSnapshot, deployed, live 403 student-scope). Note studentAttendanceInsightProvider is a deterministic templated string, not real AI (attendance provider) - acceptable, not claimed as AI. |
| Student views notices | ✅ verified | studentNoticesFutureProvider -> getNotices -> GET /student/notices (handleList 'notice', deployed). Live probe 403 student-scope. |
| Student views profile | ✅ verified | studentProfileProvider -> getProfile -> GET /student/profile (handleSnapshot 'snapshot_profile', deployed, live 403 student-scope). |
| Student 360 dossier (admin-facing student view + PDF export) | ✅ verified | student360ProfileProvider/TimelineProvider -> student360Repository (phase4_providers.dart:22-34); GET /student/360 routes via routeSis (deployed). Export builds real PDF via aksharaReportExportServiceProvider (student_360_screen.dart:48-70). SIS identity integrity certified in batch6. |

**Live probes:**
- `GET /student/dashboard (schoolAdmin token)` → 403 {"code":"FORBIDDEN","message":"Student data requires student scope"} — deployed + RBAC enforced
- `GET /student/homework` → 403 student-scope (deployed, enforced)
- `GET /student/exams` → 403 student-scope (deployed, enforced)
- `GET /student/timetable` → 403 student-scope (deployed, enforced)
- `GET /student/attendance?month=2026-06` → 403 student-scope (deployed, enforced)
- `GET /student/notices` → 403 student-scope (deployed, enforced)
- `GET /student/profile` → 403 student-scope (deployed, enforced)
- `ssh akshara cat /opt/akshara/functions/_shared/student/student_router.ts` → Matches repo; GET-only router with 7 read routes deployed
- `ssh akshara grep pilot/student index.ts` → routePilotOperations imported+wired (line 110) ahead of routeStudent (146); POST /student/homework/submit handled by pilot router — deployed

**Issues:**

#### STUDE-1 · All student screens fall back to fake placeholder data on fetch error/loading (error & loading states are dead)
- **Module:** Student
- **User Journey:** Student opens app while backend is erroring/slow
- **Severity:** 🟠 High
- **Description:** Every student screen drives its loading/error/empty UI off manual StateProviders (studentXLoadingProvider/ErrorProvider/EmptyProvider) that default to false and are NEVER set true anywhere in production code (only the QA persona switcher toggles them). watchRepositoryFuture (repository_future.dart:12-13) returns null whenever those flags are false OR the AsyncValue is loading/error, and every provider then falls back to hardcoded mock/default data: dashboard -> StudentDashboardData.mock() (student_dashboard_provider.dart:255), exams -> StudentExamsData(studentName:'Ravi Kumar',classLabel:'8-A') (student_exams_provider.dart:30-38), attendance -> AttendanceMonthData.mock() (student_attendance_provider.dart:44), timetable -> ParentTimetableData(childName:'Ravi Kumar'...) (student_timetable_provider.dart:33-41), profile -> 'Ravi Kumar' default (student_profile_provider.dart:26-39). Net effect in live: on any real backend error the student silently sees fabricated placeholder data with another child's name, and the well-built AksharaErrorState widgets (e.g. student_exams_screen.dart:44, student_attendance_screen.dart:56) never render. The 'retry' buttons only flip a flag that was never set, so they are no-ops.
- **Evidence:** repository_future.dart:5-14; grep shows no '.state = true' for any student*ErrorProvider/LoadingProvider in lib/ outside QA; fallbacks at student_dashboard_provider.dart:255, student_exams_provider.dart:30-38, student_attendance_provider.dart:44, student_timetable_provider.dart:33-41.
- **Root Cause:** Mobile read screens were wired to manual demo/QA state flags instead of binding loading/error/empty directly to the FutureProvider AsyncValue (.when/.maybeWhen). The async lifecycle is never propagated to the flags.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### STUDE-2 · Homework submit gives no success or failure feedback to the student
- **Module:** Student
- **User Journey:** Student taps 'Submit' on a pending homework item
- **Severity:** 🟡 Medium
- **Description:** onSubmit (student_homework_screen.dart:130-135) is a bare `await submitStudentHomework(ref, id)` with no try/catch and no ScaffoldMessenger/SnackBar. submitStudentHomework (student_homework_provider.dart:65-73) returns false on failure and the underlying notifier swallows the ApiFailureException inside AsyncValue.guard, returning state.valueOrNull. The screen never `ref.listen`s submitStudentHomeworkProvider. So on success there is no confirmation (only a silent list refresh) and on failure (e.g. server 500, offline) there is zero indication the submission did not happen. Backend itself is correct and live (POST /student/homework/submit, student-scope, persists + audits).
- **Evidence:** student_homework_screen.dart:128-136 (no try/catch/SnackBar); student_homework_provider.dart:65-73 (returns bool, no surface); student_mutations_provider.dart:43-59 (AsyncValue.guard swallows); no ref.listen on submit provider in the screen.
- **Root Cause:** Write mutation result/error is not surfaced in the UI; screen treats fire-and-forget submit as success-only.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### STUDE-3 · Detailed 'View report card' screen reads only mock stores, ignoring live published results
- **Module:** Student
- **User Journey:** Student taps 'View report card' after results are published
- **Severity:** 🟡 Medium
- **Description:** studentReportCardProvider is built entirely from in-memory mock singletons (MockCanonicalStudentRegistry.primaryMobileStudentId, ExamAdministrationStore.instance, MockAttendanceSyncStore.instance) and returns null unless the mock store has results (report_card_provider.dart:11-24). In a live build (STUDENT_API_ENABLED=true per config/live_release.json:10) those mock stores are empty, so the dedicated ReportCardScreen shows the 'no report card' empty state even though the same student's live exam results render in the Results tab via getExams. Inconsistent: term report card never reflects real data.
- **Evidence:** report_card_provider.dart:3-24 (mock-only imports & usage); consumed at student_exams_screen.dart:248 (ReportCardScreen(provider: studentReportCardProvider)); ReportCardScreen null -> empty state report_card_screen.dart:45-46; live mode confirmed config/live_release.json:10, scripts/run_live.sh:45.
- **Root Cause:** The detailed report-card view was never migrated from the legacy mock exam-administration store to the live student repository; only the in-tab results were wired.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### STUDE-4 · No student-facing entry point to School Memories despite it being a listed journey
- **Module:** Student
- **User Journey:** Student wants to browse school memories/photos
- **Severity:** 🟡 Medium
- **Description:** The memories feature (lib/features/memories) and /memories route exist but are gated to admin personas via Permission.viewSchoolMemories (route_guards.dart:58) and mounted in the admin shell (app_router.dart:670-676). The student bottom-nav shell (student_shell.dart primary+more destinations) has no memories tile, and no student navigation case routes to it (student_navigation.dart). Students cannot view memories.
- **Evidence:** student_shell.dart:22-72 (no memories destination); route_guards.dart:58 (admin permission); no memories case in student_navigation.dart:14-56.
- **Root Cause:** Memories was built as an admin/staff publishing surface; a read-only student consumption surface/route was never added even though the journey is in scope.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Cross-module

#### STUDE-5 · Homework screen app-bar subtitle is hardcoded to 'Ravi Kumar · 8-A'
- **Module:** Student
- **User Journey:** Any logged-in student opens the Homework (Learn) tab
- **Severity:** ⚪ Low
- **Description:** studentHomeworkProvider hardcodes studentName:'Ravi Kumar', classLabel:'8-A', unreadNotifications:2 (student_homework_provider.dart:56-63) and the screen renders it directly in the app-bar subtitle (student_homework_screen.dart:33). Unlike dashboard/exams/profile which fall back to live data, this provider has no live source for the name/class at all, so every real student sees 'Ravi Kumar · 8-A' on the Homework screen header regardless of identity.
- **Evidence:** student_homework_provider.dart:56-63; student_homework_screen.dart:24,33 (subtitle: '${data.studentName} · ${data.classLabel}').
- **Root Cause:** Homework header model was never bound to the live profile/dashboard identity; the placeholder constant was left in.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### STUDE-6 · No contract/integration test asserts the live student write route exists (gap that would mask future drift)
- **Module:** Student
- **User Journey:** N/A (test coverage gap)
- **Severity:** ⚪ Low
- **Description:** student_write_contract_test only exercises the MOCK repository and DTO snake_case serialization (gate log: 'Mock student write repository submitHomework returns submitted item', 'homework submit request uses snake_case keys'). There is no test asserting POST /student/homework/submit is actually routed server-side. It happens to be wired today via routePilotOperations, but a future removal/rename of that pilot route would silently break submit with green tests. Read routes are covered by deno sis/student router tests but the cross-router (pilot) student write has no client<->server path assertion.
- **Evidence:** gates/flutter_test.log student_write_contract_test entries (mock-only); submit route lives in pilot_operations_router.ts not student_router.ts; no deno test referencing handleStudentHomeworkSubmit path string found in pilot tests grep.
- **Root Cause:** Student write path spans two routers (pilot owns the POST); contract tests target the student module only.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

**Strengths (working well):**
- All seven student read endpoints (dashboard, attendance, homework, exams, timetable, notices, profile) are deployed on the live VPS and correctly enforce student scope — every GET with the schoolAdmin token returns 403 'Student data requires student scope' (requireStudentScope, mobile_read_handlers.ts:40-42), proving RBAC works.
- Reads are real DB-backed via student_entities snapshot/list tables scoped by organization_id + school_id + student_id (student_scoped_entity_read_store.ts) — no mock leakage in the live read repository (ApiStudentRepository delegates straight to the remote datasource).
- Homework submission backend is genuinely live: POST /student/homework/submit authenticates, enforces student scope, upserts into homework_submissions with no IDOR (student_id taken from JWT claims), and writes an audit row (pilot_operations_handlers.ts:248-278, repository.ts:200-216).
- Dashboard AI 'insight' is an honest static CTA that opens the real copilot rather than a fabricated AI claim (student_dashboard_provider.dart:228-232 comment STU-6; routed via student_navigation.dart:38-44).
- Navigation is comprehensively wired: every dashboard actionId (attendance, full_schedule, homework_list, exams, report_card, progress, notices, profile, notifications, ai_quiz/ai_assistant, period_* prefix) maps to a real route (student_navigation.dart).
- Screens are responsive (tablet breakpoint + max-content-width constraints) and use AksharaEmptyState for genuinely empty data sets (e.g. homework filter empty, exams not published).

---

### Teacher
**Code:** `TEACH`  ·  **Verdict:** `gaps-block-cert`

_Coverage:_ Traced every teacher screen/provider/repository to its client path and the deployed router (supabase/functions/api/index.ts + _shared routers), grepped repo + live /opt/akshara source, and ran 18 read-only live GET probes against https://akshara.veloraunisexsalon.com with the schoolAdmin token. Reads/writes wire fully traced. NOT exhaustively verified (out of read-only scope / lower priority): teacher messaging thread persistence end-to-end (communication-module owned), student-risk screen internals, settings/profile screens, and POST-time RBAC denial behavior (cannot POST in audit). Question-paper builder cited from existing cert, not re-litigated. Global gates: flutter analyze 0, flutter test 2389 pass, deno 680 pass (per briefing) — but teacher tests are mock-only and do not catch the live 404s/read-staleness documented here."

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Enter exam marks -> process -> publish results to parent/student | 🔴 broken | Entire teacher exam workflow is dead on live. (1) The exam picker teacherMarksExamOptionsProvider calls getMarksEntryExams -> GET /teacher/exams/marks-entry (teacher_api_paths.dart:11), but the deployed teacher router only registers /teacher/exams/marks (teacher_router.ts:28). Live probe: GET /teacher/exams/marks-entry -> 404 NOT_FOUND. With no options, teacherActiveExamIdProvider is null (teacher_exams_provider.dart:37-46) and the screen is unusable. (2) Even with an exam, the 'Submit for verification' button calls processExamResults -> POST /teacher/exams/{id}/process and Publish calls publishExamResults -> POST /teacher/exams/{id}/publish (teacher_remote_datasource.dart:179-199). NO router matches these (pilot router has no process/publish; backend equivalents live at /academics/exams/{id}/process\|publish, exam_administration_router.ts:72,78). Live probe GET /teacher/exams/{id}/publish and /process -> 404. Mark UPDATE (PUT /teacher/exams/marks/{id}) IS wired (pilot_operations_handlers.ts:381). Exam-marks read is static snapshot (handleList('exam_mark')). |
| Structured parent communication + subject-concern escalation | 🔴 broken | teacher_shell.dart:63 exposes Parent Communication as a primary nav tile. sendTeacherParentCommunication -> sendParentCommunication -> POST /teacher/parent-communication; flagSubjectConcern/listPendingConcerns/dismiss -> /teacher/parent-communication/concerns (teacher_remote_datasource.dart:201-273). NO router handles /teacher/parent-communication anywhere (grep across repo + deployed /opt/akshara: only appears in parent_insights_ai.ts text, not a route). routeCommunication prefix list is /teacher/messages only (communication_router.ts:91-99). Live probe GET /teacher/parent-communication -> 404 NOT_FOUND. Entire feature non-functional on live. |
| Mark class attendance (draft + submit) | 🟡 partial | WRITE works: client POST /teacher/attendance/submit -> routePilotOperations -> handleTeacherAttendanceSubmit persists to attendance_sessions/records + enqueues guardian alerts (pilot_operations_handlers.ts:108-169). Live probe GET /attendance/sessions returns real submitted sessions (5-A, real takenBy UUID, status submitted). BUT the teacher's own READ-BACK is broken: /teacher/attendance/students and /teacher/attendance/classes are served by createTeacherMobileReadHandlers (teacher_handlers.ts:11-22) which reads STATIC snapshots from teacher_entities table (entity_read_store.ts:66 'SELECT payload FROM teacher_entities') with NO live overlay. Live probe /teacher/attendance/students returns empty seed roster ('8-A', students:[]). So a teacher never sees their real class roster nor their own just-submitted marks. |
| Set / grade homework | 🟡 partial | Create WRITE works: POST /teacher/homework -> handleTeacherHomeworkCreate inserts homework_assignment (pilot_operations_handlers.ts:312-379). Grade WRITE works: POST /teacher/homework/submissions/{id}/review -> handleTeacherHomeworkReview (pilot_operations_handlers.ts:280-310). BUT the homework LIST the teacher reads (/teacher/homework GET -> handleList('homework_assignment'), teacher_handlers.ts:24) comes from the static teacher_entities snapshot, not the homework_assignments table; a just-created homework will not appear. Live probe returns fixed seed ('Algebra worksheet', hw_1). |
| Teacher leave apply + class-teacher leave approvals | 🟡 partial | Leave submit WRITE works: POST /teacher/leave -> handleTeacherLeaveSubmit (pilot_operations_handlers.ts:171+). Class-teacher approve/reject uses the certified approval center (teacher_leave_approvals_provider.dart:29-51) with class-teacher scope guard. BUT leave HISTORY read (/teacher/leave GET -> handleList('leave_request')) is the static snapshot; a just-submitted leave won't appear. Live probe returns fixed seed (leave_1). |
| Teacher <-> parent messaging | 🟡 partial | Send works: POST /teacher/messages -> handleTeacherSendMessage (communication_router.ts:79). Threads GET is routed (communication_router.ts:76) but resolves to handleTeacherMessageThreads. Live probe /teacher/messages returns thread items. Threads read source not verified to overlay real conversation persistence end-to-end; messaging is communication-module owned, lower priority for this audit. |
| Teacher dashboard (greeting, AI insight, pending tasks, today) | 🟡 partial | GET /teacher/dashboard works (live probe returns aiInsight, todayClasses, pendingTasks) but is a STATIC snapshot (handleSnapshot 'snapshot_dashboard', no overlay). pendingTasks:[] and todayClasses:[] are seed values, not derived from the teacher's real attendance-pending classes or timetable. AI insight text is canned ('2 classes need attendance today'). |
| View timetable / today schedule | ✅ verified | GET /teacher/timetable -> handleTimetableSnapshot which DOES overlay real slots via overlayTimetableSnapshotFromSlots with view:teacher (mobile_read_handlers.ts:707-720). Live probe returns a real per-day timetable structure. This is the only teacher read with a live overlay. |
| Build question papers (AI bank-first) | ✅ verified | Out of the teacher feature dir (lib/features/education) and separately certified: 'Question Intelligence LIVE CERTIFIED' (live 20/20, real AI gap-fill, governance + publish gate, principal-only validation). Live probe GET /education/question-papers returns real DB rows (real UUIDs, Grade 10 Mathematics, chapters). Not re-litigated. |
| Submit attendance correction (post-submission) | ✅ verified | SubmitAttendanceCorrectionNotifier (teacher_mutations_provider.dart:368-452) creates via attendanceCorrectionRepository -> POST /attendance/corrections (routed in attendance_router.ts) + approval-center adapter. Live probe GET /attendance/corrections returns real corrections. RBAC client-gated by Permission.submitAttendanceCorrection. Approval center is independently certified. |

**Live probes:**
- `GET /teacher/dashboard` → 200 static snapshot: pendingTasks:[], todayClasses:[], canned aiInsight
- `GET /teacher/attendance/classes` → 200 static seed (8-A Mathematics, pendingCount:5)
- `GET /teacher/attendance/students` → 200 but empty seed roster (students:[], '8-A') — not real class roster nor submitted marks
- `GET /teacher/homework` → 200 static seed (hw_1 Algebra worksheet)
- `GET /teacher/exams/upcoming` → 200 static seed (exam_1)
- `GET /teacher/exams/marks` → 200 static seed (mark_1 Ravi Kumar 42)
- `GET /teacher/exams/marks-entry` → 404 NOT_FOUND — exam picker dead; route not deployed
- `GET /teacher/exams/EX1/process` → 404 NOT_FOUND
- `GET /teacher/exams/EX1/publish` → 404 NOT_FOUND
- `GET /teacher/timetable` → 200 with real per-day overlay (overlayTimetableSnapshotFromSlots)
- `GET /teacher/leave + /teacher/leave/balance` → 200 static seed (leave_1; balances)
- `GET /teacher/messages` → 200 thread items returned
- `GET /teacher/parent-communication` → 404 NOT_FOUND — feature has no backend route
- `GET /attendance/sessions` → 200 REAL submitted sessions (5-A, real takenBy UUID, status submitted) — proves writes persist
- `GET /attendance/corrections` → 200 real corrections (att_corr_3)
- `GET /education/question-papers` → 200 real DB rows (Grade 10 Mathematics, real UUIDs)
- `ssh akshara grep deployed routers` → Confirmed teacher_router.ts deployed is GET-only with /teacher/exams/marks (no marks-entry); parent-communication absent from all deployed routers

**Issues:**

#### TEACH-1 · Teacher reads return static seed snapshots with no live overlay (except timetable)
- **Module:** Teacher
- **User Journey:** Mark class attendance; Set/grade homework; Enter exam marks; View leave history; Dashboard
- **Severity:** 🔴 Critical
- **Description:** createTeacherMobileReadHandlers.handleSnapshot/handleList read pre-seeded JSON from the teacher_entities snapshot table and never overlay real operational data. Unlike parent/student handlers (which call overlayExamsSnapshotFromResults / overlayAttendanceSnapshotFromRecords / overlayFeesSnapshotFromFinance / overlayReceiptsFromFinance), the teacher variant only overlays timetable. Result: a teacher's attendance roster, homework list, exam marks, upcoming exams, leave history and dashboard all show fixed seed data and never reflect the teacher's own writes (which DO persist) or the real class data. Verified the writes persist via live GET /attendance/sessions (real submitted sessions) while GET /teacher/attendance/students returns an empty seed roster.
- **Evidence:** supabase/functions/_shared/entity_read/mobile_read_handlers.ts:661-772 (teacher handleSnapshot/handleList have no overlay branch; only handleTimetableSnapshot overlays). teacher_read_repository.ts:6 createEntityReadStore('teacher_entities'). entity_read_store.ts:66 'SELECT payload FROM teacher_entities'. Live: GET /teacher/attendance/students -> students:[], '8-A'; GET /attendance/sessions -> real submitted 5-A session.
- **Root Cause:** Teacher read layer was built as snapshot-only at Batch 3; the live-overlay work that fixed parent/student reads (Batch 3/4) was never extended to the teacher persona.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### TEACH-2 · Teacher exam workflow endpoints do not exist (marks-entry, process, publish) -> 404
- **Module:** Teacher
- **User Journey:** Enter exam marks -> process -> publish results to parent/student
- **Severity:** 🔴 Critical
- **Description:** The teacher app's exam workflow points at /teacher/exams/marks-entry (load exams), /teacher/exams/{id}/process (submit for verification) and /teacher/exams/{id}/publish (publish), none of which are registered in any deployed router. The exam picker therefore returns 404 and renders no exams, making the whole marks-entry/process/publish flow unreachable from the teacher app. The backend capability exists but under the admin path /academics/exams/{id}/process|publish.
- **Evidence:** Client: teacher_api_paths.dart:11,27,28; teacher_remote_datasource.dart:68-76,179-199; teacher_exams_provider.dart:27-46 (workflow keyed on getMarksEntryExams). Router gap: teacher_router.ts:28 only /teacher/exams/marks; pilot_operations_router.ts has no process/publish; backend equivalents at exam_administration_router.ts:72,78 under /academics/exams. Live probes: GET /teacher/exams/marks-entry, /teacher/exams/EX1/process, /teacher/exams/EX1/publish all -> 404 NOT_FOUND.
- **Root Cause:** Path contract drift: teacher client paths diverge from the deployed router; teacher exam endpoints were never built/mounted while the screen assumes them.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### TEACH-3 · Teacher parent-communication + subject-concern endpoints have no backend route -> 404
- **Module:** Teacher
- **User Journey:** Structured parent communication + subject-concern escalation
- **Severity:** 🟠 High
- **Description:** Parent Communication is a primary teacher nav tile, but every call (send, flag concern, list concerns, dismiss) targets /teacher/parent-communication[/concerns], which no router handles. The feature is fully dead on live.
- **Evidence:** teacher_shell.dart:63; teacher_remote_datasource.dart:201-273; teacher_api_paths.dart:17-18. No router matches: grep of supabase/functions and deployed /opt/akshara shows /teacher/parent-communication only in parent_insights_ai.ts (text). communication_router.ts:91-99 prefix list excludes it. Live probe GET /teacher/parent-communication -> 404 NOT_FOUND.
- **Root Cause:** Backend handler/route for the structured parent-communication + concern-escalation feature was never implemented; only the Flutter side shipped.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### TEACH-4 · Teacher write handlers gate only on school scope, not granular permission or class assignment
- **Module:** Teacher
- **User Journey:** Mark class attendance; Grade homework; Update exam marks; Create homework
- **Severity:** 🟡 Medium
- **Description:** All teacher pilot write handlers authorize solely by claims.scope==='school' && school_id; they perform no granular permission check (markAttendance/enterMarks/gradeHomework) and no verification that the caller is the assigned teacher of the target class/exam. The RBAC route inventory itself records permission:null for POST /teacher/homework. Any school-scoped account (incl. schoolAdmin or unrelated staff) can mark attendance for any class_id, edit any exam mark, or grade any submission. Tenant isolation via RLS still holds, but intra-school role separation does not.
- **Evidence:** pilot_operations_handlers.ts:72-74,114-116,287-289,318-320,388-390 (scope-only checks). rbac_route_inventory.ts:44 {POST /teacher/homework, permission:null}. class_id taken from request body with no assignment check (handleTeacherAttendanceSubmit:124-132).
- **Root Cause:** Pilot fast-path handlers were written scope-only to ship the core loop; granular teacher permissions and class-assignment binding were deferred.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** RBAC

#### TEACH-5 · Teacher dashboard insight/pending-tasks/today are canned seed, not derived
- **Module:** Teacher
- **User Journey:** Teacher dashboard
- **Severity:** 🟡 Medium
- **Description:** /teacher/dashboard is a static snapshot: AI insight text, pendingTasks and todayClasses are fixed seed values, not computed from the teacher's real pending-attendance classes, timetable, or homework reviews. Misleads the teacher about what actually needs doing.
- **Evidence:** teacher_handlers.ts:7-9 handleSnapshot('snapshot_dashboard') with no overlay. Live probe: pendingTasks:[], todayClasses:[], aiInsight 'message':'2 classes need attendance today.' (canned).
- **Root Cause:** Same snapshot-only read layer as the Critical read gap; dashboard derivation never built.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### TEACH-6 · Teacher tests only exercise the mock repository, masking live wire-gaps
- **Module:** Teacher
- **User Journey:** All teacher journeys (test coverage)
- **Severity:** 🟡 Medium
- **Description:** Teacher coverage is mock-contract tests (DTO<->mock round-trips). E.g. 'Mock teacher write repository updateExamMark persists mark in getExamMarks' passes because the mock write and mock read share state, hiding the fact that on live the read is a static snapshot disconnected from the write and that marks-entry/process/publish/parent-communication 404. No test asserts the deployed router actually serves the client's paths.
- **Evidence:** gates/flutter_test.log: teacher_repository_contract_test.dart and teacher_write_contract_test.dart entries all say 'matches mock output' / 'Mock teacher write repository ...'. No live-route contract test for teacher write paths.
- **Root Cause:** Test strategy validated mapping/mocks but never asserted client path == deployed router path for teacher writes.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Live-deploy-drift

#### TEACH-7 · Attendance error-state retry only resets a local flag, does not re-fetch
- **Module:** Teacher
- **User Journey:** Mark class attendance (error recovery)
- **Severity:** ⚪ Low
- **Description:** On attendance load failure the error state's onRetry just sets teacherAttendanceErrorProvider=false rather than invalidating/refetching the underlying providers; if the failure is real the user sees stale/empty rather than a genuine retry.
- **Evidence:** teacher_attendance_screen.dart:46-51 (onRetry sets error provider to false only).
- **Root Cause:** Error flag modeled as local UI state instead of derived from the async provider.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

**Strengths (working well):**
- Attendance and homework WRITES genuinely persist to real operational tables on live (verified GET /attendance/sessions returns real submitted sessions; pilot_operations_handlers persists to attendance_sessions/records, homework_assignments) and absence alerts are enqueued to guardians.
- Timetable read is correctly overlaid with real slots for the teacher view (overlayTimetableSnapshotFromSlots), unlike the other teacher reads.
- Exam publish has layered governance on the client: examApprovalRequiredProvider blocks direct publish and routes to verification/approval, plus an explicit RBAC pre-check (Permission.publishExamResults / submitExamResults) before any call (teacher_mutations_provider.dart:219-326).
- Attendance-correction and class-teacher leave-approval flows reuse the independently-certified approval center with correct class-teacher scope guards.
- Question-paper building is real and separately LIVE CERTIFIED (Question Intelligence 20/20); live GET /education/question-papers returns real DB rows.
- Screens have consistent loading / empty / error scaffolding (AksharaLoadingState / AksharaEmptyState / AksharaErrorState) using the design-system tokens.
- All mutations route through a single _runMutation wrapper that records an audit event and invalidates the relevant reads, and every mutation maps exceptions to ApiFailureException so failures surface.

---

### Staff
**Code:** `STAFF`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Covered all 6 module Flutter files (employee_platform_screen, employee_360_screen, employee_models, staff_login_screen, staff_otp_screen, staff_login_provider) and all 5 backend files (_shared/employee/*). Traced each screen->provider->repository->remote path->deployed router->handler->RBAC->repository SQL. Confirmed live deployment via ssh and ran 4 GET live probes (dashboard, list, intelligence/dashboard, 360) all returning real data. Verified flag wiring in live_release.json + repository_config.dart, route registration in app_router.dart, RBAC in route_guards.dart and role_permissions.dart, and test coverage via gate logs + test/ grep. Did NOT re-litigate Batch-2 auth internals (cited). Read-only; no writes/edits.

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Employee platform dashboard + employee list (HR/admin) | 🔴 broken | Backend is live and returns real data (GET /employees/dashboard -> totalEmployees:2; GET /employees -> 2 real employees with UUIDs), but EMPLOYEE_API_ENABLED is ABSENT from config/live_release.json, so employeeRepositoryProvider falls back to MockEmployeeRepository (repository_providers.dart:453-458, flag default false at repository_config.dart:169-172). In the live release build the Employee Platform screen shows MOCK data while a working live backend sits unused. |
| Assign role to employee (write) | 🔴 broken | Full stack exists: POST /employees/:id/roles (employee_router.ts:39-42) -> handleAssignEmployeeRole with manageEmployees RBAC + audit (employee_handlers.ts:130-177); client assignRole present (api_phase4_repositories.dart:116). But NO UI calls assignRole/getEmployee anywhere (grep of lib/features returned nothing); the only employee screen is read-only list. The write journey is unreachable by any user. |
| Reach employee management from app navigation | 🔴 broken | Neither RouteNames.employees nor RouteNames.employee360 has any nav tile / dashboard card / button. grep across lib (excluding route_names/app_router/navigation/guards) found zero entry points; only the AppBar title literal in employee_platform_screen.dart:20. Screens are reachable only by manually typing the URL. |
| Staff identity / login (email or mobile -> OTP -> session) | ✅ verified | staff_login_screen.dart -> staff_login_provider.dart sendOtp/verifyOtp -> ApiStaffOtpWorkflow delegates to AuthRepository.login/verifyOtp (lines 162-200). In live_release.json AUTH_API_ENABLED=true so ApiStaffOtpWorkflow is selected (staffOtpWorkflowProvider line 203). completeStaffLogin persists server-issued claims+permissions (auth_provider.dart:371-416). Integration-tested: test/integration/auth/auth_flow_integration_test.dart:31-51, f1_auth_rbac_integration_test.dart:62-67. Server auth path covered by Batch-2 safe-login cert. |
| Staff role selection drives capability gating | ✅ verified | Demo role dropdown is hidden in live (staff_login_screen.dart:191 `if (!authApiActive)`); in live the active erpRole+permissions come from the server response (ApiStaffOtpWorkflow.verifyOtp reads result.user.erpRole/permissions, staff_login_provider.dart:182-192). setStaffErpRole/capability gating tested in auth_staff_session_test.dart:40-61. |
| Employee 360 profile + school workload intelligence (HR/admin) | ✅ verified | employee_360_screen.dart -> employee360Provider/employeeIntelligenceDashboardProvider (phase5_providers.dart:25-38) -> apiEmployeeIntelligenceRepository (PHASE5_API_ENABLED=true in live_release.json:36). Client paths /employees/$id/360 and /employees/intelligence/dashboard (phase5_remote_datasource.dart:46,56) match deployed router (employee_router.ts:34-37,27-29). Live probe returned real data: GET /employees/69ba2553.../360 -> profile+workload{workloadPercent:35,burnoutRisk:low}; GET /employees/intelligence/dashboard -> avgWorkloadPercent:50. RBAC requireIntelRead=viewEmployeeIntelligence (employee_intelligence_handlers.ts:17-21). |

**Live probes:**
- `GET /employees/dashboard (schoolAdmin token)` → 200, real data: totalEmployees:2, activeEmployees:2, roleDistribution schoolAdmin x1, workloadIndex:20
- `GET /employees` → 200, 2 real employees (Staging School Admin EMP-a3000000, Staging Teacher A EMP-d1000000) with UUIDs
- `GET /employees/intelligence/dashboard` → 200, avgWorkloadPercent:50, workloadBalancing for 2 employees, empty teachersNeedingSupport/highPerformers
- `GET /employees/69ba2553-33c6-4d99-937c-d456928d61ab/360` → 200, full profile+roles[schoolAdmin primary]+workload{35%,burnoutRisk low,overload 28}+attendance/leave/performance
- `ssh akshara grep routeEmployee /opt/akshara/functions/api/index.ts` → present (index.ts:44 import, :101 registered) -> employee routes are really deployed

**Issues:**

#### STAFF-1 · Employee Platform shows MOCK data in live build (EMPLOYEE_API_ENABLED missing from live_release.json)
- **Module:** Staff
- **User Journey:** HR/admin opens Employee Platform to see real staff count + roster
- **Severity:** 🟠 High
- **Description:** config/live_release.json (lines 5-49) sets ENABLE_API_MODE=true and enables ~30 module flags but omits EMPLOYEE_API_ENABLED. employeeApiEnabledProvider defaults false (repository_config.dart:167-173), so employeeRepositoryProvider returns MockEmployeeRepository (repository_providers.dart:453-458) even in production. The deployed backend works (live GET /employees/dashboard -> totalEmployees:2; GET /employees -> 2 real rows), so users see fabricated mock numbers instead of their real employees. Note: the related PHASE5 (Employee 360) path IS correctly enabled, so this is an inconsistent half-wired module.
- **Evidence:** live_release.json has no EMPLOYEE_API_ENABLED key; repository_config.dart:169-172 default false; repository_providers.dart:454 isModuleApiEnabled(employeeApiEnabledProvider); live probe of /employees + /employees/dashboard returned real data with UUIDs.
- **Root Cause:** Module flag omitted from canonical live dart-define-from-file config despite backend being deployed.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Live-deploy-drift

#### STAFF-2 · Employee management screens are orphaned (no navigation entry)
- **Module:** Staff
- **User Journey:** Any staff/admin tries to navigate to employee management
- **Severity:** 🟠 High
- **Description:** Both /employees (Employee Platform) and /employees/360/:id (Employee 360) are route-registered and RBAC-guarded but have no menu item, dashboard tile, or button anywhere in the app. A real school admin cannot reach the employee roster, 360 profile, or workload intelligence except by manually typing a URL — effectively dead features.
- **Evidence:** grep of lib (excluding route definitions/guards) for RouteNames.employees / RouteNames.employee360 / employee360Path found zero UI navigation references; only employee_platform_screen.dart:20 AppBar title.
- **Root Cause:** Screens built and routed but never linked into the app shell/menu.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### STAFF-3 · Employee role-assignment write path has no UI
- **Module:** Staff
- **User Journey:** HR assigns/changes an employee's ERP role
- **Severity:** 🟡 Medium
- **Description:** POST /employees/:id/roles is deployed with manageEmployees RBAC + audit (employee_handlers.ts:130-177) and the Flutter client assignRole exists (api_phase4_repositories.dart:116), but no screen exposes it. The Employee Platform screen only lists names+status with no tap target or detail navigation, so the entire write journey (and getEmployee detail) is dead code.
- **Evidence:** grep of lib/features for assignRole/getEmployee (excluding interfaces/mock/api) returned nothing; employee_platform_screen.dart:42-57 renders a non-tappable ListTile list.
- **Root Cause:** Backend+client capability shipped without the corresponding UI surface.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### STAFF-4 · Mock OTP value '654321' shown as hint in production OTP field
- **Module:** Staff
- **User Journey:** Real staff member enters the OTP they received
- **Severity:** ⚪ Low
- **Description:** staff_otp_screen.dart:137 unconditionally sets hintText: MockStaffOtpWorkflow.validOtp ('654321') regardless of build mode. In a live build, real staff see '654321' as placeholder text in the OTP box, which is confusing and leaks the demo OTP into production UI. It is a hint (not auto-filled), so not exploitable, but unprofessional.
- **Evidence:** staff_otp_screen.dart:137 hintText: MockStaffOtpWorkflow.validOtp; MockStaffOtpWorkflow.validOtp='654321' (staff_login_provider.dart:77). Same pattern in staff_login_screen.dart error hint at provider line 320-321 (mock-gated correctly there, but the OTP hint is not gated).
- **Root Cause:** Demo placeholder not gated behind mock/demo build flag.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### STAFF-5 · Deep-link/refresh to /staff/otp loses login state and verifies with empty identifier
- **Module:** Staff
- **User Journey:** Staff refreshes the OTP page (web) or deep-links directly to it
- **Severity:** ⚪ Low
- **Description:** StaffOtpScreen receives identifier from the URL query, but verifyOtp uses staffLoginProvider state (staff_login_provider.dart:304-316). On a fresh app/route load that provider is reset to default (identifier='', type=email), so verification would be sent for an empty/wrong identifier. The screen does not re-seed provider state from the URL params.
- **Evidence:** app_router.dart:180-191 builds StaffOtpScreen from query params only; verifyOtp (staff_login_provider.dart:308-315) reads state.identifier/state.identifierType, not widget props; no initState resync in staff_otp_screen.dart.
- **Root Cause:** OTP step relies on in-memory provider state not reconstructable from the route URL.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### STAFF-6 · No backend deno test for employee handlers/router RBAC
- **Module:** Staff
- **User Journey:** Regression safety for employee endpoints
- **Severity:** ⚪ Low
- **Description:** supabase/functions/_shared/employee/ has no *_test.ts. The deno suite covers employee only via the generic entity framework (deno_test.log:443-446 'listEntities paginates employees', 'getEmployee...'), not the actual handleAssignEmployeeRole / handleEmployee360 / requireEmployeeRead RBAC branches. RBAC and audit on the write path are unverified by automated tests.
- **Evidence:** find supabase/functions/_shared/employee -iname '*test*' returned nothing; gate deno_test.log employee references are entity-framework tests only.
- **Root Cause:** Module shipped without dedicated handler-level tests.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Tests

**Strengths (working well):**
- Staff login/OTP is genuinely server-backed in live: live_release.json AUTH_API_ENABLED=true selects ApiStaffOtpWorkflow which delegates to the shared (Batch-2-certified) AuthRepository; server issues claims+permissions, demo role dropdown is hidden in live.
- Client API paths exactly match the deployed router on both sides: /employees, /employees/dashboard, /employees/$id, /employees/$id/roles (phase4_remote_datasource.dart:74-110 vs employee_router.ts:24-47) and /employees/$id/360, /employees/intelligence/dashboard (phase5_remote_datasource.dart:46-56).
- Backend handlers all authenticate + enforce RBAC consistently (viewEmployees/viewHr for reads, manageEmployees/manageHr for writes, viewEmployeeIntelligence for 360) and emit mutation audit on role assignment (employee_handlers.ts:21-31,159-164).
- Client route guards mirror server permissions: /employees->viewEmployees, /employees/360/:id->viewEmployeeIntelligence (route_guards.dart:49,151-153); permissions exist in RBAC model and are granted to admin roles (role_permissions.dart).
- Employee 360 + intelligence dashboard are fully live and return real, sensible data (live probes: workloadPercent/burnoutRisk/avgWorkloadPercent) with no mock fallback in the production build.
- Backend repository uses parameterized SQL throughout (employee_repository.ts) and handlers degrade gracefully on TenantDbNotConfigured; UI screens use AksharaErrorState.fromFailure with retry + AksharaLoadingState (no swallowed errors).
- Employee 360 route is deployed and confirmed in live index.ts (ssh akshara grep routeEmployee -> present at index.ts:44,101).

---

### HR
**Code:** `HR`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Traced all 9 HR screens + workflow dialogs end-to-end: UI -> providers (hr_providers/hr_mutations_provider/hr_workflow_actions) -> ApiHrRepository -> HrRemoteDataSource (hr_api_paths) -> deployed hr_router -> hr_handlers/hr_write_handlers -> hr_read_repository/entity_write store -> RBAC. Confirmed deployment via ssh akshara (index.ts:95 entitlement wrap; hr_router.ts + hr_write_handlers.ts present). Ran read-only live GET probes on all 8 endpoints + employee detail + pagination + 404 + 401 (token.txt). Grepped gate logs (flutter hr_screens_test/contract tests pass; deno hr_read_repository_test 8/8 incl RBAC). Did NOT exercise writes (read-only audit) — write behavior inferred from code + persisted artifacts already in live snapshots. Not separately re-run: full suites (per briefing).

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| View employee profile (manager, docs, leave balances, attendance) | 🔴 broken | GET /hr/employees/{id} returns IDENTICAL hardcoded reportingManager='Rajesh Iyer (Principal)', address, emergencyContact, leaveBalances (8/10/15), documents ('Offer letter','ID proof' Verified) for EVERY employee — employeeDetailToApi() hr_read_repository.ts:135-186. Live-confirmed on Priya Sharma. School sees fabricated per-employee HR data. |
| Payroll -> Finance handoff | 🔴 broken | financeIntegrationNote tells user 'Payroll posts to Finance FN-05 salary disbursement' but code self-labels it a placeholder (hr_read_repository.ts:149); no HR->Finance write exists. 'Open Finance' navigates context.go(financeRoute='/finance/payroll') which has NO matching route in route_names.dart (only /finance/dashboard.. defaulters) — dead navigation. |
| View HR dashboard (KPIs, trends, AI insight) | 🟡 partial | Live GET /hr/dashboard 200 returns KPIs/trends. But KPIs are static seeded strings ('148 Total Employees') while live employee count is 3 (GET /hr/employees pagination total:3). aiInsight is a hardcoded snapshot string (hr_read_repository_test.ts:55), no callClaude in _shared/hr. Dashboard department filter (dashboard screen:22-26) is decorative — no filtered provider. |
| Create employee | 🟡 partial | POST /hr/employees deployed + RBAC manageHr (hr_write_handlers.ts:13,20; module_write_handlers.ts:51-55). UI gated by AksharaManageAction (hr_employees_screen.dart:49). Live evidence of prior write persisting ('QA Teacher' in GET). But dialog hardcodes department=administration/role=staff with no picker (hr_workflow_actions.dart:191-193). |
| Staff attendance review | 🟡 partial | GET /hr/attendance 200; filter tabs work (hrFilteredAttendanceProvider). But records are static seeded (1 record); no geo/face attendance write path; recentAttendance in profile hardcoded to one school-A id only (hr_read_repository.ts:170-183). |
| Leave: submit request | 🟡 partial | POST /hr/leave deployed, RBAC manageHr+submitStaffLeave (hr_mutations_provider.dart:45-54), approval-center handoff wired. But dialog hardcodes employeeId='HR-EMP-102', department=academics, leaveType=casual, days=1 regardless of UI fields (hr_workflow_actions.dart:56-67) — From/To/Reason captured but days always 1. |
| Payroll: view runs/entries + process run | 🟡 partial | GET /hr/payroll 200; POST /hr/payroll/run deployed + RBAC. But payroll filter (Current/Last month/All) is decorative — no filtered provider, always shows data.runs (hr_payroll_screen.dart:91-126). 'Export payroll summary PDF' is a no-op snackbar (hr_payroll_screen.dart:107-120), confirmed intentional by test 'HR payroll export PDF shows success snackbar'. |
| Recruitment pipeline view | 🟡 partial | GET /hr/recruitment 200; filter tabs work. Backend POST/PUT /hr/recruitment handlers deployed (hr_router.ts:88,108) but NO Flutter repository method or UI — screen is read-only (no buttons in hr_recruitment_screen.dart). Dead backend endpoints. |
| Performance reviews view | 🟡 partial | GET /hr/performance 200; managementInsight is static seeded string (no AI). Backend POST/PUT /hr/performance handlers deployed but NO Flutter interface method or UI create/edit — read-only screen (hr_performance_screen.dart). Dead backend endpoints. |
| HR reports export (PDF/CSV) | 🟡 partial | hr_reports_screen.dart:113-152 real PDF+CSV export via aksharaReportExportService. But export rows contain only title/id/description/headline (hr_reports_screen.dart:160-170) — no actual headcount/attendance/payroll tabular data. Headline tries kpiValue('avg_attendance') but live KPI ids are present_today (not avg_attendance), so falls back to mock headline (hr_reports_provider.dart:30-34). |
| Browse employee directory + pagination | ✅ verified | Live GET /hr/employees 200; pagination works (page=2&pageSize=2 -> total:3,hasMore:false). UI hr_employees_screen.dart:108 AksharaPaginationBar wired. Filter tabs use hrFilteredEmployeesProvider (hr_providers.dart:74). |
| Edit / activate / deactivate employee | ✅ verified | PUT /hr/employees/{id} + PATCH /hr/employees/{id}/status deployed; UI buttons RBAC-gated (hr_employee_profile_screen.dart:130-158); mutation notifiers with audit (hr_mutations_provider.dart:266-338). |
| Leave: approve / reject (+broadcast) | ✅ verified | POST /hr/leave/{id}/approve\|reject deployed; UI RBAC-gated + ApprovalCenter redirect when leaveApprovalRequired (hr_leave_screen.dart:404-431); notifier sends comm broadcast + audit + invalidates dashboard (hr_mutations_provider.dart:100-191). Live leave snapshot shows a write-test approved request persisted. |
| HR settings | ✅ verified | GET /hr/settings 200; intentionally read-only (STF-8 comment hr_settings_screen.dart:126-127 — edit removed since no write path). Honest. |
| RBAC enforcement (read viewHr / write manageHr) | ✅ verified | Reads require viewHr+school scope (hr_handlers.ts:39-42); writes require manageHr+school scope (module_write_handlers.ts:51-66). deno tests 'viewHr required for HR read','org scope denied for HR read' pass. Live no-auth GET /hr/dashboard -> 401. Module gated by entitlement module.hr_payroll (index.ts:95, default ON). |

**Live probes:**
- `GET /hr/dashboard|employees|attendance|leave|payroll|recruitment|performance|settings (schoolAdmin token)` → All 200 with seeded tenant data; dashboard KPI '148' but employees total=3; aiInsight static string.
- `GET /hr/employees/be100000-0000-4000-8000-000000000001` → 200; reportingManager/address/emergencyContact/leaveBalances/documents all hardcoded template values.
- `GET /hr/employees?page=2&pageSize=2` → 200 pagination {page:2,pageSize:2,total:3,hasMore:false}, 1 item — pagination works live.
- `GET /hr/nonexistent` → 404 {code:NOT_FOUND,'Route not found: GET /hr/nonexistent'} — router fallback works.
- `GET /hr/dashboard with no Authorization header` → 401 — auth enforced.
- `ssh akshara grep index.ts / hr_router.ts / hr_write_handlers.ts` → routeHr wrapped withEntitlement('/hr','module.hr_payroll') at index.ts:95; create/update performance+recruitment handlers + manageHr present in deployed source.

**Issues:**

#### HR-1 · Employee profile serves identical hardcoded HR data for every employee
- **Module:** HR
- **User Journey:** View employee profile (manager, docs, leave balances, attendance)
- **Severity:** 🟠 High
- **Description:** employeeDetailToApi() injects the same reportingManager 'Rajesh Iyer (Principal)', address 'Hyderabad, Telangana', emergencyContact '+91 90000 12345', leaveBalances (casual 8/sick 10/earned 15), and documents ('Offer letter','ID proof' both Verified) into EVERY employee detail response. A school HR manager opening any staff profile sees fabricated, identical data presented as that person's real record — wrong leave balances, fake verified documents, wrong manager.
- **Evidence:** supabase/functions/_shared/hr/hr_read_repository.ts:135-186; live GET /hr/employees/be100000-0000-4000-8000-000000000001 returned those exact hardcoded fields. Surfaced in lib/features/hr/employees/hr_employee_profile_screen.dart:112-185.
- **Root Cause:** Detail endpoint never modelled per-employee manager/documents/leave-balance storage; returns a static template alongside the real employee row.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Data-integrity

#### HR-2 · Payroll -> Finance handoff is fake; 'Open Finance' navigates to non-existent route
- **Module:** HR
- **User Journey:** Payroll -> Finance handoff
- **Severity:** 🟠 High
- **Description:** Users are told 'Payroll posts to Finance FN-05 salary disbursement' but no HR->Finance posting exists (code self-labels placeholder). The 'Open Finance' button navigates to financeRoute '/finance/payroll', which is not a registered route, so it dead-ends at the router fallback.
- **Evidence:** hr_read_repository.ts:149 (placeholder note); live GET /hr/payroll financeRoute='/finance/payroll'; route_names.dart:229-238 has no /finance/payroll; lib/features/hr/payroll/hr_payroll_screen.dart:143 context.go(data.financeRoute).
- **Root Cause:** Seeded financeRoute points to an unimplemented Finance payroll screen; integration note overstates a placeholder as a live feature.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Cross-module

#### HR-3 · Leave-submit dialog ignores user input (hardcoded employee/type/days)
- **Module:** HR
- **User Journey:** Leave: submit request
- **Severity:** 🟠 High
- **Description:** The 'New leave' dialog shows Employee/Reason/From/To fields but submits hardcoded employeeId='HR-EMP-102', department=academics, leaveType=casual, days=1 — only the free-text name/reason/dates flow through, and days is always 1 even for multi-day ranges. A real leave request for any other staff member, type, or duration cannot be created correctly.
- **Evidence:** lib/features/hr/hr_workflow_actions.dart:56-67 (employeeId/department/leaveType/days hardcoded); dialog fields hr_workflow_actions.dart:22-37.
- **Root Cause:** Demo-grade dialog without an employee picker / leave-type dropdown / day computation.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### HR-4 · Create-employee dialog forces department=administration, role=staff
- **Module:** HR
- **User Journey:** Create employee
- **Severity:** 🟡 Medium
- **Description:** Add-employee dialog has no department or role selector; every created employee is forced to department=administration, role=staff regardless of who they are (e.g. a new teacher cannot be created as academics/teacher).
- **Evidence:** lib/features/hr/hr_workflow_actions.dart:191-193.
- **Root Cause:** Dialog omits department/role inputs.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### HR-5 · Dashboard 'AI insight' and KPIs are static seeded strings, not real
- **Module:** HR
- **User Journey:** View HR dashboard
- **Severity:** 🟡 Medium
- **Description:** The dashboard 'AI Insight' ('Teacher attrition risk elevated in Mathematics...') and the KPI values (e.g. '148 Total Employees') are hardcoded into the seeded snapshot. They never change with real data — live employee total is 3, yet KPI shows 148. No callClaude exists in _shared/hr, so this is a fake-AI surface in a module where the rest of the app uses real Claude.
- **Evidence:** Live GET /hr/dashboard aiInsight string; hr_read_repository_test.ts:55,121 assert static string; grep callClaude in _shared/hr -> none; live employee total:3 vs KPI 148.
- **Root Cause:** HR dashboard reads a static snapshot row instead of computing KPIs/insight from live HR tables.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** AI

#### HR-6 · Payroll-screen 'Export payroll summary PDF' is a no-op snackbar
- **Module:** HR
- **User Journey:** Payroll: view runs/entries + process run
- **Severity:** 🟡 Medium
- **Description:** The payroll Export PDF button only shows 'Payroll summary export queued' and produces no file, while the HR Reports screen has a real PDF/CSV exporter. Inconsistent and misleading for an HR manager expecting a payroll document.
- **Evidence:** lib/features/hr/payroll/hr_payroll_screen.dart:107-120; test 'HR payroll export PDF shows success snackbar' codifies the no-op. Contrast hr_reports_screen.dart:113-152 (real export).
- **Root Cause:** Stub button never wired to aksharaReportExportService.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### HR-7 · Decorative filter bars on Dashboard and Payroll do nothing
- **Module:** HR
- **User Journey:** View HR dashboard / Payroll view
- **Severity:** 🟡 Medium
- **Description:** Dashboard ('All departments/Academics/Administration') and Payroll ('Current month/Last month/All runs') filter chips update state but no filtered provider consumes them — selecting a filter has zero effect on displayed data, unlike Attendance/Recruitment/Employees which do filter.
- **Evidence:** hr_dashboard_screen.dart:31-38 + no hrFilteredDashboardProvider; hr_payroll_screen.dart:33-40 + no hrFilteredPayrollProvider (grep shows only attendance/recruitment/employees use hrFiltered*).
- **Root Cause:** Filter UI added without backing filtered selectors.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### HR-8 · Performance & Recruitment write endpoints deployed but unreachable from app
- **Module:** HR
- **User Journey:** Recruitment pipeline / Performance reviews
- **Severity:** 🟡 Medium
- **Description:** Backend deploys POST/PUT /hr/performance and POST/PUT /hr/recruitment (with RBAC), but the Flutter HrRepository interface has no methods for them and the screens have no create/edit affordances — both screens are read-only. So a real HR manager cannot create a performance review or open a requisition; the endpoints are dead code.
- **Evidence:** hr_router.ts:85-111 (handlers routed, deployed per ssh grep); interfaces/hr_repository.ts:7-54 has no performance/recruitment write methods; hr_performance_screen.dart & hr_recruitment_screen.dart have no onPressed/dialog.
- **Root Cause:** Backend A6 writes shipped ahead of UI; UI never built.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### HR-9 · HR report exports omit actual tabular data; headline KPI lookup mismatches live id
- **Module:** HR
- **User Journey:** HR reports export (PDF/CSV)
- **Severity:** ⚪ Low
- **Description:** Report PDF/CSV exports contain only the report's title/id/description/headline, not the underlying headcount/attendance/leave/payroll rows — a 'Headcount report' has no employee list. Also the live headline lookup uses kpiValue('avg_attendance') but the live dashboard KPI id is 'present_today', so the attendance headline always falls back to the mock string.
- **Evidence:** hr_reports_screen.dart:160-170 (_exportRows); hr_reports_provider.dart:30-34 (avg_attendance); live GET /hr/dashboard KPI ids = total_employees/present_today/on_leave/open_positions.
- **Root Cause:** Export builder fed catalog metadata only; KPI id drift between provider and seed.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

**Strengths (working well):**
- All 8 HR read endpoints (dashboard/employees/attendance/leave/payroll/recruitment/performance/settings) are deployed and live-verified 200 with real tenant-scoped seeded data; employee detail + pagination work live.
- Reads enforce viewHr + school operational scope; writes enforce manageHr + school scope via shared module_write_handlers; deno RBAC tests pass and live no-auth GET returns 401.
- Employee create/update/status and leave submit/approve/reject are genuinely wired client->API->router->handler->hr_entities with mutation notifiers, audit emission, cache invalidation, and (leave) approval-center + comm-broadcast handoffs.
- Writes persist to the same hr_entities store reads use (live: write-test 'QA Teacher' employee and an approved leave request are visible in GET responses) — no silent mock writes in the live path.
- Module is correctly entitlement-gated (module.hr_payroll, default ON) and capability-mapped to hrPayroll; UI write actions consistently gated by AksharaManageAction(Permission.manageHr).
- Consistent loading / error / empty states across screens (AksharaLoadingState/ErrorState/EmptyState, ErpAsyncBody with retry); card-vs-table responsive layouts and semantics labels throughout.
- HR Reports screen has a real working PDF + CSV exporter via aksharaReportExportService.

---

### Principal (management + school_completion; backend _shared/principal_command, management, approval)
**Code:** `PRINC`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Traced every screen in lib/features/management (dashboard, analytics, admissions, finance, academics, performance, tasks/approval center incl. detail panel + queue + filters, settings, attendance corrections admin, workflow actions, mutations) and key school_completion screens/mutations, plus backend _shared/{management,principal_command,approval}. Wire-traced client paths to deployed router via ssh akshara and ran read-only live GET probes (management/settings, dashboard, financial-health, admissions-funnel, academic-health, principal-command/center) — all confirmed reachable; management dashboards confirmed static seed. Did NOT run any write/POST (read-only mandate), so school_completion write journeys marked partial. Did not deeply re-audit school_completion timetable/syllabus internals (prior batch-8c/onboarding certs cover them) or the education question-paper subsystem (separate cert). Single targeted tests not needed — gate logs already show approval/management/principal deno tests green.

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Principal executive dashboards (Management: revenue/finance/admissions funnel/academic health/school performance/analytics) | 🔴 broken | All read from managementRepositoryProvider.getDashboard→/management/* which is served from STATIC seeded management_entities snapshot rows (management_read_repository.ts:6, seeded only by migration 20260614300000; no refresh path exists — grep found zero UPDATE/recompute). Live probes return identical hardcoded seed: financial-health=₹45L/₹1.2Cr/87%, admissions-funnel=120 leads/45 confirmed/38%, academic-health=98% pass/94% att. aiInsight strings are static ('Financial health stable.') not real AI. A real school sees fixed fake numbers regardless of their data. |
| Principal updates Management Settings (fiscal year etc.) and saves | 🔴 broken | Reachable nav target managementSettings (management_navigation.dart:28). Save → ManagementRemoteDataSource.updateSettings does _dio.put('/management/settings') (management_remote_datasource.dart:102), but management_router.ts:18 returns null for any non-GET → 404 NOT_FOUND (confirmed on deployed VPS router via ssh). Notifier wraps in AsyncValue.guard so error is swallowed; _saveDraft has no catch and unconditionally shows 'Management settings saved' snackbar (management_settings_screen.dart:297-299). Silent failure in live mode. |
| Substitute assignment / teacher reassignment / timetable optimization (school_completion) | 🟡 partial | Writes RBAC-gated (assertManageAcademicTimetable, school_completion_mutations_provider.dart:15-27) + AsyncValue.guard; routeSchoolCompletion registered (index.ts:122) with real POST/PUT/PATCH datasource methods; SCHOOL_COMPLETION_API_ENABLED=true. Broadcast side-effects best-effort (catch-swallow, line 64). Not deeply re-probed (write-only, no live POST allowed); deno school_completion service tests ok in gate log. Marked partial pending live write verification. |
| Principal Approval Center — review cross-module requests, approve/reject with comment + audit (results, leave, fee, inventory PO, attendance correction) | ✅ verified | Client path approval_api_paths.dart approve(id)='/approvals/{id}/approve' matches deployed approval_router.ts:43-46; server enforces approvalPermissionForType per type + school scope (approval_handlers.ts:300-304) + class-teacher scoping for studentLeave (309-332) + inventory PO separation-of-duties (approval_repository.ts:36). Live builds wired (live_release.json:31 APPROVAL_API_ENABLED=true). UI gates buttons via AksharaApproveAction(permission) (approval_detail_panel.dart:113-131); loading/error/empty states present (principal_approval_center_screen.dart:59-87); fail-closed actor (approval_center_provider.dart:206). deno SoD + permission tests ok in gate log. |
| Principal Command Center (Evolution) — live executive intelligence: priorities, risk overview, attendance/fee widgets, NL query | ✅ verified | Live computed from real data: principal_command_service.ts:31-75 calls buildPrincipalIntelligenceCenter + listRiskSnapshots + executePrincipalQuery. RBAC viewPrincipalCommand\|viewAnalytics (principal_command_handlers.ts:18-20). Live probe GET /principal-command/center returned real computed values (health 44, at-risk 1). UI lib/features/evolution/principal_command_screen.dart hits EvolutionApiPaths.principalCommandCenter='/principal-command/center'. |
| Question-paper principal-only validation (approveEducation) | ✅ verified | Covered by question-paper-correction cert (principal validates teacher-built papers); deployed education_router.ts has question-papers review/publish/moderate routes (ssh akshara confirmed lines 66-125). Not re-litigated. |

**Live probes:**
- `GET /management/financial-health?tenantId=akshara` → 200 static seed: outstanding ₹45L, collectedMtd ₹1.2Cr, collectionRate 87%, expenseRatio 62%, aiInsight 'Financial health stable.' — identical to migration seed, not real data
- `GET /management/admissions-funnel?tenantId=akshara` → 200 static: stages lead=120, confirmed=45, conversionRate 38%, aiInsight 'Funnel healthy.' (seed)
- `GET /management/academic-health?tenantId=akshara` → 200 static: passRate 98%, avgAttendance 94%, teacherShortage 2, aiInsight 'Academic metrics strong.' (seed)
- `GET /management/dashboard?tenantId=akshara` → 200 static: revenue ₹2.4Cr, feeSnapshot outstanding ₹45L/collected ₹1.2Cr/87%/12 defaulters, aiInsight string (seed)
- `GET /principal-command/center?tenantId=akshara` → 200 REAL computed: executiveSummary 'Health 44 | At-risk 1 | Critical 0 | Attendance risk 50', live topPriorities/recommendations — confirms this surface is live
- `ssh akshara cat /opt/akshara/functions/_shared/management/management_router.ts` → Deployed router matches repo: 'if (method !== GET) return null' → confirms PUT /management/settings and POST /management/tasks/{id}/resolve 404 in production
- `GET /management/settings?tenantId=akshara` → 200 read works (single editable 'Fiscal year' item); but the PUT save endpoint has no handler

**Issues:**

#### PRINC-1 · Management executive dashboards serve permanently-static seed data, not the school's real numbers
- **Module:** Principal
- **User Journey:** Principal executive dashboards (Management: revenue/finance/admissions funnel/academic health/school performance/analytics)
- **Severity:** 🔴 Critical
- **Description:** The Principal/Management dashboards (dashboard, analytics, financial-health, admissions-funnel, academic-health, school-performance) are powered by the management_entities snapshot table, which is populated ONLY by migration seed and never refreshed from real student/finance/admissions data. Every school sees the same hardcoded ₹2.4Cr revenue, ₹45L outstanding, 87% collection, 12 defaulters, 120 leads / 45 confirmed / 38% conversion, 98% pass rate, 94% attendance, plus static 'aiInsight' text. For a real school in production this is misleading executive reporting — the principal's primary oversight surface shows fiction. (The separate Evolution Principal Command Center IS live-computed, which makes this doubly confusing.)
- **Evidence:** management_read_repository.ts:6 createEntityReadStore('management_entities'); seed-only inserts in migration 20260614300000_management_control_center_read_apis.sql:57-83; grep found NO UPDATE/refresh/recompute of management_entities anywhere in functions. Live GET /management/financial-health → {outstanding:'₹45L',collectedMtd:'₹1.2Cr',collectionRate:'87%',aiInsight:'Financial health stable.'}; /management/admissions-funnel → 120 lead/45 confirmed/38%; /management/academic-health → 98% pass/94% att (all = migration seed values).
- **Root Cause:** Management read APIs were built as a static snapshot-store stub (entity_read pattern) and a real aggregation/refresh layer over live finance/SIS/admissions/exam data was never implemented; the seed was left as the live source.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Data-integrity

#### PRINC-2 · Management Settings Save silently fails in live mode (PUT 404) but reports success
- **Module:** Principal
- **User Journey:** Principal updates Management Settings (fiscal year etc.) and saves
- **Severity:** 🟠 High
- **Description:** The Management Settings screen is a reachable principal action with editable items and a Save button. In a live build the Save issues PUT /management/settings, but the deployed management router only handles GET and returns 404 for any other method. The mutation notifier swallows the error via AsyncValue.guard (returns null), and _saveDraft has no catch — it unconditionally shows the 'Management settings saved' snackbar. The principal believes settings were saved; nothing persisted and no error surfaces.
- **Evidence:** Client: management_remote_datasource.dart:102 _dio.put(ManagementApiPaths.settings='/management/settings'); deployed router (ssh akshara cat .../management_router.ts) line 18 'if (method !== "GET") return null;' → NOT_FOUND 404. Swallow: management_mutations_provider.dart:83 AsyncValue.guard. False success: management_settings_screen.dart:285-304 try has no catch, shows 'Management settings saved' regardless of saved==null.
- **Root Cause:** Settings write endpoint (PUT) was never added to the management router/handlers, and the UI/notifier treat a swallowed null as success instead of surfacing failure.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### PRINC-3 · Two conflicting principal oversight surfaces (static Management dashboards vs live Evolution Command Center)
- **Module:** Principal
- **User Journey:** Principal executive dashboards (Management: revenue/finance/admissions funnel/academic health/school performance/analytics)
- **Severity:** 🟡 Medium
- **Description:** A principal can reach both the legacy Management dashboards (static seed) and the Evolution Principal Command Center (real live intelligence). They present overlapping but inconsistent executive metrics, with no indication which is authoritative. In production this erodes trust in the numbers.
- **Evidence:** Management nav exposes dashboard/analytics/finance/academics/performance (management_navigation.dart:7-28) backed by static /management/* ; Evolution principal_command_screen.dart backed by live /principal-command/center (principal_command_service.ts). Both reachable to a principal.
- **Root Cause:** Two generations of principal dashboards coexist; the static one was never deprecated/hidden after the live intelligence center shipped.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Cross-module

#### PRINC-4 · Dead management approve/reject path points at a non-existent route
- **Module:** Principal
- **User Journey:** Principal Approval Center
- **Severity:** ⚪ Low
- **Description:** management_workflow_actions.dart (approveManagementItem/rejectManagementItem) and the resolveManagementApproval mutation call POST /management/tasks/{id}/resolve, which the management router does not handle (GET-only → 404). This code is not wired to any UI button (ManagementTasksScreen delegates entirely to PrincipalApprovalCenterScreen), so it is dead code rather than a user-facing break — but it is a latent trap: any future wiring to it would 404, and it duplicates the working /approvals flow.
- **Evidence:** ManagementApiPaths.approvalResolve='/management/tasks/{id}/resolve' (management_api_paths.dart:13-14) + _dio.post (management_remote_datasource.dart:115); router GET-only (management_router.ts:18). No UI references approveManagementItem/rejectManagementItem (grep). management_tasks_screen.dart:11 returns PrincipalApprovalCenterScreen.
- **Root Cause:** Superseded management-approval path was left in place after approvals were unified into the /approvals API + Principal Approval Center.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

**Strengths (working well):**
- Principal Approval Center is genuinely production-grade: client paths exactly match the deployed approval_router; per-type RBAC permissions enforced server-side; separation-of-duties (PO creator≠approver) and class-teacher scoping for student leave enforced server-side; fail-closed approver identity; rejection requires a comment; full audit trail surfaced; loading/error/empty states all present; deno SoD/permission tests pass.
- Evolution Principal Command Center is real live intelligence computed from actual risk snapshots + attendance/fee queries (principal_command_service.ts), RBAC-gated, live-probe verified.
- Live release config correctly enables APPROVAL_API_ENABLED and MANAGEMENT_API_ENABLED so the working approval path is live by default.
- school_completion write mutations are RBAC-gated (manageAcademicTimetable) and error-guarded; routes registered and feature-flagged on.
- Question-paper principal-only validation already cert-proven and deployed (question-paper-correction).

---

### Admin (school config, settings, school setup/onboarding)
**Code:** `ADMIN`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Traced the three named dirs (lib/features/admin, settings, school_config) fully plus the closely-coupled onboarding (lib/features/onboarding) and management settings screen (central admin settings entry). Verified wires end-to-end against deployed router (ssh akshara cat) and ran GET-only live probes (school-config, management/{dashboard,settings,tasks}, onboarding/{dashboard,startup}) with the schoolAdmin token. Cross-checked gate logs for test coverage. NOT deeply audited: lib/features/school_completion (24 files — academic-ops, belongs more to academic/timetable modules) and lib/features/platform/multi_school onboarding wizard (separate Director/multi-school path, has its own passing tests). Did not POST/PUT/DELETE (read-only mandate); the management-settings 404 and backup-screen mock are confirmed by deployed source + code paths rather than a live write. Management settings overlaps the Management module — flagged here because it is the school-admin settings save journey.

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Backup & Restore admin screen | 🔴 broken | backup_restore_screen.dart: all 4 actions (school backup, tenant backup, export, restore) are pure dialogs/snackbars with NO repository and NO backend route (grep: only /health/backup exists, index.ts:235). Screen has no nav entry point. Real backups run via cron (Batch 7) but this admin UI cannot trigger/track them — it shows canned text only. |
| Management settings save (academic year, general items) | 🔴 broken | management_settings_screen.dart:287 calls updateManagementSettingsProvider→PUT /management/settings (management_remote_datasource.dart:102). Deployed management_router.ts returns null for any non-GET (matchManagementRoute line 18 'if method!==GET return null')→routeManagement returns NOT_FOUND 404. Confirmed on VPS via ssh akshara cat. updateManagementSettings execute() swallows the failure (returns state.valueOrNull, no rethrow) so UI shows 'Management settings saved' snackbar despite 404. |
| Unified school startup onboarding (profile→…→Go Live, AI prefill) | 🟡 partial | unified_onboarding_provider.dart aiPrefill/goLive wired to real backend (POST /onboarding/startup/ai-prefill, /onboarding/startup/go-live); live /onboarding/startup returns persisted state; matches B7 + onboarding-live cert. BUT screen has NO in-app nav entry (grep: only qa_test_keys references unifiedOnboarding, zero context.go/push callers) — orphaned route, reachable only by deep-link/tests. |
| Onboarding hub (invites + import dashboard) | 🟡 partial | onboarding_hub_screen.dart is a demo harness ('Preview demo student import'/'Send demo parent invite' with hardcoded rows, lines 53-60). Backend real & live (GET /onboarding/dashboard returns real jobs). Route /sis/onboarding has NO nav entry point (grep) and no real bulk-import UI here. |
| Smart School Configuration (type/curriculum/capabilities/ops → apply → persist) | ✅ verified | school_discovery_screen.dart:281 apply()→school_configuration_provider.dart:79 apply()→SchoolConfigApiRepository.save PUT /school-config (school_config_api_repository.dart:26); router school_config_router.ts:17 PUT→handlePutSchoolConfig (RBAC manageSchoolSetup + school scope + audit, school_config_handlers.ts:80-114). Live GET /school-config returns real persisted tenant config (capabilities, configuredAt 2026-06-24). Reachable from management settings (management_settings_screen.dart:142) and org-builder hub. |
| Plan ceiling locks unavailable capability toggles | ✅ verified | school_discovery_screen.dart:54 planCapabilityCeilingProvider; _capabilitySwitch locked branch (line 255) shows lock + 'Upgrade to unlock', onChanged:null. schoolCapabilitiesProvider intersects local∩ceiling (school_configuration_provider.dart:124). |
| Appearance settings (light/dark/system) | ✅ verified | appearance_settings_screen.dart:48 themeModeProvider.setThemeMode; device-local by design (comment line 14). Test passes: test/features/settings/appearance_settings_screen_test.dart in flutter_test.log. |
| Admin hub / nav RBAC gating | ✅ verified | admin_navigation_provider.dart:220 destinations filtered by rbac.hasPermission(requiredPermission); each module has requiredPermission (lines 24-200). admin_hub_screen.dart renders only workspace-scoped authorized modules. |

**Live probes:**
- `GET /school-config (schoolAdmin token)` → 200 — real persisted config: schoolType day_school, curriculum cbse, capabilities {library:true,hrPayroll:true,transport:true,...}, configuredAt 2026-06-24T11:44:05Z. Confirms live tenant-authoritative persistence works.
- `GET /management/settings` → 200 — {sections:[{id:general,items:[{id:fiscal_year,label:Fiscal year,value:Apr–Mar,editable:true}]}]}. Read works; write (PUT) path is the broken one.
- `GET /management/dashboard & /management/tasks` → 200 — real KPIs (Revenue ₹2.4Cr), aiInsight, feeSnapshot; tasks overdue=3. Management reads are live.
- `GET /onboarding/dashboard & /onboarding/startup` → 200 — dashboard returns real import jobs (fj.csv, rolled_back); startup returns persisted wizard state (currentStep schoolProfile, academicYear 2026-27). Onboarding backend live.
- `ssh akshara cat .../management/management_router.ts` → Confirmed deployed router rejects all non-GET methods (matchManagementRoute: if method!==GET return null), proving PUT /management/settings 404s in production.
- `GET /management (base)` → 404 NOT_FOUND (expected — no base handler).

**Issues:**

#### ADMIN-1 · Management settings 'Save' silently 404s and falsely reports success
- **Module:** Admin
- **User Journey:** Management settings save (academic year, fiscal year, general items)
- **Severity:** 🟠 High
- **Description:** The settings screen issues PUT /management/settings, but the deployed management router only matches GET methods (matchManagementRoute returns null for non-GET), so the request 404s. The mutation notifier wraps the call in AsyncValue.guard and returns state.valueOrNull WITHOUT rethrowing, so the screen never sees the error and unconditionally shows the 'Management settings saved' snackbar. Admin believes academic year / fiscal year edits persisted; they did not.
- **Evidence:** management_remote_datasource.dart:102 (_dio.put settings); supabase/functions/_shared/management/management_router.ts:18 'if (method !== "GET") return null' (verified deployed via ssh akshara cat /opt/akshara/functions/_shared/management/management_router.ts) → routeManagement returns NOT_FOUND; management_mutations_provider.dart:108 'return state.valueOrNull' (no rethrow); management_settings_screen.dart:297 shows success snackbar regardless.
- **Root Cause:** Backend write route never implemented (router is read-only) AND client mutation swallows the failure instead of surfacing it. Cross-module overlap with Management module but it is the central admin/school settings save path.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### ADMIN-2 · Certified unified onboarding wizard is unreachable from the app UI
- **Module:** Admin
- **User Journey:** Unified school startup onboarding
- **Severity:** 🟠 High
- **Description:** UnifiedOnboardingFlowScreen (the real, backend-wired, B7-certified school startup wizard with AI prefill + Go Live) is routed in app_router.dart:506 but nothing in the UI navigates to RouteNames.unifiedOnboarding — the only references are in qa_test_keys.dart. A new school admin cannot start the onboarding wizard from any menu/button; it is deep-link/test only.
- **Evidence:** grep 'unifiedOnboarding'/'UnifiedOnboardingFlow' across lib --include *.dart returns only qa_test_keys.dart entries + the screen/router files; zero context.go/context.push callers.
- **Root Cause:** Route wired and certified at the screen/backend level but never linked into navigation (orphaned route).
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### ADMIN-3 · Backup & Restore admin screen is entirely non-functional (mock)
- **Module:** Admin
- **User Journey:** Backup & Restore admin screen
- **Severity:** 🟡 Medium
- **Description:** All four ListTiles (school backup, tenant backup, export package, restore school) only open dialogs/SimpleDialogs that show static text or a 'started' snackbar. There is no repository, no API client, and no backend route to queue a backup, export, or restore. The only backup endpoint is GET /health/backup (monitoring). An admin who needs an on-demand backup/export/restore gets nothing — pure UI theatre over a real-looking screen.
- **Evidence:** backup_restore_screen.dart:55-115 (_showJobDialog/_showExportDialog/_showRestoreDialog all Navigator.pop only); grep: no /backup repository in lib/core/repositories; index.ts:235 only /health/backup exists.
- **Root Cause:** Screen built as a placeholder; real backups handled server-side by cron (Batch 7) but never exposed as an admin-triggerable action. Screen also has no nav entry point.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### ADMIN-4 · Onboarding hub is a demo harness, not a real admin import/invite UI
- **Module:** Admin
- **User Journey:** Onboarding hub (invites + import dashboard)
- **Severity:** 🟡 Medium
- **Description:** OnboardingHubScreen exposes only 'Preview demo student import' and 'Send demo parent invite' buttons with hardcoded demo rows/phones. The backend (preview/commit/rollback/invites) is fully real and live, but the admin-facing UI cannot import a real CSV or invite real parents from this screen. Also the two button handlers (_runDemoStudentImport/_sendDemoInvite) have no try/catch — a backend failure throws unhandled (the success snackbar after await never fires and the error is swallowed by the framework).
- **Evidence:** onboarding_hub_screen.dart:53-60 (demo button labels), :67-90 hardcoded demo rows, :92-107 hardcoded demo phone; no try/catch around repo.previewStudentImport / repo.createInvite. Route /sis/onboarding has no nav entry (grep).
- **Root Cause:** Developer demo screen left in place of a production import/invite UI; the real bulk-import flow lives elsewhere (student onboarding), leaving this route as a stub.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### ADMIN-5 · Unified onboarding 'Go Live' has no error handling for network/API failures
- **Module:** Admin
- **User Journey:** Unified school startup onboarding
- **Severity:** 🟡 Medium
- **Description:** The Go Live button handler awaits notifier.goLive() and only handles the validation-false case with a snackbar. goLive() (provider) does NOT catch exceptions from save()/goLive() and does not reset isLoading on throw, so a backend/network failure produces an unhandled exception and can leave the wizard stuck in isLoading (buttons disabled) with no user-visible error.
- **Evidence:** unified_onboarding_flow_screen.dart:73-83 (only !ok branch handled, no try/catch); unified_onboarding_provider.dart:125-139 goLive() has no try/catch and never sets isLoading:false on failure.
- **Root Cause:** Happy-path-only error handling; aiPrefill resets isLoading on catch but goLive does not.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### ADMIN-6 · Global search surfaces and navigates to routes regardless of RBAC
- **Module:** Admin
- **User Journey:** Admin hub / global search
- **Severity:** ⚪ Low
- **Description:** GlobalSearchEntry has no requiredPermission field, and the overlay shows GlobalSearchRegistry.search(query) unfiltered, then _navigate calls context.go(entry.route). A user sees and can tap entries for modules they lack permission for. Route guards block guarded routes on navigation (redirect), so it is mostly an information leak + jarring redirect rather than access; but routes without a view-permission entry (e.g. onboardingHub, backupRestore) would be reachable.
- **Evidence:** global_search_registry.dart:7-18 (no permission field); global_search_overlay.dart:55 search unfiltered, :46 context.go(entry.route); route_guards.dart kErpRouteViewPermissions is a default-allow map (schoolDiscovery guarded line 105, but unifiedOnboarding/onboardingHub/backupRestore absent → no guard).
- **Root Cause:** Search index not RBAC-filtered; relies entirely on router-level guards which do not cover unlisted routes.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** RBAC

#### ADMIN-7 · Onboarding wizard TextFields recreate controllers in build (cursor reset)
- **Module:** Admin
- **User Journey:** Unified school startup onboarding
- **Severity:** ⚪ Low
- **Description:** Several TextFields in the wizard pass controller: TextEditingController(text: ...) constructed inline inside build(), so the controller is recreated on every rebuild, resetting the cursor to the end and risking lost keystrokes while typing in academic year / classes / sections fields.
- **Evidence:** unified_onboarding_flow_screen.dart:168, 177, 186 (controller: TextEditingController(text: state.x) inside _StepBody.build).
- **Root Cause:** Inline controller construction instead of a stateful/retained controller.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### ADMIN-8 · No backend (deno) tests for school-config handlers/repository
- **Module:** Admin
- **User Journey:** Smart School Configuration
- **Severity:** ⚪ Low
- **Description:** The /school-config handlers and repository (the tenant-authoritative gating persistence) have no deno test file, unlike most other backend areas. The journey works live (GET verified) and Flutter-side tenant store is tested, but the server RBAC/scope/save path is unverified by automated tests.
- **Evidence:** ls supabase/functions/_shared/school_config/ → only handlers/repository/router .ts (no *_test.ts); grep school_config_handlers in deno_test.log → no match.
- **Root Cause:** Test coverage gap for the B1 school-config backend.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Data-integrity

**Strengths (working well):**
- School configuration is genuinely live and tenant-authoritative: GET/PUT /school-config enforce viewSchoolSetup/manageSchoolSetup + school operational scope + RLS + mutation audit (school_config_handlers.ts:80-114); live GET returns real persisted config with configuredAt timestamp.
- Plan-ceiling entitlement integration is clean: capability toggles beyond the plan are shown-but-locked with an upgrade hint, and schoolCapabilitiesProvider intersects local config with the plan ceiling (school_configuration_provider.dart:124).
- Admin nav and hub are correctly RBAC-gated — every destination carries a requiredPermission and is filtered by rbac.hasPermission (admin_navigation_provider.dart:220).
- Onboarding backend is fully implemented and deployed; all client paths (onboarding_api_paths.dart / startup_onboarding_api_paths.dart) match the deployed router exactly, and B7/onboarding-live certs already prove the end-to-end startup journey.
- School config offline-first design is sound: optimistic local write + SharedPreferences + in-memory tenant store, with backend as source of truth when the flag is on; SCHOOL_CONFIG_API_ENABLED/ENTITLEMENT_API_ENABLED/ONBOARDING_API_ENABLED all true in config/live_release.json.
- Appearance settings are correctly device-local and persisted, with passing widget test.

---

### Director (Multi-School Portal)
**Code:** `DIREC`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Covered all Flutter files in lib/features/director (9 screens + 4 widgets + 3 provider files), the repository chain (interface/hybrid/api/remote/mock), router wiring (director_navigation.dart + app_router.dart routes), entitlement gate, and the full backend _shared/director (router/handlers/repository/ai). Traced every write to its router route + RBAC + audit. Confirmed live deployment via ssh akshara cat of director_router.ts/handlers/ai and 3 GET live probes (dashboard/metric-inputs/unauth — all RBAC-correct). Cited B8_DIRECTOR_MULTI_SCHOOL_CERTIFICATION.md (13 PASS) rather than re-litigating. Did NOT exercise org-scope happy-path live (token is schoolAdmin; org persona unseeded — same constraint the cert documents in §6). All write paths verified read-only (no POST/PUT/PATCH issued).

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Compliance acknowledge | 🟡 partial | director_compliance_screen.dart:124-140 → acknowledgeCompliance → POST /director/compliance/:id/acknowledge (ACK_RE deployed, manage+org gated, audited). Works, but _acknowledge has no try/catch so a failed ack surfaces no error to the user (see issue). |
| Multi-school executive dashboard (KPIs + per-school health + exec summary) | ✅ verified | director_dashboard_screen.dart:24-92 reads directorExecutiveDashboardProvider → /director/dashboard (handleDashboard, director_handlers.ts:85). Live probe: GET /director/dashboard returns FORBIDDEN viewDirectorPortal for schoolAdmin token (RBAC working). Deployed on VPS (index.ts:124 withEntitlement module.multi_branch). B8 cert check 3 PASS. |
| Per-school overview / schools list | ✅ verified | director_schools_screen.dart:33-38 has loading/error/empty states; /director/schools → getSchoolRows (director_repository.ts:79, FROM schools s, no PII). B8 cert check 3. |
| Revenue + Marketing + Growth + Admissions + Portfolio aggregates | ✅ verified | director_revenue/marketing/growth/admissions/portfolio_screen.dart all use state.when with loading+error (grep confirmed). Backend getRevenue/getMarketing/getGrowth/getAdmissions. director_repository_test.ts 10/10 (ran: getMarketing honest zeros, getAdmissions funnel). |
| Metric input entry (spend/expense/capacity) drives Margin/ROI/Capacity | ✅ verified | director_metric_input_editor.dart:68-98 → saveMetricInput → POST /director/metric-inputs (handleSaveMetricInput, manage+org gated, 422 validation, ownership-validated upsert, audited). Mutation invalidates revenue/marketing/growth/dashboard (director_mutations_provider.dart:79-84). Deployed on VPS. Test upsertMetricInput saves/refuses-out-of-org PASS. B8 cert checks 7,8,11. |
| Real board-pack PDF export | ✅ verified | director_reports_screen.dart:146-167 → exportReport → POST /director/reports/:id/export (EXPORT_RE deployed on VPS) → buildBoardPack from live aggregates; client renders via shareDirectorBoardPackPdf (akshara_report_export_service.dart:325-422, real KPI/financials/funnel tables). buildBoardPack test PASS. B8 cert check 9. |
| AI executive summary (real Claude, safe fallback) | ✅ verified | director_ai.ts refineExecutiveSummaryWithClaude with apiKey guard + try/catch fallback to deterministic; handleSummary (director_handlers.ts:139) gates viewDirectorPortal+org. Deployed on VPS (director_ai.ts present, 1 ref). Test 'returns deterministic brief when no key' PASS. B8 cert check 10 (799-char refined). |
| Cross-module handoff (Director ← schools/admissions/finance org aggregates; → shared Copilot AI) | ✅ verified | getSchoolRows/getAdmissions/getRevenue read org-scoped from schools/admissions/finance tables (director_repository.ts). DirectorAiAssistantLink routes to shared Copilot with directorCorrespondent persona (director_shared_widgets.dart:130-150). |

**Live probes:**
- `GET /director/dashboard with schoolAdmin bearer` → 403 {FORBIDDEN, 'Permission required: viewDirectorPortal'} — RBAC correctly denies (token lacks director perm/org scope)
- `GET /director/metric-inputs with schoolAdmin bearer` → 403 {FORBIDDEN, viewDirectorPortal} — route exists + RBAC enforced
- `GET /director/dashboard unauthenticated` → 401 {UNAUTHORIZED, 'Missing bearer token'}
- `ssh akshara grep index.ts + director_router.ts` → index.ts:124 withEntitlement(routeDirector,'/director','module.multi_branch'); router has /director/metric-inputs GET+POST, EXPORT_RE, ACK_RE, handleSummary — deployed source matches repo
- `ssh akshara grep handlers/ai` → director_handlers.ts has 6 refs to buildBoardPack/upsertMetricInput/refine; director_ai.ts present with refineExecutiveSummaryWithClaude — B8 changes are live
- `deno test director_repository_test.ts` → 10 passed / 0 failed (metric upsert/ownership, board pack, AI no-key fallback, honest-zero marketing)

**Issues:**

#### DIREC-1 · 8 of 9 Director sub-routes lack client-side EntitlementModuleGate
- **Module:** Director
- **User Journey:** A non-multi-branch (e.g. Trial/Standard) org admin who deep-links or navigates to any Director screen other than the dashboard
- **Severity:** 🟡 Medium
- **Description:** Only directorDashboardRouteBuilder wraps its screen in EntitlementModuleGate(module: AdminModule.director) (director_navigation.dart:26). The other 8 builders (schools, portfolio, revenue, growth, marketing, admissions, compliance, reports) return the screen directly with no gate. A non-entitled user who reaches those routes sees the screen chrome and an API error state instead of the clean PlanLockedModuleView upgrade screen. NOT a data/security hole — the server enforces module.multi_branch via withEntitlement on every /director/* route (index.ts:124, returns 402), so no fake data leaks; this is a UX inconsistency / missed upsell.
- **Evidence:** lib/router/director_navigation.dart: grep -c EntitlementModuleGate = 1 (only line 26, dashboard). Lines 32-66 (schools/portfolio/revenue/growth/marketing/admissions/compliance/reports builders) return `const Director*Screen()` ungated. Compare admin_navigation.dart which gates each module route.
- **Root Cause:** EntitlementModuleGate was added to the dashboard route only during B8; the other 8 sub-route builders were not wrapped.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** RBAC

#### DIREC-2 · AI executive summary generation has no error handling (silent failure)
- **Module:** Director
- **User Journey:** Director taps 'Generate AI Executive Summary' on the Reports screen while the backend is unreachable or returns an error
- **Severity:** ⚪ Low
- **Description:** _generateSummary (director_reports_screen.dart:129-144) awaits generateExecutiveSummary inside try/finally with NO catch. On any failure the exception propagates uncaught; the spinner resets (finally) but _generatedSummary stays null so the card silently keeps showing the placeholder 'Generate a board-ready executive brief...'. The user gets no feedback that it failed. Contrast _exportReport on the same screen which catches and shows a 'Could not export report' snackbar.
- **Evidence:** lib/features/director/director_reports_screen.dart:129-144 (try { ... } finally { ... } — no catch). Compare lib/features/director/director_reports_screen.dart:161-166 (export has catch + snackbar).
- **Root Cause:** Inconsistent error-handling pattern between the two report actions; summary uses only try/finally.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### DIREC-3 · Compliance acknowledge has no error handling (silent failure)
- **Module:** Director
- **User Journey:** Director taps 'Acknowledge' on a compliance item while offline or when the write is rejected
- **Severity:** ⚪ Low
- **Description:** _acknowledge (director_compliance_screen.dart:124-140) awaits acknowledgeCompliance with no try/catch. The mutation notifier sets AsyncError on failure (director_mutations_provider.dart:47-50) but the screen does not surface it — on failure the success snackbar 'Compliance item acknowledged.' is skipped (because the throw aborts before it) but no error snackbar is shown either, so the user sees nothing and the item stays unacknowledged with no explanation. Contrast the metric-input editor and report export which both show error snackbars.
- **Evidence:** lib/features/director/director_compliance_screen.dart:124-140 (await ...acknowledgeCompliance then invalidate + success snackbar; no catch). Contrast director_metric_input_editor.dart:90-94 (catch → 'Could not save' snackbar).
- **Root Cause:** Inconsistent error-handling pattern; acknowledge omits the catch other Director writes have.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### DIREC-4 · Dashboard 'Executive summary' card is deterministic, not AI — only Reports screen offers AI refinement
- **Module:** Director
- **User Journey:** Director views the executive summary on the main dashboard expecting the same quality as the AI-generated one
- **Severity:** ⚪ Low
- **Description:** The dashboard DirectorExecutiveSummaryCard shows data.executiveSummary which comes from buildExecutiveSummary (deterministic template, director_repository.ts:645) — no Claude refinement. The real-AI refinement (refineExecutiveSummaryWithClaude) only fires via POST /director/summary, which is only invoked by the 'Generate AI Executive Summary' button on the Reports screen. This is by design (per B8 cert) and not a defect, but the dashboard's prominent summary card may read as flatter than the AI one, and there is no AI-refresh affordance on the dashboard itself. Cosmetic/consistency only.
- **Evidence:** director_dashboard_screen.dart:92 (DirectorExecutiveSummaryCard(summary: data.executiveSummary)); director_repository.ts:645 buildExecutiveSummary('dashboard',...) deterministic. AI path only at handleSummary (director_handlers.ts:139) reachable from director_reports_screen.dart:129.
- **Root Cause:** B8 scoped real-AI refinement to the explicit Reports-screen button only; dashboard card kept deterministic baseline.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** AI

**Strengths (working well):**
- Full wire integrity: all 9 GET routes + summary/metric-input/acknowledge/export write paths match client (director_remote_datasource.dart) ↔ deployed VPS router (confirmed via ssh akshara cat director_router.ts).
- RBAC enforced server-side at three layers: module.multi_branch entitlement (index.ts:124), viewDirectorPortal/manageDirectorPortal permission, and org-scope requirement (director_handlers.ts:47-56). Live probe confirmed 403 for school-scoped token, 401 unauth.
- No live mock leak: release build sets DIRECTOR_API_ENABLED=true (config/live_release.json:43, scripts/run_live.sh:47) and HybridDirectorRepository only falls back on ApiNotConnectedException.
- Privacy-by-design: getSchoolRows/getAdmissions select only school-level aggregates (FROM schools s, no student name/guardian/phone/email/aadhaar); a 'No student PII' privacy banner renders on every Director screen (director_module_scaffold.dart:53-58).
- Real AI with safe fallback for the exec summary (director_ai.ts: apiKey guard + refused/empty/throw all fall back to the deterministic brief); board-pack export produces a real multi-section PDF (akshara_report_export_service.dart:325).
- Backend unit tests 10/10 (ran director_repository_test.ts: metric upsert/ownership refusal, board pack, AI no-key fallback, honest-zero marketing). Responsive (card/table) layouts and loading/error/empty states across screens.

---

### Super Admin (Platform + Entitlements)
**Code:** `SA`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Covered all of lib/features/platform (excl organization_builder) and lib/features/entitlements, plus core wiring (lib/core/entitlements, lib/core/repositories/api/control_center, repository_providers, repository_config, rbac_service, role_permissions) and backend _shared/entitlements + _shared/control_center. Traced every screen->provider->repo->path->router->RBAC. Ran 11 GET-only live probes (token=schoolAdmin): /subscription 200, /plans 200, /platform/subscriptions 403, /control-center/{dashboard,schools,subscriptions,features,providers,usage} 403, /platform-operations/* 404. Confirmed deployment via ssh akshara (index.ts imports + control_center & entitlements _shared files present, write-handler RBAC matches local). Did NOT exercise write endpoints (read-only audit). Plan-assignment and Control-Center writes verified by code+RBAC+cert, not by live POST. organization_builder excluded per scope (covered by B10 cert).

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Platform Operations hub (observability/security/alerts/tenant-isolation) | 🔴 broken | No backend route exists: live GET /platform-operations/observability -> 404 'Route not found'; no routePlatformOperations in index.ts. PLATFORM_OPERATIONS_API_ENABLED absent from live_release.json -> repo resolves to MockPlatformOperationsRepository (repository_providers.dart:559-567). Acknowledge-alert write executes against mock (platform_operations_hub_screen.dart:524). Hidden in live because viewPlatformOperations is never seeded server-side. |
| White-Label platform (branding/theme/logo/deployment) | 🔴 broken | WHITE_LABEL flag absent from live_release.json -> MockWhiteLabelPlatformRepository (repository_providers.dart:606-612); no backend route. Save-branding/upload-logo/apply-theme execute against mock and return fake success (white_label_mutations_provider.dart:40,70,100). Hidden because viewWhiteLabelPlatform never seeded server-side. |
| Multi-School portfolio operations (activate/deactivate/dismiss alert) | 🔴 broken | MULTI_SCHOOL_OPERATIONS_API_ENABLED absent from live_release.json -> MockMultiSchoolOperationsRepository (repository_providers.dart:541-547); no backend route in index.ts. activate/deactivate/dismiss writes hit mock (multi_school_portfolio_screen.dart:261,278,186). Hidden because viewMultiSchoolOperations never seeded server-side. |
| Branch operations (assign school to branch) | 🔴 broken | branchRepositoryProvider ALWAYS returns MockBranchRepository (repository_providers.dart:351-353) — no flag, no API repo file. assignSchool fabricates a BranchAssignment success with zero persistence (branch_mutations_provider.dart:39-47). Hidden because manageBranchOperations exists only in client matrix. |
| Franchise operations dashboard | 🔴 broken | franchiseRepositoryProvider always MockFranchiseRepository (repository_providers.dart:355-356); no apiFranchiseRepositoryProvider exists; no backend route. Franchise mutations hit mock (franchise_screen.dart:89). |
| Platform Intelligence (AI insights) | 🟡 partial | PLATFORM_INTELLIGENCE_API_ENABLED absent from live_release.json -> MockPlatformIntelligenceRepository with aiInferencePipeline (repository_providers.dart:341-349). API repo built but no backend route deployed. Mock uses the AI pipeline so output is AI-shaped but not server-grounded. MEMORY note confirms platform-intelligence intentionally OFF (no backend; would 404). |
| Resolve org subscription (plan/entitlements/limits) on app start | ✅ verified | Live GET /subscription -> 200 with real Professional plan, full entitlements[16], capabilities{8}, limits{students:2000,schools:5}, fallbackApplied:false. Client EntitlementApiRepository.fetchSubscription path '/subscription' matches deployed entitlement_router.ts:27. SubscriptionNotifier seeds from cache then refreshes (entitlement_provider.dart:38-64) and never downgrades on transient outage. |
| Public plan catalog (GET /plans) for upgrade UX | ✅ verified | Live GET /plans -> 200, returns trial/standard/professional/enterprise with slabs, pricing. Client path '/plans' (entitlement_api_repository.dart:18) matches router (entitlement_router.ts:24). Cited B2_STEP5_CERTIFICATION.md (4-tier catalog). |
| Plan & Entitlements screen (view plan, locked modules, upgrade CTA) | ✅ verified | plan_entitlements_screen.dart reads subscriptionProvider, shows trial countdown, core vs optional modules with included/locked, WhatsApp upgrade CTA (kAksharaSalesWhatsApp). Read-only, no billing. Defense-in-depth gate present. |
| SuperAdmin assigns/changes an org plan (PUT) | ✅ verified | Live GET /platform/subscriptions -> 403 'Permission required: managePlatformSubscriptions' for schoolAdmin token = RBAC enforced. PUT /platform/organizations/{id}/subscription gates on managePlatformSubscriptions (subscription_admin_handlers.ts:23,61), audited, SECURITY DEFINER. Cited B2_STEP4_5 + B2_STEP5 CERTIFICATION (assign Standard->Professional->Enterprise live, RLS negative test). Client paths match (entitlement_api_repository.dart:43,61). |
| Control Center reads (dashboard/schools/subs/billing/CRM/support/success/analytics/monitoring/roles/settings) | ✅ verified | Live GET /control-center/dashboard\|schools\|subscriptions -> 403 'Permission required: viewControlCenter' = RBAC enforced; routes deployed (ssh: control_center_router.ts present, index.ts:30/109). Reads from org-scoped control_center_entities via controlCenterStore (control_center_handlers.ts:3-7). CONTROL_CENTER_API_ENABLED=true in config/live_release.json. Contract tests pass (control_center_repository_contract_test.dart, gate log). |
| Control Center writes: onboard school, add CRM lead | ✅ verified | POST /control-center/schools & /crm-pipeline gate on manageControlCenter + organization scope (control_center_write_handlers.ts:36-42, deployed-confirmed via ssh), persist to control_center_entities, audited; reads pull same store so writes are visible. Client mutations assert manageControlCenter (control_center_mutations_provider.dart:15-26). |
| Control Center providers/features/vault management | ✅ verified | Live GET /control-center/features -> 403 managePlatformFeatures; /providers -> 403 managePlatformProviders; /usage -> 403 viewPlatformUsage. POST features/providers/vault routes deployed (control_center_router.ts:54-59). Screens wired to live (features_screen.dart:59 setFeatureEnablement; providers_screen.dart:155 _save). |

**Live probes:**
- `GET /subscription (schoolAdmin token)` → 200 — real Professional plan, entitlements[16], capabilities{8}, limits{students:2000,schools:5}, fallbackApplied:false
- `GET /plans` → 200 — trial/standard/professional/enterprise catalog with slabs+pricing
- `GET /platform/subscriptions` → 403 FORBIDDEN 'Permission required: managePlatformSubscriptions' (RBAC working)
- `GET /control-center/dashboard | schools | subscriptions` → 403 'Permission required: viewControlCenter' (RBAC working)
- `GET /control-center/features` → 403 'Permission required: managePlatformFeatures'
- `GET /control-center/providers` → 403 'Permission required: managePlatformProviders'
- `GET /control-center/usage` → 403 'Permission required: viewPlatformUsage'
- `GET /platform-operations/observability` → 404 'Route not found' — confirms no backend for Platform Operations (flag correctly off)
- `ssh akshara cat/ls /opt/akshara/functions` → index.ts imports routeControlCenter (line 30/109) + routeEntitlements (66/137); _shared/control_center and _shared/entitlements files present; deployed write-handler RBAC (manageControlCenter + organization scope) matches local

**Issues:**

#### SA-1 · Client RBAC matrix grants superAdmin platform permissions the server never seeds (client/server drift)
- **Module:** Super Admin
- **User Journey:** Platform Operations / White-Label / Multi-School / Branch / Franchise navigation
- **Severity:** 🟡 Medium
- **Description:** RolePermissionMatrix (role_permissions.dart:146-163) grants ErpRole.superAdmin viewPlatformOperations, managePlatformOperations, viewWhiteLabelPlatform, manageWhiteLabelPlatform, viewMultiSchoolOperations, manageMultiSchoolOperations. None of these permissions exist in ANY server migration (grep of supabase/migrations: 0 files for each). The admin nav filters tiles by rbac.hasPermission (admin_navigation_provider.dart:220). In correctly-synced live API mode the server snapshot wins (rbac_service.dart:61-71) so tiles stay hidden; but if the server permission sync is stale/empty and JWT carries no perms, F1 fail-closed yields an empty set (good) — however the offline/non-API fallback (rbac_service.dart:94-95 maps staff->superAdmin via local matrix) WOULD surface these tiles, opening mock-backed screens. The matrix advertising capabilities the platform cannot actually serve is a latent inconsistency.
- **Evidence:** role_permissions.dart:146-163 (matrix grants); grep supabase/migrations -> 0 occurrences of viewPlatformOperations/viewWhiteLabelPlatform/viewMultiSchoolOperations/viewFranchiseOperations; rbac_service.dart:94-95 local-matrix fallback
- **Root Cause:** Client permission matrix lists future/unbuilt platform capabilities for superAdmin that have no server-side definition or backend, creating client-vs-server permission drift.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** RBAC

#### SA-2 · Mock-backed platform write actions fabricate success in the live build (no persistence)
- **Module:** Super Admin
- **User Journey:** Branch assign-school; White-Label save branding/upload logo/apply theme; Multi-School activate/deactivate/dismiss; Platform-Ops acknowledge alert; Franchise mutations
- **Severity:** 🟡 Medium
- **Description:** In the live release (config/live_release.json) the flags for white-label, multi-school-operations, platform-operations and platform-intelligence are absent (=> default false) and branch/franchise have no flag at all, so these repositories resolve to Mock* implementations. Their write actions (execute()/assignSchool()) succeed against in-memory mocks and show success snackbars while persisting nothing to any backend (and no backend route exists: GET /platform-operations/observability -> 404 live). This is the 'write silently hits a mock in a live build' pattern. Currently masked only because the gating permissions are not server-granted, but if ever exposed (matrix fallback or new grant) it is a data-integrity hazard.
- **Evidence:** repository_providers.dart:351-356 (branch/franchise always Mock), 541-567 & 606-612 (multi-school/platform-ops/white-label Mock when flag off); branch_mutations_provider.dart:39-47; white_label_mutations_provider.dart:40,70,100; multi_school_portfolio_screen.dart:261,278; live probe /platform-operations/observability -> 404
- **Root Cause:** Five platform sub-modules ship UI + mock repos but no deployed backend/route and no live flag; mock fallback returns fabricated success instead of a 'not available' state.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### SA-3 · Platform sub-screens are deep-link reachable despite no nav tile and no backend
- **Module:** Super Admin
- **User Journey:** Direct navigation to /platform-operations, /white-label, /multi-school, /franchise, /branch routes
- **Severity:** ⚪ Low
- **Description:** All platform routes are registered in app_router.dart (lines 664,890,939+,1128+) and reachable by deep-link even though their nav tiles are hidden by (unseeded) permissions and their backends 404. There is no route-level redirect guard tying these to a server-enforced permission, so a stale-sync or deep-link entry lands the user on a mock-data screen presented as real platform monitoring/security data (e.g. platform_operations security dashboard). Control Center and plan-assignment, by contrast, are server-enforced (403 live).
- **Evidence:** app_router.dart:664/890/939/1128 route registrations with no permission redirect; live 404 for the corresponding backend; admin_navigation_provider.dart:220 hides tile but route still resolves
- **Root Cause:** Routes lack a redirect/guard binding to a server-validated permission for unbuilt platform surfaces.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** RBAC

#### SA-4 · Plan-assignment save surfaces raw exception text to the user
- **Module:** Super Admin
- **User Journey:** SuperAdmin assigns a plan and the call fails
- **Severity:** ⚪ Low
- **Description:** organization_plan_assignment_screen.dart:218 shows SnackBar('Could not update plan: $e') interpolating the raw exception/DioException toString rather than mapping through apiFailureMapper (which the screen already imports and uses for the load path at line 78). A backend 400 INVALID_PLAN or 403 would render an opaque technical string to the admin.
- **Evidence:** organization_plan_assignment_screen.dart:214-219 (raw $e) vs the load path using AksharaErrorState.fromFailure(apiFailureMapper.fromException(e)) at line 78
- **Root Cause:** Save-action error path bypasses the failure mapper used elsewhere in the same screen.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

**Strengths (working well):**
- Entitlement layer is fully real and live-certified: GET /subscription and /plans return real production data (Professional plan, 16 entitlements, limits), enforcement ON per B2_STEP5_CERTIFICATION; client paths match the deployed router exactly.
- Plan assignment (the core super-admin write) is server-RBAC-enforced: live probe of /platform/subscriptions returns 403 managePlatformSubscriptions for a non-superAdmin token, with SECURITY DEFINER + audit + RLS-negative test cited in B2_STEP4_5.
- Control Center is a genuinely live module: 15 read snapshots + 5 write routes (schools, leads, providers, features, vault) deployed (ssh-confirmed), each gated by a distinct permission (viewControlCenter/manageControlCenter/managePlatform*), reads and writes share the same org-scoped control_center_entities store so writes are durable and visible.
- Strong defense-in-depth on writes: client mutation notifiers re-assert permissions (assertManageControlCenter, assertManageBranchOperations) before calling, and the server independently enforces.
- Good test coverage: mock/api contract-parity tests pass for control_center, platform_operations, white_label (gate log); deno entitlement enforcement tests (402 PLAN_UPGRADE_REQUIRED, Trial locks optional modules) pass.
- Entitlement ceiling model is correct: capabilities (school-enabled, intersected) vs entitlements (plan ceiling) distinction is intentional and the client planCeiling() derives correctly from the entitlements array.
- Locked-module UX is consistent: EntitlementModuleGate + PlanLockedModuleView show (never hide) locked modules with WhatsApp upgrade CTA and no in-app payment, matching approved design.

---

### Admissions
**Code:** `ADMIS`  ·  **Verdict:** `gaps-block-cert`

_Coverage:_ Traced every screen in lib/features/admissions (9 nav tabs + lead detail) to its provider→repository→client path→deployed router route→handler→RBAC. Cross-checked all client paths in admissions_api_paths.dart against admissions_router.ts AND the live-deployed router (ssh akshara). Ran 14 read-only live GET probes against the production edge with the schoolAdmin token (5 returned 404, documented). Cited B1 + B4 certs for the two already-certified journeys rather than re-litigating. Did NOT exhaustively click through every widget/dialog rendering, and did not test POST/PUT/PATCH/DELETE live (audit is read-only) — write-path correctness is inferred from handler code + cert smoke results. Documents real-file-storage gap and approval-fixture gap found by code reading, not live write."

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Enrollment wizard: prefill → submit → pending list → SIS conversion (creates student) | 🔴 broken | Submit works: POST /admissions/enrollments deployed (admissions_router.ts:128), backend INSERTs students + admissions_enrollments + links guardian (admissions_repository.ts:731-803); SIS conversion POST /sis/admissions-conversion deployed (live GET 404=exists, deno tests pass). BUT the Enrollment SCREEN's prefill (GET /admissions/enrollment/prefill) and pending-records list (GET /admissions/enrollments/pending) both return 404 live — neither route exists in deployed router. |
| Approval queue: load queue → review → approve/reject → notes | 🔴 broken | GET /admissions/approval-queue 404 live (no route) — queue cannot load, so approve/reject (which DO exist) have no IDs to act on. Approval review panel shows HARDCODED fixture data (fake counselor notes 'Meera N.', fake history 'Principal Sharma', feePlanLabel 'Standard CBSE · 3 installments', fixed dates) — admissions_approval_provider.dart:83-126. addApprovalNote client calls POST /admissions/approval/{id}/notes which has no server route. |
| Reports (funnel/source/counselor analytics) | 🔴 broken | GET /admissions/reports 404 live; no route in admissions_router.ts. Reports is a primary nav tab (admissions_navigation.dart:24,50). Provider calls getReports directly (admissions_reports_provider.dart:19). |
| Settings: view + save module settings | 🔴 broken | GET /admissions/settings 404 live; PUT also 404. No route in router. Settings is a primary nav tab (admissions_navigation.dart:25,51). Save button wired to updateSettings (admissions_settings_screen.dart:85,337). |
| Documents: list → upload → approve/reject | 🟡 partial | List GET /admissions/documents 200 live; upload/approve/reject routes deployed (admissions_router.ts:101-116) with approveAdmissions RBAC (admissions_handlers.ts:864,909). BUT uploadDocument persists only metadata (file_name, no file_url/storage) — admissions_repository.ts:556; no real file is stored or retrievable. |
| Fee handoff to Finance: list approved → pick fee structure → send → status | 🟡 partial | handoffs/approved (GET 200 live) + handoffs/send (POST) + handoffs/{id}/status (PATCH) all deployed (admissions_router.ts:132-142). BUT the fee-structure picker calls GET /admissions/fee-structures → 404 live (wrong path; the real route is /finance/fee-structures per finance_router.ts:123). Without the dropdown the user cannot choose a feeStructureId to send. |
| Lead CRM funnel: list → detail/timeline → create → update → assign counselor → change stage → follow-up → note → WhatsApp/call log | ✅ verified | B1 cert 11/11 live smoke (docs/B1_ADMISSIONS_CRM_CERTIFICATION.md:47,63-66). Live probes: GET /admissions/leads 200 (real rows), GET /admissions/leads/{id} 200 (B1 persisted timeline). Client paths in admissions_api_paths.dart:24-28 match deployed router admissions_router.ts:38-76. Mutations have client perm-asserts + ApiFailureException error mapping (admissions_mutations_provider.dart:90-92,104). Leads screen has retry/error view-state (admissions_leads_screen.dart:69-70). |
| AI next-best-action (admissions assistant / intelligence) | ✅ verified | B4 cert 8/8 live, real Claude (docs/B4_AI_ADMISSIONS_ASSISTANT_CERTIFICATION.md:8,71-86). Live probe GET /admissions/intelligence 200 returns real funnel (totalLeads:4, unassignedLeads:3) + ranked nextBestActions ([high] unassigned_leads). Route deployed admissions_router.ts:44. RBAC viewAdmissions (admissions_intelligence_handlers via dashboard scope). |
| Applications: list → create → update → submit (→ approval row) | ✅ verified | Routes deployed admissions_router.ts:78-99; GET /admissions/applications 200 live. handleSubmitApplication calls ensureApprovalForApplication (admissions_handlers.ts:739). Client paths match (admissions_api_paths.dart:30-33). |

**Live probes:**
- `GET /admissions/leads (schoolAdmin token)` → 200 — real rows (e.g. 'P1 Integ Parent', source facebook, stage new_enquiry)
- `GET /admissions/leads/{id}` → 200 — B1 persisted lead detail/timeline
- `GET /admissions/intelligence` → 200 — funnel totalLeads:4/unassignedLeads:3 + ranked NBA [high] unassigned_leads
- `GET /admissions/dashboard` → 200
- `GET /admissions/applications` → 200
- `GET /admissions/documents` → 200
- `GET /admissions/handoffs/approved` → 200
- `GET /admissions/reports` → 404 — no route (breaks Reports tab)
- `GET /admissions/settings` → 404 — no route (breaks Settings tab)
- `GET /admissions/approval-queue` → 404 — no route (breaks Approval tab)
- `GET /admissions/fee-structures` → 404 — wrong path; real route is /finance/fee-structures
- `GET /admissions/enrollments/pending` → 404 — no route (breaks Enrollment list)
- `GET /admissions/enrollment/prefill` → 404 — no route (breaks Enrollment prefill)
- `GET /sis/admissions-conversion` → 404 on GET = route exists POST-only (deployed; enrollment→student conversion works)
- `ssh akshara grep deployed admissions_router.ts for missing routes` → NONE FOUND — confirms 404s are real deploy state, not local drift

**Issues:**

#### ADMIS-1 · 5 admissions GET endpoints 404 in live build — Reports, Settings, Approval-queue, Enrollment pending, Enrollment prefill
- **Module:** Admissions
- **User Journey:** School admin opens Admissions → Reports / Settings / Approval / Enrollment tabs
- **Severity:** 🔴 Critical
- **Description:** In the live release config (config/live_release.json:8 ADMISSIONS_API_ENABLED=true + ENABLE_API_MODE=true), the API repository is active. Its datasource calls /admissions/reports, /admissions/settings, /admissions/approval-queue, /admissions/enrollments/pending, /admissions/enrollment/prefill — none of which exist in the router (locally or on the deployed VPS). Each returns 404, breaking 4 of the 9 primary admissions nav tabs for the schoolAdmin role.
- **Evidence:** Live probes: GET /admissions/{reports,settings,approval-queue,enrollments/pending,enrollment/prefill} all = 404. Client paths: admissions_api_paths.dart:8,13-16. Router has no such routes: admissions_router.ts:34-144 (confirmed on VPS via ssh akshara grep → 'NONE FOUND in deployed router'). Providers call them: admissions_reports_provider.dart:19, admissions_settings_provider.dart:14, admissions_approval_provider.dart:28, admissions_enrollment_records_provider.dart:24, admissions_enrollment_provider.dart:19.
- **Root Cause:** B1/B4 only built+certified the Leads CRM + Intelligence/Dashboard endpoints. The remaining admissions sub-modules (Reports, Settings, Approval queue, Enrollment list/prefill) shipped Flutter screens + API client paths but the backend routes/handlers were never built — yet the module flag is flipped ON in the live config, so they hit live 404s instead of falling back to mock.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### ADMIS-2 · Fee-handoff fee-structure picker points at non-existent /admissions/fee-structures
- **Module:** Admissions
- **User Journey:** Admin: Admissions → Fee Handoff → select an approved student → choose fee structure → Send to Finance
- **Severity:** 🟠 High
- **Description:** The fee-structure dropdown loads from GET /admissions/fee-structures, which 404s live. The real route is /finance/fee-structures (finance_router.ts:123). Without the dropdown the user cannot pick a feeStructureId, so the otherwise-working handoffs/send flow is unusable end-to-end.
- **Evidence:** Live probe GET /admissions/fee-structures = 404. Client: admissions_api_paths.dart:12 feeStructures='/admissions/fee-structures'; called at api_admissions_repository.dart:105. Correct route exists elsewhere: finance_router.ts:123 '/finance/fee-structures'.
- **Root Cause:** Client path was authored under the /admissions prefix but the fee-structure data lives in the Finance module; the cross-module path was never reconciled.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Cross-module

#### ADMIS-3 · Approval review panel shows hardcoded fixture data to real users
- **Module:** Admissions
- **User Journey:** Principal: Admissions → Approval → select a pending application → review notes/history before approving
- **Severity:** 🟠 High
- **Description:** Even if the approval queue loaded, the review detail (counselor notes, decision history, fee plan label) is fabricated client-side: fake authors ('Meera N.', 'Principal Sharma'), fake comments, fixed dates ('4 Jun · 2:30 PM'), feePlanLabel 'Standard CBSE · 3 installments'. A principal would make an approval decision against fictitious context. The addApprovalNote action also has no server route.
- **Evidence:** admissions_approval_provider.dart:83-126 (_buildReview hardcodes notes[]/history[]/feePlanLabel). addApprovalNote client path admissions_api_paths.dart:45-46 '/admissions/approval/{id}/notes' has no matching router entry (admissions_router.ts:118-126 only has /approve and /reject).
- **Root Cause:** Approval review UI was built ahead of the backend; the timeline/notes were stubbed with fixtures and never replaced with persisted data (same anti-pattern B1 fixed for the leads timeline, but never applied to approvals).
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### ADMIS-4 · generate-admission-number endpoint missing server route
- **Module:** Admissions
- **User Journey:** Admin generates an admission number during enrollment/application finalization
- **Severity:** 🟡 Medium
- **Description:** Client calls POST /admissions/enrollments/generate-admission-number (admissions_api_paths.dart:19) but no router entry exists; it would 404 in live mode. (Note: submitEnrollment already auto-generates an admission number server-side, so this client call may be vestigial — but if any screen invokes it, it fails.)
- **Evidence:** admissions_api_paths.dart:19 enrollmentsGenerateNumber; called api_admissions_repository.dart:246-250. No matching route in admissions_router.ts. Backend auto-gen lives only inside submitEnrollment (admissions_repository.ts:728).
- **Root Cause:** Client method shipped without a corresponding backend route; admission-number generation was folded into submitEnrollment instead.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### ADMIS-5 · Document upload stores metadata only — no real file is uploaded or retrievable
- **Module:** Admissions
- **User Journey:** Counselor uploads a student's marks memo / Aadhaar during admissions
- **Severity:** 🟡 Medium
- **Description:** handleUploadDocument/uploadDocument persist only document_type, file_name and status — there is no file_url, storage object, or signed URL. The 'uploaded' document cannot actually be viewed or downloaded by the verifier/principal, undermining the document-verification approve/reject workflow.
- **Evidence:** admissions_repository.ts:535-556 (INSERT lists document_type, file_name, is_required, status, uploaded_at — no file_url/storage). No Supabase Storage call in the admissions upload path. Contrast: device-memories module uses real Storage signed URLs (per Batch 7 memory).
- **Root Cause:** Document upload was implemented as a metadata-only placeholder; real file storage (already available via Supabase Storage from Batch 7) was never wired into admissions.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### ADMIS-6 · Live module flag ON for unbacked sub-modules causes user-facing 404s instead of graceful degradation
- **Module:** Admissions
- **User Journey:** Any pilot user navigating beyond Leads/Dashboard in Admissions
- **Severity:** 🟡 Medium
- **Description:** ADMISSIONS_API_ENABLED is a single module-wide flag (repository_config.dart:33). Because only part of the module has a backend, flipping it ON in live exposes the unbacked tabs as hard 404 errors. There is no per-endpoint fallback to mock for the missing routes, so the affected screens show error states rather than usable data.
- **Evidence:** repository_config.dart:33-39 single flag; live_release.json:8 = true; repository_providers.dart:139-143 selects ApiAdmissionsRepository wholesale (no partial fallback). Confirmed by the 5 live 404 probes above.
- **Root Cause:** Coarse module-level API gating doesn't match the partially-built backend; no per-capability gating or mock fallback for not-yet-built routes.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Live-deploy-drift

**Strengths (working well):**
- Lead CRM funnel is genuinely production-grade and live-certified: real persistence (admissions_lead_activities/_follow_ups), real audit events, RBAC manageAdmissions on every write, B1 11/11 live smoke; verified by my own GET probes (leads list + detail = 200 with real rows).
- AI admissions assistant / next-best-action is real and grounded: GET /admissions/intelligence returns a real funnel + ranked deep-linkable actions; B4 8/8 live with stub=false (real Claude). Deterministic NBA engine has 6 unit tests.
- Backend RBAC is consistent and correct: view* on reads, manage* on writes, approve* on approvals/documents, plus requireSchoolOperationalScope on every handler (admissions_handlers.ts throughout). Cross-school + parent-scope denial verified in B1/B4 certs.
- Mutation layer is robust: client-side permission asserts (assertManageAdmissions), uniform ApiFailureException error mapping, and read-invalidation after writes (admissions_mutations_provider.dart:68-92). Leads screen has explicit loading/error/retry view-states.
- Enrollment→SIS handoff (the core cross-module value) is real and well-tested: submitEnrollment creates a student + pending enrollment + guardian link; POST /sis/admissions-conversion (deployed) converts to a SIS profile with idempotency + cross-school guards (deno tests all green).

---

### Finance
**Code:** `FINAN`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Covered all 14 finance screens + QR/collection-detail flows, both routers (finance + payment), all 15 server handler files, RBAC (server + UI + route guards), mock-vs-live wiring, and state handling. Confirmed deployment via ssh diff of routers (identical) and 16 live GET probes (all 200). Cited Batch4 money-loop and P1 cert for already-proven loop & parent visibility rather than re-litigating. Did not exercise write paths (read-only audit) — relied on handler code + cert evidence. Razorpay real-money path and AI-narrative wiring are owner-gated and out of code-fix scope.

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| QR/UPI payment session (office-side mark-paid) | 🟡 partial | finance_qr_handlers.ts builds real upi://pay payload + creates/confirms session in DB; confirm is a STAFF manual mark-paid gated by manageFinance (no gateway verification) — legitimate office model. Razorpay gateway (real money) is separate and in stub mode (see issue). |
| Finance Copilot / Executive dashboard (analytics) | 🟡 partial | Live GET /finance/intelligence/copilot & /executive 200 with forecasts/risk scores. finance_intelligence_service.ts has NO Claude call — purely DETERMINISTIC analytics. Functional and correct, but UI labels it 'Copilot' implying AI (see issue). |
| Parent self online payment (Razorpay) | 🟡 partial | parent_router.ts:31-34 /parent/payments/initiate\|confirm → payment_handlers.ts (shared Razorpay). razorpay_config.ts:15 RAZORPAY_STUB_MODE defaults 'true'; no RAZORPAY_* env on VPS → runs in stub (no real money). Owner-gated. |
| Define fee structure → assign → invoice → collect → receipt → parent sees it | ✅ verified | Batch 4 cert (akshara-batch4-money-loop) proves loop live & durable. Re-confirmed live: GET /finance/fee-structures, /fee-assignments, /invoices, /collections all 200 with real DB rows (e.g. INV-PROBE-A-2026, RCPT-2026-CCEA11E3). Client createCollection→handleCreateCollection auto-creates finance_receipts and recomputes invoice. Parent routes /parent/fees,/parent/receipts deployed (parent_router.ts:51-52). |
| Admissions → Finance fee handoff (assign from approved-handoff queue) | ✅ verified | finance_fee_assignment_screen.dart:100 executeAssignFeePlan → POST /finance/fee-assignment/assign → handleAssignFeePlan → assignFromHandoff (finance_assignments_repository.ts:425 UPDATE admissions_fee_handoffs SET handoff_status='completed'). Backend persists handoff completion; client override is just optimistic UI. Real cross-module write confirmed. |
| Discounts / scholarship rule create + update | ✅ verified | finance_discounts_handlers.ts handleCreateDiscountRule/handleUpdateDiscountRule are real DB writes with audit (memory note of UnimplementedError is STALE — fixed in Batch 5). GET /finance/discounts live 200 with 2 scholarships, KPIs computed. Scholarship create via handleCreateScholarship (manageFinance). |
| Offline cash/cheque payment record + reconcile | ✅ verified | finance_offline_payments_repository.ts:83 INSERT INTO finance_offline_payments, :172 UPDATE for reconcile. Live GET /finance/payments/offline 200 with real rows (status reconciled). Screen uses PermissionGated manageFinance. |
| Defaulters tracking + WhatsApp reminder | ✅ verified | Live GET /finance/defaulters 200 (aging buckets, KPIs). finance_defaulters_screen.dart:175 WhatsAppContactButton(phone: record.guardianPhone) + reminder template line 273 (B5 cert). |
| Refund request → approve/reject | ✅ verified | Live GET /finance/refunds 200. Create gated manageFinance; approve/reject gated Permission.approveRefunds (finance_refunds_screen.dart:275,291) and server approveRefunds. Separation of create vs approve enforced. |
| Reports view + PDF export | ✅ verified | Live GET /finance/reports 200 (collection/outstanding catalog). finance_reports_screen.dart:117 aksharaReportExportServiceProvider builds PDF client-side. |
| Settings view + update | ✅ verified | Live GET /finance/settings 200 (receipt/invoice prefixes). PUT /finance/settings → handleUpdateSettings (manageFinance). |
| Inventory-finance reconciliation | ✅ verified | Live GET /finance/inventory-reconciliation/dashboard 200 (vendor/PO/AP commitments, inventoryValue). Client paths in inventory_finance_api_paths.dart match router. |

**Live probes:**
- `GET /finance/dashboard` → 200 — totalInvoiced 50000, totalCollected 7500, outstanding 44500, pendingRefunds 1; real DB
- `GET /finance/fee-structures /fee-assignments /invoices /collections` → all 200 with real seed rows (Probe Structure A, INV-PROBE-A-2026, RCPT-2026-CCEA11E3)
- `GET /finance/refunds /discounts /defaulters /reports /settings /collections/daily-summary` → all 200 with computed KPIs/catalogs
- `GET /finance/intelligence/copilot & /executive` → 200 — deterministic forecasts (8100, confidence 62) & risk scores
- `GET /finance/payments/offline & /finance/inventory-reconciliation/dashboard` → 200 — real offline payment rows (reconciled) & AP commitments 55000
- `GET /finance/collections/{id}, /invoices/{id}, /student-accounts/{id}` → 200 — resolve real rows (Staging Student, Probe Handoff A)
- `GET /finance/bogus` → 404 — unknown route correctly rejected
- `diff deployed vs local finance_router.ts & payment_router.ts` → IDENTICAL — no deploy drift
- `ssh grep RAZORPAY_* env on VPS` → none set → payment stub mode active

**Issues:**

#### FINAN-1 · Razorpay online payment runs in stub mode (no real money movement)
- **Module:** Finance
- **User Journey:** Parent self online payment (Razorpay)
- **Severity:** 🟠 High
- **Description:** The parent online-pay path (/parent/payments/initiate|confirm) and office /payments/intents/* share payment_handlers.ts which falls back to a fake intent/confirm whenever Razorpay keys are absent. razorpay_config.ts:15 defaults RAZORPAY_STUB_MODE to 'true' and no RAZORPAY_KEY_ID/SECRET/WEBHOOK_SECRET are set on the VPS, so any 'online payment' a parent makes is simulated — invoice can be marked paid without real settlement.
- **Evidence:** razorpay_config.ts:12-22 (keyId/keySecret from env, stubMode:!enabled, forceStub default true); payment_handlers.ts:216 'else if (razorpay.stubMode)'; ssh akshara found no RAZORPAY_* env vars set.
- **Root Cause:** Real payment gateway not yet provisioned (owner-gated: needs Razorpay merchant account + keys + webhook). Stub is intentional for pre-launch.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Live-deploy-drift (owner-gated)

#### FINAN-2 · Create Refund & Create Scholarship dialogs pre-fill hardcoded fake student data
- **Module:** Finance
- **User Journey:** Refund request → approve/reject
- **Severity:** 🟡 Medium
- **Description:** Opening the Create Refund dialog pre-populates a fictitious real-looking student ('Arjun Patel', admission 'ADM-2026-0138', fee account 'acct_1', ₹5,000, receipt 'RCP-2026-0142'). Create Scholarship pre-fills 'Arjun Patel'/'acct_1'/₹15,000. An admin who doesn't clear every field can submit a refund/scholarship against a fake student/wrong amount — a data-integrity hazard in a money module.
- **Evidence:** finance_workflow_actions.dart:224-231 (refund controllers) and :318-322 (scholarship controllers) — unconditional TextEditingController(text: 'Arjun Patel' …); submitted verbatim at :286-296.
- **Root Cause:** Demo seed values left in production dialog initializers; not replaced with empty/required-validated fields.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### FINAN-3 · Standalone receipt PDF export uses hardcoded/placeholder fields
- **Module:** Finance
- **User Journey:** collect → receipt
- **Severity:** 🟡 Medium
- **Description:** ExportReceiptPdfNotifier builds the receipt PDF with studentName set to receipt.studentAccountId (a UUID, not the student's name), classLabel:'N/A', paymentMethod:'N/A', and statusLabel:'Paid' hardcoded regardless of the receipt's true status. A receipt exported via this path shows a UUID instead of the student and always says 'Paid'.
- **Evidence:** finance_mutations_provider.dart:898-908 (studentName: receipt.studentAccountId, classLabel:'N/A', paymentMethod:'N/A', statusLabel:'Paid', schoolName hardcoded 'Akshara Public School').
- **Root Cause:** Receipt DTO from GET /finance/receipts/{id} lacks denormalized student name/class/method, so the export filled placeholders instead of joining/fetching collection detail.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### FINAN-4 · Finance 'Copilot/Intelligence' is deterministic analytics, labeled as AI Copilot
- **Module:** Finance
- **User Journey:** Finance Copilot / Executive dashboard
- **Severity:** ⚪ Low
- **Description:** finance_intelligence_service.ts contains no LLM call; forecasts, confidence %, defaulter risk scores are computed deterministically. The screen titles/labels it 'Copilot' which can imply generative AI insights to users. Functionally correct, but the 'AI' framing overpromises vs the real (rule-based) engine. (B9 added a separate real-AI predictions module; finance copilot itself is not wired to it.)
- **Evidence:** grep for claude/anthropic in finance_intelligence_service.ts & handlers → none; live copilot returns fixed-formula values (forecast 8100, confidence 62). finance_copilot_screen.dart:13 'Finance Copilot — forecasting…'.
- **Root Cause:** Module named/branded as Copilot before any LLM narrative was wired; analytics are deterministic by design.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** AI

#### FINAN-5 · No self-approval prevention on refunds
- **Module:** Finance
- **User Journey:** Refund request → approve/reject
- **Severity:** ⚪ Low
- **Description:** handleApproveRefund does not check that the approver differs from the refund's requester. A user holding both manageFinance and approveRefunds could create and approve their own refund. In practice these are usually separate roles, so risk is low, but a hard server check would enforce maker-checker.
- **Evidence:** finance_refunds_handlers.ts handleApproveRefund: approveRefund(db,…,auth.claims.sub) with no comparison to the refund's createdBy/requestedBy.
- **Root Cause:** Maker-checker separation enforced only by role assignment convention, not by an explicit server-side identity check.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** RBAC

**Strengths (working well):**
- Client API path constants (finance_api_paths.dart) match the deployed router exactly; finance_router.ts and payment_router.ts diff IDENTICAL to /opt/akshara/functions (no live-deploy drift).
- Every finance server handler enforces RBAC: viewFinance for reads, manageFinance for writes, approveRefunds for refund approval, plus requireSchoolOperationalScope — verified across all 15 handler files.
- UI is consistently capability-gated: write buttons wrapped in PermissionGated(Permission.manageFinance), refund approve/reject in approveRefunds; route guards use longest-prefix matching to prevent privilege escalation to child routes (route_guards.dart:154-170).
- Unified state handling: 13/14 screens use FinanceAsyncBody with loading/error/empty/retry (finance_async_state.dart); QR screen handles its own busy state; all mutations map exceptions to ApiFailureException and surface via SnackBar.
- No mock fallbacks in live finance paths: grep for UnimplementedError/ApiNotConnectedException/TODO in lib/features/finance + api/finance returned nothing; HybridFinanceRepository routes 100% to ApiFinanceRepository; config/live_release.json sets FINANCE_API_ENABLED=true.
- All 16 probed finance GET endpoints returned 200 live with real DB data; 404 correctly returned for unknown routes; detail endpoints (collection/invoice/student-account by id) resolve real rows.
- Core money loop, parent visibility, and the one P1 cross-batch handoff gap are already cert-proven (Batch 4 + P1 integration cert); admissions→finance handoff completion is persisted server-side (UPDATE admissions_fee_handoffs).

---

### Attendance
**Code:** `ATTEN`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Traced teacher (mark/draft/submit/correction), parent and student (view + correction), and management corrections-admin flows screen→provider→repo→client path→deployed router→handler→RBAC→DB/RLS. Confirmed deployment via ssh akshara for attendance_router, index.ts wiring, approval_type_handlers and attendance_correction_repository. Ran GET-only live probes for /attendance/sessions, /attendance/corrections, /teacher/attendance/classes, /parent/attendance. Grepped gate logs for attendance tests. NOT separately audited (different modules, only confirmed they are distinct subsystems, not student attendance): HR staff attendance (lib/features/hr/attendance), transport boarding attendance, hostel attendance — these have their own repositories/routes and were out of scope for the student-attendance core loop. The two High findings (correction-apply 0-row UPDATE; parent correction 403) are code-evidenced and live-confirmed in source but not write-probed (read-only mandate).

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Correction approval applies the change to actual attendance records | 🔴 broken | applyAttendanceCorrection (attendance_correction_repository.ts:198-254, deployed) UPDATEs attendance_records joined on s.class_label=$4 (correction's 'classLabel-section', e.g. '8-A') and s.session_date=COALESCE(ac.session_date,CURRENT_DATE). But (a) createAttendanceCorrection INSERT (lines 151-175) never writes session_date → always NULL → falls back to CURRENT_DATE, and (b) attendance_sessions.class_label is stored as the raw class_id ('class_8a', pilot_operations_handlers.ts:127) while corrections store parsed '8'/'8-A'. Both mismatches mean the UPDATE affects 0 rows: correction flips to 'approved' but the student's mark is NOT changed. No deno test exercises applyAttendanceCorrection. |
| Parent submits attendance correction → principal approval | 🔴 broken | parent_mutations_provider.dart:229-247 submits via attendanceCorrectionRepositoryProvider.createCorrection → POST /attendance/corrections, which requires requireAttendanceWrite = manageSis OR school operational scope (attendance_handlers.ts:38-43,163-195). A parent has scope='parent' and no school scope/manageSis, so the server returns 403. The parent UI (parent_attendance_workflow.dart) always offers the dialog but the write will fail. |
| Admin/principal reviews correction queue | 🟡 partial | attendance_corrections_admin_screen.dart lists live corrections (attendanceCorrectionRepositoryProvider.listCorrections, good loading/error/empty states) but the top KPI card reads MockAttendanceSyncStore.instance (lines 31,57-65) — in-memory mock that is empty for the admin's session, so it always shows 'No teacher submission yet'. Screen is read-only; approval happens in Approval Center (link). |
| Teacher marks class attendance (mark roster → save draft → submit → guardians alerted) | ✅ verified | Client POST /teacher/attendance/draft & /submit via teacher_remote_datasource.dart:131-153, paths teacher_api_paths.dart:19-20 match deployed pilot_operations_router.ts:18-23. Handler upserts attendance_sessions (submitted) + enqueues guardian 'Attendance alert' notifications for absentees (pilot_operations_handlers.ts:108-168). Live GET /attendance/sessions returns persisted submitted sessions. Durability confirmed in batch3 cert. |
| Privacy: parent/student see only their own attendance (RLS) | ✅ verified | Migration 20260706000000_attendance_records_parent_privacy_rls.sql restricts parent SELECT to student_guardians-linked children and student to own record; school scope keeps full access. Live GET /parent/attendance with schoolAdmin token correctly 403s ('Parent data requires parent scope'). Closes batch3 follow-up leak. |
| Parent/student view monthly attendance | ✅ verified | parent_attendance_provider.dart:27-33 → GET /parent/attendance; student_attendance_provider.dart:24-30 → GET /student/attendance. Backend handleAttendanceSnapshot overlays real attendance_records via overlayAttendanceSnapshotFromRecords (mobile_read_handlers.ts:169-208). Real data path. |
| Teacher submits attendance correction → principal approval → status reflected | ✅ verified | teacher_mutations_provider.dart:394-448 does createCorrection (POST /attendance/corrections, manageSis-gated) + submits to Approval Center. Backend approval_type_handlers.ts:112-141 handles attendanceCorrection on approve/reject (server-owned). Client correctly skips mock adapter side-effects in live mode (approval_center_provider.dart:198-199 skipDomainEffects=approvalApiEnabled). Approval gated on approveAttendanceCorrection w/ separation of duties (approval_permissions.ts:7). Submit/status lifecycle covered by attendance_correction_repository_contract_test. NOTE: the actual records mutation on approval is the separate broken journey above. |

**Live probes:**
- `GET /attendance/sessions (schoolAdmin token)` → 200 — returns persisted submitted sessions incl. classLabel '5-A' and a classLabel:'' recordCount:0 row; confirms marking persists but class label = class_id and empty sessions accepted.
- `GET /attendance/corrections (schoolAdmin token)` → 200 — returns real correction rows (att_corr_3 status 'pending', requesterRole 'teacher'); confirms correction create/list is live.
- `GET /teacher/attendance/classes (schoolAdmin token)` → 200 — {items:[{id:'class_8a',label:'8-A Mathematics',studentCount:32}]}; confirms class roster read is live.
- `GET /parent/attendance (schoolAdmin token)` → 403 FORBIDDEN 'Parent data requires parent scope' — confirms parent-scope RBAC enforced.
- `ssh akshara grep attendance routes in /opt/akshara/functions/...` → attendance_router, index.ts routeAttendance+routePilotOperations, approval_type_handlers attendanceCorrection case, and attendance_correction_repository (with the session_date/class_label mismatch) all present on live — matches repo.

**Issues:**

#### ATTEN-1 · Approved attendance correction never updates the actual attendance record (0-row UPDATE)
- **Module:** Attendance
- **User Journey:** Teacher/principal approves a correction (e.g. Absent→Present) but the student's attendance stays wrong; parent still sees the old mark.
- **Severity:** 🟠 High
- **Description:** applyAttendanceCorrection matches the attendance_records row by attendance_sessions.class_label AND session_date. createAttendanceCorrection never populates the nullable session_date column (only date_label free text), so COALESCE falls back to CURRENT_DATE; and sessions store class_label as the raw class_id ('class_8a') while corrections store a parsed label ('8-A'). Both never match a real historical session, so the UPDATE changes 0 rows while the correction is still flipped to 'approved'. Silent data-integrity failure on the core correction journey.
- **Evidence:** supabase/functions/_shared/attendance/attendance_correction_repository.ts:151-175 (INSERT omits session_date) and :222-245 (UPDATE on s.class_label=$4 AND s.session_date=COALESCE(ac.session_date,CURRENT_DATE)); class_label stored as class_id in pilot_operations_handlers.ts:127; confirmed deployed via ssh akshara cat of the same file. No deno test covers applyAttendanceCorrection.
- **Root Cause:** Correction create path and attendance-session write path use inconsistent class identifiers, and session_date is never persisted from the (free-text) date the user enters.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Data-integrity

#### ATTEN-2 · Parent attendance-correction submission is rejected by the server (403)
- **Module:** Attendance
- **User Journey:** Parent taps 'Request attendance correction', fills the dialog, submits — and it fails because the backend write requires school scope/manageSis a parent never has.
- **Severity:** 🟠 High
- **Description:** Parent correction submit posts to POST /attendance/corrections, gated by requireAttendanceWrite (manageSis OR school operational scope). Parents are scope='parent' without manageSis, so they get 403. The parent UI advertises the action (and the admin empty-state text says 'Teachers and parents submit corrections'), but there is no parent-scoped correction route.
- **Evidence:** lib/features/parent/parent_mutations_provider.dart:229-230 (createCorrection → POST /attendance/corrections); RBAC gate supabase/functions/_shared/attendance/attendance_handlers.ts:38-43,163-195; parent UI lib/features/parent/attendance/parent_attendance_workflow.dart:61-79; admin empty-state copy attendance_corrections_admin_screen.dart:76-78.
- **Root Cause:** No parent-scoped correction endpoint; client reuses the staff (manageSis) write path for a parent caller.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** RBAC

#### ATTEN-3 · Attendance marking (draft/submit) has no permission gate, only school scope
- **Module:** Attendance
- **User Journey:** A non-teaching school staffer (librarian, accountant, transport coordinator, HR) can mark/overwrite any class's attendance.
- **Severity:** 🟡 Medium
- **Description:** handleTeacherAttendanceSubmit/Draft authorize on scope==='school' && school_id only, with no requirePermission (e.g. manageSis/markAttendance). Any school-scoped account can submit attendance for any class_id, triggering guardian absence alerts. The dedicated correction write (POST /attendance/corrections) is correctly manageSis-gated, but the primary marking path is weaker.
- **Evidence:** supabase/functions/_shared/pilot/pilot_operations_handlers.ts:72-74 (draft) and :114-116 (submit) — scope check only, no requirePermission, contrast with attendance_handlers.ts requireAttendanceWrite (manageSis).
- **Root Cause:** Pilot operations handlers gate on scope rather than a role/permission; attendance marking lacks a dedicated permission check server-side.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** RBAC

#### ATTEN-4 · Admin corrections screen KPI card reads in-memory mock store (always empty in live)
- **Module:** Attendance
- **User Journey:** Admin opens Attendance corrections; the 'Teacher attendance submitted / present-absent-late' card always shows 'No teacher submission yet' regardless of real submissions.
- **Severity:** 🟡 Medium
- **Description:** The summary card sources from MockAttendanceSyncStore.instance (process-local mock mutated only by the teacher screen within the same app session), so for the admin user it is always empty/zero. The correction list below it is live and correct.
- **Evidence:** lib/features/management/attendance/attendance_corrections_admin_screen.dart:7,31,57-65 (MockAttendanceSyncStore.instance.hasTeacherSubmission/present/absent/late).
- **Root Cause:** Cross-screen sync uses an in-memory mock store instead of a live aggregate (e.g. GET /attendance/sessions counts).
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Live-deploy-drift

#### ATTEN-5 · Teacher attendance submit/draft failures are swallowed or shown as a misleading message
- **Module:** Attendance
- **User Journey:** If the submit network call fails, the teacher sees 'Mark all students before submitting' (wrong) or, for draft, nothing at all.
- **Severity:** 🟡 Medium
- **Description:** submitAttendance returns false when the mutation result is null (network/RBAC failure indistinguishable from 'unmarked'), and the screen shows the unmarked-students snackbar. saveAttendanceDraft silently no-ops on failure (only sets banner on success). The correction dialogs do surface errors correctly; only the mark/submit path swallows them.
- **Evidence:** lib/features/teacher/attendance/teacher_attendance_provider.dart:134-180; UI snackbar lib/features/teacher/attendance/teacher_attendance_screen.dart:245-254.
- **Root Cause:** Mutation result collapses success/failure to nullable, and the UI maps null to the 'unmarked' branch.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### ATTEN-6 · Correction dialog uses hardcoded placeholder date/reason and free-text date field
- **Module:** Attendance
- **User Journey:** Teacher opens the correction dialog and the date defaults to '12 Jun 2026' and reason to 'Biometric sync error…'; rushing, they submit the wrong date.
- **Severity:** ⚪ Low
- **Description:** showAttendanceCorrectionDialog prefills date '12 Jun 2026' and a canned reason; the attendance date is a free-text AksharaFormField, not a date picker, so unparseable/wrong dates can be submitted. This also feeds the session_date matching problem (issue #1).
- **Evidence:** lib/features/teacher/attendance/teacher_attendance_workflow.dart:30-33,62-66 (hardcoded text, free-text date field).
- **Root Cause:** Placeholder seed values left in the dialog; no date picker / parsing.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### ATTEN-7 · attendance_sessions persist class_label as the raw class_id; empty/zero sessions accepted
- **Module:** Attendance
- **User Journey:** Admin viewing the sessions list sees classLabel '' or 'class_8a' instead of a human label, and zero-record submitted sessions exist.
- **Severity:** ⚪ Low
- **Description:** Submit/draft set classLabel = class_id (snakeStr(body,'class_id')), so GET /attendance/sessions returns classLabel like '' or 'class_8a'. A session with recordCount 0 and empty classLabel is present on live, indicating empty submissions are accepted with no validation.
- **Evidence:** pilot_operations_handlers.ts:85-86,127-128; live GET /attendance/sessions returned {classLabel:'',recordCount:0} and takenBy-only rows.
- **Root Cause:** No mapping from class_id to a display label and no min-entry validation on submit.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Data-integrity

#### ATTEN-8 · Student 'AI attendance insight' is a static template, not AI
- **Module:** Attendance
- **User Journey:** Student sees an 'AI' attendance tip that is the same hardcoded sentence regardless of pattern.
- **Severity:** ⚪ Low
- **Description:** studentAttendanceInsightProvider builds a fixed string with the attendance % interpolated; labeled 'AI attendance insight' but is deterministic copy, not a model call. Acceptable as a deterministic insight but mislabeled.
- **Evidence:** lib/features/student_app/attendance/student_attendance_provider.dart (studentAttendanceInsightProvider — fixed message template).
- **Root Cause:** Placeholder insight not wired to the real AI/intelligence layer.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** AI

**Strengths (working well):**
- Core marking journey is fully live-wired: client paths (/teacher/attendance/draft|submit) match the deployed pilot router; sessions persist to Postgres and absentee guardian alerts are enqueued (verified on live GET /attendance/sessions).
- Privacy RLS for attendance_records is correctly scoped (parent→own children via student_guardians, student→own) and proven by a live 403 for cross-scope reads — closes the Batch 3 leak.
- Correction approval is server-owned with real separation of duties: approval gated on approveAttendanceCorrection, client correctly skips mock adapter side-effects when the approval API is enabled (skipDomainEffects).
- Teacher marking screen has complete loading/error/empty/search-empty states, submit gating on unmarked count, bulk all-present/absent, and a permission-gated correction action; correction dialogs surface backend errors to the user.
- All attendance routes confirmed deployed on the VPS (ssh) and match the repo; teacher/student/parent repositories all go through real API datasources (no ApiNotConnectedException/UnimplementedError stubs in live paths).

---

### Exams
**Code:** `EXAMS`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Traced every screen/dialog/action in lib/features/{academics/exam_admin, teacher/exams, parent/exams, student_app/exams, intelligence/exam, education}. Verified client->provider->repository->ExamApiPaths/education paths against the DEPLOYED routers (ssh akshara index.ts + exam_administration_router.ts + education_router.ts + intelligence_router.ts) and the handler RBAC/DB writes. Ran live GET probes (token valid early in session, expired late): confirmed real data for /academics/exams, /academics/exams/exam_3 (+ /marks, /remarks), /education/question-papers, /education/question-bank, /education/report-remarks, /education/homework. Cross-checked gate logs (deno exam_administration_authz + education_* suites; flutter exam_approval_adapter + exam_marks_entry + repository_contract). Cited akshara-batch3 and question-intelligence certs for already-proven journeys. NOT fully verified live: /intelligence/exam/* responses (token expired; wiring + deploy + RBAC confirmed by code). No writes performed.

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Parent/Student in-app report card from published results + PDF export | 🔴 broken | parentReportCardProvider (report_card_provider.dart:11-26) and studentReportCardProvider build the card ONLY from local ExamAdministrationStore.instance.resultsForStudent() + MockAttendanceSyncStore, never from the live API. The API parent/student repos do not feed published results into the store (only mock_parent_repository.dart:57 seeds it). studentReportCardProvider even hardcodes MockCanonicalStudentRegistry.primaryMobileStudentId. In a live build the store is empty -> report_card_screen.dart shows 'No published results yet' even though the live results list is populated. Server even exposes /academics/exams/students/{id}/published which the report card does not use. |
| Exam intelligence (analytics, subject performance, weak chapters, forecast, rank movement) | 🟡 partial | exam_intelligence_provider.dart -> HybridIntelligenceRepository (api-only, no mock fallback) -> /intelligence/exam/analytics etc.; routes deployed (intelligence_router.ts:116-122) with RBAC viewExamIntelligence\|\|viewEducation\|\|viewAnalytics (exam_intelligence_handlers.ts:25-27); INTELLIGENCE_API_ENABLED true in config/live_release.json. Could not complete live GET probe (schoolAdmin token expired mid-session; same token earlier succeeded on exams/education). Wiring verified by code/router; live response unverified. |
| Exam lifecycle admin: create -> schedule -> open-marks -> enter marks -> process -> coordinator verify -> submit for principal approval -> publish | ✅ verified | UI exam_administration_screen.dart + exam_lifecycle_actions.dart + exam_marks_entry_screen.dart wire each step through examAdminMutationProvider/examMarksMutationProvider -> ApiExamAdministrationRepository -> ExamApiPaths (/academics/exams/...) which match the deployed router exam_administration_router.ts 1:1; handlers enforce granular perms (manageExams/manageExamMarks/submitExamResults/verifyExamResults/publishExamResults) and real DB writes via withTenantContext (exam_administration_handlers.ts:172-514). Live GET probe returned real sessions across phases (exam_4 published, exam_3 processed+coordinatorVerified). flutter exam_approval_adapter_integration_test + deno exam_administration_authz_test (6 tests) green in gate logs. |
| Marks entry with per-mark save, validation, subject-teacher scope | ✅ verified | exam_marks_entry_screen.dart:349-375 validates 0..maxMarks, save gated by Permission.manageExamMarks; backend handleUpdateExamMark + handleListExamMarks enforce isSubjectTeacherScoped/teacherTeachesExamSession (handlers.ts:264-341). Live probe GET /academics/exams/exam_3/marks returned real roster (STU-001=75, STU-2026-00003=88). |
| Publish gate: approval-required mode blocks direct publish, requires coordinator verify + principal approval | ✅ verified | publishDirect throws EXAM_APPROVAL_REQUIRED when examApprovalRequiredProvider on (exam_marks_entry_provider.dart:161-171); backend handlePublishExamResults requires findApprovedByEntity('examResults') unless require_approval=false (handlers.ts:382-416). Approval chain proven by flutter exam_approval_adapter_integration_test (submit->approve->publish, reject keeps unpublished). |
| Published results reach parent (results list) and student (results list) live | ✅ verified | parentExamsProvider/studentExamsProvider -> ApiParentRepository.getExams / ApiStudentRepository.getExams -> /parent/exams, /student/exams (live routes parent_router.ts:49, student_router.ts:23, mapped via parent_mapper.toExams). Publish also fires guardian SMS (handlers.ts notifyParentsOfResults). Matches akshara-batch3 cert (parent results visibility). |
| Question-paper generation: bank-first + AI gap-fill, governance (submit->review->approve->publish), AI moderation, edit/regenerate/promote, publish gate | ✅ verified | education_question_paper_detail_screen.dart implements full lifecycle (submit l.497, moderate approve/reject l.199-251, regenerate w/ AI-credit warning l.374, promote-to-bank l.402, edit resets to draft l.353-366, 'unfilled marks' + 'moderate AI candidates' banners l.97-105) via educationMutationsProvider -> deployed education_router.ts routes. Live probes returned real /education/question-papers (status draft, blueprint w/ placedMarks) and /education/question-bank. Matches question-intelligence live-certified + question-paper-correction certs; deno education_router_test (9) + education_ai_question_gapfill_test (7) + blueprint_solver/export_moderation green. |
| Class-teacher + leadership (principal/VP) remarks persisted and shown on report card cross-device | ✅ verified | saveLeadershipExamRemark -> repo.upsertRemark -> PUT /academics/exams/{exam}/remarks/{student}; examRemarksHydrationProvider hydrates from GET remarks on screen open; backend handleUpsertExamRemark enforces classTeacher vs leadership authorship (handlers.ts:440-500). Live probe GET /academics/exams/exam_3/remarks returned [] (empty, route works). flutter exam_marks_entry_screen_test 'principal can author leadership remark' green. |

**Live probes:**
- `GET /academics/exams (schoolAdmin token)` → 200 real data: exam_4 phase=published, exam_3 phase=processed coordinatorVerified=true, etc.
- `GET /academics/exams/exam_3/marks` → 200 real roster: STU-001 marksObtained=75, STU-2026-00003=88
- `GET /academics/exams/exam_3/remarks` → 200 data:[] (route works, no remarks yet)
- `GET /academics/exams/exam_3` → 200 single session, phase=processed, coordinatorVerified=true
- `GET /education/question-papers` → 200 real paper: status=draft, blueprint placedMarks=10, programTrack=board
- `GET /education/question-bank` → 200 real bank item (Mathematics/Algebra mcq, status=active)
- `GET /education/report-remarks and /education/homework` → 200 empty paged lists (routes live)
- `GET /intelligence/exam/analytics` → UNAUTHORIZED — schoolAdmin token had expired by this point (same token succeeded earlier on exams/education); route deployed per index.ts, not response-verified
- `ssh akshara cat /opt/akshara/functions/api/index.ts` → confirms routeExamAdministration (l.89), routeEducation (l.140), routeIntelligence (l.141) imported+registered; deployed _shared/academics/exam_administration and _shared/education dirs present

**Issues:**

#### EXAMS-1 · Parent/Student report card is built from local mock store, not live published results (broken in live build)
- **Module:** Exams
- **User Journey:** Parent/Student opens 'View report card' after results are published
- **Severity:** 🟠 High
- **Description:** parentReportCardProvider (lib/features/parent/exams/report_card_provider.dart:11-26) and studentReportCardProvider (lib/features/student_app/exams/report_card_provider.dart:11-24) construct the report card exclusively from ExamAdministrationStore.instance.resultsForStudent() plus MockAttendanceSyncStore.instance.attendancePercent(). The live API repositories (ApiParentRepository/ApiStudentRepository) never populate that store; only mock_parent_repository.dart:57 seeds it. So on a real device in live mode the store is empty and report_card_screen.dart:45-49 renders 'No published results yet for a report card' (and the PDF export button is hidden) even though the live /parent/exams results list shows the same student's grades. studentReportCardProvider additionally hardcodes MockCanonicalStudentRegistry.primaryMobileStudentId as the student id. The server already exposes /academics/exams/students/{id}/published (listPublishedResultsForStudent) that the report card ignores.
- **Evidence:** report_card_provider.dart:11-26 (parent), report_card_provider.dart:11-24 (student, hardcoded MockCanonicalStudentRegistry.primaryMobileStudentId line 13); ExamAdministrationStore.resultsForStudent reads local _publishedByMarkId (exam_administration_store.dart:547-552); only mock_parent_repository.dart:57 feeds the store; live results list is separately live via /parent/exams (parent_router.ts:49).
- **Root Cause:** Report card was implemented as a local-store ('Slice 6') feature and never re-wired to the live published-results endpoint when the rest of exams went live; API repos don't hydrate ExamAdministrationStore.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap / Cross-module

#### EXAMS-2 · Parent/Student exam screens silently fall back to fabricated mock data on a live fetch error (no error state)
- **Module:** Exams
- **User Journey:** Parent/Student opens Exams when the live API call fails
- **Severity:** 🟠 High
- **Description:** parentExamsProvider resolves to ParentExamsData.mock() and studentExamsProvider to a hardcoded 'Ravi Kumar 8-A' default whenever the FutureProvider has no value (loading OR error). The screens read separate manual StateProviders (parentExamsErrorProvider/studentExamsErrorProvider) for their error/loading branches, but nothing ever sets those from the FutureProvider's async state (the only writers RESET them: parent_exams_screen.dart:81, student_exams_screen.dart:47). Result: a failed live /parent/exams call shows a parent fabricated grades (Maths A, English A+, etc. from ParentExamsData.mock(), exam_models.dart:113-188) presented as their child's real results, with no error/retry shown. Same for the student app.
- **Evidence:** parent_exams_provider.dart:30-32 (resolved = data ?? future.value ?? ParentExamsData.mock()); watchRepositoryFuture returns null on loading/error (repository_future.dart); grep shows parentExamsErrorProvider only reset to null, never set; mock factory exam_models.dart:113-188 returns concrete fake grades; student_exams_provider.dart:28-38 hardcoded 'Ravi Kumar'.
- **Root Cause:** Manual loading/error StateProviders are not bridged to the FutureProvider's AsyncValue; provider chooses a mock fallback instead of propagating the error to the UI.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX / Data-integrity

#### EXAMS-3 · Exam report settings (grading scale + rank-visible-to-parents) are device-local and have no end-to-end effect
- **Module:** Exams
- **User Journey:** Admin opens Exam Settings, picks CBSE/Percentage grading scale or toggles 'show rank to parents'
- **Severity:** 🟡 Medium
- **Description:** examReportSettingsProvider is backed solely by the ExamAdministrationStore singleton (exam_settings_provider.dart:14-37, store configureReportSettings -> local _reportSettings + optional local persistence). It is never written to the backend. Meanwhile the server computes published grade letters with a hardcoded ladder gradeForPercent() (exam_administration_repository.ts:98-110) and ignores any school grading-scale choice, and there is no server-side enforcement of showRankToParents (no rank/showRankToParents reference in parent/student/academics backend). So choosing CBSE vs Standard scale does not change the grades parents/students actually receive, and the rank toggle is a per-device admin preference other devices/roles never see. The provider comment claims it is 'applied at publish time' which is inaccurate.
- **Evidence:** exam_settings_provider.dart:9-37; exam_administration_store.dart:165-176 (local _reportSettings); backend hardcoded gradeForPercent exam_administration_repository.ts:98-110 and publishExamResults uses it (l.529); grep for showRankToParents/rank in supabase _shared parent/student/academics returned nothing.
- **Root Cause:** Settings UI exists but neither persisted to server nor consulted by the server's publish/grade computation; rank visibility never enforced server-side.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### EXAMS-4 · createExam returns the wrong exam (uses exams.last on an updated_at DESC list) and does a redundant list fetch
- **Module:** Exams
- **User Journey:** Admin creates a new exam
- **Severity:** ⚪ Low
- **Description:** ExamAdminMutationNotifier.createExam (exam_administration_provider.dart:77-80) performs an extra full listExams call after creating and returns exams.last. listExamSessions orders by updated_at DESC (exam_administration_repository.ts:174), so the newly created exam is exams.first, not exams.last; the returned session is therefore the oldest, not the created one. Currently latent because the sole caller (exam_create_dialog.dart:199) discards the return value, so users see no symptom, but the wasteful list round-trip runs and the return contract is wrong (any future caller navigating to the created exam would open the wrong one).
- **Evidence:** exam_administration_provider.dart:77-80 (exams.last); ORDER BY updated_at DESC at exam_administration_repository.ts:174; caller discards result at exam_create_dialog.dart:199-217.
- **Root Cause:** Assumes append-order list ordering; backend returns most-recent-first.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### EXAMS-5 · Exam create form uses free-text date/time with hardcoded defaults instead of pickers
- **Module:** Exams
- **User Journey:** Admin fills the Create Exam dialog
- **Severity:** ⚪ Low
- **Description:** exam_create_dialog.dart defaults exam date to free text '15 Mar 2026', time '9:00 AM - 10:30 AM', venue 'Room 8A' (lines 21-23). Date is marked required but is a plain text field with no validation of format and no date/time picker, so dates are stored as arbitrary strings (the dateLabel/timeLabel are pure labels in the backend). This degrades data quality (no sortable/structured exam date) and is a minor UX inconsistency vs other modules that use pickers.
- **Evidence:** exam_create_dialog.dart:21-23 hardcoded defaults; date field is AksharaFormField text (l.143-147); backend stores date_label as a plain string (handlers.ts:223).
- **Root Cause:** Exam dates modeled as display labels rather than structured timestamps; form never upgraded to pickers.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### EXAMS-6 · Report card PDF uses a hardcoded placeholder school name
- **Module:** Exams
- **User Journey:** Parent/Student exports the report card PDF
- **Severity:** ⚪ Low
- **Description:** report_card_screen.dart:13 sets _reportCardSchoolName = 'Akshara Vidyalaya' as an acknowledged placeholder ('until school profile wired'), and passes it into the exported PDF. Every school's report-card PDF therefore prints the same fake school name regardless of tenant.
- **Evidence:** report_card_screen.dart:13 const _reportCardSchoolName = 'Akshara Vidyalaya'; used in shareReportCardPdf l.40.
- **Root Cause:** School profile/branding not wired into the report card export.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Cross-module

**Strengths (working well):**
- Core exam admin lifecycle is fully live and DB-backed: every client path in ExamApiPaths matches the deployed router exam_administration_router.ts 1:1, confirmed via ssh akshara cat index.ts and live GET probes returning real sessions/marks.
- Strong granular RBAC, enforced on BOTH sides: client mutation providers pre-check manageExams/manageExamMarks/submitExamResults/verifyExamResults/publishExamResults, and the server independently requires the same per-operation permission plus school operational scope (handlers.ts EXAM_OPERATION_PERMISSIONS + withAuth).
- Subject-teacher scoping enforced server-side (teacherTeachesExamSession / isClassTeacherForExam) so a plain teacher can only read/edit/remark exams they actually teach.
- Excellent loading/error/empty state coverage on the admin and marks-entry screens (AksharaLoadingState/AksharaErrorState/AksharaEmptyState with retry), and mark validation (0..maxMarks, disabled when published).
- Two-stage publish governance (coordinator verify -> principal approval -> publish, with direct publish blocked when approval required) is real and covered by green integration tests; publish also triggers best-effort guardian SMS.
- Question-paper subsystem (bank-first generation, AI gap-fill, moderation queue, edit/regenerate/promote, submit->review->approve->publish gate with unfilled-marks banner) is fully wired to deployed /education routes and matches the question-intelligence certs.
- No silent mock writes in the admin/teacher write paths: HybridIntelligenceRepository is api-only, exam admin repo is pure API when EXAM_API_ENABLED (true in live_release.json); no ApiNotConnectedException/UnimplementedError in exam admin live code path.

---

### Homework
**Code:** `HOMEW`  ·  **Verdict:** `gaps-block-cert`

_Coverage:_ Traced all four homework surfaces (teacher create+review, student list+submit, parent list, intelligence plan+generate) end-to-end: Flutter screen → provider → repository → API path → deployed router (index.ts ordering verified) → _shared handler → RBAC → DB write/read. Confirmed live deployment via ssh akshara and ran GET-only probes (teacher 200 with empty submissions; student/parent 403 scope; intelligence path 404 on wrong path, real path routed). Verified mock-vs-live: live build uses Api*Repository (TEACHER/STUDENT/PARENT/INTELLIGENCE_API_ENABLED all true in config/live_release.json). Did NOT exercise live writes (read-only audit), so the broken read-back journeys (teacher-sees-submission, grade-to-parent/student) are proven by code path + GET probe rather than a write+read cycle. Gate logs show only mock contract/render tests for homework — no live integration test covers the create→submit→grade→visibility loop, consistent with the gaps found. No prior homework-specific certification doc exists.

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Teacher sees student submissions to grade | 🔴 broken | Live GET /teacher/homework returns assignments with NO submissions array — probe result: {"id":"hw_1",...,"pendingReviews":3} (no 'submissions'). handleHomework = handleList(...,'homework_assignment') (teacher_handlers.ts:24-26) is a plain entity read with no join to homework_submissions. Mapper expects raw['submissions'] (teacher_mapper.dart:88) → always empty. Teacher review screen therefore shows every assignment with zero submissions; the review action needs a real submission UUID it never receives. |
| Teacher grades submission → grade flows to student/parent | 🔴 broken | POST /teacher/homework/submissions/{id}/review → handleTeacherHomeworkReview (pilot_operations_handlers.ts:280) → reviewHomework (pilot_operations_repository.ts:228) updates ONLY homework_submissions. It never updates the student_entities 'homework_item' payload nor parent snapshot_homework, so the graded status/grade is invisible to student and parent. No overlay joins homework_submissions in mobile_read_handlers.ts handleList (only fees/exams snapshots are overlaid, lines 130-153). |
| Parent sees child's homework | 🔴 broken | Parent reads snapshot_homework (parent_handlers.ts:22-23 handleSnapshot('snapshot_homework')) — a seeded snapshot with NO overlay (handleSnapshot only overlays snapshot_fees/snapshot_exams, mobile_read_handlers.ts:130-153). Teacher create writes 'homework_item' (student_entities) only, never snapshot_homework, so teacher-assigned homework never appears in the parent app. Parent provider also falls back to ParentHomeworkData.mock() (parent_homework_provider.dart:31) showing fake 'Ravi Kumar / Exercise 5.2' homework when the future is null. |
| Teacher creates/assigns homework → delivered to student | 🟡 partial | Client POST /teacher/homework → routePilotOperations (index.ts:110 runs before routeTeacher:145) → handleTeacherHomeworkCreate (pilot_operations_handlers.ts:312) → insertHomeworkAssignment (pilot_operations_repository.ts:916) writes teacher_entities 'homework_assignment' + fans out 'homework_item' to student_entities. DTO keys match backend (teacher_write_request_dto.dart:151-156). Student read path picks it up via /student/homework handleList('homework_item'). Works, BUT delivered to WHOLE school roster, not the target class (repo comment lines 913-915: students table has no class column), and NO notification is enqueued. |
| Student submits homework | 🟡 partial | submitStudentHomework (student_homework_provider.dart:65) → POST /student/homework/submit → handleStudentHomeworkSubmit (pilot_operations_handlers.ts:248, student scope enforced) → submitHomework (pilot_operations_repository.ts:189) upserts homework_submissions. Wire OK. BUT submission status is never written back to the student_entities 'homework_item' payload, so after re-fetch the item still shows status:'pending'; and the UI ignores the bool result (student_homework_screen.dart:131) so no success/error feedback is shown. |
| AI Homework Intelligence: generate & apply remedial homework | 🟡 partial | INTELLIGENCE_API_ENABLED=true (live_release.json:40); /intelligence/homework-intelligence/plan (GET) + /generate (POST) routed (intelligence_router.ts:89,92) with real permission RBAC viewHomeworkIntelligence/manageHomeworkIntelligence (homework_intelligence_handlers.ts:19-28). BUT applyHomeworkRecommendations writes to edu_homework_assignments + edu_homework_student_targets (homework_intelligence_service.ts:209-271) — a DISJOINT data model from mobile homework (homework_item/student_entities), so AI-applied homework never appears in the student/parent mobile homework list. Content is generateStubHomeworkContent (templated, not real AI — education_generator.ts:126-138). |

**Live probes:**
- `GET /teacher/homework (schoolAdmin token)` → 200 — one assignment {id:hw_1,title:Algebra worksheet,classLabel:8-A,pendingReviews:3} with NO submissions array, confirming teacher can never see submissions to grade.
- `GET /student/homework` → 403 FORBIDDEN 'Student data requires student scope' — RBAC scope isolation working.
- `GET /parent/homework` → 403 FORBIDDEN 'Parent data requires parent scope' — RBAC scope isolation working.
- `GET /intelligence/homework` → 404 NOT_FOUND (expected — real path is /intelligence/homework-intelligence/plan); confirms router only exposes the documented paths.
- `ssh akshara cat teacher_router.ts / teacher_handlers.ts` → Deployed source matches repo: GET-only teacher router; /teacher/homework = handleList('homework_assignment'). Confirms write routes are served by the separately-mounted pilot router, not the teacher router.

**Issues:**

#### HOMEW-1 · Teacher cannot see or grade any student homework submission (live)
- **Module:** Homework
- **User Journey:** Teacher grades submission
- **Severity:** 🔴 Critical
- **Description:** GET /teacher/homework (handleList on 'homework_assignment') never joins homework_submissions, so the teacher review screen always shows assignments with an empty submissions list even though students have submitted. The review bottom-sheet (teacher_homework_screen.dart:181) is only reachable for a pending submission that never appears, and reviewSubmission needs a real homework_submissions UUID it never receives. The entire grade journey is non-functional through the mobile teacher app in live mode.
- **Evidence:** Live probe GET /teacher/homework returned items with 'pendingReviews':3 but no 'submissions' field. Backend: teacher_handlers.ts:24-26 handleList(...,'homework_assignment'); mapper expects raw['submissions'] (teacher_mapper.dart:88) → defaults to const []. No submissions overlay in mobile_read_handlers.ts (handleList lines 595-641 plain entity read).
- **Root Cause:** Teacher homework read is a generic entity-list read with no join/overlay from the homework_submissions table where student work actually lands.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### HOMEW-2 · Graded homework grade/status never reaches student or parent
- **Module:** Homework
- **User Journey:** Teacher grades submission → grade flows to student/parent
- **Severity:** 🟠 High
- **Description:** reviewHomework updates only homework_submissions; it does not propagate grade/reviewed status into the student_entities 'homework_item' payload nor the parent snapshot_homework. Student/parent homework reads have no overlay from homework_submissions, so a graded item still shows as pending with no grade.
- **Evidence:** pilot_operations_repository.ts:228-258 (reviewHomework) touches only homework_submissions. mobile_read_handlers.ts handleSnapshot overlays only fees/exams (lines 130-153); handleList for homework_item has no overlay (lines 276-324).
- **Root Cause:** No write-back of submission state into the read-model entities and no read-side overlay joining homework_submissions.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Data-integrity

#### HOMEW-3 · Teacher-assigned homework never appears in the parent app
- **Module:** Homework
- **User Journey:** Parent sees child's homework
- **Severity:** 🟠 High
- **Description:** Teacher create writes 'homework_item' to student_entities only. Parent reads snapshot_homework, which create never writes and which has no overlay. A real parent therefore never sees homework the teacher assigned; worse, on a null future the parent screen renders ParentHomeworkData.mock() (fake 'Ravi Kumar' demo homework).
- **Evidence:** insertHomeworkAssignment writes student_entities 'homework_item' (pilot_operations_repository.ts:965-984), no snapshot_homework write. parent_handlers.ts:22-23 reads snapshot_homework with no overlay. Fallback to .mock() at parent_homework_provider.dart:31; mock data at homework_models.dart:93+.
- **Root Cause:** Parent and student homework use different read entities (snapshot_homework vs homework_item) and create only writes the student one; parent provider also falls back to demo mock data.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Cross-module

#### HOMEW-4 · Student submission status not reflected back; no submit feedback
- **Module:** Homework
- **User Journey:** Student submits homework
- **Severity:** 🟠 High
- **Description:** After a student submits, the homework_item payload is not updated, so the re-fetched list still shows 'pending' and the item stays in the Pending filter. The submit handler in the UI ignores the returned bool, so neither success nor failure is surfaced to the student.
- **Evidence:** submitHomework writes only homework_submissions (pilot_operations_repository.ts:189-226); no student_entities update. student_homework_screen.dart:131 awaits submitStudentHomework but shows no SnackBar; submitStudentHomework returns bool that is discarded (student_homework_provider.dart:65-74).
- **Root Cause:** Submission write does not update the read-model entity and the UI has no result handling.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### HOMEW-5 · Homework delivered to whole school instead of the target class
- **Module:** Homework
- **User Journey:** Teacher creates/assigns homework
- **Severity:** 🟠 High
- **Description:** When no student name is given, insertHomeworkAssignment delivers the homework_item to EVERY active student in the school, ignoring the class_label, because the students table has no class column. In a multi-class school, an 8-A assignment lands in every student's homework list.
- **Evidence:** pilot_operations_repository.ts:959-963 selects all active students for the school (no class filter); developer comment lines 913-915 acknowledges 'class-precise targeting ... is a tracked refinement'.
- **Root Cause:** No class/section join available on the students table at create-fanout time.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Data-integrity

#### HOMEW-6 · Create screen claims parent+student delivery but no notification is sent
- **Module:** Homework
- **User Journey:** Teacher creates/assigns homework → delivered to student
- **Severity:** 🟡 Medium
- **Description:** The create screen tells the teacher 'Assignment is delivered to parent and student in their preferred language' but handleTeacherHomeworkCreate enqueues no notification (unlike attendance submit which calls enqueueNotificationRequested), and nothing reaches the parent at all. The promise is misleading.
- **Evidence:** teacher_homework_create_screen.dart:75 copy. handleTeacherHomeworkCreate (pilot_operations_handlers.ts:312-379) has no enqueueNotificationRequested call (contrast attendance submit lines 137-155). No parent snapshot write.
- **Root Cause:** Notification fan-out and parent delivery were never implemented for homework create.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Cross-module

#### HOMEW-7 · AI homework intelligence applies to a disjoint data model, invisible to mobile apps
- **Module:** Homework
- **User Journey:** AI Homework Intelligence: generate & apply remedial homework
- **Severity:** 🟡 Medium
- **Description:** Generate & apply writes edu_homework_assignments + edu_homework_student_targets, which are never read by the student/parent/teacher mobile homework screens (those read homework_item/homework_assignment/snapshot_homework). So 'Applied N homework assignments' produces homework no one sees in the app. Content is a deterministic stub, not real AI.
- **Evidence:** homework_intelligence_service.ts:209-271 (applyHomeworkRecommendations → createHomeworkAssignment in edu tables + edu_homework_student_targets); content via generateStubHomeworkContent (education_generator.ts:126-138). Mobile reads use student_entities/teacher_entities/snapshot entities.
- **Root Cause:** Two separate homework subsystems (education edu_* vs mobile pilot entities) were never unified.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Cross-module

#### HOMEW-8 · Homework Intelligence screen is developer-grade and lacks error handling on apply
- **Module:** Homework
- **User Journey:** AI Homework Intelligence: generate & apply remedial homework
- **Severity:** 🟡 Medium
- **Description:** The screen uses a plain AppBar, raw dropdown values ('unit_test'/'monthly_test'), hardcoded defaults ('Grade 8'/'Mathematics'), no empty state, and no confirmation before applying real homework. The Generate&apply onPressed has no try/catch around the awaited generate() call, so an exception leaves the success SnackBar unreached and propagates unhandled.
- **Evidence:** homework_intelligence_screen.dart:20-21 defaults; lines 47-55 raw dropdown; lines 60-75 no try/catch, unconditional success SnackBar; plain AppBar line 41. Violates demo-grade visual bar memory.
- **Root Cause:** Screen built as an internal tool, not polished to the product design system, and error path not handled.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### HOMEW-9 · Teacher review sheet pre-fills grade 'A' and has weak validation
- **Module:** Homework
- **User Journey:** Teacher grades submission
- **Severity:** ⚪ Low
- **Description:** The review bottom sheet pre-populates the Grade field with 'A' and has no validation, so a teacher tapping Save without changing it silently records grade 'A'. (Secondary to the fact the sheet is unreachable live, but a latent correctness risk once submissions are wired.)
- **Evidence:** teacher_homework_screen.dart:187 gradeController = TextEditingController(text: 'A'); Save button (line 226) calls reviewSubmission with no validation.
- **Root Cause:** Demo default left in the production review form.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### HOMEW-10 · Student/parent homework headers hardcoded to demo identity
- **Module:** Homework
- **User Journey:** Student submits homework
- **Severity:** ⚪ Low
- **Description:** Student homework provider hardcodes studentName:'Ravi Kumar', classLabel:'8-A' for the app-bar subtitle, and parent mock fallback uses the same demo child. Real users see demo identity in the header.
- **Evidence:** student_homework_provider.dart:58-59; parent_homework_provider.dart:31 → homework_models.dart:95-96 (childName:'Ravi Kumar', childClass:'8-A').
- **Root Cause:** Demo defaults not replaced with resolved identity from auth/snapshot.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

**Strengths (working well):**
- Create homework write is genuinely live: POST /teacher/homework is correctly routed by routePilotOperations BEFORE routeTeacher (index.ts:110 vs 145), persists to teacher_entities and fans out homework_item to student_entities, and is audited (auditMobileWrite, pilot_operations_handlers.ts:352-360). DTO snake_case keys match backend validation exactly.
- RBAC is enforced server-side on every homework write/read: teacher/student/parent scope checks (pilot_operations_handlers.ts:318,254,287), parent-leave child-link check, and the intelligence routes use real Permission gates (viewHomeworkIntelligence/manageHomeworkIntelligence). Live probes confirmed /student/homework and /parent/homework return 403 for a schoolAdmin token (correct scope isolation).
- Tenant isolation is applied via withTenantContext/runTenant on all homework DB access, and reviewHomework/submitHomework run under RLS.
- Loading and error states are present and consistent on the teacher, student, and parent homework screens (AksharaLoadingState/AksharaErrorState/AksharaEmptyState), and the screens are responsive (tablet breakpoint + max-content-width constraints).
- Backend homework routes and intelligence routes are confirmed deployed on the VPS (ssh akshara: teacher_router.ts + teacher_handlers.ts present; intelligence routes matched in tests).

---

### Communication
**Code:** `COMMU`  ·  **Verdict:** `gaps-block-cert`

_Coverage:_ Covered every file in lib/features/communication (broadcast_admin_screen, communication_providers, communication_mutations_provider), the full client repo chain (interface/api/hybrid/mock/remote datasource/api_paths), backend _shared/communication (router + handlers + service), and the related school_completion delivery/analytics screens + WhatsApp helper. Traced each UI action to its router route and RBAC perm, checked mock-vs-live (useApi:true confirmed), and ran live GETs (templates OK, delivery/metrics OK, broadcasts/history 404, teacher messages OK, parent notifications 403-scope) plus confirmed the deployed VPS router matches local. Did NOT write to live (GET-only) and did not run full suites (grepped gate logs instead). Cross-module handoffs noted: delivery/analytics dashboards are backed by the school_completion repository (out of scope), and parent/teacher messaging UIs live under lib/features/parent|teacher.

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Create / save a communication template (Templates tab) | 🔴 broken | Save button → saveTemplateProvider.execute → createTemplate → POST /communications/templates (remote/communication_remote_datasource.dart:39). NO matching route in communication_router.ts (only GET templates at line 25) and NO handler (grep of communication_handlers.ts shows no handleCreateTemplate). In live build useApi:true (repository_providers.dart:414) so this hits the live API → 404 NOT_FOUND. Deployed router on VPS confirmed identical (ssh akshara cat communication_router.ts: only GET templates, POST broadcasts, delivery metrics/webhook). |
| Edit / update a template | 🔴 broken | updateTemplate → PUT /communications/templates/{id} (remote datasource:52). No PUT route in router, no handleUpdateTemplate handler. Live build would 404. (Note: the BroadcastAdminScreen UI never passes a templateId, so the update path is also unreachable from the UI even if the route existed — create is the only UI path and it is broken.) |
| View broadcast history (History tab) & delivery roll-up (Delivery tab) | 🔴 broken | Both tabs read communicationBroadcastHistoryFutureProvider → listBroadcastHistory → GET /communications/broadcasts/history. Live probe returned {"error":{"code":"NOT_FOUND","message":"Route not found: GET /communications/broadcasts/history"}}. Router has only POST /communications/broadcasts; the path startsWith('/communications/') so it enters communication_router but matchCommunicationRoute returns null → 404. After a successful broadcast send, _sendBroadcast invalidates this provider (communication_mutations_provider.dart:49), so the History+Delivery tabs flip to an error state right after a 'success' snackbar. |
| Compose & send broadcast (admin → parents/teachers/students) | ✅ verified | broadcast_admin_screen.dart:100 _sendBroadcast → sendBroadcastProvider → ApiCommunicationRepository.sendBroadcast → POST /communications/broadcasts. Router index.ts communication_router.ts:28 maps it; handleCreateBroadcast (handlers.ts:135) requires permission 'sendBroadcast', enqueues batched recipients + deliveries and drains async via EdgeRuntime.waitUntil. Wave4 cert (WAVE4_COMPLETION_CERTIFICATION.md:44) confirms 201/0.36s/status:'queued' live; deno broadcast_batch_test.ts passing. |
| View existing templates (Templates tab) | ✅ verified | GET /communications/templates → handleListTemplates (handlers.ts:113, perm viewCommunications). Live probe returned a real template item (fee_reminder_push) from prod DB. |
| Communication Delivery & Analytics dashboards (school_completion hub) | ✅ verified | communication_delivery_screen.dart + communication_analytics_screen.dart delegate to schoolCompletionRepository.getDeliveryAnalytics/getCommunicationAnalytics (school_completion_providers.dart:117/124), NOT the communication repo. Separate working pipeline; GET /communications/delivery/metrics live-probed OK {sent:1,pending:20,failed:0,total:21}. (Backend owned by school_completion module — handoff noted.) |
| Comm hub: parent/teacher direct messaging threads | ✅ verified | Routes /parent/messages/threads, /parent/messages/send, /teacher/messages(/threads\|/send) wired in communication_router.ts:55-81. Live probe GET /teacher/messages/threads returned real thread items; GET /parent/notifications correctly 403 'Parent scope required' for schoolAdmin token (RBAC working). UI in lib/features/parent/messages & lib/features/teacher/messages. |
| WhatsApp deep-link contact (free wa.me, no Meta API) | ✅ verified | whatsapp_launcher.dart normalizes 10-digit→+91, drops trunk 0, keeps 11-15 digit intl, builds wa.me/<intl>?text=<encoded>. whatsapp_contact_button.dart hides itself when no dialable number (no dead control), SnackBars on missing number / launch failure. Used across transport/admissions/alumni/hr/inventory/parent surfaces. |
| Push device-token register/unregister + mark-read | ✅ verified | Routes /parent\|/student/device-tokens/register\|unregister and notifications mark-read/all wired (communication_router.ts:43-74), handlers require perms. FCM HTTP v1 cert (FCM_PUSH_HTTP_V1_CERTIFICATION.md) certifies the real push path live 13/13. |

**Live probes:**
- `GET /communications/templates` → 200 — returns real template item (fee_reminder_push) from prod DB; Templates-list journey works live
- `GET /communications/broadcasts/history` → 404 NOT_FOUND 'Route not found: GET /communications/broadcasts/history' — History & Delivery tabs broken live
- `GET /communications/delivery/metrics` → 200 {sent:1,pending:20,failed:0,total:21} — working metrics endpoint the client never calls
- `GET /teacher/messages/threads` → 200 — real thread items; comm-hub messaging deployed and working
- `GET /parent/notifications` → 403 FORBIDDEN 'Parent scope required' — correct RBAC denial for schoolAdmin token (not a bug)
- `ssh akshara cat /opt/akshara/functions/_shared/communication/communication_router.ts` → Deployed router has only GET templates, POST broadcasts, GET delivery/metrics, POST delivery/webhook — no POST/PUT templates, no broadcasts/history; matches local, confirms 404s are real deploy state not stale build-items

**Issues:**

#### COMMU-1 · Save Template (create) is broken in live: POST /communications/templates has no route or handler
- **Module:** Communication
- **User Journey:** Admin opens Broadcast Admin → Templates tab → fills code/channel/body/variables → taps 'Save template'
- **Severity:** 🔴 Critical
- **Description:** The client (live build, useApi:true) calls POST /communications/templates via createTemplate, but the backend router has no such route and no handleCreateTemplate handler exists. The request enters communication_router (path startsWith '/communications/') and falls through matchCommunicationRoute → returns 404 NOT_FOUND. Templates can therefore never be created from the app in production; only the seed templates are ever visible. The Templates GET, by contrast, works (live-probed).
- **Evidence:** Client: remote/communication_remote_datasource.dart:39 (POST CommunicationApiPaths.templates). Router: communication_router.ts:25 only GET /communications/templates (no POST). Handlers: grep of communication_handlers.ts has no handleCreateTemplate/handleUpdateTemplate. Live build wiring: repository_providers.dart:408-417 (useApi:true). Deployed VPS router identical (ssh akshara cat .../communication_router.ts).
- **Root Cause:** Backend template-write endpoints were never built/deployed; the Flutter UI + repository + DTO + mock were built ahead of the server, and the mock masks the gap in tests.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### COMMU-2 · Broadcast History & Delivery tabs broken in live: GET /communications/broadcasts/history returns 404
- **Module:** Communication
- **User Journey:** Admin opens Broadcast Admin → History tab (or Delivery tab) to see past campaigns / reach; also auto-triggered after sending a broadcast
- **Severity:** 🟠 High
- **Description:** Both the History and Delivery tabs in BroadcastAdminScreen read the broadcast-history provider, which calls GET /communications/broadcasts/history. This route does not exist on the live backend (404, live-probed). Worse, a successful broadcast send invalidates this provider, so immediately after the 'Broadcast sent to N recipients' snackbar, the History and Delivery tabs render an error state — making a working send look half-broken. There is a working delivery-metrics endpoint (/communications/delivery/metrics) the client never calls.
- **Evidence:** Live probe: GET /communications/broadcasts/history → {"error":{"code":"NOT_FOUND","message":"Route not found: GET /communications/broadcasts/history"}}. Client path: communication_api_paths.dart:4 broadcastHistory='/communications/broadcasts/history', called remote datasource:60. Router: communication_router.ts has no history route. Invalidation: communication_mutations_provider.dart:49. Tabs: broadcast_admin_screen.dart:93-94 (_HistoryTab/_DeliveryTab both use historyState).
- **Root Cause:** History endpoint never built/deployed; the existing /communications/delivery/metrics handler was not wired to the client, and the broadcast-history contract was implemented only in the mock.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### COMMU-3 · Mock repository masks the live 404s for templates-write and broadcast-history
- **Module:** Communication
- **User Journey:** QA / regression suite — 'Sending broadcast adds entry in history' and template save tests pass green
- **Severity:** 🟠 High
- **Description:** MockCommunicationRepository implements createTemplate/updateTemplate/listBroadcastHistory (lines 68/85/109), so the widget test (communication_broadcast_admin_widget_test.dart 'Sending broadcast adds entry in history') and the client-alignment contract test pass even though the live backend lacks these routes. This is why the broken journeys above slipped past the gate suite. Any future certification of this module must probe live, not just run unit/widget tests.
- **Evidence:** Mock: mock_communication_repository.dart:68/85/109. Passing gate test: flutter_test.log line +1935 'Sending broadcast adds entry in history' (widget test using mock, not live API). No contract test asserts the router actually exposes templates-POST or broadcasts/history.
- **Root Cause:** Hybrid repo + mock fallback means tests exercise the mock; no client↔deployed-router path-parity test exists for the write/history endpoints.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### COMMU-4 · Compose audience is free-text with no validation or picker; invalid value yields a raw 500
- **Module:** Communication
- **User Journey:** Admin composes a broadcast and types/edits the Audience field (default 'all_parents')
- **Severity:** 🟡 Medium
- **Description:** The Compose tab Audience field is a plain TextField. Valid values are the magic strings all_parents/all_teachers/all_students/school_wide (plus a few aliases). normalizeBroadcastAudience passes any unknown string through unchanged, so a typo or an unsupported segment is INSERTed and hits the comm_broadcasts CHECK constraint → handleCreateBroadcast returns INTERNAL_ERROR 500 ('Failed to send broadcast'), not a friendly validation message. A non-technical school admin has no way to know the allowed audiences.
- **Evidence:** UI: broadcast_admin_screen.dart:23 _audienceController plain TextField (line 164). Service: communication_service.ts:43 normalizeBroadcastAudience returns aliases[audience] ?? audience (pass-through). handlers.ts:172 returns generic INTERNAL_ERROR 500 (only CommunicationValidationError maps to 422; CHECK violation is not that type).
- **Root Cause:** No client-side audience enum/dropdown and no server-side allow-list validation before INSERT.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### COMMU-5 · No UI-level RBAC gate on Broadcast Admin screen (mutations are guarded, but the screen is always shown)
- **Module:** Communication
- **User Journey:** A role lacking manageCommunication navigates to /school/communications/broadcast-admin from the school-completion hub
- **Severity:** ⚪ Low
- **Description:** BroadcastAdminScreen renders all four tabs and the Send/Save buttons unconditionally. RBAC is only enforced at mutation time (_assertManageCommunication / _assertManageCommunicationTemplates in communication_mutations_provider.dart) which throws and surfaces a forbidden error after the user fills the form. Server-side perms (sendBroadcast on POST broadcasts) are correctly enforced, so this is not a security hole, but it is a poor experience — the controls should be hidden/disabled for users without permission.
- **Evidence:** broadcast_admin_screen.dart:53-98 builds tabs/buttons with no canManageCommunication check; gate is only in communication_mutations_provider.dart:12-34 at execute() time. Server enforcement confirmed: handlers.ts:141 requirePermission(sendBroadcast).
- **Root Cause:** Screen omits a capability check at build time; relies solely on post-submit mutation guards.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** RBAC

#### COMMU-6 · Dead client constant: processQueue path defined but never called
- **Module:** Communication
- **User Journey:** n/a (code hygiene)
- **Severity:** ⚪ Low
- **Description:** CommunicationApiPaths.processQueue ('/communications/notifications/process-queue') is defined client-side but never referenced anywhere in lib/. The backend route + handleProcessNotificationQueue exist and are exercised by the async drain, but there is no client trigger. Harmless dead code; flag for cleanup.
- **Evidence:** communication_api_paths.dart:12 defines processQueue; grep of lib/ finds only the definition, no usage. Server route exists (communication_router.ts:31).
- **Root Cause:** Client constant added speculatively; queue draining is fully server-driven via EdgeRuntime.waitUntil.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

**Strengths (working well):**
- Broadcast send path is genuinely production-grade and Wave4-certified live: bounded cohort (5000), two multi-row INSERTs, async drain via EdgeRuntime.waitUntil with inline fallback, status 'queued' — confirmed live and by deno broadcast_batch_test.ts.
- All error/loading/empty states in the four BroadcastAdminScreen tabs use AksharaLoadingState + AksharaErrorState.fromFailure(apiFailureMapper) (Wave5 error-leak standard), so even the broken History/Delivery tabs fail visibly rather than silently.
- WhatsApp deep-link helper is robust and reused: international normalization, trunk-0 handling, dead-control hiding, and SnackBar feedback — the chosen no-Meta-API approach is implemented cleanly.
- Comm-hub direct messaging (parent/teacher threads + send) and push device-token/mark-read routes are wired end-to-end and live (teacher threads returned real data; parent-scope RBAC correctly 403s the schoolAdmin token).
- Templates GET and delivery-metrics GET are deployed and return real prod data; RBAC permissions (viewCommunications/sendBroadcast/manageCommunications) are present on every server handler.

---

### Transport
**Code:** `TRANS`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Traced every screen in lib/features/transport (dashboard, routes, vehicles, drivers, allocation, attendance, tracking, reports, settings) -> providers -> mutations -> hybrid/api repository -> TransportApiPaths -> deployed transport_router.ts -> write/read handlers -> RBAC (manageTransport/viewTransport) -> entitlement. Confirmed live deployment via ssh akshara (router + write handlers present) and 10 GET live probes (all 200). Cross-checked batch5 cert (write loop + parent-403) and gate logs (read + RBAC tests). Did NOT exhaustively read vehicles/dashboard widget internals beyond write/AI checks, and did not run write probes (read-only mandate). Key gaps are missing UI for a deployed write (attendance), placeholder GPS/delay journeys, and incomplete SIS handoff/forms — no Critical data-loss/security issue found.

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Record transport pickup/drop attendance | 🔴 broken | Backend POST /transport/attendance (handleRecordAttendance) deployed (transport_router.ts:52), but NO client wiring: grep recordAttendance across lib/ returns nothing; transport_attendance_screen.dart is read-only table (no mark picked/absent button). Coordinator cannot record attendance from the app. |
| Live GPS monitoring / delay -> notify parents | 🔴 broken | transport_tracking_screen.dart:17 'placeholder architecture'; line 93 'map provider wiring is future work'; no live map, no 'Notify Parents' action. No TR-08 Delay Notifications screen exists (not in kTransportNavScreens, transport_navigation.dart:6-16). |
| Allocate student -> transfer -> remove | 🟡 partial | POST/POST transfer/DELETE allocations deployed & RBAC-enforced (transport_write_handlers.ts:130-257; batch5 cert line 38/57). But UI assign dialog (transport_workflow_actions.dart:101-168) only fires for existing !isAssigned rows and never sends studentName/admissionNumber/sisStudentId; no flow to add a student to transport from SIS. |
| Export transport reports | 🟡 partial | transport_reports_screen.dart:85-96 & 152-156 Export buttons only show a SnackBar 'export queued' — no backend call, no file. GET /transport/reports & /occupancy-metrics live (200) for on-screen data. |
| Transport settings management | 🟡 partial | GET /transport/settings live 200; but transport_settings_screen.dart has no write/save controls (grep onPressed/Switch/Save = none). View-only. |
| View transport (dashboard/routes/vehicles/drivers/allocations/attendance/tracking/reports/settings) | ✅ verified | All 10 GET endpoints live 200 (probe BASE/transport/* with schoolAdmin token); client TransportApiPaths.dart paths match deployed transport_router.ts GET map exactly; live data real (routes return stops w/ lat/lng, drivers return phone). Deployed: ssh akshara transport_router.ts present (Jun 24). |
| Create route (draft) -> activate | ✅ verified | POST /transport/routes + /transport/routes/{id}/activate deployed (transport_router.ts:44-57); handleCreateRoute/handleActivateRoute enforce manageTransport (createModuleWriteHandlers('manageTransport') + requireSchoolOperationalScope); UI gated by AksharaManageAction(manageTransport) at transport_routes_screen.dart:47-55; batch5 cert line 57 certifies this loop. NOTE create dialog is single-field only (see issues). |
| Driver WhatsApp contact | ✅ verified | transport_drivers_screen.dart:138-143/184-189 WhatsAppContactButton with sanitized phone (WhatsAppLauncher.resolvePhoneDigits, renders nothing if undialable — no dead button); live drivers GET returns +91 phone. batch B5 pattern. |
| RBAC enforcement (parent/student denied writes) | ✅ verified | Server: every write via createModuleWriteHandlers('manageTransport') -> requirePermission + requireSchoolOperationalScope (module_write_handlers.ts:51-90). batch5 cert line 71: parent token -> 403 on POST /transport/routes. Reads gated viewTransport + org scope (deno_test.log: 'viewTransport required', 'org scope denied'). |
| Entitlement gating (module.transport) | ✅ verified | index.ts:94 withEntitlement(routeTransport,'/transport','module.transport') deployed (ssh akshara confirmed); deno_test.log 'plan allows transport but school switched it off' covers school-level disable. |

**Live probes:**
- `GET /transport/{dashboard,routes,vehicles,drivers,allocations,attendance,tracking,reports,settings,occupancy-metrics} (schoolAdmin token)` → all 200
- `GET /transport/routes` → 200, real data: items[].stops with lat/lng/sequence/scheduledTime (e.g. Route 12 — North)
- `GET /transport/drivers` → 200, real data: Ramesh Kumar, phone +91 98765 22001, rating 4.8 (drives WhatsApp button)
- `ssh akshara grep transport /opt/akshara/functions/api/index.ts` → line 23 import routeTransport; line 94 withEntitlement(routeTransport,'/transport','module.transport') — deployed
- `ssh akshara cat transport_router.ts` → deployed router has POST /transport/routes, /allocations, /attendance, /routes/{id}/activate, /allocations/{id}/transfer, DELETE /allocations/{id} — matches client
- `ls supabase/functions/_shared/transport/` → transport_write_handlers.ts present (no _test.ts for writes); only transport_read_repository_test.ts

**Issues:**

#### TRANS-1 · Transport attendance cannot be recorded from the app (write endpoint orphaned)
- **Module:** Transport
- **User Journey:** Record transport pickup/drop attendance
- **Severity:** 🟠 High
- **Description:** Backend POST /transport/attendance (handleRecordAttendance) is deployed and RBAC-enforced, but there is zero client wiring: no recordAttendance method in TransportRepository interface/hybrid/api/mock, and transport_attendance_screen.dart renders a read-only table with no mark-picked/waiting/absent control. A coordinator literally cannot mark a student picked up or absent, so the parent-notified column is never driven by app input and the TR-07 pickup-status journey is non-functional end-to-end.
- **Evidence:** grep 'recordAttendance' across lib/ returns nothing; transport_attendance_screen.dart:96-153 (table, no buttons); backend handler exists transport_write_handlers.ts:74-103; route deployed transport_router.ts:52.
- **Root Cause:** Write endpoint shipped (A6) without the corresponding Flutter repository method + UI action; attendance screen built as read-only.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### TRANS-2 · GPS tracking and delay notifications are placeholders / missing (P0 in spec)
- **Module:** Transport
- **User Journey:** Live GPS monitoring / delay -> notify parents
- **Severity:** 🟠 High
- **Description:** Spec TR-06 GPS Monitoring and TR-08 Delay Notifications are P0, including live map, bus markers, ETA, 'Notify Parents' on delay, and parent push. The tracking screen is an explicit placeholder ('map provider wiring is future work') with a static telemetry table, and no TR-08 delay-notification screen exists at all. The core safety journey (detect delay -> notify affected parents) is absent.
- **Evidence:** transport_tracking_screen.dart:17 'placeholder architecture', :93 'map provider wiring is future work'; transport_navigation.dart:6-16 has no delay/notifications screen; spec Transport.md lines 52-54 mark TR-06/07/08 as P0.
- **Root Cause:** Real-time GPS/telemetry provider and delay-broadcast pipeline never built; module shipped read-first.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Cross-module

#### TRANS-3 · Allocation UI cannot add a student from SIS; sends no student identity; SIS transport-flag handoff missing
- **Module:** Transport
- **User Journey:** Allocate student -> transfer -> remove
- **Severity:** 🟡 Medium
- **Description:** The assign dialog (AssignStudentTransportRequest) carries only allocationId/routeId/pickupStop/dropStop — never studentName, admissionNumber, or sisStudentId, so the server stores those as empty strings. The UI only offers Assign on pre-existing unassigned allocation rows; there is no flow to pick a real student from SIS and add them to transport. Consequently the documented TR-05->Student SIS 'Transport flag' cross-module handoff (Transport.md:350) is never written back, so a student's SIS record does not reflect transport enrollment.
- **Evidence:** transport_requests.dart:33-45 (only 4 fields); transport_workflow_actions.dart:148-156 sends only those; handler defaults student fields to '' (transport_write_handlers.ts:141-150); no transport-flag write to student SIS anywhere in _shared/transport.
- **Root Cause:** Allocation modeled as edit-of-existing-row rather than create-from-SIS; cross-module write-back to SIS not implemented.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Cross-module

#### TRANS-4 · Create-route dialog is a single text field, not the spec route editor/wizard (TR-D-01)
- **Module:** Transport
- **User Journey:** Create route (draft) -> activate
- **Severity:** 🟡 Medium
- **Description:** Spec TR-D-01 CreateRoute is a 720px wizard with drag-ordered stops, map pin drop, AM/PM schedule, and vehicle assignment. The shipped dialog has one field (route name) with a hardcoded default 'Route QA — East Loop'; distance/AM/PM/shift use silent server defaults and stops/vehicle cannot be set. Assign/Transfer dialogs likewise use free-text Route ID fields prefilled with QA fixtures ('route_12','route_08','Lake View Colony') instead of dropdowns of real routes/stops — error-prone for a real coordinator (typo a routeId -> route name resolves to the raw id).
- **Evidence:** transport_workflow_actions.dart:13 nameController default 'Route QA — East Loop'; :106-108 'route_12'/'Lake View Colony'; :175-177 'route_08'/'Hitech City'; handler defaults distanceKm/amDeparture etc (transport_write_handlers.ts:46-53); routeNameById falls back to raw id (transport_write_handlers.ts:21-27).
- **Root Cause:** Dialogs built as minimal QA-driving stubs rather than full forms; route/stop pickers not implemented.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### TRANS-5 · Reports 'Export PDF' and Settings are non-functional (fake export, no save)
- **Module:** Transport
- **User Journey:** Export transport reports / Transport settings management
- **Severity:** ⚪ Low
- **Description:** The transport reports Export buttons only display a SnackBar ('export occupancy report queued' / 'Report export queued') with no backend request and no generated file — unlike other modules that produce real PDFs. The Transport settings screen (TR-09) renders view-only with no save/toggle controls, so transport configuration cannot be changed in-app.
- **Evidence:** transport_reports_screen.dart:85-96 onPressed -> SnackBar only; :152-156 _queueExport SnackBar only; transport_settings_screen.dart grep onPressed/Save/Switch -> none.
- **Root Cause:** Export wired to a stub action; settings screen built display-only.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### TRANS-6 · Transport AI is a single static insight string, not the interactive Copilot in spec
- **Module:** Transport
- **User Journey:** View transport dashboard
- **Severity:** ⚪ Low
- **Description:** Spec §16 describes an interactive AI Transport Copilot (delay prediction, route optimization, absent-pickup risk, fuel anomaly, example prompts, broadcast/notify actions) on TR-01/06/08. The dashboard shows one AksharaInsightCard fed by data.aiInsight, which is a hardcoded mock string with no server AI computation. No prompts, no actions.
- **Evidence:** transport_dashboard_screen.dart:96-100 AksharaInsightCard(message: data.aiInsight); mock_transport_repository.dart:293 aiInsight hardcoded; no aiInsight logic in transport_handlers.ts/transport_read_repository.ts (grep empty).
- **Root Cause:** AI Copilot for transport never built; insight is static fixture text.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** AI

#### TRANS-7 · No backend unit tests for transport write handlers
- **Module:** Transport
- **User Journey:** Create/allocate/transfer/remove/attendance writes
- **Severity:** ⚪ Low
- **Description:** transport_write_handlers.ts (create route, activate, assign, transfer, remove, record attendance) has no _test.ts; only transport_read_repository_test.ts exists. Write RBAC/validation/audit paths are exercised only indirectly via Flutter contract tests against mocks, leaving server-side write logic (e.g. attendance replace-vs-insert, transfer route resolution, audit emission) without direct deno coverage.
- **Evidence:** ls supabase/functions/_shared/transport/ shows only transport_read_repository_test.ts; grep deno_test.log for transport write/assign/transfer = none.
- **Root Cause:** Write handlers added without companion deno tests.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

**Strengths (working well):**
- All 10 transport GET endpoints live and returning real data (probe -> 200); client TransportApiPaths exactly match the deployed transport_router.ts route map, no path drift.
- Write loop (create route -> activate -> assign -> transfer -> remove) is deployed, RBAC-enforced server-side (manageTransport + school operational scope), and UI-gated by AksharaManageAction(manageTransport) — consistent client/server RBAC; batch5 cert proves parent -> 403.
- withMockWriteFallback only falls back on ApiNotConnectedException, so in a live build real write failures are NOT silently swallowed to mock (no fake-success risk); errors surface to user via SnackBar in all workflow dialogs.
- Driver WhatsApp contact uses sanitized phone digits and renders nothing when undialable (no dead button); live drivers data carries valid phones.
- Entitlement gating (module.transport via withEntitlement) deployed and covered by deno tests including school-level disable; reads gated by viewTransport + org scope.
- Solid empty/loading/error states across screens (AksharaLoadingState/ErrorState/EmptyState) and responsive card-vs-table layouts via AdminLayout.useCardLayout.

---

### Hostel
**Code:** `HOSTE`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Traced all 8 hostel screens (dashboard/students/rooms/attendance/leave/mess/visitors/reports) screen->provider->repository->datasource path->router->handler->RBAC. Verified client paths (hostel_api_paths.dart) match deployed router (hostel_router.ts) on both GET and POST. Confirmed deployment via ssh akshara (index.ts + _shared/hostel files). Read the 5 write handlers, both read/write factory RBAC, and the entity read/write store internals (key finding: snapshots are static stored payloads, not recomputed from list entities). Reviewed batch5 cert and gate-log hostel test results. LIMITATION: live GET probes blocked — the provided read-only token was expired (~38s past exp) so all /hostel/* and /auth/me returned UNAUTHORIZED; deployment/wire correctness confirmed by source+SSH instead. No writes attempted (read-only audit).

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Log visitor / gate pass (POST /hostel/visitors) | 🔴 broken | showLogVisitorDialog (hostel_workflow_actions.dart:342) -> logVisitorProvider -> POST /hostel/visitors -> handleLogVisitor (hostel_write_handlers.ts:226) INSERTs a 'visitor' list entity. BUT the Visitors screen reads handleVisitors=handleSnapshot('snapshot_visitors') (hostel_handlers.ts:31) — a frozen seeded snapshot, NOT the visitor list entities. A newly logged visitor never appears on the Visitors screen. |
| Hostel attendance (mark daily roll-call) | 🔴 broken | Listed key journey. Attendance screen (hostel_attendance_screen.dart) is read-only — grep for onPressed/showDialog/execute/FilledButton returns NOTHING. No POST /hostel/attendance route exists (hostel_router.ts POST block only has students/rooms/visitors/room/checkout). Warden cannot mark hostel attendance from the app. |
| Mess management (menu/headcount/cost) | 🔴 broken | Listed key journey. Mess screen (hostel_mess_screen.dart) is read-only display of HostelMessData snapshot; no write actions (grep onPressed/execute = none). handleMess=handleSnapshot('snapshot_mess'). No POST route for mess. Cannot update menu/headcount/cost. |
| Admit student into hostel (POST /hostel/students) | 🟡 partial | Wired end-to-end: hostel_workflow_actions.dart:30 showAdmitHostelStudentDialog -> admitHostelStudentProvider (hostel_mutations_provider.dart:32, asserts Permission.manageHostel) -> HybridHostelRepository.admitHostelStudent -> POST /hostel/students -> hostel_write_handlers.ts:54 handleAdmitStudent (runWrite manageHostel + audit, status 201). Batch5 cert confirms live persist+RBAC. PARTIAL: dialog prefills mock data ('Karthik Sharma','SIS-STU-10425') and SIS id is free-text with no picker/validation; backend stores sisStudentId as unvalidated string (no FK). |
| Assign room/bed to resident (POST /hostel/students/{id}/room) | 🟡 partial | showAssignHostelRoomDialog (hostel_workflow_actions.dart:105) -> assignHostelRoomProvider -> POST /hostel/students/{id}/room -> handleAssignRoom (hostel_write_handlers.ts:86) finds student+room, sets status=resident, increments room occupiedBeds. PARTIAL: dialog uses free-text Room ID/Bed fields prefilled with mock 'room_4'/'B1' — no room or bed dropdown; warden must type raw room UUID. |
| Leave / gate-pass approval | 🟡 partial | Hostel leave screen (hostel_leave_screen.dart) is read-only — no approve/reject buttons (grep = none). Approval IS wired but only via the generic Approvals engine: approval_type_handlers.ts:96 calls flipHostelLeaveStatus (hostel_write_handlers.ts:27). The hostel leave screen has no link to Approvals and no create-leave path; warden must leave the module to act. |
| Cross-module: Hostel <-> SIS / Finance | 🟡 partial | Students screen links to SIS registry (hostel_students_screen.dart:69) and row tap -> sisStudentDetail(student.sisStudentId) (line 186); Finance insight card -> financeFeeStructures (line 139). But sisStudentId is unvalidated free text from admit (no FK), so the SIS-detail deeplink can 404; feePending is a hardcoded '₹0' string (hostel_write_handlers.ts:68) not a live Finance lookup. |
| Live GET probe of /hostel/* endpoints | ⚪ unverified | Read-only token expired 38s before probe (exp 1782461822 vs now 1782461860); all /hostel/* and /auth/me returned UNAUTHORIZED. Deployment instead confirmed via ssh akshara cat /opt/akshara/functions/api/index.ts (routeHostel present) and ls _shared/hostel (all 4 files present). Token carries viewHostel+manageHostel. |
| Create hostel room (POST /hostel/rooms) | ✅ verified | showCreateHostelRoomDialog (hostel_workflow_actions.dart:235) with proper AksharaFormField validation (block+roomNumber required) -> createHostelRoomProvider -> POST /hostel/rooms -> handleCreateRoom (hostel_write_handlers.ts:195) inserts room entity + audit, status 201. Deployed (ssh: hostel_write_handlers.ts present). Add-room button gated by AksharaManageAction(Permission.manageHostel) hostel_rooms_screen.dart:44. |
| Check student out (POST /hostel/students/{id}/checkout) | ✅ verified | checkoutHostelStudent (hostel_workflow_actions.dart:179) confirm dialog -> checkoutHostelStudentProvider -> POST /hostel/students/{id}/checkout -> handleCheckoutStudent (hostel_write_handlers.ts:154) sets status=checkedOut + audit. Button only shown for resident/onLeave (hostel_students_screen.dart:267). |
| Read screens (dashboard/students/rooms/attendance/leave/mess/visitors/reports) | ✅ verified | All 8 routes wired (hostel_navigation.dart) and deployed (ssh akshara: routeHostel imported index.ts:25, entitlement-gated module.hostel index.ts:96). GET handlers enforce viewHostel + school scope (createModuleReadHandlers('viewHostel'), module_read_handlers.ts:35). Gate logs: 'viewHostel permission enforced ... ok'; flutter contract+screen tests pass. Each screen has loading/error/empty states (e.g. hostel_rooms_screen.dart:72-90). |

**Live probes:**
- `ssh akshara grep routeHostel /opt/akshara/functions/api/index.ts` → index.ts:25 import routeHostel; index.ts:96 withEntitlement(routeHostel,'/hostel','module.hostel') — deployed + entitlement-gated
- `ssh akshara ls /opt/akshara/functions/_shared/hostel/` → hostel_handlers.ts, hostel_read_repository.ts, hostel_router.ts, hostel_write_handlers.ts all present (matches repo)
- `GET /hostel/{dashboard,students,rooms,attendance,leave,mess,visitors,reports,occupancy-metrics} with token` → All returned UNAUTHORIZED 'Invalid access token' — token expired (exp 1782461822, probe at 1782461860). Not a hostel bug; /auth/me also UNAUTHORIZED. Live data behavior unverified.
- `GET /health` → {data:{status:ok,service:akshara-api}} — API up
- `decode token.txt claims` → role schoolAdmin; permissions include viewHostel + manageHostel; expired

**Issues:**

#### HOSTE-1 · Hostel attendance cannot be marked — read-only screen, no backend write route
- **Module:** Hostel
- **User Journey:** Warden opens Hostel > Attendance to record who is present/absent at night roll-call
- **Severity:** 🟠 High
- **Description:** The Attendance screen is purely a read view of a snapshot list. There is no Mark/Save/Edit affordance (no onPressed/showDialog/FilledButton anywhere in hostel_attendance_screen.dart) and no POST /hostel/attendance route in hostel_router.ts. The roll-call journey explicitly named for this module cannot be completed in-app; attendance data can only ever be the seeded snapshot.
- **Evidence:** hostel_attendance_screen.dart (no write actions on grep); hostel_router.ts:41-60 POST block lacks any attendance route; hostel_handlers.ts:19 handleAttendance is a list-read only.
- **Root Cause:** Hostel was built read-first; attendance write was never added (backend route + UI mark flow both missing).
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### HOSTE-2 · Logged visitor never appears on Visitors screen (snapshot vs list mismatch)
- **Module:** Hostel
- **User Journey:** Security logs a parent visitor; warden expects to see the active gate pass in Hostel > Visitors
- **Severity:** 🟠 High
- **Description:** handleLogVisitor INSERTs into the 'visitor' list entity_type, but the Visitors screen reads handleVisitors=handleSnapshot('snapshot_visitors') — a frozen payload that is never recomputed from visitor entities. The write succeeds (201 + success snackbar with passId) but the list shown to staff is stale, so the just-created pass is invisible. Same staleness applies to dashboard KPIs / reports / occupancy after admit/assign/checkout/create-room.
- **Evidence:** hostel_write_handlers.ts:242 insert(...,'visitor',...); hostel_handlers.ts:31 handleVisitors=handleSnapshot('snapshot_visitors'); entity_read_store.ts:57-77 getSnapshot returns a single stored payload row (id='default'), no aggregation over list entities.
- **Root Cause:** Snapshot dashboards/visitors are stored static JSONB payloads not derived from the list entities that writes mutate; the read store has no recompute step.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Data-integrity

#### HOSTE-3 · Mess management is display-only — no menu/headcount/cost write path
- **Module:** Hostel
- **User Journey:** Mess in-charge updates today's menu and headcount, or records mess cost
- **Severity:** 🟡 Medium
- **Description:** Mess screen renders HostelMessData from snapshot_mess with zero write controls; no POST /hostel/mess route exists. The 'mess' journey named for the module is not actionable; numbers are static seeded data.
- **Evidence:** hostel_mess_screen.dart (no onPressed/execute); hostel_handlers.ts:27 handleMess=handleSnapshot('snapshot_mess'); hostel_router.ts has no mess POST.
- **Root Cause:** Read-first build; mess write never scoped.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### HOSTE-4 · Assign-room dialog uses free-text Room ID/Bed with mock prefills instead of pickers
- **Module:** Hostel
- **User Journey:** Warden assigns an awaiting student to an actual vacant room and bed
- **Severity:** 🟡 Medium
- **Description:** showAssignHostelRoomDialog presents plain TextFields prefilled with mock values ('ho_stu_5','room_4','B1'). The warden must hand-type the room's raw id; there is no dropdown of vacant rooms or free beds, and no client validation that the room exists or has capacity. This is the same UX-gap class flagged in batch5 (inventory vendor picker). High risk of mis-typed/non-existent room ids in real use.
- **Evidence:** hostel_workflow_actions.dart:110-134 (TextEditingController defaults 'ho_stu_5','room_4','B1'; bare TextField labels).
- **Root Cause:** Demo-grade dialog never upgraded to entity pickers.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### HOSTE-5 · Hostel student SIS link is unvalidated free text — SIS deeplink can 404, feePending hardcoded
- **Module:** Hostel
- **User Journey:** Warden admits a boarder, then taps the resident row to open the student's SIS profile / sees fee pending
- **Severity:** 🟡 Medium
- **Description:** Admit dialog prefills mock SIS id and student fields and accepts arbitrary text; handleAdmitStudent stores sisStudentId as an unvalidated string with no FK to SIS, and writes feePending:'₹0' as a literal. The students table row navigates to sisStudentDetail(student.sisStudentId), which will 404 if the id is fabricated, and the fee figure is never a live Finance lookup, breaking the advertised Hostel->SIS/Finance handoffs.
- **Evidence:** hostel_workflow_actions.dart:34-37 mock prefills; hostel_write_handlers.ts:66 sisStudentId stored via str() (no validation), :68 feePending:'₹0' literal; hostel_students_screen.dart:186 onSelectChanged -> sisStudentDetail(student.sisStudentId).
- **Root Cause:** Admit was not wired to a real SIS student selector; hostel student is a standalone record loosely referencing SIS by string.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Cross-module

#### HOSTE-6 · Hostel leave screen has no approve/reject or create action and no link to Approvals
- **Module:** Hostel
- **User Journey:** Warden reviews a pending boarder leave request and approves it to issue the gate pass
- **Severity:** 🟡 Medium
- **Description:** Leave approval IS implemented in the backend (flipHostelLeaveStatus, called by the generic approval engine), but the Hostel > Leave screen is read-only: no approve/reject buttons and no link to the Approvals center, and there is no create-leave path. A warden viewing a Pending row in this module has no in-context way to act on it; they must know to navigate to a separate Approvals surface.
- **Evidence:** hostel_leave_screen.dart (read-only table, no action buttons on grep); flipHostelLeaveStatus wired only via approval_type_handlers.ts:96.
- **Root Cause:** Leave actions delegated entirely to the generic Approvals module with no cross-link surfaced in the hostel UI.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Cross-module

#### HOSTE-7 · Dashboard 'export' is a snackbar preview stub
- **Module:** Hostel
- **User Journey:** Admin exports the hostel dashboard
- **Severity:** ⚪ Low
- **Description:** The dashboard manage action calls showAksharaReportExportPreviewSnackBar (a preview-only snackbar), not a real export. Minor; reports screen handles this honestly by greying out non-finance exports, but the dashboard still presents an export affordance that only previews.
- **Evidence:** hostel_dashboard_screen.dart:41 onPressed -> showAksharaReportExportPreviewSnackBar(reportName:'Hostel dashboard').
- **Root Cause:** Export not implemented for hostel dashboard.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

**Strengths (working well):**
- Server RBAC is solid and consistent: GET handlers enforce viewHostel + school operational scope (module_read_handlers.ts), POST handlers enforce manageHostel + scope and run write+audit in one tenant transaction (module_write_handlers.ts via createModuleWriteHandlers('manageHostel')). Permissions exist in catalog (permissions.dart:33-34).
- Routes are deployed live and entitlement-gated: ssh akshara confirms routeHostel imported in api/index.ts:25 and wrapped withEntitlement(..., 'module.hostel') at index.ts:96; all 4 _shared/hostel/*.ts present on VPS.
- No silent mock-write risk in live builds: hostel Dio remote never throws ApiNotConnectedException, so withMockWriteFallback never falls back; real API errors propagate to the user via snackbar (hostel_workflow_actions.dart _showHostelMutationError).
- Client mutations re-assert manageHostel before calling (hostel_mutations_provider.dart:15 assertManageHostel) and invalidate dependent providers after success; write buttons gated by AksharaManageAction(Permission.manageHostel).
- Honest UX on reports: non-finance report exports are explicitly disabled/greyed rather than silent no-ops (hostel_reports_screen.dart:157-170).
- All read screens implement loading/error/empty states consistently and have card vs table responsive layouts (AdminLayout.useCardLayout). Covered by passing contract + widget tests (gate logs) and viewHostel-enforced deno test.
- Batch5 cert (akshara-batch5-module-writes-rbac) live-verified hostel admit/assign/create-room/visitor/checkout persist with audit and RBAC (parent token -> 403).

---

### Library
**Code:** `LIBRA`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Audited all 8 Flutter screens (dashboard/catalog/issues/returns/members/fines/resources/reports), 5 dialogs (issue/return/add-book/add-resource; waive confirmed ABSENT), the full client wire (paths→datasource→api/hybrid/mock repo→provider gating via LIBRARY_API_ENABLED), and the backend (router + read/write handlers + RBAC). Cross-referenced spec docs/Library.md (LB-01..08) and Batch5 cert. Confirmed gate logs (flutter+deno) for library tests. LIVE GET PROBES NOT RUN: read-only token expired (08:17Z, now 10:19Z → UNAUTHORIZED on all 8 endpoints + /auth/me) and SSH alias akshara refused (publickey) this session, so deployed index.ts and runtime responses could not be re-confirmed; deployment evidence rests on the Batch5 manual cert which predates Waves 1-5. Did not modify, edit, or write to live.

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Catalog: bulk CSV import / barcode-scan add | 🔴 broken | Spec LB-02/LB-D-05 require CSV import + barcode scan add. No import UI, no import route in library_router.ts, only single Add Book dialog (catalog screen filterTrailing, library_catalog_screen.dart:46). No edit/delete book route either (router has only POST /library/catalog). |
| Fines: view / waive / pay / post to Finance | 🔴 broken | library_fines_screen.dart is read-only display of snapshot_fines. No WaiveFine dialog (spec LB-D-04), no pay, no Finance posting — only a context.go to fee structures (fines screen:45,129). 'Records shown' KPI hardcoded '4' (fines screen:103-104). snapshot_fines is never updated by any write handler (handlers.ts:28 reads static snapshot; no writer in library module). Returns insight card falsely claims 'fines post to Finance FN-02' and 'Waive actions are audit-logged' (returns screen:104-105) — neither exists. |
| Members: enroll / block / view loans | 🔴 broken | library_members_screen.dart is read-only; no Add member (no POST /library/members in router), no Block action despite spec 'block if fines > limit'. Issue flow requires a memberId but there is no UI to create a library member — new students/staff cannot be enrolled. member.activeLoans is display-only and never updated by issue/return handlers. |
| Digital resources: upload + student/teacher read in app | 🔴 broken | Add Resource dialog collects title/type/classAccess/visibility only — NO file or URL field (workflow_actions.dart:284-356); LibraryDigitalResource model has no url/fileRef (library_models.dart:204-223). POST /library/digital-resources stores metadata only (write_handlers.ts:185). studentAppVisible/teacherAppVisible toggles have NO consumer: grep of lib/features/student\|parent\|teacher for 'library' returns zero. Spec LB-M-04 in-app PDF reader not built; nothing can actually be opened/downloaded. |
| Settings: loan period / fine-per-day / max books / categories | 🔴 broken | Spec LB-08 P2. No settings screen (no lib/features/library/settings), no nav destination (library_navigation.dart lists 8 screens, none is settings), no route. Rules hardcoded server-side: LOAN_DAYS=14, FINE_PER_DAY=5 (write_handlers.ts:16-18). School cannot configure max-books-per-student, loan period, fine rate, or block limit. |
| Issue book to member | 🟡 partial | Wire intact: datasource issueBook → POST /library/issues → handleIssueBook (write_handlers.ts:60), decrements availableCopies, audit. BUT dialog prefills MOCK seed IDs memberId='mem_5', isbn='978-0-07-802563-1' (workflow_actions.dart:28-29) which match mock_library_repository.dart:185/122 — in live build (LIBRARY_API_ENABLED=true, config/live_release.json:27) these IDs do not exist; handler tolerates missing member by using memberId as name (write_handlers.ts:75) → creates issue with garbage member. No member search/picker, no real scanner. member.activeLoans never incremented. |
| Return book + overdue fine calc | 🟡 partial | POST /library/returns → handleReturnBook (write_handlers.ts:115) computes daysOverdue*FINE_PER_DAY(5), closes loan, restores copy, audit. Return dialog prefills mock 'iss_2' (workflow_actions.dart:92). Fine is computed and shown in success snackbar BUT the computed fine is never persisted to the fines list (snapshot_fines is static seed, never written — see Fines journey). Return reachable via per-issue 'Return' button (issues screen) which passes real issue.id. |
| Reports: available/overdue/popular + export | 🟡 partial | library_reports_screen.dart renders charts from snapshot_reports (live read). Download button is a STUB: trailing IconButton onPressed → showAksharaReportExportPreviewSnackBar (reports screen:152) — preview snackbar only, no real export. Reports snapshot is static seed, never recomputed after issues/returns. |
| Live deployment of library endpoints | ⚪ unverified | Could not GET-probe: read-only token expired (exp 2026-06-26 08:17 UTC, now 10:19 UTC; /auth/me → UNAUTHORIZED). SSH alias 'akshara' refused (Permission denied publickey) this session so deployed index.ts not re-confirmed. Health endpoint OK. Deployment relies on Batch5 cert claim (live admin verify, cert lines 55-65) — that cert predates Wave 1-5 and is a manual run, not an automated docs/Library_CERTIFICATION.md. |
| Catalog: view books + add book (single) | ✅ verified | Client POST /library/catalog (library_api_paths.dart:6, datasource addBook) → router POST /library/catalog → handleAddBook (library_write_handlers.ts:32) inserts catalog entity, decrement bookkeeping, audit 'library.book.added'; manageLibrary gate (write_handlers.ts:14). Add Book dialog has required validation (workflow_actions.dart:240). Batch5 cert proved live add (LIVE_BACKEND_BATCH5... line 64). Read path live (deno 'library listEntities returns catalog'). |
| RBAC enforcement (read viewLibrary / write manageLibrary) | ✅ verified | Reads gated by createModuleReadHandlers('viewLibrary') (handlers.ts:5); writes by createModuleWriteHandlers('manageLibrary') (write_handlers.ts:14). Roles: superAdmin/schoolAdmin/librarian get manage; principal/vicePrincipal/management get view-only (role_permissions.dart). Client mirror: assertManageLibrary (library_mutations_provider.dart:15) + AksharaManageAction gate on every write button. Batch5 cert: parent token → HTTP 403 on POST /library/catalog (cert line 71). deno 'viewLibrary permission enforced' passes. |

**Live probes:**
- `GET /health` → 200 {data:{status:ok,service:akshara-api}} — backend up
- `GET /library/{dashboard,catalog,issues,returns,members,fines,digital-resources,reports} with token.txt` → All 8 → {error:{code:UNAUTHORIZED,message:'Invalid access token'}} — token expired (exp 2026-06-26T08:17:02Z, now 10:19Z); could not assess live data/RBAC
- `GET /auth/me with token.txt` → UNAUTHORIZED — confirms token expiry, not an endpoint fault
- `ssh akshara 'grep library /opt/akshara/functions/api/index.ts'` → Permission denied (publickey) — control socket not open this session; deployed router not re-confirmed

**Issues:**

#### LIBRA-1 · Issue/Return dialogs prefill MOCK seed IDs — wrong & data-corrupting in live build
- **Module:** Library
- **User Journey:** Issue book to member; Return book
- **Severity:** 🟠 High
- **Description:** showIssueLibraryBookDialog prefills memberId='mem_5' and isbn='978-0-07-802563-1'; showReturnLibraryBookDialog prefills issueId='iss_2'. These are mock_library_repository seed IDs. In the live release build (LIBRARY_API_ENABLED=true) the real backend has different UUIDs, so a librarian who accepts the defaults POSTs nonexistent IDs. The issue handler tolerates a missing member (uses memberId string as the member name, write_handlers.ts:75) so it silently creates an issue record with garbage member identity instead of rejecting — a data-integrity defect. There is also no member search, no active-loan picker, and the 'Scan ISBN'/'Scan return' buttons open a plain text-field dialog (no real barcode/QR scanner per spec LB-M-01/02).
- **Evidence:** lib/features/library/library_workflow_actions.dart:28-29,92; mock_library_repository.dart:185,42,122; write_handlers.ts:75 (member fallback); config/live_release.json:27 (LIBRARY_API_ENABLED true)
- **Root Cause:** Demo-seed defaults left in production dialogs; backend issue handler does not validate member/book existence before creating a loan.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Data-integrity

#### LIBRA-2 · Fines screen is read-only — no Waive/Pay, no Finance posting; stale snapshot
- **Module:** Library
- **User Journey:** Fines: view / waive / pay / post to Finance
- **Severity:** 🟠 High
- **Description:** Spec LB-05/LB-D-04 require an audited Waive action and optional Finance FN-02 fee-head linkage. The fines screen only displays snapshot_fines and links via context.go to fee structures. No waive route, no pay, no fine→Finance write. Worse, snapshot_fines is a static seed that no write handler ever updates, so the fine computed at return time (write_handlers.ts:133) never appears in the Fines list, and the 'Records shown' KPI is hardcoded '4'. The returns insight card actively lies: 'Overdue fines on return post to Finance FN-02... Waive actions are audit-logged' (returns screen:104-105).
- **Evidence:** lib/features/library/fines/library_fines_screen.dart:45,103-104,129; library_router.ts (no fines POST); library_handlers.ts:28 (static snapshot); library_write_handlers.ts (no snapshot_fines writer); returns screen:104-105
- **Root Cause:** Fines modelled as a static dashboard snapshot rather than derived/persisted records; waive + Finance-posting never built.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Cross-module

#### LIBRA-3 · No student/parent/teacher surfacing of library — 'My Books', reader, overdue reminders all absent
- **Module:** Library
- **User Journey:** Digital resources read in app; member view-own-loans
- **Severity:** 🟠 High
- **Description:** Spec promises students view active loans (LB-M-03 My Books), in-app PDF reader (LB-M-04), and overdue reminders to student/parent (cross-module Notifications). grep of lib/features/student, lib/features/parent, lib/features/teacher for 'library' returns ZERO references. The studentAppVisible/teacherAppVisible toggles and all the 'Visible in Student App' UI copy have no consumer. Students/teachers also lack viewLibrary, and /library/issues is school-scope (no per-member filter), so there is no role-scoped path for a student to see their own loans.
- **Evidence:** grep lib/features/{student,parent,teacher} for 'library' → no matches; library_models.dart:220-222 (toggles); issues screen:108 & resources screen copy; role_permissions.dart (students/teachers lack viewLibrary)
- **Root Cause:** Library built as an admin-only console; companion-app consumption and notification handoffs were never implemented.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Cross-module

#### LIBRA-4 · Digital resource upload stores metadata only — no file/URL, nothing to open
- **Module:** Library
- **User Journey:** Digital resources: upload + read
- **Severity:** 🟡 Medium
- **Description:** The Upload dialog collects title/type/classAccess/visibility but has no file picker or URL field; the model has no url/fileRef and the handler stores no content pointer. So a resource can be 'added' but never opened or downloaded by anyone. The 'downloads' counter is decorative. Combined with the missing reader, the entire digital-library journey is non-functional beyond listing titles.
- **Evidence:** lib/features/library/library_workflow_actions.dart:284-356 (no file/url field); library_models.dart:204-223 (no url); library_write_handlers.ts:185-200 (metadata only)
- **Root Cause:** Resource entity designed without storage integration; Supabase Storage exists (Batch 7) but is not wired to library resources.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### LIBRA-5 · Library Settings (LB-08) entirely missing — loan rules hardcoded
- **Module:** Library
- **User Journey:** Settings: loan period / fine rate / max books
- **Severity:** 🟡 Medium
- **Description:** No settings screen, nav entry, or route. Loan period (14 days) and fine-per-day (₹5) are hardcoded server constants; max-books-per-student, block limit, categories and holiday calendar are not configurable. Every pilot school is locked to the same rules, and 'block if fines > limit' cannot function because no limit is configurable and no block action exists.
- **Evidence:** no lib/features/library/settings dir; library_navigation.dart:7-14 (8 screens, no settings); library_write_handlers.ts:16-18 (LOAN_DAYS=14, FINE_PER_DAY=5 constants)
- **Root Cause:** LB-08 (P2) deferred and never built.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### LIBRA-6 · Read snapshots (dashboard/fines/reports) never recomputed after writes; member.activeLoans stale
- **Module:** Library
- **User Journey:** Dashboard KPIs; Reports; Members loan count
- **Severity:** 🟡 Medium
- **Description:** snapshot_dashboard, snapshot_fines, snapshot_reports are static seeds served by handleSnapshot; no write handler updates them. After issuing/returning books the dashboard 'Issued today'/'Overdue' KPIs, the fines list, and the reports charts stay frozen on seed data. Likewise the issue handler never increments member.activeLoans, so the Members loan-count and any fine-based block can never reflect reality. Catalog/issues/returns/members LIST endpoints are live and update correctly, so this is a consistency gap on the aggregate views, not data loss.
- **Evidence:** library_handlers.ts:8,28,36 (snapshot reads); library_write_handlers.ts (no snapshot_dashboard/fines/reports writer, no activeLoans update); issue handler write_handlers.ts:60-112
- **Root Cause:** Aggregates modelled as seed snapshots rather than derived from live entity rows.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Data-integrity

#### LIBRA-7 · No automated test/cert coverage for library writes or manageLibrary RBAC
- **Module:** Library
- **User Journey:** Live deployment / regression safety
- **Severity:** 🟡 Medium
- **Description:** Backend deno tests cover only 'library listEntities' (read) and 'viewLibrary permission'; none exercise handleIssueBook/handleReturnBook/handleAddBook/handleAddDigitalResource or the manageLibrary 403 path. Flutter tests cover screen render + DTO mapping. There is no docs/Library_CERTIFICATION.md; the only live write proof is the Batch5 manual verify, which predates Waves 1-5. The expired token + blocked SSH this session meant live GET probes could not re-confirm deployment.
- **Evidence:** scratchpad/gates/deno_test.log (only 'library listEntities' + 'viewLibrary permission enforced'); no docs/Library_CERTIFICATION.md; token.txt exp 2026-06-26T08:17Z (expired); ssh akshara → Permission denied this session
- **Root Cause:** Library never got a B-series/Completion-mode live cert; write handlers lack unit coverage.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Live-deploy-drift

#### LIBRA-8 · Report 'Download' button is a preview-snackbar stub
- **Module:** Library
- **User Journey:** Reports export RPT-LB-001/002/003
- **Severity:** ⚪ Low
- **Description:** Each report row's download IconButton calls showAksharaReportExportPreviewSnackBar with a generic 'Library report' name — it shows a snackbar and produces no file. There is no real export/print of Available/Overdue/Popular reports (spec RPT-LB-*).
- **Evidence:** lib/features/library/reports/library_reports_screen.dart:152
- **Root Cause:** Report export wired to a shared placeholder preview helper, not a real generator.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### LIBRA-9 · Catalog has no edit/delete; books are append-only
- **Module:** Library
- **User Journey:** Catalog management
- **Severity:** ⚪ Low
- **Description:** Spec LB-02 shows an 'Actions' column. The catalog table has no row actions and the router exposes only POST /library/catalog (no PUT/DELETE). A miskeyed ISBN/title/copy-count can never be corrected or a retired book removed.
- **Evidence:** lib/features/library/catalog/library_catalog_screen.dart:164-187 (no Actions cell); library_router.ts:38-47 (POST only)
- **Root Cause:** Only the add path was wired in Batch 5; edit/delete deferred.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

**Strengths (working well):**
- Client-to-router wire is clean and consistent: all 8 GET paths and 4 POST paths in library_api_paths.dart exactly match library_router.ts (dashboard/catalog/issues/returns/members/fines/digital-resources/reports).
- RBAC is correct and double-enforced: server gates reads with viewLibrary and writes with manageLibrary; client mirrors with assertManageLibrary + AksharaManageAction on every write button; principal/management get view-only matching the spec. Batch5 cert proved parent→403.
- Mock-vs-live fallback is safe: HybridLibraryRepository only falls back to mock on ApiNotConnectedException (backend down), not on real API errors — a failed live write surfaces to the user rather than silently writing to mock.
- Every screen implements proper loading / error / empty states via AksharaLoadingState/ErrorState/EmptyState, with semantic labels and a responsive card-vs-DataTable layout (AdminLayout.useCardLayout) for mobile.
- Issue/return/add flows are audited (emitMutationAudit with library.book.issued/returned/added/digital_resource.added) and the issue/return handlers keep catalog availableCopies consistent.
- Good cross-module deep-links: issue/fine/member rows route to SIS student detail when sisStudentId is present (issues screen:160, fines screen:175, members screen:153).

---

### Inventory
**Code:** `INVEN`  ·  **Verdict:** `gaps-block-cert`

_Coverage:_ Traced all 10 inventory sub-screens (dashboard/assets/categories/allocation/maintenance/procurement/vendors/reports/copilot/lifecycle) plus distribution+replacement screens through provider->repository->datasource->deployed router->handler->RBAC. Verified client/server path-string parity for reads, procurement writes, intelligence, and distribution. Confirmed live dart-define posture via config/live_release.json + scripts/run_live.sh. Confirmed mock-vs-live wiring via repository_providers + repository_config. Backend deno tests and Flutter router tests for inventory grepped from gate logs (all pass). Live GET probes could NOT be run: the provided token.txt is expired (GET /health ok, but /auth/me and all /inventory/* return UNAUTHORIZED 'Invalid access token'); SSH alias 'akshara' rejected (no control socket open this session), so deployed-source confirmation relied on repo at commit 6fb48af per briefing. Cited Batch 5 cert (LIVE_BACKEND_BATCH5_MODULE_WRITES_RBAC.md) for the previously live-verified PO approve/receive path and the still-open create-PO vendor limitation.

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Procurement: create draft PO -> approve -> receive goods (to Finance) | 🔴 broken | Create-PO is broken in live mode. inventory_mutations_provider.dart:117 sends a HARDCODED literal vendorId:'vendor_if_1' (a MOCK id, mock_inventory_finance_repository.dart:16) to the REAL finance create-PO. Finance repo validates/inserts vendor_id cast $1::uuid against inventory_vendors (inventory_finance_repository.ts:5-6,128-135). 'vendor_if_1' is not a UUID -> Postgres cast error -> 500 -> SnackBar error (inventory_workflow_actions.dart:73-77). inventoryFinanceRepositoryProvider.createPurchaseOrder has NO mock fallback (api_inventory_finance_repository.dart:122). Approve/Receive (orderId-based) are wired correctly and proven live in Batch 5 cert (LIVE_BACKEND_BATCH5_MODULE_WRITES_RBAC.md:67), but they cannot run because no valid draft PO can be created. |
| Seed/manage vendors (so a PO can reference a real vendor) | 🔴 broken | Backend route POST /inventory/vendors/catalog exists (inventory_finance_router.ts:21) with handleCreateVendor + manageInventory RBAC (inventory_finance_handlers.ts:117-120). Client method createVendor exists only in repo/datasource (api_inventory_finance_repository.dart:113, remote datasource) but is NEVER called from any screen: grep 'createVendor\|vendors/catalog' returns zero hits under lib/features. Vendors screen has no Add button (grep FilledButton/showDialog/createVendor = 0 in inventory_vendors_screen.dart). A school therefore cannot create a vendor in-app, which is the root cause the Create-PO journey has no valid vendorId. |
| Student distribution: distribute item -> parent acknowledge -> request replacement (-> Finance payment request) | 🔴 broken | Backend fully real & RLS-enforced: handlers create finance payment_requests via upsertPaymentRequest on replacement (inventory_distribution_repository.ts:139-187), routes registered in index.ts:98. BUT the Flutter distribution feature runs on MOCK in every live build: INVENTORY_DISTRIBUTION_API_ENABLED is ABSENT from both config/live_release.json and scripts/run_live.sh, so inventoryDistributionRepositoryProvider returns MockInventoryDistributionRepository (repository_providers.dart:460-466; flag default false repository_config.dart:175-181). Distribution screen create/mark-distributed/request-replacement (inventory_distribution_screen.dart:43,257,282) all hit the mock, never the deployed backend. |
| Register asset / allocate to person-room / log maintenance (per Inventory.md spec INV-02/03/04) | 🟡 partial | Inventory.md spec (docs/Inventory.md §2) lists Register assets / Allocate / Log maintenance as core Inventory-Manager write actions. Implementation has NONE: assets/categories/allocation/maintenance screens are read-only (grep for onPressed/showDialog/FilledButton excluding navigation/filter = 0 hits across all four). No backend write routes for assets/allocations/maintenance (inventory_router.ts only has GET reads + finance/distribution/intelligence writes). These journeys are display-only. |
| View inventory dashboard / assets / categories / allocations / maintenance / vendors / reports (read) | ✅ verified | Client paths in inventory_api_paths.dart (dashboard/assets/categories/allocations/maintenance/procurement/vendors/reports) all match deployed GET routes in inventory_router.ts:53-62 (matchInventoryRoute). Handlers go through createModuleReadHandlers('viewInventory', inventoryStore) (inventory_handlers.ts:5). Live build enables INVENTORY_API_ENABLED=true (config/live_release.json:28, run_live.sh:41). Dashboard screen uses inventoryDashboardViewStateProvider with loading/error/empty (inventory_dashboard_screen.dart:30,49). Backend test 'viewInventory permission enforced' ok (deno_test.log). |
| Inventory intelligence: copilot, asset lifecycle, procurement workflow, record lifecycle event | ✅ verified | Client paths (intelligence/copilot, /lifecycle, /lifecycle/events, /procurement-workflow, /procurement-workflow/:id/advance) match deployed routes (inventory_router.ts:26-43). RBAC enforced: viewInventoryIntelligence / manageAssetLifecycle / manageProcurementWorkflow with manageInventory fallback (inventory_intelligence_handlers.ts:22-44). Copilot screen has loading/error/empty via .when (inventory_copilot_screen.dart:22-24). Intelligence is deterministic compute (no Claude/Anthropic — grep returns nothing); 'computeInventoryCopilotFromSeed returns forecast and alerts' test ok (deno_test.log). Note read endpoints write snapshot rows (see issues). |

**Live probes:**
- `GET /health (no auth)` → 200 {"data":{"status":"ok","service":"akshara-api"},"error":null} — API up
- `GET /auth/me with token.txt` → {"error":{"code":"UNAUTHORIZED","message":"Invalid access token"}} — token expired; could not run authed inventory GET probes
- `GET /inventory/dashboard, /inventory/vendors/catalog, /inventory/procurement/orders with token.txt` → all return UNAUTHORIZED (token expired) — endpoints exist in deployed router source but not live-confirmed this session
- `ssh akshara 'grep inventory /opt/akshara/functions/api/index.ts'` → Permission denied (publickey,password) — no SSH control socket open; deployment confirmed via repo source at 6fb48af per briefing instead

**Issues:**

#### INVEN-1 · Distribution feature runs on mock in every live build (flag never enabled)
- **Module:** Inventory
- **User Journey:** Student distribution: distribute item -> parent acknowledge -> request replacement -> Finance payment request
- **Severity:** 🔴 Critical
- **Description:** The entire inventory distribution sub-module (dashboard, items list, create distribution, mark distributed, parent acknowledge, request replacement) is wired to MockInventoryDistributionRepository in live builds. The toggle INVENTORY_DISTRIBUTION_API_ENABLED is not present in config/live_release.json or scripts/run_live.sh, so inventoryDistributionApiEnabledProvider defaults to false and repository_providers.dart returns the mock. The fully-deployed, RLS-enforced backend (which creates real Finance payment_requests on replacement) is never called. A real school distributing uniforms/books would see mock data and replacement->fee handoffs would not occur.
- **Evidence:** repository_config.dart:175-181 (default false); repository_providers.dart:460-466 (mock fallback); config/live_release.json has only INVENTORY_FINANCE_API_ENABLED:22 and INVENTORY_API_ENABLED:28 (no distribution); scripts/run_live.sh:41 only INVENTORY_API_ENABLED; backend real at inventory_distribution_repository.ts:139-187 + index.ts:98.
- **Root Cause:** Live build dart-define manifest (live_release.json + run_live.sh) was never updated to flip INVENTORY_DISTRIBUTION_API_ENABLED=true after the distribution backend was deployed; provider defaults to mock.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Live-deploy-drift

#### INVEN-2 · Create purchase order is broken in live mode — sends hardcoded mock vendor id to real backend
- **Module:** Inventory
- **User Journey:** Procurement: create draft PO -> approve -> receive goods
- **Severity:** 🔴 Critical
- **Description:** The Create PO flow first calls the REAL finance create-PO with a hardcoded literal vendorId:'vendor_if_1' (a mock-only id). The finance backend casts vendor_id to ::uuid and FK-inserts into inventory_vendors; 'vendor_if_1' is neither a UUID nor a real row, so the write throws (500) and surfaces an error SnackBar. The second step also passes the dialog's free-text vendorName as vendorId (same FK failure). inventoryFinanceRepositoryProvider.createPurchaseOrder has no mock fallback, so the failure is hard. Net: a school cannot create a purchase order from the app, which also blocks the downstream approve/receive journey (Batch 5 listed this as a known limitation; it remains unfixed and is worse than 'needs a picker' because the id is a literal mock string).
- **Evidence:** inventory_mutations_provider.dart:117 (vendorId:'vendor_if_1'); api_inventory_repository.dart:142 (vendorName.trim() sent as vendorId); inventory_finance_repository.ts:5-6,128-135 (vendor_id $1::uuid FK insert); api_inventory_finance_repository.dart:122 (no mock fallback); mock_inventory_finance_repository.dart:16 ('vendor_if_1' is a mock id); LIVE_BACKEND_BATCH5_MODULE_WRITES_RBAC.md:85-89 (known limitation).
- **Root Cause:** Procurement create-PO was wired against mock seed ids/free-text and never given a real vendor selector; no Add-Vendor UI exists to produce a valid vendor UUID.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### INVEN-3 · No vendor-creation UI despite deployed POST /inventory/vendors/catalog
- **Module:** Inventory
- **User Journey:** Seed/manage vendors
- **Severity:** 🟠 High
- **Description:** The backend create-vendor route (manageInventory-gated) and the client createVendor repository method both exist, but no screen ever calls createVendor and the Vendors screen has no Add/Create action. Because of this, a school has no way to register a vendor, so procurement can never reference a valid vendor_id (root cause feeding the broken Create-PO journey).
- **Evidence:** inventory_finance_router.ts:21 + inventory_finance_handlers.ts:117 (route exists, RBAC manageInventory); api_inventory_finance_repository.dart:113 (createVendor defined); grep 'createVendor|vendors/catalog' under lib/features = 0; grep FilledButton/showDialog/createVendor in inventory_vendors_screen.dart = 0.
- **Root Cause:** Vendor management UI (list-with-create) was never built; only the read list screen exists.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### INVEN-4 · Inventory distribution router is not entitlement-gated (bypasses module.inventory plan gate)
- **Module:** Inventory
- **User Journey:** Student distribution
- **Severity:** 🟡 Medium
- **Description:** In index.ts, routeInventory is wrapped with withEntitlement(..., 'module.inventory') but routeInventoryDistribution is registered raw (no entitlement wrapper) immediately before it. A tenant whose plan does NOT include module.inventory can still reach /inventory/distribution/* read and write endpoints (create distribution, transition status, request replacement -> creates Finance payment requests). RBAC (manageInventoryDistribution/manageInventory) still applies, but the B2 plan-entitlement boundary is bypassed for the distribution surface.
- **Evidence:** index.ts:98 routeInventoryDistribution (unwrapped) vs index.ts:99 withEntitlement(routeInventory, '/inventory', 'module.inventory'); inventory_distribution_router.ts:52-58 has no entitlement check.
- **Root Cause:** Distribution router was added to the module list without the withEntitlement wrapper used for the sibling inventory routes.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** RBAC

#### INVEN-5 · Spec'd write journeys (register asset, allocate, log maintenance) have no UI or backend write route
- **Module:** Inventory
- **User Journey:** Register asset / allocate to person-room / log maintenance
- **Severity:** 🟡 Medium
- **Description:** Inventory.md (INV-02/03/04) specifies asset registration, allocation, and maintenance logging as primary Inventory-Manager actions. The asset/category/allocation/maintenance screens are read-only display lists with no create/edit/allocate/schedule actions, and there are no corresponding backend write routes (inventory_router.ts exposes only GET reads plus finance/distribution/intelligence writes). The asset lifecycle-event write is the only asset-touching write and is event-logging, not registration/allocation. This is a partial-implementation gap vs the module spec.
- **Evidence:** docs/Inventory.md §2 roles table (Register assets/Allocate/Log maintenance = core actions); grep onPressed/showDialog/FilledButton (excl. nav/filter) across assets/categories/allocation/maintenance screens = 0; inventory_router.ts:53-62 GET-only for these entities.
- **Root Cause:** These entities were delivered as read views over the JSONB entity store; the corresponding write CRUD (register/allocate/maintain) was never built.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### INVEN-6 · Inventory intelligence GET endpoints perform DB writes (snapshot INSERT) on every read
- **Module:** Inventory
- **User Journey:** Inventory intelligence: copilot / lifecycle / procurement workflow
- **Severity:** ⚪ Low
- **Description:** handleInventoryCopilot, handleAssetLifecycle and handleProcurementWorkflow are GET handlers but each INSERTs a row into inventory_intelligence_snapshots and emits a mutation audit on every call. A read/list refresh (or polling) silently writes rows and audit events, growing the table unbounded and muddying the audit trail. Read endpoints should be side-effect free or the snapshot persistence should be explicit/throttled.
- **Evidence:** inventory_intelligence_handlers.ts:62-66 (copilot INSERT), 101-105 (lifecycle INSERT), 214-218 (procurement INSERT), each followed by emitMutationAudit; routes are GET (inventory_router.ts:26-37).
- **Root Cause:** Snapshot persistence was attached to the compute-on-read path instead of an explicit save action.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Data-integrity

**Strengths (working well):**
- Backend procurement-finance handlers are solid: real relational PO/vendor/GRN tables, manageInventory RBAC with school-operational-scope, audit + domain-event emission in one tenant transaction, proper 404/422/500 mapping (inventory_finance_handlers.ts).
- RBAC is consistently enforced server-side on every inventory write with sensible fallbacks (manageInventoryDistribution->manageInventory, viewInventoryIntelligence->viewInventory), and the central RBAC route table covers inventory routes (rbac_route_inventory.ts; 'viewInventory permission enforced' test passes).
- Read screens have complete state handling: dashboard via ErpViewState (loading/error/empty), copilot via .when with AksharaErrorState.fromFailure, lists via watchRepositoryFuture with manual loading/error/empty providers.
- Client write paths use ApiFailure mapping and surface errors to the user via SnackBars rather than swallowing them (inventory_workflow_actions.dart, inventory_mutations_provider.dart).
- Procurement approve/receive correctly hand off to Finance (AP commitment + GRN + reconciliation), and distribution replacement creates real Finance payment_requests — the cross-module wiring is real on the backend.
- Client-side capability gating present on write buttons (AksharaManageAction with Permission.manageInventory) layered on top of server RBAC.

---

### Marketing (achievement_promotion / Publisher + Holiday Calendar, growth/_shared, communication)
**Code:** `MARKE`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Traced every screen/dialog/button in lib/features/achievement_promotion (2 screens) and lib/features/evolution/growth_platform_screen.dart to providers → repositories → datasource paths → router routes (promotion/growth) → handlers → RBAC → DB. Confirmed mock-vs-live gating (phase5ApiEnabledProvider). Read all three cert docs and cross-checked their claims against code. Live: GET /health 200 verified; authed live probes BLOCKED (token.txt expired 2026-06-26 08:17 UTC; SSH alias 'akshara' refused, owner control-socket not open) — relied on existing live certs (B6 13/13, Phase1 18/18, Phase2 13/13) for authed journeys. NOT fully covered (time/blocked): live re-probe of authed GETs; deep read of communication_repository fan-out internals (resolveBroadcastRecipients) and growth dashboard/funnel handlers beyond signatures; director_growth_screen (cross-module reuse, only skimmed). No files edited; no live writes.

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Holiday/Event Calendar — principal creates holiday/festival → list/view in app | 🔴 broken | Backend /school-calendar CRUD built + certified (school_calendar_router.ts; cert 18/18), but ZERO Flutter client: no calendar screen (only parent/attendance/attendance_calendar.dart exists), no repository, no '/school-calendar' path anywhere in lib/ (grep empty). Cert doc itself flags 'a dedicated calendar-admin screen is a minor remaining client task'. A school cannot create or view holidays/events from the app. |
| Multi-channel Publisher — end-to-end from the school UI (reach the Promotion Center, create a real festival/holiday publication, publish) | 🔴 broken | Promotion Center route /promotions is registered (app_router.dart:678-681) and guarded (route_guards.dart:59) but UNREACHABLE: no nav tile, no AdminModule, no .go/.push/goNamed references achievementPromotion (grep for navigation empty). Same 'surface hidden' pattern B6 fixed for growth (G1). Also the create FAB hardcodes achievementType:'competition_winner', title:'New School Achievement' (achievement_promotion_screen.dart:103-107) — no form, no subjectType/title/calendar-event picker, so even if reached only generic achievements can be made, not holidays/festivals. |
| Social publishing (Facebook/Instagram) — connect Meta account → publish poster to FB/IG | 🔴 broken | Phase 2 backend (OAuth connect/complete, AES-256-GCM token storage, connections list/delete) built + certified dry-run 13/13 (SOCIAL_MEDIA_INTEGRATION_PHASE2.md). But NO Flutter UI to connect a Meta account: no social screen, no '/social/connect' or 'social/connections' client wiring (grep empty). The publish dialog offers Facebook/Instagram checkboxes (achievement_promotion_screen.dart:23-24) but since no connection can ever be created from the app, FB/IG always record pending_connection (publisher_dispatch.ts:145-155). Journey unreachable client-side (separate from the owner-gated Meta App Review). |
| Publish feedback — user sees per-channel result (recipient count / WhatsApp ready / website posted) after publishing | 🟡 partial | Server returns rich publish_results per destination (publisher_dispatch.ts:120-158) and the model carries it (phase5_models.dart:449 publishResults), but no UI ever displays publishResults. WhatsApp dispatch produces a shareText deep-link payload server-side (publisher_dispatch.ts:124-127) but no client surface opens wa.me — preview _shareMetadata only tracks a metric + shows 'image generation deferred' (achievement_promotion_preview_screen.dart:55-66). |
| Live deployment of Marketing routes | 🟡 partial | GET /health → 200 live; /promotions and /growth/dashboard\|campaigns return UNAUTHORIZED (not 404) → deployed + auth-gated. Could NOT re-run authed live probes: token.txt expired 2026-06-26 08:17 UTC (exp 1782461822) and SSH alias 'akshara' refused (Permission denied publickey; owner control-socket not open this session). Relying on the three live certs for authed journeys. |
| Growth/Marketing Engine — campaigns (create → pause → activate → history) + inquiry capture → convert → CRM handoff | ✅ verified | B6 cert 13/13 live (docs/B6_MARKETING_ENGINE_CERTIFICATION.md). Client paths in evolution_api_paths.dart:24-31 match growth_router.ts:27-62 exactly (dashboard/funnel/campaigns/history/pause/PUT/inquiries/convert). RBAC: handlers gate manageGrowthPlatform/viewGrowthPlatform (growth_handlers.ts:18-20,74-76). UI gated by AksharaManageAction(Permission.manageGrowthPlatform) growth_platform_screen.dart:39-57,148-166,198-207. Marketing nav tile → /growth (admin_navigation_provider.dart:36). Tests green (growth_platform_widget_test, evolution contract parity). |
| Publisher backend — create publication → AI poster/captions → approve (principal-only) → publish to selected channels (apps/WhatsApp/website) with in-ERP fan-out | ✅ verified | HOLIDAY_PUBLISHER_PHASE1_CERTIFICATION.md 18/18 live. Router /promotions matches client phase5_remote_datasource.dart:224-296. Handlers RBAC-gated viewAchievementPromotion/manageAchievementPromotion/approveAchievementPromotion (achievement_promotion_handlers.ts:26-39), school-scope enforced, publish blocked before approval (409, line 233/265), no-destination (422, line 215), real fan-out via communication hub (publisher_dispatch.ts:73-103), audited. publisher_test 3/3 green. |

**Live probes:**
- `GET https://akshara.veloraunisexsalon.com/health` → 200 (edge live)
- `GET /promotions with bearer token` → UNAUTHORIZED (token expired exp 1782461822 = 2026-06-26 08:17 UTC) — but route resolves (not 404) so /promotions is deployed + auth-gated
- `GET /growth/dashboard and /growth/campaigns with bearer token` → UNAUTHORIZED (same expired token); routes resolve (not 404) = deployed + auth-gated
- `ssh akshara cat /opt/akshara/functions/api/index.ts` → BLOCKED — Permission denied (publickey); owner control-socket not open this session. Deployment of routes inferred from non-404 responses + B6/Phase1/Phase2 deploy records in certs.

**Issues:**

#### MARKE-1 · Promotion Center (multi-channel Publisher) is unreachable from the school UI — no nav entry
- **Module:** Marketing
- **User Journey:** Multi-channel Publisher end-to-end
- **Severity:** 🟠 High
- **Description:** Route /promotions is registered and route-guarded but nothing navigates to it: no admin module tile, no menu/nav entry, and zero .go/.push/goNamed/onTap references to RouteNames.achievementPromotion anywhere in lib/. This is the exact 'surface hidden' defect B6 fixed for the growth platform (G1), left unaddressed for the Publisher. The entire certified publisher lifecycle (create → AI poster/captions → approve → publish to apps/WhatsApp/website/FB/IG) cannot be started by a real school admin from the app.
- **Evidence:** lib/router/app_router.dart:678-681 (route registered); lib/router/route_guards.dart:59; grep for navigation to achievementPromotion → no callers; AdminModule.marketing → RouteNames.growthPlatform not /promotions (admin_navigation_provider.dart:36, entitlement_module_gate.dart:59).
- **Root Cause:** Phase 1 delivered the publisher backend + screen but never wired a navigation surface (tile/menu) to the Promotion Center; cert focused on backend journeys via API.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Surface-gap

#### MARKE-2 · No Flutter UI for the Holiday/Event Calendar — backend certified but unreachable
- **Module:** Marketing
- **User Journey:** Holiday/Event Calendar
- **Severity:** 🟠 High
- **Description:** /school-calendar CRUD is built, deployed and certified (18/18), but there is no client at all: no calendar-admin screen, no repository, no API-path constant. A principal/admin cannot create or view holidays/festivals/events from the app — only by direct API call. This breaks the documented workflow 'Principal/Admin creates Holiday/Event → publication'.
- **Evidence:** supabase/functions/_shared/school_calendar/* exists; grep for '/school-calendar'|SchoolCalendar in lib/ → empty; only lib/features/parent/attendance/attendance_calendar.dart exists. HOLIDAY_PUBLISHER_PHASE1_CERTIFICATION.md:30 self-flags the missing client screen.
- **Root Cause:** Phase 1 was reuse-first/backend-first; the calendar-admin Flutter screen was explicitly deferred and never built.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Surface-gap

#### MARKE-3 · No Flutter UI to connect a Meta (Facebook/Instagram) account — social publishing unreachable client-side
- **Module:** Marketing
- **User Journey:** Social publishing (Facebook/Instagram)
- **Severity:** 🟡 Medium
- **Description:** Phase 2 social-connection backend (OAuth start/complete, encrypted token storage, list/delete connections) is built + certified dry-run, but there is no client screen or wiring to start the connect flow. The publish dialog still offers FB/IG checkboxes, so selecting them always yields pending_connection — the school can never link an account from the app. This is a client gap distinct from the owner-gated Meta App Review steps.
- **Evidence:** supabase/functions/_shared/social/social_router.ts (connect/start, connect/complete, connections); grep for '/social/connect'|social/connections|socialConnection in lib/ → empty; FB/IG offered at achievement_promotion_screen.dart:23-24; pending_connection fallback publisher_dispatch.ts:145-155.
- **Root Cause:** Phase 2 shipped backend + dry-run cert; the connect-account management screen was not part of the client scope.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Surface-gap

#### MARKE-4 · Publisher workflow errors are silently swallowed — generate/approve/publish failures show nothing
- **Module:** Marketing
- **User Journey:** Publisher backend / Multi-channel Publisher
- **Severity:** 🟡 Medium
- **Description:** _advanceWorkflow awaits generateAssets/approvePromotion/publishPromotion with no try/catch and no error surface; on failure (e.g. publish-before-approve 409, no-destination 422, network/500) the screen just invalidates the list and the user sees no message. The publish destination dialog also returns and the workflow proceeds with no feedback. Only the list-load path uses AksharaErrorState.
- **Evidence:** lib/features/achievement_promotion/achievement_promotion_screen.dart:62-82 (_advanceWorkflow no try/catch), :142-148 (onTap/onLongPress only invalidate, no error handling). Contrast list error handling at :155-158.
- **Root Cause:** Mutations are fire-and-forget; no ref.listen/try-catch to map failures to a snackbar/error state.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### MARKE-5 · Growth campaign/inquiry mutation errors never surface to the user
- **Module:** Marketing
- **User Journey:** Growth/Marketing Engine
- **Severity:** 🟡 Medium
- **Description:** create-campaign, create-inquiry, pause, activate(update) and convert all run through AsyncNotifier.guard which captures errors into provider state, but growth_platform_screen.dart never ref.listen()s any of these notifiers. The create dialogs call Navigator.pop unconditionally after await execute(), so a failed create (e.g. backend 422 'name and channel required' for an empty name — there is no client-side validation) closes the dialog with no error and no new row, looking like a silent no-op. Pause/Convert buttons likewise give no feedback on failure.
- **Evidence:** lib/features/evolution/growth_platform_screen.dart: no ref.listen (grep empty); create-campaign pop at :305-307, create-inquiry pop at :360-362, pause/convert at :154-163/:202-204; notifiers guard+rethrow but only invalidate on success (evolution_mutations_provider.dart execute methods); backend validation growth_handlers.ts:88-89 (422).
- **Root Cause:** Screen relies on read-invalidation for success and never wires the mutation states to error UI; dialogs lack input validation.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### MARKE-6 · publishResults / WhatsApp deep-link generated server-side but never surfaced or actioned in the app
- **Module:** Marketing
- **User Journey:** Publish feedback
- **Severity:** ⚪ Low
- **Description:** On publish the server returns per-channel publishResults (in-app recipientCount, WhatsApp shareText deep-link payload, website postId, FB/IG status) and the model maps publishResults, but no screen displays it. The WhatsApp 'ready' shareText is never used to open wa.me from the promotion flow — the preview share button only tracks a 'shares' metric and shows 'image generation deferred'. So the school gets no confirmation of who/where a publication reached, and the WhatsApp channel is effectively inert in the UI.
- **Evidence:** publisher_dispatch.ts:120-158 (results incl. whatsapp shareText); phase5_models.dart:449 publishResults mapped but unused; achievement_promotion_preview_screen.dart:55-66 (_shareMetadata only tracks metric). No wa.me in lib/features/achievement_promotion (grep empty).
- **Root Cause:** Publish result payload and WhatsApp deep-link were implemented server-side ahead of the consuming UI.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### MARKE-7 · Poster image is never rendered — previewUrl/downloadUrl always null (FB/IG photo posts text-only)
- **Module:** Marketing
- **User Journey:** Publisher backend / Social publishing
- **Severity:** ⚪ Low
- **Description:** promotion_asset_service emits poster metadata with previewUrl:null/downloadUrl:null (honest AI-4 flag), the preview screen shows a placeholder box ('Image preview … ready'), and StubPromotionImageGenerator.generatePoster returns null. So dispatchPublish passes imageUrl:null to Meta, meaning FB/IG photo posts cannot include the poster (caption/text only). Matches Phase 2 cert owner-gated step #6 (image hosting/render is the remaining piece). Not a regression, but the 'AI poster' is captions-only end-to-end.
- **Evidence:** promotion_asset_service.ts:49-52 (previewUrl/downloadUrl null + AI-4 comment); achievement_promotion_preview_screen.dart:137-141,155-164 (placeholder + stub returns null); publisher_dispatch.ts:148-149 (imageUrl from null previewUrl). SOCIAL_MEDIA_INTEGRATION_PHASE2.md:69-72.
- **Root Cause:** Poster image generation/hosting hook is deferred (documented); only captions are produced.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** AI

#### MARKE-8 · getPromotion client helper throws StateError when id not in list (no orElse)
- **Module:** Marketing
- **User Journey:** Publisher backend
- **Severity:** ⚪ Low
- **Description:** ApiAchievementPromotionRepository.getPromotion fetches the full list and does firstWhere((p)=>p.id==id) with no orElse, throwing an unmapped StateError if the promotion is missing (e.g. deleted/scope change) instead of a mapped ApiFailure. Low impact (getPromotion is not on the main screen path) but it would surface as a raw error if used.
- **Evidence:** lib/core/repositories/api/phase5/api_phase5_repositories.dart:352-359 (listPromotions(...).firstWhere(... no orElse)).
- **Root Cause:** Convenience implementation re-lists instead of a dedicated GET-by-id; missing not-found handling.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### MARKE-9 · Publisher / calendar / social routes are RBAC-only, not entitlement-gated (B2 inconsistency vs growth)
- **Module:** Marketing
- **User Journey:** Live deployment of Marketing routes
- **Severity:** ⚪ Low
- **Description:** routeGrowth is wrapped withEntitlement('/growth','module.marketing') (index.ts:121), but routePromotion (104), routeSchoolCalendar (105) and routeSocial (106) have no entitlement wrapper — they are gated by RBAC only. If the Marketing module is meant to be plan-gated, the Publisher/calendar/social surfaces are reachable on plans that lack module.marketing. May be intentional (publisher = core comms), but it is an inconsistency worth an explicit decision.
- **Evidence:** supabase/functions/api/index.ts:104-106 (no withEntitlement) vs :121 (routeGrowth gated). B6 cert G4 established module.marketing gating for marketing surfaces.
- **Root Cause:** Publisher/calendar/social were added as separate route prefixes and not folded into the module.marketing entitlement decision.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** RBAC

**Strengths (working well):**
- Growth/Marketing engine is fully wired and certified: client paths (evolution_api_paths.dart:24-31) match growth_router.ts:27-62 one-to-one; create/pause/activate/history/convert all real DB writes, RBAC-gated, audited; B6 live 13/13 incl. CRM handoff with source attribution.
- Publisher backend is robust: school-scope enforced, principal-only approval, publish blocked before approval (409) and with no destination (422), real multi-channel fan-out reusing the communication hub with PERF-1 recipient cap (publisher_dispatch.ts:19,89), full mutation auditing; Phase 1 live 18/18.
- Social Phase 2 backend is security-correct: OAuth tokens AES-256-GCM encrypted at rest, refused without SOCIAL_TOKEN_ENC_KEY, never exposed in list; dry-run mode makes it certifiable pre-App-Review (13/13).
- Growth screen has complete states (loading/empty/error with retry) and per-button RBAC via AksharaManageAction(Permission.manageGrowthPlatform); full create-campaign form (name/channel/budget/audience/schedule date).
- Routes confirmed deployed live (GET /health 200; /promotions and /growth/* return UNAUTHORIZED not 404 = wired + auth-gated). Module tests green in gate logs (publisher_test 3/3, growth widget + contract parity).

---

### AI Features (Copilot, Intelligence, Predictions, AI School Builder, Parent Insights)
**Code:** `AF`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Traced every screen/provider/repository→route→handler→RBAC/entitlement for copilot, predictions, intelligence (+8 sub-features), AI school builder, and parent insights. Mock-vs-live verified per module via the dart-define flags in config/live_release.json. Deployment confirmed via unauthenticated live probes (UNAUTHORIZED = route exists & deployed) since the read token in gates/token.txt is EXPIRED (every authenticated GET incl. /auth/me returned UNAUTHORIZED) and the SSH control socket to akshara was NOT open this session (Permission denied publickey) — so no authenticated live-data probes and no `ssh cat` of the deployed index.ts were possible; relied on cert docs (B9/B7/B3/batch8) + repo source + unauth probes instead. Cert-covered journeys cited, not re-litigated. Did not modify or write anything.

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Advanced AI Predictions: leader opens hub → fee-default / admission-conversion / student-risk feeds with AI narrative | 🔴 broken | Backend B9 CERTIFIED live (B9_ADVANCED_AI_PREDICTIONS_CERTIFICATION.md, 11/11; live probe GET /predictions/fee-default → UNAUTHORIZED, route deployed & entitlement-gated per index.ts:127). Client paths/screen/states all correct (predictions_screen.dart full loading/error/empty + dual entitlement gate). BUT PREDICTIONS_API_ENABLED is ABSENT from config/live_release.json (grep -c = 0) — the canonical release config consumed by `flutter build --dart-define-from-file`. predictionsApiEnabledProvider (repository_config.dart:213) defaults false, so predictionsRepositoryProvider (repository_providers.dart:372-379) returns MockPredictionsRepository in the release build, showing hardcoded fake students (Aarav Shah, Diya Menon — mock_predictions_repository.dart:18-46) to real leaders. Only scripts/run_live.sh (dev runner) sets the flag. |
| Copilot: open assistant → create session → send message → AI reply persisted + audited | 🟡 partial | Client paths in copilot_api_paths.dart:2-6 match server routes in copilot_router.ts:19-44 exactly (verified deployed: live probe GET /copilot/sessions → UNAUTHORIZED, route exists). Server copilot_handlers.ts persists user+assistant messages, audits aiCopilotQuery/Response, RBAC viewAiCopilot/runAiCopilot enforced. AI via copilot_llm_client.ts:40-74 with safe stub fallback when no key. GAP: send-message error not surfaced to user (copilot_screen.dart:202-227 only reads sendState.isLoading, never .hasError) AND server returns 500 on Claude transport error after persisting the user message (copilot_handlers.ts:267 persists user msg, then line 277 generateCopilotResponse can throw uncaught → catch at 328 returns 500). Cited clean by FINAL_COMPLETION_AUDIT.md:199 (batch8). |
| AI School Builder: founder enters brief → AI pre-fill proposal applied to onboarding wizard (non-destructive) | ✅ verified | B7_AI_SCHOOL_BUILDER_CERTIFICATION.md (17/17). Client path startup_onboarding_api_paths.dart:4 = '/onboarding/startup/ai-prefill' matches server (index.ts:113 withEntitlement feature.ai_school_builder). Live probe POST /onboarding/startup/ai-prefill → UNAUTHORIZED (deployed). Flow has full error handling: unified_onboarding_flow_screen.dart:382-398 try/catch + SnackBar, warnings + rationale surfaced. ONBOARDING_API_ENABLED=true in live_release.json:34. |
| Parent Insights: per-child AI insight surfaced to parent (entitlement-gated) | ✅ verified | B3 cert (FINAL_COMPLETION_AUDIT.md:122,199). Client paths evolution_api_paths.dart:17-19 (/parent-insights/generate, /students/{id}, /language-preference) match server parent_insights_router.ts:21-31. index.ts:118 withEntitlement feature.parent_insights. EVOLUTION_API_ENABLED=true in live_release.json:42. Live probe GET /parent-insights/overview → UNAUTHORIZED (deployed). |
| Student-success / exam / teacher-effectiveness / at-risk intelligence dashboards | ✅ verified | All sub-feature providers route through intelligenceRepositoryProvider (exam_intelligence_provider.dart:20, student_success_provider.dart:19, teacher_effectiveness_provider.dart:14) gated on INTELLIGENCE_API_ENABLED=true (live_release.json:40). Server routes deployed (intelligence_router.ts:53-149; live probe GET /intelligence/risk/students → UNAUTHORIZED). Client-composed providers (at_risk, operations, unified_recommendations, promotion_readiness) derive from live studentSuccessPredictions/attendance/fee providers, no standalone mocks. |
| AI safe-fallback (no key / refusal / transport error) → deterministic baseline, never fabricates numbers | ✅ verified | anthropic_client.ts callers gate on aiApiKey(); predictions_ai.ts:40,61-66 returns deterministic baseline on no-key/refusal/error; copilot_llm_client.ts:43-53 stub fallback. resolveAiConfig (ai_settings.ts:60-106) DB-first with SAVEPOINT rollback, never poisons transaction. Model id claude-opus-4-8 correct (anthropic_client.ts:14). |

**Live probes:**
- `GET /health` → 200 {"status":"ok","service":"akshara-api"}
- `GET /auth/me with gates/token.txt` → UNAUTHORIZED 'Invalid access token' — token expired; all authenticated probes blocked this session
- `GET /predictions/fee-default (no auth)` → UNAUTHORIZED 'Missing bearer token' — route deployed & auth-gated (confirms B9 live)
- `POST /onboarding/startup/ai-prefill (no auth)` → UNAUTHORIZED 'Missing bearer token' — route deployed (B7 live)
- `GET /parent-insights/overview (no auth)` → UNAUTHORIZED 'Missing bearer token' — route deployed (B3 live)
- `GET /intelligence/risk/students (no auth)` → UNAUTHORIZED 'Missing bearer token' — route deployed; /intelligence/exam etc return NOT_FOUND as expected (sub-paths are /intelligence/exam/analytics etc.)
- `GET /copilot/sessions, /copilot/assistants, /copilot/suggestions (no auth)` → UNAUTHORIZED 'Missing bearer token' — all deployed; /copilot/ask correctly NOT_FOUND (real path is /copilot/sessions/{id}/messages)
- `ssh akshara cat /opt/akshara/functions/api/index.ts` → FAILED — Permission denied (publickey); control socket not open this session, could not diff deployed router vs local

**Issues:**

#### AF-1 · Predictions screen serves MOCK data in production release build (PREDICTIONS_API_ENABLED missing from live_release.json)
- **Module:** AI Features
- **User Journey:** Advanced AI Predictions: leader opens AI Predictions
- **Severity:** 🟠 High
- **Description:** The canonical release config config/live_release.json (consumed by `flutter build --release --dart-define-from-file=config/live_release.json`) enables INTELLIGENCE/AI_COPILOT/EVOLUTION but does NOT set PREDICTIONS_API_ENABLED. predictionsApiEnabledProvider defaults to false, so predictionsRepositoryProvider selects MockPredictionsRepository even in the live release. A real school leader opening the AI Predictions screen (routed /intelligence/predictions, app_router.dart:558-564, reachable via the management-hub launch tile intelligence_hub_screen.dart:480-487) sees hardcoded fake students with invented fee-default/conversion/risk scores, while the certified-live B9 backend goes unused. Undermines the flagship Enterprise AI-predictions value prop and could drive wrong leadership decisions.
- **Evidence:** config/live_release.json (grep -c PREDICTIONS_API_ENABLED = 0); repository_config.dart:213-217 default false; repository_providers.dart:372-379 falls to MockPredictionsRepository; mock_predictions_repository.dart:18-46 hardcoded 'Aarav Shah'/'Diya Menon'; flag only set in scripts/run_live.sh:48 (dev runner). Backend IS deployed (live probe GET /predictions/fee-default → UNAUTHORIZED, not NOT_FOUND) and certified (B9_ADVANCED_AI_PREDICTIONS_CERTIFICATION.md 11/11).
- **Root Cause:** Release config drift: B9 added the backend + flag plumbing but PREDICTIONS_API_ENABLED was never added to the canonical config/live_release.json (only to the dev run_live.sh).
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Live-deploy-drift

#### AF-2 · Copilot send-message failure is silent to the user (no error state rendered)
- **Module:** AI Features
- **User Journey:** Copilot: send message
- **Severity:** 🟡 Medium
- **Description:** When sending a copilot message fails (network error, server 500, RBAC/entitlement change), the error is captured into copilotSendMessageProvider via AsyncValue.guard but never surfaced. The screen only consumes sendState.isLoading (progress bar + disabling the send button). The input text was already cleared on submit, so the user's message disappears with no assistant reply and no error/SnackBar — they cannot tell whether it sent. Every other AI surface (predictions screen, AI school builder) renders error states.
- **Evidence:** copilot_screen.dart:46 clears input before send; :47 await send(); :76 sendState read; :202 & :227 only use sendState.isLoading — no sendState.hasError / SnackBar / AksharaErrorState branch. copilot_provider.dart:77-122 guards the error into state but the screen ignores it.
- **Root Cause:** Screen wires only the loading facet of the AsyncNotifier; the error facet was never rendered.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### AF-3 · Copilot server returns 500 and leaves a dangling user message when Claude transport throws
- **Module:** AI Features
- **User Journey:** Copilot: send message → AI reply
- **Severity:** 🟡 Medium
- **Description:** handleSendMessage persists the user's message (appendCopilotMessage, line 267) BEFORE calling generateCopilotResponse. If the Claude/provider HTTP call throws a transport error (callClaude in anthropic_client.ts throws on non-OK / network), generateCopilotResponse does NOT catch it (copilot_llm_client.ts:60-67 has no try/catch, unlike predictions_ai.ts:52-66 which falls back). It propagates to the handler's catch (line 328) → 500 with the raw error. Net effect: the session now has an orphaned user message with no assistant reply, the whole withTenantContext write is rolled back only partially depending on transaction scope, and the copilot lacks the safe-fallback resilience the predictions/parent-insights surfaces have. (No-key path is safe — stub; only the with-key transport-error path is affected.)
- **Evidence:** copilot_handlers.ts:267 (persist user msg) then :277 generateCopilotResponse (can throw) caught only at :328 → errorEnvelope INTERNAL_ERROR 500. copilot_llm_client.ts:60-73 callClaude not wrapped in try/catch (contrast predictions_ai.ts:52-66 / parent-insights pattern which catch→baseline).
- **Root Cause:** generateCopilotResponse omits the deterministic-fallback try/catch that the other AI callers use; persistence happens before the (fallible) generation.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** AI

#### AF-4 · Copilot session auto-rename is dead code — sessions never renamed to first question
- **Module:** AI Features
- **User Journey:** Copilot: create session → first message
- **Severity:** ⚪ Low
- **Description:** handleSendMessage auto-renames a session to the first user message only when session.title === 'New conversation' (line 303). But createSession defaults the title to the assistant's label (definition.label, line 160) when the client omits title, and the Flutter client never sends a title (copilot_provider.dart:129-132 createSession with no title; datasource only includes title if non-null, copilot_remote_datasource.dart:62). So the condition is never true and every session in the history list shows the generic assistant label (e.g. 'Finance Copilot') instead of the user's question — degraded session-list usability.
- **Evidence:** copilot_handlers.ts:160 (title fallback = definition.label) vs :303 (rename gate checks 'New conversation'); copilot_provider.dart:129-132 createSession passes no title; copilot_remote_datasource.dart:60-63 omits title when null.
- **Root Cause:** The default-title string and the auto-rename sentinel diverged; no client ever produces 'New conversation'.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

**Strengths (working well):**
- Shared AI client (anthropic_client.ts) is provider-agnostic (Anthropic-direct + OpenRouter), never fabricates, throws on transport so callers can fall back; correct model id claude-opus-4-8; temperature deliberately omitted for Opus 4.x.
- resolveAiConfig is DB-first with a SAVEPOINT that rolls back on failure without poisoning the surrounding transaction (ai_settings.ts:60-106) — robust.
- Predictions backend (B9) is deterministic-first with numbers locked; AI narrative is strictly additive and falls back to baseline on any failure (predictions_ai.ts). Server enforces per-domain RBAC + school scope + feature.ai_predictions entitlement; client mirrors the gate (defense-in-depth).
- Client↔server route strings match exactly for copilot, predictions, parent-insights, intelligence, and ai-prefill (verified file:line on both sides + unauthenticated live probes returning UNAUTHORIZED, proving deployment).
- HybridPredictions/Copilot only fall to mock on ApiNotConnectedException (flag off), NOT on real API errors — so live builds never silently fabricate when the API is reachable but erroring.
- Intelligence sub-features (exam, student-success, teacher-effectiveness, at-risk, promotion, operations, unified recommendations) all route through the live intelligenceRepositoryProvider or derive from it client-side — no orphan mocks.
- Predictions and AI-school-builder screens have complete loading/error/empty states and surface failures to the user.

---

### Organization Builder (B10, P3) — chains/trusts no-touch org setup (packs → interview → preview → provision)
**Code:** `OB`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Traced all 7 endpoints end-to-end (screen → provider → repository → datasource → router → handler → repository SQL → RLS/permission) and confirmed path-string parity client vs deployed router, mock-vs-live selection, RBAC (chain + permission + server entitlement), and AI fallback. Read all 7 Flutter module files, all 5 backend files, migration RLS/permissions/seed, route guards, nav provider, and ChainScope. Live GET probes attempted but the provided token.txt is EXPIRED (exp 1782461822 < now 1782469156) and school-scope (Org Builder needs org scope), so live calls returned 401/would-403; relied on B10 cert §5 (live 17/17 with edge-minted org JWT) as authoritative live proof, plus confirmed routes are reachable (auth error, not NOT_FOUND). SSH control-master socket was closed this session so deployed-source diff could not be re-pulled; api/index.ts:132 registration confirmed in repo and matches cert deploy claim. The onboarding/ dir in scope is a separate module (unified onboarding/bulk import/AI school builder) with its own backend, not the Org Builder provisioning path — not deep-audited here. Headline finding: provisioning is a documented stub (no real tenant creation) presented to the operator as success.

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Generate configuration preview | 🟡 partial | Preview screen watches configPreviewProvider → POST /platform/org-builder/preview → handlePreview (handlers.ts:215) in the write() scaffold gating manageOrganizationBuilder. But configPreviewProvider (providers.dart:32) does NOT call assertManageOrganizationBuilder, and the preview ROUTE only guards viewOrganizationBuilder (route_guards.dart:102). A view-only org user can navigate to the preview screen but the POST 403s — surfaced as an error state, not blocked up front (UX inconsistency). Happy path verified live (cert §5: salon roles + universal-employee module resolved). |
| Approve & provision organization | 🟡 partial | Preview screen 'Approve & provision' → startProvisioningProvider (asserts manage) → POST /platform/org-builder/provision → handleProvision (handlers.ts:227) → provision() inserts a job with status='completed', 6 completed steps, flips draft to provisioned, audits orgBuilder.organization.provisioned (repository.ts:476). HOWEVER provisioning does NOT create real organizations/schools/roles rows — it only resolves+persists config and records step outcomes (cert §6 explicitly: 'wiring into live tenant creation ... is a deliberate later phase'). UI shows 'Organization provisioned successfully' though no tenant exists. Cert §5 live 17/17 for the persisted-job flow. |
| Browse vertical packs (catalog) | ✅ verified | Hub watches verticalPacksProvider → ApiOrganizationBuilderRepository.listVerticalPacks → datasource GET /platform/org-builder/packs (api_paths.dart:2) → router handlePacks (router.ts:51) → listPacks reads org_builder_packs from DB (repository.ts:216). 4 packs seeded in migration 20260727. Cert B10 §5 live 17/17. Live probe: route reachable (returns auth error not NOT_FOUND, token expired so 401). |
| Start + advance 7-step interview with AI recommendation | ✅ verified | Interview screen _continue → saveInterviewStepProvider (asserts manageOrganizationBuilder client-side, mutations_provider.dart:14) → POST /platform/org-builder/interview/drafts/:id/step → handleSaveStep (handlers.ts:164) gates manage+orgScope, calls recommendForStep (real Claude + deterministic fallback, ai.ts:99), persists via saveStep, advances step, audits orgBuilder.interview.step_saved. Cert §5: real 137-char AI rec proven live. Contract+screen tests pass (deno 3/3, flutter hub/interview tests green). |
| Poll provisioning job status | ✅ verified | Provisioning screen polls provisioningJobProvider every 500ms (organization_provisioning_screen.dart:34) → GET /platform/provisioning-jobs/:id → handleProvisioningJob (handlers.ts:100) validates UUID, gates view+orgScope, getJob reads org_builder_provisioning_jobs. Timer cancels on completed. Since provision returns completed synchronously, first poll already shows done. |
| RBAC / chain / entitlement gating | ✅ verified | Chain-gated: ChainScope.chainOnlyModules includes organizationBuilder (chain_scope.dart:39); nav filter hides it for non-chain orgs (admin_navigation_provider.dart:217) and route_guards.dart:412 blocks deep-links for non-chain orgs. Server: all 7 routes entitlement-gated feature.organization_builder inside the router (router.ts:45-48) when ENTITLEMENT_ENFORCEMENT=true; org-scope RLS on both stateful tables (migration lines 168-182); permissions granted to org/group leadership + superAdmin only. Cert §5: 402 for Professional pilot, 403 for school-scope token, 401 unauth — all proven live. |

**Live probes:**
- `GET /health (no auth)` → 200 {"data":{"status":"ok","service":"akshara-api"}} — API live.
- `GET /platform/org-builder/packs with token.txt` → 401 UNAUTHORIZED 'Invalid access token' — token.txt is EXPIRED (exp 1782461822, now 1782469156) and school-scope. Route reachable (auth ran before routing); not NOT_FOUND, so endpoint is deployed.
- `GET /platform/org-builder/interview/drafts with token.txt` → 401 UNAUTHORIZED (expired token). Endpoint deployed and auth-gated.
- `GET /platform/provisioning-jobs/not-a-uuid with token.txt` → 401 UNAUTHORIZED (expired token) — auth precedes the UUID/NOT_FOUND check, consistent with handler order (handlers.ts:105 auth then :109 UUID).

**Issues:**

#### OB-1 · Provisioning does not create a real organization/school — UI claims success
- **Module:** Organization Builder
- **User Journey:** Approve & provision organization
- **Severity:** 🟠 High
- **Description:** handleProvision/provision() resolves and persists the config and records 6 'completed' steps, then the UI shows 'Organization provisioned successfully' (organization_provisioning_screen.dart:88). But no real organizations/schools/roles/permissions rows are created — it is config resolution + a persisted job only. A chain owner who runs this believes a new branch/vertical now exists and is operable; it does not. This is the headline value proposition of the module (no-touch org standup) and it stops at a simulated success.
- **Evidence:** repository.ts:476-535 provision() only INSERTs into org_builder_provisioning_jobs (status hardcoded 'completed') and UPDATEs the draft to 'provisioned'; the 6 steps (step_org 'Create organization', step_branch 'Create branch', step_roles, step_permissions, step_seeds, step_golive) are all `status:'completed'` with no DB writes to tenant tables. Cert B10 §6 confirms: 'wiring it into live tenant creation (creating real organizations/schools rows for a new vertical) is a deliberate later phase ... not silently skipped.'
- **Root Cause:** P3 'backend-first' scoping decision: the provisioning step deliberately stops at config resolution and does not yet call real tenant-creation. Documented in cert, but the UI presents it as a completed live provisioning with no caveat to the operator.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### OB-2 · Preview screen reachable by view-only org users but the underlying POST requires manage (403)
- **Module:** Organization Builder
- **User Journey:** Generate configuration preview
- **Severity:** ⚪ Low
- **Description:** The /organization-builder/preview route is guarded only by Permission.viewOrganizationBuilder (route_guards.dart:102), and configPreviewProvider does not assert manage. But generating the preview is a POST that the server gates on manageOrganizationBuilder (handlePreview via write() scaffold). A view-only org admin can open the preview screen and immediately get a 403 error state instead of being cleanly told they lack permission, or having the screen gated to manage up front. Same class of inconsistency applies to the interview screen (view-guarded route, but every Continue is a manage POST).
- **Evidence:** route_guards.dart:101-102 maps both interview and preview to viewOrganizationBuilder; handlers.ts:215 handlePreview uses write() → gate(claims,'manageOrganizationBuilder') (handlers.ts:124-133); providers.dart:32 configPreviewProvider calls generatePreview (POST) with no assertManageOrganizationBuilder (that assert lives only in mutations_provider.dart, not in the read-style preview provider).
- **Root Cause:** Route-guard permission (view) is coarser than the action permission (manage) for the preview/interview write paths; the screen is read-shaped but performs writes.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** RBAC

#### OB-3 · Org Builder nav tile shows for non-Enterprise chain orgs, then API 402s
- **Module:** Organization Builder
- **User Journey:** RBAC / chain / entitlement gating
- **Severity:** ⚪ Low
- **Description:** The feature.organization_builder entitlement (Enterprise) is enforced ONLY server-side (router.ts). The client gates the nav tile and routes on chain-org + viewOrganizationBuilder permission only — there is no client-side entitlement check for Org Builder (unlike Marketing, which has a dedicated modulePlanLockedProvider branch at admin_navigation_provider.dart:225). A chain org on a non-Enterprise plan with the view permission would see the 'Org Builder' tile, open the hub, and only discover it's gated when the packs API returns 402. Cert calls this 'Enterprise-entitlement-gated at runtime' but that runtime gate is purely the backend.
- **Evidence:** admin_navigation_provider.dart:205-247 nav filter handles chain-only (line 217) + permission (220) + capability/plan for the 8-flag model, with a special entitlement branch ONLY for AdminModule.marketing (225). No org-builder entitlement branch; grep for feature.organization_builder in lib/ returns nothing. Server gate: router.ts:45-48 enforceEntitlement(feature.organization_builder).
- **Root Cause:** Org Builder's Enterprise entitlement is not modelled in the client nav/lock layer (only chain + permission are), so the lock-vs-hide UX the rest of the platform has for entitlement modules is absent here.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** RBAC

#### OB-4 · Provisioning poller never stops on a failed job (latent)
- **Module:** Organization Builder
- **User Journey:** Poll provisioning job status
- **Severity:** ⚪ Low
- **Description:** The 500ms poll timer is cancelled only when job.status == completed (organization_provisioning_screen.dart:62). If a job were ever status 'failed', the screen would poll GET /platform/provisioning-jobs/:id every 500ms indefinitely (battery/network drain) and never surface a terminal failed state distinctly. Currently latent because provision() always writes status='completed' and has no failure path — but the moment real tenant-creation is wired in (the High issue above), failures become possible and this poller leaks.
- **Evidence:** organization_provisioning_screen.dart:61-63 cancels timer only on completed; ProvisioningJobStatus includes failed (models). provision() hardcodes 'completed' (repository.ts:515) so no failed job exists today — pairs with the provisioning High issue.
- **Root Cause:** Poll-stop condition checks only the success terminal state, not all terminal states (failed); acceptable today only because failure is impossible in the current stub provisioning.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

**Strengths (working well):**
- Client↔server path strings match exactly across all 7 endpoints: api_paths.dart (packs/interview/drafts/:id/step, preview, provision, provisioning-jobs/:id) == router.ts regex/literals == cert §4 contract table. No path drift.
- No mock-in-live-build risk: repository selected by isModuleApiEnabled(organizationBuilderApiEnabledProvider); ORGANIZATION_BUILDER_API_ENABLED=true in config/live_release.json:46; mock repo (mock_organization_builder_repository.dart) only used when flag off. Live edge registers routeOrganizationBuilder in api/index.ts:132.
- Real persistence + audit: drafts, recommendations (JSONB), and provisioning jobs all persisted to dedicated tables with org-scope RLS (organization_id = app_current_tenant_id(), migration 168-182); both writes audited (orgBuilder.interview.step_saved, orgBuilder.organization.provisioned).
- AI is real with a safe deterministic fallback: recommendForStep uses Claude when keyed, else baselineRecommendation; any refusal/bad-JSON/transport error returns the baseline; PII-locked system prompt (ai.ts:14-25). Stable per-step id prevents recommendation duplication on re-save (handlers.ts:197).
- Error/loading/empty states are consistent and present on every screen: hub uses AksharaLoadingState + AksharaErrorState.fromFailure with onRetry for both packs and drafts and an explicit 'No interview drafts yet.' empty state; preview and provisioning screens use the same pattern; interview shows inline spinners on Continue/Generate.
- Two disjoint prefixes correctly share one entitlement gate inside the router (router.ts:31-48), closing the gap a single withEntitlement wrapper would leave on the provisioning-jobs GET — a real correctness detail handled.
- Gates green for this module: deno repository_test 3/3, flutter contract + hub + interview screen tests all passing (gate logs); Cert B10 live 17/17 with org-scope JWT, real AI, RBAC denials (402/403/401) all proven.

---

### Dynamic Widgets (widget_platform)
**Code:** `DW`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Covered all 3 Flutter screens (registry/runtime/layout-editor), models, providers, mutations provider; full wire trace screen→provider→hybrid/api repo→remote datasource→EvolutionApiPaths→router→handlers→RBAC→DB; backend catalog, layout handlers, data service; RBAC inventory + route guards; cert B11. Live authenticated GET probes were blocked by an expired bearer token (exp 2026-06-26 08:17 UTC) and the SSH control socket was not open this session, so deployment was confirmed via unauthenticated 401-vs-404 status codes plus the B11 live cert (16/16) rather than fresh authenticated reads. Did not re-litigate the 16/16 journeys the cert already proves. No writes performed (read-only)."

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Drill-down navigation from runtime tiles to module screens | 🟡 partial | operations.school_health->/operations/hub, student_risk->/intelligence/student-success, fee_collection->/finance/dashboard, homework->/homework-intelligence all resolve. BUT attendance_risk drillDown '/sis/attendance' is NOT a registered route (route_names.dart has /sis,/sis/dashboard,/sis/students... no /sis/attendance) — dead navigation. |
| Registry screen: view widget catalog + data-source bindings + layout versions | ✅ verified | dynamic_widget_registry_screen.dart watches dynamicWidgetRegistryProvider (/widgets/registry), widgetDataSourcesProvider (/widgets/data-sources), widgetLayoutVersionsProvider (/widgets/layouts/versions). Live unauth probe returns 401 (deployed) for data-sources/versions. flutter_test.log: 'renders widget catalog and data sources' passes. Cert B11 line 82: data-sources registry 6 namespaced + versions verified live 16/16. |
| Runtime dashboard: resolve role layout + live KPI/alert tiles, RBAC-filtered | ✅ verified | dynamic_widget_runtime_screen.dart:19-21 watches roleDashboardLayoutProvider + dynamicWidgetLiveDataProvider; filterWidgetsByRbac (providers.dart:80) hides unauthorized widgets; tiles read value/summary/alerts/permissionDenied. Mapper toRoleDashboardLayout + toWidgetDataMap correct (evolution_mapper.dart:66,260). flutter_test.log: 'renders RBAC-filtered principal widgets with live data' passes. |
| Layout editor: select role/pack → toggle visibility/reorder/resize → Save tenant override (version bump) | ✅ verified | dynamic_widget_layout_editor_screen.dart _saveLayout calls saveRoleDashboardLayoutProvider → ApiEvolutionRepository.saveRoleDashboardLayout → PUT /widgets/layouts/:role (NO mock fallback; real wire). Backend widget_layout_handlers.ts:154 handleSaveRoleLayout requires manageDynamicWidgets+school scope, UPDATE-first/INSERT-fallback, version+1, audited. Cert B11: override save v1->2 isTenantOverride=true persists durably (live 16/16). |
| Layout editor: Reset to pack default | ✅ verified | _resetLayout → resetLayoutToPackDefaultProvider → POST /widgets/layouts/:role/reset. handleResetRoleLayout:215 rewrites row to pack default (isTenantOverride=false) since erp_tenant has no DELETE; audited. Cert B11: reset -> pack default, GET back to default verified live. |
| RBAC enforcement: read needs view, save/reset need manage, school-scope required, unauth 401 | ✅ verified | All 5 handlers gate requirePermission(view\|manage)+requireSchoolOperationalScope (widget_layout_handlers.ts:84,94,134,161,222). rbac_route_inventory.ts:67-71 lists all 5 routes w/ correct perms+scope. Route guards (route_guards.dart:62-64) gate all 3 screens by viewDynamicWidgets; editor mutation buttons gated by canManageDynamicWidgets. Live unauth -> 401 on all rich routes. Cert B11: RBAC 403s + org-scope 403 + unauth 401 all verified live. |
| Live deployment of rich B11 endpoints on VPS | ✅ verified | Live unauth GET /widgets/data-sources, /widgets/layouts/versions, /widgets/layouts/principal all return 401 (UNAUTHORIZED 'Missing bearer token'), not 404 — router reaches auth, proving routes deployed. index.ts:52,115 wires routeWidgetPlatform (RBAC-only, no entitlement wrapper). SSH control socket not open this session and bearer token expired (exp 2026-06-26 08:17, now ~10:19) so authenticated GET probes returned UNAUTHORIZED; relied on unauth status codes + cert. |

**Live probes:**
- `GET /health (Bearer expired token)` → 200 {"status":"ok","service":"akshara-api"}
- `GET /widgets/data-sources (unauth)` → 401 UNAUTHORIZED 'Missing bearer token' — route deployed (not 404)
- `GET /widgets/layouts/versions (unauth)` → 401 — route deployed
- `GET /widgets/layouts/principal (unauth)` → 401 — route deployed
- `GET /widgets/data-sources (Bearer token.txt)` → 401 'Invalid access token' — token expired (exp 2026-06-26 08:17 UTC; clock ~10:19), authenticated reads not possible this session
- `deno test widget_pack_catalog_test.ts` → 5 passed / 0 failed (re-run this session)

**Issues:**

#### DW-1 · Attendance Risk tile drill-down points to a non-existent route (/sis/attendance)
- **Module:** Dynamic Widgets
- **User Journey:** Principal/schoolAdmin opens Dynamic Dashboard runtime → taps the 'Attendance Risk' tile → expects the attendance screen → go_router resolves an undefined path
- **Severity:** 🟡 Medium
- **Description:** The default school dashboard's attendance_risk widget has drillDown '/sis/attendance', but no such route exists. Defined SIS routes are /sis/dashboard, /sis/students, /sis/academic-assignment, /sis/promotion, etc. Tapping the tile calls context.push('/sis/attendance') (runtime screen line 84-86) which hits the router not-found/error path. This is shipped in BOTH the backend pack catalog and the client mock, so it breaks identically in live and fallback modes.
- **Evidence:** supabase/functions/_shared/widget_platform/widget_pack_catalog.ts:189 drillDown '/sis/attendance'; lib/core/repositories/mock/mock_evolution_repository.dart:645 same; grep of lib/router/route_names.dart shows no '/sis/attendance' (only /sis/dashboard,/sis/students,...); runtime tap at dynamic_widget_runtime_screen.dart:86 context.push(widget.drillDown!).
- **Root Cause:** Catalog drill-down uses a route path that was never registered; the other tiles use valid paths. Likely intended teacherAttendance/studentAttendance or an SIS attendance screen that doesn't exist.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Cross-module

#### DW-2 · Per-widget data permission is bypassed for any school-scope token (server-side RBAC weakening)
- **Module:** Dynamic Widgets
- **User Journey:** A school-scoped user lacking viewFinance/viewStudentRisk requests /widgets/data for fee_collection/student_risk
- **Severity:** 🟡 Medium
- **Description:** buildWidgetData.hasWidgetAccess (widget_data_service.ts:23-26) returns true whenever claims.scope=='school' && school_id is set, regardless of the widget's required permission (WIDGET_PERMISSIONS). So per-widget RBAC (viewFinance, viewStudentRisk, viewHomeworkIntelligence) is effectively a no-op for every school-scope user; permissionDenied is never set for them. The route-level gate (viewDynamicWidgets) still applies, and the Flutter runtime hides unauthorized tiles via filterWidgetsByRbac, so nothing leaks into the rendered UI — but a direct GET /widgets/data?widgetIds=fee_collection returns real fee data to a school user without viewFinance.
- **Evidence:** supabase/functions/_shared/widget_platform/widget_data_service.ts:23-26 (hasWidgetAccess `||` school-scope short-circuit), used at line 178 for the permissionDenied decision; WIDGET_PERMISSIONS map at line 28-37 is therefore unenforced for school scope.
- **Root Cause:** Defense-in-depth gap: the `|| (scope===school && school_id)` clause was meant as a convenience but overrides the explicit per-widget permission check.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** RBAC

#### DW-3 · Runtime fetches live data for RBAC-hidden widgets (data crosses wire then is discarded)
- **Module:** Dynamic Widgets
- **User Journey:** User without viewFinance opens runtime dashboard; fee_collection is hidden in the UI but its data is still requested
- **Severity:** ⚪ Low
- **Description:** dynamicWidgetLiveDataProvider (dynamic_widget_providers.dart:56-69) builds visibleIds by filtering only on w.visible, NOT on RBAC. So it requests /widgets/data for widgets the user cannot view; combined with the server-side school-scope bypass (issue above), the unauthorized widget's data is returned over the wire even though filterWidgetsByRbac hides the tile in the screen. Minor privacy / wasted-payload concern; no visible UI leak.
- **Evidence:** lib/features/dynamic_widgets/dynamic_widget_providers.dart:60 `.where((w) => w.visible)` (no RBAC filter) vs runtime screen line 44 filterWidgetsByRbac applied only at render time.
- **Root Cause:** Live-data provider uses visibility flag, not the same RBAC predicate the screen uses to render.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** RBAC

#### DW-4 · GET role layout ignores verticalPack; non-school packs unresolvable + reset of non-school pack returns school widgets
- **Module:** Dynamic Widgets
- **User Journey:** A non-school vertical tenant (salon/hospital/restaurant) GETs a role layout, or resets a non-school override
- **Severity:** ⚪ Low
- **Description:** handleGetRoleLayout (widget_layout_handlers.ts:147) always returns packDefaultLayout(role, DEFAULT_PACK='school'), ignoring any verticalPack. So a non-school pack default can only be obtained by saving an override first. Worse, handleResetRoleLayout writes the chosen pack's default into the row, but the subsequent GET (isTenantOverride=false) ignores the stored pack and returns the school pack default. For the school-only pilot this is inert, but the multi-vertical contract the module advertises (salon/hospital/restaurant) is not truly server-resolvable.
- **Evidence:** widget_layout_handlers.ts:147 packDefaultLayout(role, DEFAULT_PACK) hardcoded; handleResetRoleLayout:230 uses body verticalPack for the stored def but GET path never reads stored pack when isTenantOverride=false (line 144-147).
- **Root Cause:** DEFAULT_PACK hardcoded in the GET/version handlers; verticalPack query param plumbed in the client (evolution_remote_datasource.dart:323) but unused by handleGetRoleLayout.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### DW-5 · Non-school pack widget IDs have no live data source (tiles render em-dash)
- **Module:** Dynamic Widgets
- **User Journey:** A salon/hospital/restaurant layout's tiles request live data
- **Severity:** ⚪ Low
- **Description:** packDefaultLayout for non-school packs produces widget IDs chair_utilization/bed_occupancy/active_covers/etc., but buildWidgetData.allWidgets (widget_data_service.ts:79-167) only defines the 8 school widget IDs. For any non-school ID, `if (!base) continue` (line 176) skips it, so the tile gets no data and renders '—'. School pilot is unaffected (all school IDs are present), but the advertised vertical packs would show empty tiles.
- **Evidence:** widget_pack_catalog.ts salonWidgets/hospitalWidgets/restaurantWidgets ids (lines 217-236) vs widget_data_service.ts allWidgets keys (school_health,student_risk,fee_collection,attendance_risk,homework_summary,operations_summary,employee_workload,timetable_alerts only).
- **Root Cause:** Live-data service was only implemented for the school vertical; vertical-pack catalog widgets have no corresponding data builders.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

**Strengths (working well):**
- Client↔backend contract matches exactly: EvolutionApiPaths (widgetDataSources '/widgets/data-sources', widgetLayoutVersions '/widgets/layouts/versions', widgetRoleLayout '/widgets/layouts/:role', +/reset) all matched by widget_platform_router.ts with static segments ordered before the :role regex (router lines 42-64).
- Writes are real, not mocked: Save (PUT) and Reset (POST) go straight through ApiEvolutionRepository with no mock fallback; only GET role layout has a mock safety-net and only on empty/error (hybrid_evolution_repository.dart:253-266), exactly as the B11 cert describes.
- RBAC is enforced on both sides and consistent: route-level view/manage + requireSchoolOperationalScope on every handler, rbac_route_inventory lists all 5 routes correctly, route guards + canManage gate the UI; org-scope/unauth denials verified by cert and live 401 probes.
- Persistence honors the erp_tenant no-DELETE constraint correctly (UPDATE-first/INSERT-fallback save, reset-by-rewrite), audited via widgetPlatformAudit.roleLayoutSaved + role_layout.reset events.
- Deployment confirmed live: all three rich endpoints return 401 (not 404) unauthenticated on the VPS, proving they are deployed; routeWidgetPlatform wired in index.ts with RBAC-only gating (no entitlement wrapper).
- States handled: AksharaLoadingState, AksharaErrorState.fromFailure with onRetry on every async section; empty-widgets message in runtime; save/reset buttons show spinners and disable while loading; mapper tolerates both camelCase and snake_case keys.
- Tests green: deno widget_pack_catalog_test 5/5 (re-run this session), flutter contract test (envelope mapping, save/reset round-trip, data-sources) + runtime/registry screen tests all pass in gate logs.

---

### Notifications
**Code:** `NOTIF`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Covered the full Notifications module: lib/features/notifications (screen/provider/models), lib/core/notifications/push_messaging_service.dart, the communication repository chain (interface/hybrid/api/dto/paths) and backend _shared/communication (router, handlers, service, repository SQL, fcm_v1). Traced every UI action (list, filter chips, mark-read, mark-all-read, archive, pull-to-refresh, swipe) to its route+RBAC+SQL. Confirmed deployment via live probes (health ok; comm-router NOT_FOUND envelope on /parent/notifications/bogus; 401 on missing bearer) and the FCM cert. LIMITATION: the read-only bearer token (token.txt) is EXPIRED (exp 1782461822 < now) AND is scope=school, so authenticated parent/student GET probes could not be run this session — those journeys are evidenced via code trace + the 13/13 live cert (2026-06-25) instead of a fresh authenticated probe. SSH alias 'akshara' was not authorized from this environment (publickey denied), so deployed-source diff relied on live route-behavior probes rather than cat of /opt/akshara.","liveProbes":[{"probe":"GET https://akshara.veloraunisexsalon.com/health","result":"200 {\"status\":\"ok\",\"service\":\"akshara-api\"} — API live."},{"probe":"GET /parent/notifications (no auth)","result":"401 UNAUTHORIZED 'Missing bearer token' — auth gate enforced."},{"probe":"GET /parent/notifications/bogus (bad bearer)","result":"404 NOT_FOUND 'Route not found: GET /parent/notifications/bogus' from the communication router — proves routeCommunication is deployed and prefix-matches /parent/notifications."},{"probe":"GET /parent/notifications & /student/notifications with token.txt","result":"401 'Invalid access token' — token.txt is expired (exp ~2h prior) and scope=school; could not exercise authenticated parent/student fetch. Relied on code trace + FCM cert 13/13."},{"probe":"ssh akshara cat /opt/akshara/functions/...","result":"Permission denied (publickey) — control socket not available this session; deployment confirmed via live route-behavior probes instead."}]

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Student notification inbox: list / mark-read | 🔴 broken | app_router.dart:2693-2694 _studentNotificationsTap pushes RouteNames.parentNotifications; NotificationsScreen uses communicationRepositoryProvider whose api repo defaults notificationsPath=parentNotifications (api_repository_providers.dart:334-338 never passes student path). A student session GETs /parent/notifications → handleParentNotifications returns 403 'Parent scope required' (communication_handlers.ts:212-214). Provider swallows (notifications_provider.dart:42-44) and shows demo fallback. Student route /student/notifications exists server-side but is never called by the app. |
| Empty-inbox state for real users | 🔴 broken | _EmptyInbox (notifications_screen.dart:336-371) is effectively unreachable in live API mode: refresh() falls back to _mergedInbox() when API returns empty (notifications_provider.dart:41), and build() seeds _mergedInbox() (line 27) which always appends 5 hardcoded demo notifications (_fallbackInbox, lines 126-169). |
| Archive notification (persisted) | 🟡 partial | notifications_provider.dart:97-102 archive() only mutates local state; no repository/server call — archived state lost on refresh/relaunch. No /archive route exists. |
| FCM push: permission → token register → backend persist (Android) | ✅ verified | docs/FCM_PUSH_HTTP_V1_CERTIFICATION.md live 13/13 (2026-06-25); push_messaging_service.dart:53-127 wires permission/token/register; handler handleRegisterDeviceToken (communication_handlers.ts:455-487) → registerDeviceToken ON CONFLICT (communication_repository.ts:489-503). Live: /parent/device-tokens prefix routed (comm router 404 envelope on bogus path). |
| Token refresh + re-sync on login | ✅ verified | push_messaging_service.dart:72 onTokenRefresh→_registerToken; :91-97 authProvider listener re-syncs on auth transition; cert 'token-refresh re-registration' PASS. |
| Foreground message → in-app banner + inbox refresh | ✅ verified | push_messaging_service.dart:130-160 _onForegroundMessage shows rootScaffoldMessenger SnackBar with 'View' deep-link action and calls notificationsProvider.refresh(). |
| Background/terminated tap → deep-link nav from data.route | ✅ verified | push_messaging_service.dart:163-186 + getInitialMessage :80-83; _deepLink only honors data['route'\|'deep_link'] starting with '/' (safe). Per-event route population is additive-future per cert. |
| Real FCM v1 send (service-account OAuth) | ✅ verified | cert 'Real OAuth + v1 endpoint reached' PASS (INVALID_ARGUMENT not UNAUTHENTICATED); fcm_v1_client.ts; deno fcm_v1_test.ts 5/5 ok in gate log; VPS env FCM_SERVICE_ACCOUNT_JSON + FCM_STUB_MODE=false per cert. |
| Parent notification inbox: list / mark-read / mark-all-read | ✅ verified | notifications_provider.dart:32-95 → hybrid→api repo /parent/notifications + mark-read/mark-all-read; handlers scope-guard parent (communication_handlers.ts:206-229,387-453); markRead SQL scoped by org+recipient_user_id+id::uuid (communication_repository.ts:518-545); server camelCase payload (communication_service.ts:99-110) matches mapper (communication_dto.dart:147-160); contract test communication_client_alignment passes. |

**Issues:**

#### NOTIF-1 · Student notification inbox calls parent-only route → 403 → silent demo fallback
- **Module:** Notifications
- **User Journey:** Student notification inbox: list / mark-read
- **Severity:** 🟠 High
- **Description:** Students reach the same NotificationsScreen (app_router.dart:2693 routes student bell to RouteNames.parentNotifications). The screen resolves communicationRepositoryProvider → ApiCommunicationRepository, which defaults notificationsPath to CommunicationApiPaths.parentNotifications (api_communication_repository.dart:12) and is never re-pointed to the student path (api_repository_providers.dart:334-338 constructs it with no notificationsPath). So a student session fetches GET /parent/notifications, which the server hard-rejects with 403 'Parent scope required' (communication_handlers.ts:212-214). The provider swallows the error (notifications_provider.dart:42-44) and shows demo data. The student-scoped route /student/notifications + handleStudentNotifications (communication_handlers.ts:231-254) exists and is deployed but is never invoked by the app. Net: students never see their real notifications; device-token register still works because that route allows student scope.
- **Evidence:** app_router.dart:2693-2694; api_repository_providers.dart:334-338; api_communication_repository.dart:12; communication_handlers.ts:212-214,231-254; communication_router.ts:61-62; notifications_provider.dart:42-44
- **Root Cause:** notificationsPath is role-agnostic: the provider/repo wiring never selects the student variant for student sessions; the student tap reuses the parent route name.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### NOTIF-2 · Hardcoded demo notifications shown to real parents on empty/initial inbox
- **Module:** Notifications
- **User Journey:** Empty-inbox state for real users
- **Severity:** 🟠 High
- **Description:** _fallbackInbox (notifications_provider.dart:126-169) is an unconditional list of 5 fake notifications (e.g. 'Fee reminder — Term 2 · Ravi · 8-A', 'Bus route delay') with no demo-mode gate. build() seeds the state from _mergedInbox() (line 27) and refresh() falls back to _mergedInbox() whenever the API returns an empty list (line 41). In a live build (COMMUNICATION_API_ENABLED=true) a real parent with zero notifications sees fabricated alerts, the unread-badge count (unreadNotificationsCountProvider, line 17→parent_dashboard_screen.dart:37) shows a fake count (nt-001 is unread+urgent), and the genuine _EmptyInbox state never renders. Contradicts the Wave 2 demo-purge intent for live pilot.
- **Evidence:** notifications_provider.dart:27,41,64,126-169; notifications_screen.dart:336-371; parent_dashboard_screen.dart:37
- **Root Cause:** Empty/initial state falls back to seeded demo data instead of an empty list; _fallbackInbox is not gated behind demo mode.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Data-integrity

#### NOTIF-3 · Archive action is local-only and not persisted
- **Module:** Notifications
- **User Journey:** Archive notification (persisted)
- **Severity:** 🟡 Medium
- **Description:** Swiping a notification to archive (notifications_screen.dart:118-126 → notifier.archive) only sets isArchived in local Riverpod state (notifications_provider.dart:97-102). There is no repository method or backend route for archive, so the action is lost on pull-to-refresh, navigation away, or app relaunch — the notification reappears. Mark-as-read by contrast IS persisted server-side.
- **Evidence:** notifications_provider.dart:97-102; notifications_screen.dart:118-126; no archive route in communication_router.ts
- **Root Cause:** Archive has no persistence layer (no DB column/route/repo call), unlike mark-read.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### NOTIF-4 · mark-read of in-app/fallback items (non-UUID ids) triggers swallowed server 500
- **Module:** Notifications
- **User Journey:** Parent notification inbox: list / mark-read
- **Severity:** ⚪ Low
- **Description:** In merged/mock mode the inbox contains items with non-UUID ids: comm-store bridge items 'comm-nt-<id>' (notifications_provider.dart:51) and demo items 'nt-001'..'nt-005'. Tapping them calls markRead(id) which (API mode) POSTs to /parent/notifications/mark-read; the server casts id::uuid (communication_repository.ts:526) and throws on a non-UUID, returning 500. The 500 is swallowed (notifications_provider.dart:74-76) and only an optimistic local update remains — read state for those items never persists. Low impact because these ids only appear in mock/empty-fallback paths, but it produces avoidable 500s and audit noise once the fallback issue is fixed.
- **Evidence:** notifications_provider.dart:51,67-82; communication_repository.ts:524-529
- **Root Cause:** Mixed id namespaces (server UUID vs synthetic 'comm-nt-'/'nt-' ids) hit a strict ::uuid cast; resolved once demo fallback is removed.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Data-integrity

#### NOTIF-5 · 'Mark all read' marks every notification regardless of active filter
- **Module:** Notifications
- **User Journey:** Parent notification inbox: list / mark-read
- **Severity:** ⚪ Low
- **Description:** The AppBar 'Mark all read' action calls notifier.markAllRead() (notifications_screen.dart:35-40) which clears unread on ALL items and (API) calls /parent/notifications/mark-all-read for the whole user, ignoring the currently selected filter chip (e.g. while viewing only 'Fees'). Minor UX surprise; also the disabled-guard uses filtered items.isEmpty so the button can be enabled on a non-empty filtered view yet mark unrelated categories read.
- **Evidence:** notifications_screen.dart:35-40; notifications_provider.dart:84-95; communication_handlers.ts:426-453
- **Root Cause:** mark-all-read is user-wide with no filter/category scoping on client or server.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

**Strengths (working well):**
- Parent push pipeline is genuinely live-certified end-to-end: real service-account OAuth + FCM HTTP v1 endpoint reached (cert 13/13, 2026-06-25), legacy server-key API removed, fcm_v1_test 5/5 green in gate log.
- Client↔server contract is exact for parent notifications: server emits camelCase (isRead/isUrgent/childContext) matching CommunicationMapper.toNotification, with a passing alignment test; category mapper covers all 8 categories.
- RBAC is enforced server-side on every route (scope guards parent/student/school) and confirmed live (401 on missing bearer; comm-router NOT_FOUND envelope on bogus path proves routeCommunication is deployed and prefix-matching).
- mark-read/mark-all-read SQL is correctly tenant- and recipient-scoped (org_id + recipient_user_id + id::uuid), preventing cross-user read manipulation.
- Device-token register is idempotent (ON CONFLICT) and the single register route accepts parent/student/school scope, so token registration works for all mobile roles even though the inbox fetch does not.
- iOS is cleanly degraded, not broken: firebase_options throws UnsupportedError on iOS but _initFirebase() catches it (main.dart) so the app runs with push disabled — matches the documented Android-only scope.
- Deep-link handling is defensive: only data['route']/['deep_link'] values starting with '/' are navigated, and nav failures are caught.
- Mobile responsiveness handled: tablet breakpoint + max content width, dismissible rows, urgent badge, unread indicator, pull-to-refresh.

---

### Alumni
**Code:** `ALUMN`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Covered all 9 Flutter screens (dashboard/registry/profile/events/donations/campaigns/mentorship/reports/settings), 4 write dialogs, mutations+providers+repository+remote datasource+api-paths, and the full backend (router/read+write handlers/read repository/seed migration). Traced every screen->provider->repo->client path->router route->handler->RBAC->DB. Confirmed mock-vs-live selection (live-default on). Backend deno + flutter alumni tests confirmed green via gate logs. LIVE GET probes to all 8 endpoints returned 401 because the provided read-only token had expired (exp 1782461822 < now 1782469161, ~2h stale) and is GET-only with no re-auth path - this is an environment limitation, not an alumni defect; health was up and the token's decoded claims confirmed viewAlumni+manageAlumni. SSH to VPS was unavailable this session (publickey denied; owner control-socket not open), so deployment was confirmed via live config + health rather than reading /opt/akshara source. Cited Batch 5 (manageAlumni/alumni_entities writes) and Batch 6 (graduation does not auto-surface to Alumni) certs rather than re-litigating.

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Promotion student->alumni handoff (graduate auto-surfaces in Alumni module) | 🔴 broken | Batch 6 cert (LIVE_BACKEND_BATCH6:90-94): graduation flips students.status to alumni but does NOT auto-surface the graduate in the Alumni module (separate alumni-onboarding feature, never built). Registry insight card (alumni_registry_screen.dart:106) claims 'Auto-onboard Class 12 exits' but only links to SIS - no auto-onboard exists. |
| Record/track alumni donations | 🔴 broken | No POST /alumni/donations route in alumni_router.ts (only registry/events/campaigns/mentorship). No donation write handler anywhere in backend. GET /alumni/donations reads 'donation' entity_type only ever populated by seed. Donations screen (alumni_donations_screen.dart) is read-only, header button just navigates to Finance. Donations can never be recorded in live. |
| Alumni dashboard KPIs (registered count, donation summary) | 🔴 broken | Dashboard reads getSnapshot('snapshot_dashboard') which is static seeded JSONB (migration 20260614200000:132: hardcoded '2,400 Registered Alumni', donationSummary '₹12.4L'). Never recomputed from the live alumni/event/campaign rows added via write endpoints. Surfaced directly (alumni_dashboard_screen.dart:66,73). |
| Open alumnus profile detail + WhatsApp contact | 🟡 partial | Profile screen WhatsAppContactButton (alumni_profile_screen.dart:115) validates number, hides dead control, error snackbars (whatsapp_contact_button.dart:39-61) - solid. BUT detail's employmentHistory/eventsAttended/mentorshipRole are FABRICATED in live (alumni_read_repository.ts:18-34: always 'Tech Corp' + 'Annual Reunion <batchYear>', donationHistory always []). Profile renders these sections (alumni_profile_screen.dart:141-143). |
| Export alumni reports | 🟡 partial | Reports 'Download report' button (alumni_reports_screen.dart:152) calls showAksharaReportExportPreviewSnackBar -> 'preview only. Export pipeline not connected yet.' (operational_action_feedback.dart:17-30). Honest placeholder, no real export. |
| Live deployment + RBAC enforcement | 🟡 partial | GET /health -> {status:ok}. All 8 alumni GET probes returned 401 'Invalid access token' because the read-only token expired (exp 1782461822 vs now 1782469161, ~2h stale) - environment limitation, NOT an alumni defect. Token DID carry viewAlumni+manageAlumni perms confirming RBAC mapping. Server enforces requirePermission(viewAlumni) on reads (module_read_handlers.ts:37) and requirePermission(manageAlumni) on writes (module_write_handlers.ts:53). Could not re-auth (GET-only, no creds). |
| Add alumnus to registry (Add alumni dialog -> POST /alumni/registry -> appears in list) | ✅ verified | Dialog showAddAlumniDialog (alumni_workflow_actions.dart:22-118) -> addAlumniProvider.execute (alumni_mutations_provider.dart:32) asserts manageAlumni -> ApiAlumniRepository.addAlumni -> remote POST AlumniApiPaths.registry (alumni_remote_datasource.dart:106) -> router POST '/alumni/registry' -> handleAddAlumni runWrite('manageAlumni') writeStore.insert entity_type 'alumni' (alumni_write_handlers.ts:15-42). listEntities returns it dynamically. Live-default on (config/live_release.json:29). deno test 'viewAlumni permission enforced' + flutter alumni_repository_contract_test all pass. |
| Create alumni event (POST /alumni/events) + list refresh | ✅ verified | showCreateEventDialog (alumni_workflow_actions.dart:120) -> createAlumniEventProvider -> POST AlumniApiPaths.events -> router '/alumni/events' -> handleCreateEvent runWrite manageAlumni (alumni_write_handlers.ts:45). Provider invalidates alumniEventsFutureProvider+dashboard on success. |
| Launch fundraising campaign (POST /alumni/campaigns) | ✅ verified | showCreateCampaignDialog (alumni_workflow_actions.dart:205) -> createAlumniCampaignProvider -> POST '/alumni/campaigns' -> handleCreateCampaign manageAlumni (alumni_write_handlers.ts:71). financeAccountCode captured but not wired to Finance (display-only string). |
| Match mentorship pair (POST /alumni/mentorship) | ✅ verified | showAddMentorshipDialog (alumni_workflow_actions.dart:283) -> addMentorshipPairProvider -> POST '/alumni/mentorship' -> handleAddMentorshipPair manageAlumni (alumni_write_handlers.ts:97). |
| Browse registry (list/filter/paginate/card+table responsive) | ✅ verified | alumni_registry_screen.dart:30-114 watches loading/error/empty/filtered/page providers; AksharaLoadingState/ErrorState/EmptyState all handled; AdminLayout.useCardLayout switch for mobile; AksharaPaginatedListFooter. Reads GET /alumni/registry. |

**Live probes:**
- `GET /health` → 200 {"data":{"status":"ok","service":"akshara-api"},"error":null}
- `GET /alumni/dashboard (and registry/events/donations/campaigns/mentorship/reports/settings)` → 401 UNAUTHORIZED 'Invalid access token' on all 8 - read-only token expired (exp 1782461822 vs now 1782469161). Not an alumni bug; token GET-only, no re-auth available.
- `decode token.txt claims` → role schoolAdmin, tenant a1000000..0001; permissions include viewAlumni AND manageAlumni - confirms RBAC perm names match server gates.

**Issues:**

#### ALUMN-1 · Alumni profile detail fabricates employment history, events attended, and mentorship role in live
- **Module:** Alumni
- **User Journey:** Open alumnus profile detail
- **Severity:** 🟠 High
- **Description:** alumniDetailToApi hardcodes employmentHistory to a single fake 'Tech Corp' entry, eventsAttended to ['Annual Reunion <batchYear>'], donationHistory to [], and derives mentorshipRole from engagementStatus. Every alumnus profile shows the same fabricated employment/events regardless of real data. This is a live-build mock embedded in the deployed read path, presented to school staff as real records.
- **Evidence:** supabase/functions/_shared/alumni/alumni_read_repository.ts:18-34 (alumniDetailToApi); consumed by alumni_profile_screen.dart:141 (_EmploymentSection) and :142-143 (eventsAttended/_DonationSection). Route GET /alumni/registry/:id -> handleAlumniDetail (alumni_handlers.ts:18).
- **Root Cause:** Detail endpoint never persisted real employment/events/donation sub-records; the JSONB entity stores only flat alumnus fields, so the detail view stubs the rich sections with constants.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### ALUMN-2 · Alumni dashboard KPIs and donation summary are static seed, never recomputed from live data
- **Module:** Alumni
- **User Journey:** Alumni dashboard KPIs
- **Severity:** 🟠 High
- **Description:** Dashboard 'Registered Alumni' count (2,400), donation summary (Received ₹12.4L / Pledged ₹2.1L / Pending ₹45K), recentGraduates and upcomingEvents come from a single seeded snapshot_dashboard JSONB row, not aggregated from the live alumni/event/campaign rows. A real school adding its first alumnus still sees 2,400 registered and ₹12.4L donations. Same applies to Reports snapshot (donationTrend/eventAttendance empty arrays) and Settings.
- **Evidence:** supabase/migrations/20260614200000_hostel_library_inventory_alumni_read_apis.sql:130-134 (seeded payload with hardcoded kpis/donationSummary, recentGraduates:[], upcomingEvents:[]); served via getSnapshot (entity_read_store.ts:58, single-row by entity_type) in handleDashboard/handleReports/handleSettings (alumni_handlers.ts:10,49,53); surfaced alumni_dashboard_screen.dart:66,73.
- **Root Cause:** Snapshot endpoints read a pre-seeded summary row instead of computing aggregates over the writable entity rows; write handlers append entities but never update the snapshot.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Data-integrity

#### ALUMN-3 · No donation write path - donations can never be recorded in live mode
- **Module:** Alumni
- **User Journey:** Record/track alumni donations
- **Severity:** 🟠 High
- **Description:** There is no POST /alumni/donations route and no donation write handler anywhere in the backend. The Donations screen is read-only and its 'donation' entity list is only populated by seed data. Combined with the static donation KPIs, alumni fundraising/donation tracking is non-functional in production: a school cannot log a single donation against an alumnus or campaign.
- **Evidence:** supabase/functions/_shared/alumni/alumni_router.ts:50-58 (POST routes = registry/events/campaigns/mentorship only, no donations); no donation insert in alumni_write_handlers.ts; alumni_donations_screen.dart:45-49 header button only navigates to Finance collections; GET /alumni/donations -> handleList('donation') (alumni_handlers.ts:37).
- **Root Cause:** Donation recording was scoped out of Batch 5 writes (only 4 entity types got writers); campaign raisedAmount/donorCount are also seeded constants with no increment path.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### ALUMN-4 · Registry insight card overstates capability (claims auto-onboard of Class 12 graduates)
- **Module:** Alumni
- **User Journey:** Promotion student->alumni handoff
- **Severity:** 🟡 Medium
- **Description:** The registry insight card tells staff 'Alumni records link to SIS graduate profiles. Auto-onboard Class 12 exits with status = Alumni.' but no auto-onboarding exists - graduation flips students.status only and does not create an alumni_entities record. The card's action merely navigates to SIS students. Staff may believe graduates appear automatically when they must be added manually via 'Add alumni'.
- **Evidence:** alumni_registry_screen.dart:104-111 (insight message + onAction context.go(sisStudents)); contradicted by docs/LIVE_BACKEND_BATCH6_DIRECTOR_AND_IDENTITY.md:90-94 ('does not auto-surface the graduate in the Alumni module ... separate alumni-onboarding feature').
- **Root Cause:** Copy written aspirationally for a planned alumni-onboarding feature that was never built; promotion->alumni handoff remains manual.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Cross-module

#### ALUMN-5 · Alumni report export is a non-functional placeholder
- **Module:** Alumni
- **User Journey:** Export alumni reports
- **Severity:** ⚪ Low
- **Description:** The 'Download report' button on the Alumni Reports screen never generates a file; it shows a snackbar 'Alumni report (PDF) - preview only. Export pipeline not connected yet.' Honest (not a silent mock) but the reporting journey is incomplete for a school that needs an alumni engagement report.
- **Evidence:** alumni_reports_screen.dart:151-152 -> showAksharaReportExportPreviewSnackBar (lib/shared/widgets/operational_action_feedback.dart:17-30).
- **Root Cause:** Export pipeline intentionally deferred; placeholder kept honest.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### ALUMN-6 · Write dialogs do not disable submit / show inline progress during the async write
- **Module:** Alumni
- **User Journey:** Add alumnus / create event / campaign / mentorship
- **Severity:** ⚪ Low
- **Description:** All four write dialogs pop on confirm and then await the provider; the confirm button is not disabled and no inline spinner is shown during the network call. On a slow link the user gets no in-dialog feedback (success/error arrive only as a post-dismiss snackbar). The notifier sets AsyncLoading but the dialog has already closed, so it is unobserved. Error handling itself is correct (snackbar via _showAlumniMutationError).
- **Evidence:** alumni_workflow_actions.dart:84-92 (onConfirm pops immediately), :95-106 await after pop; AsyncLoading set in notifier (alumni_mutations_provider.dart:33) but dialog already dismissed.
- **Root Cause:** Dialog uses confirm-then-await pattern rather than an in-dialog submitting state.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

**Strengths (working well):**
- All 12 endpoints (8 GET reads + 4 POST writes) trace cleanly client->router->handler with matching path strings on both sides; no path mismatches (alumni_api_paths.dart vs alumni_router.ts).
- RBAC is enforced on both tiers: server requirePermission(viewAlumni) on reads (module_read_handlers.ts:37) and requirePermission(manageAlumni) on writes (module_write_handlers.ts:53); client gates every write button with AksharaManageAction(Permission.manageAlumni) and re-checks via assertManageAlumni (alumni_mutations_provider.dart:15-26). Token carried both perms.
- Registry/Events/Campaigns/Mentorship LIST reads are genuinely dynamic in live - writes append entity rows that listEntities returns; writes emit audit events (emitMutationAudit) for each create.
- Live-default is on for production builds (config/live_release.json:29 ALUMNI_API_ENABLED=true, scripts/run_live.sh:43); health endpoint up; gate tests green (deno viewAlumni-enforced, flutter contract+screens).
- WhatsApp contact (profile screen) is robust: validates dialable digits, renders nothing for missing numbers (no dead control), surfaces snackbar on failure (whatsapp_contact_button.dart:39-61).
- Registry screen has complete loading/error/empty states and responsive card-vs-table layout (alumni_registry_screen.dart:73-91,124-135); write dialogs surface failures via snackbar and required-field guards.

---

### Verticals & Industry Packs
**Code:** `VAIP`  ·  **Verdict:** `certified-with-gaps`

_Coverage:_ Covered all of lib/features/verticals/{restaurant,salon,healthcare,accommodation} (8 dashboards/sub-screens each traced), lib/features/industry (hub + providers + mutations), their repository interfaces/mock/api layers, remote datasources + api paths, repository_config flags, router (route_names, route_guards, app_router, *_navigation, school_build_scope), admin_navigation_provider, and the B11 widget-platform cert + widget_pack_catalog backend. Traced the wire screen->provider->repo->datasource->(absent) backend route for all five surfaces. Live-probed GET /restaurant/dashboard + /restaurant/intelligence (both 404) and /health (200). Grepped gate logs for module tests (contract + dashboard + industry_hub all green). Could not SSH the deployed router directly (my key is unauthorized; owner control-socket not open this session) but live 404 probes are authoritative that no vertical routes are deployed. CRITICAL FRAMING: this entire module is the frozen P4/B12 'Verticals' roadmap item, deliberately hidden in the shipped school product (owner decision 2026-06-18). Within the production school pilot it is dormant and harmless. The 5 issues above are all 'if the freeze is lifted' gaps; none affect a real school today. Severity is set Medium/Low accordingly rather than Critical/High, since no live school journey is broken.

**Journeys verified:**

| Journey | Status | Evidence |
|---------|--------|----------|
| Restaurant ops: view dashboard -> tables -> create order -> kitchen ticket -> intelligence | 🔴 broken | If un-hidden, the journey is non-functional. orders_screen.dart is read-only (no create button); create/update mutation providers exist (restaurant_mutations_provider.dart:61,91) but are NEVER referenced by any screen (grep of lib/features found 0 usages). ApiRestaurantRepository.createRestaurantOrder returns const RestaurantOrder(id:'',...) without persisting (api_restaurant_repository.dart:44-51); listTables/Orders/Kitchen return const [] (lines 21-31). No backend route exists. Live probe GET /restaurant/dashboard -> 404 NOT_FOUND. |
| Salon ops (customers/appointments/services/intelligence) | 🔴 broken | Same stub pattern. api_salon_repository.dart returns const [] for lists and const SalonAppointment/Customer(id:'') for creates (lines 22-59). Mutation providers unused by any screen. Salon screens have 0 interactive CRUD widgets (only dashboard nav buttons). SalonApiPaths only defines /salon/dashboard + /salon/intelligence; no backend handler. SALON_API_ENABLED defaults false (repository_config.dart:321). |
| Healthcare ops (patients/appointments/practitioners/intelligence) | 🔴 broken | Identical stub: api_healthcare_repository.dart returns const [] and const Patient/Appointment(id:'') (lines 22-61). No backend route; HealthcareApiPaths only dashboard+intelligence. HEALTHCARE_API_ENABLED defaults false (repository_config.dart:313). Screens are display-only over mock data. |
| Accommodation ops (residents/occupancy/allocations/intelligence) | 🔴 broken | Identical stub: api_accommodation_repository.dart returns const [] and const Resident/Allocation(id:'') (lines 22-59). No backend route; ACCOMMODATION_API_ENABLED defaults false (repository_config.dart:337). |
| Industry hub: select active industry + toggle module activation, persist across restart | 🔴 broken | industry_providers.dart:25-27 comment 'Per-module activation toggles (in-memory MVP state)' uses StateProvider; setActiveIndustry just sets industryOverrideProvider state (industry_mutations_provider.dart:34) and activateIndustryModule mutates an in-memory Map (lines 59-63). No repository, no API call, no persistence -> all selections lost on restart. No backend route or permission for /industry exists. |
| Reach a vertical (Restaurant/Salon/Healthcare/Accommodation/Industry) in the shipped school build | ✅ verified | Intentionally BLOCKED. lib/core/config/school_build_scope.dart:22-79 hides all 5 modules from admin nav (hiddenAdminModules) and route-blocks their prefixes (hiddenRoutePrefixes). Double-enforced: route_guards.dart:405 -> AccessDeniedScreen and app_router.dart:2476 redirect. admin_navigation_provider.dart:212 filters them out. Matches owner decision 2026-06-18 ('hide now, delete later') and B11 cert ('only P4/B12 Verticals remains, frozen'). So in production school pilot these are unreachable by design - correct behavior. |
| Vertical dashboards render with mock KPIs + AI intelligence summary | ✅ verified | Dashboards render mock KPIs (mock_restaurant_repository.dart:26-35 hardcoded 'Active 12'/'Pending 3') with proper loading/error states (restaurant_dashboard_screen.dart:63-67 AksharaLoadingState/AksharaErrorState.fromFailure + onRetry). Intelligence uses the real AiInferencePipeline with safe deterministic fallback (mock_restaurant_repository.dart:50-72). Screen tests pass (gates/flutter_test.log: industry_hub + 4 vertical dashboard tests green). |

**Live probes:**
- `GET /restaurant/dashboard?tenantId=pilot (schoolAdmin bearer)` → 404 {"error":{"code":"NOT_FOUND","message":"Route not found: GET /restaurant/dashboard"}} - confirms no vertical backend deployed
- `GET /restaurant/intelligence?tenantId=pilot` → 404 NOT_FOUND - same
- `GET /health` → 200 {"data":{"status":"ok","service":"akshara-api"}} - API live, baseline healthy

**Issues:**

#### VAIP-1 · Vertical API repositories are non-persisting stubs (writes silently no-op)
- **Module:** Verticals & Industry Packs
- **User Journey:** Restaurant/Salon/Healthcare/Accommodation create+update flows
- **Severity:** 🟡 Medium
- **Description:** Every ApiXxxRepository in lib/core/repositories/api/{restaurant,salon,healthcare,accommodation}/ returns const [] for all list methods and const Entity(id:'',...) for all create/update methods without any network call or persistence. The remote datasources only implement fetchDashboard/fetchIntelligence; there are no remote methods for tables/orders/patients/appointments/residents/allocations or any mutation. So if the API flag were ever flipped on, all reads return empty and all writes silently succeed-but-persist-nothing.
- **Evidence:** lib/core/repositories/api/restaurant/api_restaurant_repository.dart:21-60 (listTables/listOrders/listKitchenTickets => const []; createRestaurantOrder => const RestaurantOrder(id:'')); identical in salon/healthcare/accommodation api repos; restaurant_remote_datasource.dart only has fetchDashboard/fetchIntelligence.
- **Root Cause:** Verticals were scaffolded (P4/B12) but never wired to a backend; API repo is a placeholder behind a flag that defaults false.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### VAIP-2 · No backend exists for any vertical or the industry framework (no routes, no RBAC, no tables)
- **Module:** Verticals & Industry Packs
- **User Journey:** All vertical + industry journeys
- **Severity:** 🟡 Medium
- **Description:** supabase/functions/api/index.ts has zero routes for restaurant/salon/healthcare/accommodation/industry. No _shared handler module exists for them (only widget_pack_catalog.ts references the words as widget reference data). The server RBAC inventory (rbac_route_inventory.ts) has no vertical permissions. The client-side permissions (viewRestaurantHospitality etc.) gate only the UI and have no server counterpart.
- **Evidence:** grep of supabase/functions/api/index.ts for restaurant|salon|healthcare|accommodation|industry => 0 hits; rbac_route_inventory.ts => 0 vertical hits. Live probe: GET /restaurant/dashboard and /restaurant/intelligence both return {"error":{"code":"NOT_FOUND"}} on https://akshara.veloraunisexsalon.com.
- **Root Cause:** Verticals are a frozen future roadmap item (P4/B12); backend was never built.
- **Estimated Effort:** L  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### VAIP-3 · CRUD mutation providers exist but are wired to no UI (dead code)
- **Module:** Verticals & Industry Packs
- **User Journey:** Restaurant create order/update kitchen ticket; Salon/Healthcare/Accommodation creates
- **Severity:** 🟡 Medium
- **Description:** Each vertical defines AsyncNotifier mutation providers (e.g. createRestaurantOrderProvider, updateKitchenTicketProvider) with RBAC assertions, but no screen invokes them. The list/management screens (orders, tables, kitchen, patient registry, room allocation, etc.) have zero create/edit/delete buttons, dialogs, or forms. So even in mock mode a user cannot perform the verticals' core actions.
- **Evidence:** grep of lib/features for createRestaurantOrderProvider/updateKitchenTicketProvider/create* salon/healthcare/accommodation => 0 usages outside the *_mutations_provider.dart files. Per-screen interaction count shows 0 onPressed/showDialog in all *_management/*_registry/orders/kitchen/allocation screens (only dashboards have nav buttons).
- **Root Cause:** Screens were generated as read-only scaffolds; action wiring was never added.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

#### VAIP-4 · Industry hub activation + active-industry selection is in-memory only (no persistence)
- **Module:** Verticals & Industry Packs
- **User Journey:** Industry hub: pick industry / toggle modules
- **Severity:** ⚪ Low
- **Description:** Selecting an active industry and toggling module activation mutate StateProviders only; nothing is saved to a repository or backend, so every choice is lost on app restart. The code comment explicitly labels it 'in-memory MVP state'. There is no backend /industry route to persist to.
- **Evidence:** lib/features/industry/industry_providers.dart:25-32 (StateProvider Map, '// Per-module activation toggles (in-memory MVP state).'); industry_mutations_provider.dart:34 sets industryOverrideProvider.state; lines 59-63 mutate in-memory Map. No repository import anywhere in the industry feature.
- **Root Cause:** Industry framework is an MVP scaffold for the frozen verticals roadmap.
- **Estimated Effort:** M  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** Wire-gap

#### VAIP-5 · Vertical list screens have no empty state
- **Module:** Verticals & Industry Packs
- **User Journey:** Restaurant orders/tables/kitchen, salon/healthcare/accommodation lists
- **Severity:** ⚪ Low
- **Description:** List screens render a ListView.builder directly; when the list is empty (which is the API-mode reality, since ApiXxxRepository returns const []), the screen shows a blank body with no 'no data' messaging. Loading and error states are handled correctly, but the empty state is missing.
- **Evidence:** lib/features/verticals/restaurant/orders_screen.dart:19-30 has data/loading/error branches but data:(list)=>ListView.builder with no list.isEmpty guard; same pattern in the other vertical list screens.
- **Root Cause:** Scaffold omitted empty-state handling.
- **Estimated Effort:** S  _(S <½d · M ½–2d · L 2+d)_
- **Recommended Fix Batch:** States/UX

**Strengths (working well):**
- Verticals are correctly and reversibly fenced off from the production school build: hidden from admin nav AND route-blocked, double-enforced in route_guards.dart:405 and app_router.dart:2476, with an explicit reversible SchoolBuildScope switch and clear owner-decision comments. A real school user cannot reach or break these.
- Dashboards have proper loading (AksharaLoadingState) and error (AksharaErrorState.fromFailure + onRetry) states consistent with the rest of the app.
- Intelligence screens use the real shared AiInferencePipeline with a deterministic safe fallback (mock_restaurant_repository.dart:50-72), so AI failures degrade gracefully.
- Client RBAC is consistent: route_guards.dart:114-132 maps every vertical route to a view permission, and mutation providers assert manage permissions (restaurant_mutations_provider.dart:14-25) before acting.
- Repository hybrid pattern is clean and flag-gated (isModuleApiEnabled, repository_config.dart) with all four vertical flags defaulting false, so no accidental live writes; contract tests confirm mock+api implement the same interface (gates/flutter_test.log).

---

## Cross-module findings

### XM-1 · Persona/admin read screens serve permanently-static seed snapshots instead of live-overlaid data  (🔴 Critical)
- **Modules:** Teacher, Principal, HR, Alumni, Library, Homework, Hostel
- **Description:** The same entity-snapshot read pattern (handleSnapshot/handleList over *_entities tables seeded only by migration) was extended to Teacher, Management/Principal, HR, Alumni, Library, Homework and Hostel WITHOUT the live-overlay step that fixed parent/student reads in Batch 3/4. Result: teacher rosters/marks/leave/dashboard, management exec dashboards (₹2.4Cr revenue etc.), HR dashboard KPIs (148 employees vs real 3), alumni KPIs (2,400 registered / ₹12.4L), library dashboard/fines/reports, homework-item read-back, and hostel visitors/dashboard all show fixed seed and never reflect real data or the module's own writes. This is the single largest trust risk — multiple modules display fiction as real operational data. Fix once as a reusable read-overlay/recompute framework and apply per module.

### XM-2 · Client surfaces ship ahead of backend routes — whole journeys 404 silently in the live build  (🔴 Critical)
- **Modules:** Parent, Teacher, Admissions, Communication, Principal, Admin
- **Description:** Many client API paths have no deployed router/handler, so the journey hard-404s in production (and the mock often masks it in tests): parent messaging/leave/PTM; teacher exam marks-entry/process/publish + parent-communication; admissions reports/settings/approval-queue/enrollment-prefill/pending + fee-structures-wrong-prefix; communication template-create + broadcast-history; management settings PUT (surfaces in both Principal and Admin). Several swallow the failure and either no-op or fall back to mock, so the user sees false success or stale data. Needs a client↔deployed-router path-parity contract test in addition to building the missing routes.

### XM-3 · Deployed-and-certified backends sit unused because their module flag is missing from config/live_release.json  (🟠 High)
- **Modules:** AI Features, Staff, Inventory, Admissions
- **Description:** PREDICTIONS_API_ENABLED, EMPLOYEE_API_ENABLED, and INVENTORY_DISTRIBUTION_API_ENABLED are present in scripts/run_live.sh (dev) but absent from the canonical config/live_release.json consumed by the release build, so the live release silently falls back to Mock repositories showing fabricated data (fake predicted students, mock employee roster, mock distributions) while working live backends go unused. Admissions has the inverse problem — a single coarse flag is ON for partially-built routes, causing 404s. Reconcile the live dart-define manifest against deployed routes (add the three missing flags; consider per-capability gating for admissions).

### XM-4 · Real users are shown fabricated/demo placeholder data presented as real  (🟠 High)
- **Modules:** Student, Exams, Notifications, Finance, HR, Alumni, Parent, AI Features
- **Description:** On error/empty/loading, multiple surfaces substitute hardcoded demo data instead of an honest error/empty state: student & parent exam screens render fabricated grades ('Ravi Kumar 8-A', mock A/A+), notifications show 5 hardcoded demo alerts to real parents (and a fake unread badge), finance refund/scholarship dialogs prefill a fake student ('Arjun Patel'/'acct_1'/₹5,000), HR profiles serve identical hardcoded manager/docs/leave-balances, alumni profiles fabricate employment/events, parent communication inbox falls back to a mock store, predictions show fake students. Violates the 'errors must surface, not swallow' and demo-purge rules. Fix is mostly bridging async error/empty state to real UI and removing demo seeds from live paths.

### XM-5 · Write-then-read decoupling: a successful write is invisible because read-model / snapshot is never updated  (🟠 High)
- **Modules:** Homework, Attendance, Hostel, Library, Teacher
- **Description:** Several modules persist a write to one table but the read path queries a different (static or un-joined) entity, so the action looks lost: homework grade/submission never propagates to student_entities/snapshot_homework (teacher can't even see submissions to grade); approved attendance correction's UPDATE matches 0 rows (class_label/session_date mismatch) so the mark never changes; logged hostel visitors land in the 'visitor' list but the screen reads a frozen snapshot_visitors; library returns compute a fine that's never persisted to the static snapshot_fines; teacher's own just-submitted attendance/homework don't appear in their static read. Needs read-side overlays/joins or write-back into the read model.

### XM-6 · Demo-grade workflow dialogs hardcode mock IDs / ignore typed input (data-integrity hazard on write)  (🟠 High)
- **Modules:** HR, Finance, Library, Hostel, Transport, Inventory, Attendance, Exams
- **Description:** Many create/assign dialogs prefill mock seed IDs or ignore the user's fields: HR leave (hardcoded employee/type/days=1) and create-employee (forced dept/role); finance refund/scholarship (fake student); library issue/return (mock 'mem_5'/'iss_2' → garbage member in live); inventory create-PO (literal mock 'vendor_if_1' → 500); hostel assign-room (free-text 'room_4'); transport route/assign (QA fixtures); attendance/exam dates as free-text with hardcoded defaults. These either corrupt data or hard-fail in live. Fix = real entity pickers + validation; several share the same 'no picker' root cause flagged since Batch 5.

### XM-7 · Certified/working features are unreachable from the app (orphaned routes, no nav entry)  (🟠 High)
- **Modules:** Staff, Admin, Marketing
- **Description:** Several built-and-sometimes-certified surfaces have no nav tile/menu/button and are reachable only by deep-link or test: Employee Platform/360/role-assignment, the unified onboarding wizard (B7-certified), the Promotion Center / multi-channel Publisher (Phase-1 certified), the Holiday/Event Calendar (certified backend, zero Flutter client), and the Meta-connect social flow. Same 'surface hidden' class B6 fixed for growth. Mostly small wiring fixes (add tiles/screens), high unblock-value for paid features.

### XM-8 · Async mutation/load errors are swallowed instead of surfaced to the user  (🟡 Medium)
- **Modules:** Student, Teacher, Communication, Director, AI Features, Notifications, Admin, Marketing, Alumni
- **Description:** A recurring UX-class defect: mutation AsyncNotifiers capture errors into state but screens never ref.listen them, or handlers use try/finally without catch, or repositories swallow exceptions — so failed submits/saves/sends/acks show no feedback (homework submit, copilot send, growth/publisher writes, director summary/acknowledge, management-settings save, notifications mark-read). Often paired with an unconditional success snackbar. Low individual severity but pervasive; best fixed as one States/UX sweep extending the Wave5 fromFailure standard to mutation paths.

### XM-9 · Write handlers gate on school scope only, not granular permission or assignment (intra-school RBAC weakening)  (🟡 Medium)
- **Modules:** Teacher, Attendance, Inventory, Dynamic Widgets, Finance
- **Description:** Several fast-path/pilot handlers authorize on scope==='school' && school_id without a granular permission or assignment check: teacher attendance/homework/exam-mark writes (any school staffer can mark any class), attendance marking, inventory distribution router not entitlement-wrapped, widget per-data permission bypassed for any school-scope token, and finance refunds lack self-approval prevention. Tenant isolation (RLS) still holds, so no cross-tenant breach — these are intra-school role-separation gaps. Fixable as a focused RBAC-hardening batch.
