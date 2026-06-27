# AKSHARA — Module Journey Roadmap

**Date:** 2026-06-26  ·  **Source of truth:** `docs/MODULE_JOURNEY_AUDIT.md` (issue IDs referenced below).
**Execution loop for every wave:** `/gap-check → fix → /certify → /deploy → /release-review`.
**Rules:** No new features. No roadmap expansion. This roadmap only *sequences and closes the audit's module-journey findings* — it adds no scope. Waves 0–5 of `FINAL_COMPLETION_ROADMAP.md` and the product roadmap (B1–B11 / P-series) stay closed/frozen.

Effort tags: **S** <½d · **M** ½–2d · **L** 2+d. Totals are engineering estimates, not commitments.

---

## Executive summary

Across 26 module verifications, AKSHARA's certified core is genuinely solid: every prior B-series and Wave cert held up under re-probe (entitlements, finance money-loop, exam lifecycle, approval center, director, control-center, question intelligence, FCM push, admissions CRM/AI, growth engine, org-builder, dynamic widgets all re-verified live with real RBAC). The gaps are NOT in the certified loops — they cluster in three repeatable systemic patterns that a sequenced fix campaign can close. Overall readiness: NOT yet fully production-trustworthy for a multi-module pilot; ~6 Critical and ~22 High issues remain, almost all variations of three root causes. Severity counts (after dedup, 41 surviving items): Critical 6, High 20, Medium 11, Low 4. Headline risks, in order: (1) DATA-INTEGRITY/TRUST — real users are shown fabricated or stale data presented as real (teacher static-snapshot reads, management exec dashboards on seed data, HR per-employee identical templates, parent/student exam & notification demo fallbacks, alumni fabricated profiles, predictions mock students) — this is the single biggest threat to demo credibility and operational correctness; (2) WIRE-GAP 404s — client surfaces ship ahead of backend routes so whole journeys silently fail in live (parent messaging/leave/PTM, teacher exam workflow + parent-communication, admissions 5 tabs, communication templates/history, management settings); (3) LIVE-CONFIG DRIFT — deployed-and-certified backends sit unused because their flag is missing from config/live_release.json (Predictions, Employee Platform, Inventory Distribution). A handful of money/identity-integrity items (homework grade never reaches parent, attendance correction 0-row UPDATE, Razorpay stub-on-disable, finance fake-student dialogs) and RBAC weakenings (attendance marking scope-only, widget per-data bypass) round out the list. No security/tenant-isolation breach was found — RLS and route-level RBAC hold everywhere. Verticals (P4/B12) are correctly frozen and harmless.

---

## How to read this

Findings are grouped into **6 execution waves** ordered by *risk-to-trust* and *unblock-value*, not by module — the same structure as the prior `FINAL_COMPLETION_ROADMAP.md`. Each wave is a coherent batch you can `/gap-check` as a unit, fix, then `/certify` + `/deploy` + `/release-review` together. Run them in order: Wave 0 stops users from seeing fake data as real, Waves 1–2 restore broken/unsafe journeys, Waves 3–4 complete partial surfaces, Wave 5 is polish and regression-safety.

| Wave | Theme | Items | Severity mix | Est. |
|------|-------|------:|--------------|------|
| ~~**Wave 0**~~ | ~~Stop showing fake data as real — live-config drift + demo fallbacks~~ | 8 | 1C + 5H + 1M + 1L | ✅ **DONE 2026-06-26** (live 14/14) — cert: `docs/JOURNEY_WAVE_0_CERTIFICATION.md` |
| ~~**Wave 1**~~ | ~~Data-integrity & money/identity correctness — silent failures that corrupt or hide real records~~ | 7 | 2C + 4H + 1M | ✅ **DONE 2026-06-26** (live **16/16**) — cert: `docs/JOURNEY_WAVE_1_CERTIFICATION.md`; deployed to VPS (10 edge files + migration 20260805000000); gates analyze 0 · flutter 2389 · deno 707 |
| **Wave 2** | Wire-gap 404s — build the missing backend routes so whole client journeys stop failing silently | 10 | Critical x3, High x5, Medium x1 | L x5 + M x4 ≈ 2 batches (split parent/teacher vs admissions/comms/settings if needed) |
| **Wave 3** | Static-snapshot read modernization — apply the live-overlay/recompute framework to remaining personas/admin dashboards | 6 | Critical x2, High x2, Medium x2 | L x4 + M x2 ≈ 2 batches |
| ~~**Wave 4**~~ | ~~Build missing write surfaces & orphaned-feature wiring — complete partial modules and surface hidden paid features~~ | 12 | 1C + 6H + 5M | ✅ **DONE 2026-06-27** (live **28/28**) — cert: `docs/JOURNEY_WAVE_4_CERTIFICATION.md`; 4A client (MJ-C9/H23/H24/M5/M8) + 4B backend (MJ-H19/M9/H20/H21/H22/M6/M7); 2 migrations + 21 edge files deployed; gates analyze 0 · flutter 2416 · deno 825 |
| ~~**Wave 5**~~ | ~~RBAC hardening, error-state UX sweep & test-gate parity — polish, consistency, and regression safety~~ | 10 | Medium x2, Low x3 + grouped UX/RBAC/test items | ✅ **DONE 2026-06-27** (live **24/24**) — cert: `docs/JOURNEY_WAVE_5_CERTIFICATION.md`; MJ-M10/M11/L2/L3/L4/L5/L6/L7/L8/M12; migration 20260807000010 + edge files deployed; gates analyze 0 · flutter 2439 · deno 848 |

