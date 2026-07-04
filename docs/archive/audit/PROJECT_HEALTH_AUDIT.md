# PROJECT HEALTH AUDIT — Akshara ERP

> **Audit date:** 2026-06-18 · **Base commit:** `70194d6` · **Auditor:** Claude (Product/Architecture/UX)
> **Verdict in one line:** A remarkably complete, well-engineered *mock prototype* that has out-run itself — the breadth (52 feature areas, 270 screens) is far ahead of the depth (real backend, real data, real AI), and the product has drifted from "easiest ERP for real schools" toward "biggest SaaS platform."

This report is written for a **non-engineer owner**. Technical file references are included for engineers, but every point is explained in plain language.

---

## How to read the scores

I deliberately separate three different questions that the existing docs blur together:

| Question | Score | What it means |
|----------|------:|---------------|
| **Is the Flutter app well-built?** | **8.5 / 10** | The code, design system, and test discipline are genuinely strong. |
| **Can a real school run on it today?** | **~4 / 10** | Most write-paths are mock/in-memory; data doesn't survive app restart; no live backend. |
| **Is it the *simplest* ERP for schools?** | **~3.5 / 10** | Scope creep (salon/restaurant/healthcare/franchise/white-label) has buried the school product. |

The team's docs report numbers from **89%** down to **35%** for "readiness." Both are true — they measure different things. The honest synthesis: **excellent app shell, hollow operational core, too much surface area.**

---

## 1. What is GOOD (keep and be proud of)

1. **The design system is real and modern.** Material 3, a ~36-component shared widget library (`lib/shared/widgets/`), design tokens for color/type/spacing/radius (`lib/theme/`), consistent KPI cards, empty/error/loading states. This is better than most commercial ERPs.
2. **The three consumer apps are genuinely mobile-first.** Parent, Teacher, Student each have a dedicated app shell with clean 3–4 item bottom navigation. The **teacher mark-attendance flow** (`lib/features/teacher/attendance/teacher_attendance_screen.dart`) is exemplary mobile UX — bulk "all present/absent", sticky submit bar, draft save.
3. **Test discipline is strong.** 1,971 passing Flutter tests, `flutter analyze` clean, 116 certified Patrol end-to-end journeys. Few codebases this size are this green.
4. **The repository/clean-architecture pattern is consistent.** Mock and API repositories sit behind interfaces, so swapping mock→real is structurally possible (`lib/core/repositories/`).
5. **The exam *marks* lifecycle is real and well-governed.** `lib/core/exams/exam_administration_store.dart` implements create → marks-entry → approval-gated publish with coordinator verification. This is the right pattern.
6. **Honest internal audits exist.** `RED_TEAM_OPERATIONAL_AUDIT.md`, `REAL_SCHOOL_OPERATIONS_AUDIT.md`, and `PRE_PRODUCTION_GAP_REPORT.md` already tell the truth. The team has the self-awareness; it just hasn't acted on it yet.

## 2. What is BAD (must fix before any real school)

1. **There is no live backend in any build.** `enableApiMode: false` is hardcoded for dev, staging *and* production (`lib/core/config/environment.dart:46,53,62`). The app runs entirely on in-memory/mock repositories everywhere.
2. **Governance data is not durable.** Approvals, leave decisions, fee concessions, attendance corrections live in in-memory stores — **lost on app restart or reinstall.** A principal who approves a leave today has no record tomorrow.
3. **RBAC is 100% client-side.** All permission checks happen in the app (`lib/core/security/rbac_service.dart`). A tampered login token grants anything; there is no server re-check. `ServerRbacRouteInventory` is dead code (0 references).
4. **No real AI exists.** Every "AI" provider is simulated (`lib/core/ai/providers/edge_ai_provider.dart` returns hardcoded templates). The "AI question generator" appends literal `"AI generated: <subject>"` strings (`lib/core/repositories/mock/mock_education_repository.dart:126-193`). Status docs claiming "96% AI" are inaccurate.
5. **Demo auth still active in the production flavor.** Real schools would get wrong roles/tenants.

## 3. What is CONFUSING

1. **Two role systems for the same people.** `UserRole {parent,teacher,student,staff}` and `ErpRole {15 roles}` both define teacher/parent/student (`lib/features/auth/`, `lib/core/security/erp_role.dart`). Which is authoritative is unclear.
2. **`academic/` vs `academics/`** — two folders, one letter apart, disjoint contents (one = timetable, one = exam admin).
3. **`phase4/` and `phase5/`** — release-phase shells with no screens, only providers; they re-route screens that live elsewhere. Pure cruft.
4. **Three "intelligence" modules** (`intelligence`, `organization_intelligence`, `homework_intelligence`) plus `management/intelligence/` — analytics fragmented across four places.
5. **Readiness numbers contradict across docs** (35% / 45% / 58–62% / 72% / 89% / 96%) because each uses a different baseline and none label which.

## 4. What is DUPLICATED

| Group | Reality | Action |
|-------|---------|--------|
| `academic` + `academics` | Naming collision, disjoint content | **Merge** into `academics/{timetable,exam_admin}` |
| `phase4` + `phase5` | Org shells, no real screens | **Delete**, fold providers into owning modules |
| `inventory` + `inventory_distribution` | distribution = 1 screen | **Move** into `inventory/` |
| `intelligence` + `organization_intelligence` + `homework_intelligence` + `management/intelligence` | Fragmented analytics | **Consolidate** |
| `franchise` + `branch` + `multi_school` + `white_label` + `platform_operations` + `organization_builder` + `control_center` | 7 folders all doing "org/tenant management" | **Consolidate** into one tenant/platform module |

