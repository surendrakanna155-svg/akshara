# AKSHARA — Final Product Completion Audit

**Date:** 2026-06-25
**HEAD:** `6c0aab1` (FCM push HTTP v1 — live certified)
**Mode:** Completion-mode, full-product audit. Single source of truth for remaining work.
**Method:** 12 parallel area-auditors over all 16 listed areas + live verification gates run by the coordinator. Existing `docs/*_CERTIFICATION.md` treated as source of truth; certified-and-unchanged areas were not re-audited.
**Constraint honored:** No fixes implemented (at audit time). No features invented. No roadmap items created or reordered.

> 🟢 **WAVE 0 COMPLETE (2026-06-25)** — `docs/WAVE0_TRIAGE_AND_GATES_CERTIFICATION.md`. Gates green, finance findings verified real vs live edge, quality-gate drift closed + CI-enforced. Resolved: TST-1, TST-2, TST-4, T-DRIFT, SEC-7/PRN-2, analyze warnings.
>
> 🟢 **WAVE 1 COMPLETE (2026-06-25)** — `docs/WAVE1_COMPLETION_CERTIFICATION.md`. Theme A (silent data loss) closed + **live-certified 8/8** + deployed to VPS. Resolved: **CORE-1/PAR-4, TCH-1, TCH-2, TCH-5, STF-7, STF-8, CORE-2** (annotated below). PTM backend build is the one deferred half of CORE-1/PAR-4 (feature gated off until built).
>
> 🟢 **WAVES 2–4 COMPLETE** — Wave 2 (multi-child + demo purge, live 21/21), Wave 3 (contract gaps + entitlement client + security, live 30/30), Wave 4 (AI moderation gate + perf, live 20/20). See the respective `docs/WAVE{2,3,4}_COMPLETION_CERTIFICATION.md`.
>
> 🟢 **WAVE 5 COMPLETE (2026-06-26)** — `docs/WAVE5_COMPLETION_CERTIFICATION.md`. Themes H (UX consistency/a11y) + J (Play custody) + the Low cleanup batch closed + **live-certified 15/15** (`scripts/qa/live_cert_completion_wave5.py`) + deployed (migration `20260803000000` + 4 edge files). Resolved: **UX-1..UX-8, PLY-3, PLY-4, NOT-1, NOT-3, PERF-4, TST-3, STF-6, AI-4**. **Owner-gated remaining:** PLY-1 (privacy legal values), PLY-2 (keystore custody). **By-design/documented:** CORE-4, SUP-3/4, MKT-1/2/3, INT-1/3, NOT-2, STF-9, PERF-3, TST-5. With this, **every Critical + High in the audit is closed**; only owner-gated PLY-1/PLY-2 + by-design Lows remain.

> ⚠️ **Standing caveat (updated by Wave 0):** This was a **source-tree** audit. The `[verify-vs-deployed-edge]` finance findings (STF-1..5, STF-4, INT-2) have now been **verified against the live VPS edge** (`/opt/akshara/functions`, 2026-06-25): the contested routes are **confirmed absent on production** → they are **real gaps**, scheduled for Wave 3 (the tag is resolved). Memory note `no-production-backend-yet` is superseded by the live VPS work; several `docs/` readiness files (e.g. `PRODUCTION_READINESS_FINAL.md`, `AKSHARA_V1_FINAL_SIGNOFF.md`, `PLAY_STORE_AND_NOTIFICATIONS_READINESS.md`) remain **stale** relative to the B-series and FCM batches.

---

## 1. Executive Summary

Akshara is a large, genuinely production-shaped ERP: **1,585 Dart files, 502 Flutter test files, a Supabase edge backend with 79 migrations, and 30+ PRODUCTION-CERTIFIED batches.** The architecture is sound end-to-end — per-module live/mock flag selection, fail-closed JWT auth, per-persona RLS, a real audit framework, server-side pagination, a coherent "Premium School OS" design system, and real Claude-backed AI with safe deterministic fallback. Director portal, Marketing engine, AI predictions, Question-Intelligence, FCM push, and the core money/HR loops are live, certified, and confirmed still-wired.

The product is **pilot-ready on the "happy path"** (single-child parent, single teacher persona, certified core loops) but is **not yet GA-clean**. The audit found **2 Critical** defects and **21 High** defects concentrated in a few repeating themes rather than scattered randomly:

1. **In-memory/mock writes left in live paths** — Teacher *homework-create* and *compose-message-send* silently don't persist (the 2 Criticals); exam remarks, Parent Meetings, branch/franchise, HR reports, and several "Settings → Edit" screens write to memory or "preview mode" only.
2. **Multi-child parent correctness** — the client never sends `activeChildId`, so multi-child parents systematically see their *first* child's data across fees/exams/attendance/etc., and the child switcher doesn't invalidate those providers.
3. **Demo/persona identity leakage** — hardcoded names (`Priya Sharma`, `Ravi Kumar`, `child_ravi`, `principal_001`) and `"(mock)"` strings surface in live UI across Parent, Teacher, and Principal surfaces.
4. **Client↔backend contract gaps** — a cluster of finance peripheral routes (offline/QR/defaulters/reports/settings/scholarship/discounts-read) the live client calls but the edge source doesn't implement **[verify-vs-deployed-edge]**.
5. **AI moderation/export gate** — rejected/unmoderated AI question-paper items can reach a student-facing paper through an ungated export path.
6. **Security hardening** — one unauthenticated fail-open webhook; the legacy communication module's mutations (incl. broadcasts) are unaudited; parent-experience handlers rely on RLS alone with no defense-in-depth child check.
7. **Quality-gate drift** — `flutter test` has 7 reds (2 stale mock-count asserts + 5 stale goldens), no CI runs the test/golden gate, and no Patrol/integration journey exercises the live backend.