---

## Wave 0 — Stop showing fake data as real — live-config drift + demo fallbacks ✅ **COMPLETE (2026-06-26)**

> **Status: DONE.** Cert: `docs/JOURNEY_WAVE_0_CERTIFICATION.md`. Release-review: **GO**. Live cert `scripts/qa/live_cert_journey_wave0.py` **14/14** (real OTP auth/RBAC/data). Gates held: analyze 0 · flutter 2389 · deno 680. No backend/migration change (client + release-config only); all 8 items (MJ-C1/H1/H2/H3/H4/H5/H6/L1) closed.

**Why this wave:** These are the cheapest, highest-trust-impact fixes: deployed-and-certified backends are already live but the release build shows mock data only because a flag is missing from config/live_release.json, and several screens substitute demo data on empty/error. Doing this first immediately makes already-built work visible and removes the worst credibility risks before any new routes are built. Each item is a config edit or a small state-binding change; certifiable as one batch via gap-check→certify→deploy.

**Severity mix:** High x5, Medium x2, Low x1  ·  **Estimate:** Mostly S (7) + 1 M ≈ 1 short batch

| ID | Module | Item | Sev | Effort |
|----|--------|------|-----|-------:|
| `MJ-C1` | Inventory | Add INVENTORY_DISTRIBUTION_API_ENABLED to live_release.json (entire distribution sub-module runs on mock in live) | 🔴 Critical | S |
| `MJ-H1` | AI Features | Add PREDICTIONS_API_ENABLED to config/live_release.json (release build serves mock predictions) | 🟠 High | S |
| `MJ-H2` | Staff | Add EMPLOYEE_API_ENABLED to config/live_release.json (Employee Platform shows mock roster) | 🟠 High | S |
| `MJ-H3` | Notifications | Remove hardcoded demo-notification fallback shown to real parents on empty/initial inbox (+ fake unread badge) | 🟠 High | S |
| `MJ-H5` | Student | Bind student screen loading/error/empty to FutureProvider async state; stop falling back to fabricated 'Ravi Kumar' placeholder data | 🟠 High | M |
| `MJ-H6` | Exams | Stop parent/student exam screens substituting mock grades on live fetch error; surface error/retry instead | 🟠 High | S |
| `MJ-H4` | Finance | Remove fake-student prefills from Create Refund / Create Scholarship dialogs (money-write data-integrity hazard) | 🟡 Medium | S |
| `MJ-L1` | Student | Replace hardcoded 'Ravi Kumar · 8-A' homework header with resolved live identity | ⚪ Low | S |

**Exit criteria:** every item above closed and re-verified live; `flutter analyze` 0 / `flutter test` green / `deno test` green held; `/release-review` verdict **GO**.

---

## Wave Wave 1 — Data-integrity & money/identity correctness — silent failures that corrupt or hide real records ✅ **COMPLETE (2026-06-26)**

