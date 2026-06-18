# MASTER RECOMMENDATION REPORT — Akshara ERP

> **Audit date:** 2026-06-18 · **Base commit:** `70194d6` · **Auditor:** Claude (Product / ERP Architecture / UX / Education-domain / Tech-lead)
> **Companion docs:** `PROJECT_HEALTH_AUDIT` · `UI_UX_AUDIT_REPORT` · `WORKSPACE_ARCHITECTURE_AUDIT` · `SCREEN_CONSOLIDATION_REPORT` · `MOBILE_FIRST_AUDIT` · `REAL_WORLD_SCHOOL_AUDIT` · `ROADMAP_REVIEW` · `QUESTION_INTELLIGENCE_PLATFORM_AUDIT` · `FIRST_10_SCHOOLS_STRATEGY`
> **One sentence:** Akshara is an over-built, well-engineered *mock prototype* whose path to greatness is **subtraction + depth** — cut ~30% of non-school surface, make ~8 workflows truly real, finish the workspace model, then build Question Intelligence as the moat.

Severity legend: 🔴 critical · 🟠 high · 🟡 medium. Effort: S/M/L/XL.

---

## 1. TOP 50 UX PROBLEMS

1. 🔴 "See everything" admin home — flat grid of 22 module cards, no workspace scoping.
2. 🔴 Principal/admin roles see non-school modules (Salon, Restaurant, Healthcare, Accommodation).
3. 🟠 Sub-nav overload — Control Center 15, Finance 14, Inventory 10 items.
4. 🟠 Bottom-nav selected-state wrong for deep routes (highlights Home while in Messages/Transport).
5. 🟠 Too few tabs for too many destinations (Parent: ~10 behind 3 tabs); no "More" tab.
6. 🟠 ~28 dead buttons (`onPressed: () {}`) that look functional.
7. 🟠 QA persona switcher bar visible in all consumer shells.
8. 🟠 Principal/Growth routes bypass permission guards (look accessible when they shouldn't be).
9. 🟡 Director portal not phone-responsive (fixed 320px cards overflow <360px).
10. 🟡 Three competing breakpoint systems → inconsistent reflow.
11. 🟡 46 files use raw `Theme.of` instead of `context.aksharaText` → visual drift.
12. 🟡 Long single-column dashboards (Parent ~9 stacked sections; notices below the fold).
13. 🟡 Two "promotion" screens mean different things.
14. 🟡 Timetable appears in 4 modules with overlapping UX.
15. 🟡 Inventory has a stray copilot screen duplicating the central AI surface.
16. 🟡 Inconsistent filter UX (bottom-sheet vs inline bars).
17. 🟡 Hardcoded placeholder labels (e.g. teacher attendance subtitle "Priya Sharma · Mathematics").
18. 🟡 Fixed KPI card heights risk truncation with Indic fonts / large text scaling.
19. 🟡 Center AI nav slot crowds thumb reach / edge labels.
20. 🟡 Tablet-portrait still hits horizontal-scroll tables in some screens (library catalog).
21. 🟠 No unified report-card view for parents.
22. 🟠 Exam results read-only with no ranks.
23. 🟠 Notifications in-app only — parents miss them (no push/SMS/WhatsApp).
24. 🟡 Heavy hand-built multi-step forms (admissions enrollment, 441 lines) — no shared wizard.
25. 🟡 Class-teacher dashboard dead-ends into attendance, not a command center.
26. 🟡 Librarian copilot mapped to HR context (wrong scope).
27. 🟡 Export buttons show "queued" snackbars but do nothing.
28. 🟡 Director/Control-Center dense sub-screens (CRM/billing/support) on phones.
29. 🟡 No section collapse/prioritization on long dashboards.
30. 🟡 Ambiguous "where am I" feedback across persona shells.
31. 🟡 Two role systems confuse which identity is shown.
32. 🟡 `academic` vs `academics` naming collision.
33. 🟡 Module names invite confusion (sis/student/student_360).
34. 🟠 Attendance-correction request doesn't reliably appear in principal inbox (B02b-ATT-01).
35. 🟡 Copilot labeled as intelligent but returns canned text (expectation mismatch).
36. 🟡 No empty-state guidance for first-run schools (data-less screens).
37. 🟡 Finance concession flow gives no feedback that it didn't post to ledger.
38. 🟡 Transport/hostel/library read-only views look editable.
39. 🟡 No per-school feature flags → small schools see modules they don't use.
40. 🟡 Inconsistent iconography/labeling between consumer and admin surfaces.
41. 🟡 Searchable dropdowns not used everywhere long lists appear.
42. 🟡 No global search / command palette for admins drowning in nav.
43. 🟡 Notice/event content pushed far down on parent home.
44. 🟡 Multi-child parent context switch is a top-corner chip (reach issue).
45. 🟡 Approval inbox lacks bulk actions for principals.
46. 🟡 No "recently used / pinned tasks" to shortcut deep nav.
47. 🟡 Report/export formats not previewable before generating.
48. 🟡 Hostel visitor QR is a placeholder.
49. 🟡 Status/score docs overstate readiness → internal UX expectations misaligned.
50. 🟡 No onboarding tour for new staff users facing a dense ERP.

## 2. TOP 50 ARCHITECTURE PROBLEMS

1. 🔴 No live backend — `enableApiMode:false` in dev/staging/prod (`environment.dart:46,53,62`).
2. 🔴 Governance state in-memory — approvals/leave/concessions/corrections lost on restart.
3. 🔴 RBAC 100% client-side; server has no enforcement.
4. 🔴 `ServerRbacRouteInventory` is dead code (0 references).
5. 🔴 Server permission sync is an explicit stub ("no HTTP sync in v2.0").
6. 🔴 Demo auth active in production flavor.
7. 🔴 No Workspace abstraction — flat role-filtered dashboard.
8. 🔴 Single-role data model — multi-hat users impossible (`auth_models.dart:152`).
9. 🔴 Exam paper generation is fake (`mock_education_repository.dart:126-193`).
10. 🔴 No real LLM anywhere; all AI providers simulated.
11. 🟠 Two disconnected exam subsystems (`core/exams` vs `features/education`).
12. 🟠 Syllabus taxonomy not wired as AI boundary (free-text chapters, not IDs).
13. 🟠 Mutation guards manual per-provider (~40 files); registry descriptive, not enforced.
14. 🟠 Cross-shell leakage — any staff can enter `/teacher/*` (`app_router.dart:2265`).
15. 🟠 Over-broad role grants (90+ perms incl. verticals on principal/schoolAdmin).
16. 🟠 No unified student identity across SIS/attendance/exams/transport/hostel.
17. 🟠 18 write methods throw `ApiNotConnectedException` when API mode is on.
18. 🟠 Exam data device-local (SharedPreferences) — not server-authoritative.
19. 🟠 Attendance class submit has no API layer (in-memory sync store).
20. 🟠 Finance concessions in-memory; don't post to ledger.
21. 🟠 F6 (audit upload) not started — compliance/durability gap.
22. 🟠 F7 (leave + finance orchestration) not started.
23. 🟠 Two role enums duplicate teacher/parent/student identity.
24. 🟠 No VP/delegation/acting-principal model (role is a perm bundle only).
25. 🟠 Notifications have no push/SMS/WhatsApp transport.
26. 🟡 ~30% of screens serve out-of-scope verticals/SaaS.
27. 🟡 `phase4`/`phase5` cruft shells (no screens, only providers).
28. 🟡 Org/tenant management fragmented across 7 folders.
29. 🟡 Analytics fragmented across 4 "intelligence" locations.
30. 🟡 AI pipeline bypassed by the question flow (no constraint enforcement).
31. 🟡 No central API error→domain mapping guarantee for all write paths.
32. 🟡 RLS server enforcement deferred (65% partial).
33. 🟡 Backup/restore architecture 40%, no certification.
34. 🟡 Multi-language framework 65%, rollout 25%.
35. 🟡 Hardcoded demo school IDs in director portfolio.
36. 🟡 Admission settings save doesn't trigger SIS link.
37. 🟡 Hostel allocation not triggered by `needsHostel` flag.
38. 🟡 Library fines don't post to finance.
39. 🟡 No item-level exam analytics (p-value/discrimination).
40. 🟡 No PYQ store / Bloom / learning-outcome entities.
41. 🟡 No foundation/competitive-exam pattern model.
42. 🟡 Report cards/receipts not generated as real PDFs server-side.
43. 🟡 Documentation sprawl (238 files) — no single SSOT scoreboard.
44. 🟡 Registry drift (~15 "Planned" rows actually shipped; "shipped" ≠ prod-ready).
45. 🟡 Readiness scores contradictory across docs (no labeled baselines).
46. 🟡 QA login widens client trust (full matrix, forces mock mode).
47. 🟡 No per-tenant feature-flag system for school-by-school enablement.
48. 🟡 Observability/alerting incomplete (app-layer only).
49. 🟡 No penetration test (design only).
50. 🟡 Test coverage strong on mock, thin on real-API contract paths.

## 3. TOP 50 SIMPLIFICATIONS

1. Introduce the Workspace model; users see only their job.
2. Collapse two role enums into one role model.
3. Add real multi-role + workspace switcher.
4. Strip vertical permissions from school roles.
5. Shelve `verticals/` (salon/restaurant/healthcare/accommodation).
6. Shelve SaaS/org tier (franchise/white-label/platform-ops/org-builder/evolution).
7. Delete `phase4`/`phase5`.
8. Merge `academic`→`academics`.
9. Merge `inventory_distribution`→`inventory`.
10. Consolidate 4 intelligence locations → 1.
11. Consolidate 7 org/tenant folders → 1 admin `platform/`.
12. Merge `copilot`+`ai_content`; remove stray inventory copilot.
13. Cap primary nav at ≤5 items; add "More".
14. One breakpoint system.
15. Finish `context.aksharaText` migration (kill raw `Theme.of`).
16. One canonical timetable source; personas render read-only.
17. Rename one "promotion" screen.
18. Build one shared multi-step wizard widget.
19. Standardize bottom-sheet filters.
20. Remove QA persona switcher from prod builds.
21. Per-school feature flags (enable only used modules).
22. One readiness scoreboard with labeled columns.
23. Collapse 238 docs → ~15 living docs; archive the rest.
24. Replace FINAL/TRUTH/RC_LOCK/SIGNOFF doc chain with one status page.
25. Unify the two exam subsystems into one chain.
26. Make syllabus IDs the single reference for questions/papers.
27. Central mutation gate instead of 40 manual asserts.
28. Single unified student identity across modules.
29. Unify approval inbox as one durable governance store.
30. One notifications service with pluggable transports (in-app/push/SMS/WhatsApp).
31. Consolidate report/export into one document service.
32. Standardize empty/first-run states (already have the widgets).
33. Add global admin search/command palette to reduce nav depth.
34. Add pinned/recent tasks to shortcut deep flows.
35. Bulk actions in principal approval inbox.
36. Make Director portal responsive (reuse `AdminLayout.isMobile`).
37. Remove hardcoded demo IDs/labels.
38. Wire or hide all dead buttons.
39. One AI pipeline path (no bypass).
40. Single environment/config truth for API mode per tenant.
41. Reuse the exam approval pattern for question/paper moderation.
42. Standardize iconography/labels across consumer+admin.
43. Consolidate finance flows so concessions/refunds share ledger posting.
44. Fold management sub-modules into their canonical homes.
45. One promotion engine (grade promotion) cleanly separated from achievements.
46. Reduce role count to the school-relevant set; archive unused ones.
47. Single "school setup" wizard replacing scattered config screens.
48. Unify parent/student result views to one report-card component.
49. Collapse duplicate transport/hostel/library read views.
50. Establish one definition of "done" = durable + server-backed + tested.

## 4. TOP 50 QUICK WINS (low effort, visible value)

1. Remove QA persona switcher from prod (S). 2. Wire/hide dead buttons (S). 3. Delete phase4/phase5 (S). 4. Merge academic→academics (S). 5. Merge inventory_distribution (S). 6. Fix bottom-nav selected-state (S). 7. Add "More" tab to consumer apps (S–M). 8. Strip vertical perms from school roles (S). 9. Hide non-school modules behind a flag (S). 10. Make Director portal responsive (S). 11. Fix hardcoded teacher attendance subtitle (S). 12. Rename one "promotion" screen (S). 13. Cap visible nav items + overflow menu (M). 14. One breakpoint constant set (M). 15. Fix B02b-ATT-01 title/inbox mismatch (S–M). 16. Add bulk approve in principal inbox (M). 17. Standardize bottom-sheet filters on top list screens (M). 18. Replace stub export snackbars with disabled+"coming soon" (S). 19. Document sis/student/student_360 distinction + rename student→student_app (S). 20. Archive stale docs into `_archive/` (S). 21. One readiness scoreboard page (S). 22. Correct AI status docs to reflect simulated inference (S). 23. Fix `/principal-command`/`/growth` route guards (S–M). 24. Remove hardcoded demo school IDs (M). 25. Library copilot → library context (S). 26. Consolidate timetable entry to one source, others read-only (M). 27. Remove stray inventory copilot screen (S). 28. Finish `context.aksharaText` migration in highest-traffic screens (M). 29. Add empty-state guidance to first-run screens (M). 30. Add per-school feature flag scaffold (M). 31. Section prioritization/collapse on parent home (M). 32. Tablet-portrait card fallback for library catalog (S). 33. Add global admin search (M). 34. Pinned/recent tasks shortcut (M). 35. Fix selected-state across all three shells (S). 36. Wire admission settings → SIS link (M). 37. Hostel allocation trigger from `needsHostel` (M). 38. Library fines → finance posting (M). 39. Consolidate intelligence nav entries (M). 40. Standardize iconography (M). 41. Add report-card component placeholder unifying parent/student views (M). 42. Add "assistant" labeling to copilot to set expectations (S). 43. Remove unused role enum values (S). 44. Add onboarding tooltip tour for staff (M). 45. Preview before export (M). 46. Consolidate finance concession/refund feedback (M). 47. Replace launch_*.png clutter in repo root (S). 48. Clear stale golden failure artifacts (S). 49. Add per-tenant API-mode config switch (M). 50. Single "school setup" entry point linking existing config screens (M).

## 5. TOP 20 DANGEROUS AREAS

1. 🔴 Client-only RBAC + forgeable role claim — anyone can self-elevate.
2. 🔴 In-memory governance — a principal's approvals legally/operationally vanish.
3. 🔴 Demo auth in prod — wrong roles/tenants on real data.
4. 🔴 No live backend — "working" demos hide that nothing persists server-side.
5. 🔴 Fake exam generation presented as AI — reputational risk if shown to schools.
6. 🔴 Exam data device-local — data fork/loss on server cutover.
7. 🟠 Over-granted roles expose unrelated modules + actions.
8. 🟠 18 write methods throw on API mode — turning on the backend breaks flows.
9. 🟠 No unified student identity — data integrity risk across modules.
10. 🟠 Attendance/marks not server-authoritative — no official record.
11. 🟠 Manual mutation guards — one forgotten assert = unauthorized write.
12. 🟠 Cross-shell leakage into teacher app.
13. 🟠 RLS server enforcement incomplete — multi-tenant data isolation unproven.
14. 🟠 No backup/restore certification — data-loss exposure in month one.
15. 🟠 Notifications undelivered (no push/SMS) — parents miss fee/safety alerts.
16. 🟠 B02b-ATT-01 — approval routing defect of unknown root cause.
17. 🟡 Status-doc inflation — decisions made on wrong readiness assumptions.
18. 🟡 Scope sprawl — security/test surface far larger than needed.
19. 🟡 No pen test — unknown server-side vulnerabilities.
20. 🟡 Doc sprawl — truth is hard to find; contradictions persist.

## 6. WHAT TO FIX FIRST (ordered)

1. **Cut scope** (shelve verticals/SaaS, delete phase4/5, strip role over-grants) — S/M, unlocks focus.
2. **Real backend for the core 5** (SIS, attendance, fees, approvals, auth/RBAC) — XL, the foundation.
3. **Durable governance** (F6/F7) — L.
4. **Exam chain end-to-end** (assign an owner) — XL, the #1 product gap.
5. **Notifications: push + SMS/WhatsApp** — M, the trust-maker.
6. **Fix B02b-ATT-01** — S/M.
7. **Workspace model + nav cleanup** — L, the "feels simple" payoff.

## 7. WHAT TO POSTPONE

Live LLM/AI inference · Director multi-school comparison (real) · Question Intelligence full build (do deterministic pieces post-core) · multi-language rollout (right after core) · observability/pen-test hardening · any SaaS/multi-industry re-introduction.

## 8. WHAT TO DELETE

`phase4`/`phase5` shells · stray inventory copilot · one duplicate "promotion" screen (rename) · dead `onPressed:(){}` buttons · QA persona switcher in prod · repo-root screenshot clutter · stale golden artifacts · ~220 point-in-time docs (archive).

## 9. WHAT TO REDESIGN

1. **Navigation → Workspace model** (USER→ROLE→WORKSPACE→TASK).
2. **Roles → one multi-role model** with least-privilege defaults + VP/delegation.
3. **Exams → one unified chain** (syllabus IDs → bank/PYQ → blueprint → moderation → publish → marks → analytics).
4. **AI → constrained, syllabus-bounded, gap-fill-only** behind one pipeline.
5. **Notifications → one service, pluggable transports.**
6. **Governance → one durable, auditable approval store.**
7. **Readiness reporting + docs → one living scoreboard + ~15 docs.**

---

## 10. FINAL ERP MATURITY ASSESSMENT

| Dimension | Score /10 | Notes |
|-----------|:---------:|-------|
| App engineering quality | 8.5 | Clean architecture, tests, analyze-clean |
| Design system & UI | 8.0 | Modern M3, ~36 components, consistent |
| Mobile-first UX (consumer) | 8.0 | Teacher flow exemplary |
| Mobile-first UX (admin) | 6.0 | Responsive but nav-dense |
| Feature breadth | 9.0 | Too much, actually |
| **Feature depth (real data)** | **3.5** | Mock/in-memory core |
| Backend/production readiness | 3.5 | No live backend; F6/F7 pending |
| Security (server) | 3.0 | Client-only RBAC, demo auth |
| Data durability | 2.5 | In-memory governance |
| Exam/academic chain | 3.0 | Missing/fake |
| AI / Question Intelligence | 2.5 | Simulated; great scaffold |
| Simplicity / focus | 3.5 | Scope creep buries the school |
| Documentation truthfulness | 5.0 | Honest audits exist but buried |
| **Overall (real-school readiness)** | **~4.5 / 10** | Strong shell, hollow core, over-scoped |
| **Overall (as a Flutter prototype)** | **~8 / 10** | Genuinely impressive build |

**Maturity verdict:** *Advanced prototype, early product.* The craftsmanship is real and rare; the operational substance is not there yet, and the scope is working against the mission. The gap to a great product is **not capability — it's focus and depth.**

---

## EXECUTIVE SUMMARY

Akshara ERP is one of the more impressively *built* school-ERP codebases you'll see at this stage — a modern Material-3 design system, three genuinely mobile-first consumer apps (the teacher attendance flow is exemplary), clean architecture, and serious test discipline. But it has **out-run its foundation**: it runs entirely on mock/in-memory data with no live backend, client-only security, simulated AI, a fake exam-paper generator, and ~30% of its 270 screens devoted to non-school verticals and unsold SaaS features. The intended "USER → ROLE → WORKSPACE → TASK" simplicity model isn't implemented — users see a flat, over-granted "whole ERP" menu. Encouragingly, the team's *own* honest audits already say much of this; the truth is just buried under 238 docs and optimistic headline scores.

## RECOMMENDED ACTION PLAN

**Don't build more — cut, deepen, and make real.** (1) Trim scope to the school product. (2) Put the core five workflows (SIS, attendance, fees, approvals, auth/RBAC) on a real, durable backend. (3) Build the exam chain end-to-end. (4) Add real notifications (push/SMS/WhatsApp). (5) Implement the workspace model so every user sees only their job. (6) Then — and only then — build the **Question Intelligence Platform** (deterministic pieces first, constrained AI second) as the differentiator that makes schools switch to you.

## ERP MATURITY SCORE

**Real-school readiness: ~4.5 / 10.** Build quality: ~8/10. The delta between these two numbers *is* the work.

## IMMEDIATE ACTION PLAN (next steps for the owner)

1. **Approve the scope cut** (shelve verticals + SaaS, delete phase4/5, strip role over-grants). Lowest effort, highest clarity.
2. **Commit to "make it real for one school"** as the only theme until done — pause new features.
3. **Assign an owner to the exam chain** (the single biggest product gap).
4. **Decide the backend go-live plan** (turn on API mode for a pilot tenant; finish F1 enforcement + F6/F7).
5. **Adopt one readiness scoreboard** and archive the doc sprawl.
6. Then schedule the **workspace redesign** and the **Question Intelligence** track.

**Then STOP and pilot with 1–2 schools before scaling to 10.**