None of the Criticals/Highs are architectural; all are bounded, localized, and fixable inside the existing patterns. **Estimated remediation: ~2 focused completion waves** (see `FINAL_COMPLETION_ROADMAP.md`).

---

## 2. Production Readiness

**Overall production readiness: ~85%** — pilot-ready with conditions; GA after Waves 1–2.

| Area | Readiness | Headline gap |
|------|----------:|--------------|
| ERP Core (data/routing/DI) | 93% | Parent Meetings mock-only but live-reachable |
| Parent App | 72% | Multi-child scoping broken (wrong child shown) |
| Student App | 78% | Homework submission content-less; stale dashboard seed |
| Teacher App | 80% | **2 Critical**: homework-create + compose-send don't persist |
| Staff/Admin | 80% | Finance peripheral routes 404 in live |
| Principal | 92% | Admissions review panel shows fabricated context |
| Director Portal | 98% | None (fully certified) |
| Super Admin | 80% | `ENTITLEMENT_API_ENABLED` off → entitlement UX dark |
| AI Features | 88% | Rejected AI questions can reach student paper |
| Marketing | 95% | FB/IG owner-gated (by design) |
| Notifications | 90% | Per-event deep links unpopulated |
| Integrations | 92% | Defaulters WhatsApp has no backend |
| Security | 85% | Fail-open delivery webhook; unaudited broadcasts |
| Performance | 80% | Broadcast dispatch unbounded N+1 |
| UX & Accessibility | 88% | Raw error strings leak to users |
| Testing | 85% → 92% | ✅ 7 reds + CI gate fixed (Wave 0); patrol live-E2E remains (TST-3/5) |
| Play Store | 90% | Privacy placeholders; keystore custody |

---

## 3. Issue Count by Severity

Counts shown as **at audit → remaining after Wave 1**. Wave 0 closed 6 (TST-1/2/4, T-DRIFT, SEC-7, PRN-2). Wave 1 closed 7 (2 Critical TCH-1/TCH-2 + 2 High TCH-5/CORE-1(=PAR-4) + 3 Medium STF-7/STF-8/CORE-2).

| Severity | At audit | Remaining | Definition |
|----------|------:|------:|------------|
| **Critical** | 2 | **0** | Live user action silently fails / data lost; blocks core loop |
| **High** | 21 | **18** | Wrong data shown, route 404 in live, security fail-open, broken core sub-flow, release blocker |
| **Medium** | ~34 | **~28** | Degraded but non-blocking; mock/preview-only secondary flows; UX/perf/audit gaps |
| **Low** | ~35 | **~33** | Cosmetic, by-design owner-gated, dead code, doc staleness, test hygiene |
| **Total** | **~92** | **~79** | |

---

## 4. Verification Results (run by coordinator, this audit)

Two columns shown: **At audit (2026-06-25 AM)** → **After Wave 0 (2026-06-25 PM)**.

| Gate | At audit | After Wave 0 ✅ |
|------|----------|-----------------|
| `flutter analyze` | 105 issues, 0 errors | **0 issues** (CI now `--fatal-infos`) |
| `flutter test` | 2376 passed, 1 skipped, **7 FAILED** | **2383 passed, 1 skipped, 0 failed** |
| backend `deno test` | 662 passed, **1 FAILED** (`approval_router_test.ts` env) | **665 passed, 0 failed, 2 ignored** |
| Patrol journeys | 127 files, all **mock-backed** (no live-VPS journey) | unchanged — addressed in Wave 5 (TST-3) |
| Live E2E vs VPS | not exercised by the suite (live proof via `scripts/qa/*`) | unchanged — Wave 5 (TST-3) |

> The earlier `AKSHARA_V1_FINAL_SIGNOFF.md` "0 issues / 1688 passed" baseline had **drifted** (T-DRIFT). **Wave 0 closed the drift** and CI now enforces the 0-issue bar so it can't recur. Patrol/live-E2E coverage (TST-3/TST-5) remains for Wave 5.

---

## 5. Detailed Findings by Module

Severity key: **C**ritical / **H**igh / **M**edium / **L**ow. Effort: **S** (<½ day) / **M** (½–2 days) / **L** (2+ days). IDs are referenced by `FINAL_COMPLETION_ROADMAP.md`.

### 5.1 ERP Core — 93%
| ID | Description | Evidence | Sev | Effort |
|----|-------------|----------|:---:|:---:|
| ~~CORE-1~~ ✅ | **RESOLVED (Wave 1):** gated OFF via `SchoolBuildScope` (backend build deferred). Was: Parent Meetings (PTM) **mock-only but a live-reachable route**; scheduling/summary writes go to in-memory mock, lost on restart, no backend exists. *(cross-cuts Parent)* | `repository_providers.dart:389-392`; `app_router.dart:882`; `route_guards.dart:92`; `FINAL_TRUTH_AUDIT.md:214` | H | M |
| ~~CORE-2~~ ✅ | **RESOLVED (Wave 1):** `/branches` now chain-gated via `ChainScope` (unreachable in single-school pilot). Was: Branch & Franchise repositories mock-only with no API path (chain-only; hidden by `SchoolBuildScope` for school pilots → unreachable today, but non-persistent for any chain org). | `repository_providers.dart:351-357`; `FINAL_TRUTH_AUDIT.md:58,112` | M | L |
| CORE-3 | `tenantContextProvider` falls back to `TenantContext.demo` (`tenant_demo_001`) when claims null; dead in prod (hardened login logs out on null claims; RLS uses JWT) but ships demo identifiers — wants a defensive guard. | `tenant_provider.dart:21-27`; `auth_provider.dart:108-114` | L | S |
| CORE-4 | Dead fallback scaffolding: `withMockWriteFallback` triggers only on `ApiNotConnectedException`, which is **never thrown in `lib/`** — all 6+ hybrid mock-write branches are unreachable dead code that obscures true live behavior. | `hybrid_write_fallback.dart:8-12`; `api_exception.dart` (no throw sites) | L | S |