> **Status: DONE.** Cert: `docs/JOURNEY_WAVE_1_CERTIFICATION.md`. Live cert `scripts/qa/live_cert_journey_wave1.py` **16/16** (real OTP auth/RBAC/write→read). All 7 items (MJ-C2/H7/H8/H9/H10/H11/M1) fixed at root cause, deployed to the VPS pilot (10 edge `_shared` files + migration `20260805000000_wave1_hr_employee_profile.sql` applied + ledgered), edge restarted. Gates held: analyze 0 · flutter 2389 · deno 707 (+27 Wave-1 tests). Live cert additionally surfaced + fixed a latent `text=uuid` 500 in `reviewHomework` (made reachable by MJ-C2).

**Why this wave:** After the cheap trust fixes, close the silent data-integrity defects where a write succeeds but is wrong, lost, or invisible — these are the items most likely to produce incorrect operational decisions or financial discrepancies and must be airtight before pilot. Grouped because they share the write-then-read-decoupling and gateway-integrity root causes and can be certified together as a correctness batch.

**Severity mix:** Critical x2, High x4, Medium x1  ·  **Estimate:** M x5 + L x2 ≈ 1 substantial batch

| ID | Module | Item | Sev | Effort |
|----|--------|------|-----|-------:|
| `MJ-C2` | Homework | Teacher cannot see or grade any student submission (read never joins homework_submissions) | 🔴 Critical | M |
| `MJ-H7` | Homework | Graded homework grade/status never reaches student or parent (no write-back / read overlay) | 🟠 High | M |
| `MJ-H8` | Homework | Homework delivered to whole school instead of target class (no class filter at fan-out) | 🟠 High | M |
| `MJ-H9` | Attendance | Approved attendance correction never updates the real record (0-row UPDATE: class_label/session_date mismatch) | 🟠 High | M |
| `MJ-H10` | HR | Employee profile serves identical hardcoded manager/docs/leave-balances for every employee | 🟠 High | L |
| `MJ-H11` | Finance | Razorpay confirm can capture without gateway verification if stub mode is disabled without SDK integration (owner-gated) | 🟠 High | M |
| `MJ-M1` | Hostel | Logged visitor never appears on Visitors screen (write→'visitor' list vs read→frozen snapshot_visitors) | 🟡 Medium | L |

**Exit criteria:** every item above closed and re-verified live; `flutter analyze` 0 / `flutter test` green / `deno test` green held; `/release-review` verdict **GO**.

---

## Wave Wave 2 — Wire-gap 404s — build the missing backend routes so whole client journeys stop failing silently — ✅ DONE (PRODUCTION CERTIFIED 2026-06-26, live 28/28; see docs/JOURNEY_WAVE_2_CERTIFICATION.md)

**Why this wave:** These are journeys where the Flutter surface ships but the route 404s in production, breaking core persona loops (parent↔teacher comms, leave, PTM; teacher exam workflow; admissions tabs; communication templates/history; management/admin settings save). They unblock the most user-visible broken paths and share a fix pattern (build/mount the route + add a client↔router path-parity contract test). Grouped as the 'make every shipped screen actually work' batch.

**Severity mix:** Critical x3, High x5, Medium x1  ·  **Estimate:** L x5 + M x4 ≈ 2 batches (split parent/teacher vs admissions/comms/settings if needed)

