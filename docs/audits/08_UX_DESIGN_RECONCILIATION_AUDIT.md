# Akshara ERP — UX & Design-System Reconciliation Audit

**Auditor:** Fable (independent) · **Date:** 2026-07-03 · **HEAD:** `68f15cb`
**Scope:** reconcile the prior Fable UI/UX audit (2026-07-02, archived) against current implementation; assess the design system; add new findings.
**Confidence:** High (design system verified in code); Medium on per-screen UX deltas (the mobile-UX deep-dive was session-limited).

> **Charter Part 8 compliance:** the prior audit is one day old and its recommendations are a *plan*,
> largely **not yet implemented**. Most Tier 1–3 items therefore remain valid. This report does not
> repeat the prior audit's per-screen detail; it validates its verdict, records what has changed since,
> and folds the still-valid items into the new roadmap.

---

## 1. The design system is REAL (a genuine strength)

The approved "Premium School OS" visual system (`docs/design/VISUAL_DESIGN_SYSTEM.md`) is **substantially and actively implemented**, not aspirational:
- Token-driven: `lib/theme/` has color/typography/spacing(8pt)/radius/elevation/shadow token files, with **exact-match** brand colors (`#5B5BF0`), canvas gradient, hairline borders, KPI type scale.
- Live components in production dashboards (Parent/Teacher/Student): `AksharaGradientHero`, `AksharaPremiumKpiCard`, `AksharaAiSuggestionBar`, `AksharaPremiumEmptyState`, line-art motifs.
- White-label-ready (per-school color override hooks exist).

**Drift / aspirational (minor):** dark theme is code-complete but **not user-facing** (`themeMode` = Light only); the docked center-AI FAB is documented but not integrated; Inter font is intended but ships Roboto+Noto; shadow pixel values are approximated. None block pilot.

---

## 2. Reconciliation of the prior Fable UI/UX audit (2026-07-02)

Prior verdict: **UX 5.5/10** — "foundation outclasses UX"; the five highest-frequency workflows (attendance, marks, grading, approvals, fee collection) carry the most friction; design system unenforced across the long tail; feedback layer (skeletons, haptics, refresh, undo) absent.

| Prior recommendation | Status at HEAD `68f15cb` | Verdict |
|---|---|---|
| Tier 1 #1 Payment-flow trust pack | Not implemented | **Still valid** |
| Tier 1 #2 Keyboard-type sweep (~1,402 fields) | Not implemented | **Still valid** (mechanical; high daily impact) |
| Tier 1 #3 Feedback layer (haptics/refresh/skeletons/success) | Not implemented | **Still valid** |
| Tier 1 #5 Copy pass (~30% raw error enums) | Partially relevant — backend still leaks raw `error.message` (SEC-6) | **Still valid** |
| Tier 1 #6 Freshness chip (offline "as of…") | Read-cache infra exists (REL); chip not surfaced | **Still valid** (infra now exists — cheap to surface) |
| Tier 1 #7 PopScope + draft-chip | Draft mixin exists but wired into 2 screens (REL-3) | **Partially delivered; extend** |
| Tier 2 #10 Bulk-operations framework | **Partially delivered** — PRI-1 batch approve/reject shipped; HR leave batch shipped | **Advanced; generalize to all lists** |
| Tier 2 #11 Approvals Inbox (cross-module) | Not unified (per-module approvals exist) | **Still valid** |
| Tier 2 #8/#9 Exception-grid attendance / inline marks ergonomics | Not implemented (marks grid exists but save bypasses reliability, REL-2) | **Still valid — highest adoption impact** |
| Tier 3 #15 Design-system enforcement (lints, contrast-in-CI, migration sweep) | Not enforced | **Still valid** |
| Tier 4 (UPI-native, Morning Brief, digests, Student 360, actionable notifications) | Backlog candidates | **Owner to mint; post-pilot** |

**Net:** the module-completion + identity waves since 2026-07-02 added *features and backends*, not the *ergonomic/feedback* layer the UX audit prioritized. The prior audit's Tier 1–3 program is **still ~90% open and still the right UX plan**. It should be run as a named "Product Excellence (UX) wave" with QW-style certification, after the core is live-verified.

---

## 3. New / reinforced findings

| ID | Sev | Finding | Evidence | Recommendation |
|---|---|---|---|---|
| UX-1 | **P1** | The five highest-frequency workflows still carry the most friction (attendance, marks, grading, approvals, fee) | prior audit Phase 2; marks-save bypass REL-2 | Run Tier 2 #8/#9/#10/#11 as the first UX wave — this is where daily adoption is won or lost. |
| UX-2 | **P1** | Feedback layer absent (0 skeleton screens, 1 pull-to-refresh, no haptics, no success views) | prior audit metrics | Ship the Tier 1 feedback pack — cheapest perceived-quality upgrade vs the consumer apps parents use daily. |
| UX-3 | **P2** | Offline read-cache exists but its freshness state is invisible to users | REL read-cache; no "as of…" chip | Surface the freshness chip on money/attendance surfaces — converts built infrastructure into visible trust. |
| UX-4 | **P2** | Design system is unenforced on the long tail (raw TextStyles/colors on new code) | prior audit Tier 3 #15 | Add lints (error-on-new-code) + contrast checker in CI + persona-shell golden baselines. |
| UX-5 | **P2** | Keyboard-type / input-affordance sweep not done (~4% of fields have correct keyboard hints) | prior audit; HR free-text date fields (`hr_workflow_actions.dart:80`) | Mechanical sweep: correct `keyboardType` + date pickers (XCT-3 in the enhancement backlog). |
| UX-6 | **P3** | Dark theme built but not user-toggleable | `app_theme.dart` (themeMode=Light) | Ship the toggle when ready; low effort, real delight. |

---

## 4. Desktop vs mobile

- **Mobile-first is real for Parent/Teacher/Student.** Persona shells + premium dashboards are mobile-optimized.
- **ERP admin (Finance/HR/Admissions/SIS) adapts via real breakpoints** — wide tables swap to card layouts under 768px (`admin_layout.dart`, `AdminLayout.useCardLayout`). Usable on a phone; dense-but-functional on tablet-landscape.
- **Gap (Medium conf.):** Desktop productivity affordances the prior audit called for (command palette, dense tables, keyboard-first admin) are largely absent — admin is "responsive mobile screens on a big canvas," not a productivity-optimized desktop surface. This matters for the front-office clerk persona.

## 5. Strategic UX recommendation

The product's UX **foundation is strong** (design tokens, persona shells, offline honesty, governance visibility). The gap is **ergonomic obsession on the five daily tasks + a feedback layer + design-system enforcement** — no re-architecture required. Sequence a **Product Excellence (UX) wave** (Tiers 1–3) after the core is live-verified and before broad commercial rollout. Target: prior audit's 5.5/10 → 8/10 rubric.

## 6. Unknowns

- Per-screen UX deltas since 2026-07-02 across Teacher/Student mobile (deep-dive was session-limited) — inferred from architecture + design-system usage, not re-walked screen-by-screen.