*Covered by certs (clean):* API/contract parity, route-guard privilege-escalation hardening, live-mode wiring, error mapper (401/403/5xx/timeout/network/404 all explicit, none swallowed).

### 5.2 Parent App — 72%
| ID | Description | Evidence | Sev | Effort |
|----|-------------|----------|:---:|:---:|
| PAR-1 | **Multi-child scoping broken:** fees/exams/receipts/attendance/homework/timetable/notices/events reads never send `activeChildId`; backend defaults to `child_ids[0]` → switching child shows the **first** child's data. (RLS itself safe.) | `parent_remote_datasource.dart:185-191`; `mobile_read_handlers.ts:51-65` | H | M |
| PAR-2 | Child switcher invalidates only dashboard/experience-hub/profile — **not** fees/exams/receipts/attendance — so those keep stale data after switching child. | `parent_active_child_provider.dart:49-55`; `parent_child_switcher_sheet.dart:45-46` | H | S |
| PAR-3 | Leave application **hardcodes `childId:'child_ravi'`** (live write path) — a multi-child parent always files leave against the demo child. | `parent_leave_provider.dart:83` | H | S |
| ~~PAR-4~~ ✅ | **RESOLVED (Wave 1):** parent PTM route gated off via `SchoolBuildScope` (= CORE-1). Was: Parent PTM view reads the mock-only meetings repo and resolves child via `MockCanonicalStudentRegistry` (`child_ravi` fallback); no live PTM data. *(same root as CORE-1)* | `parent_ptm_provider.dart:42-54` | M | M |
| PAR-5 | Receipts/dashboard headers hardcode `childName:'Ravi Kumar'`, `childClass:'8-A'`, `unreadNotifications:2` regardless of real child. | `parent_receipts_provider.dart:77-80`; `parent_dashboard_provider.dart:44-49` | M | S |
| PAR-6 | Dashboard child-switch is cosmetic: `forActiveChild` rewrites copy with hardcoded `isPriya` demo branches; `getDashboard` sends no child id, so real per-child dashboard isn't refetched. | `parent_dashboard_provider.dart:170-216,307-313` | M | M |
| PAR-7 | Real-auth linked children built with `name:'Child'` + empty class → multi-child switcher shows indistinguishable "Child" entries. | `auth_role_mapping.dart:29-41` | M | M |
| PAR-8 | Transport allocation resolves active child via `MockCanonicalStudentRegistry`, falls back to `items.first` on no match — can show another child's bus. | `parent_transport_provider.dart:12-29` | M | M |
| PAR-9 | Notices/events list-payload header fields (child + unread badge) hardcoded though lists are live. | `parent_notices_provider.dart:62-65`; `parent_events_provider.dart:33-45` | L | S |

*Covered by certs (clean):* Parent Insights (B3, per-child), results→parent & fee→parent receipts (FULL_LIVE_JOURNEY), messages send/persist, leave-submit persists+audited. **Common thread: single-child parents work (the certified path); multi-child + demo-identity leftovers are the gap.**

### 5.3 Student App — 78%
| ID | Description | Evidence | Sev | Effort |
|----|-------------|----------|:---:|:---:|
| STU-1 | Homework submission is content-less one-tap "mark submitted" — UI sends empty `notes`, no attachment (no file picker/notes field), backend stores empty submission. | `student_homework_provider.dart:65-74`; `student_requests.dart:1-12`; `pilot_operations_repository.ts:189-226` | H | M |
| STU-2 | **Overdue homework cannot be submitted** — Submit button only renders for `status==pending`; no late-submit path though backend accepts any homeworkId. | `homework_list_row.dart:99-100`; `student_homework_screen.dart:128-129` | H | S |
| STU-3 | No success/error feedback on homework submit — awaited bool discarded; failure shows nothing. | `student_homework_screen.dart:130-135`; `student_mutations_provider.dart:43-59` | M | S |
| STU-4 | Student home dashboard tiles are **stale seed data** (no live overlay, unlike detail screens) — today's schedule/attendance KPI/homework-due/exam reminder can contradict live detail screens. | `student_handlers.ts:8-9`; `mobile_read_handlers.ts` (student snapshot overlays only `snapshot_exams`) | M | M |
| STU-5 | "Upcoming Exams" never overlaid with real scheduled exams (`overlayExamsSnapshotFromResults` sets only `examResults`). | `pilot_operations_repository.ts:866-918` | M | M |
| STU-6 | Dashboard AI insight is static snapshot text, not the real Claude copilot (only the action button opens real AI). | `student_mapper.dart:203-208` | L | S |
| STU-7 | `join_class` quick action is non-functional (routes to timetable; no live-class feature) — implies a capability that doesn't exist. | `student_navigation.dart:38-39` | L | S |

*Clean:* RLS solid (student_id from JWT, org+school+student WHERE on every read); empty/error/loading states present on all student screens.