| ID | Module | Item | Sev | Effort |
|----|--------|------|-----|-------:|
| `MJ-C3` | Parent | Parent↔teacher messaging routes (/parent/messages, /parent/communication/*) not deployed — inbox shows mock, reply no-ops | 🔴 Critical | L |
| `MJ-C4` | Parent | Parent meetings / PTM is mock-only in production (no live repo or backend route) | 🔴 Critical | L |
| `MJ-C5` | Teacher | Teacher exam workflow endpoints (marks-entry/process/publish) 404 — entire marks→publish flow unreachable | 🔴 Critical | M |
| `MJ-H12` | Parent | POST /parent/leave not deployed — parent leave application fails in live | 🟠 High | M |
| `MJ-H13` | Teacher | Teacher parent-communication + subject-concern endpoints have no backend route (404, primary nav tile dead) | 🟠 High | L |
| `MJ-H14` | Admissions | 5 admissions GET endpoints 404 (Reports/Settings/Approval-queue/Enrollment pending+prefill) — 4 nav tabs broken | 🟠 High | L |
| `MJ-H15` | Admissions | Approval review panel shows hardcoded fixture data (fake notes/history/fee-plan) + addApprovalNote has no route | 🟠 High | M |
| `MJ-C6` | Communication | Template-create (POST) and broadcast-history (GET) 404 in live; mock masks both from the test gate | 🟠 High | M |
| `MJ-H16` | Admin | Management settings Save silently 404s (PUT not deployed) yet reports success (shared Principal/Admin path) | 🟠 High | M |
| `MJ-M2` | Notifications | Student inbox calls parent-only route (403→demo fallback); /student/notifications never invoked | 🟠 High | M |

**Exit criteria:** every item above closed and re-verified live; `flutter analyze` 0 / `flutter test` green / `deno test` green held; `/release-review` verdict **GO**.

---

## Wave Wave 3 — Static-snapshot read modernization — apply the live-overlay/recompute framework to remaining personas/admin dashboards

**Why this wave:** The largest systemic trust gap: build one reusable read-overlay/recompute layer (extending the Batch 3/4 parent/student pattern) and apply it to the teacher, management/principal, HR, alumni, and library aggregate reads so they reflect real data and the module's own writes. Sequenced after the wire-gaps because some overlays depend on the now-existing write/read tables; certifiable as a 'reads tell the truth' batch.

**Severity mix:** Critical x2, High x2, Medium x2  ·  **Estimate:** L x4 + M x2 ≈ 2 batches

| ID | Module | Item | Sev | Effort |
|----|--------|------|-----|-------:|
| `MJ-C7` | Teacher | Teacher reads are static seed snapshots with no live overlay (roster/marks/homework/leave/dashboard) | 🔴 Critical | L |
| `MJ-C8` | Principal | Management executive dashboards serve permanently-static seed, not the school's real numbers | 🔴 Critical | L |
| `MJ-H17` | HR | HR dashboard KPIs + AI insight are static seed (148 vs real 3 employees); no recompute | 🟠 High | L |
| `MJ-H18` | Alumni | Alumni dashboard KPIs/donation summary are static seed, never recomputed from live rows | 🟠 High | M |
| `MJ-M3` | Alumni | Alumni profile detail fabricates employment history / events attended / mentorship role in live | 🟡 Medium | M |
| `MJ-M4` | Library | Library dashboard/fines/reports snapshots never recomputed after writes; member.activeLoans stale | 🟡 Medium | M |

**Exit criteria:** every item above closed and re-verified live; `flutter analyze` 0 / `flutter test` green / `deno test` green held; `/release-review` verdict **GO**.

---

## Wave Wave 4 — Build missing write surfaces & orphaned-feature wiring — ✅ **DONE (PRODUCTION CERTIFIED 2026-06-27, live 28/28; see docs/JOURNEY_WAVE_4_CERTIFICATION.md)**

> **Status: DONE.** All 12 items closed: **4A** client-only (MJ-C9 vendor-create + real-vendor PO, MJ-H23 Employee Platform nav, MJ-H24 Promotion/Holiday/Meta nav, MJ-M5 onboarding wizard nav, MJ-M8 HR dialogs honor input) + **4B** backend write surfaces (MJ-H19 transport attendance, MJ-M9 transport delay-notify + SIS identity, MJ-H20 hostel attendance+mess, MJ-H21 library member-enroll + issue-validation + fines + resource URL, MJ-H22 alumni donation + campaign increment, MJ-M6 Org Builder REAL provisioning, MJ-M7 admissions real Storage). 2 forward-only migrations (`20260806000010` org-builder SECURITY DEFINER provisioning, `20260806000020` admissions storage bucket) applied + ledgered; 21 edge files deployed; edge recreated. Live cert caught + fixed 3 real defects (transport allocation PK collision → upsert; Storage `:8080` port in `toPublicStorageUrl` → also fixes device-memories; org-builder empty-name validation). Gates: analyze 0 · flutter 2416 · deno 825 (+35).

**Why this wave:** Close the 'deployed/built but unreachable or write-less' gaps: add UI for deployed writes (transport attendance, hostel attendance/mess, inventory vendor-create + real PO, library members/fines/edit, admissions doc storage), and add nav surfaces for orphaned certified features (Employee Platform/360, onboarding wizard, Promotion Center, Holiday Calendar, Meta-connect). High unblock-value for monetizable surfaces; depends on the prior waves' route/overlay work.

**Severity mix:** Critical x1, High x6, Medium x4  ·  **Estimate:** L x6 + M x6 + S x1 ≈ 2-3 batches

| ID | Module | Item | Sev | Effort |
|----|--------|------|-----|-------:|
| `MJ-C9` | Inventory | Create-PO sends hardcoded mock vendor id → 500; no vendor-create UI exists (blocks entire procurement loop) | 🔴 Critical | M |
| `MJ-H19` | Transport | Transport attendance write endpoint orphaned — no client method or UI to record pickup/drop | 🟠 High | M |
| `MJ-H20` | Hostel | Hostel attendance + mess have no write path (read-only screens, no backend route) | 🟠 High | L |
| `MJ-H21` | Library | Issue/return use mock-seed IDs (garbage member in live); no member-enroll, fines read-only, resources store no file | 🟠 High | L |
| `MJ-H22` | Alumni | No donation write path — donations can never be recorded in live (read-only screen, no route) | 🟠 High | L |
| `MJ-H23` | Staff | Employee Platform/360/role-assignment orphaned (no nav entry); write path unreachable | 🟠 High | M |
| `MJ-H24` | Marketing | Promotion Center + Holiday Calendar + Meta-connect have no reachable UI surface (certified backends idle) | 🟠 High | M |
| `MJ-M5` | Admin | Certified unified onboarding wizard unreachable from app nav (orphaned route) | 🟠 High | S |
| `MJ-M6` | Organization Builder | Provisioning is a documented stub (creates no real tenant) but UI claims 'provisioned successfully' | 🟠 High | L |
| `MJ-M8` | HR | Leave/create-employee dialogs ignore user input (hardcoded employee/type/days/dept/role) | 🟠 High | M |
| `MJ-M9` | Transport | GPS tracking + delay-notify journeys are placeholders (P0 in spec); SIS transport-flag handoff missing | 🟠 High | L |
| `MJ-M7` | Admissions | Document upload stores metadata only — no real file stored/retrievable (Storage not wired) | 🟡 Medium | M |

**Exit criteria:** every item above closed and re-verified live; `flutter analyze` 0 / `flutter test` green / `deno test` green held; `/release-review` verdict **GO**.

---

## Wave Wave 5 — RBAC hardening, error-state UX sweep & test-gate parity — ✅ **DONE (PRODUCTION CERTIFIED 2026-06-27, live 24/24; see docs/JOURNEY_WAVE_5_CERTIFICATION.md)**

> **Status: DONE.** All 10 items closed: **MJ-M10** teacher writes gate on granular perms (new `markAttendance`/`manageHomework` + reused `manageExamMarks`; non-teaching staff blocked), **MJ-M11** parent-scoped attendance-correction route + own-child RLS + `submitAttendanceCorrection` grant, **MJ-L2** per-widget RBAC for school scope + drill-down route + hidden-widget fetch, **MJ-L4** copilot error state + deterministic fallback, **MJ-L5** removed unseeded superAdmin platform perms + honest mock-write state, **MJ-L3** Director entitlement gates + write error handling, **MJ-L6** refund self-approval block, **MJ-L7** inventory intelligence GETs side-effect-free, **MJ-L8** global-search RBAC filter, **MJ-M12** comms path-parity contract tests (+ fixed a real missing `PUT /communications/templates/:id` handler). 1 forward-only migration (`20260807000010_wave5_teacher_attendance_rbac`) applied + ledgered; edge `_shared` redeployed; edge recreated. Live cert caught + fixed 3 real defects (pre-existing `recorded_on` 500 in operations-hub/widgets endpoint → join `attendance_sessions.session_date`; parent-correction PK collision under RLS-filtered count → unique id; error-mapping masking PK clash as 403 → narrowed to RLS). 8 disjoint items built by parallel agents; teacher/attendance RBAC owned centrally. Class-assignment binding (TEACH-4 half) deferred pending ATTEN-7 identifier normalization. Gates: analyze 0 · flutter 2439 · deno 848.

### Original plan (for reference)

**Why this wave:** Final consolidation wave: harden intra-school RBAC (scope-only write gates, per-widget data bypass, self-approval, missing entitlement wrappers), do one States/UX sweep extending the Wave5 fromFailure standard to mutation paths (silent submit/save/send failures), and add the client↔deployed-router path-parity contract tests that would have caught the wire-gaps. Lowest risk-to-trust per item but closes the long tail and prevents recurrence; certifiable as the hardening/regression batch.

**Severity mix:** Medium x2, Low x3 + grouped UX/RBAC/test items  ·  **Estimate:** S-heavy (8 S + 2 M) ≈ 1 batch

| ID | Module | Item | Sev | Effort |
|----|--------|------|-----|-------:|
| `MJ-M12` | Communication | Add client↔deployed-router path-parity contract tests (mock currently masks live 404s) | 🟠 High | S |
| `MJ-M10` | Teacher | Teacher write handlers gate on school scope only — no granular permission or class-assignment check | 🟡 Medium | M |
| `MJ-M11` | Attendance | Attendance marking (draft/submit) has no permission gate, only school scope; parent correction submit 403'd needs scoped route | 🟡 Medium | M |
| `MJ-L2` | Dynamic Widgets | Per-widget data permission bypassed for any school-scope token; attendance-risk drill-down route doesn't exist | 🟡 Medium | S |
| `MJ-L4` | AI Features | Copilot send-message failure silent (no error state); server 500 leaves dangling user message (no fallback) | 🟡 Medium | M |
| `MJ-L5` | Super Admin | Client RBAC matrix grants superAdmin platform perms the server never seeds; mock writes fabricate success | 🟡 Medium | S |
| `MJ-L3` | Director | 8 Director sub-routes lack client EntitlementModuleGate; summary/acknowledge writes lack error handling | ⚪ Low | S |
| `MJ-L6` | Finance | No self-approval prevention on refunds (maker-checker by convention only) | ⚪ Low | S |
| `MJ-L7` | Inventory | Intelligence GET endpoints perform DB snapshot INSERT + audit on every read (side-effectful reads) | ⚪ Low | S |
| `MJ-L8` | Admin | Global search surfaces/navigates routes regardless of RBAC; unlisted routes unguarded | ⚪ Low | S |

**Exit criteria:** every item above closed and re-verified live; `flutter analyze` 0 / `flutter test` green / `deno test` green held; `/release-review` verdict **GO**.

---

## Cross-module findings (address within the wave that owns the root cause)

| # | Finding | Modules | Sev |
|---|---------|---------|-----|
| XM-1 | Persona/admin read screens serve permanently-static seed snapshots instead of live-overlaid data | Teacher, Principal, HR, Alumni, Library, Homework, Hostel | 🔴 Critical |
| XM-2 | Client surfaces ship ahead of backend routes — whole journeys 404 silently in the live build | Parent, Teacher, Admissions, Communication, Principal, Admin | 🔴 Critical |
| XM-3 | Deployed-and-certified backends sit unused because their module flag is missing from config/live_release.json | AI Features, Staff, Inventory, Admissions | 🟠 High |
| XM-4 | Real users are shown fabricated/demo placeholder data presented as real | Student, Exams, Notifications, Finance, HR, Alumni, Parent, AI Features | 🟠 High |
| XM-5 | Write-then-read decoupling: a successful write is invisible because read-model / snapshot is never updated | Homework, Attendance, Hostel, Library, Teacher | 🟠 High |
| XM-6 | Demo-grade workflow dialogs hardcode mock IDs / ignore typed input (data-integrity hazard on write) | HR, Finance, Library, Hostel, Transport, Inventory, Attendance, Exams | 🟠 High |
| XM-7 | Certified/working features are unreachable from the app (orphaned routes, no nav entry) | Staff, Admin, Marketing | 🟠 High |
| XM-8 | Async mutation/load errors are swallowed instead of surfaced to the user | Student, Teacher, Communication, Director, AI Features, Notifications, Admin, Marketing, Alumni | 🟡 Medium |
| XM-9 | Write handlers gate on school scope only, not granular permission or assignment (intra-school RBAC weakening) | Teacher, Attendance, Inventory, Dynamic Widgets, Finance | 🟡 Medium |

> Full descriptions for each XM finding are in `docs/MODULE_JOURNEY_AUDIT.md` → *Cross-module findings*.

---

## Module verdicts (one-line)

| Module | Status | Verdict |
|--------|--------|---------|
| Parent | certified-with-gaps | Core reads + multi-child + insights + fees are live and certified, but messaging/leave/PTM 404 in production and inbox silently shows mock data. |
| Student | certified-with-gaps | All 7 reads + homework submit are live and student-scoped, but every screen falls back to fabricated placeholder data on error and the report card reads mock stores. |
| Teacher | gaps-block-cert | Writes persist, but teacher reads are static seed snapshots (no live overlay) and the entire exam workflow + parent-communication endpoints 404. |
| Staff | certified-with-gaps | Login/OTP + Employee 360 are live, but Employee Platform shows mock data (flag missing) and employee mgmt screens are orphaned with no nav entry. |
| HR | certified-with-gaps | Reads/writes wired with RBAC, but employee profiles serve identical hardcoded data, dashboard KPIs are static seed, and leave/create dialogs ignore user input. |
| Principal | certified-with-gaps | Approval Center + Evolution Command Center are real and live, but the legacy Management exec dashboards serve permanently-static seed and settings-save silently 404s. |
| Admin | certified-with-gaps | School-config persistence and RBAC nav are solid, but management-settings save silently 404s, backup screen is pure theatre, and the certified onboarding wizard is unreachable. |
| Director | certified-with-gaps | Fully live and B8-certified; only minor UX gaps (8 sub-routes lack client entitlement gate, two writes lack error handling). |
| Super Admin | certified-with-gaps | Entitlements + Control Center are genuinely live and RBAC-enforced; five platform sub-modules are mock-only client/server drift (no backend, unseeded perms). |
| Admissions | gaps-block-cert | Leads CRM + AI are certified live, but 5 nav tabs 404 (Reports/Settings/Approval/Enrollment) and approval review shows hardcoded fixture data. |
| Finance | certified-with-gaps | Money loop, parent visibility, and RBAC all certified live with no drift; gaps are owner-gated Razorpay stub and fake-student prefills in refund/scholarship dialogs. |
| Attendance | certified-with-gaps | Marking persists and privacy RLS holds, but approved corrections never update the actual record (0-row UPDATE) and parent correction submit is 403'd. |
| Exams | certified-with-gaps | Full admin lifecycle + publish governance + results-to-parent are live; report card reads mock store and parent/student screens fall back to fabricated grades. |
| Homework | gaps-block-cert | Create/submit persist, but teacher cannot see/grade submissions, grades never reach student/parent, and assignments fan out to the whole school. |
| Communication | gaps-block-cert | Broadcast send is Wave4-certified live, but template-create and broadcast-history 404, and the mock masks both from the test gate. |
| Transport | certified-with-gaps | All reads + write loop live and RBAC-enforced, but attendance write has no UI and GPS/delay-notify journeys are placeholders. |
| Hostel | certified-with-gaps | Admit/assign/checkout/create-room are live, but attendance/mess have no write path and logged visitors never appear (snapshot vs list mismatch). |
| Library | certified-with-gaps | Catalog-add + RBAC live, but issue/return use mock-seed IDs, fines are read-only static, members can't be enrolled, and digital resources store no file. |
| Inventory | gaps-block-cert | Reads + intelligence live, but distribution runs on mock (flag missing), create-PO sends a hardcoded mock vendor id (500), and no vendor-create UI exists. |
| Marketing | certified-with-gaps | Growth engine + publisher backend certified, but the Promotion Center, Holiday Calendar, and Meta-connect have no reachable UI surface. |
| AI Features | certified-with-gaps | Copilot/insights/school-builder/predictions backends certified with safe fallback, but Predictions serves mock in release (flag missing) and copilot errors are silent. |
| Organization Builder | certified-with-gaps | B10-certified packs→interview→preview→provision flow is live, but provisioning is a documented stub that creates no real tenant while claiming success. |
| Dynamic Widgets | certified-with-gaps | B11-certified registry/runtime/editor all live; minor gaps (per-widget RBAC bypass for school scope, dead attendance drill-down route). |
| Notifications | certified-with-gaps | Parent FCM push pipeline certified live, but students call the parent-only route (403→demo fallback) and real parents see hardcoded demo notifications. |
| Alumni | certified-with-gaps | Registry/event/campaign/mentorship writes live with RBAC, but profiles fabricate employment/events, dashboard KPIs are static seed, and donations can't be recorded. |
| Verticals | frozen-by-design | Correctly hidden and route-blocked in the school build (frozen P4/B12); all gaps are 'if un-frozen' and harmless to the live pilot today. |

---

## Next step

Awaiting approval. On approval we close **one wave at a time** using `/gap-check → fix → /certify → /deploy → /release-review`, starting with **Wave 0** (fastest, highest trust-leverage). No fixes have been applied — this run was audit-only.
