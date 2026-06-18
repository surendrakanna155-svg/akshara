# SCREEN CONSOLIDATION REPORT — Akshara ERP

> **Audit date:** 2026-06-18 · **Base commit:** `70194d6`
> **Inventory:** 52 feature folders · 270 `_screen.dart` files · 1,491 Dart files · 287 routes.
> **Key finding:** There is almost **no classic dead code** (the two-level router wires nearly everything). The real problems are **(a) over-coverage** — ~30% of screens serve non-school/SaaS futures — and **(b) fragmentation** — the same job is spread across many folders. Consolidation target: **270 → ~180 maintained screens; 52 → ~30 folders.**

---

## How to read this

Each recommendation lists: **Benefit · Risk · Complexity · Suggested replacement.** "Complexity" = engineering effort to do the consolidation (Low/Med/High). All of this is **recommendation only** — no changes made.

---

## A. DELETE — cruft with no real screens

### A1. `phase4/` and `phase5/` shells
- **What:** `phase4/` has only `phase4_providers.dart` (no screens); `phase5/` has only models/providers. Their `*_navigation.dart` files merely re-route screens that physically live in `employee/`, `homework_intelligence/`, `inventory_distribution/`, `ai_content/`, `memories/`, `operations/`, `promotion/`, `resource_optimization/`.
- **Benefit:** Removes confusing "phase" indirection; clarifies ownership.
- **Risk:** Low — must re-point the routes to the owning modules first.
- **Complexity:** Low.
- **Replacement:** Fold providers/models into the owning modules; route those modules directly.

## B. REMOVE / SHELVE — out-of-scope for a school ERP

### B1. `verticals/` (20 screens: restaurant, salon, healthcare, accommodation)
- **What:** Fully-built, routed, non-school business modules.
- **Benefit:** Removes ~20 maintained screens + their nav files (`industry/salon/healthcare/restaurant/accommodation_navigation.dart`) and strips vertical permissions from school roles.
- **Risk:** Low for schools (no school uses them); only matters if a non-school vertical is a real near-term business line — owner decision.
- **Complexity:** Low (gate behind a disabled feature flag) → Med (full removal).
- **Replacement:** Disabled feature flag / separate future product. Not in the school build.

### B2. Org/SaaS-platform tier: `franchise`, `white_label`, `platform_operations`, `evolution`, `dynamic_widgets`, `memories`, `resource_optimization`
- **What:** ~25–30 screens of multi-tenant/SaaS tooling for a product with no customers yet.
- **Benefit:** Major surface-area reduction; less to test, secure, translate, theme.
- **Risk:** Low now; revisit when a paying multi-tenant customer exists.
- **Complexity:** Med.
- **Replacement:** Shelve behind flags until needed.

## C. MERGE — fragmentation of one job across many folders

### C1. `academic/` + `academics/` → `academics/{timetable, exam_admin}`
- **What:** `academic/` = timetable only (1 screen); `academics/` = exam_admin only (2). One-letter-apart names with disjoint content.
- **Benefit:** Eliminates the single most confusing naming collision in the repo.
- **Risk:** Low.
- **Complexity:** Low.

### C2. `inventory_distribution/` → `inventory/distribution/`
- **What:** distribution = 1 screen (uniform/book distribution + replacement).
- **Benefit:** One inventory module, not two.
- **Risk:** Low.
- **Complexity:** Low.

### C3. Analytics: `intelligence/` + `organization_intelligence/` + `homework_intelligence/` + `management/intelligence/` → one `intelligence/` module
- **What:** Academic analytics, "trust intelligence hub", a 1-screen homework hub, and a management sub-folder — all analytics.
- **Benefit:** One place for "insights"; coherent story instead of four scattered hubs.
- **Risk:** Med — providers cross modules; needs careful re-wiring.
- **Complexity:** Med.

### C4. Org/tenant management: `multi_school` + `branch` + `franchise` + `white_label` + `platform_operations` + `organization_builder` + `control_center` → one `platform/` (admin-only) module
- **What:** Seven folders all doing "manage organisations/tenants/branding."
- **Benefit:** Collapses the biggest fragmentation cluster (~30+ screens) into one admin module — and most of it can be shelved per §B until there's a SaaS customer.
- **Risk:** Med — `control_center` is the richest (15 screens) and partly real; keep its useful parts.
- **Complexity:** High.

### C5. AI surface: `copilot/` + `ai_content/` (+ `inventory_copilot_screen`)
- **What:** copilot = assistant dock/persona shell (3); ai_content = content-generation (1); plus a stray inventory copilot screen.
- **Benefit:** One AI module; removes the stray inventory AI screen that duplicates the copilot surface.
- **Risk:** Low.
- **Complexity:** Low–Med.

## D. CLARIFY — confusing, not duplicate (rename, don't merge)

### D1. `sis/` vs `student/` vs `student_360/`
- **Verdict:** **Not duplicates.** sis = admin student-information system; student = student-facing app; student_360 = single analytics dossier view. Keep all three, but the names invite confusion.
- **Action:** Document the distinction; consider renaming `student/` → `student_app/`.

### D2. "Promotion" collision
- **What:** `sis/academic_operations/sis_promotion_screen.dart` (grade promotion) vs `promotion/achievement_promotion_screen.dart` (achievements/marketing). Same word, different meaning.
- **Action:** Rename one (e.g. `achievement_promotion` → `showcase`/`spotlight`).

### D3. Timetable scatter
- **What:** Timetable surfaces appear in `academic/`, `management/`, `parent/`, `teacher/`.
- **Action:** One canonical timetable source of truth in `academics/timetable`; personas render read-only views of it.

## E. DEAD-ACTION SCREENS (functional cleanup, not consolidation)

`RED_TEAM_OPERATIONAL_AUDIT.md` identified **~28 screens with dead actions** (`onPressed: () {}`) — export buttons in HR settings, library resources, hostel dashboard, etc. These are not dead *screens* but dead *buttons*. Either wire them or hide them; shipped buttons that do nothing erode trust fastest.

---

## Consolidation scorecard

| Action | Folders affected | Screens affected | Complexity | Priority |
|--------|-----------------:|-----------------:|------------|----------|
| Delete phase4/phase5 | 2 | 0 | Low | 🟢 Quick win |
| Shelve verticals | ~5 | ~20 | Low–Med | 🟠 Owner decision |
| Shelve SaaS/org tier | ~6 | ~30 | Med | 🟠 Owner decision |
| Merge academic→academics | 2→1 | 3 | Low | 🟢 Quick win |
| Merge inventory_distribution | 2→1 | 2 | Low | 🟢 Quick win |
| Merge intelligence hubs | 4→1 | ~7 | Med | 🟡 |
| Merge org/tenant tier | 7→1 | ~30 | High | 🟡 |
| Merge AI surface | 3→1 | ~5 | Low–Med | 🟡 |
| Fix dead-action buttons | many | ~28 | Low | 🟢 Quick win |

**Net target:** 52 folders → ~30; 270 screens → ~180 actively maintained for the school product. Every removed screen is one less thing to test, secure, translate, and theme — directly serving the "easiest ERP" goal.

> ⚠️ **Caveat for engineers:** the router wires screens via per-module `*_navigation.dart` builder functions consumed by `app_router.dart`. A naive grep of `app_router.dart` alone produces false "dead" verdicts. Verify reachability through the navigation builders before removing anything.
