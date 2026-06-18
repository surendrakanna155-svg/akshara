# CLAUDE MASTER AUDIT — Permanent Memory & Source of Truth

> **Role:** Product Auditor · ERP Architect · UX Reviewer · Education Domain Expert · Technical Lead
> **Owner:** Surendra (non-engineer project owner)
> **North Star:** The *easiest*, most intuitive, modern, **mobile-first** ERP for *real schools* — not the biggest ERP.
> **Mode:** AUDIT ONLY. No code, no refactor, no new features until owner approves.
> **Started:** 2026-06-18 · **Audit base commit:** `70194d6` · Tag `pre-claude-audit-v1` · Branch `feature/m15-theme`

---

## 0. How to use this file
This is Claude's continuously-updated memory across the audit. Every other audit doc derives from facts recorded here. Update it as findings land. Never lose context.

Deliverables (status tracked in §10):
1. docs/CLAUDE_MASTER_AUDIT.md (this file) — STEP 0
2. docs/PROJECT_HEALTH_AUDIT.md — STEP 2
3. docs/UI_UX_AUDIT_REPORT.md — STEP 3
4. docs/WORKSPACE_ARCHITECTURE_AUDIT.md — STEP 4
5. docs/SCREEN_CONSOLIDATION_REPORT.md — STEP 5
6. docs/MOBILE_FIRST_AUDIT.md — STEP 6
7. docs/REAL_WORLD_SCHOOL_AUDIT.md — STEP 7
8. docs/ROADMAP_REVIEW.md — STEP 8
9. docs/QUESTION_INTELLIGENCE_PLATFORM_AUDIT.md — STEP 9
10. docs/FIRST_10_SCHOOLS_STRATEGY.md — STEP 10
11. docs/MASTER_RECOMMENDATION_REPORT.md — STEP 11

---

## 1. Project status (as recorded by the team, to be verified)
- **Stack:** Flutter + Riverpod + Clean Architecture + GoRouter + Supabase (Postgres + RLS + Edge Functions). Material 3. Backend stack LOCKED per BACKEND_ARCHITECTURE_DECISION.md.
- **Scale:** ~1,491 Dart files; ~70 `lib/features/*` modules; ~40 `lib/core/*` modules; 238 doc entries; 163 commits.
- **Backend phases:** Governance (Phase D) + F1 Auth/RBAC + F2 Approval + F3 SIS/Student360 + F4 Exams + F5 Attendance = certified. Team claims **~89% production API readiness**. F6 (audit upload) + F7 (production GO gate) = NOT started, frozen pending this audit.
- **QA:** Patrol e2e ~46% weighted coverage, 116 certified journeys. Flutter test: 1971 passed / 1 skipped. `flutter analyze`: 0 errors.
- **Known open defect:** B02b-ATT-01 (High) — Parent attendance correction not visible in Principal approval inbox (Patrol Batch 02b failure). Root cause unconfirmed.
- **Self-acknowledged risks:** documentation sprawl (600+ markdown files), server RBAC parity is P0 debt (client RBAC only), exam data device-local in mock mode, emulator instability.

## 2. Architecture understanding (VERIFIED in code)
- **No Workspace abstraction exists.** Reality = `USER → ROLE → (one flat 22-module menu) → TASK`. Two role enums: `UserRole{parent,teacher,student,staff}` (shell) + `ErpRole{15 roles}` (permissions). Intended USER→ROLE→WORKSPACE→TASK is unimplemented.
- **Single-role data model** — `AuthState.role`/`AuthClaims.erpRole` scalar → multi-hat users (Teacher+Inventory) structurally impossible.
- **RBAC 100% client-side.** `enableApiMode:false` in dev/staging/prod (`environment.dart:46,53,62`). `ServerRbacRouteInventory` is dead code. Mutation guards manual across ~40 providers.
- **No live backend in any build** — all mock/in-memory repositories.
- **Over-broad role grants** — principal/schoolAdmin get non-school vertical permissions (Salon/Restaurant/Healthcare).
- Inventory: 52 feature folders, 270 screens, 1491 dart files, 287 routes. Mostly REAL but over-covered.

## 3. Major decisions
- Backend = Supabase (locked). Audit recommends turning ON API mode for pilot tenants — durability is the gating need.
- Strategy verdict: **subtraction + depth**, not more building.

## 4. Risks (top)
- Client-only RBAC + forgeable claim; in-memory governance (approvals vanish on restart); demo auth in prod; fake exam generation; exam data device-local; no push/SMS notifications; no unified student identity; backup/restore uncertified.