### 5.4 Teacher App — 80%
| ID | Description | Evidence | Sev | Effort |
|----|-------------|----------|:---:|:---:|
| ~~TCH-1~~ ✅ | **FIXED (Wave 1, live-certified):** Homework CREATE never persisted — writes only to in-memory `SchoolHomeworkStore.instance`; no repository/mutation call, no `createHomework` on `TeacherRepository`. Lost on restart, never reaches students/parents in live mode. | `teacher_homework_create_screen.dart:135-162` | **C** | M |
| ~~TCH-2~~ ✅ | **FIXED (Wave 1, live-certified):** Compose-message SEND was a no-op — `sendComposedMessage` clears the draft and flips the tab; never calls `sendTeacherMessageProvider`. The "Message sent (mock)." snackbar is literally true. (In-thread reply IS wired.) | `teacher_messages_provider.dart:46-52`; `teacher_messages_screen.dart:235-247` | **C** | M |
| TCH-3 | "Students needing attention"/risk fabricated client-side from `MockCanonicalStudentRegistry` + synthetic snapshots — never the backend or the certified B9 engine. | `teacher_student_risk_service.dart:74-99` | H | M |
| TCH-4 | Hardcoded teacher persona in app-bar subtitle of 4 screens (`"Priya Sharma · Mathematics"` / `"Priya Sharma"`) — every teacher sees the demo name. | `teacher_attendance_screen.dart:36`; `teacher_exams_screen.dart:36`; `teacher_homework_screen.dart:32`; `teacher_messages_screen.dart:39` | H | S |
| ~~TCH-5~~ ✅ | **FIXED (Wave 1, live-certified):** Exam remarks persisted only to a `SharedPreferences`-backed in-memory singleton; `ExamAdministrationRepository` has no remark method → never sent to backend, invisible to other devices/roles. | `exam_marks_entry_provider.dart:219-260`; `exam_administration_persistence.dart:5-12` | H | M |
| TCH-6 | `"(mock)"` text shipped in production success snackbars (leave-submit & compose) — underlying leave call IS real; string is demo-revealing. | `teacher_leave_screen.dart:232`; `teacher_messages_screen.dart:241` | M | S |
| TCH-7 | Demo-data side effects in `build()`: `seedDemoSubjectConcernIfNeeded()` injects mock concerns on every rebuild of class-teacher/parent-communication screens. | `teacher_class_teacher_dashboard_screen.dart:22`; `teacher_teaching_context_provider.dart:198-211` | M | S |
| TCH-8 | Homework-create form pre-filled with demo defaults ("8-A", "Mathematics", "Ravi Kumar") submittable unchanged. | `teacher_homework_create_screen.dart:27-31` | M | S |
| TCH-9 | Timetable day-selector chips all show date "1" (`DateTime(2026,6,1)`); cosmetic only (periods render correctly). | `teacher_timetable_screen.dart:85` | L | S |
| TCH-10 | Duplicate import of `api_failure.dart` (matches analyze warnings; no functional impact). | `exam_marks_entry_provider.dart:3,7` | L | S |

*Clean:* attendance save/submit, homework *review*, leave submit, parent-communication send, attendance-correction approval, in-thread reply — all genuinely wired + audited; teacher-scope enforced server-side; Question-Intelligence covered by its cert.

### 5.5 Staff/Admin — 80%
| ID | Description | Evidence | Sev | Effort |
|----|-------------|----------|:---:|:---:|
| STF-1 | Finance **offline-payment** routes (`GET/POST /finance/payments/offline`, `/reconcile`) absent from edge; client calls them with `FINANCE_API_ENABLED:true` → 404, breaks reconciliation. **[verify-vs-deployed-edge]** | `finance_router.ts` (no match); `finance_remote_datasource.dart:201-234`; `finance_api_paths.dart:7,26` | H | M |
| STF-2 | Finance **QR/UPI** session routes absent (`POST /finance/payments/qr`, `.../qr/{id}[/confirm]`) → QR screen fails live. **[verify-vs-deployed-edge]** | `finance_router.ts` (no match); `finance_remote_datasource.dart:154-188` | H | M |
| STF-3 | Finance **defaulters / reports / settings** routes absent (`GET /finance/defaulters`, `/reports`, `GET/PUT /finance/settings`) → those screens 404 live. **[verify-vs-deployed-edge]** | `finance_remote_datasource.dart:236,277,287,464` | H | M |
| STF-4 | **Discounts dashboard READ** route absent — router has only `POST/PUT`; client `GET /finance/discounts` → screen load 404 (writes work per B5). **[verify-vs-deployed-edge]** | `finance_router.ts:217,221`; `finance_remote_datasource.dart:267` | H | S |
| STF-5 | **Scholarship** create/update routes absent (`POST/PUT /finance/scholarships`); reachable from workflow actions. **[verify-vs-deployed-edge]** | `finance_remote_datasource.dart:406,420` | M | M |
| STF-6 | Hostel report "Download" buttons dead for every report except `rpt_5` (non-null handler hides the no-op). | `hostel_reports_screen.dart:160-164` | M | S |
| ~~STF-7~~ ✅ | **FIXED (Wave 1):** wired to `getDashboard` + real PDF/CSV export. Was: HR Reports data `HrReportsData.mock()` (not backend-wired); report export app-wide is preview-only ("Export pipeline not connected yet") — no file produced. | `hr_reports_provider.dart:13`; `operational_action_feedback.dart:17` | M | M |
| ~~STF-8~~ ✅ | **FIXED (Wave 1):** the 5 no-op edit affordances removed (no write path exists). Was: "Settings → Edit" preview-only in 5 modules (HR, transport, alumni, control-center settings + roles); HR Recruitment & Performance read-only (no stage-advance/hire/review mutations). | `hr/settings/...:131`; `transport/settings/...:136`; `platform/control_center/settings/...:135`, `.../roles/...:118`; `alumni/settings/...:133` | M | M |
| STF-9 | Misc lows: `PUT /finance/student-accounts/{id}` route missing but no UI caller (dead code); school-config `apply()` lacks write-layer RBAC (route-guarded only); transport GPS map + hostel visitor QR are honest unbuilt placeholders; admin profile-menu "coming soon" cosmetic. | various | L | S |

*Clean:* core money loop (collections/receipts/invoices/fee-structures/refunds/assignment), HR employees/leave/payroll, inventory/library/transport/hostel CRUD — repository-backed, audited, RBAC-gated (Batch 5 / HR certs). Management FY/Q filter now flows into query (remediated).