## 5. What is OVER-ENGINEERED (built ahead of need)

- **`verticals/` (20 screens): restaurant, salon, healthcare, accommodation.** Entirely non-school. This is the single clearest case of scope creep — 20 shipped, maintained screens with zero relevance to the first 10 schools.
- **`franchise`, `white_label`, `multi_school`, `platform_operations`, `organization_builder`, `evolution` (~30 screens combined):** SaaS-platform tooling for a product that has zero customers yet.
- **`dynamic_widgets`, `memories`, `resource_optimization`:** speculative.
- **Multi-industry "kernel" (M13):** a generalized industry framework before the school vertical itself is operational.

**Plain-language summary:** the team built the multi-industry SaaS platform *before* finishing the school. ~70–80 of the 270 screens (≈30%) serve futures the first 10 schools will never touch — and every one of them is wired in, so they cost maintenance and add cognitive load.

## 6. What is UNDER-ENGINEERED (too thin for what a school needs)

1. **The exam chain** — paper generation is fake; question bank has no learning outcomes/Bloom/provenance; no question moderation; no report-card generation.
2. **Server everything** — auth, RBAC, persistence, audit upload (F6/F7 not started).
3. **Vice-Principal / delegation** — role doesn't exist; no "acting principal."
4. **Unified student identity** — the same student isn't linked across SIS, attendance, exams, transport, hostel.
5. **Notifications** — in-app only; no push/email/SMS (the channels Indian schools actually use).

## 7. What is MISSING (expected by a real school, absent)

- ERP exam administration end-to-end (create → schedule → marks → publish → report card → ranks).
- Durable server records for anything a principal approves.
- SMS/WhatsApp/push communication (the dominant parent channel in India).
- A real backup/restore story (40% per `BACKUP_RECOVERY_ARCHITECTURE.md`).
- Multi-language rollout (framework 65%, rollout 25%) — Tamil/Hindi/Telugu/Marathi matter.
- Fee receipts/report cards as real PDFs.

## 8. What should be REMOVED (or shelved behind a flag)

- `verticals/` (salon/restaurant/healthcare/accommodation) — remove from build or hide behind a disabled flag.
- `phase4/`, `phase5/` shells — delete.
- `franchise`, `white_label`, `evolution`, `dynamic_widgets`, `memories`, `resource_optimization` — shelve until there's a paying multi-tenant customer.

## 9. What should be MERGED

See §4. Net effect: ~70 feature folders → ~30; ~270 screens → ~180 maintained surfaces.

## 10. What should be SIMPLIFIED

1. **Roles:** one role model, not two. Add real multi-role support (a teacher who is also exam coordinator).
2. **Navigation:** replace the flat 22-module admin grid with **responsibility-scoped workspaces** (see `WORKSPACE_ARCHITECTURE_AUDIT.md`).
3. **Docs:** 238 doc files / "600+ markdown files" is unmanageable. Collapse to ~15 living documents.
4. **Readiness reporting:** one scoreboard with explicit "code-complete" vs "production-ready" columns.

---

## Technical-debt register (top 12, by severity)

| # | Debt | Severity | Evidence |
|---|------|----------|----------|
| 1 | No live backend; `enableApiMode:false` everywhere | 🔴 Critical | `environment.dart:46,53,62` |
| 2 | Governance state in-memory (lost on restart) | 🔴 Critical | `PRE_PRODUCTION_GAP_REPORT.md` A2/A5/A6/A7 |
| 3 | RBAC client-only; server inventory dead code | 🔴 Critical | `rbac_service.dart`, `server_rbac_route_inventory.dart` |
| 4 | Demo auth in production flavor | 🔴 Critical | `BACKEND_ARCHITECTURE_DECISION.md` |
| 5 | Exam paper generation is fake | 🟠 High | `mock_education_repository.dart:126-193` |
| 6 | No real LLM; status docs overstate AI | 🟠 High | `lib/core/ai/providers/*` |
| 7 | Single-role data model; no VP/delegation | 🟠 High | `auth_models.dart:152`, `auth_claims.dart:21` |
| 8 | No unified student identity across modules | 🟠 High | `RED_TEAM_OPERATIONAL_AUDIT.md` |
| 9 | ~30% of screens serve out-of-scope verticals/SaaS | 🟡 Medium | module inventory |
| 10 | Two role enums; academic/academics; phase4/5 cruft | 🟡 Medium | structure |
| 11 | Documentation sprawl (238 files) | 🟡 Medium | `docs/` |
| 12 | 28 screens with dead `onPressed:(){}` actions | 🟡 Medium | `RED_TEAM_OPERATIONAL_AUDIT.md` |

---

## Bottom line

Akshara is **not a struggling project** — it is an *over-achieving* one that built too much breadth on a mock foundation and lost sight of its own north star. The fix is **not more building; it is subtraction plus depth**: cut the non-school surface area, make a small set of school workflows real (durable data + server RBAC + real exam chain), and finish the workspace model so users see only their job. Do that and the app's genuine strengths (design system, mobile UX, test discipline) will carry it to 10 happy schools.

→ Detailed sub-audits: `UI_UX_AUDIT_REPORT.md`, `WORKSPACE_ARCHITECTURE_AUDIT.md`, `SCREEN_CONSOLIDATION_REPORT.md`, `MOBILE_FIRST_AUDIT.md`, `REAL_WORLD_SCHOOL_AUDIT.md`, `QUESTION_INTELLIGENCE_PLATFORM_AUDIT.md`, `ROADMAP_REVIEW.md`, `FIRST_10_SCHOOLS_STRATEGY.md`, `MASTER_RECOMMENDATION_REPORT.md`.