## 5. UX issues (top)
- "See everything" admin menu; principal sees Salon/Restaurant; sub-nav overload (CC 15/Finance 14); wrong bottom-nav selected-state; ~28 dead buttons; QA persona switcher in prod; Director not phone-responsive; 3 breakpoint systems. Consumer apps (Parent/Teacher/Student) are GOOD; teacher attendance flow exemplary. Design system mature.

## 6. Duplicate workflows / modules (CONFIRMED)
- DELETE: phase4/phase5 (cruft shells, no screens). MERGE: academic→academics; inventory_distribution→inventory; 4 intelligence locations→1; 7 org/tenant folders→1; copilot+ai_content. SHELVE (scope creep): verticals (20 screens), franchise/white_label/multi_school/platform_operations/organization_builder/evolution. NOT duplicates: sis/student/student_360 (rename for clarity).

## 7. Technical debt
- See PROJECT_HEALTH_AUDIT §"Technical-debt register" (top 12) and MASTER_RECOMMENDATION §2 (top 50 architecture problems). Headline: no backend, in-memory governance, client-only RBAC, demo auth, fake exams, no real LLM.

## 8. Roadmap recommendations
- F1–F7 track is correct but only 5/7 done; product milestones raced ahead on mock. Reorder: exam chain (currently "blocked, no owner") → top priority; F6/F7 + durable governance next; notifications. Postpone live AI/SaaS/multi-industry. Build Question Intelligence (deterministic-first) as the moat AFTER core is real. See ROADMAP_REVIEW.md + FIRST_10_SCHOOLS_STRATEGY.md.

## 9. Open questions for the owner
1. Are any non-school verticals (salon/restaurant/healthcare) a real near-term business line, or safe to shelve?
2. Is multi-school/franchise/white-label needed for the first 10 schools, or post-launch?
3. Who owns the exam chain (the #1 gap)? Is the P3-02 "product block" still in force?
4. Timeline expectation for first real-school go-live (drives backend prioritization)?
5. Budget/appetite for the Question Intelligence Platform as a dedicated track?
6. OK to archive ~220 point-in-time docs into docs/_archive/?

## Maturity score
- Real-school readiness **~4.5/10**; Flutter build quality **~8/10**. The delta is the work.

## 10. Deliverable tracker
| # | Doc | Status |
|---|-----|--------|
| 0 | CLAUDE_MASTER_AUDIT.md | ✅ Complete |
| 2 | PROJECT_HEALTH_AUDIT.md | ✅ Complete |
| 3 | UI_UX_AUDIT_REPORT.md | ✅ Complete |
| 4 | WORKSPACE_ARCHITECTURE_AUDIT.md | ✅ Complete |
| 5 | SCREEN_CONSOLIDATION_REPORT.md | ✅ Complete |
| 6 | MOBILE_FIRST_AUDIT.md | ✅ Complete |
| 7 | REAL_WORLD_SCHOOL_AUDIT.md | ✅ Complete |
| 8 | ROADMAP_REVIEW.md | ✅ Complete |
| 9 | QUESTION_INTELLIGENCE_PLATFORM_AUDIT.md | ✅ Complete |
| 10 | FIRST_10_SCHOOLS_STRATEGY.md | ✅ Complete |
| 11 | MASTER_RECOMMENDATION_REPORT.md | ✅ Complete |

## 11. Audit history
- 2026-06-18 (later): **First scope-trim shipped (owner-approved, "hide now, delete later").** Added `lib/core/config/school_build_scope.dart` — one reversible switch that hides non-school verticals (Salon, Restaurant, Healthcare, Accommodation, Industry framework), White-label, and experimental extras (Organization Builder, Platform Operations, Dynamic Widgets, Franchise, Resource Optimization, Memories, Evolution suite: setup-wizard/teacher-assistant/parent-insights/principal-command/growth-platform). KEPT multi-school (control center, director, multi-school portfolio, branches). Wired into the admin menu (`admin_navigation_provider.dart`) and the route guard (`ErpRouteGuard` in `route_guards.dart`); `canAccessErpRoute` kept pure-RBAC so permission tests stay valid. Nothing deleted — flip `SchoolBuildScope.enabled=false` to restore all. Updated `admin_navigation_provider_test.dart` (22→13 modules) + added `test/core/config/school_build_scope_test.dart`. Gates: `flutter analyze` 0 errors; `flutter test` 1975 passed / 1 skipped.
- 2026-06-18: Audit initiated. Read CLAUDE_HANDOFF, PRE_CLAUDE_HANDOFF_REPORT, PROJECT_CONTEXT, AGENTS.md. Surveyed repo structure. Launched parallel deep-dive investigators (navigation/RBAC, module inventory, question-intelligence, mobile UX, roadmap/prior-audits synthesis).