### 5.6 Principal — 92%
| ID | Description | Evidence | Sev | Effort |
|----|-------------|----------|:---:|:---:|
| PRN-1 | Admissions approval review panel **fabricates decision context** — counselor notes, fee-plan label, workflow steps, approval history are hardcoded (`'Meera N.'`, `'Standard CBSE · 3 installments'`, `'Principal Sharma'`); queue list is live but the context the principal decides on is fake. | `admissions_approval_provider.dart:83-127` | M | M |
| ~~PRN-2~~ ✅ | ~~`approval_router_test.ts` cannot load → `routeApproval` has no passing unit coverage.~~ **FIXED (Wave 0):** self-contained `AppConfig` literal; the 3 approval-router tests now pass (deno 662→665). | `approval_router_test.ts` | ~~L~~ | done |
| PRN-3 | Approval actor falls back to synthetic `'principal_001'` if claims null at decision time → attributes approval to a non-existent principal in the audit trail. Prefer fail-closed. | `approval_center_provider.dart:201-208` | L | S |

*Clean:* approval center real + RBAC-gated (`APPROVAL_API_ENABLED` on, `assertApprovalPermission`); question-paper validation principal-only (`approveEducation`); management mutations real + audited.

### 5.7 Director Portal — 98%
No real gaps. Org-scope SQL aggregation, RBAC (`view/manageDirectorPortal` + org-scope guard), `module.multi_branch` entitlement gate, metric-input write, board-pack PDF, real-AI exec summary all verified live-wired; hybrid repo falls back to mock only on true unreachability (not on 402/403/500). *Covered by B8_DIRECTOR_MULTI_SCHOOL.*

