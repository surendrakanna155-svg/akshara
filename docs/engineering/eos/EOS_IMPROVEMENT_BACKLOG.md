# EOS Improvement Backlog

Future enhancements to the Engineering Operating System (`/eos`) skill, surfaced
by the **EOS Self-Certification Run (2026-06-28)**. These are **enhancement
items, not blockers** — the EOS is certified to operate as the mandatory gate
without them (see `EOS_RUN_LEDGER.md`).

**Scope rules for every item below:** improve the **EOS implementation only**.
Do **not** rewrite, duplicate, move, or restructure the
`AKSHARA_ENGINEERING_CONSTITUTION.md` (it is frozen/stable). Do **not** touch
Flutter / backend / database / QA waves / roadmap / production code.

| ID | Title | Severity | Owning Constitution rule | Status |
|----|-------|----------|--------------------------|--------|
| F2 | Map Part 8 *Automatic QA Planning* | P2 | Part 8 — *Automatic QA Planning* | Backlog |
| F3 | Map Part 8 *AI Engineering Guidance* | P2 | Part 8 — *AI Engineering Guidance* | Backlog |
| F4 | Add *Certification Evidence Storage* fields to report template | P2 | Part 7B — *Certification Evidence Storage* | Backlog |
| F5 | Reconcile health-score taxonomy with Part 8 health pillars | P2 | Part 8 — *Engineering Health* | Backlog |
| F6 | Define EOS fallback for categories lacking Acceptance Criteria | P3 | Part 7B — Categories 5 (Accessibility) & 14 (Analytics) | Backlog |
| F7 | Show the full Certification Scope ladder | P3 | Part 7B — *Certification Scope* | Backlog |
| F8 | (Cosmetic) De-compress the auto-failure list | P3 | Part 7B — *Automatic Failure Conditions* | Optional |

---

## F2 — Map Part 8 *Automatic QA Planning*  ·  P2
- **Gap:** `CONSTITUTION_MAP.md`'s "Part 8 detection checklist" omits the
  *Automatic QA Planning* section (QA Waves · Regression Packs · Smoke Tests ·
  Feature / Security / Performance / Production Certification).
- **Risk:** the EOS can mark a wave "done" without wiring the Constitution's
  QA-planning step.
- **Fix direction:** add one pointer row to the Part-8 section of
  `CONSTITUTION_MAP.md`. No skill-body change (it already iterates Part 8).

## F3 — Map Part 8 *AI Engineering Guidance*  ·  P2
- **Gap:** *AI Engineering Guidance* ("the EOS should verify the implementation
  follows this Constitution… identify skipped engineering practices before
  changes are accepted") is uncited anywhere in the skill.
- **Risk:** notable for an AI-built project — the section most directly about
  this project's workflow is embodied only implicitly.
- **Fix direction:** add a map pointer; reference it in the gate narrative.

## F4 — Add *Certification Evidence Storage* fields to the report template  ·  P2
- **Gap:** the report template in `USAGE.md` captures Date / Evidence / Result
  but omits **Version**, **Reviewer**, and **Remaining Risks** — fields Part 7B
  requires every certification to generate.
- **Fix direction:** add those three fields to the report-template header in
  `USAGE.md`.

## F5 — Reconcile health-score taxonomy with Part 8 health pillars  ·  P2
- **Gap:** the EOS scores the 20 Part-7B certification categories, but Part 8 —
  *Engineering Health* names ~14 pillars including **Infrastructure Health**,
  **Release Health**, and **Production Health** that have no 1:1 category row.
- **Risk:** those pillars can go unscored. (Low impact — scores never gate, per
  Part 7B — *Engineering Score*.)
- **Fix direction:** either map the extra pillars onto categories explicitly or
  add them as health rows in the report template.

## F6 — Define EOS fallback for categories lacking Acceptance Criteria  ·  P3
- **Gap:** Part 7B categories 5 (Accessibility) and 14 (Analytics) have no
  dedicated Acceptance Criteria / Failure Conditions section in the Constitution.
  The EOS is told to "apply that Part's Acceptance Criteria" where none exist.
- **Constraint:** the Constitution is frozen — this is **not** a request to add
  Constitution sections. The EOS-side fix is to define a **deterministic
  fallback**: evaluate against the nearest owning section (3A/6A for
  accessibility; 6B + Part 8 *Inputs* for analytics) and explicitly flag
  "no dedicated criteria — evidence-based judgement, not opinion," so the engine
  never silently improvises (which Part 7B — *Failure Conditions* forbids).
- **Fix direction:** add the fallback rule to `CONSTITUTION_MAP.md` notes for
  those two category rows.

## F7 — Show the full Certification Scope ladder  ·  P3
- **Gap:** `SKILL.md` abbreviates the scope ladder to 9 rungs
  ("function → … → commercial"); Part 7B — *Certification Scope* lists 15,
  including Background Jobs, Notifications, Reports, AI Features, Offline
  Features, and Entire Applications.
- **Risk:** a reviewer may not treat those as first-class certifiable scopes.
- **Fix direction:** reference the full section instead of the abbreviated ladder.

## F8 — (Cosmetic) De-compress the auto-failure list  ·  P3 · Optional
- **Observation:** the EOS lists "broken auth/sync" as one item; the
  Constitution lists *Broken Authentication* and *Broken Synchronization*
  separately (11 conditions vs the EOS's 10). Both are already covered — purely
  cosmetic.
- **Fix direction:** split the two for a 1:1 match, or leave as-is. No
  functional impact.