### 5.8 Super Admin — 80%
| ID | Description | Evidence | Sev | Effort |
|----|-------------|----------|:---:|:---:|
| SUP-1 | **`ENTITLEMENT_API_ENABLED` omitted from `live_release.json`** → in release builds the client entitlement layer is off: plan ceiling unrestricted, subscription = Trial placeholder, plan catalog empty. G6a/b/c locked-module UX, plan badges, upgrade CTAs render nothing. Server enforcement still works (B2-certified), but client never reflects/explains the 402. | `config/live_release.json` (no key — confirmed 0 matches); `entitlement_provider.dart:27,44,77-87` | H | S |
| SUP-2 | Super-admin Organization-Plan-Assignment screen depends on the empty `planCatalogProvider` → in-app plan assignment non-functional even though `PUT /platform/organizations/:id/subscription` exists (B2 certified via script, not the screen). Resolves with SUP-1. | `organization_plan_assignment_screen.dart:66-67,206` | H | S |
| SUP-3 | `platform_operations`, `multi_school`, `white_label`, `branch`, `franchise` have **no `_shared/` backend module** and are mock-only stubs (correctly OFF in live config so they don't 404, but shipped UI with no live path). | `repository_providers.dart:351-357,559-611`; `ls _shared/` | M | L |
| SUP-4 | Verticals (restaurant/salon/healthcare/accommodation) mock-backed, no live flag — **intentional frozen P4/B12 scope**, not a regression. | `repository_providers.dart:569-601`; `live_release.json` _comment | L | — |

*Clean:* entitlement server enforcement (`ENTITLEMENT_ENFORCEMENT=true`, all module routers `withEntitlement`), Org-Builder backend + provisioning (B10), widget platform (B11).

### 5.9 AI Features — 88%
| ID | Description | Evidence | Sev | Effort |
|----|-------------|----------|:---:|:---:|
| AI-1 | **Rejected/unmoderated AI question-paper items can reach the student paper** — `moderatePaperItem` only sets `review_status='rejected'` (row stays); publish gate counts only `pending`; export maps ALL items with no review-status filter → a human-disapproved AI question + answer prints into the student paper. | `education_repository.ts:533,578,682-689`; `education_mapper.ts:146`; `education_handlers.ts:873` | H | M |
| AI-2 | Export endpoint (`handleExportQuestionPaper`) requires only `viewEducation` and exports any paper state (draft/submitted, incl. `pending`/`rejected` items) — bypasses the publish gate. | `education_handlers.ts:857-877` | M | S |
| AI-3 | Publisher AI caption enhancer uses env-only `aiApiKey()`/`claudeModel()` instead of `resolveAiConfig(db,orgId)` — an org configuring AI only via the Control Center panel silently gets deterministic captions. | `promotion/publisher_ai_captions.ts:8,31` | L | S |
| AI-4 | "AI poster generation" emits metadata + captions only — no rendered image (`previewUrl`/`downloadUrl` always null while `imageGenerationReady:true`). Intentional (hosting owner-gated) but the flag misleads. | `promotion/promotion_asset_service.ts:50-53` | L | M |
| AI-5 | `bankReuseCount`/`aiGeneratedCount` chips read 0 — Flutter parses top-level, backend emits inside `blueprint`. Cosmetic composition-chip bug. | `education/mapper/education_mapper.dart:155-156` | L | S |

*Clean (cert-covered):* copilot, parent insights, admissions assistant, AI school builder, all 3 predictions (Enterprise `feature.ai_predictions` gate enforced), director exec summary, question-paper bank-first solver (approve/pending paths). Real AI needs `ANTHROPIC_API_KEY`/`OPENROUTER_API_KEY` on VPS or an active Control Center panel config; otherwise degrades safely to deterministic output. Model id `claude-opus-4-8` correct.

### 5.10 Marketing — 95%
| ID | Description | Evidence | Sev | Effort |
|----|-------------|----------|:---:|:---:|
| MKT-1 | FB/IG channels require owner Meta setup to leave dry-run (records `dry_run`/`pending_connection` until then). By design. | `meta_graph_client.ts:22-29`; `social_publish_service.ts` | L | — |
| MKT-2 | Social poster photo post needs a public poster URL; if generation emits none, FB/IG posts degrade to text-only. | `publisher_dispatch.ts:131-138` | L | M |
| MKT-3 | Calendar-admin Flutter screen is a noted minor remaining client task (events createable via API today). | HOLIDAY_PUBLISHER_PHASE1 cert | L | S |

*Clean:* publisher create→AI poster+captions→approve→publish fan-out to parent/student/teacher/staff + WhatsApp + website; Growth engine double-gated by `module.marketing` (B6).

### 5.11 Notifications — 90%
| ID | Description | Evidence | Sev | Effort |
|----|-------------|----------|:---:|:---:|
| NOT-1 | Per-event deep links largely unpopulated: client honors `data.route` and payload supports it, but enqueue paths (incl. publisher) don't set `route` → most pushes land without a specific deep link (category fallback only). | `publisher_dispatch.ts:74-82`; `notification_providers.ts:132` | M | M |
| NOT-2 | iOS push not enabled (needs `GoogleService-Info.plist`, `DefaultFirebaseOptions.ios`, APNs .p8); cleanly stubbed, Android-only by design. | FCM cert; `firebase_options.dart` | L | M |
| NOT-3 | Stale doc: `PLAY_STORE_AND_NOTIFICATIONS_READINESS.md` still says push "not yet wired" — superseded by FCM cert (push IS live). | doc vs FCM_PUSH_HTTP_V1 | L | S |

### 5.12 Integrations — 92%
| ID | Description | Evidence | Sev | Effort |
|----|-------------|----------|:---:|:---:|
| INT-1 | Real FB/IG posting + transactional fee/result SMS are owner-gated (Meta App Review/secrets; `TRANSACTIONAL_SMS_ENABLED=true`). Code complete, auto-activates. | `config.ts:119`; SOCIAL_MEDIA_PHASE2 | L | — |
| INT-2 | Fee-defaulters WhatsApp surface has **no backend** (`/finance/defaulters` absent — see STF-3); button degrades gracefully but shows no live numbers. | B5 cert live table | M | M |
| INT-3 | Inventory-vendor WhatsApp surface forward-compatible only (0 vendor records seeded). | B5 cert live table | L | S |

*Clean:* WhatsApp `wa.me` deep-links live across surfaces (normalization fixed+tested); Social Phase 2 OAuth + AES-256-GCM token storage deployed (dry-run); Fast2SMS OTP live; Supabase Storage present.

### 5.13 Security — 85%
| ID | Description | Evidence | Sev | Effort |
|----|-------------|----------|:---:|:---:|
| SEC-1 | **Fail-open route:** `POST /communications/delivery/webhook` runs `UPDATE notification_deliveries` with **no auth, no HMAC/shared-secret**, and fabricates `system-webhook` claims with **hardcoded tenant/school UUIDs**. Any unauthenticated caller can flip delivery statuses (bounded to that one tenant + status column). | `communication_handlers.ts:446-490`; router `:37` | H | M |
| SEC-2 | Broadcast + all communication mutations **unaudited** (createBroadcast, process-queue, send-message, mark-read, device-token register/unregister, webhook) — legacy module predates the B-series audit framework. | `communication_handlers.ts` (no `emitMutationAudit`) | M | M |
| SEC-3 | Parent-experience handlers rely **solely on RLS, no defense-in-depth**: `requireParentScope` checks only the permission, never asserts `scope==="parent"`; `studentId` taken from query/body and passed to DB without a `claims.child_ids` check (unlike `mobile_read_handlers.ts`). Safe today only because the sensitive tables carry parent RLS. | `parent_experience_handlers.ts:18-20,32-44,74-92` | M | S |
| SEC-4 | Missing parent-scope RLS on `intel_parent_guidance_reports` (only `*_school_scope`). With SEC-3 this is the table that would leak if it ever gained a parent read path; currently returns empty for parent tokens (functional gap). | `migrations/20260621000000_intelligence_layer_foundation.sql:113` | L | S |
| SEC-5 | `handleSaveStep` (org-builder interview) and `handleResetRoleLayout` (widget layout) perform real writes with no `emitMutationAudit`. | `organization_builder_handlers.ts`; `widget_layout_handlers.ts:~236` | L | S |
| SEC-6 | RBAC route inventory incomplete & not enforced against live routers: omits `/predictions/*`, `/director/*`, `/platform/org-builder/*`, `/platform/subscriptions`, `/communications/delivery/webhook`, `/widgets/data/refresh`; validation test only cross-checks the static list against itself. (Handlers DO enforce in code.) | `rbac_route_inventory.ts:12-154`; `rbac_route_validation_test.ts:36-76` | L | M |
| ~~SEC-7~~ ✅ | ~~Test-env fragility: `approval_router_test.ts` `loadConfig()` at module top-level throws at collection.~~ **FIXED (Wave 0):** test now uses a self-contained `AppConfig` literal (no env, no cross-file leak); deno suite green. (`tenant_isolation_enforced_test.ts` was already correctly guarded by `ERP_TENANT_DATABASE_URL`.) | `approval_router_test.ts` | ~~L~~ | done |

*Verified strong:* fail-closed JWT verify; hashed OTP + multi-layer rate limiting; refresh-token reuse detection revokes family; SECURITY DEFINER fns scoped (`SET search_path`, `REVOKE FROM PUBLIC`, `GRANT erp_tenant`); exam marks scoped by real `teacher_subject_assignments` (S1/S2 remediated); parent-per-child + student-own-data RLS verified on sensitive tables; no secrets in repo. RED_TEAM "/principal-command, /growth unguarded" claim is **stale** (both guarded).

### 5.14 Performance — 80%
| ID | Description | Evidence | Sev | Effort |
|----|-------------|----------|:---:|:---:|
| PERF-1 | School-wide broadcast/notification dispatch is an **unbounded sequential N+1**: `resolveBroadcastRecipients` returns all recipients uncapped, then 2 awaited writes per recipient, then `processDeliveryQueue` loops again — all synchronous in the HTTP request. At hundreds–thousands of parents → slow / edge-timeout-prone. | `communication_service.ts:218,244`; `notification_service.ts:55-90`; `publisher_dispatch.ts:71-85`; `communication_repository.ts:476` | H | M |
| PERF-2 | SIS registry search fires a backend fetch on **every keystroke** (no debounce) → request storm + cost in live mode. No debounce utility exists in `lib/`. | `sis_registry_screen.dart:118-119`; `sis_registry_provider.dart:53-84` | M | S |
| PERF-3 | 53 missing `prefer_const` (from analyze) → minor avoidable rebuilds; F5 profiling deferred. | `PERFORMANCE_CERTIFICATION_REPORT.md:74` | L | S |
| PERF-4 | Cold-start (<3s) and live-API p95 latency **never measured** — only mock-repo stopwatch benchmarks exist (cert flags F1/F2 as open). | `PERFORMANCE_CERTIFICATION_REPORT.md:72-73` | M | L |

*Clean:* server-side pagination wired end-to-end (cap 100); virtualized `ListView.builder` for data tables; 210 indexes across migrations; sane Dio timeouts; negligible assets (28K); no N+1 in dashboard aggregation.

### 5.15 UX & Accessibility — 88%
| ID | Description | Evidence | Sev | Effort |
|----|-------------|----------|:---:|:---:|
| UX-1 | Hand-rolled error states bypass `AksharaErrorState` — raw `Text('Error: $e')`, no retry, **leaks raw exception strings to users** (~42 screens). | `intelligence_screen.dart:139`; `employee_360_screen.dart:70`; `education_question_paper_detail_screen.dart:38`; `platform_operations_hub_screen.dart:788` | H | M |
| UX-2 | Design-token drift grew: 54 files use raw `Theme.of(context).textTheme` vs 223 on `context.aksharaText` (prior audit ~46 → +8 regression). | `director_dashboard_screen.dart:117`; `dynamic_widget_registry_screen.dart:52` | M | M |
| UX-3 | Full-screen loading hand-rolled as bare `Center(CircularProgressIndicator())` instead of `AksharaLoadingState` (~83 screens; no semantic label). | `teacher_student_risk_screen.dart:33`; `employee_platform_screen.dart:28` | M | M |
| UX-4 | Hand-rolled empty states as plain `Center(Text('No ...'))` — no illustration/Semantics/action (~6 screens). | `achievement_promotion_screen.dart:110`; `workflow_automation_screen.dart:141` | M | S |
| UX-5 | Off-system `Colors.*` for status (red/orange/green) — breaks dark mode / contrast (34 instances / 19 files). | `intelligence_hub_screen.dart:573-575`; `director_compliance_screen.dart:108` | M | S |
| UX-6 | ~26 of 79 IconButtons have no `tooltip:`/Semantics label — icon-only controls invisible to screen readers. | `dynamic_widget_layout_editor_screen.dart`; `daily_substitutions_screen.dart` | M | S |
| UX-7 | Magic-number `EdgeInsets` bypass `AksharaSpacing` (170 instances / 79 files). | `ai_content_screen.dart:110`; `intelligence_screen.dart:110` | L | M |
| UX-8 | Checkbox theme `MaterialTapTargetSize.shrinkWrap` + `VisualDensity.compact` shrinks tap targets below 48dp. | `app_theme.dart:628-629` | L | S |
| UX-9 | Hardcoded sample names leak into live UI subtitles ("Priya Sharma · Mathematics") — *(cross-cuts TCH-4, PAR-5)*. | `teacher_attendance_screen.dart:36`; `hr_employees_screen.dart:116` | L | S |

*Resolved since prior audit (not counted):* QA persona switcher now prod-gated; 0 dead `onPressed:(){}`; Director portal phone-responsive; KPI text-scale clamped; 0 raster images; no `barrierDismissible:false` traps.

### 5.16 Testing — 85% → **92%** (after Wave 0)
| ID | Description | Evidence | Sev | Effort |
|----|-------------|----------|:---:|:---:|
| ~~TST-1~~ ✅ | ~~SIS mock seed drifted to 11; two tests assert 10 → fail.~~ **FIXED (Wave 0):** placeholder is intended onboarding data; asserts updated to 11. | `repository_test.dart:59`; `sis_providers_test.dart:46` | ~~H~~ | done |
| ~~TST-2~~ ✅ | ~~5 stale goldens (parent dashboard ×3, dark parent dashboard, dark admin hub).~~ **FIXED (Wave 0):** regenerated after confirming intended design shift. | `dark_mode_render_test.dart`; `parent_dashboard_golden_test.dart` | ~~M~~ | done |
| TST-3 | No Patrol/integration journey hits the live backend — all run mock-backed (`enableApiMode:false`). Roadmap-claimed "live E2E" not exercised by the suite. | `patrol_test/helpers/patrol_app.dart:24` | M | M |
| ~~TST-4~~ ✅ | ~~"No CI runs flutter test/goldens"~~ — **finding was inaccurate**: `flutter_ci.yml`→`run_ci_gates.sh` runs analyze + full `flutter test --coverage`, `backend_staging.yml` runs `deno test`. **Wave 0 hardened** Gate 1 to `flutter analyze --fatal-infos` so the 0-issue bar is enforced on PR. | `scripts/qa/run_ci_gates.sh:11`; `.github/workflows/` | ~~M~~ | done |
| TST-5 | Patrol coverage doc admits PARTIAL on P0 flows (parent pay-fee full journey, attendance-correction submit, published-results-after-approval). | `PATROL_COVERAGE_AUDIT.md` | L | M |
| ~~T-DRIFT~~ ✅ | ~~Quality-gate baseline drifted (now 105 analyze + 7 reds).~~ **FIXED (Wave 0):** gates restored to 0 issues / all green; CI `--fatal-infos` prevents recurrence. | this audit §4 | ~~M~~ | done |

*Clean:* zero `@Skip`/`markTestSkipped` across 502 files (good discipline); patrol journey/smoke/workflow structure (PATROL_FINAL).

### 5.17 Play Store Readiness — 90%
| ID | Description | Evidence | Sev | Effort |
|----|-------------|----------|:---:|:---:|
| PLY-1 | Privacy policy hosted (200) but legal content has unfilled placeholders (entity name, registered address, grievance/contact email) — Play data-safety + DPDP grievance officer need real values. | `docs/legal/PRIVACY_POLICY.md:31,32,145,165-168` | H | S |
| PLY-2 | Release upload keystore not present (owner custody) — without `android/key.properties` the release build silently **signs with the debug key**. | `build.gradle.kts` (debug fallback); PLAY_STORE doc `:44` | H | S |
| PLY-3 | minSdk/targetSdk/compileSdk inherit Flutter defaults, not pinned in-repo — can't statically confirm targetSdk meets Play minimum (API 34/35). | `build.gradle.kts:41-42` | M | S |
| PLY-4 | No `ic_launcher_round`; single adaptive xml only. | `res/mipmap-*/ic_launcher.png` | L | S |

*Clean:* real `applicationId=com.akshara.erp`, R8 minify + resource shrink + ProGuard, conditional release signing wired, AAB target in `build_release.sh`, minimal permissions (INTERNET, POST_NOTIFICATIONS), version `18.6.2+187`.

---

## 6. Cross-Cutting Themes

| Theme | Issues | Why it matters |
|-------|--------|----------------|
| **A. In-memory / mock writes in live paths** | TCH-1, TCH-2, TCH-5, CORE-1/PAR-4, CORE-2, STF-7, STF-8 | The two Criticals + several Highs share one root: writes that look successful but never reach the backend. Highest-trust risk. |
| **B. Multi-child parent correctness** | PAR-1, PAR-2, PAR-3, PAR-6, PAR-7, PAR-8 | A whole persona class (multi-child parents) sees wrong-child data. One `activeChildId` plumbing fix resolves most. |
| **C. Demo/persona identity leakage** | TCH-4, TCH-6, TCH-8, PAR-3, PAR-5, PAR-9, PRN-3, UX-9, CORE-3 | Hardcoded `Priya Sharma`/`Ravi Kumar`/`child_ravi`/`principal_001`/`"(mock)"` in shipping UI — looks unfinished, can mis-attribute writes. |
| **D. Client↔backend contract gaps** | STF-1, STF-2, STF-3, STF-4, STF-5, SUP-2, INT-2 | Live client calls routes the edge source doesn't implement → 404. **[verify-vs-deployed-edge]** first. |
| **E. AI moderation/export gate** | AI-1, AI-2 | Reject path + ungated export can leak unapproved AI content to students. |
| **F. Security hardening** | SEC-1, SEC-2, SEC-3, SEC-4, SEC-5, SEC-6 | One fail-open route + audit/defense-in-depth gaps in the legacy comm/parent-experience surfaces. |
| **G. Quality-gate drift** | TST-1, TST-2, TST-3, TST-4, T-DRIFT, analyze 105 | Gates that should be green/CI-enforced are red and unenforced. |
| **H. UX consistency drift** | UX-1..UX-9 | Long-tail admin screens hand-roll states/tokens; one High (raw error leak). |
| **I. Release config switches** | SUP-1/SUP-2, NOT-1 | A single config flag (`ENTITLEMENT_API_ENABLED`) gates the whole paid-plan client UX. |
| **J. Play Store custody** | PLY-1, PLY-2, PLY-3 | Owner-custody legal/keystore items before first AAB upload. |

---

## 7. Summaries

**Test coverage summary.** 502 Flutter test files + 127 Patrol files + 662 backend Deno tests — broad and disciplined (zero skipped markers). Gaps: 7 red Flutter tests (2 stale asserts + 5 stale goldens), 1 red Deno test (env), **no CI enforcement**, and **no live-backend E2E** in the suite (Patrol is mock-only; live proof lives in `scripts/qa/` cert scripts). Coverage of *code* is strong; coverage of the *live integration* and *gate enforcement* is the weak point.

**Performance summary.** Architecturally good — real server-side pagination (cap 100), virtualized data tables, 210 DB indexes, sane Dio timeouts, tiny assets. Two real risks: an unbounded sequential N+1 in broadcast/notification dispatch (PERF-1, scale/timeout risk) and no search debounce (PERF-2). Cold-start and live p95 remain unmeasured (PERF-4).

**UX summary.** The "Premium School OS" system is real and widely adopted with proper Semantics on shared widgets, healthy tap targets, and line-art (no raster) assets; several prior-audit items are resolved. The gap is consistency drift in the long-tail admin/platform screens that hand-roll loading/empty/error states and bypass tokens — one High (raw exception strings shown to users), the rest Medium/Low. Overall 88%.

**Security summary.** Strong core: fail-closed JWT, hashed+rate-limited OTP, refresh-reuse revocation, non-bypass `erp_tenant` role with per-persona RLS, scoped SECURITY DEFINER functions, and audited B-series mutations; the two prior Critical exam-security findings are remediated. Residual: one unauthenticated fail-open webhook (SEC-1, High), unaudited legacy communication/broadcast mutations (SEC-2), and parent-experience handlers leaning on RLS alone (SEC-3) — defense-in-depth, not a confirmed live leak. Overall 85%.

---

## 8. Conclusion

Akshara is a feature-complete, largely-certified ERP that is **~85% production-ready**. There is **no architectural rework** outstanding — every Critical and High is a bounded completion task inside an existing, working pattern. Clearing **Theme A (mock writes), Theme B (multi-child), Theme D (contract gaps), Theme E (AI gate), and SEC-1** lifts the product over the GA line; Themes C/G/H/I/J are the polish-and-prove tail. The prioritized, wave-by-wave execution plan — each item routed through `/gap-check → fix → /certify → /deploy → /release-review` — is in **`docs/FINAL_COMPLETION_ROADMAP.md`**.
